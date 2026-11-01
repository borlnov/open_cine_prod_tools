// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/events/resources_base_event.dart';

/// The events about locations and their sets.
sealed class OcptResourcesLocationsEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesLocationsEvent();
}

/// Requests creating a new, blank location at the end of the list, then selecting it: the left
/// dock's `+ Add a location` action.
class OcptResourcesLocationCreationRequestedEvent extends OcptResourcesLocationsEvent {
  /// Class constructor
  const OcptResourcesLocationCreationRequestedEvent();
}

/// Requests deleting location [locationId], dispatched once `OcptResourcesDeleteConfirmDialog` has
/// already confirmed it. Clears the selection when it was the selected location, and drops any
/// pending field edit that still targeted it or one of its sets.
class OcptResourcesLocationDeletionRequestedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location to delete.
  final String locationId;

  /// Class constructor
  const OcptResourcesLocationDeletionRequestedEvent({required this.locationId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Records the raw text just typed into [field] of location [locationId], dispatched by the
/// location sheet on every keystroke.
///
/// Rides the same field-edit autosave debounce as `OcptResourcesPersonFieldChangedEvent`.
class OcptResourcesLocationFieldChangedEvent extends OcptResourcesLocationsEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId, field, rawValue];
}

/// Sets location [locationId]'s colour to `ocptCoveragePalette[colorIndex]`, written immediately:
/// picking a swatch is a single discrete action, not typing.
class OcptResourcesLocationColorChangedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location whose colour changed.
  final String locationId;

  /// The new colour index.
  final int colorIndex;

  /// Class constructor
  const OcptResourcesLocationColorChangedEvent({
    required this.locationId,
    required this.colorIndex,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId, colorIndex];
}

/// Sets location [locationId]'s filming permit status to [status], written immediately.
class OcptResourcesLocationPermitStatusChangedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location whose permit status changed.
  final String locationId;

  /// The new status.
  final OcptPermitStatus status;

  /// Class constructor
  const OcptResourcesLocationPermitStatusChangedEvent({
    required this.locationId,
    required this.status,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId, status];
}

/// Sets the date location [locationId]'s permit status last changed to [date] (or clears it, when
/// null), written immediately.
class OcptResourcesLocationPermitDateChangedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location whose permit date changed.
  final String locationId;

  /// The new date, or null to clear it.
  final DateTime? date;

  /// Class constructor
  const OcptResourcesLocationPermitDateChangedEvent({required this.locationId, required this.date});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId, date];
}

/// Sets who to contact about location [locationId] to person [personId] (or clears it, when null),
/// written immediately: picking a person from a menu is a single discrete action, not typing.
class OcptResourcesLocationContactChangedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location whose contact changed.
  final String locationId;

  /// The id of the person to contact, or null to clear it.
  final String? personId;

  /// Class constructor
  const OcptResourcesLocationContactChangedEvent({
    required this.locationId,
    required this.personId,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId, personId];
}

/// Adds a new, blank set at the end of location [locationId]'s sets, written immediately.
class OcptResourcesSetAddedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location the set is added to.
  final String locationId;

  /// Class constructor
  const OcptResourcesSetAddedEvent({required this.locationId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Records the raw text just typed into [field] of set [setId], dispatched by the location sheet's
/// sets card on every keystroke. Rides the same debounce as every other typed field of the mode.
class OcptResourcesSetFieldChangedEvent extends OcptResourcesLocationsEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId, field, rawValue];
}

/// Removes set [setId] and the scene links onto it, written immediately.
class OcptResourcesSetRemovedEvent extends OcptResourcesLocationsEvent {
  /// The id of the set to remove.
  final String setId;

  /// Class constructor
  const OcptResourcesSetRemovedEvent({required this.setId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Moves set [setId] to location [locationId], written immediately.
///
/// The set leaves the sheet it was being edited on — that is what a move is — taking its code, its
/// notes and its scenes with it (`OcptLocationsService.moveSetToLocation`).
class OcptResourcesSetLocationChangedEvent extends OcptResourcesLocationsEvent {
  /// The id of the set being moved.
  final String setId;

  /// The id of the location it now belongs to.
  final String locationId;

  /// Class constructor
  const OcptResourcesSetLocationChangedEvent({required this.setId, required this.locationId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId, locationId];
}

/// Says scene [sceneId] is shot in set [setId], written immediately.
///
/// A scene may be shot in several sets, so this **adds** to whatever sets it already has (see
/// `OcptLocationsService.assignSceneToSet`) rather than moving it — a mis-assignment is repaired by
/// dropping the wrong set from its own chip, which says so explicitly.
class OcptResourcesSceneAssignedToSetEvent extends OcptResourcesLocationsEvent {
  /// The id of the scene being assigned.
  final String sceneId;

  /// The id of the set it is shot in.
  final String setId;

  /// Class constructor
  const OcptResourcesSceneAssignedToSetEvent({required this.sceneId, required this.setId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sceneId, setId];
}

/// Says scene [sceneId] is no longer shot in set [setId], leaving the other sets it is shot in
/// alone, written immediately.
class OcptResourcesSceneRemovedFromSetEvent extends OcptResourcesLocationsEvent {
  /// The id of the scene being unassigned.
  final String sceneId;

  /// The id of the set it is no longer shot in.
  final String setId;

  /// Class constructor
  const OcptResourcesSceneRemovedFromSetEvent({required this.sceneId, required this.setId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sceneId, setId];
}

/// Requests referencing a scouting photo for location [locationId]: opens the native file picker
/// and, if a file is picked, stores its path.
///
/// [fileTypeLabel] is the localized label the native dialog names its type filter with, travelling
/// on the event exactly as an export's does — no manager or service of this app ever sees a `Tr`.
class OcptResourcesLocationPhotoAddRequestedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location the photo is referenced for.
  final String locationId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptResourcesLocationPhotoAddRequestedEvent({
    required this.locationId,
    required this.fileTypeLabel,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId, fileTypeLabel];
}

/// Requests referencing location [locationId]'s filming permit document, replacing whichever one it
/// referenced before. See [OcptResourcesLocationPhotoAddRequestedEvent] for [fileTypeLabel].
class OcptResourcesPermitDocumentPickRequestedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location the document is referenced for.
  final String locationId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptResourcesPermitDocumentPickRequestedEvent({
    required this.locationId,
    required this.fileTypeLabel,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId, fileTypeLabel];
}

/// Drops location [locationId]'s reference to its permit document. The file itself is never
/// touched.
class OcptResourcesPermitDocumentClearedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location whose permit document reference is dropped.
  final String locationId;

  /// Class constructor
  const OcptResourcesPermitDocumentClearedEvent({required this.locationId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Sets the date asset [assetId]'s document — a filming permit, so far the only document this
/// dates — becomes valid to [date] (or clears it, when null), written immediately: picking a date
/// is a single discrete action, not typing.
///
/// One event per date, mirroring [OcptResourcesLocationPermitDateChangedEvent] and
/// `OcptResourcesPersonImageRightsDateChangedEvent` rather than one event naming which of the two
/// changed: every other date field of this mode already reads this way, and a discriminated event
/// would be a second shape for what is, from every neighbouring event's own point of view, one
/// more single-date field.
class OcptResourcesAssetValidFromChangedEvent extends OcptResourcesLocationsEvent {
  /// The id of the asset whose validity window changed.
  final String assetId;

  /// The new date, or null to clear it.
  final DateTime? date;

  /// Class constructor
  const OcptResourcesAssetValidFromChangedEvent({required this.assetId, required this.date});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, assetId, date];
}

/// Sets the date asset [assetId]'s document stops being valid to [date] (or clears it, when null),
/// written immediately. See [OcptResourcesAssetValidFromChangedEvent] for why this is its own
/// event rather than a shared, discriminated one.
class OcptResourcesAssetValidUntilChangedEvent extends OcptResourcesLocationsEvent {
  /// The id of the asset whose validity window changed.
  final String assetId;

  /// The new date, or null to clear it.
  final DateTime? date;

  /// Class constructor
  const OcptResourcesAssetValidUntilChangedEvent({required this.assetId, required this.date});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, assetId, date];
}

/// Drops the asset reference [assetId] — a scouting photo. The file itself is never touched.
class OcptResourcesAssetRemovedEvent extends OcptResourcesLocationsEvent {
  /// The id of the asset reference to drop.
  final String assetId;

  /// Class constructor
  const OcptResourcesAssetRemovedEvent({required this.assetId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, assetId];
}

/// Adds an availability window to location [locationId], written immediately.
///
/// The window a location sheet mints is one whole day, every weekday, free of any condition: every
/// other answer is then given on the row it creates, where it is read beside the others.
class OcptResourcesLocationAvailabilityAddedEvent extends OcptResourcesLocationsEvent {
  /// The id of the location the window is added to.
  final String locationId;

  /// The first date this window covers.
  final DateTime startDate;

  /// The last date this window covers, inclusive.
  final DateTime endDate;

  /// Which days of the week, inside the range, this window covers, as an `ocptWeekdayMask*` mask.
  final int weekdays;

  /// Which part of each covered day this window takes.
  final OcptDayPartSlot slot;

  /// The start of the window in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? endMinute;

  /// Whether the location may be used freely over this window, or under a condition.
  final OcptLocationAvailabilityKind kind;

  /// What qualifies this window, free multi-line text.
  final String note;

  /// Class constructor
  const OcptResourcesLocationAvailabilityAddedEvent({
    required this.locationId,
    required this.startDate,
    required this.endDate,
    required this.weekdays,
    required this.slot,
    required this.startMinute,
    required this.endMinute,
    required this.kind,
    required this.note,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    locationId,
    startDate,
    endDate,
    weekdays,
    slot,
    startMinute,
    endMinute,
    kind,
    note,
  ];
}

/// Updates availability window [id]'s fields, written immediately, replacing all of them at once.
class OcptResourcesLocationAvailabilityUpdatedEvent extends OcptResourcesLocationsEvent {
  /// The id of the window to update.
  final String id;

  /// The new first date.
  final DateTime startDate;

  /// The new last date, inclusive.
  final DateTime endDate;

  /// The new weekday mask.
  final int weekdays;

  /// The new slot within each covered day.
  final OcptDayPartSlot slot;

  /// The new window start in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The new window end in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? endMinute;

  /// The new kind.
  final OcptLocationAvailabilityKind kind;

  /// The new note.
  final String note;

  /// Class constructor
  const OcptResourcesLocationAvailabilityUpdatedEvent({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.weekdays,
    required this.slot,
    required this.startMinute,
    required this.endMinute,
    required this.kind,
    required this.note,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    id,
    startDate,
    endDate,
    weekdays,
    slot,
    startMinute,
    endMinute,
    kind,
    note,
  ];
}

/// Removes availability window [id], written immediately.
class OcptResourcesLocationAvailabilityRemovedEvent extends OcptResourcesLocationsEvent {
  /// The id of the window to remove.
  final String id;

  /// Class constructor
  const OcptResourcesLocationAvailabilityRemovedEvent({required this.id});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, id];
}

/// Fired by the field-edit debounce timer `OcptResourcesLocationFieldChangedEvent` and
/// `OcptResourcesSetFieldChangedEvent` (re)start, once it elapses with no further edit. Not meant
/// to be dispatched by a widget directly.
class OcptResourcesLocationsFieldEditFlushRequestedEvent extends OcptResourcesLocationsEvent {
  /// Class constructor
  const OcptResourcesLocationsFieldEditFlushRequestedEvent();
}
