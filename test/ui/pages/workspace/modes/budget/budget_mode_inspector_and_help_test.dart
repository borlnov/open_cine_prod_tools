// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_help.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'budget_mode_test_doubles.dart';

/// Run the tests of the budget mode inspector and help.
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
    await projectsManager.closeCurrentProject().okOrFail;
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

  /// Switches the centre to the tools drawer's own `Logistics` page.
  Future<void> openLogistics(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await openTools(tester, page: tr.budgetHeaderLogisticsSegmentLabel);
  }

  /// Switches the centre to the tools drawer's own revenue-sharing page.
  Future<void> openSharing(WidgetTester tester) async {
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await openTools(tester, page: tr.budgetHeaderSharingSegmentLabel);
  }

  /// The `⋮` menu of the account row named [label], in the expenses table — needed because
  /// `OcptBudgetCostTracking` draws its identity pane (a row's own name) and its amounts pane
  /// (where a row's own `⋮` menu lives) as sibling subtrees sharing one vertical scroll, not one
  /// ancestor of the other, so [find.ancestor]/[find.descendant] cannot connect the two.
  Finder menuInRowOf(WidgetTester tester, String label) {
    final rowY = tester.getCenter(find.text(label)).dy;
    final menus = find.byType(PopupMenuButton<String>);
    for (var index = 0; index < tester.widgetList(menus).length; index++) {
      final candidate = menus.at(index);
      if ((tester.getCenter(candidate).dy - rowY).abs() < 4) {
        return candidate;
      }
    }
    throw StateError("No ⋮ menu found level with the row naming '$label'");
  }

  testWidgets("the Inspector tab is withheld on a view with nothing to inspect", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    // Selecting an account in the quote opens the right dock on its inspector.
    await openExpenses(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(OcptBudgetCostTracking),
        matching: find.text(tr.budgetCncAccountArtisticRights),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(tr.budgetRightDockInspectorTabLabel), findsOneWidget);

    // The logistics has no account and never puts one there, so the tab goes rather than showing a
    // stale one — and the dock falls back to the help panel instead of closing.
    await openLogistics(tester);
    expect(find.text(tr.budgetRightDockInspectorTabLabel), findsNothing);
    expect(find.text(tr.budgetRightDockHelpTabLabel), findsOneWidget);
    expect(find.byType(OcptBudgetHelp), findsOneWidget);

    // Coming back brings the inspector back: the stored preference was never overwritten.
    await openExpenses(tester);
    expect(find.text(tr.budgetRightDockInspectorTabLabel), findsOneWidget);
    expect(find.byType(OcptBudgetHelp), findsNothing);
  });

  testWidgets("selecting a resource or a taking in the resources tree opens the Inspector tab", (
    tester,
  ) async {
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

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
    await openResources(tester);

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
  });

  testWidgets("the help panel follows the centre view, with no extra click", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    await tester.tap(find.byTooltip(tr.workspaceHelpTooltip));
    await tester.pumpAndSettle();

    // The dashboard is the mode's default view now, so its own page opens first.
    expect(find.text(tr.budgetHeaderDashboardTitle), findsWidgets);

    // Switching to the cost-tracking table changes the help panel's page without touching the
    // dock at all.
    await openExpenses(tester);
    expect(find.text(tr.budgetHelpExpensesBody5), findsOneWidget);
    expect(find.text(tr.budgetHelpCashFlowBody5), findsNothing);

    // Switching the header's own reading changes the help panel's page without touching the dock
    // at all.
    await openCashFlow(tester);

    expect(find.text(tr.budgetHelpExpensesBody5), findsNothing);
    expect(find.text(tr.budgetHelpCashFlowBody5), findsOneWidget);
  });

  testWidgets("the chain highlights the step the current route stands on", (tester) async {
    // Comfortably wide, so the chain's own cells are read in the shape they normally wear.
    tester.view.physicalSize = const Size(2200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    await tester.tap(find.byTooltip(tr.workspaceHelpTooltip));
    await tester.pumpAndSettle();

    // The current step wears no words of its own: it is announced, not drawn — the same
    // wash-and-weight the header's own chips use. So the badge is looked for in the semantics
    // tree.
    Finder currentSteps() =>
        find.bySemanticsLabel(RegExp(RegExp.escape(tr.budgetHelpChainCurrentStepBadge)));

    // The cost report reads every column at once, so no single step of the chain stands for it
    // in particular — driven explicitly, the dashboard no longer being the same route.
    await openExpenses(tester);
    expect(currentSteps(), findsNothing);

    // Neither does the resources document's own top level — its tree reads both columns at once.
    await openResources(tester);
    expect(currentSteps(), findsNothing);

    // Expenses read by date, the tools drawer's own cash flow page, is the expenses chain's own
    // `Paid` step.
    await openCashFlow(tester);
    expect(currentSteps(), findsOneWidget);
  });

  testWidgets("offers the help panel under a previewed version", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final version = await projectsManager
        .createProjectVersion(name: "v1", note: "")
        .maybeValueOrFail;
    expect(version, isNotNull);
    final versionId = version!.id;
    final previewResult = await projectsManager.previewVersion(versionId);
    expect(previewResult.status.isSuccess, isTrue);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    // The help action is never withheld under a preview — it writes nothing.
    await tester.tap(find.byTooltip(tr.workspaceHelpTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetRightDockHelpTabLabel), findsOneWidget);
    expect(find.byType(OcptBudgetHelp), findsOneWidget);

    // Driven onto the cost report explicitly — the mode no longer opens on it by default.
    await openExpenses(tester);
    expect(find.text(tr.budgetHelpExpensesBody5), findsOneWidget);

    // Leave the preview so the working copy is what the next test opens onto.
    await projectsManager.exitPreview().okOrFail;
  });

  testWidgets(
    "the header's own capture button reads + Nouveau on all five routes, the dashboard included",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
      final button = find.byKey(const Key("ocptBudgetHeaderCaptureButton"));

      // The mode opens on the dashboard, which now offers the very same button as every other
      // route — no route withholds it of its own accord any more, only a previewed version does.
      expect(button, findsOneWidget);
      expect(find.text(tr.budgetHeaderNewAction), findsOneWidget);

      await openExpenses(tester);
      expect(button, findsOneWidget);

      await openResources(tester);
      expect(button, findsOneWidget);

      // The tools drawer's own cash flow page now offers it too — it carries no capture
      // affordance of its own, but the daily gesture of recording a movement is one click away.
      await openCashFlow(tester);
      expect(button, findsOneWidget);

      await openLogistics(tester);
      expect(button, findsOneWidget);

      await openSharing(tester);
      expect(button, findsOneWidget);
    },
  );

  testWidgets(
    "the régie's own in-page defrayal button is gone — the header's own button is the only door "
    "left",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // The défraiements section draws nothing at all while the logistics holds neither a shooting
      // day nor a defrayal yet: one is seeded so the section itself is on screen.
      final project = projectsManager.currentProject!;
      await projectsManager.budgetAllowancesService
          .createAllowance(
            database: project.database,
            personId: null,
            kind: OcptBudgetAllowanceKind.other,
            label: "Taxi",
            date: DateTime(2026, 3),
            endDate: null,
            quantityMilli: 1000,
            unitAmountMilliCents: 2000000,
            notes: "",
          )
          .maybeValueOrFail;

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openLogistics(tester);
      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

      // The page's own creation button is gone — every defrayal is now typed through the wizard.
      expect(find.text(tr.budgetLogisticsAllowancesSectionTitle), findsOneWidget);
      expect(find.text(tr.budgetLogisticsAllowanceCreationAction), findsNothing);

      // The header's own button, promoted to `defrayPerson`, one click from the defrayal form.
      await tester.tap(find.byKey(const Key("ocptBudgetHeaderCaptureButton")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("ocptBudgetNewSaveButton")), findsOneWidget);
    },
  );

  testWidgets("the header's own capture button is withheld whole under a previewed version", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final version = await projectsManager
        .createProjectVersion(name: "v1", note: "")
        .maybeValueOrFail;
    expect(version, isNotNull);
    final versionId = version!.id;
    final previewResult = await projectsManager.previewVersion(versionId);
    expect(previewResult.status.isSuccess, isTrue);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();

    // Driven onto every route that offers the button while live, so its absence here is the
    // preview's own doing — not built at all, withheld, never disabled.
    await openExpenses(tester);
    expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsNothing);

    await openResources(tester);
    expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsNothing);

    await openLogistics(tester);
    expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsNothing);

    await openSharing(tester);
    expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsNothing);

    // Leave the preview so the working copy is what the next test opens onto.
    await projectsManager.exitPreview().okOrFail;
  });

  testWidgets("selecting a poste row opens the fiche without narrowing any view", (tester) async {
    tester.view.physicalSize = const Size(1750, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
    await tester.pumpAndSettle();
    await openExpenses(tester);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

    // The right dock is closed until something is selected.
    expect(find.byType(OcptBudgetDetail), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(OcptBudgetCostTracking),
        matching: find.text(tr.budgetCncAccountArtisticRights),
      ),
    );
    await tester.pumpAndSettle();

    // Selected: the click opened the detail panel on this very account.
    expect(find.byType(OcptBudgetDetail), findsOneWidget);

    // Not filtered: the header draws no account filter tag at all — the one place every view of
    // the mode agrees on whether it is narrowed.
    Finder filterTagIcon() =>
        find.descendant(of: find.byType(OcptBudgetHeader), matching: find.byIcon(Icons.close));
    expect(filterTagIcon(), findsNothing);

    // The cash flow page, a document the filter would narrow if it were set, still lists every
    // account's own movement rather than one.
    await openCashFlow(tester);
    expect(filterTagIcon(), findsNothing);
  });

  testWidgets(
    "a poste row's own ⋮ menu narrows the expenses table; the header's own filter tag stands on "
    "every route and clears it everywhere at once",
    (tester) async {
      tester.view.physicalSize = const Size(1750, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();
      await openExpenses(tester);

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

      // No tag drawn while nothing is filtered.
      Finder filterTag() => find.descendant(
        of: find.byType(OcptBudgetHeader),
        matching: find.text(tr.budgetCncAccountArtisticRights),
      );
      expect(filterTag(), findsNothing);

      await tester.tap(menuInRowOf(tester, tr.budgetCncAccountArtisticRights));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetCostTrackingFilterOnlyAction));
      await tester.pumpAndSettle();

      // The header now draws the filter tag naming the account — the mode is narrowed.
      expect(filterTag(), findsOneWidget);

      // And the narrowing is real, not merely announced by the tag: the expenses table has
      // dropped every other account.
      Finder inCostTracking(Finder matching) =>
          find.descendant(of: find.byType(OcptBudgetCostTracking), matching: matching);
      expect(inCostTracking(find.text(tr.budgetCncAccountArtisticRights)), findsOneWidget);
      expect(inCostTracking(find.text(tr.budgetCncAccountOverheads)), findsNothing);

      // The tag still stands while a route that does not honour the filter is on screen — the
      // tools drawer's own cash flow page still lists every account's own movement rather than one.
      await openCashFlow(tester);
      expect(filterTag(), findsOneWidget);

      // Clearing it, through the tag's own ✕, is read everywhere at once.
      await openExpenses(tester);
      await tester.tap(
        find.descendant(of: find.byType(OcptBudgetHeader), matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();

      expect(filterTag(), findsNothing);
      expect(inCostTracking(find.text(tr.budgetCncAccountOverheads)), findsOneWidget);
    },
  );

  group("the floating add at a compact width", () {
    testWidgets(
      "is present at a compact width, and the header's own capture button is withheld — never "
      "both at once",
      (tester) async {
        tester.view.physicalSize = const Size(700, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsNothing);
      },
    );

    testWidgets(
      "is absent at a desktop width, where the header's own capture button is the only door",
      (tester) async {
        tester.view.physicalSize = const Size(1750, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.byKey(const Key("ocptBudgetHeaderCaptureButton")), findsOneWidget);
      },
    );

    testWidgets("is drawn icon-only, with no visible label text of its own", (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));

      // Icon-only: no FloatingActionButton.extended drawing the label text, and the label lives
      // on as the button's tooltip instead — the standing accessibility fallback.
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(Icon), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.text(tr.budgetHeaderNewAction),
        ),
        findsNothing,
      );
      expect(find.byTooltip(tr.budgetHeaderNewAction), findsOneWidget);
    });

    testWidgets(
      "tapping it fires the header's own + New flow, creating a quote line and opening the "
      "fiche on it",
      (tester) async {
        tester.view.physicalSize = const Size(700, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
        await tester.pumpAndSettle();
        await openExpenses(tester);

        final tr = Tr.of(tester.element(find.byType(OcptBudgetMode)));
        expect(find.byType(OcptBudgetDetail), findsNothing);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // The very same wizard the header's own capture button opens, its `addQuoteLine` gesture
        // pre-selected for the expenses route — one click reaches step 2.
        expect(find.byType(OcptBudgetNewDialog), findsOneWidget);
        await tester.tap(find.byKey(const Key("ocptBudgetNewContinueButton")));
        await tester.pumpAndSettle();

        // Step 2: which account this line prices — scoped to the wizard, whose background still
        // shows the very same account name in the expenses table underneath it.
        await tester.tap(
          find.descendant(
            of: find.byType(OcptBudgetNewDialog),
            matching: find.text(tr.budgetCncAccountArtisticRights),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key("ocptBudgetNewAttachmentContinueButton")));
        await tester.pumpAndSettle();

        // Step 3: the line's own form — label, quantity and unit price, in that order; the unit
        // field between quantity and unit price is left blank, being optional.
        final fields = find.descendant(
          of: find.byType(OcptBudgetNewDialog),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(fields.at(0), "Camera rental");
        await tester.enterText(fields.at(1), "1");
        await tester.enterText(fields.at(3), "50.00");
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key("ocptBudgetNewSaveButton")));
        await tester.pumpAndSettle();

        // The line lands selected, the right dock opened on its own detail panel — exactly what the
        // header's own capture button already does for this same gesture
        // (`OcptBudgetBloc._onLineCreated`).
        expect(find.byType(OcptBudgetDetail), findsOneWidget);
        expect(find.text("Camera rental"), findsWidgets);
      },
    );

    testWidgets("is withheld under a previewed version", (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final version = await projectsManager
          .createProjectVersion(name: "v1", note: "")
          .maybeValueOrFail;
      expect(version, isNotNull);
      final previewResult = await projectsManager.previewVersion(version!.id);
      expect(previewResult.status.isSuccess, isTrue);

      await tester.pumpWidget(wrapWithLocalization(const OcptBudgetMode()));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);

      // Leave the preview so the working copy is what the next test opens onto.
      await projectsManager.exitPreview().okOrFail;
    });
  });
}
