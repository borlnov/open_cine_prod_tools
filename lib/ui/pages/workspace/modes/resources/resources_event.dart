// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_unavailability_slot.dart';

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
/// Clears the selected person, role and location when [tab] actually differs from the one already
/// active: a tab switch shows a different list, none of whose rows the previous selection belonged
/// to.
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

  /// Class constructor
  const OcptResourcesPositionAddedEvent({
    required this.personId,
    required this.positionId,
    required this.customLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId, positionId, customLabel];
}

/// Updates position assignment [id]'s fields, written immediately, replacing both at once.
class OcptResourcesPositionUpdatedEvent extends OcptResourcesEvent {
  /// The id of the position assignment to update.
  final String id;

  /// The new stable position code, or empty when [customLabel] is used instead.
  final String positionId;

  /// The new free-text position label.
  final String customLabel;

  /// Class constructor
  const OcptResourcesPositionUpdatedEvent({
    required this.id,
    required this.positionId,
    required this.customLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, id, positionId, customLabel];
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

  /// The first date this unavailability covers.
  final DateTime startDate;

  /// The last date this unavailability covers, inclusive.
  final DateTime endDate;

  /// Which part of each covered day this unavailability takes.
  final OcptUnavailabilitySlot slot;

  /// The start of the window in minutes from midnight, or null unless [slot] is
  /// [OcptUnavailabilitySlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [slot] is
  /// [OcptUnavailabilitySlot.custom].
  final int? endMinute;

  /// Why this person is unavailable, free multi-line text.
  final String reason;

  /// Class constructor
  const OcptResourcesUnavailabilityAddedEvent({
    required this.personId,
    required this.startDate,
    required this.endDate,
    required this.slot,
    required this.startMinute,
    required this.endMinute,
    required this.reason,
  });

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    personId,
    startDate,
    endDate,
    slot,
    startMinute,
    endMinute,
    reason,
  ];
}

/// Updates unavailability [id]'s fields, written immediately, replacing all of them at once.
class OcptResourcesUnavailabilityUpdatedEvent extends OcptResourcesEvent {
  /// The id of the unavailability to update.
  final String id;

  /// The new first date.
  final DateTime startDate;

  /// The new last date, inclusive.
  final DateTime endDate;

  /// The new slot within each covered day.
  final OcptUnavailabilitySlot slot;

  /// The new window start in minutes from midnight, or null unless [slot] is
  /// [OcptUnavailabilitySlot.custom].
  final int? startMinute;

  /// The new window end in minutes from midnight, or null unless [slot] is
  /// [OcptUnavailabilitySlot.custom].
  final int? endMinute;

  /// The new reason.
  final String reason;

  /// Class constructor
  const OcptResourcesUnavailabilityUpdatedEvent({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.slot,
    required this.startMinute,
    required this.endMinute,
    required this.reason,
  });

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    id,
    startDate,
    endDate,
    slot,
    startMinute,
    endMinute,
    reason,
  ];
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

/// Selects role [roleId], dispatched by a row of `OcptRolesList`: the centre then shows that
/// role's `OcptRoleSheet`.
///
/// Selecting the already-selected role changes nothing, exactly as selecting a person twice does.
class OcptResourcesRoleSelectedEvent extends OcptResourcesEvent {
  /// The id of the role to select.
  final String roleId;

  /// Class constructor
  const OcptResourcesRoleSelectedEvent({required this.roleId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// Requests adding a hand-added role of [kind] at the end of the cast, then selecting it: the
/// left dock's `+ Add a role` action, offering `silent` and `extra` (never `speaking`, which only
/// `OcptRoleIndexService.reconcile` ever creates).
class OcptResourcesRoleCreationRequestedEvent extends OcptResourcesEvent {
  /// The kind of the role to create, never [OcptRoleKind.speaking].
  final OcptRoleKind kind;

  /// Class constructor
  const OcptResourcesRoleCreationRequestedEvent({required this.kind});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, kind];
}

/// Records the raw text just typed into [field] of role [roleId], dispatched by the role sheet on
/// every keystroke.
///
/// Rides the same field-edit autosave debounce as `OcptResourcesPersonFieldChangedEvent`: the
/// typed value becomes visible immediately as a pending edit in
/// `OcptResourcesState.pendingRoleFieldEdits`, and (re)starts the debounce that eventually writes
/// it.
class OcptResourcesRoleFieldChangedEvent extends OcptResourcesEvent {
  /// The id of the role whose field was edited.
  final String roleId;

  /// The field edited.
  final OcptRoleField field;

  /// The raw text now sitting in the field, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptResourcesRoleFieldChangedEvent({
    required this.roleId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId, field, rawValue];
}

/// Casts person [personId] to role [roleId] (or uncasts it, when [personId] is null), written
/// immediately: picking a cast member from a menu is a single discrete action, not typing.
class OcptResourcesRoleCastChangedEvent extends OcptResourcesEvent {
  /// The id of the role being cast.
  final String roleId;

  /// The id of the person now cast in this role, or null to uncast it.
  final String? personId;

  /// Class constructor
  const OcptResourcesRoleCastChangedEvent({required this.roleId, required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId, personId];
}

/// Sets role [roleId]'s kind to [kind], written immediately: picking a kind from a menu is a
/// single discrete action, not typing.
class OcptResourcesRoleKindChangedEvent extends OcptResourcesEvent {
  /// The id of the role whose kind changed.
  final String roleId;

  /// The new kind.
  final OcptRoleKind kind;

  /// Class constructor
  const OcptResourcesRoleKindChangedEvent({required this.roleId, required this.kind});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId, kind];
}

/// Requests deleting role [roleId]: the role sheet's own delete action. Tombstones the role,
/// clears the selection when it was the selected role, and drops any pending field edit that
/// still targeted it.
class OcptResourcesRoleDeletionRequestedEvent extends OcptResourcesEvent {
  /// The id of the role to delete.
  final String roleId;

  /// Class constructor
  const OcptResourcesRoleDeletionRequestedEvent({required this.roleId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// The removed-role banner's "keep it" action for role [roleId]: it stops being owned by
/// `OcptRoleIndexService.reconcile` and becomes a hand-added `silent` role, its casting and notes
/// untouched.
class OcptResourcesOrphanedRoleKeptEvent extends OcptResourcesEvent {
  /// The id of the orphaned role to keep.
  final String roleId;

  /// Class constructor
  const OcptResourcesOrphanedRoleKeptEvent({required this.roleId});

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
class OcptResourcesPersonSheetOpenRequestedEvent extends OcptResourcesEvent {
  /// The id of the person whose sheet to open.
  final String personId;

  /// Class constructor
  const OcptResourcesPersonSheetOpenRequestedEvent({required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, personId];
}

/// Selects location [locationId], dispatched by a row of `OcptLocationsList`: the centre then shows
/// that location's `OcptLocationSheet`.
class OcptResourcesLocationSelectedEvent extends OcptResourcesEvent {
  /// The id of the location to select.
  final String locationId;

  /// Class constructor
  const OcptResourcesLocationSelectedEvent({required this.locationId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Requests creating a new, blank location at the end of the list, then selecting it: the left
/// dock's `+ Add a location` action.
class OcptResourcesLocationCreationRequestedEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesLocationCreationRequestedEvent();
}

/// Requests deleting location [locationId], dispatched once the sheet's inline confirmation has
/// already been answered. Clears the selection when it was the selected location, and drops any
/// pending field edit that still targeted it or one of its sets.
class OcptResourcesLocationDeletionRequestedEvent extends OcptResourcesEvent {
  /// The id of the location to delete.
  final String locationId;

  /// Class constructor
  const OcptResourcesLocationDeletionRequestedEvent({required this.locationId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Records the raw text just typed into [field] of location [locationId], dispatched by the
/// location sheet on every keystroke.
///
/// Rides the same field-edit autosave debounce as `OcptResourcesPersonFieldChangedEvent`.
class OcptResourcesLocationFieldChangedEvent extends OcptResourcesEvent {
  /// The id of the location whose field was edited.
  final String locationId;

  /// The field edited.
  final OcptLocationField field;

  /// The raw text now sitting in the field, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptResourcesLocationFieldChangedEvent({
    required this.locationId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId, field, rawValue];
}

/// Sets location [locationId]'s colour to `ocptCoveragePalette[colorIndex]`, written immediately:
/// picking a swatch is a single discrete action, not typing.
class OcptResourcesLocationColorChangedEvent extends OcptResourcesEvent {
  /// The id of the location whose colour changed.
  final String locationId;

  /// The new colour index.
  final int colorIndex;

  /// Class constructor
  const OcptResourcesLocationColorChangedEvent({
    required this.locationId,
    required this.colorIndex,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId, colorIndex];
}

/// Sets location [locationId]'s filming permit status to [status], written immediately.
class OcptResourcesLocationPermitStatusChangedEvent extends OcptResourcesEvent {
  /// The id of the location whose permit status changed.
  final String locationId;

  /// The new status.
  final OcptPermitStatus status;

  /// Class constructor
  const OcptResourcesLocationPermitStatusChangedEvent({
    required this.locationId,
    required this.status,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId, status];
}

/// Sets the date location [locationId]'s permit status last changed to [date] (or clears it, when
/// null), written immediately.
class OcptResourcesLocationPermitDateChangedEvent extends OcptResourcesEvent {
  /// The id of the location whose permit date changed.
  final String locationId;

  /// The new date, or null to clear it.
  final DateTime? date;

  /// Class constructor
  const OcptResourcesLocationPermitDateChangedEvent({
    required this.locationId,
    required this.date,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId, date];
}

/// Sets who to contact about location [locationId] to person [personId] (or clears it, when null),
/// written immediately: picking a person from a menu is a single discrete action, not typing.
class OcptResourcesLocationContactChangedEvent extends OcptResourcesEvent {
  /// The id of the location whose contact changed.
  final String locationId;

  /// The id of the person to contact, or null to clear it.
  final String? personId;

  /// Class constructor
  const OcptResourcesLocationContactChangedEvent({
    required this.locationId,
    required this.personId,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId, personId];
}

/// Adds a new, blank set at the end of location [locationId]'s sets, written immediately.
class OcptResourcesSetAddedEvent extends OcptResourcesEvent {
  /// The id of the location the set is added to.
  final String locationId;

  /// Class constructor
  const OcptResourcesSetAddedEvent({required this.locationId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Records the raw text just typed into [field] of set [setId], dispatched by the location sheet's
/// sets card on every keystroke. Rides the same debounce as every other typed field of the mode.
class OcptResourcesSetFieldChangedEvent extends OcptResourcesEvent {
  /// The id of the set whose field was edited.
  final String setId;

  /// The field edited.
  final OcptSetField field;

  /// The raw text now sitting in the field, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptResourcesSetFieldChangedEvent({
    required this.setId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId, field, rawValue];
}

/// Removes set [setId] and the scene links onto it, written immediately.
class OcptResourcesSetRemovedEvent extends OcptResourcesEvent {
  /// The id of the set to remove.
  final String setId;

  /// Class constructor
  const OcptResourcesSetRemovedEvent({required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Says scene [sceneId] is shot in set [setId], written immediately.
///
/// A scene is shot in one set, so this **moves** the scene when it already sat in another one (see
/// `OcptLocationsService.assignSceneToSet`) — including from a set of another location, which is
/// exactly what repairing a mis-assignment looks like.
class OcptResourcesSceneAssignedToSetEvent extends OcptResourcesEvent {
  /// The id of the scene being assigned.
  final String sceneId;

  /// The id of the set it is shot in.
  final String setId;

  /// Class constructor
  const OcptResourcesSceneAssignedToSetEvent({required this.sceneId, required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId, setId];
}

/// Says scene [sceneId] is no longer shot in set [setId], leaving it with no set at all, written
/// immediately.
class OcptResourcesSceneRemovedFromSetEvent extends OcptResourcesEvent {
  /// The id of the scene being unassigned.
  final String sceneId;

  /// The id of the set it is no longer shot in.
  final String setId;

  /// Class constructor
  const OcptResourcesSceneRemovedFromSetEvent({required this.sceneId, required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId, setId];
}

/// Requests referencing a scouting photo for location [locationId]: opens the native file picker
/// and, if a file is picked, stores its path.
///
/// [fileTypeLabel] is the localized label the native dialog names its type filter with, travelling
/// on the event exactly as an export's does — no manager or service of this app ever sees a `Tr`.
class OcptResourcesLocationPhotoAddRequestedEvent extends OcptResourcesEvent {
  /// The id of the location the photo is referenced for.
  final String locationId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptResourcesLocationPhotoAddRequestedEvent({
    required this.locationId,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId, fileTypeLabel];
}

/// Requests referencing location [locationId]'s filming permit document, replacing whichever one it
/// referenced before. See [OcptResourcesLocationPhotoAddRequestedEvent] for [fileTypeLabel].
class OcptResourcesPermitDocumentPickRequestedEvent extends OcptResourcesEvent {
  /// The id of the location the document is referenced for.
  final String locationId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptResourcesPermitDocumentPickRequestedEvent({
    required this.locationId,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId, fileTypeLabel];
}

/// Drops location [locationId]'s reference to its permit document. The file itself is never
/// touched.
class OcptResourcesPermitDocumentClearedEvent extends OcptResourcesEvent {
  /// The id of the location whose permit document reference is dropped.
  final String locationId;

  /// Class constructor
  const OcptResourcesPermitDocumentClearedEvent({required this.locationId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Drops the asset reference [assetId] — a scouting photo. The file itself is never touched.
class OcptResourcesAssetRemovedEvent extends OcptResourcesEvent {
  /// The id of the asset reference to drop.
  final String assetId;

  /// Class constructor
  const OcptResourcesAssetRemovedEvent({required this.assetId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, assetId];
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
