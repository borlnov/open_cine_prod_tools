// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/utils/ocpt_max_daily_presence.dart';

/// The person sheet's "Maximum daily presence" card: `OcptPerson.maxDailyPresenceMinutes`, a single
/// field typed in minutes.
///
/// **Not restricted to minors** — an adult under a medical restriction is the same fact — so this
/// card is always shown, next to `OcptPersonSheetMinorCallout` when the selected person is one: the
/// two constraints are thought about together, which is why the sheet places them side by side
/// rather than folding this one inside the minor-only callout.
class OcptPersonSheetMaxPresenceCard extends StatelessWidget {
  /// The id of the person this card belongs to.
  final String personId;

  /// [personId]'s current value for `OcptPersonField.maxDailyPresenceMinutes`: a pending edit still
  /// in the bloc's debounce, or the person's own stored value.
  final String Function(OcptPersonField field) fieldValueOf;

  /// Called with the field's raw text on every keystroke, or null while the sheet may not be
  /// written to.
  final void Function(OcptPersonField field, String rawValue)? onFieldChanged;

  /// Class constructor
  const OcptPersonSheetMaxPresenceCard({
    super.key,
    required this.personId,
    required this.fieldValueOf,
    required this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onFieldChanged = this.onFieldChanged;

    return OcptResourcesSheetCard(
      title: tr.resourcesMaxDailyPresenceTitle,
      child: OcptResourcesSheetField(
        ownerId: personId,
        label: "",
        value: fieldValueOf(OcptPersonField.maxDailyPresenceMinutes),
        hintText: tr.resourcesMaxDailyPresenceHint,
        suffixText: tr.resourcesMaxDailyPresenceSuffix,
        keyboardType: TextInputType.number,
        errorTextOf: (value) => _errorTextOf(tr, value),
        onChanged: onFieldChanged == null
            ? null
            : (value) => onFieldChanged(OcptPersonField.maxDailyPresenceMinutes, value),
      ),
    );
  }

  /// What is wrong with the typed [value], or null when there is nothing to say about it.
  ///
  /// A **remark, never a gate**, exactly as `OcptElementSheetSourcingCard._costErrorOf` is for the
  /// cost field: the value is written either way, since a maximum nobody finished typing is not the
  /// same claim as "no maximum at all" — an empty field is not an error, most people have none
  /// recorded.
  String? _errorTextOf(Tr tr, String value) {
    if (value.trim().isEmpty || ocptMaxDailyPresenceMinutesOf(value) != null) {
      return null;
    }

    return tr.resourcesMaxDailyPresenceFormatError;
  }
}
