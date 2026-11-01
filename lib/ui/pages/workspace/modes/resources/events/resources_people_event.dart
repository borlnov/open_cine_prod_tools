// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/events/resources_base_event.dart';

/// The events about people (address book).
sealed class OcptResourcesPeopleEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesPeopleEvent();
}

/// Requests creating a new, blank person at the end of the address book, then selecting it: the
/// left dock's `+ Add a person` action.
class OcptResourcesPersonCreationRequestedEvent extends OcptResourcesPeopleEvent {
  /// Class constructor
  const OcptResourcesPersonCreationRequestedEvent();
}

/// Requests erasing person [personId], dispatched once `OcptResourcesDeleteConfirmDialog` has
/// already confirmed it. Clears the selection when [personId] was the selected person, and drops
/// any pending field edit that still targeted it.
class OcptResourcesPersonDeletionRequestedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person to erase.
  final String personId;

  /// Class constructor
  const OcptResourcesPersonDeletionRequestedEvent({required this.personId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId];
}

/// Records the raw text just typed into [field] of person [personId], dispatched by the person
/// sheet on every keystroke.
///
/// The typed value becomes visible immediately as a pending edit in
/// `OcptResourcesPeopleState.pendingFieldEdits`, and (re)starts the field-edit autosave debounce
/// that eventually writes it, unless something flushes it sooner (selecting another person or tab,
/// leaving the workspace, or the mode itself leaving the widget tree).
class OcptResourcesPersonFieldChangedEvent extends OcptResourcesPeopleEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, field, rawValue];
}

/// Sets person [personId]'s avatar colour to `ocptCoveragePalette[colorIndex]`, written
/// immediately: picking a swatch is a single discrete action, not typing.
class OcptResourcesPersonColorChangedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person whose colour changed.
  final String personId;

  /// The new colour index.
  final int colorIndex;

  /// Class constructor
  const OcptResourcesPersonColorChangedEvent({required this.personId, required this.colorIndex});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, colorIndex];
}

/// Sets person [personId]'s date of birth to [date] (or clears it, when null), written
/// immediately: picking a date is a single discrete action, not typing.
class OcptResourcesPersonBirthDateChangedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person whose date of birth changed.
  final String personId;

  /// The new date of birth, or null to clear it.
  final DateTime? date;

  /// Class constructor
  const OcptResourcesPersonBirthDateChangedEvent({required this.personId, required this.date});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, date];
}

/// Sets whether person [personId] can travel to set on their own, written immediately: a tri-state
/// toggle (unknown/yes/no) is a single discrete action, not typing.
class OcptResourcesPersonTransportAutonomyChangedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person whose transport autonomy changed.
  final String personId;

  /// The new value: true, false, or null for "not asked yet".
  final bool? isTransportAutonomous;

  /// Class constructor
  const OcptResourcesPersonTransportAutonomyChangedEvent({
    required this.personId,
    required this.isTransportAutonomous,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, isTransportAutonomous];
}

/// Sets person [personId]'s image rights status to [status], written immediately: picking a status
/// is a single discrete action, not typing.
class OcptResourcesPersonImageRightsStatusChangedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person whose image rights status changed.
  final String personId;

  /// The new status.
  final OcptImageRightsStatus status;

  /// Class constructor
  const OcptResourcesPersonImageRightsStatusChangedEvent({
    required this.personId,
    required this.status,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, status];
}

/// Sets the date person [personId]'s image rights status last changed to [date] (or clears it,
/// when null), written immediately: picking a date is a single discrete action, not typing.
class OcptResourcesPersonImageRightsDateChangedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person whose image rights date changed.
  final String personId;

  /// The new date, or null to clear it.
  final DateTime? date;

  /// Class constructor
  const OcptResourcesPersonImageRightsDateChangedEvent({
    required this.personId,
    required this.date,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, date];
}

/// Sets person [personId]'s mileage rate to `budget_mileage_rates` row [mileageRateId] (or clears
/// it, when null), written immediately: picking a rate from the project's catalogue is a single
/// discrete action, not typing.
///
/// Null means "this person claims nothing" — never "zero kilometres", the reading
/// `OcptPerson.maxDailyPresenceMinutes` already carries on this very sheet — and is what the
/// picker's own "No rate" entry reports.
class OcptResourcesPersonMileageRateChangedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person whose mileage rate changed.
  final String personId;

  /// The id of the newly picked `budget_mileage_rates` row, or null to clear it.
  final String? mileageRateId;

  /// Class constructor
  const OcptResourcesPersonMileageRateChangedEvent({
    required this.personId,
    required this.mileageRateId,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, mileageRateId];
}

/// Adds a crew position assignment to person [personId], written immediately.
class OcptResourcesPositionAddedEvent extends OcptResourcesPeopleEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, positionId, customLabel];
}

/// Updates position assignment [id]'s fields, written immediately, replacing both at once.
class OcptResourcesPositionUpdatedEvent extends OcptResourcesPeopleEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, id, positionId, customLabel];
}

/// Removes position assignment [id], written immediately.
class OcptResourcesPositionRemovedEvent extends OcptResourcesPeopleEvent {
  /// The id of the position assignment to remove.
  final String id;

  /// Class constructor
  const OcptResourcesPositionRemovedEvent({required this.id});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, id];
}

/// Adds a skill to person [personId], written immediately.
class OcptResourcesSkillAddedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person the skill is added to.
  final String personId;

  /// The skill itself, free text.
  final String label;

  /// Class constructor
  const OcptResourcesSkillAddedEvent({required this.personId, required this.label});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, label];
}

/// Updates skill [id]'s label, written immediately.
class OcptResourcesSkillUpdatedEvent extends OcptResourcesPeopleEvent {
  /// The id of the skill to update.
  final String id;

  /// The new label.
  final String label;

  /// Class constructor
  const OcptResourcesSkillUpdatedEvent({required this.id, required this.label});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, id, label];
}

/// Removes skill [id], written immediately.
class OcptResourcesSkillRemovedEvent extends OcptResourcesPeopleEvent {
  /// The id of the skill to remove.
  final String id;

  /// Class constructor
  const OcptResourcesSkillRemovedEvent({required this.id});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, id];
}

/// Adds an unavailability to person [personId], written immediately.
class OcptResourcesUnavailabilityAddedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person the unavailability is added to.
  final String personId;

  /// The first date this unavailability covers.
  final DateTime startDate;

  /// The last date this unavailability covers, inclusive.
  final DateTime endDate;

  /// Which part of each covered day this unavailability takes.
  final OcptDayPartSlot slot;

  /// The start of the window in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
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
class OcptResourcesUnavailabilityUpdatedEvent extends OcptResourcesPeopleEvent {
  /// The id of the unavailability to update.
  final String id;

  /// The new first date.
  final DateTime startDate;

  /// The new last date, inclusive.
  final DateTime endDate;

  /// The new slot within each covered day.
  final OcptDayPartSlot slot;

  /// The new window start in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The new window end in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom].
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
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
class OcptResourcesUnavailabilityRemovedEvent extends OcptResourcesPeopleEvent {
  /// The id of the unavailability to remove.
  final String id;

  /// Class constructor
  const OcptResourcesUnavailabilityRemovedEvent({required this.id});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, id];
}

/// Requests referencing person [personId]'s photo, replacing whichever one they referenced before.
/// See `OcptResourcesLocationPhotoAddRequestedEvent` for [fileTypeLabel].
class OcptResourcesPersonPhotoPickRequestedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person the photo is referenced for.
  final String personId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptResourcesPersonPhotoPickRequestedEvent({
    required this.personId,
    required this.fileTypeLabel,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, fileTypeLabel];
}

/// Drops person [personId]'s reference to their photo. The file itself is never touched.
class OcptResourcesPersonPhotoClearedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person whose photo reference is dropped.
  final String personId;

  /// Class constructor
  const OcptResourcesPersonPhotoClearedEvent({required this.personId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId];
}

/// Requests referencing person [personId]'s signed image rights release, replacing whichever one
/// they referenced before. See `OcptResourcesLocationPhotoAddRequestedEvent` for [fileTypeLabel].
///
/// Writes the reference alone: `imageRightsStatus` stays whatever the sheet's own control says, a
/// filed document being a different claim from a signed one.
class OcptResourcesImageRightsDocumentPickRequestedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person the document is referenced for.
  final String personId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptResourcesImageRightsDocumentPickRequestedEvent({
    required this.personId,
    required this.fileTypeLabel,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId, fileTypeLabel];
}

/// Drops person [personId]'s reference to their signed image rights release. Neither the file nor
/// `imageRightsStatus` is touched.
class OcptResourcesImageRightsDocumentClearedEvent extends OcptResourcesPeopleEvent {
  /// The id of the person whose image rights document reference is dropped.
  final String personId;

  /// Class constructor
  const OcptResourcesImageRightsDocumentClearedEvent({required this.personId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, personId];
}

/// Fired by the field-edit debounce timer `OcptResourcesPersonFieldChangedEvent` (re)starts, once
/// it elapses with no further edit. Not meant to be dispatched by a widget directly.
class OcptResourcesPeopleFieldEditFlushRequestedEvent extends OcptResourcesPeopleEvent {
  /// Class constructor
  const OcptResourcesPeopleFieldEditFlushRequestedEvent();
}
