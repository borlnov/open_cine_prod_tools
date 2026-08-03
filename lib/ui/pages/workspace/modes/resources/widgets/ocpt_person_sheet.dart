// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_hmc_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_image_rights_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_logistics_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_meals_health_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_minor_callout.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_positions_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_unavailabilities_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_notes_card.dart';

/// The resources mode's centre, once a person is selected: the whole person sheet, a single
/// scrolling column edited in place — the header (photo slot, name, minor badge, contact grid),
/// the crew positions card, the legal-hours callout (only while the person is a minor), a
/// two-column grid of cards (meals/health/skills; logistics; image rights; hair, make-up and
/// costume), the
/// full-width unavailabilities card, the notes card, and `Delete this person` at the very bottom.
///
/// The unavailabilities are the one card outside the grid: a date range, a slot selector and a
/// multi-line reason do not fit half a sheet's width, and cramming them there is what made the
/// reason field a single line in the first place.
///
/// Every callback is always given by the caller (the mode always has a person selected while this
/// widget is built, exactly as `OcptShotInspectorPanel` is always given `onDeleteRequested` while a
/// shot is selected); [isReadOnly] is what this widget uses to null every one of them out before
/// handing it to the part that owns the affordance, so a field added later cannot be gated in one
/// place and forgotten in the other. The "Days of presence and function held" section of the
/// mock-up is schedule data and is out of scope here entirely.
class OcptPersonSheet extends StatelessWidget {
  /// The person this sheet shows.
  final OcptPerson person;

  /// Whether what the mode shows is a project version being previewed read-only, which no
  /// callback of this sheet may write through.
  final bool isReadOnly;

  /// [person]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// person's own stored value.
  final String Function(OcptPersonField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke.
  final void Function(OcptPersonField field, String rawValue) onFieldChanged;

  /// Called with the palette index picked from the avatar's colour popover.
  final ValueChanged<int> onColorChanged;

  /// Called with the newly picked date of birth, or null to clear it.
  final ValueChanged<DateTime?> onBirthDateChanged;

  /// Called with the newly picked transport autonomy.
  final ValueChanged<bool?> onTransportAutonomyChanged;

  /// Called with the newly picked image rights status.
  final ValueChanged<OcptImageRightsStatus> onImageRightsStatusChanged;

  /// Called with the newly picked image rights date, or null to clear it.
  final ValueChanged<DateTime?> onImageRightsDateChanged;

  /// Called when `+ Add a function` is clicked, appending a new, blank assignment.
  final VoidCallback onPositionAdded;

  /// Called with a position's id and its two current fields once a local edit is ready to be
  /// written.
  final void Function(String id, {required String positionId, required String customLabel})
  onPositionUpdated;

  /// Called with a position's id when its row's remove button is clicked.
  final ValueChanged<String> onPositionRemoved;

  /// Called with a new skill's label.
  final ValueChanged<String> onSkillAdded;

  /// Called with a skill's id when its chip's remove control is clicked.
  final ValueChanged<String> onSkillRemoved;

  /// Called with a new unavailability's whole shape: one full day when `+ Add an unavailability`
  /// picked a date, a second `custom` slot over an existing row's dates when that row's `+` was
  /// clicked. Its reason always starts empty, editable on the row it creates.
  final void Function({
    required DateTime startDate,
    required DateTime endDate,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
  })
  onUnavailabilityAdded;

  /// Called with an unavailability's id and its current fields once a local edit or a discrete
  /// change is ready to be written.
  final void Function(
    String id, {
    required DateTime startDate,
    required DateTime endDate,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
    required String reason,
  })
  onUnavailabilityUpdated;

  /// Called with an unavailability's id when its row's remove button is clicked.
  final ValueChanged<String> onUnavailabilityRemoved;

  /// Called when `Delete this person` is clicked, opening the deletion confirmation.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptPersonSheet({
    super.key,
    required this.person,
    this.isReadOnly = false,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onColorChanged,
    required this.onBirthDateChanged,
    required this.onTransportAutonomyChanged,
    required this.onImageRightsStatusChanged,
    required this.onImageRightsDateChanged,
    required this.onPositionAdded,
    required this.onPositionUpdated,
    required this.onPositionRemoved,
    required this.onSkillAdded,
    required this.onSkillRemoved,
    required this.onUnavailabilityAdded,
    required this.onUnavailabilityUpdated,
    required this.onUnavailabilityRemoved,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isMinor = person.isMinor == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OcptPersonSheetHeader(
            person: person,
            fieldValueOf: fieldValueOf,
            onFieldChanged: isReadOnly ? null : onFieldChanged,
            onColorChanged: isReadOnly ? null : onColorChanged,
            onBirthDateChanged: isReadOnly ? null : onBirthDateChanged,
          ),
          const SizedBox(height: 16),
          OcptPersonSheetPositionsCard(
            personId: person.id,
            positions: person.positions,
            onUpdated: isReadOnly ? null : onPositionUpdated,
            onRemoved: isReadOnly ? null : onPositionRemoved,
            onAdded: isReadOnly ? null : onPositionAdded,
          ),
          if (isMinor) ...[
            const SizedBox(height: 12),
            OcptPersonSheetMinorCallout(
              personId: person.id,
              value: fieldValueOf(OcptPersonField.minorNotes),
              onChanged: isReadOnly
                  ? null
                  : (value) => onFieldChanged(OcptPersonField.minorNotes, value),
            ),
          ],
          const SizedBox(height: 12),
          _buildCardGrid(context),
          const SizedBox(height: 12),
          OcptPersonSheetUnavailabilitiesCard(
            unavailabilities: person.unavailabilities,
            onUpdated: isReadOnly ? null : onUnavailabilityUpdated,
            onRemoved: isReadOnly ? null : onUnavailabilityRemoved,
            onAdded: isReadOnly ? null : onUnavailabilityAdded,
          ),
          const SizedBox(height: 12),
          OcptResourcesNotesCard(
            title: tr.resourcesNotesTitle,
            ownerId: person.id,
            value: fieldValueOf(OcptPersonField.notes),
            onChanged: isReadOnly ? null : (value) => onFieldChanged(OcptPersonField.notes, value),
          ),
          if (!isReadOnly) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onDeleteRequested,
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                child: Text(tr.resourcesDeletePersonAction),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The two-column grid of cards: meals/health/skills beside logistics, then image rights beside
  /// hair, make-up and costume.
  Widget _buildCardGrid(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: OcptPersonSheetMealsHealthCard(
              personId: person.id,
              skills: person.skills,
              fieldValueOf: fieldValueOf,
              onFieldChanged: isReadOnly ? null : onFieldChanged,
              onSkillAdded: isReadOnly ? null : onSkillAdded,
              onSkillRemoved: isReadOnly ? null : onSkillRemoved,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OcptPersonSheetLogisticsCard(
              personId: person.id,
              isTransportAutonomous: person.isTransportAutonomous,
              fieldValueOf: fieldValueOf,
              onFieldChanged: isReadOnly ? null : onFieldChanged,
              onTransportAutonomyChanged: isReadOnly ? null : onTransportAutonomyChanged,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: OcptPersonSheetImageRightsCard(
              status: person.imageRightsStatus,
              date: person.imageRightsDate,
              onStatusChanged: isReadOnly ? null : onImageRightsStatusChanged,
              onDateChanged: isReadOnly ? null : onImageRightsDateChanged,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OcptPersonSheetHmcCard(
              personId: person.id,
              fieldValueOf: fieldValueOf,
              onFieldChanged: isReadOnly ? null : onFieldChanged,
            ),
          ),
        ],
      ),
    ],
  );
}
