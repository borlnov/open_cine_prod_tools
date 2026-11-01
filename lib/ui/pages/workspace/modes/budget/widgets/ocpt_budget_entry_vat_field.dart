// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';

/// `TVA`.
class OcptBudgetEntryVatField extends StatelessWidget {
  /// The controller of the VAT rate override field.
  final TextEditingController controller;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// Class constructor
  const OcptBudgetEntryVatField({
    super.key,
    required this.controller,
    required this.defaultVatRateBasisPoints,
  });

  /// Build the budget entry VAT field as a [TextFormField].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final defaultVatRateBasisPoints = this.defaultVatRateBasisPoints;
    final vatRateHint = defaultVatRateBasisPoints == null
        ? null
        : tr.budgetLineVatRateInheritedHint(ocptVatRatePercentTextOf(defaultVatRateBasisPoints));

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: tr.budgetLineVatRateFieldLabel,
        hintText: vatRateHint,
        suffixText: tr.budgetLineVatRateSuffix,
      ),
    );
  }
}
