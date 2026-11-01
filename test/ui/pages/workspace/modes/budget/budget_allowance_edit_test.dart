// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'budget_mode_scenarios_test_doubles.dart';

void main() {
  final harness = BudgetScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  testWidgets("editing a defrayal from the Regie page writes the new quantity", (tester) async {
    await harness.seedAllowance("Per diem");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderRegieSegmentLabel);

    await harness.tap(tester, find.text("Per diem"));
    expect(find.byType(AlertDialog), findsOneWidget);
    await harness.type(
      tester,
      find.widgetWithText(TextFormField, tr.budgetAllowanceDialogQuantityFieldLabel),
      "5",
    );
    await harness.tap(tester, find.text(tr.budgetEntryDialogConfirmAction));

    expect(find.byType(AlertDialog), findsNothing);
    final allowances = await harness.readAllowances();
    expect(allowances, hasLength(1));
    expect(allowances.single.quantityMilli, 5000);
  });
}
