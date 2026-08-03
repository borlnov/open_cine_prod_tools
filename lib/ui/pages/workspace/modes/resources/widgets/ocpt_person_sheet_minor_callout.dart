// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// The warning-tinted "Legal hours" callout shown on the person sheet whenever the selected
/// person is a minor: `OcptPerson.minorNotes` (hours, guardian presence, authorisation),
/// editable in place through the sheet's own `OcptPersonField` debounce, exactly as every other
/// free-text field of the sheet.
class OcptPersonSheetMinorCallout extends StatelessWidget {
  /// The id of the person this callout belongs to.
  final String personId;

  /// The current value of `minorNotes`.
  final String value;

  /// Called with the raw text on every keystroke, or null while the sheet may not be written to.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const OcptPersonSheetMinorCallout({
    super.key,
    required this.personId,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = ocptWarningColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.resourcesMinorCalloutTitle,
            style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          OcptResourcesSheetField(
            ownerId: personId,
            label: "",
            value: value,
            multiline: true,
            hintText: tr.resourcesMinorNotesHint,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
