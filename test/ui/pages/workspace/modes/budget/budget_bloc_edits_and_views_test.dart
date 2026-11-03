// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_budget_cnc_accounts.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../../../ocpt_result_expectations.dart';
import 'budget_bloc_test_doubles.dart';

/// The seed the ten real CNC accounts make, resolved without a `Tr` (the label text itself is never
/// read by these tests, only the ids and the count): the seeding path itself is what is under
/// test, so it is exercised against the very ids `OcptBudgetQuoteService` will actually seed in
/// the app.
final _realCncSeed = [
  for (final account in ocptBudgetCncAccounts)
    OcptBudgetAccountSeed(
      id: account.id,
      code: account.code,
      label: account.code,
      simpleLabel: null,
    ),
];

/// Run the tests of the budget bloc edits and views.
void main() {
  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds a bloc wired to the test project, seeded with [seed] (defaulting to [smallSeed]).
  OcptBudgetBloc buildBloc({List<OcptBudgetAccountSeed> seed = smallSeed}) => OcptBudgetBloc(
    seed: seed,
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the expenses bloc of [modeBloc], with a fast field-edit debounce so tests don't have to
  /// wait out the real 2 s one.
  OcptBudgetExpensesBloc buildExpenses(
    OcptBudgetBloc modeBloc, {
    Duration fieldEditDebounce = const Duration(milliseconds: 10),
  }) {
    final bloc = OcptBudgetExpensesBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: fieldEditDebounce,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group("what writes the typed edits first", () {
    /// Types an edit into the expenses view, dispatches [event] to the mode, and answers whether
    /// the edit was written (and so forgotten) by the time the mode has handled it.
    Future<bool> flushes(OcptBudgetEvent event) async {
      final bloc = buildBloc();
      final expensesBloc = buildExpenses(bloc, fieldEditDebounce: const Duration(days: 1));
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: loaded.accounts.first.id,
          field: OcptBudgetField.accountLabel,
          rawValue: "Typed",
        ),
      );
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      bloc.add(event);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final isWritten = expensesBloc.state.pendingFieldEdits.isEmpty;
      await expensesBloc.close();
      await bloc.close();
      return isWritten;
    }

    test("a view, a tools page, the switches, a dock tab, a poste, a line, a commitment, an "
        "entry and the poste filter do", () async {
      for (final event in <OcptBudgetEvent>[
        const OcptBudgetViewSelectedEvent(view: OcptBudgetView.expenses),
        const OcptBudgetToolsViewSelectedEvent(toolsView: OcptBudgetToolsView.logistics),
        const OcptBudgetSimplifiedToggledEvent(isSimplified: true),
        const OcptBudgetTaxBasisChangedEvent(basis: OcptBudgetTaxBasis.excludingTax),
        const OcptBudgetRightDockTabSelectedEvent(tab: OcptBudgetRightDockTab.versions),
        const OcptBudgetAccountSelectedEvent(accountId: "gone"),
        const OcptBudgetLineSelectedEvent(lineId: "gone"),
        const OcptBudgetCommitmentSelectedEvent(commitmentId: "gone"),
        const OcptBudgetEntrySelectedEvent(entryId: "gone"),
        const OcptBudgetAccountFilterSelectedEvent(accountId: null),
      ]) {
        expect(await flushes(event), isTrue, reason: "$event writes the typed edit first");
      }
    });

    test("a receipt, a resource, a taking, a share, the dock toggle, the provisioning poste, a "
        "tree node and the project settings do not", () async {
      for (final event in <OcptBudgetEvent>[
        const OcptBudgetReceiptSelectedEvent(receiptId: "gone"),
        const OcptBudgetResourceSelectedEvent(resourceId: "gone"),
        const OcptBudgetRevenueSelectedEvent(revenueId: "gone"),
        const OcptBudgetShareSelectedEvent(shareId: "gone"),
        const OcptBudgetRightDockToggledEvent(),
        const OcptBudgetProvisionAccountSelectedEvent(accountId: "gone"),
        const OcptBudgetRowExpansionToggledEvent(nodeId: "gone"),
        const OcptBudgetProjectSettingsChangedEvent(),
      ]) {
        expect(await flushes(event), isFalse, reason: "$event leaves the typed edit pending");
      }
    });
  });

  group("the epochs the views react to", () {
    test("entering the mode moves both epochs and says why", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.reloadEpoch, greaterThan(0));
      expect(state.selectionEpoch, greaterThan(0));
      expect(state.selectionCause, OcptBudgetSelectionCause.load);
    });

    test("reading the snapshot again answers true and moves the reload epoch alone", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      // Written behind the mode's back, as a view's own write would be.
      await projectsManager.budgetQuoteService
          .createAccount(database: projectsManager.currentProject!.database, label: "Late poste")
          .maybeValueOrFail;

      final hasRead = await bloc.reload({OcptBudgetReloadScope.snapshot});

      expect(hasRead, isTrue);
      expect(bloc.state.accounts, hasLength(smallSeed.length + 1));
      expect(bloc.state.reloadEpoch, greaterThan(loaded.reloadEpoch));
      expect(bloc.state.selectionEpoch, loaded.selectionEpoch);
    });

    test("reading again with no project open answers false and moves nothing", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      await projectsManager.closeCurrentProject().okOrFail;

      final hasRead = await bloc.reload({OcptBudgetReloadScope.snapshot});

      expect(hasRead, isFalse);
      expect(bloc.state.reloadEpoch, loaded.reloadEpoch);
    });

    test("a read that fails answers false and moves nothing", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final database = projectsManager.currentProject!.database;

      await database.customStatement("ALTER TABLE budget_entries RENAME TO budget_entries_gone");
      try {
        final hasRead = await bloc.reload({OcptBudgetReloadScope.snapshot});

        expect(hasRead, isFalse);
        expect(bloc.state.reloadEpoch, loaded.reloadEpoch);
      } finally {
        await database.customStatement("ALTER TABLE budget_entries_gone RENAME TO budget_entries");
      }
    });

    test("each way of moving the selection names itself", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;

      Future<OcptBudgetSelectionCause> causeOf(OcptBudgetEvent event) async {
        final before = bloc.state.selectionEpoch;
        bloc.add(event);
        final moved = await waitForState(bloc, (state) => state.selectionEpoch > before);
        return moved.selectionCause;
      }

      expect(
        await causeOf(OcptBudgetAccountSelectedEvent(accountId: accountId)),
        OcptBudgetSelectionCause.selected,
      );
      expect(
        await causeOf(OcptBudgetAccountFilterSelectedEvent(accountId: accountId)),
        OcptBudgetSelectionCause.filtered,
      );
      expect(
        await causeOf(OcptBudgetProvisionAccountSelectedEvent(accountId: accountId)),
        OcptBudgetSelectionCause.provisionSelected,
      );
      expect(
        await causeOf(
          const OcptBudgetViewSelectedEvent(view: OcptBudgetView.expenses, clearSelection: true),
        ),
        OcptBudgetSelectionCause.viewChanged,
      );

      // An account a view created is selected by the mode on that view's behalf.
      final expensesBloc = buildExpenses(bloc);
      final before = bloc.state.selectionEpoch;
      expensesBloc.add(const OcptBudgetAccountCreatedEvent());
      final created = await waitForState(bloc, (state) => state.selectionEpoch > before);
      expect(created.selectionCause, OcptBudgetSelectionCause.created);
    });

    test("selecting the same row again is still a move, a stale id is not", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;

      bloc.add(OcptBudgetAccountSelectedEvent(accountId: accountId));
      final selected = await waitForState(
        bloc,
        (state) => state.selectionEpoch > loaded.selectionEpoch,
      );

      bloc.add(OcptBudgetAccountSelectedEvent(accountId: accountId));
      await waitForState(bloc, (state) => state.selectionEpoch > selected.selectionEpoch);

      final reselected = bloc.state;
      bloc.add(const OcptBudgetAccountSelectedEvent(accountId: "not-a-poste"));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.selectionEpoch, reselected.selectionEpoch);
    });

    test("a read that finds the selected poste gone drops it and says so", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;

      bloc.add(OcptBudgetAccountSelectedEvent(accountId: accountId));
      final selected = await waitForState(bloc, (state) => state.selectedAccountId == accountId);

      // Deleted behind the mode's back, as another view's write would be.
      await projectsManager.budgetQuoteService
          .deleteAccount(database: projectsManager.currentProject!.database, accountId: accountId)
          .okOrFail;
      expect(await bloc.reload({OcptBudgetReloadScope.snapshot}), isTrue);

      expect(bloc.state.selection, isNull);
      expect(bloc.state.selectionEpoch, greaterThan(selected.selectionEpoch));
      expect(bloc.state.selectionCause, OcptBudgetSelectionCause.reconciled);
    });

    test("a change that replaces no data leaves both epochs alone", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetSimplifiedToggledEvent(isSimplified: true));
      await waitForState(bloc, (state) => state.isSimplified);

      expect(bloc.state.reloadEpoch, loaded.reloadEpoch);
      expect(bloc.state.selectionEpoch, loaded.selectionEpoch);
    });

    test("the project settings page moves the reload epoch, never the selection", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.reloadEpoch > loaded.reloadEpoch);

      expect(bloc.state.selectionEpoch, loaded.selectionEpoch);
    });
  });

  group("loading the quote", () {
    test("seeds the ten CNC postes on the first read of an empty project", () async {
      final bloc = buildBloc(seed: _realCncSeed);
      addTearDown(bloc.close);

      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.accounts, hasLength(10));
      expect(
        state.accounts.map((account) => account.id).toSet(),
        ocptBudgetCncAccounts.map((c) => c.id).toSet(),
      );
    });

    test("reads the project's own currency and default VAT rate", () async {
      final project = projectsManager.currentProject!;
      await projectsManager.saveCurrentProjectCurrencyCode("USD").okOrFail;
      await projectsManager.saveCurrentProjectDefaultVatRateBasisPoints(2000).okOrFail;

      final bloc = buildBloc();
      addTearDown(bloc.close);

      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.currencyCode, "USD");
      expect(state.defaultVatRateBasisPoints, 2000);
      // The project variable is only read to force the settings write above onto the very
      // project the bloc reads; nothing further is asserted on it.
      expect(project.name, "My Movie");
    });

    test("re-seeding does not duplicate postes already deleted", () async {
      final project = projectsManager.currentProject!;
      final first = await projectsManager.budgetQuoteService
          .loadAccounts(database: project.database, seed: smallSeed)
          .valueOrFail;
      await projectsManager.budgetQuoteService
          .deleteAccount(database: project.database, accountId: first.first.id)
          .okOrFail;

      final bloc = buildBloc();
      addTearDown(bloc.close);
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.accounts, hasLength(smallSeed.length - 1));
    });
  });

  group("selecting a view", () {
    test("writes the view alone, leaving every other route-adjacent field untouched", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;

      bloc
        ..add(OcptBudgetAccountSelectedEvent(accountId: accountId))
        ..add(OcptBudgetAccountFilterSelectedEvent(accountId: accountId))
        ..add(OcptBudgetRowExpansionToggledEvent(nodeId: accountId))
        ..add(const OcptBudgetSimplifiedToggledEvent(isSimplified: true))
        ..add(const OcptBudgetTaxBasisChangedEvent(basis: OcptBudgetTaxBasis.excludingTax));
      await waitForState(
        bloc,
        (state) =>
            state.selectedAccountId == accountId &&
            state.filterAccountId == accountId &&
            state.expandedNodeIds.contains(accountId) &&
            state.isSimplified &&
            state.taxBasis == OcptBudgetTaxBasis.excludingTax,
      );

      bloc.add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.resources));
      final switched = await waitForState(bloc, (state) => state.view == OcptBudgetView.resources);

      expect(switched.selectedAccountId, accountId);
      expect(switched.filterAccountId, accountId);
      expect(switched.expandedNodeIds, contains(accountId));
      expect(switched.isSimplified, isTrue);
      expect(switched.taxBasis, OcptBudgetTaxBasis.excludingTax);
    });

    test("the header's own chip drops the selection, the filter and expansion untouched", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;

      bloc
        ..add(OcptBudgetAccountSelectedEvent(accountId: accountId))
        ..add(OcptBudgetAccountFilterSelectedEvent(accountId: accountId))
        ..add(OcptBudgetRowExpansionToggledEvent(nodeId: accountId));
      await waitForState(
        bloc,
        (state) =>
            state.selectedAccountId == accountId &&
            state.filterAccountId == accountId &&
            state.expandedNodeIds.contains(accountId),
      );

      bloc.add(
        const OcptBudgetViewSelectedEvent(view: OcptBudgetView.resources, clearSelection: true),
      );
      final switched = await waitForState(bloc, (state) => state.view == OcptBudgetView.resources);

      // The detail panel greets the new view empty — the object belonged to the view being left.
      expect(switched.selection, isNull);
      expect(switched.selectedAccountId, isNull);
      // The filter and the expansion are the mode's, not the detail panel's, so they survive the
      // switch.
      expect(switched.filterAccountId, accountId);
      expect(switched.expandedNodeIds, contains(accountId));
    });

    test("the header's own tools switch drops the selection the same way", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;

      bloc.add(OcptBudgetAccountSelectedEvent(accountId: accountId));
      await waitForState(bloc, (state) => state.selectedAccountId == accountId);

      bloc.add(
        const OcptBudgetToolsViewSelectedEvent(
          toolsView: OcptBudgetToolsView.sharing,
          clearSelection: true,
        ),
      );
      final switched = await waitForState(
        bloc,
        (state) => state.toolsView == OcptBudgetToolsView.sharing,
      );

      expect(switched.selection, isNull);
    });
  });

  group("the right dock", () {
    test("persists the fraction and the last tab", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetRightDockFractionChangedEvent(fraction: 0.3));
      await waitForState(bloc, (state) => state.rightDockFraction == 0.3);
      expect(await propertiesManager.budgetRightDockFraction.load(), 0.3);

      bloc.add(const OcptBudgetRightDockTabSelectedEvent(tab: OcptBudgetRightDockTab.versions));
      await waitForState(bloc, (state) => state.rightDockTab == OcptBudgetRightDockTab.versions);
      expect(
        await propertiesManager.budgetLastRightDockTab.load(),
        OcptBudgetRightDockTab.versions,
      );
    });
  });

  group("the mode's own poste filter", () {
    test("selecting a poste filters nothing, and filtering selects nothing", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;
      final otherAccountId = loaded.accounts[1].id;

      // The two used to be one field, which is how a click in the quote came to narrow the cash
      // journal without anything saying so.
      bloc.add(OcptBudgetAccountSelectedEvent(accountId: accountId));
      final selected = await waitForState(bloc, (state) => state.selectedAccountId == accountId);
      expect(selected.filterAccountId, isNull);

      bloc.add(OcptBudgetAccountFilterSelectedEvent(accountId: otherAccountId));
      final filtered = await waitForState(bloc, (state) => state.filterAccountId == otherAccountId);
      expect(filtered.selectedAccountId, accountId);
    });

    test("a null poste clears the filter", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;

      bloc.add(OcptBudgetAccountFilterSelectedEvent(accountId: accountId));
      await waitForState(bloc, (state) => state.filterAccountId == accountId);

      bloc.add(const OcptBudgetAccountFilterSelectedEvent(accountId: null));
      final state = await waitForState(bloc, (state) => state.filterAccountId == null);

      expect(state.filterAccountId, isNull);
    });

    test("a poste naming no live poste is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;

      bloc.add(OcptBudgetAccountFilterSelectedEvent(accountId: accountId));
      await waitForState(bloc, (state) => state.filterAccountId == accountId);

      bloc.add(const OcptBudgetAccountFilterSelectedEvent(accountId: "no-such-poste"));
      await pumpEventQueue();

      expect(bloc.state.filterAccountId, accountId);
    });

    test("deleting the filtered poste clears the filter", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final accountId = loaded.accounts.first.id;

      bloc.add(OcptBudgetAccountFilterSelectedEvent(accountId: accountId));
      await waitForState(bloc, (state) => state.filterAccountId == accountId);

      expensesBloc.add(OcptBudgetAccountDeletionConfirmedEvent(accountId: accountId));
      final state = await waitForState(
        bloc,
        (state) => state.accounts.every((account) => account.id != accountId),
      );

      expect(state.filterAccountId, isNull);
    });
  });

  group("the financing plan", () {
    test("loads every live resource alongside the quote", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;

      final resourceId = await projectsManager.budgetFinancingService
          .createResource(database: project.database, label: "Regional grant")
          .maybeValueOrFail;
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      final state = await waitForState(bloc, (state) => state.resources.isNotEmpty);

      expect(state.resources, hasLength(1));
      expect(state.resources.single.label, "Regional grant");
      expect(state.resourceCount, 1);
    });
  });

  group("selecting a resource", () {
    test("highlights it, ignoring an id naming no live resource", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService
          .createResource(database: project.database, label: "Regional grant")
          .maybeValueOrFail;
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);

      bloc.add(const OcptBudgetResourceSelectedEvent(resourceId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.selectedResourceId, isNull);

      bloc.add(OcptBudgetResourceSelectedEvent(resourceId: resourceId!));
      final state = await waitForState(bloc, (state) => state.selectedResourceId != null);
      expect(state.selectedResourceId, resourceId);
    });
  });

  group("the revenue sharing", () {
    test("loads every live revenue and share alongside the quote", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;

      final revenueId = await projectsManager.budgetSharingService
          .createRevenue(
            database: project.database,
            date: DateTime(2026, 3),
            label: "Festival prize",
          )
          .maybeValueOrFail;
      final shareId = await projectsManager.budgetSharingService
          .createShare(database: project.database, label: "Production")
          .maybeValueOrFail;
      expect(revenueId, isNotNull);
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      final state = await waitForState(
        bloc,
        (state) => state.revenues.isNotEmpty && state.shares.isNotEmpty,
      );

      expect(state.revenues, hasLength(1));
      expect(state.revenues.single.label, "Festival prize");
      expect(state.revenueCount, 1);
      expect(state.shares, hasLength(1));
      expect(state.shares.single.label, "Production");
      expect(state.shareCount, 1);
    });
  });

  group("selecting a revenue", () {
    test("highlights it, ignoring an id naming no live revenue", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService
          .createRevenue(
            database: project.database,
            date: DateTime(2026, 3),
            label: "Festival prize",
          )
          .maybeValueOrFail;
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);

      bloc.add(const OcptBudgetRevenueSelectedEvent(revenueId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.selectedRevenueId, isNull);

      bloc.add(OcptBudgetRevenueSelectedEvent(revenueId: revenueId!));
      final state = await waitForState(bloc, (state) => state.selectedRevenueId != null);
      expect(state.selectedRevenueId, revenueId);
    });

    test("opens the Inspector tab, mirroring selecting a resource", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService
          .createRevenue(
            database: project.database,
            date: DateTime(2026, 3),
            label: "Festival prize",
          )
          .maybeValueOrFail;
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);

      bloc.add(OcptBudgetRevenueSelectedEvent(revenueId: revenueId!));
      final state = await waitForState(
        bloc,
        (state) => state.rightDockTab == OcptBudgetRightDockTab.inspector,
      );
      expect(state.selection, OcptBudgetRevenueSelection(revenueId));
    });
  });
}
