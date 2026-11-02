// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_dashboard.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_status_bar.dart';

import 'budget_mode_scenarios_test_doubles.dart';

/// Run the tests of the budget mode views scenarios.
void main() {
  final harness = BudgetScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds [target] inside the detail panel of the right dock.
  Finder inDetail(Finder target) =>
      find.descendant(of: find.byType(OcptBudgetDetail), matching: target);

  /// Finds [target] inside the header band.
  Finder inHeader(Finder target) =>
      find.descendant(of: find.byType(OcptBudgetHeader), matching: target);

  /// Reads the status bar at the bottom of the workspace.
  OcptBudgetStatusBar statusBar(WidgetTester tester) =>
      tester.widget<OcptBudgetStatusBar>(find.byType(OcptBudgetStatusBar));

  /// Opens the expenses table, then the twisty of its first poste.
  Future<void> openExpensesExpanded(WidgetTester tester) async {
    await harness.tapHeader(tester, harness.trOf(tester).budgetHeaderExpensesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
  }

  /// Seeds poste "Camera" holding the quote line "Camera deposit" (100.00), the off-line
  /// commitment "Lens order" (30.00) and the debit "Taxi" (15.00), returning the ids in that
  /// order.
  Future<(String, String, String, String)> seedCamera() async {
    final posteId = await harness.seedPoste("Camera");
    final lineId = await harness.seedLine(posteId, "Camera deposit");
    final commitmentId = await harness.seedCommitment(posteId, "Lens order", amountCents: 3000);
    final entryId = await harness.seedDebit("Taxi", 1500, posteId: posteId);
    return (posteId, lineId, commitmentId, entryId);
  }

  testWidgets("the mode shows a spinner, then the dashboard with the ten CNC postes seeded and "
      "the right dock shut, and entering it again seeds nothing more", (tester) async {
    tester.view.physicalSize = const Size(1750, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness.wrap(const OcptBudgetMode()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    final tr = harness.trOf(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("My Movie"), findsOneWidget);
    expect(find.byType(OcptBudgetDashboard), findsOneWidget);
    expect(find.byType(OcptBudgetCostTracking), findsNothing);
    expect(statusBar(tester).posteCount, 10);
    expect(statusBar(tester).lineCount, 0);
    expect(find.byTooltip(tr.budgetRightDockCloseTooltip), findsNothing);
    expect(find.byType(OcptBudgetDetail), findsNothing);
    final seeded = await harness.readPostes();
    expect(seeded, hasLength(10));
    expect(seeded.map((poste) => poste.label), contains(tr.budgetCncPosteArtisticRights));

    await harness.unmount(tester);
    await tester.pumpWidget(harness.wrap(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    expect(await harness.readPostes(), hasLength(10));
    expect(statusBar(tester).posteCount, 10);
  });

  testWidgets("a project that already holds a poste is not seeded with the CNC nomenclature, and "
      "its lines and figures are what the status bar counts", (tester) async {
    final posteId = await harness.seedPoste("Camera");
    await harness.seedLine(posteId, "Camera deposit");
    await harness.seedLine(posteId, "Lens rental", unitAmountCents: 2500);
    await harness.mount(tester);

    expect(await harness.readPostes(), hasLength(1));
    expect(statusBar(tester).posteCount, 1);
    expect(statusBar(tester).lineCount, 2);
    expect(statusBar(tester).quotedTotalCents, 12500);
  });

  testWidgets("each chip lands on its own view, and the tools drawer opens on the page it was "
      "last left on", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(inHeader(find.text(tr.budgetHeaderCashFlowSegmentLabel)), findsNothing);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    expect(find.byType(OcptBudgetCostTracking), findsOneWidget);
    expect(find.byType(OcptBudgetDashboard), findsNothing);
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    expect(find.byType(OcptBudgetFinancing), findsOneWidget);

    // The drawer opens on the cash flow page, and shows its own three-way switch.
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    expect(find.byType(OcptBudgetCashJournal), findsOneWidget);
    expect(inHeader(find.text(tr.budgetHeaderRegieSegmentLabel)), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderRegieSegmentLabel);
    expect(find.byType(OcptBudgetRegie), findsOneWidget);

    // Leaving the drawer hides its switch, and coming back lands on the page left, not the first.
    await harness.tapHeader(tester, tr.budgetHeaderDashboardSegmentLabel);
    expect(find.byType(OcptBudgetDashboard), findsOneWidget);
    expect(inHeader(find.text(tr.budgetHeaderRegieSegmentLabel)), findsNothing);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    expect(find.byType(OcptBudgetRegie), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderSharingSegmentLabel);
    expect(find.byType(OcptBudgetSharing), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    expect(find.byType(OcptBudgetSharing), findsOneWidget);
  });

  testWidgets("the simplified switch and the expanded rows outlive a trip through another view", (
    tester,
  ) async {
    await seedCamera();
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openExpensesExpanded(tester);
    expect(find.text("Camera deposit"), findsOneWidget);

    await harness.tap(tester, find.text(tr.budgetHeaderSimplifiedSegmentLabel));
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    expect(find.byType(OcptBudgetCostTracking), findsNothing);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);

    // The poste is still opened, and the simplified switch is still on: the Camera poste carries
    // no simple label, so its own label stands, and the "N°" column stays gone.
    expect(find.text("Camera deposit"), findsOneWidget);
    expect(find.text("Camera"), findsOneWidget);
    expect(find.text(tr.budgetCostTrackingColumnNumber), findsNothing);
    await harness.tap(tester, find.text(tr.budgetHeaderDetailedSegmentLabel));
    expect(find.text(tr.budgetCostTrackingColumnNumber), findsOneWidget);
  });

  testWidgets("selecting a poste, a line, a commitment and an entry in the expenses table each "
      "replace the fiche and open the right dock", (tester) async {
    await seedCamera();
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openExpensesExpanded(tester);
    expect(find.byTooltip(tr.budgetRightDockCloseTooltip), findsNothing);

    await harness.tap(tester, find.text("Camera").first);
    expect(find.byTooltip(tr.budgetRightDockCloseTooltip), findsOneWidget);
    expect(
      inDetail(find.text(tr.budgetInspectorPosteCodeFieldLabel.toUpperCase())),
      findsOneWidget,
    );

    await harness.tap(tester, find.text("Camera deposit"));
    expect(inDetail(find.text(tr.budgetInspectorPosteCodeFieldLabel.toUpperCase())), findsNothing);
    expect(inDetail(find.text(tr.budgetLineQuantityFieldLabel.toUpperCase())), findsOneWidget);
    expect(inDetail(find.text("Camera deposit")), findsWidgets);

    await harness.tap(tester, find.text("Lens order"));
    expect(inDetail(find.text(tr.budgetLineQuantityFieldLabel.toUpperCase())), findsNothing);
    expect(inDetail(find.text(tr.budgetDetailKindCommitmentLabel)), findsOneWidget);
    expect(inDetail(find.text("Lens order")), findsOneWidget);

    await harness.tap(tester, find.text("Taxi"));
    expect(inDetail(find.text(tr.budgetDetailKindCommitmentLabel)), findsNothing);
    expect(inDetail(find.text(tr.budgetDetailKindEntryLabel)), findsOneWidget);
    expect(inDetail(find.text("Taxi")), findsOneWidget);
  });

  testWidgets("the cash flow page selects entries and upcoming commitments, and a selection made "
      "there opens the right dock even from the Help tab", (tester) async {
    await seedCamera();
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await harness.tap(tester, find.text(tr.budgetRightDockHelpTabLabel));
    expect(find.byType(OcptBudgetDetail), findsNothing);

    await harness.tap(tester, find.text("Taxi"));
    expect(inDetail(find.text(tr.budgetDetailKindEntryLabel)), findsOneWidget);

    await harness.tap(tester, find.text("Lens order"));
    expect(inDetail(find.text(tr.budgetDetailKindEntryLabel)), findsNothing);
    expect(inDetail(find.text(tr.budgetDetailKindCommitmentLabel)), findsOneWidget);
  });

  testWidgets("the resources tree selects a contribution, a taking and a receipt, one at a time", (
    tester,
  ) async {
    final resourceId = await harness.seedResource("Regional grant", 20000);
    await harness.seedRevenue("Festival prize", 9000);
    await harness.projectsManager.budgetJournalService.createEntry(
      database: harness.database,
      date: DateTime(2026),
      label: "Grant instalment",
      resourceId: resourceId,
      creditCents: 4000,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    // The takings family opens on its own twisty, then the subsidies one and its contribution.
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).last);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);

    await harness.tap(tester, find.text("Regional grant"));
    expect(inDetail(find.text("Regional grant")), findsOneWidget);
    expect(inDetail(find.text(tr.budgetFinancingEditAction)), findsOneWidget);

    await harness.tap(tester, find.text("Festival prize"));
    expect(inDetail(find.text("Regional grant")), findsNothing);
    expect(inDetail(find.text("Festival prize")), findsOneWidget);

    await harness.tap(tester, find.textContaining("Grant instalment"));
    expect(inDetail(find.text("Festival prize")), findsNothing);
    expect(inDetail(find.text("Grant instalment")), findsOneWidget);
    expect(inDetail(find.text(tr.budgetDetailKindEntryLabel)), findsOneWidget);
  });

  testWidgets("a share is highlighted in the sharing page without opening a fiche of its own", (
    tester,
  ) async {
    await harness.seedShare("Producer");
    await harness.seedShare("Director", sharePermille: 300);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderSharingSegmentLabel);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);

    await harness.tap(tester, find.text("Producer"));
    // The dock stays on its empty hint, a share having no detail panel, and the selection leaves
    // the hint alone.
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    final highlighted = tester.widget<OcptBudgetSharing>(find.byType(OcptBudgetSharing));
    expect(highlighted.selectedShareId, (await harness.readShares()).first.id);

    await harness.tap(tester, find.text("Director"));
    expect(
      tester.widget<OcptBudgetSharing>(find.byType(OcptBudgetSharing)).selectedShareId,
      (await harness.readShares()).last.id,
    );
  });

  testWidgets("a chip drops the selection while a link that selects and switches keeps it", (
    tester,
  ) async {
    final (_, lineId, _, _) = await seedCamera();
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openExpensesExpanded(tester);
    await harness.tap(tester, find.text("Camera deposit"));
    expect(inDetail(find.text(tr.budgetLineQuantityFieldLabel.toUpperCase())), findsOneWidget);

    // Leaving for the resources chip drops the line: the dock stays open but empty, and the line
    // is not selected any more when coming back.
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);

    // The tools drawer's own page switch drops it too.
    await harness.tap(tester, find.text("Camera deposit"));
    expect(inDetail(find.text(tr.budgetLineQuantityFieldLabel.toUpperCase())), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    await harness.tap(tester, find.text("Lens order"));
    expect(inDetail(find.text(tr.budgetDetailKindCommitmentLabel)), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderSharingSegmentLabel);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);

    // The line's own "Show commitment" link switches view and selects in one gesture: nothing
    // is dropped along the way, and the commitment's detail panel is what the dock then shows.
    final promotedLineId = await harness.seedLine(
      (await harness.readPostes()).first.id,
      "Promoted line",
    );
    await harness.seedCommitment(
      (await harness.readPostes()).first.id,
      "Promoted order",
      lineId: promotedLineId,
    );
    await harness.unmount(tester);
    await harness.mount(tester);
    await openExpensesExpanded(tester);
    await harness.tap(tester, find.text("Promoted line"));
    await harness.tap(tester, inDetail(find.text(tr.budgetLineShowCommitmentAction)));
    expect(find.byType(OcptBudgetCashJournal), findsOneWidget);
    expect(inDetail(find.text(tr.budgetDetailKindCommitmentLabel)), findsOneWidget);
    expect(inDetail(find.text("Promoted order")), findsOneWidget);
    expect(lineId, isNotEmpty);
  });
}
