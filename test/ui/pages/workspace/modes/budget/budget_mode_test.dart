// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' show Value;
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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_capture_band.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_help.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_poste_dock.dart';
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

  /// Switches the centre to the cost-tracking table, the mode's own default view.
  Future<void> openCostTracking(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tapHeaderChip(tester, tr.budgetHeaderCostTrackingSegmentLabel);
  }

  /// Switches the centre to the régie view.
  Future<void> openRegie(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tapHeaderChip(tester, tr.budgetHeaderRegieSegmentLabel);
  }

  /// Switches the centre to the cash journal view.
  Future<void> openCashJournal(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tapHeaderChip(tester, tr.budgetHeaderCashJournalSegmentLabel);
  }

  /// Switches the centre to the committed-spending view.
  Future<void> openCommitted(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tapHeaderChip(tester, tr.budgetHeaderCommittedSegmentLabel);
  }

  /// Switches the centre to the financing view.
  Future<void> openFinancing(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tapHeaderChip(tester, tr.budgetHeaderFinancingSegmentLabel);
  }

  /// Switches the centre to the revenue-sharing view.
  Future<void> openSharing(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await tapHeaderChip(tester, tr.budgetHeaderSharingSegmentLabel);
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
    // Scoped to the cost-tracking table: the left dock now prints every poste's own name too.
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

    // The cash journal's own empty state offers no `+ Entry` action at all, so an entry is seeded
    // first to reach the working table this test actually exercises.
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

    // Scoped to the dialog itself: the capture band sits on the very same document and reuses
    // these very same field labels for its own fields, so an unscoped finder is ambiguous the
    // moment both are on screen at once.
    await tester.enterText(
      inPanel(find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel)),
      "Camera rental",
    );
    await tester.enterText(
      inPanel(find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel)),
      "50.00",
    );
    await tester.tap(inPanel(find.text(tr.budgetEntryDialogConfirmAction)));
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
    "undoing a receipt against a financing resource asks through OcptConfirmDialog, then "
    "tombstones the entry it names",
    (tester) async {
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

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openFinancing(tester);

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
    },
  );

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

  testWidgets(
    "offers a Help tab in the right dock, toggled from the toolbar's own button",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
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
    },
  );

  testWidgets("the Inspector tab is withheld on a view with nothing to inspect", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    // Selecting a poste in the quote opens the dock on its inspector. Scoped to the
    // cost-tracking table: the left dock now prints every poste's own name too.
    await openCostTracking(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(OcptBudgetCostTracking),
        matching: find.text(tr.budgetCncPosteArtisticRights),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(tr.budgetRightDockInspectorTabLabel), findsOneWidget);

    // The régie has no poste and never puts one there, so the tab goes rather than showing a
    // stale one — and the dock falls back to the help panel instead of closing.
    await openRegie(tester);
    expect(find.text(tr.budgetRightDockInspectorTabLabel), findsNothing);
    expect(find.text(tr.budgetRightDockHelpTabLabel), findsOneWidget);
    expect(find.byType(OcptBudgetHelp), findsOneWidget);

    // Coming back brings the inspector back: the stored preference was never overwritten.
    await openCostTracking(tester);
    expect(find.text(tr.budgetRightDockInspectorTabLabel), findsOneWidget);
    expect(find.byType(OcptBudgetHelp), findsNothing);
  });

  testWidgets(
    "selecting a resource or a taking in the resources tree opens the Inspector tab",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Festival prize",
      );
      expect(resourceId, isNotNull);
      expect(revenueId, isNotNull);

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
      await openFinancing(tester);

      // The subsidy sits under its own family's twisty, the taking under the `Takings` one.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_right).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Regional grant"));
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetRightDockInspectorTabLabel), findsOneWidget);
      expect(find.text("Regional grant"), findsWidgets);

      await tester.tap(find.text("Festival prize"));
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetRightDockInspectorTabLabel), findsOneWidget);
      expect(find.text("Festival prize"), findsWidgets);
    },
  );

  testWidgets("the help panel follows the centre view, with no extra click", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    await tester.tap(find.byTooltip(tr.workspaceHelpTooltip));
    await tester.pumpAndSettle();

    // The cost-tracking table is the mode's default view, so its own page opens first.
    expect(find.text(tr.budgetHelpCostTrackingBody4), findsOneWidget);
    expect(find.text(tr.budgetHelpCashJournalBody4), findsNothing);

    // Switching the header's own reading changes the help panel's page without touching the dock
    // at all.
    await openCashJournal(tester);

    expect(find.text(tr.budgetHelpCostTrackingBody4), findsNothing);
    expect(find.text(tr.budgetHelpCashJournalBody4), findsOneWidget);
  });

  testWidgets("the chain highlights the step the current route stands on", (tester) async {
    // Comfortably wide, so the chain's own cells are read in the shape they normally wear.
    tester.view.physicalSize = const Size(2200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    await tester.tap(find.byTooltip(tr.workspaceHelpTooltip));
    await tester.pumpAndSettle();

    // The current step wears no words of its own: it is announced, not drawn — the same
    // wash-and-weight the header's own chips use. So the badge is looked for in the semantics
    // tree.
    Finder currentSteps() => find.bySemanticsLabel(
      RegExp(RegExp.escape(tr.budgetHelpChainCurrentStepBadge)),
    );

    // The cost report (the mode's own default view) reads every column at once, so no single step
    // of the chain stands for it in particular.
    expect(currentSteps(), findsNothing);

    // Neither does the resources document's own top level — its tree reads both columns at once.
    await openFinancing(tester);
    expect(currentSteps(), findsNothing);

    // The committed spending is the expenses chain's own `Committed` step.
    await openCommitted(tester);
    expect(currentSteps(), findsOneWidget);

    // Expenses read by date is the expenses chain's own `Paid` step.
    await openCashJournal(tester);
    expect(currentSteps(), findsOneWidget);
  });

  testWidgets("offers the help panel under a previewed version", (tester) async {
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

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    // The help action is never withheld under a preview — it writes nothing.
    await tester.tap(find.byTooltip(tr.workspaceHelpTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetRightDockHelpTabLabel), findsOneWidget);
    expect(find.byType(OcptBudgetHelp), findsOneWidget);
    expect(find.text(tr.budgetHelpCostTrackingBody4), findsOneWidget);

    // Leave the preview so the working copy is what the next test opens onto.
    await projectsManager.exitPreview();
  });

  testWidgets(
    "the capture band is offered on the cost report, the cash journal and the financing plan, "
    "absent on sharing",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();

      // The mode opens on the cost report, where the capture band already shows —
      // `openCostTracking` is a no-op here, kept for clarity.
      await openCostTracking(tester);
      expect(find.byType(OcptBudgetCaptureBand), findsOneWidget);

      // The cash journal is the very same document, read in a different order.
      await openCashJournal(tester);
      expect(find.byType(OcptBudgetCaptureBand), findsOneWidget);

      // Financing.
      await openFinancing(tester);
      expect(find.byType(OcptBudgetCaptureBand), findsOneWidget);

      // Sharing carries no capture band at all.
      await openSharing(tester);
      expect(find.byType(OcptBudgetCaptureBand), findsNothing);
    },
  );

  testWidgets(
    "the capture band keeps a half-typed draft between the cost report and the cash journal, and "
    "starts fresh on the financing plan",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();

      /// The draft as the band's own controllers hold it, read straight off them rather than
      /// through `find.text`: a wording echoed by a suggestion row would match that just as well,
      /// and what this test is about is whether the widget was remounted, not what is on screen.
      (String wording, String amount) draftOf() => (
        tester
            .widget<TextFormField>(find.byKey(const Key("ocptBudgetCaptureBandWordingField")))
            .controller!
            .text,
        tester
            .widget<TextFormField>(find.byKey(const Key("ocptBudgetCaptureBandAmountField")))
            .controller!
            .text,
      );

      await tester.enterText(
        find.byKey(const Key("ocptBudgetCaptureBandWordingField")),
        "Half-typed wording",
      );
      await tester.enterText(find.byKey(const Key("ocptBudgetCaptureBandAmountField")), "250.00");
      await tester.pumpAndSettle();
      expect(draftOf(), ("Half-typed wording", "250.00"));

      // The cash journal reads the very movements the cost report reads, in another order, and the
      // band captures the same debit on both: moving between them must not throw a draft away.
      await openCashJournal(tester);
      expect(draftOf(), ("Half-typed wording", "250.00"));

      // The financing plan captures a credit instead, so the band does remount there — its draft
      // cleared rather than carried into a direction it was never typed for.
      await openFinancing(tester);
      expect(draftOf(), ("", ""));
    },
  );

  testWidgets("the capture band is withheld on the committed spending and the régie", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    await openCommitted(tester);
    expect(find.byType(OcptBudgetCaptureBand), findsNothing);

    await openRegie(tester);
    expect(find.byType(OcptBudgetCaptureBand), findsNothing);

    // Back on the cost report, it returns.
    await openCostTracking(tester);
    expect(find.byType(OcptBudgetCaptureBand), findsOneWidget);
  });

  testWidgets("the capture band is withheld whole under a previewed version", (tester) async {
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

    // Not built at all — withheld, not disabled.
    expect(find.byType(OcptBudgetCaptureBand), findsNothing);

    // Still absent on resources, the other document that offers it while live.
    await openFinancing(tester);
    expect(find.byType(OcptBudgetCaptureBand), findsNothing);

    // Leave the preview so the working copy is what the next test opens onto.
    await projectsManager.exitPreview();
  });

  testWidgets(
    "clicking a dock card selects the poste and does not narrow every other view",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openCostTracking(tester);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

      // The right dock is closed until something is selected.
      expect(find.byType(OcptBudgetFiche), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(OcptBudgetPosteDock),
          matching: find.text(tr.budgetCncPosteArtisticRights),
        ),
      );
      await tester.pumpAndSettle();

      // Selected: the click opened the fiche on this very poste.
      expect(find.byType(OcptBudgetFiche), findsOneWidget);

      // Not filtered: the header's own chip still reads "every poste" — the one place every
      // view of the mode agrees on whether it is narrowed.
      expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsOneWidget);

      // The cash journal, a document the filter would narrow if it were set, still lists the
      // whole quote's own filter caption as unfiltered too.
      await openCashJournal(tester);
      expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsOneWidget);
    },
  );

  testWidgets("a dock card's own ⋮ menu narrows every view to that poste", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openCostTracking(tester);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    await tester.tap(
      find
          .descendant(of: find.byType(OcptBudgetPosteDock), matching: find.byType(PopupMenuButton<void>))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetPosteDockFilterOnlyAction));
    await tester.pumpAndSettle();

    // The header's own chip now names the poste rather than reading "every poste" — the mode
    // is narrowed, and every view that can honour the filter now agrees on it.
    expect(find.text(tr.budgetHeaderPosteFilterAllLabel), findsNothing);
    expect(find.text(tr.budgetCncPosteArtisticRights), findsWidgets);
  });

  testWidgets(
    "the poste dock is drawn on financing, régie and sharing, its filter entry withheld",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();

      Future<void> expectDockWithNoFilterEntry() async {
        expect(find.byType(OcptBudgetPosteDock), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(OcptBudgetPosteDock),
            matching: find.byType(PopupMenuButton<void>),
          ),
          findsNothing,
        );
      }

      await openFinancing(tester);
      await expectDockWithNoFilterEntry();

      await openRegie(tester);
      await expectDockWithNoFilterEntry();

      await openSharing(tester);
      await expectDockWithNoFilterEntry();
    },
  );
}
