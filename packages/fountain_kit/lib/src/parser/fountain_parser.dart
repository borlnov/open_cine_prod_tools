// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/models/fountain_title_page.dart';
import 'package:fountain_kit/src/parser/fountain_block_builder.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';

/// A `key: value` title page entry still being accumulated while scanning
/// the title page pre-pass, before it is frozen into an immutable
/// [FountainTitlePageEntry].
class _PendingTitleEntry {
  /// Creates a [_PendingTitleEntry] starting at [startLine].
  _PendingTitleEntry({required this.key, required this.startLine})
    : endLine = startLine;

  /// The entry key, exactly as written in the source.
  final String key;

  /// The value lines accumulated so far, in source order.
  final List<String> values = [];

  /// The global line number of the `key: value` line itself.
  final int startLine;

  /// The global line number of the last value line accumulated so far.
  int endLine;
}

/// A boneyard or standalone-note span found by a pre-pass, still expressed
/// in raw offsets before it is turned into a [FountainBlock].
class _ScrubbedSpan {
  /// Creates a [_ScrubbedSpan].
  const _ScrubbedSpan({
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.isBoneyard,
  });

  /// The character offset, in the document source, of the first character
  /// of this span (including its markers).
  final int startOffset;

  /// The character offset one past the last character of this span
  /// (including its markers).
  final int endOffset;

  /// The span's inner text, with its `/* */` or `[[ ]]` markers stripped.
  final String text;

  /// Whether this span is a boneyard comment (`true`) or a standalone note
  /// (`false`).
  final bool isBoneyard;
}

/// Parses Fountain screenplay source text into a [FountainDocument].
///
/// Parsing runs in clearly separated, side-effect-free passes:
///
/// 1. Boneyard (`/* */`) extraction, which also blanks out the matched
///    text so later passes never see it.
/// 2. Standalone note (`[[ ]]`) extraction, same treatment.
/// 3. Title page extraction.
/// 4. Line classification ([FountainLineClassifier]).
/// 5. Block building ([FountainBlockBuilder]).
/// 6. Merging the boneyard/note blocks from steps 1-2 back into the block
///    list built in step 5, in source order.
///
/// Every pass is a pure function of its input and returns plain data (no
/// pass mutates shared state), which keeps the door open for a future
/// incremental `reparseRange` entry point that only redoes the passes for a
/// changed region of the document.
class FountainParser {
  /// Creates a [FountainParser].
  const FountainParser();

  /// Matches a title page key at the start of a line, for example `Draft
  /// date` in `Draft date: 1/1/2026`.
  static final RegExp _titleKeyPattern = RegExp('^([A-Za-z][A-Za-z0-9 ]*):');

  /// Matches a boneyard block comment, possibly spanning several lines.
  static final RegExp _boneyardPattern = RegExp(r'/\*[\s\S]*?\*/');

  /// Matches an inline or standalone authoring note, possibly spanning
  /// several lines.
  static final RegExp _notePattern = RegExp(r'\[\[[\s\S]*?\]\]');

  /// Parses [source] into a [FountainDocument].
  FountainDocument parse(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lineStartOffsets = _computeLineStartOffsets(normalized);

    final boneyardSpans = _extractSpans(
      normalized,
      _boneyardPattern,
      isBoneyard: true,
    );
    final afterBoneyard = _scrub(
      normalized,
      boneyardSpans.map((span) => (span.startOffset, span.endOffset)),
    );

    final noteSpans = _extractStandaloneNoteSpans(
      afterBoneyard,
      lineStartOffsets,
    );
    final scrubbed = _scrub(
      afterBoneyard,
      noteSpans.map((span) => (span.startOffset, span.endOffset)),
    );

    final lines = scrubbed.split('\n');

    final titlePageResult = _parseTitlePage(lines, lineStartOffsets);
    final bodyLines = lines.sublist(titlePageResult.bodyStartLine);

    final types = const FountainLineClassifier().classify(bodyLines);
    final bodyBlocks = const FountainBlockBuilder().build(
      lines: bodyLines,
      types: types,
      lineStartOffsets: lineStartOffsets,
      bodyStartLine: titlePageResult.bodyStartLine,
    );

    final extraBlocks = [...boneyardSpans, ...noteSpans]
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));
    final blocks = _mergeByOffset(
      bodyBlocks,
      extraBlocks
          .map((span) => _buildExtraBlock(span, lineStartOffsets))
          .toList(growable: false),
    );

    return FountainDocument(
      titlePage: titlePageResult.titlePage,
      blocks: blocks,
      sourceText: normalized,
    );
  }

  /// Returns, for every global line number of [source], the character
  /// offset of that line's first character.
  List<int> _computeLineStartOffsets(String source) {
    final offsets = <int>[0];
    for (var index = 0; index < source.length; index++) {
      if (source[index] == '\n') {
        offsets.add(index + 1);
      }
    }
    return offsets;
  }

  /// Returns the global line number containing character offset [offset],
  /// given the document's [lineStartOffsets] table.
  int _lineForOffset(List<int> lineStartOffsets, int offset) {
    var line = 0;
    for (var index = 0; index < lineStartOffsets.length; index++) {
      if (lineStartOffsets[index] <= offset) {
        line = index;
      } else {
        break;
      }
    }
    return line;
  }

  /// Finds every match of [pattern] in [source] and returns it as a
  /// [_ScrubbedSpan].
  List<_ScrubbedSpan> _extractSpans(
    String source,
    RegExp pattern, {
    required bool isBoneyard,
  }) {
    // Both `/* */` and `[[ ]]` markers are two characters long on each side.
    const markerLength = 2;
    return pattern
        .allMatches(source)
        .map(
          (match) => _ScrubbedSpan(
            startOffset: match.start,
            endOffset: match.end,
            text: source.substring(
              match.start + markerLength,
              match.end - markerLength,
            ),
            isBoneyard: isBoneyard,
          ),
        )
        .toList(growable: false);
  }

  /// Finds every `[[ ]]` note in [source] that occupies one or more whole
  /// lines by itself (i.e. nothing but whitespace shares its line(s)),
  /// which is what makes it a standalone [FountainNoteBlock] rather than an
  /// inline note span within another block (see `FountainInlineStyle.note`).
  List<_ScrubbedSpan> _extractStandaloneNoteSpans(
    String source,
    List<int> lineStartOffsets,
  ) {
    final spans = <_ScrubbedSpan>[];
    for (final match in _notePattern.allMatches(source)) {
      final startLine = _lineForOffset(lineStartOffsets, match.start);
      final endLine = _lineForOffset(lineStartOffsets, match.end - 1);
      final lineStart = lineStartOffsets[startLine];
      final lineEndOffset = endLine + 1 < lineStartOffsets.length
          ? lineStartOffsets[endLine + 1] - 1
          : source.length;
      final before = source.substring(lineStart, match.start);
      final after = source.substring(match.end, lineEndOffset);
      if (before.trim().isEmpty && after.trim().isEmpty) {
        spans.add(
          _ScrubbedSpan(
            startOffset: match.start,
            endOffset: match.end,
            text: source.substring(match.start + 2, match.end - 2),
            isBoneyard: false,
          ),
        );
      }
    }
    return spans;
  }

  /// Returns a copy of [source] with every character offset covered by
  /// [spans] replaced by a space (newlines are preserved), so that the
  /// text's line structure and every other character offset stay stable
  /// for later passes.
  String _scrub(String source, Iterable<(int, int)> spans) {
    final buffer = StringBuffer();
    var cursor = 0;
    for (final span in spans) {
      buffer.write(source.substring(cursor, span.$1));
      for (var index = span.$1; index < span.$2; index++) {
        buffer.write(source[index] == '\n' ? '\n' : ' ');
      }
      cursor = span.$2;
    }
    buffer.write(source.substring(cursor));
    return buffer.toString();
  }

  /// Builds the top-level [FountainBlock] (a [FountainBoneyard] or
  /// [FountainNoteBlock]) for a pre-pass [span].
  FountainBlock _buildExtraBlock(
    _ScrubbedSpan span,
    List<int> lineStartOffsets,
  ) {
    final range = FountainSourceRange(
      startLine: _lineForOffset(lineStartOffsets, span.startOffset),
      endLine: _lineForOffset(lineStartOffsets, span.endOffset - 1),
      startOffset: span.startOffset,
      endOffset: span.endOffset,
    );
    return span.isBoneyard
        ? FountainBoneyard(sourceRange: range, text: span.text)
        : FountainNoteBlock(sourceRange: range, text: span.text);
  }

  /// Merges two block lists, both already in ascending source-offset
  /// order, into one list in ascending source-offset order.
  List<FountainBlock> _mergeByOffset(
    List<FountainBlock> first,
    List<FountainBlock> second,
  ) {
    final merged = <FountainBlock>[];
    var indexA = 0;
    var indexB = 0;
    while (indexA < first.length && indexB < second.length) {
      if (first[indexA].sourceRange.startOffset <=
          second[indexB].sourceRange.startOffset) {
        merged.add(first[indexA++]);
      } else {
        merged.add(second[indexB++]);
      }
    }
    merged.addAll(first.skip(indexA));
    merged.addAll(second.skip(indexB));
    return merged;
  }

  /// Scans [lines] for a leading title page block and returns it together
  /// with the global line number the document body starts at.
  ({FountainTitlePage? titlePage, int bodyStartLine}) _parseTitlePage(
    List<String> lines,
    List<int> lineStartOffsets,
  ) {
    if (lines.isEmpty || !_titleKeyPattern.hasMatch(lines[0])) {
      return (titlePage: null, bodyStartLine: 0);
    }

    final pending = <_PendingTitleEntry>[];
    var index = 0;
    while (index < lines.length) {
      final line = lines[index];
      if (line.trim().isEmpty) {
        index++;
        break;
      }
      final keyMatch = _titleKeyPattern.firstMatch(line);
      if (keyMatch != null) {
        final entry = _PendingTitleEntry(
          key: keyMatch.group(1)!,
          startLine: index,
        );
        final rest = line.substring(keyMatch.end).trim();
        if (rest.isNotEmpty) {
          entry.values.add(rest);
        }
        pending.add(entry);
        index++;
      } else if (line.startsWith(RegExp(r'\s')) && pending.isNotEmpty) {
        pending.last.values.add(line.trim());
        pending.last.endLine = index;
        index++;
      } else {
        break;
      }
    }

    if (pending.isEmpty) {
      return (titlePage: null, bodyStartLine: 0);
    }

    final entries = pending
        .map(
          (entry) => FountainTitlePageEntry(
            key: entry.key,
            values: entry.values.isEmpty ? [''] : entry.values,
            sourceRange: FountainSourceRange(
              startLine: entry.startLine,
              endLine: entry.endLine,
              startOffset: lineStartOffsets[entry.startLine],
              endOffset:
                  lineStartOffsets[entry.endLine] + lines[entry.endLine].length,
            ),
          ),
        )
        .toList(growable: false);

    final titlePage = FountainTitlePage(
      entries: entries,
      sourceRange: FountainSourceRange(
        startLine: 0,
        endLine: pending.last.endLine,
        startOffset: lineStartOffsets[0],
        endOffset:
            lineStartOffsets[pending.last.endLine] +
            lines[pending.last.endLine].length,
      ),
    );
    return (titlePage: titlePage, bodyStartLine: index);
  }
}
