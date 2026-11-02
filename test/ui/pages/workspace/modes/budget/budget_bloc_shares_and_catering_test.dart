// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'budget_bloc_test_doubles.dart';

/// Run the tests of the budget bloc shares and catering.
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

  /// Builds the cash journal bloc of [modeBloc].
  OcptBudgetCashJournalBloc buildJournal(OcptBudgetBloc modeBloc) {
    final bloc = OcptBudgetCashJournalBloc(modeBloc: modeBloc, projectsManager: projectsManager);
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

  group("selecting a share", () {
    test("highlights it, ignoring an id naming no live share", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final shareId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "Production",
      );
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.isNotEmpty);

      bloc.add(const OcptBudgetShareSelectedEvent(shareId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.selectedShareId, isNull);

      bloc.add(OcptBudgetShareSelectedEvent(shareId: shareId!));
      final state = await waitForState(bloc, (state) => state.selectedShareId != null);
      expect(state.selectedShareId, shareId);
    });
  });

  group("the catering pass", () {
    test(
      "loads the schedule, the roles, the people and the prices, and computes the pass",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        await waitForState(bloc, (state) => !state.isLoading);
        final project = projectsManager.currentProject!;

        final personId = await projectsManager.peopleService.createPerson(
          database: project.database,
        );
        expect(personId, isNotNull);
        await projectsManager.peopleService.updatePerson(
          database: project.database,
          personId: personId!,
          commuteKmMilli: const drift.Value(10000),
        );

        final locationId = await projectsManager.locationsService.createLocation(
          database: project.database,
          name: "Studio A",
        );
        expect(locationId, isNotNull);

        final dayId = await projectsManager.scheduleService.createDay(
          database: project.database,
          date: DateTime(2026, 3),
        );
        expect(dayId, isNotNull);

        final scheduleSnapshot = await projectsManager.scheduleService.loadSchedule(
          database: project.database,
        );
        final slotId = scheduleSnapshot.slotsByDayId[dayId]!.single.id;
        await projectsManager.scheduleService.updateSlot(
          database: project.database,
          slotId: slotId,
          locationId: drift.Value(locationId),
        );
        await projectsManager.scheduleService.addSlotCrewMember(
          database: project.database,
          slotId: slotId,
          personId: personId,
        );

        await projectsManager.saveCurrentProjectMealPriceCents(1200);
        await projectsManager.saveCurrentProjectSnackPriceCents(400);

        // A mileage scale, there to pre-fill a defrayal somebody types — never to deduce one.
        await projectsManager.budgetFinancingService.createMileageRate(
          database: project.database,
          label: "Car",
        );

        bloc.add(const OcptBudgetProjectSettingsChangedEvent());
        // Waits for the crew count itself, not merely for a day to exist: the bloc's own initial
        // load (fired at construction, before any of the writes above) races these very writes, and
        // a state it emits mid-way through them would still make `logisticsDays` non-empty on its
        // own.
        final state = await waitForState(
          bloc,
          (state) => state.logisticsDays.isNotEmpty && state.logisticsDays.single.crewCount == 1,
        );

        expect(state.logisticsDays.single.dayId, dayId);
        expect(state.logisticsDays.single.crewCount, 1);
        expect(state.logisticsDays.single.headCount, 1);
        expect(state.logisticsDays.single.cost.isComplete, isTrue);
        expect(state.logisticsDecorNameByDayId[dayId], "Studio A");

        // The person's own commute is loaded and the mileage scales with it — both there to
        // pre-fill a defrayal somebody types — and nothing is deduced from either: a production
        // that has written no defrayal is defraying nobody.
        expect(state.allowances, isEmpty);
        expect(state.people.map((person) => person.id), contains(personId));
        expect(state.mileageRates, hasLength(1));
      },
    );
  });

  group("toggling the expenses tree's own expansion", () {
    test("expands a node it did not hold, and collapses one it did — independently of any "
        "other node", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetRowExpansionToggledEvent(nodeId: "poste-1"));
      final firstExpanded = await waitForState(
        bloc,
        (state) => state.expandedNodeIds.contains("poste-1"),
      );
      expect(firstExpanded.expandedNodeIds, {"poste-1"});

      bloc.add(const OcptBudgetRowExpansionToggledEvent(nodeId: "line-1"));
      final bothExpanded = await waitForState(
        bloc,
        (state) => state.expandedNodeIds.contains("line-1"),
      );
      expect(bothExpanded.expandedNodeIds, {"poste-1", "line-1"});

      bloc.add(const OcptBudgetRowExpansionToggledEvent(nodeId: "poste-1"));
      final onlyLineLeft = await waitForState(
        bloc,
        (state) => !state.expandedNodeIds.contains("poste-1"),
      );
      expect(onlyLineLeft.expandedNodeIds, {"line-1"});
    });

    test(
      "is not persisted across a fresh load — every bloc starts with nothing expanded",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final state = await waitForState(bloc, (state) => !state.isLoading);

        expect(state.expandedNodeIds, isEmpty);
      },
    );
  });

  group("selecting a quote line, a commitment or an entry", () {
    test("selecting a line names it in the selection and opens the Inspector", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);
      final lineId = withLine.postes.first.lines.single.id;

      // A poste selection first, so the switch away from it is what this test actually proves.
      bloc.add(OcptBudgetPosteSelectedEvent(posteId: loaded.postes.last.id));
      await waitForState(bloc, (state) => state.selectedPosteId == loaded.postes.last.id);

      bloc.add(OcptBudgetLineSelectedEvent(lineId: lineId));
      final state = await waitForState(
        bloc,
        (state) => state.selection == OcptBudgetLineSelection(lineId),
      );

      expect(state.selection, OcptBudgetLineSelection(lineId));
      expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
    });

    test("a line id naming no live line is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetLineSelectedEvent(lineId: "gone"));
      // Nothing to wait for: give the bloc a beat to (not) react, then assert it never did.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selection, isNull);
    });

    test("deleting a selected line clears the selection on the next snapshot", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);
      final lineId = withLine.postes.first.lines.single.id;
      await waitForState(bloc, (state) => state.selection == OcptBudgetLineSelection(lineId));

      expensesBloc.add(OcptBudgetLineDeletionConfirmedEvent(lineId: lineId));
      final state = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isEmpty,
      );

      expect(state.selection, isNull);
    });

    test("selecting a commitment names it in the selection and opens the Inspector", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      journalBloc.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          fields: OcptBudgetCommitmentFormFields(
            dueDate: null,
            label: "Insurance",
            posteId: posteId,
            amountCents: 12000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      final withCommitment = await waitForState(bloc, (state) => state.commitments.isNotEmpty);
      final commitmentId = withCommitment.commitments.single.id;

      bloc.add(OcptBudgetCommitmentSelectedEvent(commitmentId: commitmentId));
      final state = await waitForState(
        bloc,
        (state) => state.selection == OcptBudgetCommitmentSelection(commitmentId),
      );

      expect(state.selection, OcptBudgetCommitmentSelection(commitmentId));
      expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
    });

    test("a commitment id naming no live commitment is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetCommitmentSelectedEvent(commitmentId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selection, isNull);
    });

    test("selecting an entry names it in the selection and opens the Inspector", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Camera rental",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final withEntry = await waitForState(bloc, (state) => state.entries.isNotEmpty);
      final entryId = withEntry.entries.single.id;

      bloc.add(OcptBudgetEntrySelectedEvent(entryId: entryId));
      final state = await waitForState(
        bloc,
        (state) => state.selection == OcptBudgetEntrySelection(entryId),
      );

      expect(state.selection, OcptBudgetEntrySelection(entryId));
      expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
    });

    test("an entry id naming no live entry is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetEntrySelectedEvent(entryId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selection, isNull);
    });

    test(
      "selecting a receipt names the same entry in the selection and opens the Inspector",
      () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final journalBloc = buildJournal(bloc);
        final loaded = await waitForState(bloc, (state) => !state.isLoading);
        final posteId = loaded.postes.first.id;

        journalBloc.add(
          OcptBudgetEntryCreationConfirmedEvent(
            fields: OcptBudgetEntryFormFields(
              date: DateTime(2026, 3),
              label: "Camera rental",
              posteId: posteId,
              resourceId: null,
              revenueId: null,
              shareId: null,
              isDebit: true,
              amountCents: 5000,
              isTaxInclusive: true,
              vatRateBasisPoints: null,
              voucherNumber: null,
              pickedReceiptPath: null,
              isReceiptDetached: false,
            ),
          ),
        );
        final withEntry = await waitForState(bloc, (state) => state.entries.isNotEmpty);
        final entryId = withEntry.entries.single.id;

        bloc.add(OcptBudgetReceiptSelectedEvent(receiptId: entryId));
        final state = await waitForState(
          bloc,
          (state) => state.selection == OcptBudgetReceiptSelection(entryId),
        );

        expect(state.selection, OcptBudgetReceiptSelection(entryId));
        expect(state.rightDockTab, OcptBudgetRightDockTab.inspector);
      },
    );

    test("a receipt id naming no live entry is ignored", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetReceiptSelectedEvent(receiptId: "gone"));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selection, isNull);
    });

    test("a selected receipt is dropped once its own entry is deleted", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Camera rental",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final withEntry = await waitForState(bloc, (state) => state.entries.isNotEmpty);
      final entryId = withEntry.entries.single.id;

      bloc.add(OcptBudgetReceiptSelectedEvent(receiptId: entryId));
      await waitForState(bloc, (state) => state.selection == OcptBudgetReceiptSelection(entryId));

      journalBloc.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId));
      final state = await waitForState(bloc, (state) => state.entries.isEmpty);

      expect(state.selection, isNull);
    });
  });
}
