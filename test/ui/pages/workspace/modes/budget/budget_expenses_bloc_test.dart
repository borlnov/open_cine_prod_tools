// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_snapshot_loader.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager that only records the call: these bloc tests never navigate for real.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A quote service whose [updatePoste] can be made to fail, and that counts how many times it was
/// asked to write.
class _FlakyQuoteService extends OcptBudgetQuoteService {
  /// Whether [updatePoste] throws.
  bool fails = false;

  /// How many times [updatePoste] was called.
  int updatePosteCalls = 0;

  /// When set, [updatePoste] waits for it before writing, so a test can type while a write is in
  /// flight.
  Completer<void>? gate;

  /// Class constructor
  _FlakyQuoteService() : super(logger: const SilentLogger(), deviceId: () async => "test-device");

  @override
  Future<void> updatePoste({
    required OcptProjectDatabase database,
    required String posteId,
    drift.Value<String> code = const drift.Value.absent(),
    drift.Value<String> label = const drift.Value.absent(),
    drift.Value<String?> simpleLabel = const drift.Value.absent(),
    drift.Value<int?> estimateToCompleteCents = const drift.Value.absent(),
  }) async {
    updatePosteCalls++;
    await gate?.future;
    if (fails) {
      throw StateError("poste update intentionally failed for the test");
    }

    return super.updatePoste(
      database: database,
      posteId: posteId,
      code: code,
      label: label,
      simpleLabel: simpleLabel,
      estimateToCompleteCents: estimateToCompleteCents,
    );
  }
}

/// A snapshot loader whose read can be made to fail.
class _FlakySnapshotLoader extends OcptBudgetSnapshotLoader {
  /// Whether [load] throws.
  bool fails = false;

  /// Class constructor
  _FlakySnapshotLoader({required super.projectsManager, required super.seed});

  @override
  Future<OcptBudgetRead> load(OcptOpenProjectModel project) async {
    if (fails) {
      throw StateError("budget read intentionally failed for the test");
    }

    return super.load(project);
  }
}

/// A minimal, three-entry seed used by every test that isn't about the seeding path itself, so
/// their own assertions aren't drowned in ten postes.
const _smallSeed = [
  OcptBudgetPosteSeed(id: "seed-1", code: "1", label: "Poste one", simpleLabel: "P1"),
  OcptBudgetPosteSeed(id: "seed-2", code: "2", label: "Poste two", simpleLabel: "P2"),
  OcptBudgetPosteSeed(id: "seed-3", code: "3", label: "Poste three", simpleLabel: "P3"),
];

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
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_expenses_bloc_test_test_");
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

  /// Builds the mode bloc wired to the test project, seeded with [seed] (defaulting to [_smallSeed]).
  OcptBudgetBloc buildBloc({List<OcptBudgetPosteSeed> seed = _smallSeed}) => OcptBudgetBloc(
    seed: seed,
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
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

  group("creating a poste", () {
    test("appends an empty poste and selects it, opening the Inspector tab", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expensesBloc.add(const OcptBudgetPosteCreatedEvent());
      final state = await waitForState(bloc, (state) => state.selectedPosteId != null);

      expect(state.postes.last.label, "");
      expect(state.selectedPosteId, state.postes.last.id);
      expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
    });
  });

  group("reordering a poste", () {
    test("moves it to the new position", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final firstId = loaded.postes.first.id;

      expensesBloc.add(OcptBudgetPosteReorderedEvent(posteId: firstId, newPosition: 2));
      final state = await waitForState(bloc, (state) => state.postes.last.id == firstId);

      expect(state.postes.last.id, firstId);
    });
  });

  group("deleting a poste", () {
    test("tombstones it, its own lines, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId));
      await waitForState(bloc, (state) => state.selectedPosteId == posteId);

      expensesBloc.add(OcptBudgetPosteDeletionConfirmedEvent(posteId: posteId));
      final state = await waitForState(bloc, (state) => state.postes.length < _smallSeed.length);

      expect(state.postes.any((poste) => poste.id == posteId), isFalse);
      expect(state.selectedPosteId, isNull);
    });
  });

  group("creating and deleting a quote line", () {
    test("creates an empty line inside the poste and selects it, then deletes it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final loadedWithLine = await waitForState(
        bloc,
        (state) => state.postes.first.lines.isNotEmpty,
      );
      final lineId = loadedWithLine.postes
          .firstWhere((poste) => poste.id == posteId)
          .lines
          .single
          .id;
      final withLine = await waitForState(
        bloc,
        (state) => state.selection == OcptBudgetLineSelection(lineId),
      );
      expect(withLine.selection, OcptBudgetLineSelection(lineId));

      expensesBloc.add(OcptBudgetLineDeletionConfirmedEvent(lineId: lineId));
      final withoutLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isEmpty,
      );

      expect(withoutLine.postes.firstWhere((poste) => poste.id == posteId).lines, isEmpty);
    });
  });

  group("typing into a field", () {
    test("debounces the write: a unit price typed as 12.50 reads back as 1250 cents", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: lineId,
          field: OcptBudgetField.lineUnitAmount,
          rawValue: "12.50",
        ),
      );

      // Right after the keystroke, the field reads the pending edit back — the debounce hasn't
      // flushed yet.
      final pending = await waitForState(
        expensesBloc,
        (state) => state.pendingFieldEdits[(lineId, OcptBudgetField.lineUnitAmount)] == "12.50",
      );
      expect(pending.fieldValueOf(lineId, OcptBudgetField.lineUnitAmount, ""), "12.50");

      final flushed = await waitForState(
        bloc,
        (state) =>
            state.postes
                .firstWhere((poste) => poste.id == posteId)
                .lines
                .firstWhere((line) => line.id == lineId)
                .unitPrice
                .amountCents ==
            1250,
      );

      final line = flushed.postes.firstWhere((poste) => poste.id == posteId).lines.single;
      expect(line.unitPrice.amountCents, 1250);
      final forgotten = await waitForState(
        expensesBloc,
        (state) => state.pendingFieldEdits.isEmpty,
      );
      expect(forgotten.pendingFieldEdits, isEmpty);
    });

    test("switching view writes what is still in the debounce, so the next view reads "
        "it", () async {
      // The defect this pins: an amount typed in the cost-tracking table and followed straight by a
      // click on another chip was still sitting in the debounce, so the view switched to drew the
      // figures from before it and only corrected itself two seconds later.
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: lineId,
          field: OcptBudgetField.lineUnitAmount,
          rawValue: "12.50",
        ),
      );
      await waitForState(
        expensesBloc,
        (state) => state.pendingFieldEdits[(lineId, OcptBudgetField.lineUnitAmount)] == "12.50",
      );

      // Switching view, well inside the debounce window, must write it rather than wait it out.
      bloc.add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.resources));

      // The flush reloads the snapshot first and forgets the edits after, so the state worth waiting
      // for is the one that carries the written figure, not merely an empty pending map.
      await waitForState(
        bloc,
        (state) =>
            state.view == OcptBudgetView.resources &&
            state.postes
                    .firstWhere((poste) => poste.id == posteId)
                    .lines
                    .single
                    .unitPrice
                    .amountCents ==
                1250,
      );

      final forgotten = await waitForState(
        expensesBloc,
        (state) => state.pendingFieldEdits.isEmpty,
      );
      expect(forgotten.pendingFieldEdits, isEmpty);
    });

    test(
      "skips the write when the typed unit price does not parse, leaving the stored value alone",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final expensesBloc = buildExpenses(bloc);
        final loaded = await waitForState(bloc, (state) => !state.isLoading);
        final posteId = loaded.postes.first.id;

        expensesBloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
        final withLine = await waitForState(
          bloc,
          (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
        );
        final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;
        final storedBefore = withLine.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .single
            .unitPrice
            .amountCents;

        expensesBloc.add(
          OcptBudgetFieldChangedEvent(
            targetId: lineId,
            field: OcptBudgetField.lineUnitAmount,
            rawValue: "not a number",
          ),
        );
        await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isEmpty);

        final line = bloc.state.postes.firstWhere((poste) => poste.id == posteId).lines.single;
        expect(line.unitPrice.amountCents, storedBefore);
      },
    );
  });

  group("a line's tax basis", () {
    test("is written immediately, never through the field-edit debounce", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc, fieldEditDebounce: const Duration(seconds: 30));
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      expensesBloc.add(
        OcptBudgetLineTaxInclusiveChangedEvent(lineId: lineId, isTaxInclusive: false),
      );
      final state = await waitForState(
        bloc,
        (state) => !state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .single
            .unitPrice
            .isTaxInclusive,
      );

      expect(
        state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .single
            .unitPrice
            .isTaxInclusive,
        isFalse,
      );
    });
  });

  group("a line's VAT rate override", () {
    test("the Inherit action clears it back to null immediately", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc, fieldEditDebounce: const Duration(seconds: 30));
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      expensesBloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      await projectsManager.budgetQuoteService.updateLine(
        database: project.database,
        lineId: lineId,
        vatRateBasisPoints: const drift.Value(550),
      );

      // The write above went straight through the service, bypassing the bloc, so its own cached
      // state hasn't caught up yet — its line still (stale) reads a null override, exactly the
      // value the Inherit action is about to produce for real. Reloading first, and waiting for
      // the override to actually show up as 550, is what keeps the assertion below honest: without
      // it, `waitForState` would resolve against this stale cached `null` the instant the Inherit
      // event is dispatched, never actually waiting for its own reload to land.
      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(
        bloc,
        (state) =>
            state.postes
                .firstWhere((poste) => poste.id == posteId)
                .lines
                .single
                .unitPrice
                .vatRateBasisPoints ==
            550,
      );

      expensesBloc.add(OcptBudgetLineVatRateInheritedRequestedEvent(lineId: lineId));
      final state = await waitForState(
        bloc,
        (state) =>
            state.postes
                .firstWhere((poste) => poste.id == posteId)
                .lines
                .single
                .unitPrice
                .vatRateBasisPoints ==
            null,
      );

      expect(
        state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .single
            .unitPrice
            .vatRateBasisPoints,
        isNull,
      );
    });
  });

  group("a poste's estimate to complete", () {
    test("a typed figure debounces the write: 12.50 reads back as 1250 cents", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: posteId,
          field: OcptBudgetField.posteEstimateToComplete,
          rawValue: "12.50",
        ),
      );

      // Right after the keystroke, the field reads the pending edit back — the debounce hasn't
      // flushed yet.
      final pending = await waitForState(
        expensesBloc,
        (state) =>
            state.pendingFieldEdits[(posteId, OcptBudgetField.posteEstimateToComplete)] == "12.50",
      );
      expect(pending.fieldValueOf(posteId, OcptBudgetField.posteEstimateToComplete, ""), "12.50");

      final flushed = await waitForState(
        bloc,
        (state) =>
            state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents == 1250,
      );

      expect(
        flushed.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents,
        1250,
      );
      final forgotten = await waitForState(
        expensesBloc,
        (state) => state.pendingFieldEdits.isEmpty,
      );
      expect(forgotten.pendingFieldEdits, isEmpty);
    });

    test(
      "skips the write when the typed figure does not parse, leaving the stored value alone",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final expensesBloc = buildExpenses(bloc);
        final loaded = await waitForState(bloc, (state) => !state.isLoading);
        final posteId = loaded.postes.first.id;
        final storedBefore = loaded.postes
            .firstWhere((poste) => poste.id == posteId)
            .estimateToCompleteCents;

        expensesBloc.add(
          OcptBudgetFieldChangedEvent(
            targetId: posteId,
            field: OcptBudgetField.posteEstimateToComplete,
            rawValue: "not a number",
          ),
        );
        await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isEmpty);

        expect(
          bloc.state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents,
          storedBefore,
        );
      },
    );

    test("skips the write on an empty submission too, never writing zero", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final storedBefore = loaded.postes
          .firstWhere((poste) => poste.id == posteId)
          .estimateToCompleteCents;

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: posteId,
          field: OcptBudgetField.posteEstimateToComplete,
          rawValue: "",
        ),
      );
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isEmpty);

      expect(
        bloc.state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents,
        storedBefore,
      );
    });

    test("the Derive again action clears it back to null immediately", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc, fieldEditDebounce: const Duration(seconds: 30));
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      await projectsManager.budgetQuoteService.updatePoste(
        database: project.database,
        posteId: posteId,
        estimateToCompleteCents: const drift.Value(5000),
      );

      // The write above went straight through the service, bypassing the bloc, so its own cached
      // state hasn't caught up yet — see the mirrored VAT-rate test above for why reloading first,
      // and waiting for the typed figure to actually show up, is what keeps the assertion below
      // honest.
      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(
        bloc,
        (state) =>
            state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents == 5000,
      );

      expensesBloc.add(OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent(posteId: posteId));
      final state = await waitForState(
        bloc,
        (state) =>
            state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents == null,
      );

      expect(
        state.postes.firstWhere((poste) => poste.id == posteId).estimateToCompleteCents,
        isNull,
      );
    });
  });

  group("paying a quote line directly", () {
    test("mints the commitment behind the payment and the payment names it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      // A line quoted at 10.00 €, tax-inclusive.
      expensesBloc.add(
        OcptBudgetLineCreatedEvent(
          posteId: posteId,
          fields: const OcptBudgetLineFormFields(
            label: "Camera",
            quantityMilli: 1000,
            unit: "u",
            unitAmountCents: 1000,
          ),
        ),
      );
      final withLine = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);
      final lineId = withLine.postes.first.lines.single.id;

      expensesBloc.add(
        OcptBudgetLinePaidDirectlyEvent(
          lineId: lineId,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 6),
            label: "Camera",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 1000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.commitments.isNotEmpty && state.entries.isNotEmpty,
      );

      // The commitment was minted from the line, naming it, at its full quoted total.
      final commitment = state.commitments.single;
      expect(commitment.lineId, lineId);
      expect(commitment.amount.amountCents, 1000);
      // The payment names that very commitment, so settlement reads back off the link.
      expect(state.entries.single.commitmentId, commitment.id);
    });

    test("a partial payment leaves the commitment standing at its full amount", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(
        OcptBudgetLineCreatedEvent(
          posteId: posteId,
          fields: const OcptBudgetLineFormFields(
            label: "Camera",
            quantityMilli: 1000,
            unit: "u",
            unitAmountCents: 1000,
          ),
        ),
      );
      final withLine = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);
      final lineId = withLine.postes.first.lines.single.id;

      // Pay only 4.00 € of the 10.00 € quoted.
      expensesBloc.add(
        OcptBudgetLinePaidDirectlyEvent(
          lineId: lineId,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 6),
            label: "Camera deposit",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 400,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.commitments.isNotEmpty && state.entries.isNotEmpty,
      );

      // The commitment is the full quoted total; only 400 has been paid against it.
      expect(state.commitments.single.amount.amountCents, 1000);
      expect(state.entries.single.debitCents, 400);
      expect(state.entries.single.commitmentId, state.commitments.single.id);
    });
  });

  group("the breakdown link", () {
    test(
      "loads the elements catalogue and derives how many are priced and how many are not",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final expensesBloc = buildExpenses(bloc);
        final project = projectsManager.currentProject!;

        final pricedElementId = await projectsManager.elementsService.createElement(
          database: project.database,
          name: "Camera body",
          category: OcptElementCategory.camera,
          sourceKind: OcptElementSourceKind.owned,
        );
        expect(pricedElementId, isNotNull);
        final unpricedElementId = await projectsManager.elementsService.createElement(
          database: project.database,
          name: "Dolly",
          category: OcptElementCategory.specialEquipment,
          sourceKind: OcptElementSourceKind.toBuy,
        );
        expect(unpricedElementId, isNotNull);

        final loaded = await waitForState(bloc, (state) => state.elements.length == 2);
        final posteId = loaded.postes.first.id;

        expensesBloc.add(
          OcptBudgetLineCreatedFromElementEvent(posteId: posteId, elementId: pricedElementId!),
        );

        final state = await waitForState(bloc, (state) => state.elementLinkCounts.pricedCount == 1);

        expect(state.elementLinkCounts.unpricedCount, 1);
        expect(state.unpricedElements.map((element) => element.id), [unpricedElementId]);
      },
    );

    test(
      "a fresh line seeds its label from the element, never a price even off a known cost",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final expensesBloc = buildExpenses(bloc);
        final project = projectsManager.currentProject!;

        final elementId = await projectsManager.elementsService.createElement(
          database: project.database,
          name: "Camera body",
          category: OcptElementCategory.camera,
          sourceKind: OcptElementSourceKind.owned,
        );
        expect(elementId, isNotNull);
        await projectsManager.elementsService.updateElement(
          database: project.database,
          elementId: elementId!,
          cost: const drift.Value(5000),
        );

        final loaded = await waitForState(bloc, (state) => state.elements.length == 1);
        final posteId = loaded.postes.first.id;

        expensesBloc.add(
          OcptBudgetLineCreatedFromElementEvent(posteId: posteId, elementId: elementId),
        );

        final state = await waitForState(
          bloc,
          (state) =>
              state.postes.any((poste) => poste.lines.any((line) => line.elementId == elementId)),
        );
        final line = state.postes
            .expand((poste) => poste.lines)
            .firstWhere((line) => line.elementId == elementId);

        expect(line.label, "Camera body");
        expect(line.unitPrice.amountCents, 0);
      },
    );

    test(
      "event.quantityMilli seeds the fresh line's own quantity, absent leaving the default",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final expensesBloc = buildExpenses(bloc);
        final project = projectsManager.currentProject!;

        final elementId = await projectsManager.elementsService.createElement(
          database: project.database,
          name: "Rostrum",
          category: OcptElementCategory.specialEquipment,
          sourceKind: OcptElementSourceKind.toBuy,
        );
        expect(elementId, isNotNull);

        final loaded = await waitForState(bloc, (state) => state.elements.length == 1);
        final posteId = loaded.postes.first.id;

        expensesBloc.add(
          OcptBudgetLineCreatedFromElementEvent(
            posteId: posteId,
            elementId: elementId!,
            quantityMilli: 3000,
          ),
        );

        final state = await waitForState(
          bloc,
          (state) =>
              state.postes.any((poste) => poste.lines.any((line) => line.elementId == elementId)),
        );
        final line = state.postes
            .expand((poste) => poste.lines)
            .firstWhere((line) => line.elementId == elementId);

        expect(line.quantityMilli, 3000);
      },
    );
  });

  group("the events of the expenses bloc", () {
    /// The name of each event of the expenses hierarchy: the switch names every one, so an event
    /// added to the hierarchy does not compile until this list, and the test below, know it.
    String nameOf(OcptBudgetExpensesEvent event) => switch (event) {
      OcptBudgetPosteCreatedEvent() => "poste created",
      OcptBudgetPosteReorderedEvent() => "poste reordered",
      OcptBudgetPosteDeletionConfirmedEvent() => "poste deleted",
      OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent() => "estimate derived",
      OcptBudgetLineCreatedEvent() => "line created",
      OcptBudgetLineCreatedFromElementEvent() => "line from element",
      OcptBudgetLineDeletionConfirmedEvent() => "line deleted",
      OcptBudgetLineTaxInclusiveChangedEvent() => "tax basis",
      OcptBudgetLineVatRateInheritedRequestedEvent() => "vat inherited",
      OcptBudgetLinePaidDirectlyEvent() => "paid directly",
      OcptBudgetFieldChangedEvent() => "field changed",
      OcptBudgetFieldEditFlushRequestedEvent() => "field flush",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc, fieldEditDebounce: const Duration(days: 1));
      final project = projectsManager.currentProject!;
      final elementId = await projectsManager.elementsService.createElement(
        database: project.database,
        name: "Camera body",
        category: OcptElementCategory.camera,
        sourceKind: OcptElementSourceKind.owned,
      );
      final loaded = await waitForState(bloc, (state) => state.elements.isNotEmpty);
      final posteId = loaded.postes.first.id;
      final otherPosteId = loaded.postes.last.id;

      final handled = <String>[];
      Future<void> proves(
        OcptBudgetExpensesEvent event,
        bool Function(OcptBudgetState) effect,
      ) async {
        expensesBloc.add(event);
        await waitForState(bloc, effect);
        handled.add(nameOf(event));
      }

      // An event nobody handles is ignored silently, so each is proven by its effect.
      await proves(
        const OcptBudgetPosteCreatedEvent(),
        (state) => state.postes.length == _smallSeed.length + 1,
      );
      await proves(
        OcptBudgetPosteReorderedEvent(posteId: posteId, newPosition: 2),
        (state) => state.postes[2].id == posteId,
      );
      await proves(
        OcptBudgetLineCreatedEvent(posteId: posteId),
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.length == 1,
      );
      final lineId = bloc.state.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;
      await proves(
        OcptBudgetLineCreatedFromElementEvent(posteId: posteId, elementId: elementId!),
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.length == 2,
      );
      await proves(
        OcptBudgetLineTaxInclusiveChangedEvent(lineId: lineId, isTaxInclusive: false),
        (state) => !state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .firstWhere((line) => line.id == lineId)
            .unitPrice
            .isTaxInclusive,
      );
      await projectsManager.budgetQuoteService.updateLine(
        database: project.database,
        lineId: lineId,
        vatRateBasisPoints: const drift.Value(550),
      );
      await bloc.reload({OcptBudgetReloadScope.snapshot});
      await proves(
        OcptBudgetLineVatRateInheritedRequestedEvent(lineId: lineId),
        (state) =>
            state.postes
                .firstWhere((poste) => poste.id == posteId)
                .lines
                .firstWhere((line) => line.id == lineId)
                .unitPrice
                .vatRateBasisPoints ==
            null,
      );

      // Typing records a pending edit, and the flush request writes it.
      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: otherPosteId,
          field: OcptBudgetField.posteLabel,
          rawValue: "Typed",
        ),
      );
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isNotEmpty);
      handled.add(
        nameOf(
          const OcptBudgetFieldChangedEvent(
            targetId: "",
            field: OcptBudgetField.posteLabel,
            rawValue: "",
          ),
        ),
      );
      await proves(
        const OcptBudgetFieldEditFlushRequestedEvent(),
        (state) => state.postes.firstWhere((poste) => poste.id == otherPosteId).label == "Typed",
      );
      await proves(
        OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent(posteId: otherPosteId),
        (state) =>
            state.postes.firstWhere((poste) => poste.id == otherPosteId).estimateToCompleteCents ==
            null,
      );
      await proves(
        OcptBudgetLinePaidDirectlyEvent(
          lineId: lineId,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 6),
            label: "Camera",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 100,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
        (state) => state.entries.isNotEmpty,
      );
      await proves(
        OcptBudgetLineDeletionConfirmedEvent(lineId: lineId),
        (state) => !state.postes.expand((poste) => poste.lines).any((line) => line.id == lineId),
      );
      await proves(
        OcptBudgetPosteDeletionConfirmedEvent(posteId: otherPosteId),
        (state) => !state.postes.any((poste) => poste.id == otherPosteId),
      );

      expect(handled.toSet(), hasLength(12), reason: "one proof per event of the hierarchy");
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      buildExpenses(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);
    });
  });

  group("a typed edit whose re-read fails after it was written", () {
    test("stops what the flush was for, and is still pending", () async {
      final loader = _FlakySnapshotLoader(projectsManager: projectsManager, seed: _smallSeed);
      final bloc = OcptBudgetBloc(
        seed: _smallSeed,
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _RecordingRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
        snapshotLoader: loader,
      );
      addTearDown(bloc.close);
      final expensesBloc = OcptBudgetExpensesBloc(
        modeBloc: bloc,
        projectsManager: projectsManager,
        fieldEditDebounce: const Duration(days: 1),
      );
      addTearDown(expensesBloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: posteId,
          field: OcptBudgetField.posteLabel,
          rawValue: "Typed",
        ),
      );
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      loader.fails = true;
      expect(await bloc.flushAllPendingWrites(), isFalse);

      // The write landed, but the mode could not read it back: nothing may go on as if it had.
      final stored = await projectsManager.budgetQuoteService.loadPostes(
        database: projectsManager.currentProject!.database,
        seed: _smallSeed,
      );
      expect(stored.firstWhere((poste) => poste.id == posteId).label, "Typed");
      expect(expensesBloc.state.pendingFieldEdits, isNotEmpty);

      loader.fails = false;
      expect(await bloc.flushAllPendingWrites(), isTrue);
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isEmpty);
      expect(bloc.state.postes.firstWhere((poste) => poste.id == posteId).label, "Typed");
    });
  });

  group("a typed edit that cannot be written", () {
    /// Builds the expenses bloc of [modeBloc] over [quote], whose debounce never fires by itself.
    OcptBudgetExpensesBloc buildOver(OcptBudgetBloc modeBloc, _FlakyQuoteService quote) {
      final bloc = OcptBudgetExpensesBloc(
        modeBloc: modeBloc,
        projectsManager: projectsManager,
        budgetQuoteService: quote,
        fieldEditDebounce: const Duration(days: 1),
      );
      addTearDown(bloc.close);
      return bloc;
    }

    test("stays pending, stops what the flush was for, and is written by the next flush", () async {
      final quote = _FlakyQuoteService();
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildOver(bloc, quote);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final storedLabel = loaded.postes.first.label;

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: posteId,
          field: OcptBudgetField.posteLabel,
          rawValue: "Typed",
        ),
      );
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      quote.fails = true;
      expect(await bloc.flushAllPendingWrites(), isFalse);

      // The edit is still on screen and the database still holds the old value.
      expect(expensesBloc.state.pendingFieldEdits, isNotEmpty);
      final stored = await projectsManager.budgetQuoteService.loadPostes(
        database: projectsManager.currentProject!.database,
        seed: _smallSeed,
      );
      expect(stored.firstWhere((poste) => poste.id == posteId).label, storedLabel);

      // A selection flushes first, so it does not happen either.
      bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.selection, isNull);

      // The next flush writes everything.
      quote.fails = false;
      expect(await bloc.flushAllPendingWrites(), isTrue);
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isEmpty);
      expect(bloc.state.postes.firstWhere((poste) => poste.id == posteId).label, "Typed");
    });

    test("is written once when the widget leaves and the bloc closes after it", () async {
      final quote = _FlakyQuoteService();
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildOver(bloc, quote);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: loaded.postes.first.id,
          field: OcptBudgetField.posteLabel,
          rawValue: "Typed",
        ),
      );
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      // What the widget leaving the tree does: the flush starts, and the bloc closes in the same
      // frame, before the write is done.
      final flushing = bloc.flushPendingFieldEdits();
      await expensesBloc.close();
      await flushing;

      expect(quote.updatePosteCalls, 1);
    });
  });

  group("the edits typed into the expenses view", () {
    test("are dropped, unwritten, when the mode reads everything again", () async {
      final quote = _FlakyQuoteService();
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = OcptBudgetExpensesBloc(
        modeBloc: bloc,
        projectsManager: projectsManager,
        budgetQuoteService: quote,
        fieldEditDebounce: const Duration(days: 1),
      );
      addTearDown(expensesBloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: loaded.postes.first.id,
          field: OcptBudgetField.posteLabel,
          rawValue: "Typed",
        ),
      );
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      // What a version preview or a restore does once it has swapped the database.
      bloc.add(const OcptBudgetLoadRequestedEvent());
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isEmpty);

      expect(quote.updatePosteCalls, 0);
    });

    test("typed while a write is in flight are kept, only what was written is forgotten", () async {
      final quote = _FlakyQuoteService()..gate = Completer<void>();
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = OcptBudgetExpensesBloc(
        modeBloc: bloc,
        projectsManager: projectsManager,
        budgetQuoteService: quote,
        fieldEditDebounce: const Duration(days: 1),
      );
      addTearDown(expensesBloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: posteId,
          field: OcptBudgetField.posteLabel,
          rawValue: "First",
        ),
      );
      await waitForState(expensesBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      final flush = bloc.flushAllPendingWrites();
      while (quote.updatePosteCalls == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expensesBloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: posteId,
          field: OcptBudgetField.posteLabel,
          rawValue: "Second",
        ),
      );
      await waitForState(
        expensesBloc,
        (state) => state.pendingFieldEdits.values.contains("Second"),
      );
      quote.gate!.complete();
      expect(await flush, isTrue);

      expect(expensesBloc.state.pendingFieldEdits.values, ["Second"]);
    });
  });
}
