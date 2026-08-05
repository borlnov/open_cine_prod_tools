// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';

/// The events handled by `OcptBreakdownBloc`.
sealed class OcptBreakdownEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptBreakdownEvent();
}

/// Requests loading the current project's whole breakdown read: the screenplay text, the scenes
/// with their tags, and the three catalogues resolved into targets.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptBreakdownLoadRequestedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownLoadRequestedEvent();
}

/// Requests leaving the workspace: closes the current project and navigates back to the home page.
class OcptBreakdownBackRequestedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownBackRequestedEvent();
}

/// Reports that the project settings page was closed after changing something.
///
/// Re-reads the page setup the script view is typeset with: nothing in the snapshot itself depends
/// on the page format, but reloading it here too is what keeps this mode from being the one place a
/// change made on the project settings page is silently missed, mirroring
/// `OcptShotListBloc`'s own handler.
class OcptBreakdownProjectSettingsChangedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownProjectSettingsChangedEvent();
}

/// Selects scene [sceneId], dispatched by a row of `OcptBreakdownScenePanel` or by a heading row of
/// `OcptBreakdownScriptView`.
///
/// A scene id that no longer exists in the current snapshot (a stale click on a list rebuilt
/// underneath) is ignored rather than selecting nothing.
class OcptBreakdownSceneSelectedEvent extends OcptBreakdownEvent {
  /// The id of the scene to select.
  final String sceneId;

  /// Class constructor
  const OcptBreakdownSceneSelectedEvent({required this.sceneId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId];
}

/// Toggles the left (scene) dock's visibility.
class OcptBreakdownLeftPanelToggledEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownLeftPanelToggledEvent();
}

/// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens or
/// switches to it).
class OcptBreakdownRightDockTabSelectedEvent extends OcptBreakdownEvent {
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
class OcptBreakdownRightDockToggledEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownRightDockToggledEvent();
}

/// Closes the right dock via its own × close button.
class OcptBreakdownRightDockClosedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownRightDockClosedEvent();
}

/// Applies and persists whichever dock fraction the ended drag gesture reports.
///
/// Only one of [left]/[right] is ever non-null per event, mirroring how the shell's own
/// `onDockFractionsChanged` callback is shaped.
class OcptBreakdownDockFractionsChangedEvent extends OcptBreakdownEvent {
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
class OcptBreakdownDockLayoutResetEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownDockLayoutResetEvent();
}
