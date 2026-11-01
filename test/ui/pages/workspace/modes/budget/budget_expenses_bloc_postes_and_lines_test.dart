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
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'budget_expenses_bloc_test_doubles.dart';

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
      final state = await waitForState(bloc, (state) => state.postes.length < smallSeed.length);

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
}
