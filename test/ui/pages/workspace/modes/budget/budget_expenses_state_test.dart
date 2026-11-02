// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_state.dart';

/// Run the tests of [OcptBudgetExpensesState].
void main() {
  group("OcptBudgetExpensesState.fieldValueOf", () {
    test("reads a pending edit ahead of the stored value", () {
      final state = const OcptBudgetExpensesState.init().copyWith(
        pendingFieldEdits: {("poste-1", OcptBudgetField.accountLabel): "Typed"},
      );

      expect(state.fieldValueOf("poste-1", OcptBudgetField.accountLabel, "Stored"), "Typed");
    });

    test("falls back to the stored value while nothing is pending for that key", () {
      const state = OcptBudgetExpensesState.init();

      expect(state.fieldValueOf("poste-1", OcptBudgetField.accountLabel, "Stored"), "Stored");
    });
  });
}
