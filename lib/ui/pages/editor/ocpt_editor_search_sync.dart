// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_text_search.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search_text_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// Applies the find/replace bar's state onto the editing surface that is live, and carries out its
/// `Replace` and `Replace all`: each editing surface counts, highlights and replaces what it shows,
/// and this is the page's half of that rule.
///
/// It remembers what it last reported and navigated to, so that typing inside an editing surface
/// while the bar is open never yanks the caret back to "the current match" and a count is reported
/// once per genuine change. The search itself lives in `OcptEditorSearchBloc`; this holds no search
/// state of its own, only those memories.
class OcptEditorSearchSync {
  /// The controller holding the raw source text, which paints the raw mode's matches.
  final OcptEditorSearchTextController _textController;

  /// The controller bridging to the live styled editor, which does the styled mode's own.
  final OcptStyledEditorController _styledEditorController;

  /// The editing mode actually driving which surface is live, see `_EditorViewState._liveMode`.
  final OcptEditorMode Function(OcptEditorState state) _liveMode;

  /// Places the raw selection on a match and scrolls it into view, without taking the keyboard
  /// focus from the find field.
  final void Function(OcptTextMatch match) _navigateToMatch;

  /// The `(query, isCaseSensitive, isWholeWord, text)` combination [_textController]'s matches
  /// were last computed from and reported to the bloc, in raw mode.
  ///
  /// Reset to null whenever raw mode's search sync is skipped (styled mode is active, a version is
  /// being previewed, or the bar is closed), so the next time it applies again always recomputes
  /// and re-reports rather than trusting a coincidental match against stale state from before the
  /// gap — see [syncRaw]'s own doc comment.
  ({String query, bool isCaseSensitive, bool isWholeWord, String text})?
  _lastReportedRawSearchInputs;

  /// The `(query, isCaseSensitive, isWholeWord, currentMatchIndex)` combination the raw
  /// controller's selection/scroll were last navigated to.
  ///
  /// Deliberately excludes the source text itself: recomputing matches after every keystroke made
  /// *inside* the raw editor must not keep yanking the caret back to "the current match" while the
  /// user is simply typing somewhere else. It's still included as part of [syncRaw]'s own
  /// reset-on-gap behaviour, alongside [_lastReportedRawSearchInputs].
  ({String query, bool isCaseSensitive, bool isWholeWord, int? currentMatchIndex})?
  _lastNavigatedRawSearchTarget;

  /// The `(query, isCaseSensitive, isWholeWord, currentMatchIndex)` combination
  /// [_styledEditorController] was last handed a navigation for, the styled mode's own counterpart
  /// to [_lastNavigatedRawSearchTarget] — the styled editor's own delegate is what recomputes and
  /// re-highlights matches reactively on every keystroke made *inside* the document (it alone has
  /// live access to each node's current text), so this dedup only needs to gate genuine navigation
  /// (opening the bar, Next/Previous, a query/option change, a replace's own follow-up selection),
  /// exactly like [_lastNavigatedRawSearchTarget] gates raw mode's.
  ({String query, bool isCaseSensitive, bool isWholeWord, int? currentMatchIndex})?
  _lastNavigatedStyledSearchTarget;

  /// The [OcptStyledEditorController.searchMatchCount] last reported to the bloc, so
  /// [reportStyledMatchCount] only dispatches [OcptEditorSearchMatchesReportedEvent] on
  /// a genuine change — the controller notifies its listeners for other reasons too (a block-type
  /// or inline-style read-state refresh), which must never be mistaken for a fresh match count.
  int? _lastReportedStyledSearchMatchCount;

  /// Class constructor
  OcptEditorSearchSync({
    required OcptEditorSearchTextController textController,
    required OcptStyledEditorController styledEditorController,
    required OcptEditorMode Function(OcptEditorState state) liveMode,
    required void Function(OcptTextMatch match) navigateToMatch,
  }) : _textController = textController,
       _styledEditorController = styledEditorController,
       _liveMode = liveMode,
       _navigateToMatch = navigateToMatch;

  /// Applies [search] onto the live editing surface of [state], reporting the raw mode's count to
  /// [searchBloc], see [syncRaw] and [syncStyled].
  void sync(OcptEditorState state, OcptEditorSearchState search, OcptEditorSearchBloc searchBloc) {
    syncRaw(state, search, searchBloc);
    syncStyled(state, search);
  }

  /// Reports the styled editor's match count to [searchBloc] when it genuinely changed, while the
  /// styled surface is the live one and the bar is open.
  ///
  /// The styled editor's own delegate recomputes matches reactively from the live document on every
  /// keystroke made inside it (only it has access to each node's current text), and its controller
  /// notifies its listeners for other reasons too (a block-type or inline-style read-state refresh),
  /// which must never be mistaken for a fresh match count.
  void reportStyledMatchCount({
    required bool isStyledSurfaceLive,
    required OcptEditorSearchBloc searchBloc,
  }) {
    if (!isStyledSurfaceLive || !searchBloc.state.isOpen) {
      return;
    }

    final matchCount = _styledEditorController.searchMatchCount;
    if (matchCount == _lastReportedStyledSearchMatchCount) {
      return;
    }
    _lastReportedStyledSearchMatchCount = matchCount;
    searchBloc.add(OcptEditorSearchMatchesReportedEvent(matchCount: matchCount));
  }

  /// The current find/replace query, built from [search], reused by every raw-mode search
  /// operation ([syncRaw], [requestRawReplace], [requestRawReplaceAll]) so none of them
  /// can drift from what the bar itself last reported.
  OcptEditorSearchQuery _rawSearchQueryOf(OcptEditorSearchState search) => OcptEditorSearchQuery(
    query: search.query,
    isCaseSensitive: search.isCaseSensitive,
    isWholeWord: search.isWholeWord,
  );

  /// Recomputes [_textController]'s matches from its own live text whenever the find/replace bar
  /// is open in raw mode, paints them through [_textController]'s own
  /// [OcptEditorSearchTextController.updateMatches], reports the count to the bloc, and navigates
  /// the selection/scroll to the current match when the navigation target actually changed.
  ///
  /// Two separate signatures gate the two side effects this performs, both reset to null whenever
  /// the sync is skipped (see [_lastReportedRawSearchInputs]/[_lastNavigatedRawSearchTarget]'s own
  /// doc comments):
  ///
  /// - [_lastReportedRawSearchInputs] includes the live text, so the report re-runs on every edit
  ///   (a match's own count must track what's actually on screen);
  /// - [_lastNavigatedRawSearchTarget] deliberately does not, so typing inside the raw editor while
  ///   the bar is open never yanks the caret back to "the current match" on every keystroke — only
  ///   an actual navigation (opening the bar, Next/Previous, a query/option change, the current
  ///   match's own index moving because the match count changed) does.
  void syncRaw(
    OcptEditorState state,
    OcptEditorSearchState search,
    OcptEditorSearchBloc searchBloc,
  ) {
    if (_liveMode(state) != OcptEditorMode.raw || state.isPreviewingVersion) {
      _lastReportedRawSearchInputs = null;
      _lastNavigatedRawSearchTarget = null;
      return;
    }

    if (!search.isOpen) {
      _textController.updateMatches(const [], null);
      _lastReportedRawSearchInputs = null;
      _lastNavigatedRawSearchTarget = null;
      return;
    }

    final text = _textController.text;
    final matches = _rawSearchQueryOf(search).matchesIn(text);
    _textController.updateMatches(matches, search.currentMatchIndex);

    final reportedInputs = (
      query: search.query,
      isCaseSensitive: search.isCaseSensitive,
      isWholeWord: search.isWholeWord,
      text: text,
    );
    if (reportedInputs != _lastReportedRawSearchInputs) {
      _lastReportedRawSearchInputs = reportedInputs;
      searchBloc.add(OcptEditorSearchMatchesReportedEvent(matchCount: matches.length));
    }

    final navigationTarget = (
      query: search.query,
      isCaseSensitive: search.isCaseSensitive,
      isWholeWord: search.isWholeWord,
      currentMatchIndex: search.currentMatchIndex,
    );
    if (navigationTarget != _lastNavigatedRawSearchTarget) {
      _lastNavigatedRawSearchTarget = navigationTarget;
      final currentIndex = search.currentMatchIndex;
      if (currentIndex != null && currentIndex < matches.length) {
        _navigateToMatch(matches[currentIndex]);
      }
    }
  }

  /// Recomputes and applies the styled mode's own half of the find/replace bar's wiring
  /// (`OcptStyledEditorController.updateSearch`), the counterpart to [syncRaw].
  ///
  /// Unlike [syncRaw], this has nothing to *report*: the styled editor's own delegate
  /// recomputes matches reactively from the live document on every keystroke made inside it (only
  /// it has access to each node's current text) and reports the count itself, through
  /// `_EditorViewState._onStyledEditorControllerChanged`. This method's only job is *navigation* — placing the
  /// selection on the current match and scrolling it into view — which it only forwards when
  /// [_lastNavigatedStyledSearchTarget] shows the navigation target actually changed, exactly like
  /// [syncRaw] gates [_navigateToMatch] the same way (so typing elsewhere in the styled
  /// document never yanks the caret back onto "the current match" on every keystroke either).
  void syncStyled(OcptEditorState state, OcptEditorSearchState search) {
    final isStyledSurfaceLive = _liveMode(state) == OcptEditorMode.styled;
    if (!isStyledSurfaceLive || state.isPreviewingVersion || !search.isOpen) {
      if (_lastNavigatedStyledSearchTarget != null) {
        _lastNavigatedStyledSearchTarget = null;
        _lastReportedStyledSearchMatchCount = null;
        _styledEditorController.updateSearch(query: null, currentMatchIndex: null);
      }
      return;
    }

    final navigationTarget = (
      query: search.query,
      isCaseSensitive: search.isCaseSensitive,
      isWholeWord: search.isWholeWord,
      currentMatchIndex: search.currentMatchIndex,
    );
    if (navigationTarget == _lastNavigatedStyledSearchTarget) {
      return;
    }
    _lastNavigatedStyledSearchTarget = navigationTarget;
    _styledEditorController.updateSearch(
      query: OcptEditorSearchQuery(
        query: search.query,
        isCaseSensitive: search.isCaseSensitive,
        isWholeWord: search.isWholeWord,
      ),
      currentMatchIndex: search.currentMatchIndex,
    );
  }

  /// Replaces the current match in raw mode with the replacement field's text, then selects
  /// whichever match now starts at or after the end of what was just written — never simply the
  /// match that ends up at the same index, which a replacement that itself still matches the query
  /// (`MARIE` → `MARIE-JEANNE`, the scenario that puts replace in scope)
  /// would land back inside, turning every further `Replace` press into
  /// `MARIE-JEANNE-JEANNE-JEANNE…` forever — see `OcptEditorSearchCurrentMatchSelectedEvent`'s own
  /// doc comment. Wraps to the first remaining match when none starts after the edit; dispatches
  /// nothing at all when none remain, since [syncRaw]'s own reactive report already clears
  /// the index to null the moment it sees the match count drop to 0.
  ///
  /// The replacement itself is an ordinary text edit, applied straight onto [_textController]: the
  /// resulting [OcptEditorTextChangedEvent] flows through the existing reclassify/autosave
  /// debounces with no special case, and [syncRaw] is what turns the edit into a fresh
  /// [OcptEditorSearchMatchesReportedEvent] on its own.
  void requestRawReplace(OcptEditorSearchState search, OcptEditorSearchBloc searchBloc) {
    final currentIndex = search.currentMatchIndex;
    if (currentIndex == null) {
      return;
    }

    final text = _textController.text;
    final query = _rawSearchQueryOf(search);
    final matches = query.matchesIn(text);
    if (currentIndex >= matches.length) {
      return;
    }

    final match = matches[currentIndex];
    final replacement = search.replacement;
    final newText = text.replaceRange(match.start, match.end, replacement);
    final writtenEnd = match.start + replacement.length;

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: writtenEnd),
    );

    final newMatches = query.matchesIn(newText);
    if (newMatches.isEmpty) {
      return;
    }
    final nextIndex = newMatches.indexWhere((candidate) => candidate.start >= writtenEnd);
    searchBloc.add(
      OcptEditorSearchCurrentMatchSelectedEvent(index: nextIndex == -1 ? 0 : nextIndex),
    );
  }

  /// Replaces every match in raw mode with the replacement field's text, behind
  /// [OcptConfirmDialog] naming how many matches will be replaced (the repository rule: an
  /// irreversible action is always confirmed by a dialog, never an inline yes/no).
  Future<void> requestRawReplaceAll(BuildContext context, OcptEditorSearchState search) async {
    final text = _textController.text;
    final matches = _rawSearchQueryOf(search).matchesIn(text);
    if (matches.isEmpty) {
      return;
    }

    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.editorReplaceAllConfirmTitle,
      message: tr.editorReplaceAllConfirmMessage(matches.length),
      cancelLabel: tr.editorReplaceAllConfirmCancelAction,
      confirmLabel: tr.editorReplaceAllConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final replacement = search.replacement;
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      buffer
        ..write(text.substring(cursor, match.start))
        ..write(replacement);
      cursor = match.end;
    }
    buffer.write(text.substring(cursor));

    _textController.value = TextEditingValue(
      text: buffer.toString(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  /// Replaces the current match in styled mode (`OcptStyledEditorController.replaceCurrentMatch`),
  /// then dispatches [OcptEditorSearchCurrentMatchSelectedEvent] with the index it returns — see
  /// that controller method's own doc comment for why this can't simply keep the previous index,
  /// the same reason [requestRawReplace] computes its own `nextIndex` by hand. A no-op (dispatches
  /// nothing) when the controller reports there's nothing left to select.
  void requestStyledReplace(OcptEditorSearchState search, OcptEditorSearchBloc searchBloc) {
    final nextIndex = _styledEditorController.replaceCurrentMatch(search.replacement);
    if (nextIndex == null) {
      return;
    }
    searchBloc.add(OcptEditorSearchCurrentMatchSelectedEvent(index: nextIndex));
  }

  /// Replaces every match in styled mode with the replacement field's text, behind
  /// [OcptConfirmDialog] naming how many matches will be replaced — the same repository rule
  /// [requestRawReplaceAll] follows, reusing the exact same dialog copy so a replace-all reads
  /// identically whichever editing mode triggered it.
  Future<void> requestStyledReplaceAll(BuildContext context, OcptEditorSearchState search) async {
    final matchCount = _styledEditorController.searchMatchCount;
    if (matchCount == 0) {
      return;
    }

    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.editorReplaceAllConfirmTitle,
      message: tr.editorReplaceAllConfirmMessage(matchCount),
      cancelLabel: tr.editorReplaceAllConfirmCancelAction,
      confirmLabel: tr.editorReplaceAllConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    _styledEditorController.replaceAllMatches(search.replacement);
  }
}
