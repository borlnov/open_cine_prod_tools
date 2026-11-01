// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/events/editor_base_event.dart';
import 'package:spell_kit/spell_kit.dart';

/// The events about the spell-check pass and the words it is taught.
sealed class OcptEditorSpellCheckEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSpellCheckEvent();
}

/// Reports the misspelled ranges found in the raw mode's Fountain source text, dispatched once
/// `OcptSpellCheckManager.check`'s isolate round trip resolves.
///
/// `OcptEditorBloc._onParseRequested` fires the check request without awaiting it (an `Emitter`
/// can't be used once a handler has returned), so the answer comes back as this event instead.
/// [generation] is the manager's own generation the request was issued under, and [checkedText] is
/// the exact `FountainDocument.sourceText` the request was computed against: the handler drops
/// this answer when either has moved on by the time it arrives (the manager's generation bumped by
/// a language change, or a newer parse having produced a different source text since): a stale
/// generation's answer is never painted (`docs/architecture/screenplay.md`).
class OcptEditorSpellCheckRangesReportedEvent extends OcptEditorSpellCheckEvent {
  /// The manager's generation the request answered by [ranges] was issued under.
  final int generation;

  /// The exact `FountainDocument.sourceText` [ranges] were computed against.
  final String checkedText;

  /// The misspelled ranges found, document-absolute.
  final List<SpellRange> ranges;

  /// Class constructor
  const OcptEditorSpellCheckRangesReportedEvent({
    required this.generation,
    required this.checkedText,
    required this.ranges,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, generation, checkedText, ranges];
}

/// Reports the styled mode's current set of checkable node texts, the styled counterpart to the
/// raw mode's own parse-tick trigger.
///
/// Dispatched by `editor_page.dart` whenever `OcptStyledEditorController
/// .spellCheckTextsByNodeId` actually changes (a document edit that touched a checked block, a
/// full document rebuild, or the visibility switch flipping back on) — the bloc has no document of
/// its own for the styled mode's addressing, since a node's own display text (what
/// `SpellingAndGrammarStyler` addresses) only ever lives in the live super_editor document
/// (`docs/architecture/screenplay.md`).
class OcptEditorStyledSpellCheckTextsReportedEvent extends OcptEditorSpellCheckEvent {
  /// The checkable node texts to check, keyed by node id.
  final Map<String, String> textsByNodeId;

  /// Class constructor
  const OcptEditorStyledSpellCheckTextsReportedEvent({required this.textsByNodeId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, textsByNodeId];
}

/// Reports the misspelled ranges found in the styled mode's checkable node texts, dispatched once
/// `OcptSpellCheckManager.check`'s isolate round trip resolves — the styled counterpart to
/// [OcptEditorSpellCheckRangesReportedEvent].
///
/// [generation] is the manager's own generation the request was issued under; the handler drops
/// this answer when it has since moved on (a language change, or a word learned or ignored, while
/// the isolate round trip was in flight), the same "a stale generation's answer is dropped" rule
/// [OcptEditorSpellCheckRangesReportedEvent] follows. Unlike that event, there is no whole-document
/// `checkedText` to compare against: [ranges] are keyed by node id rather than by document-absolute
/// offset, so a range computed against a node's text that has since changed is instead clamped and
/// dropped at the point it's turned into a `TextError`, by the styled editor itself
/// (`docs/architecture/screenplay.md`) — and a node id that no longer exists in the
/// document by the time this arrives is simply ignored there too.
class OcptEditorStyledSpellCheckRangesReportedEvent extends OcptEditorSpellCheckEvent {
  /// The manager's generation the request answered by [ranges] was issued under.
  final int generation;

  /// The misspelled ranges found, keyed by node id, each relative to that node's own display text.
  final Map<String, List<SpellRange>> ranges;

  /// Class constructor
  const OcptEditorStyledSpellCheckRangesReportedEvent({
    required this.generation,
    required this.ranges,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, generation, ranges];
}

/// Reports that the styled editor's right-click "Ignore this word" entry was picked for [word].
///
/// Session-only (`docs/architecture/screenplay.md`): reaches `OcptSpellCheckManager.ignoreWord`
/// alone, never `OcptProjectDictionaryService` — persisting an ignored word would silently build a
/// second dictionary nobody can see or edit. The manager's own generation bump has invalidated both
/// spell-check caches by the time this handler returns, so it re-issues a check over both editing
/// surfaces right away, so ignoring a word makes its underline disappear without anything
/// having to be re-typed. Refused while a version is being previewed, like every other write this
/// bloc makes.
class OcptEditorWordIgnoredEvent extends OcptEditorSpellCheckEvent {
  /// The word to ignore for the rest of this session.
  final String word;

  /// Class constructor
  const OcptEditorWordIgnoredEvent({required this.word});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, word];
}

/// Reports that the styled editor's right-click "Add to the project's dictionary" entry was
/// picked for [word].
///
/// Persisted through `OcptProjectDictionaryService.learnWord` on the open project's database, the
/// freshly reloaded word list then pushed into `OcptSpellCheckManager.setLearnedWords` — unlike
/// [OcptEditorWordIgnoredEvent], this outlives the session, in the project file itself. Re-issues a
/// check over both editing surfaces afterwards for the identical reason that event does. A no-op
/// with no project open, and refused while a version is being previewed.
class OcptEditorWordLearnedEvent extends OcptEditorSpellCheckEvent {
  /// The word to teach the open project's dictionary.
  final String word;

  /// Class constructor
  const OcptEditorWordLearnedEvent({required this.word});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, word];
}
