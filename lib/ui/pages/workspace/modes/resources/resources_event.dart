// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_half_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';

/// The events handled by `OcptResourcesBloc`.
sealed class OcptResourcesEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptResourcesEvent();
}

/// Requests loading the current project's whole resources catalogue, together with the persisted
/// dock fractions.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptResourcesLoadRequestedEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesLoadRequestedEvent();
}

/// Requests leaving the workspace: flushes any pending field edit, closes the current project, and
/// navigates back to the home page.
class OcptResourcesBackRequestedEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesBackRequestedEvent();
}

/// Selects the left dock's tab [tab], dispatched by `OcptResourcesTabBar`.
///
/// Clears the selected person when [tab] actually differs from the one already active: a tab
/// switch shows a different list, none of whose rows the previous selection belonged to (and only
/// [OcptResourcesTab.people] has a selectable row at all, this milestone).
class OcptResourcesTabSelectedEvent extends OcptResourcesEvent {
  /// The tab to select.
  final OcptResourcesTab tab;

  /// Class constructor
  const OcptResourcesTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Selects the person [personId], dispatched by a row of `OcptPeopleList`.
class OcptResourcesPersonSelectedEvent extends OcptResourcesEvent {
  /// The id of the person to select.
  final String personId;

  /// Class constructor
  const OcptResourcesPersonSelectedEvent({required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId];
}

/// Requests creating a new, blank person at the end of the address book, then selecting it: the
/// left dock's `+ Add a person` action.
class OcptResourcesPersonCreationRequestedEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesPersonCreationRequestedEvent();
}

/// Requests erasing person [personId], dispatched once `OcptPersonDeleteConfirmDialog` has already
/// confirmed it. Clears the selection when [personId] was the selected person, and drops any
/// pending field edit that still targeted it.
class OcptResourcesPersonDeletionRequestedEvent extends OcptResourcesEvent {
  /// The id of the person to erase.
  final String personId;

  /// Class constructor
  const OcptResourcesPersonDeletionRequestedEvent({required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId];
}

/// Records the raw text just typed into [field] of person [personId], dispatched by the person
/// sheet on every keystroke.
///
/// The typed value becomes visible immediately as a pending edit in
/// `OcptResourcesState.pendingFieldEdits`, and (re)starts the field-edit autosave debounce that
/// eventually writes it, unless something flushes it sooner (selecting another person or tab,
/// leaving the workspace, or the mode itself leaving the widget tree).
class OcptResourcesPersonFieldChangedEvent extends OcptResourcesEvent {
  /// The id of the person whose field was edited.
  final String personId;

  /// The field edited.
  final OcptPersonField field;

  /// The raw text now sitting in the field, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptResourcesPersonFieldChangedEvent({
    required this.personId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, field, rawValue];
}

/// Fired by the field-edit debounce timer `OcptResourcesPersonFieldChangedEvent` (re)starts, once
/// it elapses with no further edit. Not meant to be dispatched by a widget directly.
class OcptResourcesFieldEditFlushRequestedEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesFieldEditFlushRequestedEvent();
}

/// Sets person [personId]'s avatar colour to `ocptCoveragePalette[colorIndex]`, written
/// immediately: picking a swatch is a single discrete action, not typing.
class OcptResourcesPersonColorChangedEvent extends OcptResourcesEvent {
  /// The id of the person whose colour changed.
  final String personId;

  /// The new colour index.
  final int colorIndex;

  /// Class constructor
  const OcptResourcesPersonColorChangedEvent({required this.personId, required this.colorIndex});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, colorIndex];
}

/// Sets person [personId]'s date of birth to [date] (or clears it, when null), written
/// immediately: picking a date is a single discrete action, not typing.
class OcptResourcesPersonBirthDateChangedEvent extends OcptResourcesEvent {
  /// The id of the person whose date of birth changed.
  final String personId;

  /// The new date of birth, or null to clear it.
  final DateTime? date;

  /// Class constructor
  const OcptResourcesPersonBirthDateChangedEvent({required this.personId, required this.date});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, date];
}

/// Sets whether person [personId] can travel to set on their own, written immediately: a tri-state
/// toggle (unknown/yes/no) is a single discrete action, not typing.
class OcptResourcesPersonTransportAutonomyChangedEvent extends OcptResourcesEvent {
  /// The id of the person whose transport autonomy changed.
  final String personId;

  /// The new value: true, false, or null for "not asked yet".
  final bool? isTransportAutonomous;

  /// Class constructor
  const OcptResourcesPersonTransportAutonomyChangedEvent({
    required this.personId,
    required this.isTransportAutonomous,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, isTransportAutonomous];
}

/// Sets person [personId]'s image rights status to [status], written immediately: picking a status
/// is a single discrete action, not typing.
class OcptResourcesPersonImageRightsStatusChangedEvent extends OcptResourcesEvent {
  /// The id of the person whose image rights status changed.
  final String personId;

  /// The new status.
  final OcptImageRightsStatus status;

  /// Class constructor
  const OcptResourcesPersonImageRightsStatusChangedEvent({
    required this.personId,
    required this.status,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, status];
}

/// Sets the date person [personId]'s image rights status last changed to [date] (or clears it,
/// when null), written immediately: picking a date is a single discrete action, not typing.
class OcptResourcesPersonImageRightsDateChangedEvent extends OcptResourcesEvent {
  /// The id of the person whose image rights date changed.
  final String personId;

  /// The new date, or null to clear it.
  final DateTime? date;

  /// Class constructor
  const OcptResourcesPersonImageRightsDateChangedEvent({
    required this.personId,
    required this.date,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, date];
}

/// Adds a crew position assignment to person [personId], written immediately.
class OcptResourcesPositionAddedEvent extends OcptResourcesEvent {
  /// The id of the person the position is added to.
  final String personId;

  /// The stable code of the position, from `ocptCrewPositions`, or empty when [customLabel] is
  /// used instead.
  final String positionId;

  /// A free-text position label, used instead of [positionId] when the catalogue has nothing that
  /// fits.
  final String customLabel;

  /// Free text describing when this assignment applies.
  final String scopeNotes;

  /// Class constructor
  const OcptResourcesPositionAddedEvent({
    required this.personId,
    required this.positionId,
    required this.customLabel,
    required this.scopeNotes,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, positionId, customLabel, scopeNotes];
}

/// Updates position assignment [id]'s fields, written immediately, replacing all three at once.
class OcptResourcesPositionUpdatedEvent extends OcptResourcesEvent {
  /// The id of the position assignment to update.
  final String id;

  /// The new stable position code, or empty when [customLabel] is used instead.
  final String positionId;

  /// The new free-text position label.
  final String customLabel;

  /// The new scope notes.
  final String scopeNotes;

  /// Class constructor
  const OcptResourcesPositionUpdatedEvent({
    required this.id,
    required this.positionId,
    required this.customLabel,
    required this.scopeNotes,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id, positionId, customLabel, scopeNotes];
}

/// Removes position assignment [id], written immediately.
class OcptResourcesPositionRemovedEvent extends OcptResourcesEvent {
  /// The id of the position assignment to remove.
  final String id;

  /// Class constructor
  const OcptResourcesPositionRemovedEvent({required this.id});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id];
}

/// Adds a skill to person [personId], written immediately.
class OcptResourcesSkillAddedEvent extends OcptResourcesEvent {
  /// The id of the person the skill is added to.
  final String personId;

  /// The skill itself, free text.
  final String label;

  /// Class constructor
  const OcptResourcesSkillAddedEvent({required this.personId, required this.label});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, label];
}

/// Updates skill [id]'s label, written immediately.
class OcptResourcesSkillUpdatedEvent extends OcptResourcesEvent {
  /// The id of the skill to update.
  final String id;

  /// The new label.
  final String label;

  /// Class constructor
  const OcptResourcesSkillUpdatedEvent({required this.id, required this.label});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id, label];
}

/// Removes skill [id], written immediately.
class OcptResourcesSkillRemovedEvent extends OcptResourcesEvent {
  /// The id of the skill to remove.
  final String id;

  /// Class constructor
  const OcptResourcesSkillRemovedEvent({required this.id});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id];
}

/// Adds an unavailability to person [personId], written immediately.
class OcptResourcesUnavailabilityAddedEvent extends OcptResourcesEvent {
  /// The id of the person the unavailability is added to.
  final String personId;

  /// The date this unavailability covers.
  final DateTime date;

  /// How much of [date] this unavailability covers.
  final OcptHalfDay halfDay;

  /// Why this person is unavailable, free text.
  final String reason;

  /// Class constructor
  const OcptResourcesUnavailabilityAddedEvent({
    required this.personId,
    required this.date,
    required this.halfDay,
    required this.reason,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, date, halfDay, reason];
}

/// Updates unavailability [id]'s fields, written immediately, replacing all three at once.
class OcptResourcesUnavailabilityUpdatedEvent extends OcptResourcesEvent {
  /// The id of the unavailability to update.
  final String id;

  /// The new date.
  final DateTime date;

  /// The new half-day coverage.
  final OcptHalfDay halfDay;

  /// The new reason.
  final String reason;

  /// Class constructor
  const OcptResourcesUnavailabilityUpdatedEvent({
    required this.id,
    required this.date,
    required this.halfDay,
    required this.reason,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id, date, halfDay, reason];
}

/// Removes unavailability [id], written immediately.
class OcptResourcesUnavailabilityRemovedEvent extends OcptResourcesEvent {
  /// The id of the unavailability to remove.
  final String id;

  /// Class constructor
  const OcptResourcesUnavailabilityRemovedEvent({required this.id});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id];
}

/// Toggles the visibility of the left (list) dock.
class OcptResourcesLeftPanelToggledEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesLeftPanelToggledEvent();
}

/// Selects a tab of the right dock, dispatched by the dock's own tab row. There being only one
/// tab, this either opens the dock on it or closes the dock, mirroring the shot list's own
/// select-the-active-tab-again-to-close semantics.
class OcptResourcesRightDockTabSelectedEvent extends OcptResourcesEvent {
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
class OcptResourcesRightDockToggledEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesRightDockToggledEvent();
}

/// Closes the right dock via its own × close button.
class OcptResourcesRightDockClosedEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesRightDockClosedEvent();
}

/// Requests updating the mode's dock width fractions, persisting whichever of [left]/[right] is
/// given.
///
/// Dispatched once per drag gesture, on `onHorizontalDragEnd`, never per frame.
class OcptResourcesDockFractionsChangedEvent extends OcptResourcesEvent {
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
class OcptResourcesDockLayoutResetEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesDockLayoutResetEvent();
}

/// Dismisses the transient write error currently shown, if any.
class OcptResourcesWriteErrorDismissedEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesWriteErrorDismissedEvent();
}
