// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_inline_field.dart';

/// One editable text field bound to the detail panel's [OcptBudgetDetail.fieldValueOf] and
/// [OcptBudgetDetail.onFieldChanged].
class OcptBudgetDetailField extends StatelessWidget {
  /// The detail panel whose field value and change callback this field is bound to.
  final OcptBudgetDetail detail;

  /// The id of the poste or line the field writes to.
  final String targetId;

  /// Which field of the target is written.
  final OcptBudgetField field;

  /// The field's label.
  final String label;

  /// The field's stored value, shown while no pending edit holds a newer one.
  final String storedValue;

  /// The greyed placeholder shown while the field is empty, or null.
  final String? hintText;

  /// An inline error message, or null while the field's own value stands as typed.
  final String? errorText;

  /// Whether the field is written as several lines.
  final bool multiline;

  /// Class constructor
  const OcptBudgetDetailField({
    super.key,
    required this.detail,
    required this.targetId,
    required this.field,
    required this.label,
    required this.storedValue,
    this.hintText,
    this.errorText,
    this.multiline = false,
  });

  /// Build the budget detail panel field as an [OcptBudgetInlineField].
  @override
  Widget build(BuildContext context) {
    final fieldValueOf = detail.fieldValueOf;
    final onFieldChanged = detail.onFieldChanged;
    return OcptBudgetInlineField(
      label: label,
      value: fieldValueOf(targetId, field, storedValue),
      hintText: hintText,
      errorText: errorText,
      multiline: multiline,
      onChanged: onFieldChanged == null ? null : (value) => onFieldChanged(targetId, field, value),
    );
  }
}
