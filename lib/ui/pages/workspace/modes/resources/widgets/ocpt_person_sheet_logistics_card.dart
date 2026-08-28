// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// "Logistics": whether the person can travel to set on their own (a real tri-state — unknown is
/// itself a selectable value, not a missing one), where they stay during the shoot, their travel
/// logistics, and the two figures the catering-and-travel pass will cross to price their own
/// commute — the one-way distance and which of the project's own mileage rates it is reimbursed
/// at.
///
/// The commute belongs on this card rather than a new one of its own: it is the same question —
/// "how does this person get to set" — asked of the same person on the same sheet, and this app
/// asks Benoit before drawing a new card, not before adding a field to one that already exists.
class OcptPersonSheetLogisticsCard extends StatelessWidget {
  /// The person these fields belong to.
  final String personId;

  /// The person's current transport autonomy: true, false, or null for "not asked yet".
  final bool? isTransportAutonomous;

  /// [personId]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// person's own stored value.
  final String Function(OcptPersonField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be
  /// written to.
  final void Function(OcptPersonField field, String rawValue)? onFieldChanged;

  /// Called with the newly picked transport autonomy, or null while it may not be changed.
  final ValueChanged<bool?>? onTransportAutonomyChanged;

  /// The project's own mileage rates, offered by the rate picker below the commute field, in
  /// `sortKey` order.
  final List<OcptBudgetMileageRate> mileageRates;

  /// The id of the person's currently picked mileage rate (`people.mileageRateId`), or null while
  /// they name none — the honest reading of a field nobody has answered yet, never "zero
  /// kilometres", the same reading `OcptPersonSheetMaxPresenceCard`'s own field already carries on
  /// this sheet.
  final String? mileageRateId;

  /// Called with the newly picked mileage rate's id, or null for "no rate", or null itself while
  /// it may not be changed.
  final ValueChanged<String?>? onMileageRateChanged;

  /// Class constructor
  const OcptPersonSheetLogisticsCard({
    super.key,
    required this.personId,
    required this.isTransportAutonomous,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onTransportAutonomyChanged,
    required this.mileageRates,
    required this.mileageRateId,
    required this.onMileageRateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptResourcesSheetCard(
      title: tr.resourcesLogisticsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.resourcesTransportAutonomyLabel.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          _OcptTransportAutonomyControl(
            value: isTransportAutonomous,
            onChanged: onTransportAutonomyChanged,
          ),
          const SizedBox(height: 10),
          OcptResourcesSheetField(
            ownerId: personId,
            label: tr.resourcesAccommodationNotesLabel,
            value: fieldValueOf(OcptPersonField.accommodationNotes),
            multiline: true,
            onChanged: _onFieldChangedOrNull(OcptPersonField.accommodationNotes),
          ),
          const SizedBox(height: 10),
          OcptResourcesSheetField(
            ownerId: personId,
            label: tr.resourcesTravelNotesLabel,
            value: fieldValueOf(OcptPersonField.travelNotes),
            multiline: true,
            onChanged: _onFieldChangedOrNull(OcptPersonField.travelNotes),
          ),
          const SizedBox(height: 10),
          OcptResourcesSheetField(
            ownerId: personId,
            label: tr.resourcesCommuteDistanceLabel,
            value: fieldValueOf(OcptPersonField.commuteKmMilli),
            hintText: tr.resourcesCommuteDistanceHint,
            suffixText: tr.resourcesCommuteDistanceSuffix,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorTextOf: (value) => _commuteDistanceErrorTextOf(tr, value),
            onChanged: _onFieldChangedOrNull(OcptPersonField.commuteKmMilli),
          ),
          const SizedBox(height: 10),
          Text(
            tr.resourcesMileageRateLabel.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          _OcptMileageRatePicker(
            mileageRates: mileageRates,
            mileageRateId: mileageRateId,
            onChanged: onMileageRateChanged,
          ),
        ],
      ),
    );
  }

  /// What is wrong with the typed commute distance [value], or null when there is nothing to say
  /// about it.
  ///
  /// A **remark, never a gate**, exactly as `OcptPersonSheetMaxPresenceCard._errorTextOf` is for
  /// its own field: the value is written either way, an empty field being the normal state rather
  /// than an error, most people having no commute recorded.
  String? _commuteDistanceErrorTextOf(Tr tr, String value) {
    if (value.trim().isEmpty || ocptBudgetQuantityMilliOf(value) != null) {
      return null;
    }

    return tr.resourcesCommuteDistanceFormatError;
  }

  /// The `onChanged` a field of [field] is given: the one reporting to [onFieldChanged], or null
  /// while the sheet may not be written to.
  ValueChanged<String>? _onFieldChangedOrNull(OcptPersonField field) {
    final onFieldChanged = this.onFieldChanged;
    if (onFieldChanged == null) {
      return null;
    }
    return (value) => onFieldChanged(field, value);
  }
}

/// The three-way pill selector for transport autonomy — unknown/no/yes, in that order — matching
/// `OcptResourcesTabBar`'s own segmented look. "Not asked" is a real, clickable value: the person
/// sheet never hides it behind an empty selection.
class _OcptTransportAutonomyControl extends StatelessWidget {
  /// The current value: true, false, or null for "not asked yet".
  final bool? value;

  /// Called with the value picked, or null while it may not be changed: the pills then read the
  /// current value out with no reaction to a tap.
  final ValueChanged<bool?>? onChanged;

  /// Class constructor
  const _OcptTransportAutonomyControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(context, null, tr.resourcesTransportAutonomyUnknown),
          _buildOption(context, false, tr.resourcesTransportAutonomyNo),
          _buildOption(context, true, tr.resourcesTransportAutonomyYes),
        ],
      ),
    );
  }

  /// Builds one option of the control.
  Widget _buildOption(BuildContext context, bool? optionValue, String label) {
    final theme = Theme.of(context);
    final isSelected = optionValue == value;
    final onChanged = this.onChanged;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );

    if (onChanged == null) {
      return pill;
    }

    return InkWell(
      onTap: () => onChanged(optionValue),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: pill,
    );
  }
}

/// The mileage rate picker: a dropdown over [mileageRates], plus a "No rate" entry carrying null —
/// `OcptProjectSettingsScreenplayLanguageSection`'s own idiom for a picker whose "nothing picked"
/// is a real, honest answer rather than an incomplete selection.
///
/// Offers exactly the rates [mileageRates] holds, whatever their number — none while the project
/// has not been given any yet (`OcptProjectSettingsMileageRatesSection`'s own doc comment for why
/// this app suggests none of its own), which then leaves only the "No rate" entry, itself already
/// the field's current value: an empty catalogue therefore reads as an ordinary, unremarkable
/// picker rather than as something broken.
class _OcptMileageRatePicker extends StatelessWidget {
  /// The project's own mileage rates offered by this picker, in `sortKey` order.
  final List<OcptBudgetMileageRate> mileageRates;

  /// The id of the currently picked rate, or null for "No rate".
  final String? mileageRateId;

  /// Called with the newly picked rate's id, or null for "No rate", or null itself while it may
  /// not be changed.
  final ValueChanged<String?>? onChanged;

  /// Class constructor
  const _OcptMileageRatePicker({
    required this.mileageRates,
    required this.mileageRateId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    // A rate this person once named that the catalogue no longer lists live (tombstoned since, or
    // never seeded in the first place) would make `DropdownButton` throw on a value with no
    // matching item: falling back to null here is the same honest reading
    // `docs/architecture/budget.md` already gives such a person's own travel figures — no live
    // rate is exactly "no rate" from where this picker stands.
    final liveRate = mileageRates.where((rate) => rate.id == mileageRateId).firstOrNull;

    // Withheld, not disabled (`docs/architecture/foundations.md`): a `DropdownButton` given a null
    // `onChanged` paints itself in Flutter's own disabled grey, which is exactly the look this app
    // never wants for a read-only preview. A plain line of text reads the current pick out —
    // `_OcptImageRightsStatusBadge`'s own reasoning for the very same field shape.
    final onChanged = this.onChanged;
    if (onChanged == null) {
      return Text(
        liveRate?.label ?? tr.resourcesMileageRateNoRateOption,
        style: theme.textTheme.bodySmall,
      );
    }

    return DropdownButton<String?>(
      value: liveRate?.id,
      isExpanded: true,
      onChanged: onChanged,
      mouseCursor: ocptClickableCursor,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
      items: [
        DropdownMenuItem(child: Text(tr.resourcesMileageRateNoRateOption)),
        for (final rate in mileageRates) DropdownMenuItem(value: rate.id, child: Text(rate.label)),
      ],
    );
  }
}
