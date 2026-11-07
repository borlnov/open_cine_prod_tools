// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';

/// This is the bloc class for the screenplay editor's find/replace bar: whether it is open, the
/// query, the replacement, both options, and the match count and current match each editing surface
/// reports.
///
/// The search lives in a bloc of its own rather than in either editing surface, which is what lets
/// it survive a raw ⇄ styled mode toggle: each mode counts what it shows, so the count can
/// legitimately differ between the two for a query holding markup. The bloc owns no text and looks
/// at nothing of the mode: the surfaces find the matches in the text they hold and report how many
/// there are, and replacing is an ordinary edit of that text, which reaches the mode through its
/// text-changed event.
class OcptEditorSearchBloc
    extends AbsOcptViewBloc<OcptEditorSearchState, OcptEditorState, OcptEditorBloc> {
  /// Class constructor
  OcptEditorSearchBloc({required super.modeBloc}) : super(const OcptEditorSearchState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptEditorSearchOpenedEvent>(_onSearchOpened);
    on<OcptEditorSearchClosedEvent>(_onSearchClosed);
    on<OcptEditorSearchReplaceRowToggledEvent>(_onSearchReplaceRowToggled);
    on<OcptEditorSearchQueryChangedEvent>(_onSearchQueryChanged);
    on<OcptEditorSearchReplacementChangedEvent>(_onSearchReplacementChanged);
    on<OcptEditorSearchCaseSensitivityToggledEvent>(_onSearchCaseSensitivityToggled);
    on<OcptEditorSearchWholeWordToggledEvent>(_onSearchWholeWordToggled);
    on<OcptEditorSearchMatchesReportedEvent>(_onSearchMatchesReported);
    on<OcptEditorSearchNextRequestedEvent>(_onSearchNextRequested);
    on<OcptEditorSearchPreviousRequestedEvent>(_onSearchPreviousRequested);
    on<OcptEditorSearchCurrentMatchSelectedEvent>(_onSearchCurrentMatchSelected);
  }

  /// Open the find/replace bar (see `OcptEditorSearchOpenedEvent`'s own doc comment for exactly
  /// what folds and what doesn't).
  Future<void> _onSearchOpened(
    OcptEditorSearchOpenedEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    emitter(
      state.copyWithOpened(
        isReplaceRowOpen: state.isReplaceRowOpen || event.withReplaceRow,
        focusRequestId: state.focusRequestId + 1,
      ),
    );
  }

  /// Close the find/replace bar, clearing the highlight but keeping the query, the replacement
  /// and both options (see `OcptEditorSearchClosedEvent`'s own doc comment).
  Future<void> _onSearchClosed(
    OcptEditorSearchClosedEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    emitter(state.copyWithClosed());
  }

  /// Fold or unfold the replace row.
  Future<void> _onSearchReplaceRowToggled(
    OcptEditorSearchReplaceRowToggledEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    emitter(state.copyWithReplaceRowToggled(isReplaceRowOpen: !state.isReplaceRowOpen));
  }

  /// Store the find field's new text and reset the current match index to 0, ready to be
  /// clamped by the mounted surface's next match count report.
  Future<void> _onSearchQueryChanged(
    OcptEditorSearchQueryChangedEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    emitter(state.copyWithQuery(query: event.query));
  }

  /// Store the replace field's new text.
  Future<void> _onSearchReplacementChanged(
    OcptEditorSearchReplacementChangedEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    emitter(state.copyWithReplacement(replacement: event.replacement));
  }

  /// Toggle the "match case" option.
  Future<void> _onSearchCaseSensitivityToggled(
    OcptEditorSearchCaseSensitivityToggledEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    emitter(state.copyWithCaseSensitivity(isCaseSensitive: !state.isCaseSensitive));
  }

  /// Toggle the "whole word" option.
  Future<void> _onSearchWholeWordToggled(
    OcptEditorSearchWholeWordToggledEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    emitter(state.copyWithWholeWord(isWholeWord: !state.isWholeWord));
  }

  /// Record the mounted surface's current match count, clamping the current match index into the
  /// new range (null once [OcptEditorSearchMatchesReportedEvent.matchCount] is 0).
  Future<void> _onSearchMatchesReported(
    OcptEditorSearchMatchesReportedEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    final matchCount = event.matchCount;
    if (matchCount == 0) {
      emitter(state.copyWithoutMatches());
      return;
    }

    final clampedIndex = (state.currentMatchIndex ?? 0).clamp(0, matchCount - 1);
    emitter(state.copyWithMatches(matchCount: matchCount, currentMatchIndex: clampedIndex));
  }

  /// Move to the next match, wrapping from the last one back to the first. A no-op while there is
  /// no match.
  Future<void> _onSearchNextRequested(
    OcptEditorSearchNextRequestedEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    final matchCount = state.matchCount;
    if (matchCount == 0) {
      return;
    }

    final nextIndex = ((state.currentMatchIndex ?? -1) + 1) % matchCount;
    emitter(state.copyWithCurrentMatch(currentMatchIndex: nextIndex));
  }

  /// Move to the previous match, wrapping from the first one back to the last. A no-op while
  /// there is no match.
  Future<void> _onSearchPreviousRequested(
    OcptEditorSearchPreviousRequestedEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    final matchCount = state.matchCount;
    if (matchCount == 0) {
      return;
    }

    final previousIndex = ((state.currentMatchIndex ?? 0) - 1 + matchCount) % matchCount;
    emitter(state.copyWithCurrentMatch(currentMatchIndex: previousIndex));
  }

  /// Set the current match directly to [OcptEditorSearchCurrentMatchSelectedEvent.index], computed
  /// by whichever editing surface just performed a `Replace` against the text it just wrote (see
  /// the event's own doc comment for why this can't simply keep the previous index).
  Future<void> _onSearchCurrentMatchSelected(
    OcptEditorSearchCurrentMatchSelectedEvent event,
    Emitter<OcptEditorSearchState> emitter,
  ) async {
    emitter(state.copyWithCurrentMatch(currentMatchIndex: event.index));
  }
}
