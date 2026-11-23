// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/models/fountain_title_page.dart';
import 'package:fountain_kit/src/models/fountain_title_page_entry.dart';
import 'package:fountain_kit/src/parser/fountain_block_builder.dart';
import 'package:fountain_kit/src/parser/fountain_comment_spans.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';

/// A `key: value` title page entry still being accumulated while scanning
/// the title page pre-pass, before it is frozen into an immutable
/// [FountainTitlePageEntry].
class _PendingTitleEntry {
  /// The entry key, exactly as written in the source.
  final String key;

  /// The value lines accumulated so far, in source order.
  final List<String> values;

  /// The global line number of the `key: value` line itself.
  final int startLine;

  /// The global line number of the last value line accumulated so far.
  int endLine;

  /// Create a [_PendingTitleEntry] starting at [startLine].
  _PendingTitleEntry({required this.key, required this.startLine})
    : values = [],
      endLine = startLine;
}

/// A boneyard or standalone-note span found by a pre-pass, still expressed
/// in raw offsets before it is turned into a [FountainBlock].
class _ScrubbedSpan {
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

  /// Create a [_ScrubbedSpan].
  const _ScrubbedSpan({
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.isBoneyard,
  });
}

/// Parse Fountain screenplay source text into a [FountainDocument].
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
  /// Matches a title page key at the start of a line, for example `Draft
  /// date` in `Draft date: 1/1/2026`.
  static final RegExp _titleKeyPattern = RegExp('^([A-Za-z][A-Za-z0-9 ]*):');

  /// Create a [FountainParser].
  const FountainParser();

  /// Parse [source] into a [FountainDocument].
  FountainDocument parse(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lineStartOffsets = _computeLineStartOffsets(normalized);

    final boneyardSpans = _extractSpans(normalized, FountainCommentSpans.boneyards(normalized));
    final afterBoneyard = FountainCommentSpans.scrub(
      normalized,
      FountainCommentSpans.boneyards(normalized),
    );

    final noteSpans = _extractStandaloneNoteSpans(afterBoneyard);
    final scrubbed = FountainCommentSpans.scrub(
      afterBoneyard,
      noteSpans.map(
        (span) =>
            FountainCommentSpan(start: span.startOffset, end: span.endOffset, isBoneyard: false),
      ),
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
      extraBlocks.map((span) => _buildExtraBlock(span, lineStartOffsets)).toList(growable: false),
    );

    return FountainDocument(
      titlePage: titlePageResult.titlePage,
      blocks: blocks,
      sourceText: normalized,
    );
  }

  /// Return, for every global line number of [source], the character
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

  /// Return the global line number containing character offset [offset],
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

  /// Turn each of [spans], found in [source], into a [_ScrubbedSpan].
  List<_ScrubbedSpan> _extractSpans(String source, List<FountainCommentSpan> spans) {
    // Both `/* */` and `[[ ]]` markers are two characters long on each side.
    const markerLength = 2;
    return spans
        .map(
          (span) => _ScrubbedSpan(
            startOffset: span.start,
            endOffset: span.end,
            text: source.substring(span.start + markerLength, span.end - markerLength),
            isBoneyard: span.isBoneyard,
          ),
        )
        .toList(growable: false);
  }

  /// Find every `[[ ]]` note in [source] that occupies one or more whole
  /// lines by itself (i.e. nothing but whitespace shares its line(s)),
  /// which is what makes it a standalone [FountainNoteBlock] rather than an
  /// inline note span within another block (see `FountainInlineStyle.note`).
  List<_ScrubbedSpan> _extractStandaloneNoteSpans(String source) =>
      _extractSpans(source, FountainCommentSpans.standaloneNotes(source));

  /// Build the top-level [FountainBlock] (a [FountainBoneyard] or
  /// [FountainNoteBlock]) for a pre-pass [span].
  FountainBlock _buildExtraBlock(_ScrubbedSpan span, List<int> lineStartOffsets) {
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

  /// Merge two block lists, both already in ascending source-offset
  /// order, into one list in ascending source-offset order.
  List<FountainBlock> _mergeByOffset(List<FountainBlock> first, List<FountainBlock> second) {
    final merged = <FountainBlock>[];
    var indexA = 0;
    var indexB = 0;
    while (indexA < first.length && indexB < second.length) {
      if (first[indexA].sourceRange.startOffset <= second[indexB].sourceRange.startOffset) {
        merged.add(first[indexA++]);
      } else {
        merged.add(second[indexB++]);
      }
    }
    merged.addAll(first.skip(indexA));
    merged.addAll(second.skip(indexB));
    return merged;
  }

  /// Scan [lines] for a leading title page block and return it together
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
        final entry = _PendingTitleEntry(key: keyMatch.group(1)!, startLine: index);
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
              endOffset: lineStartOffsets[entry.endLine] + lines[entry.endLine].length,
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
        endOffset: lineStartOffsets[pending.last.endLine] + lines[pending.last.endLine].length,
      ),
    );
    return (titlePage: titlePage, bodyStartLine: index);
  }
}
