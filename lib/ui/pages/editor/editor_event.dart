// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_pdf_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:spell_kit/spell_kit.dart';

/// The events handled by `OcptEditorBloc`.
sealed class OcptEditorEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptEditorEvent();
}

/// Requests loading the current project's screenplay (text, title and page format) into the
/// editor.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptEditorLoadRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorLoadRequestedEvent();
}

/// Reports that the source text was edited by the user.
///
/// This marks the screenplay dirty and (re)starts the parse and autosave debounce timers.
class OcptEditorTextChangedEvent extends OcptEditorEvent {
  /// The full source text as it now stands in the editor.
  final String text;

  /// Class constructor
  const OcptEditorTextChangedEvent({required this.text});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, text];
}

/// Requests a re-parse of the current source text into a fresh `FountainDocument`.
///
/// This is dispatched by the bloc's own parse debounce timer; it isn't meant to be sent by
/// widgets.
class OcptEditorParseRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorParseRequestedEvent();
}

/// Requests recomputing `OcptEditorState.statistics` from the current document and page setup.
///
/// This is dispatched by the bloc's own statistics debounce timer, kept separate from the parse
/// debounce because pagination is too heavy to run on every parse tick while typing continuously;
/// it isn't meant to be sent by widgets.
class OcptEditorStatisticsRecomputeRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorStatisticsRecomputeRequestedEvent();
}

/// Requests saving the current source text to the project database.
///
/// [isManual] tells whether the save was explicitly requested by the user (toolbar button or
/// Ctrl+S) rather than triggered by the autosave debounce timer: it decides the snapshot reason
/// the save is tagged with.
class OcptEditorSaveRequestedEvent extends OcptEditorEvent {
  /// Whether the save was explicitly requested by the user.
  final bool isManual;

  /// Class constructor
  const OcptEditorSaveRequestedEvent({required this.isManual});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, isManual];
}

/// Reports that the editor caret moved to another source line.
///
/// The current line drives the preview scroll synchronization and the scene panel highlight.
class OcptEditorCaretMovedEvent extends OcptEditorEvent {
  /// The 0-based source line the caret is now on.
  final int line;

  /// Class constructor
  const OcptEditorCaretMovedEvent({required this.line});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, line];
}

/// Requests moving the editor caret to the character offset a scene starts at.
///
/// This is sent when the user clicks a scene in the scene panel; the page applies the resulting
/// `OcptEditorJumpRequest` to its text controller.
class OcptEditorSceneJumpRequestedEvent extends OcptEditorEvent {
  /// The character offset, in the source text, at which the target scene starts.
  final int charOffset;

  /// Class constructor
  const OcptEditorSceneJumpRequestedEvent({required this.charOffset});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, charOffset];
}

/// Toggles the visibility of the scene panel.
class OcptEditorScenePanelToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorScenePanelToggledEvent();
}

/// Selects a tab of the right dock, dispatched by the toolbar's preview/syntax buttons and by the
/// dock's own tab row.
///
/// Implements decision 3's toggle semantics: if [tab] is already the dock's active tab, the dock
/// closes; otherwise the dock opens (or switches) to show [tab]. Either way, [tab] becomes
/// `OcptEditorState.lastRightDockTab`, the tab [OcptEditorRightDockToggledEvent] reopens the dock
/// on. This is also an explicit user action on the dock, so it clears
/// `OcptEditorState.autoClosedRightDockTab` — a dock the user just acted on by hand must never be
/// silently reopened by a later mode switch.
class OcptEditorRightDockTabSelectedEvent extends OcptEditorEvent {
  /// The tab the toolbar button pressed represents.
  final OcptEditorRightDockTab tab;

  /// Class constructor
  const OcptEditorRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock as a whole, dispatched by the workspace toolbar's right dock toggle.
///
/// An open dock closes, whichever tab it shows; a closed one reopens on
/// `OcptEditorState.lastRightDockTab`, so the dock always comes back where the user left it.
/// Just like [OcptEditorRightDockTabSelectedEvent], this is an explicit user action, so it also
/// clears `OcptEditorState.autoClosedRightDockTab`.
class OcptEditorRightDockToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorRightDockToggledEvent();
}

/// Closes the right dock via its own × close button, whichever tab is currently active.
///
/// Just like [OcptEditorRightDockTabSelectedEvent], this is an explicit user action, so it also
/// clears `OcptEditorState.autoClosedRightDockTab`.
class OcptEditorRightDockClosedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorRightDockClosedEvent();
}

/// Requests updating the editor's dock width fractions, persisting whichever of [left]/[right] is
/// given.
///
/// Dispatched once per drag gesture, on `onHorizontalDragEnd`, never per frame: the live drag
/// itself only moves `OcptWorkspaceDockLayoutController`'s in-memory fractions, which is what
/// keeps a drag from emitting a bloc state (and rebuilding the editing subtrees) on every frame.
class OcptEditorDockFractionsChangedEvent extends OcptEditorEvent {
  /// The new left (scenes) dock fraction, or null to leave it unchanged.
  final double? left;

  /// The new right (preview / syntax) dock fraction, or null to leave it unchanged.
  final double? right;

  /// Class constructor
  const OcptEditorDockFractionsChangedEvent({this.left, this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Requests restoring both dock fractions to their defaults ("Reset panel layout").
class OcptEditorDockLayoutResetEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorDockLayoutResetEvent();
}

/// Toggles the editing mode between the styled block editor and the raw text source.
///
/// The new mode is persisted through `OcptPropertiesManager.editorMode`, so it's restored the
/// next time the editor is opened.
class OcptEditorModeToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorModeToggledEvent();
}

/// Toggles the "Word-like" page simulation on or off.
///
/// The new value is persisted through `OcptPropertiesManager.isPageSimulationEnabled`, so it's
/// restored the next time the editor is opened.
class OcptEditorPageSimulationToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorPageSimulationToggledEvent();
}

/// Toggles whether the styled editor shows every scene heading's number in its left gutter.
///
/// The new value is persisted through `OcptPropertiesManager.styledSceneNumbersVisible`, so it's
/// restored the next time the editor is opened.
class OcptEditorStyledSceneNumbersToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorStyledSceneNumbersToggledEvent();
}

/// Toggles whether this machine shows the spell-check underlines, in either editing mode (the `⋮`
/// menu's "Spell check" entry, directly below "Scene numbers").
///
/// The new value is persisted through `OcptPropertiesManager.spellCheckVisible`, so it's restored
/// the next time the editor opens, and re-drives `OcptSpellCheckManager.useLanguage` (this is one
/// of the two on/off switches of `docs/architecture/screenplay.md` — the other is
/// the project's own screenplay language). Switching off also clears
/// `OcptEditorState.rawSpellCheckRanges` at once, rather than waiting for a debounce tick that
/// isn't coming: with the switch off, nothing is ever checked again until it flips back on.
class OcptEditorSpellCheckToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSpellCheckToggledEvent();
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
class OcptEditorSpellCheckRangesReportedEvent extends OcptEditorEvent {
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
class OcptEditorStyledSpellCheckTextsReportedEvent extends OcptEditorEvent {
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
class OcptEditorStyledSpellCheckRangesReportedEvent extends OcptEditorEvent {
  /// The manager's generation the request answered by [ranges] was issued under.
  final int generation;

  /// The misspelled ranges found, keyed by node id, each relative to that node's own display text.
  final Map<String, List<SpellRange>> ranges;

  /// Class constructor
  const OcptEditorStyledSpellCheckRangesReportedEvent({required this.generation, required this.ranges});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, generation, ranges];
}

/// Reports that the styled editor's right-click "Ignore this word" entry was picked for [word].
///
/// Session-only (`docs/architecture/screenplay.md`): reaches
/// `OcptSpellCheckManager.ignoreWord` alone, never `OcptProjectDictionaryService` — persisting an
/// ignored word would silently build a second dictionary nobody can see or edit. The manager's own
/// generation bump has invalidated both spell-check caches by the time this handler returns, so it
/// re-issues a check over both editing surfaces right away: the milestone's own acceptance
/// criterion is that ignoring a word makes its underline disappear without anything having to be
/// re-typed. Refused while a version is being previewed, like every other write this bloc makes.
class OcptEditorWordIgnoredEvent extends OcptEditorEvent {
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
class OcptEditorWordLearnedEvent extends OcptEditorEvent {
  /// The word to teach the open project's dictionary.
  final String word;

  /// Class constructor
  const OcptEditorWordLearnedEvent({required this.word});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, word];
}

/// Requests updating the editor's page setup (page size and margins).
///
/// [pageSetup] is persisted (format per-project, margins app-wide) and applied live to the
/// preview and the styled page editor.
class OcptEditorPageSetupChangedEvent extends OcptEditorEvent {
  /// The new page setup to apply and persist.
  final OcptPageSetup pageSetup;

  /// Class constructor
  const OcptEditorPageSetupChangedEvent({required this.pageSetup});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pageSetup];
}

/// Reports that the project settings page was closed after changing something.
///
/// Unlike [OcptEditorPageSetupChangedEvent], this carries no value: the project settings page
/// writes the project's page format itself (through the very same
/// `OcptProjectsManager.saveCurrentProjectPageFormat`), so all this bloc has to do is re-read it
/// and repaginate.
class OcptEditorProjectSettingsChangedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorProjectSettingsChangedEvent();
}

/// Dismisses the transient save error currently shown, if any.
class OcptEditorSaveErrorDismissedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSaveErrorDismissedEvent();
}

/// Requests leaving the editor and going back to the projects list.
///
/// If the screenplay is dirty, the pending change is flushed with a save first; the current
/// project is then closed and navigation goes back through the router manager.
class OcptEditorBackRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorBackRequestedEvent();
}

/// Requests exporting the current screenplay to a `.fountain` file.
///
/// If the screenplay is dirty, it's saved first (tagged `OcptSnapshotReason.export`) so the
/// exported file matches exactly what the project stores.
class OcptEditorExportRequestedEvent extends OcptEditorEvent {
  /// The label of the file type shown in the native save dialog, localized by the caller.
  final String fileTypeLabel;

  /// The selected episode's own tag (`ep. 2`), resolved by `EditorPage` from
  /// `OcptWorkspaceBloc.state.episodes`/`.selectedEpisodeId` and null while the open project holds
  /// one episode or none — see `ocptWorkspaceEpisodeExportTagOf`.
  final String? episodeTag;

  /// The tapped `Export` control's own screen `Rect`, anchoring the OS share sheet's popover on an
  /// iPad/Mac when the export is handed to it rather than to the native save dialog; null on
  /// desktop and wherever no anchor was resolved.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptEditorExportRequestedEvent({
    required this.fileTypeLabel,
    this.episodeTag,
    this.shareAnchor,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fileTypeLabel, episodeTag, shareAnchor];
}

/// Requests exporting the current screenplay to a PDF file.
///
/// If the screenplay is dirty, it's saved first (tagged `OcptSnapshotReason.export`) so the
/// exported PDF matches exactly what the project stores. [options] carries the one-off
/// format/margins and content toggles picked in the export dialog.
class OcptEditorExportPdfRequestedEvent extends OcptEditorEvent {
  /// The options this export runs with.
  final OcptPdfExportOptions options;

  /// The label of the file type shown in the native save dialog, localized by the caller.
  final String fileTypeLabel;

  /// The selected episode's own tag, exactly as [OcptEditorExportRequestedEvent.episodeTag] is —
  /// see its own doc comment.
  final String? episodeTag;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptEditorExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptEditorExportPdfRequestedEvent({
    required this.options,
    required this.fileTypeLabel,
    this.episodeTag,
    this.shareAnchor,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, fileTypeLabel, episodeTag, shareAnchor];
}

/// Requests replacing the current screenplay text with the content of a picked screenplay file —
/// a `.fountain`, an `.fdx` or a `.celtx`.
///
/// Dispatched only once the user confirmed the replacement in the import confirmation dialog.
class OcptEditorImportRequestedEvent extends OcptEditorEvent {
  /// The label of the file type shown in the open-file dialog, localized by the caller.
  final String fileTypeLabel;

  /// Class constructor
  const OcptEditorImportRequestedEvent({required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fileTypeLabel];
}

/// Dismisses the transient export/import notice currently shown, if any.
class OcptEditorIoNoticeDismissedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorIoNoticeDismissedEvent();
}

/// Requests updating the screenplay's title-page metadata.
///
/// Each field is written into the Fountain source's title-page section (creating one if the
/// screenplay had none, or dropping it entirely if every field is left blank), then the change is
/// saved (tagged `OcptSnapshotReason.manual`) and the document is re-parsed.
class OcptEditorTitlePageChangedEvent extends OcptEditorEvent {
  /// The new `Title` field value, or an empty string to clear it.
  final String title;

  /// The new `Credit` field value, or an empty string to clear it.
  final String credit;

  /// The new `Author` field value, or an empty string to clear it.
  final String author;

  /// The new `Draft date` field value, or an empty string to clear it.
  final String draftDate;

  /// The new `Contact` field value, or an empty string to clear it.
  final String contact;

  /// The new `Source` field value, or an empty string to clear it.
  final String source;

  /// Class constructor
  const OcptEditorTitlePageChangedEvent({
    required this.title,
    required this.credit,
    required this.author,
    required this.draftDate,
    required this.contact,
    required this.source,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, title, credit, author, draftDate, contact, source];
}

/// Opens the find/replace bar, dispatched by Ctrl+F ([withReplaceRow] false), Ctrl+H and the `⋮`
/// menu's `Find and replace…` entry (both [withReplaceRow] true).
///
/// Sets `OcptEditorState.search`'s `isOpen`, and unfolds the replace row when [withReplaceRow] is
/// true — but never folds it back when false, so Ctrl+F on an already-unfolded bar leaves the
/// replace row exactly as it was. Also bumps `OcptEditorSearchState.focusRequestId`, so the bar
/// knows to (re)focus and select the find field even when it was already open.
class OcptEditorSearchOpenedEvent extends OcptEditorEvent {
  /// Whether the replace row must be unfolded.
  final bool withReplaceRow;

  /// Class constructor
  const OcptEditorSearchOpenedEvent({required this.withReplaceRow});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, withReplaceRow];
}

/// Closes the find/replace bar (Escape, or its own × button).
///
/// Clears the highlight (the match count and the current match index), but keeps the query, the
/// replacement and both options, so reopening the bar comes back to the same search.
class OcptEditorSearchClosedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSearchClosedEvent();
}

/// Folds or unfolds the replace row (the bar's own chevron).
class OcptEditorSearchReplaceRowToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSearchReplaceRowToggledEvent();
}

/// Reports that the find field's text changed.
///
/// Resets `OcptEditorSearchState.currentMatchIndex` to 0, ready for the mounted surface's next
/// `OcptEditorSearchMatchesReportedEvent` to clamp it once the new query's matches are known.
class OcptEditorSearchQueryChangedEvent extends OcptEditorEvent {
  /// The find field's new text.
  final String query;

  /// Class constructor
  const OcptEditorSearchQueryChangedEvent({required this.query});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, query];
}

/// Reports that the replace field's text changed.
class OcptEditorSearchReplacementChangedEvent extends OcptEditorEvent {
  /// The replace field's new text.
  final String replacement;

  /// Class constructor
  const OcptEditorSearchReplacementChangedEvent({required this.replacement});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, replacement];
}

/// Toggles the "match case" option (the find field's `Aa` toggle).
class OcptEditorSearchCaseSensitivityToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSearchCaseSensitivityToggledEvent();
}

/// Toggles the "whole word" option (the find field's `ab` toggle).
class OcptEditorSearchWholeWordToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSearchWholeWordToggledEvent();
}

/// Reports the current match count of the mounted editing surface — raw mode counts matches in the
/// Fountain source text, styled mode in each node's display text (see `OcptEditorState.search`'s
/// own doc comment for why the two can differ).
///
/// Clamps `OcptEditorState.search.currentMatchIndex` into the new `[0, matchCount)` range, null
/// when [matchCount] is 0.
class OcptEditorSearchMatchesReportedEvent extends OcptEditorEvent {
  /// The mounted surface's current match count.
  final int matchCount;

  /// Class constructor
  const OcptEditorSearchMatchesReportedEvent({required this.matchCount});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, matchCount];
}

/// Moves to the next match (the bar's `›` button), wrapping from the last match back to the first.
class OcptEditorSearchNextRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSearchNextRequestedEvent();
}

/// Moves to the previous match (the bar's `‹` button), wrapping from the first match back to the
/// last.
class OcptEditorSearchPreviousRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSearchPreviousRequestedEvent();
}

/// Sets the current match to [index] directly, dispatched by whichever editing surface just
/// performed a `Replace` and computed, against the text it just wrote, which match should become
/// current next.
///
/// Not necessarily the match that now sits at the same index the replaced one held: a replacement
/// that itself still matches the query (`MARIE` → `MARIE-JEANNE`, the plan's own headline scenario)
/// still matches at the very same offset, so naively keeping the index in place would land back
/// inside what was just written — turning every further `Replace` press into
/// `MARIE-JEANNE-JEANNE-JEANNE…` forever. The surface is expected to have already recomputed its
/// own matches from the edited text and to follow this event with its own
/// [OcptEditorSearchMatchesReportedEvent], whose clamp is what keeps [index] honest once the final
/// match count is known — general, not raw-mode-specific: the styled mode's own `Replace` reaches
/// it the same way.
class OcptEditorSearchCurrentMatchSelectedEvent extends OcptEditorEvent {
  /// The 0-based index, among the matches the mounted surface just recomputed, to make current.
  final int index;

  /// Class constructor
  const OcptEditorSearchCurrentMatchSelectedEvent({required this.index});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, index];
}
