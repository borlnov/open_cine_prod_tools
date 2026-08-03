// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';

/// "Logistics": whether the person can travel to set on their own (a real tri-state — unknown is
/// itself a selectable value, not a missing one), where they stay during the shoot, and their
/// travel logistics.
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

  /// Class constructor
  const OcptPersonSheetLogisticsCard({
    super.key,
    required this.personId,
    required this.isTransportAutonomous,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onTransportAutonomyChanged,
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
        ],
      ),
    );
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
