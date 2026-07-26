// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';

/// Translates local line indices (into the body line array passed to
/// [FountainBlockBuilder.build]) into [FountainSourceRange]s that point back
/// into the full document source.
///
/// This indirection exists because the body lines the block builder works
/// over may start partway through the document (after a title page), so a
/// local line index and a global line number are not the same thing.
class _RangeCalculator {
  /// Creates a [_RangeCalculator].
  const _RangeCalculator({
    required this.lines,
    required this.lineStartOffsets,
    required this.bodyStartLine,
  });

  /// The body lines being folded into blocks.
  final List<String> lines;

  /// The character offset, in the full document source, of the start of
  /// every global line, indexed by global line number.
  final List<int> lineStartOffsets;

  /// The global line number of `lines[0]`.
  final int bodyStartLine;

  /// Returns the [FountainSourceRange] covering local lines
  /// `[localStart, localEnd]` (inclusive).
  FountainSourceRange rangeFor(int localStart, int localEnd) {
    final globalStart = bodyStartLine + localStart;
    final globalEnd = bodyStartLine + localEnd;
    return FountainSourceRange(
      startLine: globalStart,
      endLine: globalEnd,
      startOffset: lineStartOffsets[globalStart],
      endOffset: lineStartOffsets[globalEnd] + lines[localEnd].length,
    );
  }
}

/// Second parsing pass: folds a body's classified lines into an ordered
/// list of top-level [FountainBlock]s, grouping dialogue (character,
/// parentheticals, dialogue lines) and multi-line elements (action,
/// lyrics) as it goes.
///
/// Like [FountainLineClassifier], this class holds no state between calls:
/// [build] is a pure function of its arguments.
class FountainBlockBuilder {
  /// Creates a [FountainBlockBuilder].
  const FountainBlockBuilder();

  /// Matches a character extension in parentheses at the end of a cue, for
  /// example ` (V.O.)` in `SARAH (V.O.)`.
  static final RegExp _characterExtension = RegExp(
    r'^(.*?)\s*\(([^()]*)\)\s*$',
  );

  /// Matches a scene number tag at the end of a heading, for example
  /// `#4A#` in `INT. HOUSE #4A#`.
  static final RegExp _sceneNumber = RegExp(r'#([A-Za-z0-9.\-]+)#\s*$');

  /// Matches a section heading's leading `#` run and its text.
  static final RegExp _sectionPattern = RegExp(r'^(#{1,6})\s*(.*)$');

  /// Folds [lines] (already classified into [types], one-to-one) into an
  /// ordered list of top-level [FountainBlock]s.
  ///
  /// [lineStartOffsets] must hold, for every global line number of the full
  /// document source, the character offset of that line's first character;
  /// [bodyStartLine] is the global line number of `lines[0]` (non-zero when
  /// the document had a title page before this body).
  List<FountainBlock> build({
    required List<String> lines,
    required List<FountainLineType> types,
    required List<int> lineStartOffsets,
    required int bodyStartLine,
  }) {
    final calculator = _RangeCalculator(
      lines: lines,
      lineStartOffsets: lineStartOffsets,
      bodyStartLine: bodyStartLine,
    );
    final blocks = <FountainBlock>[];
    var index = 0;
    while (index < lines.length) {
      final type = types[index];
      switch (type) {
        case FountainLineType.blank:
          index++;
        case FountainLineType.pageBreak:
          blocks.add(
            FountainPageBreak(sourceRange: calculator.rangeFor(index, index)),
          );
          index++;
        case FountainLineType.section:
          blocks.add(
            _buildSection(lines[index], calculator.rangeFor(index, index)),
          );
          index++;
        case FountainLineType.synopsis:
          blocks.add(
            _buildSynopsis(lines[index], calculator.rangeFor(index, index)),
          );
          index++;
        case FountainLineType.sceneHeading:
          blocks.add(
            _buildSceneHeading(lines[index], calculator.rangeFor(index, index)),
          );
          index++;
        case FountainLineType.transition:
          blocks.add(
            _buildTransition(lines[index], calculator.rangeFor(index, index)),
          );
          index++;
        case FountainLineType.centeredText:
          blocks.add(
            _buildCenteredText(lines[index], calculator.rangeFor(index, index)),
          );
          index++;
        case FountainLineType.lyrics:
          final end = _consumeRun(types, index, FountainLineType.lyrics);
          blocks.add(
            _buildLyrics(
              lines.sublist(index, end + 1),
              calculator.rangeFor(index, end),
            ),
          );
          index = end + 1;
        case FountainLineType.action:
          final end = _consumeRun(types, index, FountainLineType.action);
          blocks.add(
            _buildAction(
              lines.sublist(index, end + 1),
              calculator.rangeFor(index, end),
            ),
          );
          index = end + 1;
        case FountainLineType.character:
          final end = _consumeDialogueGroup(types, index);
          blocks.add(_buildDialogueGroup(lines, types, index, end, calculator));
          index = end + 1;
        case FountainLineType.parenthetical:
        case FountainLineType.dialogue:
          // A parenthetical/dialogue line can only be reached here if it
          // was not preceded by a character cue, which the classifier
          // never produces; fall back to treating it as action so
          // `build` stays total over any input.
          blocks.add(
            FountainActionBlock(
              sourceRange: calculator.rangeFor(index, index),
              lines: [lines[index]],
              forced: false,
            ),
          );
          index++;
      }
    }
    return blocks;
  }

  /// Returns the last local index (inclusive) of the contiguous run of
  /// lines classified as [type] that starts at [start].
  int _consumeRun(
    List<FountainLineType> types,
    int start,
    FountainLineType type,
  ) {
    var end = start;
    while (end + 1 < types.length && types[end + 1] == type) {
      end++;
    }
    return end;
  }

  /// Returns the last local index (inclusive) of a dialogue group starting
  /// with the character cue at [start]: every following line classified as
  /// [FountainLineType.parenthetical] or [FountainLineType.dialogue].
  int _consumeDialogueGroup(List<FountainLineType> types, int start) {
    var end = start;
    while (end + 1 < types.length &&
        (types[end + 1] == FountainLineType.parenthetical ||
            types[end + 1] == FountainLineType.dialogue)) {
      end++;
    }
    return end;
  }

  /// Builds a [FountainSceneHeading] from its raw source line.
  FountainSceneHeading _buildSceneHeading(
    String rawLine,
    FountainSourceRange range,
  ) {
    final forced = rawLine.startsWith('.') && !rawLine.startsWith('..');
    var work = rawLine.trim();
    if (forced) {
      work = work.substring(1).trim();
    }
    String? sceneNumber;
    final numberMatch = _sceneNumber.firstMatch(work);
    if (numberMatch != null) {
      sceneNumber = numberMatch.group(1);
      work = work.substring(0, numberMatch.start).trimRight();
    }
    return FountainSceneHeading(
      sourceRange: range,
      rawText: rawLine,
      headingText: work.toUpperCase().trim(),
      forcedMarker: forced,
      sceneNumber: sceneNumber,
    );
  }

  /// Builds a [FountainActionBlock] from its raw source lines.
  FountainActionBlock _buildAction(
    List<String> rawLines,
    FountainSourceRange range,
  ) {
    final forced = rawLines.first.startsWith('!');
    final content = List<String>.of(rawLines);
    if (forced) {
      content[0] = content[0].substring(1);
    }
    return FountainActionBlock(
      sourceRange: range,
      lines: content,
      forced: forced,
    );
  }

  /// Builds a [FountainCharacter] from its raw source line.
  FountainCharacter _buildCharacter(String rawLine, FountainSourceRange range) {
    var work = rawLine.trim();
    if (work.startsWith('@')) {
      work = work.substring(1).trim();
    }
    var isDualDialogue = false;
    if (work.endsWith('^')) {
      isDualDialogue = true;
      work = work.substring(0, work.length - 1).trim();
    }
    var name = work;
    String? extension;
    final match = _characterExtension.firstMatch(work);
    if (match != null) {
      name = match.group(1)!.trim();
      extension = match.group(2)!.trim();
    }
    return FountainCharacter(
      sourceRange: range,
      name: name,
      extension: extension,
      isDualDialogue: isDualDialogue,
    );
  }

  /// Builds a [FountainDialogueGroup] spanning local lines
  /// `[start, end]`, where `lines[start]` is the character cue.
  FountainDialogueGroup _buildDialogueGroup(
    List<String> lines,
    List<FountainLineType> types,
    int start,
    int end,
    _RangeCalculator calculator,
  ) {
    final character = _buildCharacter(
      lines[start],
      calculator.rangeFor(start, start),
    );
    final children = <FountainBlock>[];
    for (var index = start + 1; index <= end; index++) {
      final childRange = calculator.rangeFor(index, index);
      if (types[index] == FountainLineType.parenthetical) {
        final trimmed = lines[index].trim();
        children.add(
          FountainParenthetical(
            sourceRange: childRange,
            text: trimmed.substring(1, trimmed.length - 1),
          ),
        );
      } else {
        final raw = lines[index];
        children.add(
          FountainDialogueLine(
            sourceRange: childRange,
            text: raw.trim().isEmpty ? '' : raw,
          ),
        );
      }
    }
    return FountainDialogueGroup(
      sourceRange: calculator.rangeFor(start, end),
      character: character,
      children: children,
      isDualDialogue: character.isDualDialogue,
    );
  }

  /// Builds a [FountainTransition] from its raw source line.
  FountainTransition _buildTransition(
    String rawLine,
    FountainSourceRange range,
  ) {
    final trimmed = rawLine.trim();
    final forced = trimmed.startsWith('>');
    final text = forced ? trimmed.substring(1).trim() : trimmed;
    return FountainTransition(sourceRange: range, text: text, forced: forced);
  }

  /// Builds a [FountainLyrics] block from its raw source lines.
  FountainLyrics _buildLyrics(
    List<String> rawLines,
    FountainSourceRange range,
  ) {
    final content = rawLines
        .map(
          (rawLine) => rawLine.startsWith('~') ? rawLine.substring(1) : rawLine,
        )
        .toList(growable: false);
    return FountainLyrics(sourceRange: range, lines: content);
  }

  /// Builds a [FountainCenteredText] block from its raw source line.
  FountainCenteredText _buildCenteredText(
    String rawLine,
    FountainSourceRange range,
  ) {
    final trimmed = rawLine.trim();
    final inner = trimmed.substring(1, trimmed.length - 1).trim();
    return FountainCenteredText(sourceRange: range, text: inner);
  }

  /// Builds a [FountainSection] from its raw source line.
  FountainSection _buildSection(String rawLine, FountainSourceRange range) {
    final match = _sectionPattern.firstMatch(rawLine.trim())!;
    return FountainSection(
      sourceRange: range,
      level: match.group(1)!.length,
      text: match.group(2)!.trim(),
    );
  }

  /// Builds a [FountainSynopsis] from its raw source line.
  FountainSynopsis _buildSynopsis(String rawLine, FountainSourceRange range) {
    final text = rawLine.trim().replaceFirst(RegExp(r'^=+\s?'), '');
    return FountainSynopsis(sourceRange: range, text: text);
  }
}
