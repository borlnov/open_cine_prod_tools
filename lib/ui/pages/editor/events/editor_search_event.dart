// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/events/editor_base_event.dart';

/// The events about the find and replace bar.
sealed class OcptEditorSearchEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSearchEvent();
}

/// Opens the find/replace bar, dispatched by Ctrl+F ([withReplaceRow] false), Ctrl+H and the `⋮`
/// menu's `Find and replace…` entry (both [withReplaceRow] true).
///
/// Sets `OcptEditorState.search`'s `isOpen`, and unfolds the replace row when [withReplaceRow] is
/// true — but never folds it back when false, so Ctrl+F on an already-unfolded bar leaves the
/// replace row exactly as it was. Also bumps `OcptEditorSearchState.focusRequestId`, so the bar
/// knows to (re)focus and select the find field even when it was already open.
class OcptEditorSearchOpenedEvent extends OcptEditorSearchEvent {
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
class OcptEditorSearchClosedEvent extends OcptEditorSearchEvent {
  /// Class constructor
  const OcptEditorSearchClosedEvent();
}

/// Folds or unfolds the replace row (the bar's own chevron).
class OcptEditorSearchReplaceRowToggledEvent extends OcptEditorSearchEvent {
  /// Class constructor
  const OcptEditorSearchReplaceRowToggledEvent();
}

/// Reports that the find field's text changed.
///
/// Resets `OcptEditorSearchState.currentMatchIndex` to 0, ready for the mounted surface's next
/// `OcptEditorSearchMatchesReportedEvent` to clamp it once the new query's matches are known.
class OcptEditorSearchQueryChangedEvent extends OcptEditorSearchEvent {
  /// The find field's new text.
  final String query;

  /// Class constructor
  const OcptEditorSearchQueryChangedEvent({required this.query});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, query];
}

/// Reports that the replace field's text changed.
class OcptEditorSearchReplacementChangedEvent extends OcptEditorSearchEvent {
  /// The replace field's new text.
  final String replacement;

  /// Class constructor
  const OcptEditorSearchReplacementChangedEvent({required this.replacement});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, replacement];
}

/// Toggles the "match case" option (the find field's `Aa` toggle).
class OcptEditorSearchCaseSensitivityToggledEvent extends OcptEditorSearchEvent {
  /// Class constructor
  const OcptEditorSearchCaseSensitivityToggledEvent();
}

/// Toggles the "whole word" option (the find field's `ab` toggle).
class OcptEditorSearchWholeWordToggledEvent extends OcptEditorSearchEvent {
  /// Class constructor
  const OcptEditorSearchWholeWordToggledEvent();
}

/// Reports the current match count of the mounted editing surface — raw mode counts matches in the
/// Fountain source text, styled mode in each node's display text (see `OcptEditorState.search`'s
/// own doc comment for why the two can differ).
///
/// Clamps `OcptEditorState.search.currentMatchIndex` into the new `[0, matchCount)` range, null
/// when [matchCount] is 0.
class OcptEditorSearchMatchesReportedEvent extends OcptEditorSearchEvent {
  /// The mounted surface's current match count.
  final int matchCount;

  /// Class constructor
  const OcptEditorSearchMatchesReportedEvent({required this.matchCount});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, matchCount];
}

/// Moves to the next match (the bar's `›` button), wrapping from the last match back to the first.
class OcptEditorSearchNextRequestedEvent extends OcptEditorSearchEvent {
  /// Class constructor
  const OcptEditorSearchNextRequestedEvent();
}

/// Moves to the previous match (the bar's `‹` button), wrapping from the first match back to the
/// last.
class OcptEditorSearchPreviousRequestedEvent extends OcptEditorSearchEvent {
  /// Class constructor
  const OcptEditorSearchPreviousRequestedEvent();
}

/// Sets the current match to [index] directly, dispatched by whichever editing surface just
/// performed a `Replace` and computed, against the text it just wrote, which match should become
/// current next.
///
/// Not necessarily the match that now sits at the same index the replaced one held: a replacement
/// that itself still matches the query (`MARIE` → `MARIE-JEANNE`, the scenario that puts replace in
/// scope) still matches at the very same offset, so naively keeping the index in place would land
/// back inside what was just written — turning every further `Replace` press into
/// `MARIE-JEANNE-JEANNE-JEANNE…` forever. The surface is expected to have already recomputed its
/// own matches from the edited text and to follow this event with its own
/// [OcptEditorSearchMatchesReportedEvent], whose clamp is what keeps [index] honest once the final
/// match count is known — general, not raw-mode-specific: the styled mode's own `Replace` reaches
/// it the same way.
class OcptEditorSearchCurrentMatchSelectedEvent extends OcptEditorSearchEvent {
  /// The 0-based index, among the matches the mounted surface just recomputed, to make current.
  final int index;

  /// Class constructor
  const OcptEditorSearchCurrentMatchSelectedEvent({required this.index});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, index];
}
