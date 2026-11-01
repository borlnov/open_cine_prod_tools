// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';

import 'budget_mode_scenarios_test_doubles.dart';

/// Run the tests of the budget mode lifecycle scenarios.
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

  /// Opens the export panel from the toolbar, leaving time for it to appear but not for the
  /// field-edit debounce to run out.
  Future<void> openExportPanel(WidgetTester tester) =>
      harness.tapOpening(tester, find.byTooltip(harness.trOf(tester).workspaceExportTooltip));

  /// Picks the card titled [title] of the open export panel and lets its options dialog open, if
  /// it has one, without letting the field-edit debounce out.
  Future<void> pickExportCard(WidgetTester tester, String title) async {
    await openExportPanel(tester);
    await harness.tapQuickly(tester, harness.inDialog(find.text(title)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Applies the options dialog of a PDF export.
  Future<void> applyExportOptions(WidgetTester tester) => harness.tap(
    tester,
    harness.inDialog(find.text(harness.trOf(tester).editorExportPdfExportAction)),
  );

  /// Taps the version card to preview it and waits for the read-only banner to show.
  Future<void> previewFirstVersion(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await tester.tapAt(
      tester.getTopLeft(find.byType(OcptProjectVersionCard)) + const Offset(24, 12),
    );
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
  }

  /// Leaves the preview and waits for the banner to go.
  Future<void> exitPreview(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await tester.tap(find.text(tr.workspaceReadOnlyBannerExitAction));
    await harness.pumpUntil(
      tester,
      () => !harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
  }

  /// Seeds one of everything: poste "Camera" with the line "Camera deposit", the commitment "Lens
  /// order", the debit "Taxi", the resource "Regional grant", the taking "Festival prize" and the
  /// share "Producer", returning the id of "Camera".
  Future<String> seedEverything() async {
    final posteId = await harness.seedPoste("Camera");
    await harness.seedLine(posteId, "Camera deposit");
    await harness.seedCommitment(posteId, "Lens order", amountCents: 3000);
    await harness.seedDebit("Taxi", 1500, posteId: posteId);
    await harness.seedResource("Regional grant", 20000);
    await harness.seedRevenue("Festival prize", 9000);
    await harness.seedShare("Producer");

    return posteId;
  }

  testWidgets("the export panel lists the four documents and the project package, greys out the "
      "financing plan and the cash journal while they have nothing to print, and exports "
      "nothing from a greyed card", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await openExportPanel(tester);
    for (final title in [
      tr.budgetExportQuoteTitle,
      tr.budgetExportFinancingPlanTitle,
      tr.budgetExportCashJournalTitle,
      tr.budgetExportFinancialReportTitle,
      tr.workspaceExportProjectPackageTitle,
    ]) {
      expect(harness.inDialog(find.text(title)), findsOneWidget, reason: title);
    }
    expect(harness.inDialog(find.text(tr.budgetExportUnavailableNoResourceReason)), findsOneWidget);
    expect(harness.inDialog(find.text(tr.budgetExportUnavailableNoEntryReason)), findsOneWidget);
    expect(harness.inDialog(find.text(tr.budgetExportUnavailableNoPosteReason)), findsNothing);

    await harness.tap(tester, harness.inDialog(find.text(tr.budgetExportFinancingPlanTitle)));
    await harness.tap(tester, harness.inDialog(find.text(tr.budgetExportCashJournalTitle)));
    expect(harness.exportManager.exports, isEmpty);
  });

  testWidgets("the quote export asks for its options, hands the document what was typed a moment "
      "ago in the tax basis the header reads, and says where the file went, or that it failed", (
    tester,
  ) async {
    final posteId = await harness.seedPoste("Camera");
    await harness.seedLine(posteId, "Camera deposit");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderExcludingTaxSegmentLabel);
    await harness.tap(tester, inTracking(find.text("Camera")));

    // Cancelling the options dialog exports nothing.
    await pickExportCard(tester, tr.budgetExportQuoteTitle);
    expect(find.text(tr.budgetExportQuoteDialogTitle), findsOneWidget);
    await harness.tap(tester, find.text(tr.editorPageSetupCancelAction));
    expect(harness.exportManager.exports, isEmpty);

    await harness.type(
      tester,
      harness.fieldLabelled(tr.budgetInspectorPosteLabelFieldLabel),
      "Camera crew",
    );
    await pickExportCard(tester, tr.budgetExportQuoteTitle);
    await applyExportOptions(tester);
    final export = harness.exportManager.exports.single;
    expect(export.document, "quote");
    expect(export.projectName, "My Movie");
    expect(export.taxBasis, OcptBudgetTaxBasis.excludingTax);
    expect(export.pageSetup!.format, OcptPageFormat.usLetter);
    expect(export.includeTitlePage, isTrue);
    expect(export.snapshot.postes.single.label, "Camera crew");
    expect((await harness.readPostes()).single.label, "Camera crew");
    expect(find.text(tr.budgetExportFileSuccessMessage("/tmp/quote.out")), findsOneWidget);

    // The basis picked in the options dialog wins over the one the header reads.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await pickExportCard(tester, tr.budgetExportQuoteTitle);
    await harness.tap(tester, harness.inDialog(find.text(tr.budgetHeaderIncludingTaxSegmentLabel)));
    await applyExportOptions(tester);
    expect(harness.exportManager.exports.last.taxBasis, OcptBudgetTaxBasis.includingTax);

    // A cancelled save dialog is silent.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    harness.exportManager
      ..reset()
      ..shouldCancel = true;
    await pickExportCard(tester, tr.budgetExportQuoteTitle);
    await applyExportOptions(tester);
    expect(harness.exportManager.exports, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);

    // A writer that throws is reported to the user.
    harness.exportManager
      ..reset()
      ..shouldFail = true;
    await pickExportCard(tester, tr.budgetExportQuoteTitle);
    await applyExportOptions(tester);
    expect(find.text(tr.budgetExportError), findsOneWidget);
  });

  testWidgets("the financing plan, the cash journal and the financial report each export the "
      "snapshot as the mode holds it, and a workbook that cannot be built is reported", (
    tester,
  ) async {
    final posteId = await harness.seedPoste("Camera");
    await harness.seedLine(posteId, "Camera deposit");
    final resourceId = await harness.seedResource("Regional grant", 20000);
    await harness.projectsManager.budgetJournalService.createEntry(
      database: harness.database,
      date: DateTime(2026),
      label: "Grant instalment",
      resourceId: resourceId,
      creditCents: 4000,
    );
    await harness.projectsManager.saveCurrentProjectPageFormat(OcptPageFormat.a4);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await pickExportCard(tester, tr.budgetExportFinancingPlanTitle);
    expect(find.text(tr.budgetExportFinancingPlanDialogTitle), findsOneWidget);
    await applyExportOptions(tester);
    var export = harness.exportManager.exports.last;
    expect(export.document, "financingPlan");
    expect(export.snapshot.resources.single.label, "Regional grant");
    expect(export.pageSetup!.format, OcptPageFormat.a4);

    await pickExportCard(tester, tr.budgetExportFinancialReportTitle);
    expect(find.text(tr.budgetExportFinancialReportDialogTitle), findsOneWidget);
    await applyExportOptions(tester);
    export = harness.exportManager.exports.last;
    expect(export.document, "financialReport");
    expect(export.snapshot.entries.single.label, "Grant instalment");

    // The workbook takes no options: picking its card exports at once, with the labels of what
    // each entry settles.
    await openExportPanel(tester);
    await harness.tap(tester, harness.inDialog(find.text(tr.budgetExportCashJournalTitle)));
    export = harness.exportManager.exports.last;
    expect(export.document, "cashJournal");
    expect(export.linkLabelByEntryId!.values.single, "Regional grant");
    expect(find.text(tr.budgetExportFileSuccessMessage("/tmp/cashJournal.out")), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    harness.exportManager.shouldAnswerFailed = true;
    await openExportPanel(tester);
    await harness.tap(tester, harness.inDialog(find.text(tr.budgetExportCashJournalTitle)));
    expect(find.text(tr.budgetExportError), findsOneWidget);
  });

  testWidgets("coming back from the project settings never re-reads the page format the export "
      "dialogs start from, with a change or without", (tester) async {
    await harness.seedPoste("Camera");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.projectsManager.saveCurrentProjectPageFormat(OcptPageFormat.a4);

    harness.routerManager.pushAnswer = false;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    expect(harness.routerManager.pushCount, 1);
    await pickExportCard(tester, tr.budgetExportQuoteTitle);
    await applyExportOptions(tester);
    expect(harness.exportManager.exports.last.pageSetup!.format, OcptPageFormat.usLetter);

    harness.routerManager.pushAnswer = true;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    expect(harness.routerManager.pushCount, 2);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await pickExportCard(tester, tr.budgetExportQuoteTitle);
    await applyExportOptions(tester);
    // Only the currency and the VAT rate are re-read after a settings change: the dialogs keep
    // the page setup read when the mode was entered.
    expect(harness.exportManager.exports.last.pageSetup!.format, OcptPageFormat.usLetter);
  });

  testWidgets("the right dock reopens on the tab it was last left on, and picking a row opens "
      "the inspector without changing the saved tab", (tester) async {
    await harness.seedPoste("Camera");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);

    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await harness.tap(tester, find.text(tr.budgetRightDockHelpTabLabel));
    expect(
      await harness.propertiesManager.budgetLastRightDockTab.load(),
      OcptBudgetRightDockTab.help,
    );
    // The active tab closes the dock when picked again; the toolbar reopens it where it was.
    await harness.tap(tester, find.text(tr.budgetRightDockHelpTabLabel));
    expect(find.byTooltip(tr.budgetRightDockCloseTooltip), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    expect(find.byTooltip(tr.budgetRightDockCloseTooltip), findsOneWidget);
    expect(find.byType(OcptBudgetFiche), findsNothing);

    await harness.tap(tester, inTracking(find.text("Camera")));
    expect(find.byType(OcptBudgetFiche), findsOneWidget);
    expect(
      await harness.propertiesManager.budgetLastRightDockTab.load(),
      OcptBudgetRightDockTab.help,
    );
    await harness.tap(tester, find.byTooltip(tr.budgetRightDockCloseTooltip));
    expect(find.byType(OcptBudgetFiche), findsNothing);
  });

  testWidgets("the mode starts from the right dock tab and width stored by the previous visit", (
    tester,
  ) async {
    await harness.propertiesManager.budgetLastRightDockTab.store(OcptBudgetRightDockTab.versions);
    await harness.propertiesManager.budgetRightDockFraction.store(0.27);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.byType(OcptProjectVersionsPanel), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    expect(find.byType(OcptProjectVersionsPanel), findsOneWidget);
    expect(await harness.propertiesManager.budgetRightDockFraction.load(), 0.27);
  });

  testWidgets("a dock stored on the inspector shows Help where nothing can be inspected, without "
      "forgetting the inspector", (tester) async {
    await harness.seedPoste("Camera");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    expect(find.text(tr.budgetRightDockInspectorTabLabel), findsNothing);

    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    expect(find.text(tr.budgetRightDockInspectorTabLabel), findsOneWidget);
    expect(find.text(tr.budgetFicheEmptyHint), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    await harness.tapHeader(tester, tr.budgetHeaderRegieSegmentLabel);
    expect(find.text(tr.budgetRightDockInspectorTabLabel), findsNothing);
    expect(find.text(tr.budgetFicheEmptyHint), findsNothing);
    expect(
      await harness.propertiesManager.budgetLastRightDockTab.load(),
      OcptBudgetRightDockTab.inspector,
    );
    await harness.tapHeader(tester, tr.budgetHeaderSharingSegmentLabel);
    expect(find.text(tr.budgetFicheEmptyHint), findsOneWidget);
  });

  testWidgets("a project left with no poste draws the feed card in the expenses table, which opens "
      "the catering page itself, hands the workspace over to Resources or the schedule, and greys "
      "the documents that need a poste", (tester) async {
    await harness.seedPoste("Camera");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    final workspace = harness.workspaceBlocOf(tester);

    await harness.tap(
      tester,
      harness.menuInRowOf(tester, "Camera", within: find.byType(OcptBudgetCostTracking)),
    );
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<String>, tr.budgetPosteDeleteAction),
    );
    await harness.confirmDialog(tester, tr.budgetDeleteConfirmAction);
    expect(statusBar(tester).posteCount, 0);
    // A project whose only poste was deleted is not seeded again: the table is not empty.
    expect(await harness.readPostes(), isEmpty);

    await openExportPanel(tester);
    expect(harness.inDialog(find.text(tr.budgetExportUnavailableNoPosteReason)), findsNWidgets(2));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await harness.tap(tester, inTracking(find.text(tr.budgetDashboardFeedCateringTitle)));
    expect(find.text(tr.budgetHeaderRegieTitle), findsWidgets);
    expect(workspace.state.mode, isNot(OcptWorkspaceMode.schedule));

    await harness.tap(tester, find.text(tr.budgetDashboardFeedBreakdownTitle));
    expect(workspace.state.mode, OcptWorkspaceMode.resources);
    expect(workspace.state.revealRequest, isA<OcptResourcesRevealRequest>());

    await harness.tap(tester, find.text(tr.budgetDashboardFeedScheduleTitle));
    expect(workspace.state.mode, OcptWorkspaceMode.schedule);
  });

  testWidgets("leaving through the back button closes the project and pops the page", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.byTooltip(tr.editorBackToProjectsTooltip));
    expect(harness.projectsManager.currentProject, isNull);
    expect(harness.routerManager.popCount, 1);
  });

  testWidgets("previewing a version reloads the whole budget and withholds every write, leaving "
      "it brings the working copy back", (tester) async {
    await seedEverything();
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    // Written after the version was captured, so the preview cannot show it.
    await harness.seedPoste("Sound");
    await harness.seedDebit("Late fee", 300);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(statusBar(tester).posteCount, 2);
    expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsOneWidget);
    expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    await harness.tap(tester, inTracking(find.text("Camera")));
    expect(find.byType(OcptBudgetFiche), findsOneWidget);

    await harness.tap(tester, find.text(tr.budgetRightDockVersionsTabLabel));
    await previewFirstVersion(tester);

    // The version's own budget, the selection dropped and every writing control withheld.
    expect(find.text(tr.workspaceReadOnlyBannerExitAction), findsOneWidget);
    expect(statusBar(tester).posteCount, 1);
    expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsNothing);
    expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsNothing);
    // The poste row keeps its menu for the one thing that only reads: narrowing the table.
    await harness.tap(
      tester,
      harness.menuInRowOf(tester, "Camera", within: find.byType(OcptBudgetCostTracking)),
    );
    expect(find.byType(PopupMenuItem<String>), findsOneWidget);
    expect(find.text(tr.budgetCostTrackingFilterOnlyAction), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text(tr.budgetPosteCreationAction), findsNothing);
    await harness.tap(tester, find.text(tr.budgetRightDockInspectorTabLabel));
    expect(find.text(tr.budgetFicheEmptyHint), findsOneWidget);

    await harness.tap(tester, inTracking(find.text("Camera")));
    expect(harness.readOnlyFields(), findsWidgets);
    expect(harness.editableFields(), findsNothing);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, inTracking(find.text("Lens order")));
    expect(inFiche(find.text(tr.budgetFicheKindCommitmentLabel)), findsOneWidget);
    expect(inFiche(find.text(tr.budgetCommittedDeleteAction)), findsNothing);
    expect(inFiche(find.text(tr.budgetFinancingEditAction)), findsNothing);

    await harness.tapHeader(tester, tr.budgetHeaderResourcesSegmentLabel);
    await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
    await harness.tap(tester, find.text("Regional grant"));
    expect(inFiche(find.text("Regional grant")), findsOneWidget);
    expect(inFiche(find.text(tr.budgetFinancingEditAction)), findsNothing);
    expect(inFiche(find.textContaining(r"Receive $")), findsNothing);

    await harness.tapHeader(tester, tr.budgetHeaderToolsSegmentLabel);
    expect(find.text("Late fee"), findsNothing);
    expect(find.text("Taxi"), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderSharingSegmentLabel);
    expect(
      find.descendant(
        of: find.byType(OcptBudgetSharing),
        matching: find.byType(PopupMenuButton<String>),
      ),
      findsNothing,
    );

    // The package export card says why it is unavailable.
    await harness.tap(tester, find.byTooltip(tr.workspaceExportTooltip));
    expect(
      harness.inDialog(find.text(tr.workspaceExportProjectPackagePreviewReason)),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // Back to the working copy: everything written since is there again, and writable.
    await exitPreview(tester);
    expect(statusBar(tester).posteCount, 2);
    expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsOneWidget);
    expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsOneWidget);
    await harness.tapHeader(tester, tr.budgetHeaderCashFlowSegmentLabel);
    expect(find.text("Late fee"), findsOneWidget);
  });

  testWidgets("a field typed just before previewing a version is written first, the preview "
      "shows the version's own, and leaving it brings the typed value back", (tester) async {
    await harness.seedPoste("Camera");
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    await harness.tap(tester, inTracking(find.text("Camera")));

    await harness.type(
      tester,
      harness.fieldLabelled(tr.budgetInspectorPosteLabelFieldLabel),
      "Camera crew",
    );
    await harness.tapQuickly(tester, find.text(tr.budgetRightDockVersionsTabLabel));
    await previewFirstVersion(tester);

    // The working copy file holds it already, though the debounce never ran out.
    final stored = await harness.projectsManager.budgetQuoteService.loadPostes(
      database: harness.projectsManager.currentProject!.fileDatabase,
      seed: const [],
    );
    expect(stored.single.label, "Camera crew");
    expect(inTracking(find.text("Camera")), findsOneWidget);
    expect(inTracking(find.text("Camera crew")), findsNothing);

    await exitPreview(tester);
    expect(inTracking(find.text("Camera crew")), findsOneWidget);
  });

  testWidgets("restoring a version puts the budget back to it and drops the selection", (
    tester,
  ) async {
    await seedEverything();
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.seedPoste("Sound");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(statusBar(tester).posteCount, 2);
    await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
    await harness.tap(tester, inTracking(find.text("Sound")));
    expect(find.byType(OcptBudgetFiche), findsOneWidget);

    await harness.tap(tester, find.text(tr.budgetRightDockVersionsTabLabel));
    await harness.tap(tester, find.text(tr.projectVersionRestoreAction));
    await harness.tap(tester, find.text(tr.projectVersionRestoreConfirmAction));
    await harness.pumpUntil(tester, () => statusBar(tester).posteCount == 1);
    await harness.eventually(tester, () async => (await harness.readPostes()).length == 1);

    expect((await harness.readPostes()).single.label, "Camera");
    expect(find.byType(OcptProjectVersionsPanel), findsOneWidget);
    await harness.tap(tester, find.text(tr.budgetRightDockInspectorTabLabel));
    expect(find.text(tr.budgetFicheEmptyHint), findsOneWidget);
  });

  testWidgets("a field write that fails throws through the mode: the edit stays pending and on "
      "screen, the database keeps its value, and the next edit writes both", (tester) async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final posteId = await harness.seedPoste("Camera");
      await harness.seedLine(posteId, "Camera deposit");
      await harness.mount(tester);
      final tr = harness.trOf(tester);
      await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
      await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
      await harness.tap(tester, inTracking(find.text("Camera deposit")));

      harness.projectsManager.failures.failLineUpdates = true;
      await harness.type(tester, harness.fieldLabelled(tr.budgetLineLabelFieldLabel), "Rental");
      await harness.letDebounceRun(tester);
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      expect((await harness.readPoste("Camera")).lines.single.label, "Camera deposit");
      expect(
        tester
            .widget<TextField>(harness.fieldLabelled(tr.budgetLineLabelFieldLabel))
            .controller!
            .text,
        "Rental",
      );

      // The failure did not stop the mode: a later edit goes through.
      harness.projectsManager.failures.failLineUpdates = false;
      await harness.type(tester, harness.fieldLabelled(tr.budgetLineLabelFieldLabel), "Rental 2");
      await harness.letDebounceRun(tester);
      expect((await harness.readPoste("Camera")).lines.single.label, "Rental 2");
      expect(errors, hasLength(1));
    }, (error, stack) => errors.add(error));
  });

  testWidgets("a payment whose entry cannot be written leaves the commitment it created behind, "
      "reloads nothing, and a second attempt creates a second commitment for the same line", (
    tester,
  ) async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final posteId = await harness.seedPoste("Camera");
      await harness.seedLine(posteId, "Camera deposit");
      await harness.mount(tester);
      final tr = harness.trOf(tester);
      await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
      await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
      await harness.tap(tester, inTracking(find.text("Camera deposit")));

      harness.projectsManager.failures.failEntryCreation = true;
      await harness.tap(tester, inFiche(find.text(tr.budgetFichePayAction(r"$100.00"))));
      await harness.tap(tester, harness.inDialog(find.text(tr.budgetEntryDialogConfirmAction)));
      expect(errors, hasLength(1));
      expect(await harness.readEntries(), isEmpty);
      expect(await harness.readCommitments(), hasLength(1));
      // The screen was never reloaded: the line still offers to be committed.
      expect(inFiche(find.text(tr.budgetLineCommitAction)), findsOneWidget);

      harness.projectsManager.failures.failEntryCreation = false;
      await harness.tap(tester, inFiche(find.text(tr.budgetFichePayAction(r"$100.00"))));
      await harness.tap(tester, harness.inDialog(find.text(tr.budgetEntryDialogConfirmAction)));
      expect(await harness.readEntries(), hasLength(1));
      expect(await harness.readCommitments(), hasLength(2));
    }, (error, stack) => errors.add(error));
  });

  testWidgets("leaving the mode while a field write fails only logs it", (tester) async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final posteId = await harness.seedPoste("Camera");
      await harness.seedLine(posteId, "Camera deposit");
      await harness.mount(tester);
      final tr = harness.trOf(tester);
      await harness.tapHeader(tester, tr.budgetHeaderExpensesSegmentLabel);
      await harness.tap(tester, find.byIcon(Icons.keyboard_arrow_right).first);
      await harness.tap(tester, inTracking(find.text("Camera deposit")));

      harness.projectsManager.failures.failLineUpdates = true;
      await harness.type(tester, harness.fieldLabelled(tr.budgetLineLabelFieldLabel), "Rental");
      await harness.unmount(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      expect(errors, isEmpty);
      expect((await harness.readPoste("Camera")).lines.single.label, "Camera deposit");
    }, (error, stack) => errors.add(error));
  });
}
