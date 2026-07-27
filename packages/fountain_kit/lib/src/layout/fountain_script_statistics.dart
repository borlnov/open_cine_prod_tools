// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_printable_text.dart';
import 'package:fountain_kit/src/layout/fountain_script_composer.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';

/// The at-a-glance counters a writer wants while editing a screenplay: how
/// long it is, how many scenes and speaking roles it has, and how dense its
/// prose is.
///
/// [wordCount] and [signCount] are measured over the document's *printable*
/// content only — the body a reader sees on the page, exactly the blocks
/// [FountainScriptComposer] itself prints: section headings, synopses,
/// notes and boneyard comments are editor-only organizational text, so they
/// are excluded, along with the title page (which is not part of
/// [FountainDocument.blocks] to begin with).
class FountainScriptStatistics extends Equatable {
  /// Creates a [FountainScriptStatistics] with every counter given
  /// explicitly. Prefer [FountainScriptStatistics.of] to compute one from a
  /// parsed document.
  const FountainScriptStatistics({
    required this.pageCount,
    required this.sceneCount,
    required this.speakingCharacterCount,
    required this.wordCount,
    required this.signCount,
  });

  /// The all-zero statistics for the no-document-loaded-yet state.
  static const FountainScriptStatistics empty = FountainScriptStatistics(
    pageCount: 0,
    sceneCount: 0,
    speakingCharacterCount: 0,
    wordCount: 0,
    signCount: 0,
  );

  /// The number of printed pages the document would paginate to, i.e.
  /// `FountainScriptComposer().compose(...).pages.length` — the same number
  /// the PDF exporter prints, so the on-screen count always matches the
  /// exported file exactly. `0` for a document with no printable content.
  final int pageCount;

  /// The number of scene headings in the document:
  /// `document.scenes.length`.
  final int sceneCount;

  /// The number of distinct speaking roles: every [FountainCharacter.name]
  /// introducing a [FountainDialogueGroup], normalized (trimmed, internal
  /// whitespace collapsed, upper-cased) and deduplicated, so the same role
  /// cued with and without a parenthetical extension (`(V.O.)`, `(CONT'D)`,
  /// …) — already excluded from [FountainCharacter.name] itself — counts
  /// once. A dual-dialogue pair contributes both of its cues.
  final int speakingCharacterCount;

  /// The number of words across the document's printable content: each
  /// printable block's rendered text is split on runs of whitespace.
  final int wordCount;

  /// The number of signs (non-whitespace characters) across the document's
  /// printable content. "Signs" rather than "characters" to avoid clashing
  /// with [speakingCharacterCount]'s sense of the word.
  final int signCount;

  /// Computes the statistics of [document] when laid out at [metrics].
  factory FountainScriptStatistics.of(
    FountainDocument document,
    FountainLayoutMetrics metrics,
  ) {
    var words = 0;
    var signs = 0;
    for (final block in document.blocks) {
      for (final text in printableTextsOf(block)) {
        words += wordCountOf(text);
        signs += signCountOf(text);
      }
    }

    return FountainScriptStatistics(
      pageCount: const FountainScriptComposer()
          .compose(document: document, metrics: metrics)
          .pages
          .length,
      sceneCount: document.scenes.length,
      speakingCharacterCount: _speakingCharacterCount(document),
      wordCount: words,
      signCount: signs,
    );
  }

  /// The number of distinct normalized character names introducing a
  /// [FountainDialogueGroup] anywhere in [document].
  static int _speakingCharacterCount(FountainDocument document) {
    final names = <String>{};
    for (final block in document.blocks) {
      if (block case FountainDialogueGroup(:final character)) {
        names.add(normalizeCharacterName(character.name));
      }
    }
    return names.length;
  }

  @override
  List<Object?> get props => [
    pageCount,
    sceneCount,
    speakingCharacterCount,
    wordCount,
    signCount,
  ];

  @override
  String toString() =>
      'FountainScriptStatistics($pageCount pages, $sceneCount scenes, '
      '$speakingCharacterCount characters, $wordCount words, '
      '$signCount signs)';
}
