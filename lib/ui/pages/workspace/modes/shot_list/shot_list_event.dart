// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';

/// The events handled by `OcptShotListBloc`.
sealed class OcptShotListEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptShotListEvent();
}

/// Requests loading the current project's shot list, together with the persisted dock fractions,
/// visible columns and last right dock tab.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptShotListLoadRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListLoadRequestedEvent();
}

/// Selects the sequence [sequenceId], expanding it in the left dock and showing its shots in the
/// centre table.
///
/// Selecting a sequence other than the one already selected clears the selected shot: the table
/// now shows a different sequence's shots, none of which the previous selection belonged to.
class OcptShotListSequenceSelectedEvent extends OcptShotListEvent {
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
class OcptShotListShotSelectedEvent extends OcptShotListEvent {
  /// The id of the shot to select.
  final String shotId;

  /// Class constructor
  const OcptShotListShotSelectedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}

/// Requests creating a new shot at the end of the selected sequence, then selecting it.
///
/// Does nothing while no sequence is selected, or while the selected one is the orphan group: a
/// shot only ever exists inside a real screenplay scene, and the orphan group is where shots go
/// when their scene disappears, never where new ones are authored.
class OcptShotListShotCreationRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListShotCreationRequestedEvent();
}

/// Toggles the visibility of the left (sequences) dock.
class OcptShotListSequencePanelToggledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListSequencePanelToggledEvent();
}

/// Selects a tab of the right dock, dispatched by the dock's own tab row.
///
/// Follows the screenplay editor's toggle semantics exactly: selecting the tab already active
/// closes the dock, any other tab opens (or switches) it. Either way [tab] becomes
/// `OcptShotListState.lastRightDockTab`, the tab [OcptShotListRightDockToggledEvent] reopens the
/// dock on, and is persisted.
class OcptShotListRightDockTabSelectedEvent extends OcptShotListEvent {
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
class OcptShotListRightDockToggledEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListRightDockToggledEvent();
}

/// Closes the right dock via its own × close button, whichever tab is currently active.
class OcptShotListRightDockClosedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListRightDockClosedEvent();
}

/// Requests updating the mode's dock width fractions, persisting whichever of [left]/[right] is
/// given.
///
/// Dispatched once per drag gesture, on `onHorizontalDragEnd`, never per frame, exactly like the
/// screenplay editor's own equivalent.
class OcptShotListDockFractionsChangedEvent extends OcptShotListEvent {
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
class OcptShotListDockLayoutResetEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListDockLayoutResetEvent();
}

/// Shows or hides the optional table column [column], persisting the new set.
class OcptShotListColumnToggledEvent extends OcptShotListEvent {
  /// The optional column whose visibility is toggled.
  final OcptShotListColumn column;

  /// Class constructor
  const OcptShotListColumnToggledEvent({required this.column});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, column];
}

/// Dismisses the transient write error currently shown, if any.
class OcptShotListWriteErrorDismissedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListWriteErrorDismissedEvent();
}

/// Requests leaving the workspace and going back to the projects list.
///
/// The shot list has nothing to flush (every edit is written as it is made), so this only closes
/// the current project and navigates back through the router manager.
class OcptShotListBackRequestedEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListBackRequestedEvent();
}
