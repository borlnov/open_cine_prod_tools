// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:spell_kit/spell_kit.dart';

/// Matches a boneyard block comment (`/* ... */`), possibly spanning several lines — the very
/// same pattern `FountainParser` extracts standalone boneyard blocks with, kept in step by hand
/// since that one is private to the package.
final RegExp _boneyardPattern = RegExp(r'/\*[\s\S]*?\*/');

/// Matches an inline or standalone authoring note (`[[ ... ]]`), possibly spanning several
/// lines — the mirror of [_boneyardPattern].
final RegExp _notePattern = RegExp(r'\[\[[\s\S]*?\]\]');

/// Whether a screenplay line of [type] is prose a spell check should ever look at, rather than
/// scaffolding or a fixed vocabulary the language itself does not own.
///
/// A scene heading (`INT. KITCHEN - DAY`) is a set name in capitals: proper nouns, abbreviations
/// and a syntax of its own. A character cue — and the `(CONT'D)`/`(MORE)` that rides along with
/// it — is a name, and a writer's invented names are exactly what a dictionary does not have. A
/// transition (`CUT TO:`, `FADE OUT.`) draws from a fixed vocabulary that belongs to the
/// screenplay form, not to the language it is written in. A section heading and a synopsis are
/// the writer talking to themselves about the script, not the script. Lyrics are sung text,
/// written as it is heard, not prose to be corrected. A blank line and a forced page break carry
/// no prose at all. That leaves action, dialogue, a parenthetical and centered text as the
/// screenplay's actual prose — the only four types this returns `true` for.
///
/// A title-page field is left alone for the very same reason a synopsis is, but it never reaches
/// this function as a [FountainLineType] in the first place: a title is invented on purpose, the
/// six fields exist only under page simulation, and a caller (the bloc, or the styled editor's
/// own title-page component) leaves them out of what it hands to the checker before this rule
/// ever runs — this function only ever sees a body line's type.
bool ocptIsSpellCheckedLineType(FountainLineType type) {
  switch (type) {
    case FountainLineType.action:
    case FountainLineType.dialogue:
    case FountainLineType.parenthetical:
    case FountainLineType.centeredText:
      return true;
    case FountainLineType.blank:
    case FountainLineType.pageBreak:
    case FountainLineType.section:
    case FountainLineType.synopsis:
    case FountainLineType.sceneHeading:
    case FountainLineType.transition:
    case FountainLineType.lyrics:
    case FountainLineType.character:
      return false;
  }
}

/// The tokenizer options a screenplay spell check applies by default: the all-caps rule (a scene
/// heading fragment, a character cue or a shouted word) and the digit rule (a page number, a
/// measurement, a code) of `docs/plans/screenplay-spell-check.md` §4.3, both on.
///
/// [SpellTokenizerOptions.fromAffixFile] is the richer form the spell-check worker isolate builds
/// once it has parsed a language's `.aff` file, since it also honours that language's own
/// `WORDCHARS`; this constant is the app-side default for a caller with no affix file in hand
/// (this file has none — it stays free of `spell_kit`'s parsing internals on purpose) and simply
/// relies on `SpellTokenizerOptions`'s own built-in word-character set, over which both rules are
/// already on by default.
const SpellTokenizerOptions ocptScreenplaySpellTokenizerOptions = SpellTokenizerOptions();

/// The spans of every inline authoring note (`[[ ... ]]`) and boneyard comment (`/* ... */`)
/// found inside a block's own [source] text, in ascending order.
///
/// A block's displayed text and its raw Fountain source agree almost everywhere, but a note or a
/// boneyard comment sitting inside a line of action or dialogue is authoring scaffolding, not the
/// script (§4.3) — the very same argument that already keeps a whole note/boneyard *block* out of
/// the checked set entirely. A caller checking raw Fountain source uses these spans to drop the
/// tokens that fall inside them before handing the rest off to be checked.
List<SpellRange> ocptSpellCheckSkipSpansIn(String source) {
  final spans = <SpellRange>[
    for (final match in _boneyardPattern.allMatches(source)) SpellRange(match.start, match.end),
    for (final match in _notePattern.allMatches(source)) SpellRange(match.start, match.end),
  ];
  spans.sort((a, b) => a.start.compareTo(b.start));
  return spans;
}
