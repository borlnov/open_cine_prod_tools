// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
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
      for (final text in _printableTexts(block)) {
        words += _wordCount(text);
        signs += _signCount(text);
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
        names.add(_normalizeCharacterName(character.name));
      }
    }
    return names.length;
  }

  /// Trims [name], collapses runs of internal whitespace to a single space,
  /// and upper-cases it, so two spellings of the same role are recognized
  /// as one.
  static String _normalizeCharacterName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  /// Yields the rendered text of [block] — the same text
  /// [FountainScriptComposer] would print, parentheses and scene numbers
  /// included — and (for a dialogue group) of every child it introduces, if
  /// [block] is part of the printed screenplay; yields nothing for a
  /// section, synopsis, note, boneyard comment or page break, mirroring the
  /// filter `FountainScriptComposer._printableBlocks` applies before
  /// pagination (replicated rather than shared, since that filter is
  /// private to its own file).
  static Iterable<String> _printableTexts(FountainBlock block) sync* {
    switch (block) {
      case FountainSceneHeading(:final headingText, :final sceneNumber):
        yield sceneNumber == null ? headingText : '$sceneNumber. $headingText';
      case FountainActionBlock(:final lines):
        yield* lines;
      case FountainDialogueGroup(:final character, :final children):
        yield _characterCueText(character);
        for (final child in children) {
          yield* _printableTexts(child);
        }
      case FountainParenthetical(:final text):
        yield '($text)';
      case FountainDialogueLine(:final text):
        yield text;
      case FountainTransition(:final text):
        yield text;
      case FountainLyrics(:final lines):
        yield* lines;
      case FountainCenteredText(:final text):
        yield text;
      case FountainCharacter():
        // Never a top-level or directly-nested block: only reached through
        // FountainDialogueGroup.character above.
        break;
      case FountainSection():
      case FountainSynopsis():
      case FountainNoteBlock():
      case FountainBoneyard():
      case FountainPageBreak():
        break;
    }
  }

  /// The full character cue text: the name, followed by its parenthetical
  /// extension if any, exactly as it is printed.
  static String _characterCueText(FountainCharacter character) =>
      character.extension == null
      ? character.name
      : '${character.name} (${character.extension})';

  /// Splits [text] on runs of whitespace and counts the resulting words; an
  /// empty or all-whitespace [text] counts as zero.
  static int _wordCount(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }

  /// Counts the non-whitespace characters of [text] — what a writer means
  /// by "signs": every printed glyph, spaces excluded.
  static int _signCount(String text) =>
      text.replaceAll(RegExp(r'\s'), '').length;

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
