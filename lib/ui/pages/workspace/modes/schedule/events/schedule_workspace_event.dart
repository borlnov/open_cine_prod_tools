// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/events/schedule_base_event.dart';

/// The events about the mode itself: loading, leaving, the docks and the centre.
sealed class OcptScheduleWorkspaceEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleWorkspaceEvent();
}

/// Requests loading the current project's whole schedule read: the days with their slots, crew,
/// cast and blocks, the shot list (for the shots still to place and every placed block's own
/// label) and the resources catalogues (locations, roles, people) the inspector and the slot/cast
/// pickers read.
///
/// Dispatched once by the bloc's own constructor; it isn't meant to be sent by a widget.
class OcptScheduleLoadRequestedEvent extends OcptScheduleWorkspaceEvent {
  /// Class constructor
  const OcptScheduleLoadRequestedEvent();
}

/// Requests leaving the workspace: closes the current project and navigates back to the home page.
class OcptScheduleBackRequestedEvent extends OcptScheduleWorkspaceEvent {
  /// Class constructor
  const OcptScheduleBackRequestedEvent();
}

/// Toggles the left (days) dock's visibility.
class OcptScheduleLeftPanelToggledEvent extends OcptScheduleWorkspaceEvent {
  /// Class constructor
  const OcptScheduleLeftPanelToggledEvent();
}

/// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens or
/// switches to it).
class OcptScheduleRightDockTabSelectedEvent extends OcptScheduleWorkspaceEvent {
  /// The tab to select.
  final OcptScheduleRightDockTab tab;

  /// Class constructor
  const OcptScheduleRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens on
/// its last tab.
class OcptScheduleRightDockToggledEvent extends OcptScheduleWorkspaceEvent {
  /// Class constructor
  const OcptScheduleRightDockToggledEvent();
}

/// Closes the right dock via its own × close button.
class OcptScheduleRightDockClosedEvent extends OcptScheduleWorkspaceEvent {
  /// Class constructor
  const OcptScheduleRightDockClosedEvent();
}

/// Applies whichever dock fraction the ended drag gesture reports.
///
/// Only one of [left]/[right] is ever non-null per event, mirroring how the shell's own
/// `onDockFractionsChanged` callback is shaped. The bloc persists the fractions through
/// `OcptPropertiesManager` (see `OcptScheduleBloc`'s own doc comment).
class OcptScheduleDockFractionsChangedEvent extends OcptScheduleWorkspaceEvent {
  /// The left dock's new fraction, or null when the drag was on the right divider.
  final double? left;

  /// The right dock's new fraction, or null when the drag was on the left divider.
  final double? right;

  /// Class constructor
  const OcptScheduleDockFractionsChangedEvent({required this.left, required this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Restores both dock fractions to their defaults.
class OcptScheduleDockLayoutResetEvent extends OcptScheduleWorkspaceEvent {
  /// Class constructor
  const OcptScheduleDockLayoutResetEvent();
}

/// Selects which of the two centre views (agenda or day) the mode shows, dispatched by the
/// header's own `Agenda`/`Day` switch.
class OcptScheduleCentreViewSelectedEvent extends OcptScheduleWorkspaceEvent {
  /// The view to select.
  final OcptScheduleCentreView view;

  /// Class constructor
  const OcptScheduleCentreViewSelectedEvent({required this.view});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, view];
}

/// Selects which of the three agenda presentations is shown, dispatched by the header's own
/// segmented control.
class OcptScheduleAgendaModeSelectedEvent extends OcptScheduleWorkspaceEvent {
  /// The presentation to select.
  final OcptScheduleAgendaMode mode;

  /// Class constructor
  const OcptScheduleAgendaModeSelectedEvent({required this.mode});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, mode];
}

/// Selects what fact the agenda tints a day with, dispatched by the header's own "Colour by"
/// segmented control.
class OcptScheduleAgendaColorModeSelectedEvent extends OcptScheduleWorkspaceEvent {
  /// The colour mode to select.
  final OcptScheduleAgendaColorMode mode;

  /// Class constructor
  const OcptScheduleAgendaColorModeSelectedEvent({required this.mode});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, mode];
}

/// Pages the week/month agenda to [date], dispatched by the week/month presentation's own
/// previous/next/today controls, once built. The new anchor date only, since it is the week or the
/// month **containing** [date] that is shown next — resolving that from the current
/// `OcptScheduleAgendaMode` is the widget's own job, not this event's.
class OcptScheduleAgendaAnchorDateChangedEvent extends OcptScheduleWorkspaceEvent {
  /// The date the week/month agenda now anchors on.
  final DateTime date;

  /// Class constructor
  const OcptScheduleAgendaAnchorDateChangedEvent({required this.date});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, date];
}

/// Re-reads the page setup after the project settings page changed something, so the three export
/// dialogs pre-fill from the page format actually in effect — mirrors `OcptShotListBloc`'s own
/// handler for the very same reason.
class OcptScheduleProjectSettingsChangedEvent extends OcptScheduleWorkspaceEvent {
  /// Class constructor
  const OcptScheduleProjectSettingsChangedEvent();
}
