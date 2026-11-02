// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Run the tests of the budget mode writes scenarios.
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

  /// Finds [target] inside the capture wizard.
  Finder inWizard(Finder target) => find.descendant(of: find.byType(Dialog), matching: target);

  /// Reads the status bar at the bottom of the workspace.
  OcptBudgetStatusBar statusBar(WidgetTester tester) =>
      tester.widget<OcptBudgetStatusBar>(find.byType(OcptBudgetStatusBar));

  /// Opens the expenses table, then the twisty of its first account.
  Future<void> openExpensesExpanded(WidgetTester tester) async {
    await harness.tapHeader(tester, harness.trOf(tester).budgetHeaderExpensesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
  }

  /// Opens the capture wizard from the header's `New` button and continues past step 1, whose
  /// first card the current view has already picked.
  Future<void> openWizard(WidgetTester tester, {String? gesture}) async {
    await harness.tap(tester, find.byKey(const Key("ocptBudgetHeaderCaptureButton")));
    if (gesture != null) {
      await harness.tap(tester, find.byKey(Key("ocptBudgetNewGestureCard-$gesture")));
    }
    await harness.tap(tester, find.byKey(const Key("ocptBudgetNewContinueButton")));
  }

  /// Types [values] into the first text fields of the wizard's form, in order.
  Future<void> fillWizard(WidgetTester tester, List<String> values) async {
    final fields = inWizard(find.byType(TextFormField));
    for (var index = 0; index < values.length; index++) {
      await tester.enterText(fields.at(index), values[index]);
    }
    await tester.pumpAndSettle();
  }

  /// Saves the wizard's form.
  Future<void> saveWizard(WidgetTester tester) =>
      harness.tap(tester, find.byKey(const Key("ocptBudgetNewSaveButton")));

  testWidgets("paying a quote line directly writes the commitment it implies and the debit that "
      "settles it, and the payment shows in the journal and in the line's own fiche", (
    tester,
  ) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedLine(accountId, "Camera deposit");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openExpensesExpanded(tester);
    await harness.tap(tester, inTracking(find.text("Camera deposit")));

    // Cancelling the wizard that the gesture opens writes nothing.
    await harness.tap(tester, inDetail(find.text(tr.budgetDetailPayAction(r"$100.00"))));
    await harness.tap(tester, inWizard(find.text(tr.budgetEntryDialogCancelAction)));
    expect(await harness.readEntries(), isEmpty);
    expect(await harness.readCommitments(), isEmpty);

    await harness.tap(tester, inDetail(find.text(tr.budgetDetailPayAction(r"$100.00"))));
    await harness.tap(tester, inWizard(find.text(tr.budgetEntryDialogConfirmAction)));
    final commitment = (await harness.readCommitments()).single;
    final entry = (await harness.readEntries()).single;
    expect(commitment.label, "Camera deposit");
    expect(commitment.amount.amountCents, 10000);
    expect(commitment.accountId, accountId);
    expect(commitment.lineId, isNotNull);
    expect(entry.debitCents, 10000);
    expect(entry.commitmentId, commitment.id);
    expect(entry.accountId, accountId);

    // The detail panel stays on the line, which now lists its payment and no longer offers to pay
    // it.
    expect(inDetail(find.text(tr.budgetDetailPayAction(r"$100.00"))), findsNothing);
    expect(inDetail(find.text(r"$100.00")), findsWidgets);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    expect(find.text("Camera deposit"), findsOneWidget);
    // Nothing is left to come: the settled commitment is not listed as upcoming.
    expect(find.text(tr.budgetCashUpcomingSectionTitle), findsNothing);
  });

  testWidgets("committing a quote line, then paying it, then undoing that settlement moves the "
      "commitment between upcoming and settled while the entry stays", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedLine(accountId, "Camera deposit");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openExpensesExpanded(tester);
    await harness.tap(tester, inTracking(find.text("Camera deposit")));

    await harness.tap(tester, inDetail(find.text(tr.budgetLineCommitAction)));
    await harness.tap(tester, inWizard(find.text(tr.budgetEntryDialogConfirmAction)));
    expect((await harness.readCommitments()).single.lineId, isNotNull);
    expect(await harness.readEntries(), isEmpty);
    expect(inDetail(find.text(tr.budgetLineCommitAction)), findsNothing);
    expect(inDetail(find.text(tr.budgetLineShowCommitmentAction)), findsOneWidget);

    // The commitment is upcoming in the cash flow page.
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    expect(find.text(tr.budgetCashUpcomingSectionTitle), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);

    // Cancelling the commitment asks first, deletes it and leaves the quote line alone; the
    // line can then be committed again.
    await harness.tap(tester, inTracking(find.text("Camera deposit")));
    await harness.tap(tester, inDetail(find.text(tr.budgetLineUncommitAction)));
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect(await harness.readCommitments(), hasLength(1));
    await harness.tap(tester, inDetail(find.text(tr.budgetLineUncommitAction)));
    await harness.confirmDialog(tester, tr.budgetLineUncommitAction);
    expect(await harness.readCommitments(), isEmpty);
    expect((await harness.readAccount("Camera")).lines, hasLength(1));
    await harness.tap(tester, inDetail(find.text(tr.budgetLineCommitAction)));
    await harness.tap(tester, inWizard(find.text(tr.budgetEntryDialogConfirmAction)));
    expect(await harness.readCommitments(), hasLength(1));

    // Paying the commitment settles it: one entry naming it, nothing upcoming any more.
    await harness.tap(tester, inTracking(find.text("Camera deposit")));
    await harness.tap(tester, inDetail(find.text(tr.budgetDetailPayAction(r"$100.00"))));
    await harness.tap(tester, inWizard(find.text(tr.budgetEntryDialogConfirmAction)));
    final commitmentId = (await harness.readCommitments()).single.id;
    expect((await harness.readEntries()).single.commitmentId, commitmentId);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    expect(find.text(tr.budgetCommittedStatusSettledLabel), findsOneWidget);

    // Undoing the settlement frees the entry from the commitment without deleting it.
    await harness.tap(tester, harness.menuInRowOf(tester, tr.budgetCommittedStatusSettledLabel));
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<String>, tr.budgetCommittedUnsettleAction),
    );
    expect((await harness.readEntries()).single.commitmentId, isNull);
    expect(find.text(tr.budgetCommittedStatusSettledLabel), findsNothing);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    expect(find.text(tr.budgetCashUpcomingSectionTitle), findsOneWidget);
  });

  testWidgets("undoing the settlement of a commitment paid in instalments frees every instalment "
      "and deletes none", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    final lineId = await harness.seedLine(accountId, "Camera deposit");
    final commitmentId = await harness.seedCommitment(
      accountId,
      "Camera deposit",
      amountCents: 10000,
      lineId: lineId,
    );
    await harness.seedDebit("Deposit", 6000, accountId: accountId, commitmentId: commitmentId);
    await harness.seedDebit("Balance", 4000, accountId: accountId, commitmentId: commitmentId);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openExpensesExpanded(tester);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    expect(find.text(tr.budgetCommittedStatusSettledLabel), findsOneWidget);

    await harness.tap(tester, harness.menuInRowOf(tester, tr.budgetCommittedStatusSettledLabel));
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<String>, tr.budgetCommittedUnsettleAction),
    );
    final entries = await harness.readEntries();
    expect(entries.map((entry) => entry.label), ["Deposit", "Balance"]);
    expect(entries.map((entry) => entry.commitmentId), [null, null]);
    expect(find.text(tr.budgetCommittedStatusSettledLabel), findsNothing);
  });

  testWidgets("an off-line debit is promoted into the quote through a line and a commitment, or "
      "moved off the quote altogether, from its own fiche", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedLine(accountId, "Camera deposit");
    await harness.seedDebit("Taxi", 1500, accountId: accountId);
    await harness.seedDebit("Coffee", 700, accountId: accountId);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);

    await harness.tap(tester, find.text("Taxi"));
    await harness.tap(tester, inDetail(find.text(tr.budgetDetailPromoteToQuoteAction)));
    final account = await harness.readAccount("Camera");
    expect(account.lines.map((line) => line.label), ["Camera deposit", "Taxi"]);
    expect(account.lines.last.unitPrice.amountCents, 1500);
    final commitment = (await harness.readCommitments()).single;
    expect(commitment.lineId, account.lines.last.id);
    final entries = await harness.readEntries();
    expect(entries.firstWhere((entry) => entry.label == "Taxi").commitmentId, commitment.id);
    expect(entries.firstWhere((entry) => entry.label == "Coffee").commitmentId, isNull);
    expect(statusBar(tester).lineCount, 2);
    expect(statusBar(tester).quotedTotalCents, 11500);
    // The detail panel follows the entry, which is no longer offered the promotion.
    expect(inDetail(find.text("Taxi")), findsOneWidget);
    expect(inDetail(find.text(tr.budgetDetailPromoteToQuoteAction)), findsNothing);

    await harness.tap(tester, find.text("Coffee"));
    await harness.tap(tester, inDetail(find.text(tr.budgetDetailEntryMoveOffQuoteAction)));
    expect((await harness.readEntries()).firstWhere((e) => e.label == "Coffee").accountId, isNull);
    expect(inDetail(find.text(tr.budgetDetailEntryMoveOffQuoteAction)), findsNothing);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    expect(find.text(tr.budgetCostTrackingOffQuoteLabel), findsOneWidget);
  });

  testWidgets("promoting an off-line commitment adds a quote line for it and re-points the "
      "commitment at that line", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedCommitment(accountId, "Lens order", amountCents: 3000);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openExpensesExpanded(tester);

    await harness.tap(tester, find.text("Lens order"));
    await harness.tap(tester, inDetail(find.text(tr.budgetDetailPromoteToQuoteAction)));
    final account = await harness.readAccount("Camera");
    expect(account.lines.single.label, "Lens order");
    expect(account.lines.single.unitPrice.amountCents, 3000);
    expect((await harness.readCommitments()).single.lineId, account.lines.single.id);
    expect(statusBar(tester).quotedTotalCents, 3000);
    expect(inDetail(find.text(tr.budgetDetailPromoteToQuoteAction)), findsNothing);
  });

  testWidgets("a new poste is appended, selected and opened in the fiche, and a line born from "
      "the wizard is selected in its turn", (tester) async {
    await harness.seedAccount("Camera");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    expect(find.byTooltip(tr.budgetRightDockCloseTooltip), findsNothing);

    await harness.tap(tester, inTracking(find.text(tr.budgetAccountCreationAction)));
    expect((await harness.readAccounts()).map((account) => account.label), ["Camera", ""]);
    expect(statusBar(tester).accountCount, 2);
    expect(
      inDetail(find.text(tr.budgetInspectorAccountCodeFieldLabel.toUpperCase())),
      findsOneWidget,
    );
    await harness.type(
      tester,
      harness.fieldLabelled(tr.budgetInspectorAccountLabelFieldLabel),
      "Sound",
    );
    await harness.letDebounceRun(tester);
    expect((await harness.readAccounts()).last.label, "Sound");

    // The wizard's step 2 picks the account; step 3 holds label, quantity, unit and price.
    await openWizard(tester);
    await harness.tap(tester, inWizard(find.text("Sound")));
    await harness.tap(tester, find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
    await fillWizard(tester, ["Boom pole", "2", "day", "35"]);
    await saveWizard(tester);
    final line = (await harness.readAccount("Sound")).lines.single;
    expect(line.label, "Boom pole");
    expect(line.quantityMilli, 2000);
    expect(line.unit, "day");
    expect(line.unitPrice.amountCents, 3500);
    expect(statusBar(tester).quotedTotalCents, 7000);
    // The new line is the selection: the detail panel shows a line, not the account it replaced.
    expect(inDetail(find.text(tr.budgetLineQuantityFieldLabel.toUpperCase())), findsOneWidget);
    expect(inDetail(find.text("Boom pole")), findsWidgets);
  });

  testWidgets("a payment recorded from the cash flow page shows in the journal, in the "
      "expenses table and on the dashboard", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedLine(accountId, "Camera deposit");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);

    await openWizard(tester);
    await harness.tap(tester, inWizard(find.text("Camera")));
    await harness.tap(tester, find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
    await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Camera rental");
    await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "40.00");
    await saveWizard(tester);

    final entry = (await harness.readEntries()).single;
    expect(entry.label, "Camera rental");
    expect(entry.debitCents, 4000);
    expect(entry.accountId, (await harness.readAccount("Camera")).id);
    expect(find.text("Camera rental"), findsOneWidget);

    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    expect(inTracking(find.text(r"$40.00")), findsWidgets);
    await harness.tapHeader(tester, tr.budgetHeaderDashboardSegmentLabel);
    expect(
      find.descendant(of: find.byType(OcptBudgetDashboard), matching: find.text(r"$40.00")),
      findsWidgets,
    );
  });

  testWidgets("an in-kind contribution recorded in the financing plan mints its counterpart "
      "line in the quote, and a cash resource receipt shows as a credit", (tester) async {
    await harness.seedAccount("Camera");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);

    await openWizard(tester, gesture: "planContribution");
    await harness.tap(tester, inWizard(find.text(tr.budgetFinancingGroupInKindLabel)));
    await fillWizard(tester, ["Lent camera", "400"]);
    await harness.tap(tester, inWizard(find.byType(DropdownButton<String>)));
    await harness.tap(tester, find.text("Camera").last);
    await saveWizard(tester);

    expect((await harness.readResources()).single.label, "Lent camera");
    final line = (await harness.readAccount("Camera")).lines.single;
    expect(line.label, "Lent camera");
    expect(line.unitPrice.amountCents, 40000);
    expect(line.inKindResourceId, (await harness.readResources()).single.id);
    expect(statusBar(tester).lineCount, 1);
    expect(statusBar(tester).quotedTotalCents, 40000);
    // The financing page reads the new quote: what the film costs now, and that it is covered.
    expect(
      find.descendant(of: find.byType(OcptBudgetFinancing), matching: find.text(r"$400.00")),
      findsWidgets,
    );
    // The new resource is the selection, but unlike a new account or line it does not open the
    // dock: the detail panel is there once the dock is.
    expect(find.byTooltip(tr.budgetRightDockCloseTooltip), findsNothing);
    await harness.openRightDock(tester);
    expect(inDetail(find.text("Lent camera")), findsOneWidget);

    // A cash subsidy is received from its own detail panel: a credit is written, naming it.
    await openWizard(tester, gesture: "planSubsidy");
    await fillWizard(tester, ["Regional grant", "200"]);
    await saveWizard(tester);
    final grant = (await harness.readResources()).firstWhere((r) => r.label == "Regional grant");
    expect(grant.amountCents, 20000);
    await harness.tap(tester, inDetail(find.text(tr.budgetDetailReceiveAction(r"$200.00"))));
    await harness.tap(tester, inWizard(find.text(tr.budgetEntryDialogConfirmAction)));
    final entry = (await harness.readEntries()).single;
    expect(entry.creditCents, 20000);
    expect(entry.resourceId, grant.id);
    expect(inDetail(find.text(tr.budgetDetailReceiveAction(r"$200.00"))), findsNothing);
  });

  testWidgets("a taking and a revenue-sharing participant are created from the wizard and "
      "selected, the participant by a plain highlight", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    await openWizard(tester, gesture: "planTaking");
    await fillWizard(tester, ["Festival prize", "90"]);
    await saveWizard(tester);
    expect((await harness.readRevenues()).single.amountCents, 9000);
    expect(find.byTooltip(tr.budgetRightDockCloseTooltip), findsNothing);
    await harness.openRightDock(tester);
    expect(inDetail(find.text("Festival prize")), findsOneWidget);

    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderSharingSegmentLabel);
    await openWizard(tester);
    await fillWizard(tester, ["Producer", "50", "10"]);
    await saveWizard(tester);
    final share = (await harness.readShares()).single;
    expect(share.label, "Producer");
    expect(share.sharePermille, 500);
    expect(share.reinvestPermille, 100);
    expect(
      tester.widget<OcptBudgetSharing>(find.byType(OcptBudgetSharing)).selectedShareId,
      share.id,
    );
  });

  testWidgets("shares are reordered from their row menu, one position at a time", (tester) async {
    await harness.seedShare("Producer");
    await harness.seedShare("Director", sharePermille: 300);
    await harness.seedShare("Writer", sharePermille: 200);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderSharingSegmentLabel);

    await harness.tap(tester, harness.menuInRowOf(tester, "Writer"));
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<String>, tr.budgetAccountMoveUpAction),
    );
    expect((await harness.readShares()).map((share) => share.label), [
      "Producer",
      "Writer",
      "Director",
    ]);
  });

  testWidgets("provisioning a defrayal into the quote asks first, then writes the lines it "
      "computed into the chosen poste and leaves the second run with nothing to do", (
    tester,
  ) async {
    await harness.seedAllowance("Per diem");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderLogisticsSegmentLabel);

    await harness.tap(tester, find.text(tr.budgetLogisticsProvisionAction));
    expect(find.text(tr.budgetProvisionConfirmTitle), findsOneWidget);
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect(statusBar(tester).lineCount, 0);

    await harness.tap(tester, find.text(tr.budgetLogisticsProvisionAction));
    await harness.confirmDialog(tester, tr.budgetLogisticsProvisionAction);
    final transport = (await harness.readAccounts()).firstWhere(
      (account) => account.id == "d75aa74c-ed99-494a-bca0-3508b166ec18",
    );
    expect(transport.lines, hasLength(1));
    expect(transport.lines.single.provisionKey, isNotNull);
    expect(statusBar(tester).lineCount, 1);
    expect(statusBar(tester).quotedTotalCents, 2000);

    // The provisioned figure is now in the quote, so the gesture has nothing left to write.
    expect(find.text(tr.budgetLogisticsProvisionAction), findsNothing);
    expect(find.text(tr.budgetProvisionNothingToDoMessage), findsOneWidget);
  });

  testWidgets("the header counts the alerts, and the link of an over-quote alert row selects "
      "the poste on the expenses table", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedLine(accountId, "Camera deposit");
    await harness.seedDebit("Camera rental", 25000, accountId: accountId);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.byType(OcptBudgetHeader), findsOneWidget);
    expect(
      find.descendant(of: find.byType(OcptBudgetHeader), matching: find.text("1")),
      findsOneWidget,
    );
    await harness.tap(
      tester,
      find.textContaining(r"has $250.00 paid or committed against a $100.00 quote"),
    );
    expect(find.byType(OcptBudgetCostTracking), findsOneWidget);
    expect(
      inDetail(find.text(tr.budgetInspectorAccountCodeFieldLabel.toUpperCase())),
      findsOneWidget,
    );
  });

  testWidgets("a cash alert on the dashboard opens the cash flow page, where the commitment that "
      "causes it can be selected", (tester) async {
    final accountId = await harness.seedAccount("Camera");
    await harness.seedCommitment(accountId, "Lens order", amountCents: 3000);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.textContaining("falls below zero"));
    expect(find.byType(OcptBudgetCashJournal), findsOneWidget);
    expect(find.byType(OcptBudgetDashboard), findsNothing);
    await harness.tap(tester, find.text("Lens order"));
    expect(inDetail(find.text(tr.budgetDetailKindCommitmentLabel)), findsOneWidget);
  });

  testWidgets("a defrayal is created from the wizard, shows in the catering page and is deleted "
      "after a question, and postes move up and down from their row menu", (tester) async {
    await harness.seedAccount("Camera");
    await harness.seedAccount("Sound");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    await harness.tap(
      tester,
      harness.menuInRowOf(tester, "Sound", within: find.byType(OcptBudgetCostTracking)),
    );
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<String>, tr.budgetAccountMoveUpAction),
    );
    expect((await harness.readAccounts()).map((account) => account.label), ["Sound", "Camera"]);

    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderLogisticsSegmentLabel);
    await openWizard(tester);
    await fillWizard(tester, ["Per diem", "2", "20"]);
    await saveWizard(tester);
    final allowance = (await harness.readAllowances()).single;
    expect(allowance.label, "Per diem");
    expect(allowance.quantityMilli, 2000);
    expect(find.text("Per diem"), findsOneWidget);

    await harness.tap(
      tester,
      find.descendant(
        of: find.byType(OcptBudgetLogistics),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<String>, tr.budgetCommittedDeleteAction),
    );
    expect(find.text(tr.budgetDeleteAllowanceConfirmTitle), findsOneWidget);
    await harness.cancelDialog(tester, tr.budgetDeleteCancelAction);
    expect(await harness.readAllowances(), hasLength(1));
    await harness.tap(
      tester,
      find.descendant(
        of: find.byType(OcptBudgetLogistics),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<String>, tr.budgetCommittedDeleteAction),
    );
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect(await harness.readAllowances(), isEmpty);
    expect(find.text("Per diem"), findsNothing);
  });
}
