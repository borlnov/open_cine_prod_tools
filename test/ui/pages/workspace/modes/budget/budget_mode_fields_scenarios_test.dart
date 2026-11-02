// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_status_bar.dart';

import 'budget_mode_scenarios_test_doubles.dart';

/// Run the tests of the budget mode fields scenarios.
void main() {
  final harness = BudgetScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds [target] inside the fiche of the right dock.
  Finder inFiche(Finder target) =>
      find.descendant(of: find.byType(OcptBudgetFiche), matching: target);

  /// Finds [target] inside the expenses table.
  Finder inTracking(Finder target) =>
      find.descendant(of: find.byType(OcptBudgetCostTracking), matching: target);

  /// Reads the status bar at the bottom of the workspace.
  OcptBudgetStatusBar statusBar(WidgetTester tester) =>
      tester.widget<OcptBudgetStatusBar>(find.byType(OcptBudgetStatusBar));

  /// Reads the text a fiche field captioned [label] holds.
  String fieldText(WidgetTester tester, String label) =>
      tester.widget<TextField>(harness.fieldLabelled(label)).controller!.text;

  /// Opens the expenses table on a project holding poste "Camera" and poste "Sound", selecting
  /// "Camera", and returns the id of "Camera".
  Future<String> openCameraFiche(WidgetTester tester) async {
    final cameraId = await harness.seedPoste("Camera");
    await harness.seedPoste("Sound");
    await harness.mount(tester);
    await harness.tapHeader(tester, harness.trOf(tester).budgetHeaderExpensesSegmentLabel);
    await harness.tap(tester, inTracking(find.text("Camera")));

    return cameraId;
  }

  /// Opens the expenses table on a project holding poste "Camera" with the line "Camera deposit",
  /// selecting that line.
  Future<String> openLineFiche(WidgetTester tester) async {
    final posteId = await harness.seedPoste("Camera");
    final lineId = await harness.seedLine(posteId, "Camera deposit");
    await harness.mount(tester);
    await harness.tapHeader(tester, harness.trOf(tester).budgetHeaderExpensesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, find.text("Camera deposit"));

    return lineId;
  }

  testWidgets("a poste label typed in the fiche shows there at once, and reaches the table and "
      "the database once the debounce has run out", (tester) async {
    await openCameraFiche(tester);
    final tr = harness.trOf(tester);

    await harness.type(
      tester,
      harness.fieldLabelled(tr.budgetInspectorPosteLabelFieldLabel),
      "Camera crew",
    );
    expect(fieldText(tester, tr.budgetInspectorPosteLabelFieldLabel), "Camera crew");
    await tester.pump(const Duration(milliseconds: 1500));
    expect((await harness.readPostes()).map((poste) => poste.label), ["Camera", "Sound"]);
    expect(inTracking(find.text("Camera crew")), findsNothing);

    await harness.letDebounceRun(tester);
    expect((await harness.readPostes()).map((poste) => poste.label), ["Camera crew", "Sound"]);
    expect(inTracking(find.text("Camera crew")), findsOneWidget);
    expect(fieldText(tester, tr.budgetInspectorPosteLabelFieldLabel), "Camera crew");
  });

  testWidgets("a field typed a moment ago is written first by a row pick, a chip, a switch, a "
      "tab or a filter, none of which waits for the debounce", (tester) async {
    await openCameraFiche(tester);
    final tr = harness.trOf(tester);
    final labelField = harness.fieldLabelled(tr.budgetInspectorPosteLabelFieldLabel);

    /// Types [value] into the label, runs [trigger] and waits for the label to land in the
    /// database, then runs [restore] and selects "Camera" again.
    Future<void> check(
      String value,
      Future<void> Function() trigger, {
      Future<void> Function()? restore,
    }) async {
      await harness.type(tester, labelField, value);
      expect((await harness.readPostes()).first.label, isNot(value));
      await trigger();
      await harness.eventually(
        tester,
        () async => (await harness.readPostes()).first.label == value,
        reason: "after typing $value",
      );
      await restore?.call();
      await harness.tap(tester, inTracking(find.text(value)));
    }

    await check("A", () => harness.tapQuickly(tester, inTracking(find.text("Sound"))));
    await check(
      "B",
      () => harness.tapHeaderQuickly(tester, tr.budgetHeaderResourcesSegmentLabel),
      restore: () => harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel),
    );
    await check(
      "C",
      () => harness.tapQuickly(tester, find.text(tr.budgetHeaderSimplifiedSegmentLabel)),
    );
    await check(
      "D",
      () => harness.tapQuickly(tester, find.text(tr.budgetHeaderExcludingTaxSegmentLabel)),
    );
    await check("E", () => harness.tapQuickly(tester, find.text(tr.budgetRightDockHelpTabLabel)));
    await check("F", () async {
      await harness.tapOpening(
        tester,
        harness.menuInRowOf(tester, "E", within: find.byType(OcptBudgetCostTracking)),
      );
      await harness.tapQuickly(
        tester,
        find.widgetWithText(PopupMenuItem<String>, tr.budgetCostTrackingFilterOnlyAction),
      );
    });
    await harness.letDebounceRun(tester);
  });

  testWidgets("leaving the mode with a field still pending writes it straight away", (
    tester,
  ) async {
    await openCameraFiche(tester);
    final tr = harness.trOf(tester);

    await harness.type(
      tester,
      harness.fieldLabelled(tr.budgetInspectorPosteLabelFieldLabel),
      "Camera crew",
    );
    expect((await harness.readPostes()).first.label, "Camera");
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.eventually(
      tester,
      () async => (await harness.readPostes()).first.label == "Camera crew",
    );
  });

  testWidgets("a figure that does not parse is skipped and the field falls back to what is "
      "stored, while valid figures are stored as cents, thousandths and basis points", (
    tester,
  ) async {
    final lineId = await openLineFiche(tester);
    final tr = harness.trOf(tester);
    expect(lineId, isNotEmpty);

    await harness.type(tester, harness.fieldLabelled(tr.budgetLineQuantityFieldLabel), "abc");
    await harness.type(tester, harness.fieldLabelled(tr.budgetLineUnitPriceFieldLabel), "twelve");
    await harness.letDebounceRun(tester);
    var line = (await harness.readPoste("Camera")).lines.single;
    expect(line.quantityMilli, 1000);
    expect(line.unitPrice.amountCents, 10000);
    expect(fieldText(tester, tr.budgetLineQuantityFieldLabel), "1");
    expect(fieldText(tester, tr.budgetLineUnitPriceFieldLabel), "100.00");

    await harness.type(tester, harness.fieldLabelled(tr.budgetLineQuantityFieldLabel), "2.5");
    await harness.type(tester, harness.fieldLabelled(tr.budgetLineUnitPriceFieldLabel), "12.50");
    await harness.type(tester, harness.fieldLabelled(tr.budgetLineVatRateFieldLabel), "20");
    await harness.type(tester, harness.fieldLabelled(tr.budgetLineUnitFieldLabel), "day");
    await harness.type(tester, harness.fieldLabelled(tr.budgetLineNotesFieldLabel), "Two crews");
    await harness.letDebounceRun(tester);
    line = (await harness.readPoste("Camera")).lines.single;
    expect(line.quantityMilli, 2500);
    expect(line.unitPrice.amountCents, 1250);
    expect(line.unitPrice.vatRateBasisPoints, 2000);
    expect(line.unit, "day");
    expect(line.notes, "Two crews");
    // The quote total follows: 2.5 x 12.50, in the status bar and the table.
    expect(statusBar(tester).quotedTotalCents, 3125);
    expect(inTracking(find.text(r"$31.25")), findsWidgets);
  });

  testWidgets("several fields typed together are all written, and a typed figure shows in "
      "another view the moment its chip is picked", (tester) async {
    final lineId = await openLineFiche(tester);
    final tr = harness.trOf(tester);
    expect(lineId, isNotEmpty);

    await harness.type(tester, harness.fieldLabelled(tr.budgetLineLabelFieldLabel), "Rental");
    await harness.type(tester, harness.fieldLabelled(tr.budgetLineUnitPriceFieldLabel), "40");
    await harness.tapHeaderQuickly(tester, tr.budgetHeaderResourcesSegmentLabel);
    await harness.eventually(
      tester,
      () async => (await harness.readPoste("Camera")).lines.single.label == "Rental",
    );
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    expect((await harness.readPoste("Camera")).lines.single.unitPrice.amountCents, 4000);
    expect(statusBar(tester).quotedTotalCents, 4000);

    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    expect(find.text("Rental"), findsOneWidget);
  });

  testWidgets("the estimate to complete is typed, then handed back to its derivation at once", (
    tester,
  ) async {
    await openCameraFiche(tester);
    final tr = harness.trOf(tester);

    await harness.type(
      tester,
      harness.fieldLabelled(tr.budgetInspectorPosteEstimateToCompleteFieldLabel),
      "500",
    );
    await harness.letDebounceRun(tester);
    expect((await harness.readPoste("Camera")).estimateToCompleteCents, 50000);
    expect(inFiche(find.text(r"$500.00")), findsWidgets);

    await harness.tap(
      tester,
      inFiche(find.text(tr.budgetInspectorPosteEstimateToCompleteDeriveAction)),
    );
    expect((await harness.readPoste("Camera")).estimateToCompleteCents, isNull);
  });

  testWidgets("a line's tax basis and its inherited VAT rate are written the moment they are "
      "picked", (tester) async {
    await openLineFiche(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.fieldLabelled(tr.budgetLineVatRateFieldLabel), "10");
    await harness.letDebounceRun(tester);
    expect((await harness.readPoste("Camera")).lines.single.unitPrice.vatRateBasisPoints, 1000);

    await harness.tap(tester, inFiche(find.text(tr.budgetLineVatRateInheritAction)));
    expect((await harness.readPoste("Camera")).lines.single.unitPrice.vatRateBasisPoints, isNull);

    await harness.tap(tester, inFiche(find.text(tr.budgetLineTaxExclusiveOption)));
    expect((await harness.readPoste("Camera")).lines.single.unitPrice.isTaxInclusive, isFalse);
    await harness.tap(tester, inFiche(find.text(tr.budgetLineTaxInclusiveOption)));
    expect((await harness.readPoste("Camera")).lines.single.unitPrice.isTaxInclusive, isTrue);
  });
}
