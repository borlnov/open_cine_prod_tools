// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_max_daily_presence.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The resources mode's centre while the people tab is active: the selected person's
/// [OcptPersonSheet], or the empty state asking for a selection.
///
/// The sheet sits inside a [BlocBuilder] on [OcptResourcesPeopleBloc] alone, so a keystroke in one
/// of its fields redraws the sheet and not the shell around it. Deleting the person is only
/// *asked*, through [onDeleteRequested]: the mode owns the confirmation dialog.
class OcptResourcesPersonSheetView extends StatelessWidget {
  /// The mode's state, which the selected person and the shared lists are read from.
  final OcptResourcesState state;

  /// Called when the user asked to delete the selected person.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptResourcesPersonSheetView({
    super.key,
    required this.state,
    required this.onDeleteRequested,
  });

  /// Build the resources person sheet view as a [BlocBuilder].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final selectedPerson = state.selectedPerson;
    if (selectedPerson == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.groups_outlined,
        message: tr.resourcesNoPersonSelectedHint,
      );
    }

    final peopleBloc = context.read<OcptResourcesPeopleBloc>();

    return BlocBuilder<OcptResourcesPeopleBloc, OcptResourcesPeopleState>(
      builder: (context, peopleState) => OcptPersonSheet(
        key: ValueKey(selectedPerson.id),
        person: selectedPerson,
        isReadOnly: state.isPreviewingVersion,
        fieldValueOf: (field) => _fieldValueOf(peopleState, selectedPerson, field),
        onFieldChanged: (field, rawValue) => peopleBloc.add(
          OcptResourcesPersonFieldChangedEvent(
            personId: selectedPerson.id,
            field: field,
            rawValue: rawValue,
          ),
        ),
        onColorChanged: (colorIndex) => peopleBloc.add(
          OcptResourcesPersonColorChangedEvent(personId: selectedPerson.id, colorIndex: colorIndex),
        ),
        onPhotoPickRequested: () => peopleBloc.add(
          OcptResourcesPersonPhotoPickRequestedEvent(
            personId: selectedPerson.id,
            fileTypeLabel: tr.resourcesImageFileTypeLabel,
          ),
        ),
        onPhotoCleared: () =>
            peopleBloc.add(OcptResourcesPersonPhotoClearedEvent(personId: selectedPerson.id)),
        onImageRightsDocumentPickRequested: () => peopleBloc.add(
          OcptResourcesImageRightsDocumentPickRequestedEvent(
            personId: selectedPerson.id,
            fileTypeLabel: tr.resourcesDocumentFileTypeLabel,
          ),
        ),
        onImageRightsDocumentCleared: () => peopleBloc.add(
          OcptResourcesImageRightsDocumentClearedEvent(personId: selectedPerson.id),
        ),
        onBirthDateChanged: (date) => peopleBloc.add(
          OcptResourcesPersonBirthDateChangedEvent(personId: selectedPerson.id, date: date),
        ),
        onTransportAutonomyChanged: (isTransportAutonomous) => peopleBloc.add(
          OcptResourcesPersonTransportAutonomyChangedEvent(
            personId: selectedPerson.id,
            isTransportAutonomous: isTransportAutonomous,
          ),
        ),
        onImageRightsStatusChanged: (status) => peopleBloc.add(
          OcptResourcesPersonImageRightsStatusChangedEvent(
            personId: selectedPerson.id,
            status: status,
          ),
        ),
        mileageRates: state.mileageRates,
        onMileageRateChanged: (mileageRateId) => peopleBloc.add(
          OcptResourcesPersonMileageRateChangedEvent(
            personId: selectedPerson.id,
            mileageRateId: mileageRateId,
          ),
        ),
        onImageRightsDateChanged: (date) => peopleBloc.add(
          OcptResourcesPersonImageRightsDateChangedEvent(personId: selectedPerson.id, date: date),
        ),
        onPositionAdded: () => peopleBloc.add(
          OcptResourcesPositionAddedEvent(
            personId: selectedPerson.id,
            positionId: "",
            customLabel: "",
          ),
        ),
        onPositionUpdated: (id, {required positionId, required customLabel}) => peopleBloc.add(
          OcptResourcesPositionUpdatedEvent(
            id: id,
            positionId: positionId,
            customLabel: customLabel,
          ),
        ),
        onPositionRemoved: (id) => peopleBloc.add(OcptResourcesPositionRemovedEvent(id: id)),
        onSkillAdded: (label) =>
            peopleBloc.add(OcptResourcesSkillAddedEvent(personId: selectedPerson.id, label: label)),
        onSkillRemoved: (id) => peopleBloc.add(OcptResourcesSkillRemovedEvent(id: id)),
        onUnavailabilityAdded:
            ({
              required startDate,
              required endDate,
              required slot,
              required startMinute,
              required endMinute,
            }) => peopleBloc.add(
              OcptResourcesUnavailabilityAddedEvent(
                personId: selectedPerson.id,
                startDate: startDate,
                endDate: endDate,
                slot: slot,
                startMinute: startMinute,
                endMinute: endMinute,
                reason: "",
              ),
            ),
        onUnavailabilityUpdated:
            (
              id, {
              required startDate,
              required endDate,
              required slot,
              required startMinute,
              required endMinute,
              required reason,
            }) => peopleBloc.add(
              OcptResourcesUnavailabilityUpdatedEvent(
                id: id,
                startDate: startDate,
                endDate: endDate,
                slot: slot,
                startMinute: startMinute,
                endMinute: endMinute,
                reason: reason,
              ),
            ),
        onUnavailabilityRemoved: (id) =>
            peopleBloc.add(OcptResourcesUnavailabilityRemovedEvent(id: id)),
        onDeleteRequested: onDeleteRequested,
      ),
    );
  }

  /// [person]'s current value for [field]: a pending edit still sitting in the bloc's debounce
  /// takes priority over the person's own stored value, so typing is never overwritten by an
  /// unrelated reload. Mirrors `OcptShotListMode._fieldValueOf`.
  String _fieldValueOf(OcptResourcesPeopleState state, OcptPerson person, OcptPersonField field) {
    final pending = state.pendingFieldEdits[(person.id, field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptPersonField.firstName => person.firstName,
      OcptPersonField.lastName => person.lastName,
      OcptPersonField.email => person.email,
      OcptPersonField.phone => person.phone,
      OcptPersonField.addressLine1 => person.addressLine1,
      OcptPersonField.addressLine2 => person.addressLine2,
      OcptPersonField.postalCode => person.postalCode,
      OcptPersonField.city => person.city,
      OcptPersonField.region => person.region,
      OcptPersonField.country => person.country,
      OcptPersonField.minorNotes => person.minorNotes,
      OcptPersonField.maxDailyPresenceMinutes => ocptMaxDailyPresenceTextOf(
        person.maxDailyPresenceMinutes,
      ),
      OcptPersonField.commuteKmMilli =>
        person.commuteKmMilli == null ? "" : ocptBudgetQuantityLabel(person.commuteKmMilli!),
      OcptPersonField.accommodationNotes => person.accommodationNotes,
      OcptPersonField.travelNotes => person.travelNotes,
      OcptPersonField.dietaryNotes => person.dietaryNotes,
      OcptPersonField.allergies => person.allergies,
      OcptPersonField.measurementHeight => person.measurementHeight,
      OcptPersonField.measurementChest => person.measurementChest,
      OcptPersonField.measurementWaist => person.measurementWaist,
      OcptPersonField.measurementHips => person.measurementHips,
      OcptPersonField.sizeTop => person.sizeTop,
      OcptPersonField.sizeBottom => person.sizeBottom,
      OcptPersonField.sizeShoes => person.sizeShoes,
      OcptPersonField.hmcNotes => person.hmcNotes,
      OcptPersonField.notes => person.notes,
    };
  }
}
