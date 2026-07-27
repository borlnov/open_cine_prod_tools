// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_printable_text.dart';
import 'package:fountain_kit/src/layout/fountain_script_composer.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';

/// The at-a-glance counters a scene-scoped inspector wants for a single
/// scene of a screenplay: who speaks in it, how many words it holds, and
/// how long it runs once paginated. The scene-scoped sibling of
/// [FountainScriptStatistics].
class FountainSceneStatistics extends Equatable {
  /// Creates a [FountainSceneStatistics] with every counter given
  /// explicitly. Prefer [FountainSceneStatistics.of] to compute one from a
  /// parsed document.
  const FountainSceneStatistics({
    required this.speakingCharacters,
    required this.wordCount,
    required this.pageEighths,
  });

  /// The scene's speaking roles, in order of first appearance, normalized
  /// (trimmed, internal whitespace collapsed, upper-cased) and deduplicated
  /// the same way [FountainScriptStatistics.speakingCharacterCount] is —
  /// see [normalizeCharacterName].
  final List<String> speakingCharacters;

  /// The number of words across the scene's printable content, from its
  /// heading (included) up to, but excluding, the next scene heading (or
  /// the end of the document for the last scene). Counted the same way
  /// [FountainScriptStatistics.wordCount] counts the whole document.
  final int wordCount;

  /// This scene's length in eighths of a page — the unit assistant
  /// directors actually use — derived from the composed line count of the
  /// scene (its heading up to, but excluding, the next one) against
  /// [FountainLayoutMetrics.linesPerPage] at the metrics the scene was
  /// computed with, rounded to the nearest eighth.
  ///
  /// A presentation layer wanting an estimated duration derives it from
  /// this at its own call site, on the industry rule of one page ≈ one
  /// minute (`pageEighths / 8` minutes): that convention belongs to the
  /// presentation, not to this layout fact.
  final int pageEighths;

  /// Computes the statistics of the [sceneIndex]-th scene (0-based, in
  /// [FountainDocument.scenes] order) of [document] when laid out at
  /// [metrics].
  ///
  /// [sceneIndex] must be a valid index into [FountainDocument.scenes];
  /// there is no "no scene" state to represent here, since a caret that
  /// precedes every scene simply has no current scene to compute this for.
  factory FountainSceneStatistics.of(
    FountainDocument document,
    FountainLayoutMetrics metrics,
    int sceneIndex,
  ) {
    final scenes = document.scenes;
    assert(
      sceneIndex >= 0 && sceneIndex < scenes.length,
      'sceneIndex $sceneIndex is out of range for ${scenes.length} scenes',
    );

    final sceneBlocks = _blocksOfScene(document, sceneIndex);

    var words = 0;
    for (final block in sceneBlocks) {
      for (final text in printableTextsOf(block)) {
        words += wordCountOf(text);
      }
    }

    return FountainSceneStatistics(
      speakingCharacters: _speakingCharactersOf(sceneBlocks),
      wordCount: words,
      pageEighths: _pageEighthsOf(document, metrics, sceneIndex),
    );
  }

  /// The top-level blocks of [document] belonging to its [sceneIndex]-th
  /// scene: the scene heading itself, up to (but excluding) the next scene
  /// heading, or the end of [FountainDocument.blocks] for the last scene.
  static List<FountainBlock> _blocksOfScene(
    FountainDocument document,
    int sceneIndex,
  ) {
    final blocks = document.blocks;
    final headingIndices = [
      for (var index = 0; index < blocks.length; index++)
        if (blocks[index] is FountainSceneHeading) index,
    ];

    final start = headingIndices[sceneIndex];
    final end = sceneIndex + 1 < headingIndices.length ? headingIndices[sceneIndex + 1] : blocks.length;
    return blocks.sublist(start, end);
  }

  /// The normalized, deduplicated, first-appearance-ordered speaking roles
  /// introduced by a [FountainDialogueGroup] anywhere in [sceneBlocks]. A
  /// dual-dialogue pair contributes both of its cues.
  static List<String> _speakingCharactersOf(List<FountainBlock> sceneBlocks) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final block in sceneBlocks) {
      if (block case FountainDialogueGroup(:final character)) {
        final normalized = normalizeCharacterName(character.name);
        if (seen.add(normalized)) {
          ordered.add(normalized);
        }
      }
    }
    return ordered;
  }

  /// Composes the whole of [document] at [metrics] and returns the
  /// [sceneIndex]-th scene's line count, rounded to the nearest eighth of
  /// [FountainLayoutMetrics.linesPerPage].
  ///
  /// A scene heading's own composed lines always form one contiguous run
  /// (the composer places a whole heading in one step), so scenes are told
  /// apart by grouping consecutive [FountainScriptLine.isSceneHeading]
  /// lines into heading boundaries. This assumes two consecutive headings
  /// are never composed back to back with zero lines between them, true of
  /// every real screenplay (a heading is normally followed by at least one
  /// spacer or body line before the next one).
  static int _pageEighthsOf(
    FountainDocument document,
    FountainLayoutMetrics metrics,
    int sceneIndex,
  ) {
    final lines = [
      for (final page in const FountainScriptComposer().compose(document: document, metrics: metrics).pages)
        ...page.lines,
    ];

    var ordinal = -1;
    var previousWasHeading = false;
    var sceneLineCount = 0;

    for (final line in lines) {
      if (line.isSceneHeading && !previousWasHeading) {
        ordinal++;
        if (ordinal > sceneIndex) {
          break;
        }
      }
      if (ordinal == sceneIndex) {
        sceneLineCount++;
      }
      previousWasHeading = line.isSceneHeading;
    }

    return (sceneLineCount * 8 / metrics.linesPerPage).round();
  }

  @override
  List<Object?> get props => [speakingCharacters, wordCount, pageEighths];

  @override
  String toString() =>
      'FountainSceneStatistics(${speakingCharacters.length} characters, $wordCount words, '
      '$pageEighths/8 pages)';
}
