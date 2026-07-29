// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';

/// A single clickable word of a [OcptShotCoverageBlock], as the scenario coverage editor lays it
/// out from a scene's text.
///
/// [startOffset] and [endOffset] are, like every offset in this file, scene-relative (relative to
/// the owning [OcptShotCoverageLayout.sceneText], itself already sliced out of the screenplay's
/// whole text): [endOffset] is exclusive, so `sceneText.substring(startOffset, endOffset)` always
/// yields back [text].
class OcptShotCoverageWord extends Equatable {
  /// This word's exact source text, punctuation included (a word is a whitespace-delimited run of
  /// non-whitespace characters, so trailing punctuation stays attached to it).
  final String text;

  /// The scene-relative character offset, in the owning [OcptShotCoverageLayout.sceneText], at
  /// which this word starts.
  final int startOffset;

  /// The scene-relative character offset, in the owning [OcptShotCoverageLayout.sceneText], one
  /// past this word's last character.
  final int endOffset;

  /// Class constructor
  const OcptShotCoverageWord({
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShotCoverageWord(text: $text, startOffset: $startOffset, endOffset: $endOffset)";

  /// Object properties
  @override
  List<Object?> get props => [text, startOffset, endOffset];
}

/// One non-blank source line of a scene, laid out into its clickable [words].
///
/// A block never spans more than one Fountain source line, but a coverage *range* may well span
/// several blocks: the click interaction closes a range wherever the second click lands, so a
/// block is a unit of rendering and labelling, never a boundary the model enforces.
class OcptShotCoverageBlock extends Equatable {
  /// This block's line's [FountainLineType], as classified by [OcptShotCoverageLayout.of], shown
  /// as the block's label in the inspector.
  final FountainLineType type;

  /// This block's exact source line text.
  final String text;

  /// The scene-relative character offset, in the owning [OcptShotCoverageLayout.sceneText], at
  /// which this block's line starts.
  final int startOffset;

  /// The scene-relative character offset, in the owning [OcptShotCoverageLayout.sceneText], one
  /// past this block's line's last character (i.e. excluding the newline that follows it).
  final int endOffset;

  /// This block's words, in source order.
  final List<OcptShotCoverageWord> words;

  /// Class constructor
  const OcptShotCoverageBlock({
    required this.type,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.words,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShotCoverageBlock(type: $type, startOffset: $startOffset, endOffset: $endOffset, "
      "wordCount: ${words.length})";

  /// Object properties
  @override
  List<Object?> get props => [type, text, startOffset, endOffset, words];
}

/// A scene's text, laid out into the blocks and words the scenario coverage editor renders and
/// the shot list bloc reasons with.
///
/// Built once per scene by [OcptShotCoverageLayout.of] from the scene's own text (sliced out of
/// the screenplay's whole text using `OcptSceneShotSequence.charStart`/`charEnd`), this is the
/// single place that converts between the word-level interaction the mock-up describes and the
/// character-offset ranges `OcptShotCoverageService` actually stores (see that service's class
/// doc comment for why storage is offset-based rather than word-index-based).
///
/// Every query method below takes the shot(s)' whole [OcptShotCoverageRange] list — which may
/// include ranges of scenes other than this one, since a shot can cover more than one scene's
/// text — and **ignores any range whose [OcptShotCoverageRange.sceneId] differs from [sceneId]**.
class OcptShotCoverageLayout extends Equatable {
  /// The scene this layout was built from.
  final String sceneId;

  /// The scene's own text, sliced out of the screenplay's whole Fountain text using the scene's
  /// `charStart`/`charEnd`. Every offset in this class is relative to the start of this string.
  final String sceneText;

  /// This scene's non-blank source lines, each laid out into a block. A blank line contributes no
  /// block of its own, which is what a renderer reads the gap between two consecutive blocks'
  /// offsets as: adjacent lines are one character apart (their newline), anything wider means the
  /// source left a blank line there.
  final List<OcptShotCoverageBlock> blocks;

  /// Class constructor
  const OcptShotCoverageLayout({
    required this.sceneId,
    required this.sceneText,
    required this.blocks,
  });

  /// Lays [sceneText] (scene [sceneId]'s own text) out into [OcptShotCoverageLayout.blocks].
  ///
  /// Classifies every line of [sceneText] in one `FountainLineClassifier.classify` call: a scene
  /// always starts at its own heading, so classifying its lines in isolation from the rest of the
  /// document is correct here — no `FountainLineType` rule looks outside the one line immediately
  /// before or after the line being classified (see that classifier's doc comment), and a scene
  /// never has lines from a previous scene immediately above its own heading.
  factory OcptShotCoverageLayout.of({required String sceneId, required String sceneText}) {
    final lines = sceneText.split("\n");

    final lineStarts = List<int>.filled(lines.length, 0);
    var offset = 0;
    for (var i = 0; i < lines.length; i++) {
      lineStarts[i] = offset;
      // + 1 for the newline separating this line from the next; irrelevant for the last line,
      // whose real end is its own block's `endOffset` rather than this running total.
      offset += lines[i].length + 1;
    }

    final types = const FountainLineClassifier().classify(lines);

    final blocks = <OcptShotCoverageBlock>[];
    for (var i = 0; i < lines.length; i++) {
      if (types[i] == FountainLineType.blank) {
        continue;
      }

      final line = lines[i];
      final lineStart = lineStarts[i];
      final words = <OcptShotCoverageWord>[
        for (final match in RegExp(r'\S+').allMatches(line))
          OcptShotCoverageWord(
            text: match.group(0)!,
            startOffset: lineStart + match.start,
            endOffset: lineStart + match.end,
          ),
      ];

      blocks.add(
        OcptShotCoverageBlock(
          type: types[i],
          text: line,
          startOffset: lineStart,
          endOffset: lineStart + line.length,
          words: words,
        ),
      );
    }

    return OcptShotCoverageLayout(sceneId: sceneId, sceneText: sceneText, blocks: blocks);
  }

  /// The block whose `[startOffset, endOffset)` contains [offset], or null if [offset] falls on a
  /// blank line or outside every block.
  OcptShotCoverageBlock? blockContaining(int offset) {
    for (final block in blocks) {
      if (offset >= block.startOffset && offset < block.endOffset) {
        return block;
      }
    }
    return null;
  }

  /// The scene-relative range to store for a click on [first] followed by a click on [second],
  /// order-insensitive: closing a range by clicking backwards (the second click lands on a word
  /// before the first) yields the same range as clicking the same two words forwards.
  ({int startOffset, int endOffset}) rangeBetween(
    OcptShotCoverageWord first,
    OcptShotCoverageWord second,
  ) {
    final startOffset = first.startOffset <= second.startOffset
        ? first.startOffset
        : second.startOffset;
    final endOffset = first.endOffset >= second.endOffset ? first.endOffset : second.endOffset;
    return (startOffset: startOffset, endOffset: endOffset);
  }

  /// Whether any of [ranges] (ignoring every range not of [sceneId]) overlaps [word].
  bool isWordCovered(OcptShotCoverageWord word, Iterable<OcptShotCoverageRange> ranges) =>
      _rangesOfThisScene(ranges).any((range) => _overlaps(range, word.startOffset, word.endOffset));

  /// The number of distinct words, across every block of this layout, covered by at least one of
  /// [ranges] (ignoring every range not of [sceneId]).
  ///
  /// Counted as a union: a word covered by two overlapping ranges of the same shot (or of two
  /// different shots) is still counted once, since this walks the layout's own words rather than
  /// summing how many ranges cover each one.
  int countCoveredWords(Iterable<OcptShotCoverageRange> ranges) {
    final relevantRanges = _rangesOfThisScene(ranges).toList(growable: false);
    var count = 0;
    for (final block in blocks) {
      for (final word in block.words) {
        if (relevantRanges.any((range) => _overlaps(range, word.startOffset, word.endOffset))) {
          count++;
        }
      }
    }
    return count;
  }

  /// The ranges of [ranges] (ignoring every range not of [sceneId]) that overlap [block]: the
  /// inspector's "also covered by" set for that block, and what decides its `modified` badge.
  List<OcptShotCoverageRange> rangesIn(
    OcptShotCoverageBlock block,
    Iterable<OcptShotCoverageRange> ranges,
  ) => _rangesOfThisScene(
    ranges,
  ).where((range) => _overlaps(range, block.startOffset, block.endOffset)).toList(growable: false);

  /// The range of [ranges] (ignoring every range not of [sceneId]) covering the scene-relative
  /// [offset], or null if none does: the inspector's "click a covered word to remove its range"
  /// interaction.
  OcptShotCoverageRange? rangeAt(int offset, Iterable<OcptShotCoverageRange> ranges) {
    for (final range in _rangesOfThisScene(ranges)) {
      if (offset >= range.startOffset && offset < range.endOffset) {
        return range;
      }
    }
    return null;
  }

  /// The exact text [range] covers in [sceneText]: what the inspector quotes for a range it lists
  /// read-only, rather than re-rendering the whole scene around it.
  ///
  /// The offsets are clamped to [sceneText]'s own bounds first: a range recorded before an edit
  /// shrank its scene can momentarily reach past the end of the text it was anchored in, and a
  /// quoted extract is not worth throwing a `RangeError` over — that disagreement is what
  /// `OcptShotCoverageService.isRangeStale` reports, and what the `modified` badge shown next to
  /// this very extract already says.
  String coveredTextOf(OcptShotCoverageRange range) {
    final start = range.startOffset.clamp(0, sceneText.length);
    final end = range.endOffset.clamp(start, sceneText.length);
    return sceneText.substring(start, end);
  }

  /// The blocks [range] covers any part of, in reading order: what the inspector labels a quoted
  /// extract with (`ACTION → DIALOGUE` for a range running from one into the other) now that a
  /// range may span more than one of them.
  List<OcptShotCoverageBlock> blocksSpannedBy(OcptShotCoverageRange range) => [
    if (range.sceneId == sceneId)
      for (final block in blocks)
        if (_overlaps(range, block.startOffset, block.endOffset)) block,
  ];

  /// [ranges] (ignoring every range not of [sceneId]) in the order they appear in the scene's
  /// text: the order the inspector lists a shot's covered extracts in, which is the order they
  /// read in rather than the order they happened to be recorded in.
  List<OcptShotCoverageRange> rangesInReadingOrder(Iterable<OcptShotCoverageRange> ranges) =>
      _rangesOfThisScene(ranges).toList()
        ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

  /// Filters [ranges] down to the ones belonging to this layout's own [sceneId], dropping ranges
  /// of any other scene a shot's whole range list may also carry.
  Iterable<OcptShotCoverageRange> _rangesOfThisScene(Iterable<OcptShotCoverageRange> ranges) =>
      ranges.where((range) => range.sceneId == sceneId);

  /// Whether [range] overlaps the scene-relative `[startOffset, endOffset)` span.
  static bool _overlaps(OcptShotCoverageRange range, int startOffset, int endOffset) =>
      range.startOffset < endOffset && range.endOffset > startOffset;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShotCoverageLayout(sceneId: $sceneId, blockCount: ${blocks.length})";

  /// Object properties
  @override
  List<Object?> get props => [sceneId, sceneText, blocks];
}
