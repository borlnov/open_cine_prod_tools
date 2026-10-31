// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListBloc` about workspace shell, selection and dock.
sealed class OcptShotListWorkspaceEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListWorkspaceEvent();
}

/// Requests loading the current project's shot list, together with the persisted dock fractions,
/// visible columns and last right dock tab.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptShotListLoadRequestedEvent extends OcptShotListWorkspaceEvent {
  /// Class constructor
  const OcptShotListLoadRequestedEvent();
}

/// Selects the sequence [sequenceId], expanding it in the left dock and showing its shots in the
/// centre table.
///
/// Selecting a sequence other than the one already selected clears the selected shot: the table
/// now shows a different sequence's shots, none of which the previous selection belonged to.
class OcptShotListSequenceSelectedEvent extends OcptShotListWorkspaceEvent {
  /// The `OcptShotSequence.id` of the sequence to select.
  final String sequenceId;

  /// Class constructor
  const OcptShotListSequenceSelectedEvent({required this.sequenceId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sequenceId];
}

/// Selects the shot [shotId], dispatched by a table row and by a shot entry of the left dock.
///
/// Selecting a shot also selects the sequence holding it (so clicking a shot in the left dock's
/// tree switches the centre table too) and opens the right dock on its inspector tab, matching
/// the mock-up's "clicking a row opens the inspector" behaviour.
class OcptShotListShotSelectedEvent extends OcptShotListWorkspaceEvent {
  /// The id of the shot to select.
  final String shotId;

  /// Class constructor
  const OcptShotListShotSelectedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Toggles the visibility of the left (sequences) dock.
class OcptShotListSequencePanelToggledEvent extends OcptShotListWorkspaceEvent {
  /// Class constructor
  const OcptShotListSequencePanelToggledEvent();
}

/// Selects a tab of the right dock, dispatched by the dock's own tab row.
///
/// Follows the screenplay editor's toggle semantics exactly: selecting the tab already active
/// closes the dock, any other tab opens (or switches) it. Either way [tab] becomes
/// `OcptShotListState.lastRightDockTab`, the tab [OcptShotListRightDockToggledEvent] reopens the
/// dock on, and is persisted.
class OcptShotListRightDockTabSelectedEvent extends OcptShotListWorkspaceEvent {
  /// The tab whose label was clicked.
  final OcptShotListRightDockTab tab;

  /// Class constructor
  const OcptShotListRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock as a whole, dispatched by the workspace toolbar's right dock toggle: an
/// open dock closes, a closed one reopens on `OcptShotListState.lastRightDockTab`.
class OcptShotListRightDockToggledEvent extends OcptShotListWorkspaceEvent {
  /// Class constructor
  const OcptShotListRightDockToggledEvent();
}

/// Closes the right dock via its own × close button, whichever tab is currently active.
class OcptShotListRightDockClosedEvent extends OcptShotListWorkspaceEvent {
  /// Class constructor
  const OcptShotListRightDockClosedEvent();
}

/// Requests updating the mode's dock width fractions, persisting whichever of [left]/[right] is
/// given.
///
/// Dispatched once per drag gesture, on `onHorizontalDragEnd`, never per frame, exactly like the
/// screenplay editor's own equivalent.
class OcptShotListDockFractionsChangedEvent extends OcptShotListWorkspaceEvent {
  /// The new left (sequences) dock fraction, or null to leave it unchanged.
  final double? left;

  /// The new right (inspector) dock fraction, or null to leave it unchanged.
  final double? right;

  /// Class constructor
  const OcptShotListDockFractionsChangedEvent({this.left, this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Requests restoring both dock fractions to their defaults ("Reset panel layout").
class OcptShotListDockLayoutResetEvent extends OcptShotListWorkspaceEvent {
  /// Class constructor
  const OcptShotListDockLayoutResetEvent();
}

/// Shows or hides the optional table column [column], persisting the new set.
class OcptShotListColumnToggledEvent extends OcptShotListWorkspaceEvent {
  /// The optional column whose visibility is toggled.
  final OcptShotListColumn column;

  /// Class constructor
  const OcptShotListColumnToggledEvent({required this.column});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, column];
}

/// Dismisses the transient write error currently shown, if any.
class OcptShotListWriteErrorDismissedEvent extends OcptShotListWorkspaceEvent {
  /// Class constructor
  const OcptShotListWriteErrorDismissedEvent();
}

/// Requests leaving the workspace and going back to the projects list.
///
/// Flushes any pending field edit before closing the current project, so navigating back right
/// after typing never loses it.
class OcptShotListBackRequestedEvent extends OcptShotListWorkspaceEvent {
  /// Class constructor
  const OcptShotListBackRequestedEvent();
}

/// Reports that the project settings page was closed after changing something.
///
/// The page format is the only field the scenario coverage export dialog pre-fills from, so this
/// re-reads it (through `OcptShotListState.pageSetup`) rather than carrying the new value on the
/// event, exactly as the screenplay editor's own equivalent event does.
class OcptShotListProjectSettingsChangedEvent extends OcptShotListWorkspaceEvent {
  /// Class constructor
  const OcptShotListProjectSettingsChangedEvent();
}

/// Selects centre view [view], dispatched by `OcptShotListCentreHeader`'s own switch, and persists
/// it through `OcptPropertiesManager.shotListLastCentreView`.
///
/// Keeps `OcptShotListState.selectedShotId`/`.selectedSequenceId` exactly as they were: the two
/// views read the same selection, one just shows more of it than the other.
class OcptShotListCentreViewSelectedEvent extends OcptShotListWorkspaceEvent {
  /// The view just picked.
  final OcptShotListCentreView view;

  /// Class constructor
  const OcptShotListCentreViewSelectedEvent({required this.view});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, view];
}

/// Selects set `event.setId` on the floor plans view, dispatched by a click on its own tab.
/// A symbol only ever belongs to the set currently shown, so the floor plan canvas drops its
/// selection when it sees the selection move.
class OcptShotListSetSelectedEvent extends OcptShotListWorkspaceEvent {
  /// The id of the set to select.
  final String setId;

  /// Class constructor
  const OcptShotListSetSelectedEvent({required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Selects set [setId], one the floor plans just linked to the selected sequence (created, linked
/// or duplicated), dispatched by `OcptShotListFloorPlanSetsBloc` once the mode holds the set.
///
/// Moves the selection like [OcptShotListSetSelectedEvent] does, saying why: the set was added.
class OcptShotListSetAddedEvent extends OcptShotListWorkspaceEvent {
  /// The id of the set just added to the selected sequence.
  final String setId;

  /// Class constructor
  const OcptShotListSetAddedEvent({required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Falls back to the first set of the selected sequence, after the selected set was unlinked from
/// it, dispatched by `OcptShotListFloorPlanSetsBloc` once the mode holds the sequence's sets
/// without it. Selects none when the sequence has no set left.
class OcptShotListSetRemovedEvent extends OcptShotListWorkspaceEvent {
  /// Class constructor
  const OcptShotListSetRemovedEvent();
}

/// Reads the floor plans again after a placement was removed or hidden, then moves the selection
/// saying why ([cause]) and which row ([targetId]): dispatched by
/// `OcptShotListFloorPlanPlacementsBloc` once it wrote, and awaited, so the canvas has cleared what
/// the gesture always cleared by the time the placements bloc goes on.
///
/// [cause] is one of [OcptShotListSelectionCause.symbolRemoved],
/// [OcptShotListSelectionCause.symbolHidden] and [OcptShotListSelectionCause.arrowRemoved].
class OcptShotListFloorPlanPlacementChangedEvent extends OcptShotListWorkspaceEvent {
  /// What happened to the placement.
  final OcptShotListSelectionCause cause;

  /// The id of the symbol or arrow it happened to.
  final String targetId;

  /// Class constructor
  const OcptShotListFloorPlanPlacementChangedEvent({required this.cause, required this.targetId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, cause, targetId];
}
