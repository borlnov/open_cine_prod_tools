// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';

import 'budget_mode_scenarios_test_doubles.dart';

/// The workspace swaps its side docks for drawers below the compact breakpoint, which unmounts
/// every view of the mode: a dialog confirmed after that must still write.
void main() {
  final harness = BudgetScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds [target] inside the open dialog.
  Finder inDialog(Finder target) => find.descendant(of: find.byType(Dialog), matching: target);

  /// Finds [target] inside the detail panel of the right dock.
  Finder inDetail(Finder target) =>
      find.descendant(of: find.byType(OcptBudgetDetail), matching: target);

  /// Shrinks the window below the compact breakpoint while a dialog stays open.
  Future<void> shrinkWindow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    await tester.pumpAndSettle();
  }

  testWidgets("a capture wizard confirmed after the window crossed the compact breakpoint "
      "still writes", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);

    await harness.tap(tester, find.byKey(const Key("ocptBudgetHeaderCaptureButton")));
    await harness.tap(tester, find.byKey(const Key("ocptBudgetNewGestureCard-planSubsidy")));
    await harness.tap(tester, find.byKey(const Key("ocptBudgetNewContinueButton")));

    // The wizard lays itself out again below the breakpoint and drops what was typed, so the
    // window shrinks first and the form is filled in afterwards.
    await shrinkWindow(tester);
    final fields = inDialog(find.byType(TextFormField));
    await tester.enterText(fields.at(0), "Regional grant");
    await tester.enterText(fields.at(1), "200");
    await tester.pumpAndSettle();
    await harness.tap(tester, find.byKey(const Key("ocptBudgetNewSaveButton")));

    final resources = await harness.readResources();
    expect(resources.map((resource) => resource.label), ["Regional grant"]);
  });

  testWidgets("a line paid directly from the fiche still writes when the window crossed the "
      "compact breakpoint under the open wizard", (tester) async {
    final posteId = await harness.seedPoste("Camera");
    await harness.seedLine(posteId, "Camera deposit");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, find.text("Camera deposit"));
    await harness.tap(tester, inDetail(find.text(tr.budgetDetailPayAction(r"$100.00"))));

    await shrinkWindow(tester);
    await harness.tap(tester, inDialog(find.text(tr.budgetEntryDialogConfirmAction)));

    expect(await harness.readCommitments(), hasLength(1));
    expect(await harness.readEntries(), hasLength(1));
  });

  testWidgets("a resource edited from the financing view still writes when the window crossed "
      "the compact breakpoint under the open dialog", (tester) async {
    await harness.seedResource("Lent camera", 40000);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, harness.menuInRowOf(tester, "Lent camera"));
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<String>, tr.budgetFinancingEditAction),
    );
    await tester.enterText(inDialog(find.byType(TextFormField)).first, "Borrowed camera");
    await tester.pumpAndSettle();

    await shrinkWindow(tester);
    await harness.tap(tester, inDialog(find.text(tr.budgetEntryDialogConfirmAction)));

    final resources = await harness.readResources();
    expect(resources.map((resource) => resource.label), ["Borrowed camera"]);
  });
}
