// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_dashboard.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_help.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'budget_mode_test_doubles.dart';

/// Run the tests of the budget mode postes and journal.
void main() {
  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(RecordingRouterManager())
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_mode_test_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  });

  /// Taps the header's own control (a view chip, a switch segment…) labelled [label], scoped to
  /// `OcptBudgetHeader` — the help panel's own map, and a view's own title, often reuse the very
  /// same words for its cells, so a plain `find.text` is ambiguous whenever the Help tab is open
  /// beside the header.
  Future<void> tapHeaderChip(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(OcptBudgetHeader), matching: find.text(label)).first,
    );
    await tester.pumpAndSettle();
  }

  /// Switches the centre to the expenses table, the mode's own default view once the dashboard
  /// itself is left.
  Future<void> openExpenses(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tapHeaderChip(tester, tr.budgetHeaderExpensesSegmentLabel);
  }

  /// Switches the centre to the resources document.
  Future<void> openResources(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tapHeaderChip(tester, tr.budgetHeaderResourcesSegmentLabel);
  }

  /// Opens the tools drawer, then, once [page] is given, its own segmented switch's [page]
  /// segment — a plain call lands on whichever of the drawer's own three pages
  /// [OcptBudgetState.toolsView] already read (`Flux de trésorerie` the very first time).
  Future<void> openTools(WidgetTester tester, {String? page}) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tapHeaderChip(tester, tr.budgetHeaderToolsSegmentLabel);
    if (page != null) {
      await tapHeaderChip(tester, page);
    }
  }

  /// Switches the centre to the tools drawer's own `Flux de trésorerie` page.
  Future<void> openCashFlow(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await openTools(tester, page: tr.budgetHeaderCashFlowSegmentLabel);
  }

  /// A finder scoped to the export panel's own `AlertDialog`, so its card titles can't collide
  /// with anything else on screen — mirrors `schedule_mode_test.dart`'s own `inPanel`.
  Finder inPanel(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  testWidgets("the ten CNC postes are seeded and shown on first entry", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final statusBar = tester.widget<OcptBudgetStatusBar>(find.byType(OcptBudgetStatusBar));
    expect(statusBar.posteCount, 10);

    await openExpenses(tester);
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    // Scoped to the expenses table itself.
    expect(
      find.descendant(
        of: find.byType(OcptBudgetCostTracking),
        matching: find.text(tr.budgetCncPosteArtisticRights),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(OcptBudgetCostTracking),
        matching: find.text(tr.budgetCncPosteOverheads),
      ),
      findsOneWidget,
    );
  });

  group("the dashboard", () {
    testWidgets("is the mode's own default view", (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();

      // Opened without touching a single chip.
      expect(find.byType(OcptBudgetDashboard), findsOneWidget);
      expect(find.byType(OcptBudgetCostTracking), findsNothing);
    });

    testWidgets("carries the header's own + Nouveau button, like every other route", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsOneWidget);
    });

    testWidgets("its own onPosteOpened wiring selects the poste and lands on the cost report", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
      // A fresh project seeds ten postes but no alert, so the dashboard's only poste-linking
      // gesture — an over-quote alert row — draws nothing yet
      // (`ocpt_budget_dashboard_test.dart` covers that row's own click end to end once an alert
      // exists). What this integration needs is that `budget_mode.dart`'s own wiring of
      // `OcptBudgetDashboard.onPosteOpened` still selects the poste and switches to Expenses, so
      // it is invoked directly on the mounted widget rather than through a tap.
      final dashboard = tester.widget<OcptBudgetDashboard>(find.byType(OcptBudgetDashboard));
      final posteId = dashboard.postes
          .firstWhere((poste) => poste.label == tr.budgetCncPosteArtisticRights)
          .id;

      dashboard.onPosteOpened(posteId);
      await tester.pumpAndSettle();

      // Landed on the cost report — a dashboard row is a link to where the poste is worked on,
      // not a selection that opens the fiche over the dashboard itself.
      expect(find.byType(OcptBudgetDashboard), findsNothing);
      expect(find.byType(OcptBudgetCostTracking), findsOneWidget);

      // And the poste it names is the very one selected — the fiche opened on it.
      expect(find.byType(OcptBudgetFiche), findsOneWidget);
    });
  });

  testWidgets("the simplified switch swaps every poste's label and hides the N° column", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openExpenses(tester);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    // Scoped to the cost-tracking table: the left dock now prints every poste's own name too.
    Finder inCostTracking(Finder matching) =>
        find.descendant(of: find.byType(OcptBudgetCostTracking), matching: matching);
    expect(inCostTracking(find.text(tr.budgetCncPosteArtisticRights)), findsOneWidget);
    expect(inCostTracking(find.text("1")), findsWidgets);

    await tester.tap(find.text(tr.budgetHeaderSimplifiedSegmentLabel));
    await tester.pumpAndSettle();

    expect(inCostTracking(find.text(tr.budgetCncPosteArtisticRights)), findsNothing);
    expect(inCostTracking(find.text(tr.budgetCncPosteSimpleArtisticRights)), findsOneWidget);
  });

  testWidgets("deleting a poste asks through OcptConfirmDialog", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openExpenses(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tester.tap(find.text(tr.budgetPosteDeleteAction));
    await tester.pumpAndSettle();

    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    expect(find.text(tr.budgetDeletePosteConfirmTitle), findsOneWidget);

    // Cancelling leaves every poste in place.
    await tester.tap(find.text(tr.budgetDeleteCancelAction));
    await tester.pumpAndSettle();

    final statusBar = tester.widget<OcptBudgetStatusBar>(find.byType(OcptBudgetStatusBar));
    expect(statusBar.posteCount, 10);
  });

  testWidgets(
    "creating an entry through the header's own capture button shows it in the tools drawer's "
    "own cash flow page",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // The tools drawer's own cash flow page is now a read-only statement, carrying no capture
      // affordance of its own — the daily gesture is the header's own button, opening the wizard.
      // Opened from `tools › cashFlow`, the cash-movement family is promoted and `J'ai payé
      // quelque chose` (recordExpense) arrives pre-selected, one click from step 2.
      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openCashFlow(tester);

      await tester.tap(find.byKey(const Key("ocptBudgetHeaderCaptureButton")));
      await tester.pumpAndSettle();

      // Step 1 opens with `recordExpense` already selected — one click reaches step 2.
      expect(find.byKey(const Key("ocptBudgetNewContinueButton")), findsOneWidget);
      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      // Step 2: the optional poste attachment — `Hors devis`.
      await tester.tap(find.byKey(const Key("ocptBudgetNewOffQuoteChoice")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Camera rental");
      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "50.00");
      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      expect(find.text("Camera rental"), findsOneWidget);
    },
  );

  testWidgets("deleting a cash-journal entry asks through OcptConfirmDialog", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = projectsManager.currentProject!;
    await projectsManager.budgetJournalService.createEntry(
      database: project.database,
      date: DateTime(2026),
      label: "To be deleted",
      debitCents: 500,
    );

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openCashFlow(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tester.tap(find.text(tr.budgetEntryDeleteAction));
    await tester.pumpAndSettle();

    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    expect(find.text(tr.budgetDeleteEntryConfirmTitle), findsOneWidget);

    // Cancelling leaves the entry in place.
    await tester.tap(find.text(tr.budgetDeleteCancelAction));
    await tester.pumpAndSettle();
    expect(find.text("To be deleted"), findsOneWidget);

    // Confirming removes it, and the view falls back to the shared empty state.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetEntryDeleteAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetDeleteConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text("To be deleted"), findsNothing);
    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  testWidgets(
    "editing a cash-journal entry opens the simplified dialog directly, no step of its own",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "Bank fees",
        debitCents: 500,
      );

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openCashFlow(tester);
      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetFinancingEditAction));
      await tester.pumpAndSettle();

      // The dialog only edits now: one screen, no nature card, no Continuer, no changer link — and
      // the label field already reads the entry's own value.
      expect(find.byKey(const Key("ocptBudgetNewContinueButton")), findsNothing);
      expect(find.byKey(const Key("ocptBudgetEntryWizardChangeNatureLink")), findsNothing);
      expect(find.text(tr.budgetEntryDialogEditTitle), findsOneWidget);
      expect(find.widgetWithText(TextFormField, "Bank fees"), findsOneWidget);

      // The entry names no poste, resource, taking, share or person, so its nature is inferred as
      // `Autre mouvement` and its own direction choice is drawn.
      expect(find.text(tr.budgetEntryDialogDirectionFieldLabel.toUpperCase()), findsOneWidget);
    },
  );

  testWidgets("undoing a receipt against a financing resource asks through OcptConfirmDialog, then "
      "tombstones the entry it names", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = projectsManager.currentProject!;
    final resourceId = await projectsManager.budgetFinancingService.createResource(
      database: project.database,
      label: "Regional grant",
    );
    await projectsManager.budgetFinancingService.updateResource(
      database: project.database,
      resourceId: resourceId!,
      amountCents: const Value(10000),
    );
    await projectsManager.budgetJournalService.createEntry(
      database: project.database,
      date: DateTime(2026),
      label: "Regional grant",
      resourceId: resourceId,
      creditCents: 4000,
    );

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openResources(tester);

    // The resource sits under its own `Contributions` family row, which opens on the family's
    // own twisty — the only family drawn here, this cash resource being the only live one.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tester.tap(find.text(tr.budgetFinancingUndoReceiptAction));
    await tester.pumpAndSettle();

    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    expect(find.text(tr.budgetUndoReceiptConfirmTitle), findsOneWidget);

    // Cancelling leaves the receipt in place — still partly received, so both gestures remain.
    await tester.tap(find.text(tr.budgetDeleteCancelAction));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text(tr.budgetFinancingRecordReceiptAction), findsOneWidget);
    expect(find.text(tr.budgetFinancingUndoReceiptAction), findsOneWidget);
    await tester.tap(find.text(tr.budgetFinancingUndoReceiptAction));
    await tester.pumpAndSettle();

    // Confirming tombstones the entry: the resource reads as having received nothing again, so
    // Record a receipt is offered once more and Undo the last receipt is gone.
    await tester.tap(find.text(tr.budgetDeleteConfirmAction));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text(tr.budgetFinancingRecordReceiptAction), findsOneWidget);
    expect(find.text(tr.budgetFinancingUndoReceiptAction), findsNothing);
  });

  testWidgets("withholds every cash-journal writing affordance under a previewed version", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = projectsManager.currentProject!;
    await projectsManager.budgetJournalService.createEntry(
      database: project.database,
      date: DateTime(2026),
      label: "Frozen entry",
      debitCents: 500,
    );

    final version = await projectsManager.createProjectVersion(name: "v1", note: "");
    expect(version, isNotNull);
    final versionId = version!.id;
    final previewResult = await projectsManager.previewVersion(versionId);
    expect(previewResult.status.isSuccess, isTrue);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openCashFlow(tester);

    expect(find.text("Frozen entry"), findsOneWidget);
    // The read-only statement withholds its rows' own ⋮ menu, the one writing affordance it
    // still offers while live.
    expect(find.byType(PopupMenuButton<String>), findsNothing);

    // Leave the preview so the working copy is what the next test opens onto.
    await projectsManager.exitPreview();
  });

  testWidgets(
    "withholds the creation footer and every row's own ⋮ menu under a previewed version",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final version = await projectsManager.createProjectVersion(name: "v1", note: "");
      expect(version, isNotNull);
      final versionId = version!.id;
      final previewResult = await projectsManager.previewVersion(versionId);
      expect(previewResult.status.isSuccess, isTrue);

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openExpenses(tester);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
      expect(find.text(tr.budgetPosteCreationAction), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);

      // Leave the preview so the working copy is what the next test opens onto.
      await projectsManager.exitPreview();
    },
  );

  testWidgets(
    "committing a quote line through Commit this line… shows it as committed in the tree",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A commitment is no longer created from a dedicated view of its own: a quote line's own
      // fiche is the one place `Commit this line…` is offered — seeding a poste with a line first
      // reaches it.
      final project = projectsManager.currentProject!;
      final posteId = await projectsManager.budgetQuoteService.createPoste(
        database: project.database,
        label: "Camera",
      );
      expect(posteId, isNotNull);
      final lineId = await projectsManager.budgetQuoteService.createLine(
        database: project.database,
        posteId: posteId!,
        label: "Camera deposit",
        unitAmountCents: const Value(5000),
      );
      expect(lineId, isNotNull);

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openExpenses(tester);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

      // The poste's own twisty is the only one on screen — this is the only poste seeded.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Camera deposit"));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr.budgetLineCommitAction));
      await tester.pumpAndSettle();

      // The dialog opened pre-filled from the line itself — nothing left to type.
      await tester.tap(inPanel(find.text(tr.budgetEntryDialogConfirmAction)));
      await tester.pumpAndSettle();

      // The line is promoted: its own `Commit this line…` primary action is gone.
      expect(find.text(tr.budgetLineCommitAction), findsNothing);
    },
  );

  testWidgets("deleting a commitment asks through OcptConfirmDialog", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = projectsManager.currentProject!;
    final posteId = await projectsManager.budgetQuoteService.createPoste(
      database: project.database,
      label: "Camera",
    );
    expect(posteId, isNotNull);
    await projectsManager.budgetJournalService.createCommitment(
      database: project.database,
      posteId: posteId!,
      label: "To be deleted",
      amountCents: 500,
    );

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openExpenses(tester);

    // The commitment names no line, so it draws as one of the poste's own off-line sub-rows —
    // reached by expanding the poste's own twisty, the only one seeded here. Its own menu is the
    // second `⋮` on screen, the first being the poste row's.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).at(1));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tester.tap(find.text(tr.budgetCommittedDeleteAction));
    await tester.pumpAndSettle();

    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    expect(find.text(tr.budgetDeleteCommitmentConfirmTitle), findsOneWidget);

    // Cancelling leaves the commitment in place.
    await tester.tap(find.text(tr.budgetDeleteCancelAction));
    await tester.pumpAndSettle();
    expect(find.text("To be deleted"), findsOneWidget);

    // Confirming removes it — the poste's own row is left with nothing to expand onto.
    await tester.tap(find.byType(PopupMenuButton<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetCommittedDeleteAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetDeleteConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text("To be deleted"), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
  });

  testWidgets(
    "settling a commitment records a debit entry and links it; unsettling leaves the entry alone",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      final posteId = await projectsManager.budgetQuoteService.createPoste(
        database: project.database,
        label: "Camera",
      );
      expect(posteId, isNotNull);
      await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId!,
        label: "Camera deposit",
        amountCents: 5000,
      );

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openExpenses(tester);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

      // The commitment names no line, so it draws as the poste's own off-line sub-row, reached
      // by expanding the poste's own twisty — the only one seeded here.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetCommittedSettleAction));
      await tester.pumpAndSettle();

      // The entry dialog opened pre-filled from the commitment.
      expect(find.widgetWithText(TextFormField, "Camera deposit"), findsOneWidget);
      expect(find.widgetWithText(TextFormField, "50.00"), findsOneWidget);

      // Scoped to the dialog itself, defensively — nothing else on this page reads the very same
      // `Save` label, but every other tap in this file already scopes the same way.
      await tester.tap(inPanel(find.text(tr.budgetEntryDialogConfirmAction)));
      await tester.pumpAndSettle();

      // The commitment now reads Settled, and Settle is no longer offered.
      expect(find.text(tr.budgetCommittedStatusSettledLabel), findsOneWidget);

      // The journal now carries the debit this settlement created.
      await openCashFlow(tester);
      expect(find.text("Camera deposit"), findsOneWidget);

      // Undoing the settlement leaves the entry in place. The poste's own twisty is still
      // expanded — that state outlives switching to another route and back.
      await openExpenses(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetCommittedUnsettleAction));
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetCommittedStatusSettledLabel), findsNothing);

      // The commitment is unsettled again, so it reappears under `À venir` — a second
      // "Camera deposit", the settlement's own entry above it in the statement left exactly as it
      // was.
      await openCashFlow(tester);
      expect(find.text("Camera deposit"), findsNWidgets(2));
    },
  );

  testWidgets(
    "accepting the wizard's own reconciliation strip on a commitment settles it, exactly as "
    "Settle does",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      final posteId = await projectsManager.budgetQuoteService.createPoste(
        database: project.database,
        label: "Camera",
      );
      expect(posteId, isNotNull);
      await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId!,
        label: "Atelier Verrier",
        amountCents: 25000,
      );

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openCashFlow(tester);
      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

      // The header's own button opens step 1 with `recordExpense` already selected (the
      // cash-movement family promoted from `tools › cashFlow`) — one click to step 2.
      await tester.tap(find.byKey(const Key("ocptBudgetHeaderCaptureButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();

      // Step 2: the optional poste attachment — `Hors devis`, the commitment's own match not
      // depending on naming the same poste.
      await tester.tap(find.byKey(const Key("ocptBudgetNewOffQuoteChoice")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
      await tester.pumpAndSettle();

      // Typed to match the commitment on both amount and wording — the strip appears once both
      // the amount and the label read as saveable, its own top candidate already selected.
      await tester.enterText(find.byKey(const Key("ocptBudgetNewLabelField")), "Atelier Verrier");
      await tester.enterText(find.byKey(const Key("ocptBudgetNewAmountField")), "250.00");
      await tester.pumpAndSettle();

      // Reconciliation is opt-in now: the candidate is on offer, but the reader picks it before it
      // settles anything — saving untouched would record a plain expense instead.
      await tester.tap(find.byKey(const Key("ocptBudgetNewMatchingCandidate0")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
      await tester.pumpAndSettle();

      // The commitment reads Settled, exactly as the dedicated Settle gesture leaves it — the
      // wizard's own accepted-suggestion mapping in `budget_mode.dart` named its poste and tax
      // basis, which only a commitment settlement (not a plain entry) ever does.
      await openExpenses(tester);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetCommittedStatusSettledLabel), findsOneWidget);
    },
  );

  testWidgets("withholds a committed line's own sub-row menu under a previewed version", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = projectsManager.currentProject!;
    final posteId = await projectsManager.budgetQuoteService.createPoste(
      database: project.database,
      label: "Camera",
    );
    expect(posteId, isNotNull);
    await projectsManager.budgetJournalService.createCommitment(
      database: project.database,
      posteId: posteId!,
      label: "Frozen commitment",
      amountCents: 500,
    );

    final version = await projectsManager.createProjectVersion(name: "v1", note: "");
    expect(version, isNotNull);
    final versionId = version!.id;
    final previewResult = await projectsManager.previewVersion(versionId);
    expect(previewResult.status.isSuccess, isTrue);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openExpenses(tester);

    // Expanding the poste's own twisty only reads — never withheld under a preview.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
    await tester.pumpAndSettle();

    expect(find.text("Frozen commitment"), findsOneWidget);

    // Exactly one `⋮` menu remains: the poste row's own, carrying nothing but the never-withheld
    // `Show this poste only` — the commitment sub-row's own menu (Settle, Edit, Delete) is gone
    // whole.
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    expect(find.text(tr.budgetCostTrackingFilterOnlyAction), findsOneWidget);
    expect(find.text(tr.budgetCommittedSettleAction), findsNothing);
    expect(find.text(tr.budgetCommittedDeleteAction), findsNothing);

    // Leave the preview so the working copy is what the next test opens onto.
    await projectsManager.exitPreview();
  });

  testWidgets("the export panel draws all four documents plus the standing project-package card", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetExportPanelTitle), findsOneWidget);
    expect(inPanel(find.text(tr.budgetExportQuoteTitle)), findsOneWidget);
    expect(inPanel(find.text(tr.budgetExportFinancingPlanTitle)), findsOneWidget);
    expect(inPanel(find.text(tr.budgetExportCashJournalTitle)), findsOneWidget);
    expect(inPanel(find.text(tr.budgetExportFinancialReportTitle)), findsOneWidget);
    expect(inPanel(find.text(tr.workspaceExportProjectPackageTitle)), findsOneWidget);

    // The ten CNC postes are seeded on first entry, so the quote and the financial report are
    // both available; a fresh project holds no live resource and no live entry yet, so the
    // financing plan and the cash journal are both greyed and inert with their own reason.
    expect(inPanel(find.text(tr.budgetExportQuoteDescription)), findsOneWidget);
    expect(inPanel(find.text(tr.budgetExportFinancialReportDescription)), findsOneWidget);
    expect(inPanel(find.text(tr.budgetExportUnavailableNoResourceReason)), findsOneWidget);
    expect(inPanel(find.text(tr.budgetExportUnavailableNoEntryReason)), findsOneWidget);

    // Picking the quote card opens its own options dialog.
    await tester.tap(inPanel(find.text(tr.budgetExportQuoteTitle)));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetExportPanelTitle), findsNothing);
    expect(find.text(tr.budgetExportQuoteDialogTitle), findsOneWidget);
  });

  testWidgets("offers a Help tab in the right dock, toggled from the toolbar's own button", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    expect(find.text(tr.budgetRightDockHelpTabLabel), findsNothing);

    await tester.tap(find.byTooltip(tr.workspaceHelpTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetRightDockHelpTabLabel), findsOneWidget);
    expect(find.byType(OcptBudgetHelp), findsOneWidget);

    // Clicking the toolbar's Help button again, while the tab is already showing, closes the
    // dock — the same toggle reading every other dock toggle already has.
    await tester.tap(find.byTooltip(tr.workspaceHelpTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetRightDockHelpTabLabel), findsNothing);
    expect(find.byType(OcptBudgetHelp), findsNothing);
  });
}
