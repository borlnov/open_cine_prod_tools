// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The navigator [_wrapWithLocalization] mounts, so [_RecordingRouterManager.pop] can close a
/// dialog opened through `showDialog` — mirrors `schedule_mode_test.dart`'s own instance of this
/// pattern.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] pops [_navigatorKey]'s own navigator.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates, [_navigatorKey], [ocptTheme]'s light theme and a
/// bare [Scaffold] — mirrors `schedule_mode_test.dart`'s own `_wrapWithLocalization`.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  navigatorKey: _navigatorKey,
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

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
      ..registerSingleton<OcptRouterManager>(_RecordingRouterManager())
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

  /// Switches the centre from the default dashboard to the cost-tracking table, whose own table
  /// this test suite exercises most.
  Future<void> openCostTracking(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tester.tap(find.text(tr.budgetHeaderCostTrackingSegmentLabel));
    await tester.pumpAndSettle();
  }

  /// Switches the centre to the cash journal view.
  Future<void> openCashJournal(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tester.tap(find.text(tr.budgetHeaderCashJournalSegmentLabel));
    await tester.pumpAndSettle();
  }

  /// Switches the centre to the committed-spending view.
  Future<void> openCommitted(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tester.tap(find.text(tr.budgetHeaderCommittedSegmentLabel));
    await tester.pumpAndSettle();
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

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final statusBar = tester.widget<OcptBudgetStatusBar>(find.byType(OcptBudgetStatusBar));
    expect(statusBar.posteCount, 10);

    await openCostTracking(tester);
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    expect(find.text(tr.budgetCncPosteArtisticRights), findsOneWidget);
    expect(find.text(tr.budgetCncPosteOverheads), findsOneWidget);
  });

  testWidgets("the simplified switch swaps every poste's label and hides the N° column", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openCostTracking(tester);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    expect(find.text(tr.budgetCncPosteArtisticRights), findsOneWidget);
    expect(find.text("1"), findsWidgets);

    await tester.tap(find.text(tr.budgetHeaderSimplifiedSegmentLabel));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetCncPosteArtisticRights), findsNothing);
    expect(find.text(tr.budgetCncPosteSimpleArtisticRights), findsOneWidget);
  });

  testWidgets("deleting a poste asks through OcptConfirmDialog", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openCostTracking(tester);

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

  testWidgets("creating a cash-journal entry through its own dialog shows it in the table", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The cash journal's own empty state offers no `+ Entry` action at all (mirrors the
    // dashboard's own reading for a project with no poste), so an entry is seeded first to reach
    // the working table this test actually exercises.
    final project = projectsManager.currentProject!;
    await projectsManager.budgetJournalService.createEntry(
      database: project.database,
      date: DateTime(2026),
      label: "Seed entry",
      debitCents: 100,
    );

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openCashJournal(tester);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tester.tap(find.text(tr.budgetCashJournalEntryCreationAction));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera rental",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "50.00",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text("Camera rental"), findsOneWidget);
  });

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

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openCashJournal(tester);

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
    "withholds every cash-journal writing affordance under a previewed version",
    (tester) async {
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

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openCashJournal(tester);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
      expect(find.text("Frozen entry"), findsOneWidget);
      expect(find.text(tr.budgetCashJournalEntryCreationAction), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);

      // Leave the preview so the working copy is what the next test opens onto.
      await projectsManager.exitPreview();
    },
  );

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

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openCostTracking(tester);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
      expect(find.text(tr.budgetPosteCreationAction), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);

      // Leave the preview so the working copy is what the next test opens onto.
      await projectsManager.exitPreview();
    },
  );

  testWidgets("creating a commitment through its own dialog shows it in the table", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The committed-spending view's own empty state offers no `+ Commitment` action at all
    // (mirrors the cash journal's own reading), so a commitment is seeded first to reach the
    // working table this test actually exercises.
    final project = projectsManager.currentProject!;
    final posteId = await projectsManager.budgetQuoteService.createPoste(
      database: project.database,
      label: "Camera",
    );
    expect(posteId, isNotNull);
    await projectsManager.budgetJournalService.createCommitment(
      database: project.database,
      posteId: posteId!,
      label: "Seed commitment",
      amountCents: 100,
    );

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openCommitted(tester);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tester.tap(find.text(tr.budgetCommittedCreationAction));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera deposit",
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Camera").last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "50.00",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text("Camera deposit"), findsOneWidget);
  });

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

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openCommitted(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
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

    // Confirming removes it, and the view falls back to the shared empty state.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetCommittedDeleteAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetDeleteConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text("To be deleted"), findsNothing);
    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
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

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openCommitted(tester);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetCommittedSettleAction));
      await tester.pumpAndSettle();

      // The entry dialog opened pre-filled from the commitment.
      expect(find.widgetWithText(TextFormField, "Camera deposit"), findsOneWidget);
      expect(find.widgetWithText(TextFormField, "50.00"), findsOneWidget);

      await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
      await tester.pumpAndSettle();

      // The commitment now reads Settled, and Settle is no longer offered.
      expect(find.text(tr.budgetCommittedStatusSettledLabel), findsOneWidget);

      // The journal now carries the debit this settlement created.
      await openCashJournal(tester);
      expect(find.text("Camera deposit"), findsOneWidget);

      // Undoing the settlement leaves the entry in place.
      await openCommitted(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetCommittedUnsettleAction));
      await tester.pumpAndSettle();

      expect(find.text(tr.budgetCommittedStatusSettledLabel), findsNothing);

      await openCashJournal(tester);
      expect(find.text("Camera deposit"), findsOneWidget);
    },
  );

  testWidgets(
    "withholds every committed-spending writing affordance under a previewed version",
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
        label: "Frozen commitment",
        amountCents: 500,
      );

      final version = await projectsManager.createProjectVersion(name: "v1", note: "");
      expect(version, isNotNull);
      final versionId = version!.id;
      final previewResult = await projectsManager.previewVersion(versionId);
      expect(previewResult.status.isSuccess, isTrue);

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openCommitted(tester);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
      expect(find.text("Frozen commitment"), findsOneWidget);
      expect(find.text(tr.budgetCommittedCreationAction), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);

      // Leave the preview so the working copy is what the next test opens onto.
      await projectsManager.exitPreview();
    },
  );

  testWidgets(
    "the export panel draws all four documents plus the standing project-package card",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
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
    },
  );
}
