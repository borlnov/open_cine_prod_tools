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
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
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
import 'budget_expenses_bloc_test_doubles.dart';

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

  /// Builds the mode bloc wired to the test project, seeded with [seed] (defaulting to [smallSeed]).
  OcptBudgetBloc buildBloc({List<OcptBudgetPosteSeed> seed = smallSeed}) => OcptBudgetBloc(
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
        (state) => state.postes.length == smallSeed.length + 1,
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
      final loader = _FlakySnapshotLoader(projectsManager: projectsManager, seed: smallSeed);
      final bloc = OcptBudgetBloc(
        seed: smallSeed,
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: RecordingRouterManager(),
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
        seed: smallSeed,
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
        seed: smallSeed,
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
