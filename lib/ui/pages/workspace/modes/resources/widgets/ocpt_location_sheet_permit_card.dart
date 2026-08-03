// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';

/// "Filming permit": what the permit *is* — the reference it was granted under, and the date that
/// happened.
///
/// The status itself is not here: it is the header's badge (see `OcptLocationSheetHeader`), where it
/// is read at a glance beside the location's name, and asking for it twice on one sheet would be
/// two controls answering one question.
class OcptLocationSheetPermitCard extends StatelessWidget {
  /// The id of the location this card belongs to.
  final String locationId;

  /// The date the permit status last changed, or null.
  final DateTime? permitDate;

  /// The location's current value for `field`.
  final String Function(OcptLocationField field) fieldValueOf;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be written
  /// to.
  final void Function(OcptLocationField field, String rawValue)? onFieldChanged;

  /// Called with the newly picked date (or null to clear it), or null while it may not be changed.
  final ValueChanged<DateTime?>? onPermitDateChanged;

  /// Class constructor
  const OcptLocationSheetPermitCard({
    super.key,
    required this.locationId,
    required this.permitDate,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onPermitDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onFieldChanged = this.onFieldChanged;

    return OcptResourcesSheetCard(
      title: tr.resourcesLocationPermitCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OcptResourcesSheetField(
            ownerId: locationId,
            label: tr.resourcesLocationPermitLabelLabel,
            value: fieldValueOf(OcptLocationField.permitLabel),
            hintText: tr.resourcesLocationPermitLabelHint,
            onChanged: onFieldChanged == null
                ? null
                : (value) => onFieldChanged(OcptLocationField.permitLabel, value),
          ),
          const SizedBox(height: 10),
          OcptPersonSheetDateField(
            label: tr.resourcesLocationPermitDateLabel,
            value: permitDate,
            onChanged: onPermitDateChanged,
          ),
        ],
      ),
    );
  }
}
