// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_status_bar.dart';

import 'budget_mode_scenarios_test_doubles.dart';

/// The stable id of the CNC account the catering and travel provisioning starts out pointed at.
const _logisticsAccountId = "d75aa74c-ed99-494a-bca0-3508b166ec18";

/// Run the tests of the budget mode reconcile scenarios.
void main() {
  final harness = BudgetScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds [target] inside the detail panel of the right dock.
  Finder inDetail(Finder target) =>
      find.descendant(of: find.byType(OcptBudgetDetail), matching: target);

  /// Finds [target] inside the expenses table.
  Finder inTracking(Finder target) =>
      find.descendant(of: find.byType(OcptBudgetCostTracking), matching: target);

  /// Reads what the detail panel of the right dock was handed as the selection, null while nothing
  /// is selected: a deleted row must not stay selected behind an empty detail panel.
  Object? selectionOf(WidgetTester tester) =>
      tester.widget<OcptBudgetDetail>(find.byType(OcptBudgetDetail)).selection;

  /// Reads the status bar at the bottom of the workspace.
  OcptBudgetStatusBar statusBar(WidgetTester tester) =>
      tester.widget<OcptBudgetStatusBar>(find.byType(OcptBudgetStatusBar));

  /// Opens the expenses table, then the twisty of its first account.
  Future<void> openExpensesExpanded(WidgetTester tester) async {
    await harness.tapHeader(tester, harness.trOf(tester).budgetHeaderExpensesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
  }

  /// Picks [label] from the `⋮` menu of the row naming [rowLabel], then lets the menu close.
  Future<void> pickRowMenu(
    WidgetTester tester,
    String rowLabel,
    String label, {
    Finder? within,
  }) async {
    await harness.tap(tester, harness.menuInRowOf(tester, rowLabel, within: within));
    await harness.tap(tester, find.widgetWithText(PopupMenuItem<String>, label));
  }

  testWidgets("deleting the poste the table is filtered on and the fiche shows asks first, then "
      "clears the fiche and the filter", (tester) async {
    final cameraId = await harness.seedAccount("Camera");
    await harness.seedAccount("Sound");
    await harness.seedLine(cameraId, "Camera deposit");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);

    await harness.tap(tester, inTracking(find.text("Camera")));
    expect(
      inDetail(find.text(tr.budgetInspectorAccountCodeFieldLabel.toUpperCase())),
      findsOneWidget,
    );
    expect(selectionOf(tester), isNotNull);
    await pickRowMenu(
      tester,
      "Camera",
      tr.budgetCostTrackingFilterOnlyAction,
      within: find.byType(OcptBudgetCostTracking),
    );
    expect(inTracking(find.text("Sound")), findsNothing);

    // Cancelling keeps the account, the detail panel and the filter as they were.
    await pickRowMenu(
      tester,
      "Camera",
      tr.budgetAccountDeleteAction,
      within: find.byType(OcptBudgetCostTracking),
    );
    expect(find.text(tr.budgetDeleteAccountConfirmTitle), findsOneWidget);
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect(await harness.readAccounts(), hasLength(2));
    expect(
      inDetail(find.text(tr.budgetInspectorAccountCodeFieldLabel.toUpperCase())),
      findsOneWidget,
    );
    expect(inTracking(find.text("Sound")), findsNothing);

    // Confirming deletes it with its lines; nothing selected, nothing filtered any more.
    await pickRowMenu(
      tester,
      "Camera",
      tr.budgetAccountDeleteAction,
      within: find.byType(OcptBudgetCostTracking),
    );
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect((await harness.readAccounts()).map((account) => account.label), ["Sound"]);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    expect(selectionOf(tester), isNull);
    expect(inTracking(find.text("Camera")), findsNothing);
    expect(inTracking(find.text("Sound")), findsOneWidget);
    expect(statusBar(tester).accountCount, 1);
    expect(statusBar(tester).lineCount, 0);
    expect(find.byTooltip(tr.budgetHeaderAccountFilterClearTooltip), findsNothing);
  });

  testWidgets("a poste filter narrows the expenses table alone, outlives the other views and is "
      "lifted by its chip", (tester) async {
    final cameraId = await harness.seedAccount("Camera");
    await harness.seedAccount("Sound");
    await harness.seedDebit("Taxi", 1500, accountId: cameraId);
    await harness.seedDebit("Mic", 900, accountId: (await harness.readAccounts()).last.id);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);

    await pickRowMenu(tester, "Sound", tr.budgetCostTrackingFilterOnlyAction);
    expect(inTracking(find.text("Camera")), findsNothing);
    expect(inTracking(find.text("Sound")), findsOneWidget);
    // Selecting an account is not filtering by it.
    expect(find.text(tr.budgetDetailEmptyHint), findsNothing);

    // The cash flow page reads the whole account, whatever the filter says.
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    expect(find.text("Taxi"), findsOneWidget);
    expect(find.text("Mic"), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    expect(inTracking(find.text("Camera")), findsNothing);

    await harness.tap(tester, find.byTooltip(tr.budgetHeaderAccountFilterClearTooltip));
    expect(inTracking(find.text("Camera")), findsOneWidget);
    expect(inTracking(find.text("Sound")), findsOneWidget);
  });

  testWidgets("deleting the selected quote line from its fiche asks first, then empties the "
      "fiche and keeps the poste", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedLine(accountId, "Camera deposit");
    await harness.seedLine(accountId, "Lens rental", unitAmountCents: 2500);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openExpensesExpanded(tester);

    await harness.tap(tester, find.text("Camera deposit"));
    await harness.tap(tester, inDetail(find.text(tr.budgetLineDeleteAction)));
    expect(find.text(tr.budgetDeleteLineConfirmTitle), findsOneWidget);
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect((await harness.readAccount("Camera")).lines, hasLength(2));
    expect(statusBar(tester).lineCount, 2);

    await harness.tap(tester, inDetail(find.text(tr.budgetLineDeleteAction)));
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect((await harness.readAccount("Camera")).lines.map((line) => line.label), ["Lens rental"]);
    expect(find.text("Camera deposit"), findsNothing);
    expect(find.text("Lens rental"), findsOneWidget);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    expect(selectionOf(tester), isNull);
    expect(statusBar(tester).lineCount, 1);
    expect(statusBar(tester).quotedTotalCents, 2500);
  });

  testWidgets("deleting the selected entry or commitment from its fiche empties the fiche, and "
      "an entry deleted while another row is selected leaves that selection alone", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedCommitment(accountId, "Lens order", amountCents: 3000);
    await harness.seedDebit("Taxi", 1500, accountId: accountId);
    await harness.seedDebit("Coffee", 700);
    await harness.seedDebit("Late fee", 300);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);

    await harness.tap(tester, find.text("Coffee"));
    await harness.tap(tester, inDetail(find.text(tr.budgetEntryDeleteAction)));
    expect(find.text(tr.budgetDeleteEntryConfirmTitle), findsOneWidget);
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect(await harness.readEntries(), hasLength(3));
    await harness.tap(tester, inDetail(find.text(tr.budgetEntryDeleteAction)));
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect((await harness.readEntries()).map((entry) => entry.label), ["Taxi", "Late fee"]);
    expect(find.text("Coffee"), findsNothing);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    expect(selectionOf(tester), isNull);

    // A commitment selected under "Upcoming" goes the same way.
    await harness.tap(tester, find.text("Lens order"));
    expect(inDetail(find.text(tr.budgetDetailKindCommitmentLabel)), findsOneWidget);
    await harness.tap(tester, inDetail(find.text(tr.budgetCommittedDeleteAction)));
    expect(find.text(tr.budgetDeleteCommitmentConfirmTitle), findsOneWidget);
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect(await harness.readCommitments(), hasLength(1));
    await harness.tap(tester, inDetail(find.text(tr.budgetCommittedDeleteAction)));
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect(await harness.readCommitments(), isEmpty);
    expect(find.text("Lens order"), findsNothing);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    expect(selectionOf(tester), isNull);

    // Deleting a row from its menu while the detail panel shows another leaves the detail panel on
    // its own row.
    await harness.tap(tester, find.text("Taxi"));
    await pickRowMenu(tester, "Late fee", tr.budgetEntryDeleteAction);
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect((await harness.readEntries()).map((entry) => entry.label), ["Taxi"]);
    expect(inDetail(find.text("Taxi")), findsOneWidget);
  });

  testWidgets("deleting an in-kind contribution takes its counterpart quote line with it, and "
      "empties the fiche that showed it", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedLine(accountId, "Camera deposit");
    final resourceId = await harness.seedResource("Lent camera", 40000);
    await harness.projectsManager.budgetFinancingService.updateResource(
      database: harness.database,
      resourceId: resourceId,
      groupKind: const Value(OcptBudgetResourceGroupKind.inKind),
    );
    await harness.projectsManager.budgetQuoteService.createLine(
      database: harness.database,
      accountId: accountId,
      label: "Lent camera",
      quantityMilli: const Value(1000),
      unitAmountCents: const Value(40000),
      inKindResourceId: Value(resourceId),
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(statusBar(tester).lineCount, 2);
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, find.text("Lent camera"));
    expect(inDetail(find.text("Lent camera")), findsOneWidget);

    await harness.tap(tester, inDetail(find.text(tr.budgetCommittedDeleteAction)));
    expect(find.text(tr.budgetDeleteResourceConfirmTitle), findsOneWidget);
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect(await harness.readResources(), hasLength(1));
    expect(statusBar(tester).lineCount, 2);

    await harness.tap(tester, inDetail(find.text(tr.budgetCommittedDeleteAction)));
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect(await harness.readResources(), isEmpty);
    expect((await harness.readAccount("Camera")).lines.map((line) => line.label), [
      "Camera deposit",
    ]);
    expect(statusBar(tester).lineCount, 1);
    expect(statusBar(tester).quotedTotalCents, 10000);
    expect(find.text("Lent camera"), findsNothing);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    expect(selectionOf(tester), isNull);
  });

  testWidgets("deleting a selected taking empties the fiche, and deleting the highlighted share "
      "drops the highlight", (tester) async {
    await harness.seedRevenue("Festival prize", 9000);
    await harness.seedShare("Producer");
    await harness.seedShare("Director", sharePermille: 300);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, find.text("Festival prize"));
    expect(inDetail(find.text("Festival prize")), findsOneWidget);
    await harness.tap(tester, inDetail(find.text(tr.budgetCommittedDeleteAction)));
    expect(find.text(tr.budgetDeleteRevenueConfirmTitle), findsOneWidget);
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect(await harness.readRevenues(), hasLength(1));
    await harness.tap(tester, inDetail(find.text(tr.budgetCommittedDeleteAction)));
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect(await harness.readRevenues(), isEmpty);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    expect(selectionOf(tester), isNull);

    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderSharingSegmentLabel);
    await harness.tap(tester, find.text("Producer"));
    final producerId = (await harness.readShares()).first.id;
    expect(
      tester.widget<OcptBudgetSharing>(find.byType(OcptBudgetSharing)).selectedShareId,
      producerId,
    );
    await pickRowMenu(tester, "Producer", tr.budgetCommittedDeleteAction);
    expect(find.text(tr.budgetDeleteShareConfirmTitle), findsOneWidget);
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect(await harness.readShares(), hasLength(2));
    expect(
      tester.widget<OcptBudgetSharing>(find.byType(OcptBudgetSharing)).selectedShareId,
      producerId,
    );
    await pickRowMenu(tester, "Producer", tr.budgetCommittedDeleteAction);
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect((await harness.readShares()).map((share) => share.label), ["Director"]);
    expect(
      tester.widget<OcptBudgetSharing>(find.byType(OcptBudgetSharing)).selectedShareId,
      isNull,
    );
  });

  testWidgets("undoing the receipt that is selected tombstones its entry and empties the fiche, "
      "while a write that leaves the selection standing keeps it", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedLine(accountId, "Camera deposit");
    final resourceId = await harness.seedResource("Regional grant", 20000);
    await harness.projectsManager.budgetJournalService.createEntry(
      database: harness.database,
      date: DateTime(2026),
      label: "Grant instalment",
      resourceId: resourceId,
      creditCents: 4000,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    // A write that leaves the selected line standing keeps the detail panel on it.
    await openExpensesExpanded(tester);
    await harness.tap(tester, find.text("Camera deposit"));
    await harness.tap(tester, inDetail(find.text(tr.budgetLineTaxExclusiveOption)));
    expect((await harness.readAccount("Camera")).lines.single.unitPrice.isTaxInclusive, isFalse);
    expect(inDetail(find.text(tr.budgetLineQuantityFieldLabel.toUpperCase())), findsOneWidget);

    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, find.textContaining("Grant instalment"));
    expect(inDetail(find.text("Grant instalment")), findsOneWidget);

    await pickRowMenu(tester, "Regional grant", tr.budgetFinancingUndoReceiptAction);
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect(await harness.readEntries(), isEmpty);
    expect(find.textContaining("Grant instalment"), findsNothing);
    expect(find.text(tr.budgetDetailEmptyHint), findsOneWidget);
    expect(selectionOf(tester), isNull);
  });

  testWidgets("the poste the catering provisioning points at follows a deletion, falling back "
      "from the transport poste to the first one", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderLogisticsSegmentLabel);
    OcptBudgetLogistics logistics() =>
        tester.widget<OcptBudgetLogistics>(find.byType(OcptBudgetLogistics));
    expect(logistics().provisionAccountId, _logisticsAccountId);

    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    await pickRowMenu(
      tester,
      tr.budgetCncAccountTransportPerDiemsLogistics,
      tr.budgetAccountDeleteAction,
    );
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderLogisticsSegmentLabel);
    expect(logistics().provisionAccountId, (await harness.readAccounts()).first.id);
    expect(logistics().provisionAccountId, isNot(_logisticsAccountId));
  });
}
