// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';

/// The step-3 primary action: `Create N lines` for the breakdown selector, `Save` for every other
/// gesture, and nothing at all while no gesture is picked.
class OcptBudgetNewFormPrimaryAction extends StatelessWidget {
  /// The gesture in effect, or null while none is.
  final OcptBudgetGesture? gesture;

  /// How many breakdown elements are checked, read only for the breakdown selector's label.
  final int breakdownSelectedCount;

  /// Called when the button is pressed, or null to withhold it.
  final VoidCallback? onPressed;

  /// Class constructor
  const OcptBudgetNewFormPrimaryAction({
    super.key,
    required this.gesture,
    required this.breakdownSelectedCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final gesture = this.gesture;
    if (gesture == null) {
      return const SizedBox.shrink();
    }

    if (gesture == OcptBudgetGesture.addQuoteLinesFromBreakdown) {
      return FilledButton(
        key: const Key("ocptBudgetNewCreateLinesButton"),
        onPressed: onPressed,
        child: Text(tr.budgetNewCreateLinesAction(breakdownSelectedCount)),
      );
    }

    return FilledButton(
      key: const Key("ocptBudgetNewSaveButton"),
      onPressed: onPressed,
      child: Text(tr.budgetEntryDialogConfirmAction),
    );
  }
}
