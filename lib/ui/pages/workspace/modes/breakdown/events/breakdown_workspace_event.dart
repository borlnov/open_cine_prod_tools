// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/events/breakdown_base_event.dart';

/// The events about the mode itself: loading, leaving, the docks, the legend, the centre and its search.
sealed class OcptBreakdownWorkspaceEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownWorkspaceEvent();
}

/// Requests leaving the workspace: closes the current project and navigates back to the home page.
class OcptBreakdownBackRequestedEvent extends OcptBreakdownWorkspaceEvent {
  /// Class constructor
  const OcptBreakdownBackRequestedEvent();
}

/// Reports that the project settings page was closed after changing something.
///
/// Re-reads the page setup the script view is typeset with: nothing in the snapshot itself depends
/// on the page format, but reloading it here too is what keeps this mode from being the one place a
/// change made on the project settings page is silently missed, mirroring
/// `OcptShotListBloc`'s own handler.
class OcptBreakdownProjectSettingsChangedEvent extends OcptBreakdownWorkspaceEvent {
  /// Class constructor
  const OcptBreakdownProjectSettingsChangedEvent();
}

/// Toggles the left (scene) dock's visibility.
class OcptBreakdownLeftPanelToggledEvent extends OcptBreakdownWorkspaceEvent {
  /// Class constructor
  const OcptBreakdownLeftPanelToggledEvent();
}

/// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens or
/// switches to it).
class OcptBreakdownRightDockTabSelectedEvent extends OcptBreakdownWorkspaceEvent {
  /// The tab to select.
  final OcptBreakdownRightDockTab tab;

  /// Class constructor
  const OcptBreakdownRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens on
/// its single tab.
class OcptBreakdownRightDockToggledEvent extends OcptBreakdownWorkspaceEvent {
  /// Class constructor
  const OcptBreakdownRightDockToggledEvent();
}

/// Closes the right dock via its own × close button.
class OcptBreakdownRightDockClosedEvent extends OcptBreakdownWorkspaceEvent {
  /// Class constructor
  const OcptBreakdownRightDockClosedEvent();
}

/// Applies and persists whichever dock fraction the ended drag gesture reports.
///
/// Only one of [left]/[right] is ever non-null per event, mirroring how the shell's own
/// `onDockFractionsChanged` callback is shaped.
class OcptBreakdownDockFractionsChangedEvent extends OcptBreakdownWorkspaceEvent {
  /// The left dock's new fraction, or null when the drag was on the right divider.
  final double? left;

  /// The right dock's new fraction, or null when the drag was on the left divider.
  final double? right;

  /// Class constructor
  const OcptBreakdownDockFractionsChangedEvent({required this.left, required this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Restores both dock fractions to their defaults, persisting them.
class OcptBreakdownDockLayoutResetEvent extends OcptBreakdownWorkspaceEvent {
  /// Class constructor
  const OcptBreakdownDockLayoutResetEvent();
}

/// Toggles whether legend key [key] is hidden from the script view's own highlighting, dispatched
/// by a row of `OcptBreakdownCategoryLegend`.
///
/// A reading aid for the pass in progress alone: the hidden set this event grows or shrinks is
/// never persisted, unlike the two dock fractions above.
class OcptBreakdownLegendEntryToggledEvent extends OcptBreakdownWorkspaceEvent {
  /// The legend key whose hidden state is toggled.
  final OcptBreakdownLegendKey key;

  /// Class constructor
  const OcptBreakdownLegendEntryToggledEvent({required this.key});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, key];
}

/// Reveals every legend key currently hidden from the script view's own highlighting, dispatched by
/// `OcptBreakdownCategoryLegend`'s own `Show all` action.
class OcptBreakdownLegendShowAllRequestedEvent extends OcptBreakdownWorkspaceEvent {
  /// Class constructor
  const OcptBreakdownLegendShowAllRequestedEvent();
}

/// Selects which of the two views (script or recap) the mode's centre shows, dispatched by the
/// header's own `Script`/`Recap` switch.
///
/// Clears any pending tag anchor and pending range: the popover a range interaction might be
/// driving has no script sheet left to close over once the centre leaves it — there is nothing to
/// close them on when the sheet is gone.
class OcptBreakdownCentreViewSelectedEvent extends OcptBreakdownWorkspaceEvent {
  /// The view to select.
  final OcptBreakdownCentreView view;

  /// Class constructor
  const OcptBreakdownCentreViewSelectedEvent({required this.view});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, view];
}

/// Records the header's own search field text as typed, dispatched on every keystroke.
///
/// The moment [query] turns non-empty while the script view is active, the bloc switches the
/// centre to the recap in the same emitted state — carrying the just-typed text into the view that
/// actually answers it — and clears any pending tag anchor and pending range, for the same reason
/// [OcptBreakdownCentreViewSelectedEvent] does. Clearing the field back to empty afterward does
/// **not** switch back to the script view: a user who read the recap and cleared the field to widen
/// it again is browsing the table, not asking to leave it.
class OcptBreakdownSearchQueryChangedEvent extends OcptBreakdownWorkspaceEvent {
  /// The field's raw text, as typed.
  final String query;

  /// Class constructor
  const OcptBreakdownSearchQueryChangedEvent({required this.query});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, query];
}
