// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_field.dart';

/// "Hair, make-up & costume": the body measurements a wardrobe sheet always carries (height,
/// chest, waist, hips), the three clothing sizes, and the HMC continuity notes.
///
/// These fields used to sit on the meals/health/skills card, which put a fitting's measurements
/// beside a person's allergies and driving licences — three things read by three different people
/// at three different moments. Everything a costume or make-up department needs is on this card
/// and nowhere else.
class OcptPersonSheetHmcCard extends StatelessWidget {
  /// The person these fields belong to.
  final String personId;

  /// [personId]'s current value for `field`: a pending edit still in the bloc's debounce, or the
  /// person's own stored value.
  final String Function(OcptPersonField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be
  /// written to.
  final void Function(OcptPersonField field, String rawValue)? onFieldChanged;

  /// Class constructor
  const OcptPersonSheetHmcCard({
    super.key,
    required this.personId,
    required this.fieldValueOf,
    required this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptPersonSheetCard(
      title: tr.resourcesHmcTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldRow([
            (tr.resourcesMeasurementHeightLabel, OcptPersonField.measurementHeight),
            (tr.resourcesMeasurementChestLabel, OcptPersonField.measurementChest),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            (tr.resourcesMeasurementWaistLabel, OcptPersonField.measurementWaist),
            (tr.resourcesMeasurementHipsLabel, OcptPersonField.measurementHips),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            (tr.resourcesSizeTopLabel, OcptPersonField.sizeTop),
            (tr.resourcesSizeBottomLabel, OcptPersonField.sizeBottom),
            (tr.resourcesSizeShoesLabel, OcptPersonField.sizeShoes),
          ]),
          const SizedBox(height: 10),
          OcptPersonSheetField(
            personId: personId,
            label: tr.resourcesHmcNotesLabel,
            value: fieldValueOf(OcptPersonField.hmcNotes),
            multiline: true,
            onChanged: _onFieldChangedOrNull(OcptPersonField.hmcNotes),
          ),
        ],
      ),
    );
  }

  /// One row of equally wide fields, built from their `(label, field)` pairs.
  Widget _buildFieldRow(List<(String, OcptPersonField)> fields) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, (label, field)) in fields.indexed) ...[
        if (index > 0) const SizedBox(width: 8),
        Expanded(
          child: OcptPersonSheetField(
            personId: personId,
            label: label,
            value: fieldValueOf(field),
            onChanged: _onFieldChangedOrNull(field),
          ),
        ),
      ],
    ],
  );

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
