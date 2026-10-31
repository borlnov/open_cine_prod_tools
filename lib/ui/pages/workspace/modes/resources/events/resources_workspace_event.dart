// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/events/resources_base_event.dart';

/// The events about workspace shell, selection and dock.
sealed class OcptResourcesWorkspaceEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesWorkspaceEvent();
}

/// Requests loading the current project's whole resources catalogue, together with the persisted
/// dock fractions.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptResourcesLoadRequestedEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesLoadRequestedEvent();
}

/// Requests leaving the workspace: flushes any pending field edit, closes the current project, and
/// navigates back to the home page.
class OcptResourcesBackRequestedEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesBackRequestedEvent();
}

/// Reports that the project settings page was closed after changing something.
class OcptResourcesProjectSettingsChangedEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesProjectSettingsChangedEvent();
}

/// Selects the left dock's tab [tab], dispatched by `OcptResourcesTabBar`.
///
/// Clears the selected person, role and location when [tab] actually differs from the one already
/// active: a tab switch shows a different list, none of whose rows the previous selection belonged
/// to.
class OcptResourcesTabSelectedEvent extends OcptResourcesWorkspaceEvent {
  /// The tab to select.
  final OcptResourcesTab tab;

  /// Class constructor
  const OcptResourcesTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Selects the person [personId], dispatched by a row of `OcptPeopleList`.
class OcptResourcesPersonSelectedEvent extends OcptResourcesWorkspaceEvent {
  /// The id of the person to select.
  final String personId;

  /// Class constructor
  const OcptResourcesPersonSelectedEvent({required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId];
}

/// Fired by the field-edit debounce timer `OcptResourcesPersonFieldChangedEvent` (re)starts, once
/// it elapses with no further edit. Not meant to be dispatched by a widget directly.
class OcptResourcesFieldEditFlushRequestedEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesFieldEditFlushRequestedEvent();
}

/// Selects role [roleId], dispatched by a row of `OcptRolesList`: the centre then shows that
/// role's `OcptRoleSheet`.
///
/// Selecting the already-selected role changes nothing, exactly as selecting a person twice does.
class OcptResourcesRoleSelectedEvent extends OcptResourcesWorkspaceEvent {
  /// The id of the role to select.
  final String roleId;

  /// Class constructor
  const OcptResourcesRoleSelectedEvent({required this.roleId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// Requests opening person [personId]'s sheet, dispatched by the role sheet's dedicated `↗`
/// affordance in the cast-member cell (a plain row click only *selects* the role).
///
/// Dispatched by the role sheet's cast member line and by the location sheet's contact line alike.
/// Flushes any pending field edit first, then switches the left dock to
/// [OcptResourcesTab.people] and selects [personId] in one state — deliberately **not** by
/// dispatching `OcptResourcesTabSelectedEvent`, which clears the selection on every tab change: the
/// sheet this event was asked to open would be deselected again in the very same frame.
class OcptResourcesPersonSheetOpenRequestedEvent extends OcptResourcesWorkspaceEvent {
  /// The id of the person whose sheet to open.
  final String personId;

  /// Class constructor
  const OcptResourcesPersonSheetOpenRequestedEvent({required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId];
}

/// Requests opening role [roleId]'s sheet, dispatched by the element sheet's `Roles concerned`
/// chips.
///
/// [OcptResourcesPersonSheetOpenRequestedEvent]'s sibling and follows it exactly: it switches the
/// left dock to [OcptResourcesTab.roles] and selects [roleId] in one state rather than dispatching
/// `OcptResourcesTabSelectedEvent`, which clears the selection on every tab change. This is a plain
/// tab-and-selection change **inside** the resources mode, so it carries no
/// `OcptWorkspaceRevealRequest`: the user is already here.
class OcptResourcesRoleSheetOpenRequestedEvent extends OcptResourcesWorkspaceEvent {
  /// The id of the role whose sheet to open.
  final String roleId;

  /// Class constructor
  const OcptResourcesRoleSheetOpenRequestedEvent({required this.roleId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// Selects location [locationId], dispatched by a row of `OcptLocationsList`: the centre then shows
/// that location's `OcptLocationSheet`.
class OcptResourcesLocationSelectedEvent extends OcptResourcesWorkspaceEvent {
  /// The id of the location to select.
  final String locationId;

  /// Class constructor
  const OcptResourcesLocationSelectedEvent({required this.locationId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Requests revealing set [setId]'s own floor plan in the shot list mode's floor plans view, on
/// its first linked sequence in screenplay order — the sets
/// card's own `Open in shot list` action.
///
/// Resolving the target sequence and episode needs a database read
/// (`OcptLocationsService.firstLinkedSceneOf`), which this event's own handler does before setting
/// `OcptResourcesState.pendingShotListReveal` — the mode reads it, dispatches the actual
/// cross-mode `OcptWorkspaceModeSelectedEvent` and reports it taken into account
/// ([OcptResourcesShotListRevealDismissedEvent]), exactly as `OcptShotListState
/// .pendingCharacterNamePromptSymbolId` is consumed.
class OcptResourcesOpenSetInShotListRequestedEvent extends OcptResourcesWorkspaceEvent {
  /// The id of the Resources set whose floor plan to reveal.
  final String setId;

  /// Class constructor
  const OcptResourcesOpenSetInShotListRequestedEvent({required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Reports that the mode has taken `OcptResourcesState.pendingShotListReveal` into account (it
/// dispatched the cross-mode switch it names), so it can be cleared and never re-dispatched on a
/// later rebuild.
class OcptResourcesShotListRevealDismissedEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesShotListRevealDismissedEvent();
}

/// Selects the element [elementId], dispatched by a row of `OcptElementsList`.
class OcptResourcesElementSelectedEvent extends OcptResourcesWorkspaceEvent {
  /// The id of the element to select.
  final String elementId;

  /// Class constructor
  const OcptResourcesElementSelectedEvent({required this.elementId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId];
}

/// Toggles the visibility of the left (list) dock.
class OcptResourcesLeftPanelToggledEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesLeftPanelToggledEvent();
}

/// Toggles whether the search field is shown, dispatched by the toolbar's search icon button.
///
/// Opening it also opens the left dock when it was closed — a field in a hidden dock would be a
/// toggle that does nothing — and closing it clears whatever was typed, so a hidden field can
/// never keep filtering a list nobody can see any more.
class OcptResourcesSearchToggledEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesSearchToggledEvent();
}

/// Records the text currently sitting in the search field, dispatched by
/// `OcptResourcesSearchField` on every keystroke.
///
/// Needs no debounce, unlike a sheet field's typed value: this writes nothing to the project
/// database, only to `OcptResourcesState.searchQuery`, so there is no write to spare by waiting
/// out a pause in typing.
class OcptResourcesSearchQueryChangedEvent extends OcptResourcesWorkspaceEvent {
  /// The text now sitting in the search field, exactly as typed.
  final String query;

  /// Class constructor
  const OcptResourcesSearchQueryChangedEvent({required this.query});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, query];
}

/// Selects a tab of the right dock, dispatched by the dock's own tab row. There being only one
/// tab, this either opens the dock on it or closes the dock, mirroring the shot list's own
/// select-the-active-tab-again-to-close semantics.
class OcptResourcesRightDockTabSelectedEvent extends OcptResourcesWorkspaceEvent {
  /// The tab whose label was clicked.
  final OcptResourcesRightDockTab tab;

  /// Class constructor
  const OcptResourcesRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock as a whole, dispatched by the workspace toolbar's right dock toggle: an
/// open dock closes, a closed one reopens on its single tab.
class OcptResourcesRightDockToggledEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesRightDockToggledEvent();
}

/// Closes the right dock via its own × close button.
class OcptResourcesRightDockClosedEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesRightDockClosedEvent();
}

/// Requests updating the mode's dock width fractions, persisting whichever of [left]/[right] is
/// given.
///
/// Dispatched once per drag gesture, on `onHorizontalDragEnd`, never per frame.
class OcptResourcesDockFractionsChangedEvent extends OcptResourcesWorkspaceEvent {
  /// The new left (list) dock fraction, or null to leave it unchanged.
  final double? left;

  /// The new right (versions) dock fraction, or null to leave it unchanged.
  final double? right;

  /// Class constructor
  const OcptResourcesDockFractionsChangedEvent({this.left, this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Requests restoring both dock fractions to their defaults ("Reset panel layout").
class OcptResourcesDockLayoutResetEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesDockLayoutResetEvent();
}

/// Dismisses the transient write error currently shown, if any.
class OcptResourcesWriteErrorDismissedEvent extends OcptResourcesWorkspaceEvent {
  /// Class constructor
  const OcptResourcesWriteErrorDismissedEvent();
}
