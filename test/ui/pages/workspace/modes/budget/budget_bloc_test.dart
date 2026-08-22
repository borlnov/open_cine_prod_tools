// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_budget_cnc_postes.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager that only records the call: these bloc tests never navigate for real.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// The seed the ten real CNC postes make, resolved without a `Tr` (the label text itself is never
/// read by these tests, only the ids and the count): the seeding path itself is what is under
/// test, so it is exercised against the very ids `OcptBudgetQuoteService` will actually seed in
/// the app.
final _realCncSeed = [
  for (final poste in ocptBudgetCncPostes)
    OcptBudgetPosteSeed(id: poste.id, code: poste.code, label: poste.code, simpleLabel: null),
];

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

  /// Builds a bloc wired to the test project, seeded with [seed] (defaulting to [_smallSeed]) and
  /// a fast field-edit debounce so tests don't have to wait out the real 2 s one.
  OcptBudgetBloc buildBloc({
    List<OcptBudgetPosteSeed> seed = _smallSeed,
    Duration fieldEditDebounce = const Duration(milliseconds: 10),
  }) => OcptBudgetBloc(
    seed: seed,
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    fieldEditDebounce: fieldEditDebounce,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptBudgetState> waitForState(
    OcptBudgetBloc bloc,
    bool Function(OcptBudgetState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group("loading the quote", () {
    test("seeds the ten CNC postes on the first read of an empty project", () async {
      final bloc = buildBloc(seed: _realCncSeed);
      addTearDown(bloc.close);

      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.postes, hasLength(10));
      expect(state.postes.map((poste) => poste.id).toSet(), ocptBudgetCncPostes.map((c) => c.id).toSet());
    });

    test("reads the project's own currency and default VAT rate", () async {
      final project = projectsManager.currentProject!;
      await projectsManager.saveCurrentProjectCurrencyCode("USD");
      await projectsManager.saveCurrentProjectDefaultVatRateBasisPoints(2000);

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
      final first = await projectsManager.budgetQuoteService.loadPostes(
        database: project.database,
        seed: _smallSeed,
      );
      await projectsManager.budgetQuoteService.deletePoste(
        database: project.database,
        posteId: first.first.id,
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.postes, hasLength(_smallSeed.length - 1));
    });
  });

  group("creating a poste", () {
    test("appends an empty poste and selects it, opening the Inspector tab", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBudgetPosteCreatedEvent());
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
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final firstId = loaded.postes.first.id;

      bloc.add(OcptBudgetPosteReorderedEvent(posteId: firstId, newPosition: 2));
      final state = await waitForState(bloc, (state) => state.postes.last.id == firstId);

      expect(state.postes.last.id, firstId);
    });
  });

  group("deleting a poste", () {
    test("tombstones it, its own lines, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId));
      await waitForState(bloc, (state) => state.selectedPosteId == posteId);

      bloc.add(OcptBudgetPosteDeletionConfirmedEvent(posteId: posteId));
      final state = await waitForState(bloc, (state) => state.postes.length < _smallSeed.length);

      expect(state.postes.any((poste) => poste.id == posteId), isFalse);
      expect(state.selectedPosteId, isNull);
    });
  });

  group("creating and deleting a quote line", () {
    test("creates an empty line inside the poste and expands it, then deletes it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(bloc, (state) => state.expandedLineId != null);
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;
      expect(withLine.expandedLineId, lineId);

      bloc.add(OcptBudgetLineDeletionConfirmedEvent(lineId: lineId));
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
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      bloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: lineId,
          field: OcptBudgetField.lineUnitAmount,
          rawValue: "12.50",
        ),
      );

      // Right after the keystroke, the field reads the pending edit back — the debounce hasn't
      // flushed yet.
      final pending = await waitForState(
        bloc,
        (state) => state.pendingFieldEdits[(lineId, OcptBudgetField.lineUnitAmount)] == "12.50",
      );
      expect(pending.fieldValueOf(lineId, OcptBudgetField.lineUnitAmount, ""), "12.50");

      final flushed = await waitForState(
        bloc,
        (state) => state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .firstWhere((line) => line.id == lineId)
            .unitPrice
            .amountCents ==
            1250,
      );

      final line = flushed.postes.firstWhere((poste) => poste.id == posteId).lines.single;
      expect(line.unitPrice.amountCents, 1250);
      expect(flushed.pendingFieldEdits, isEmpty);
    });

    test("skips the write when the typed unit price does not parse, leaving the stored value alone", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
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

      bloc.add(
        OcptBudgetFieldChangedEvent(
          targetId: lineId,
          field: OcptBudgetField.lineUnitAmount,
          rawValue: "not a number",
        ),
      );
      final flushed = await waitForState(bloc, (state) => state.pendingFieldEdits.isEmpty);

      final line = flushed.postes.firstWhere((poste) => poste.id == posteId).lines.single;
      expect(line.unitPrice.amountCents, storedBefore);
    });
  });

  group("a line's tax basis", () {
    test("is written immediately, never through the field-edit debounce", () async {
      final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 30));
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(
        bloc,
        (state) => state.postes.firstWhere((poste) => poste.id == posteId).lines.isNotEmpty,
      );
      final lineId = withLine.postes.firstWhere((poste) => poste.id == posteId).lines.single.id;

      bloc.add(OcptBudgetLineTaxInclusiveChangedEvent(lineId: lineId, isTaxInclusive: false));
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
        state.postes.firstWhere((poste) => poste.id == posteId).lines.single.unitPrice.isTaxInclusive,
        isFalse,
      );
    });
  });

  group("a line's VAT rate override", () {
    test("the Inherit action clears it back to null immediately", () async {
      final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 30));
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
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
        (state) => state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .single
            .unitPrice
            .vatRateBasisPoints ==
            550,
      );

      bloc.add(OcptBudgetLineVatRateInheritedRequestedEvent(lineId: lineId));
      final state = await waitForState(
        bloc,
        (state) => state.postes
            .firstWhere((poste) => poste.id == posteId)
            .lines
            .single
            .unitPrice
            .vatRateBasisPoints ==
            null,
      );

      expect(
        state.postes.firstWhere((poste) => poste.id == posteId).lines.single.unitPrice.vatRateBasisPoints,
        isNull,
      );
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
      expect(await propertiesManager.budgetLastRightDockTab.load(), OcptBudgetRightDockTab.versions);
    });
  });

  group("the cash journal", () {
    test("loads its entries, and paidCentsOf reflects a poste that has actually been paid", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final otherPosteId = loaded.postes[1].id;
      final project = projectsManager.currentProject!;

      await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "Camera rental",
        posteId: posteId,
        debitCents: 5000,
      );

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      expect(state.entries, hasLength(1));
      expect(state.paidCentsOf(posteId), 5000);
      // A poste with no entry against it reads a real zero, not a hole.
      expect(state.paidCentsOf(otherPosteId), 0);
    });
  });

  group("creating a cash-journal entry", () {
    test("writes the typed amount onto debitCents when isDebit is true", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Camera rental",
            posteId: posteId,
            resourceId: null,
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
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      expect(state.entries, hasLength(1));
      final entry = state.entries.single;
      expect(entry.label, "Camera rental");
      expect(entry.posteId, posteId);
      expect(entry.debitCents, 5000);
      expect(entry.creditCents, 0);
      // The service mints its own voucher number rather than reading the (null) one submitted.
      expect(entry.voucherNumber, "J-001");
    });

    test("writes the typed amount onto creditCents when isDebit is false", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3, 2),
            label: "Grant received",
            posteId: null,
            resourceId: null,
            isDebit: false,
            amountCents: 20000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      final entry = state.entries.single;
      expect(entry.debitCents, 0);
      expect(entry.creditCents, 20000);
      expect(entry.posteId, isNull);
    });
  });

  group("an entry's own voucher", () {
    test("a fresh pick on creation is referenced against the new entry", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Camera rental",
            posteId: posteId,
            resourceId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: "/tmp/receipt.pdf",
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.entries.isNotEmpty && state.receiptsByEntryId.isNotEmpty,
      );

      final entry = state.entries.single;
      expect(state.receiptsByEntryId[entry.id]?.path, "/tmp/receipt.pdf");
    });

    test("a fresh pick on an edit replaces whatever the entry already referenced", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "Original",
        posteId: posteId,
        debitCents: 1000,
      );
      await projectsManager.budgetJournalService.setEntryReceipt(
        database: project.database,
        entryId: entryId!,
        path: "/tmp/first.pdf",
      );

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.receiptsByEntryId.isNotEmpty);

      bloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026),
            label: "Original",
            posteId: posteId,
            resourceId: null,
            isDebit: true,
            amountCents: 1000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: "/tmp/second.pdf",
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.receiptsByEntryId[entryId]?.path == "/tmp/second.pdf",
      );

      expect(state.receiptsByEntryId, hasLength(1));
    });

    test("the dialog's own Detach action drops the reference on an edit", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "Original",
        posteId: posteId,
        debitCents: 1000,
      );
      await projectsManager.budgetJournalService.setEntryReceipt(
        database: project.database,
        entryId: entryId!,
        path: "/tmp/receipt.pdf",
      );

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.receiptsByEntryId.isNotEmpty);

      bloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026),
            label: "Original",
            posteId: posteId,
            resourceId: null,
            isDebit: true,
            amountCents: 1000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: true,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.receiptsByEntryId.isEmpty);

      expect(state.receiptsByEntryId, isEmpty);
    });

    test("settling a commitment can reference a voucher on the fresh entry it creates", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "Camera deposit",
        amountCents: 5000,
      );
      expect(commitmentId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      bloc.add(
        OcptBudgetCommitmentSettlementConfirmedEvent(
          commitmentId: commitmentId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 4),
            label: "Camera deposit",
            posteId: posteId,
            resourceId: null,
            isDebit: true,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: "/tmp/invoice.pdf",
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.commitments.single.isSettled && state.receiptsByEntryId.isNotEmpty,
      );

      final settledEntry = state.entries.single;
      expect(state.receiptsByEntryId[settledEntry.id]?.path, "/tmp/invoice.pdf");
    });
  });

  group("editing a cash-journal entry", () {
    test("writes every field back, the voucher number included", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final otherPosteId = loaded.postes[1].id;
      final project = projectsManager.currentProject!;

      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "Original",
        posteId: posteId,
        debitCents: 1000,
      );
      expect(entryId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.entries.isNotEmpty);

      bloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 2, 2),
            label: "Renamed",
            posteId: otherPosteId,
            resourceId: null,
            isDebit: false,
            amountCents: 750,
            isTaxInclusive: false,
            vatRateBasisPoints: 2000,
            voucherNumber: "J-999",
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.single.label == "Renamed");

      final entry = state.entries.single;
      expect(entry.posteId, otherPosteId);
      expect(entry.debitCents, 0);
      expect(entry.creditCents, 750);
      expect(entry.isTaxInclusive, isFalse);
      expect(entry.vatRateBasisPoints, 2000);
      expect(entry.voucherNumber, "J-999");
    });
  });

  group("deleting a cash-journal entry", () {
    test("tombstones it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026),
        label: "To be deleted",
        posteId: posteId,
        debitCents: 500,
      );
      expect(entryId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.entries.isNotEmpty);

      bloc.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId!));
      final state = await waitForState(bloc, (state) => state.entries.isEmpty);

      expect(state.entries, isEmpty);
    });
  });

  group("clearing the cash journal filter", () {
    test("clears the selected poste", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId));
      await waitForState(bloc, (state) => state.selectedPosteId == posteId);

      bloc.add(const OcptBudgetCashJournalFilterClearedEvent());
      final state = await waitForState(bloc, (state) => state.selectedPosteId == null);

      expect(state.selectedPosteId, isNull);
    });
  });

  group("creating a commitment", () {
    test("writes every field, defaulting settledEntryId to null", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      bloc.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          fields: OcptBudgetCommitmentFormFields(
            dueDate: DateTime(2026, 6),
            label: "Camera deposit",
            posteId: posteId,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      expect(state.commitments, hasLength(1));
      final commitment = state.commitments.single;
      expect(commitment.label, "Camera deposit");
      expect(commitment.posteId, posteId);
      expect(commitment.amount.amountCents, 5000);
      expect(commitment.status, OcptBudgetCommitmentStatus.quoteAccepted);
      expect(commitment.isSettled, isFalse);
    });
  });

  group("editing a commitment", () {
    test("writes every field back, never the poste", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "Original",
        amountCents: 1000,
      );
      expect(commitmentId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      bloc.add(
        OcptBudgetCommitmentUpdateConfirmedEvent(
          commitmentId: commitmentId!,
          fields: OcptBudgetCommitmentFormFields(
            dueDate: DateTime(2026, 3),
            label: "Renamed",
            posteId: posteId,
            amountCents: 750,
            isTaxInclusive: false,
            vatRateBasisPoints: 2000,
            status: OcptBudgetCommitmentStatus.invoiceReceived,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.commitments.single.label == "Renamed");

      final commitment = state.commitments.single;
      expect(commitment.posteId, posteId);
      expect(commitment.amount.amountCents, 750);
      expect(commitment.amount.isTaxInclusive, isFalse);
      expect(commitment.amount.vatRateBasisPoints, 2000);
      expect(commitment.status, OcptBudgetCommitmentStatus.invoiceReceived);
    });
  });

  group("deleting a commitment", () {
    test("tombstones it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "To be deleted",
        amountCents: 500,
      );
      expect(commitmentId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      bloc.add(OcptBudgetCommitmentDeletionConfirmedEvent(commitmentId: commitmentId!));
      final state = await waitForState(bloc, (state) => state.commitments.isEmpty);

      expect(state.commitments, isEmpty);
    });
  });

  group("settling a commitment", () {
    test("creates a debit entry and links it as settledEntryId", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "Camera deposit",
        amountCents: 5000,
      );
      expect(commitmentId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      bloc.add(
        OcptBudgetCommitmentSettlementConfirmedEvent(
          commitmentId: commitmentId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 4),
            label: "Camera deposit",
            posteId: posteId,
            resourceId: null,
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
      final state = await waitForState(bloc, (state) => state.commitments.single.isSettled);

      expect(state.entries, hasLength(1));
      final entry = state.entries.single;
      expect(entry.debitCents, 5000);
      expect(entry.creditCents, 0);
      final commitment = state.commitments.single;
      expect(commitment.settledEntryId, entry.id);
      // Settled, it no longer counts as committed against the poste.
      expect(state.committedCentsOf(posteId), 0);
    });
  });

  group("unsettling a commitment", () {
    test("clears the link but leaves the journal entry alone", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;
      final project = projectsManager.currentProject!;

      final commitmentId = await projectsManager.budgetJournalService.createCommitment(
        database: project.database,
        posteId: posteId,
        label: "Camera deposit",
        amountCents: 5000,
      );
      expect(commitmentId, isNotNull);
      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026, 4),
        label: "Camera deposit",
        posteId: posteId,
        debitCents: 5000,
      );
      expect(entryId, isNotNull);
      await projectsManager.budgetJournalService.updateCommitment(
        database: project.database,
        commitmentId: commitmentId!,
        settledEntryId: drift.Value(entryId),
      );

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.commitments.isNotEmpty && state.commitments.single.isSettled);

      bloc.add(OcptBudgetCommitmentUnsettleRequestedEvent(commitmentId: commitmentId));
      final state = await waitForState(bloc, (state) => !state.commitments.single.isSettled);

      expect(state.commitments.single.settledEntryId, isNull);
      // The journal entry itself is untouched.
      expect(state.entries, hasLength(1));
      expect(state.entries.single.id, entryId);
    });
  });

  group("the financing plan", () {
    test("loads every live resource alongside the quote", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;

      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
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
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
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

  group("creating a resource", () {
    test("writes every field and selects it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.valued,
            isReimbursable: false,
            notes: "Lent by the lab",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedResourceId != null);

      expect(state.resources, hasLength(1));
      final resource = state.resources.single;
      expect(resource.groupKind, OcptBudgetResourceGroupKind.inKind);
      expect(resource.label, "Camera loan");
      expect(resource.amountCents, 250000);
      expect(resource.status, OcptBudgetResourceStatus.valued);
      expect(resource.notes, "Lent by the lab");
      expect(state.selectedResourceId, resource.id);
    });
  });

  group("editing a resource", () {
    test("writes every field back", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Original",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);

      bloc.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId!,
          fields: const OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.cash,
            label: "Renamed",
            amountCents: 500,
            status: OcptBudgetResourceStatus.secured,
            isReimbursable: true,
            notes: "Repaid before the split",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.resources.single.label == "Renamed");

      final resource = state.resources.single;
      expect(resource.groupKind, OcptBudgetResourceGroupKind.cash);
      expect(resource.amountCents, 500);
      expect(resource.status, OcptBudgetResourceStatus.secured);
      expect(resource.isReimbursable, isTrue);
      expect(resource.notes, "Repaid before the split");
    });
  });

  group("deleting a resource", () {
    test("tombstones it, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "To be deleted",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);
      bloc.add(OcptBudgetResourceSelectedEvent(resourceId: resourceId!));
      await waitForState(bloc, (state) => state.selectedResourceId == resourceId);

      bloc.add(OcptBudgetResourceDeletionConfirmedEvent(resourceId: resourceId));
      final state = await waitForState(bloc, (state) => state.resources.isEmpty);

      expect(state.resources, isEmpty);
      expect(state.selectedResourceId, isNull);
    });
  });

  group("an entry naming a resource", () {
    test("writes resourceId, and it shows up in receivedByResourceId once credited", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);

      bloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Grant instalment",
            posteId: null,
            resourceId: resourceId,
            isDebit: false,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      expect(state.entries.single.resourceId, resourceId);
      expect(state.receivedByResourceId[resourceId]?.amountCents, 5000);
      expect(state.receivedCentsOf(resourceId!), 5000);
    });

    test("an edit can also name a resource, wiring it the very same way", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
      expect(resourceId, isNotNull);
      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Grant instalment",
        creditCents: 5000,
      );
      expect(entryId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.entries.isNotEmpty && state.resources.isNotEmpty);

      bloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Grant instalment",
            posteId: null,
            resourceId: resourceId,
            isDebit: false,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: "J-001",
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.entries.single.resourceId == resourceId,
      );

      expect(state.receivedCentsOf(resourceId!), 5000);
    });
  });

  group("the catering-and-travel pass", () {
    test("loads the schedule, the roles, the people and the prices, and computes the pass", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final project = projectsManager.currentProject!;

      final personId = await projectsManager.peopleService.createPerson(database: project.database);
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

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      // Waits for the crew count itself, not merely for a day to exist: the bloc's own initial
      // load (fired at construction, before any of the writes above) races these very writes, and
      // a state it emits mid-way through them would still make `regieDays` non-empty on its own.
      final state = await waitForState(
        bloc,
        (state) => state.regieDays.isNotEmpty && state.regieDays.single.crewCount == 1,
      );

      expect(state.regieDays.single.dayId, dayId);
      expect(state.regieDays.single.crewCount, 1);
      expect(state.regieDays.single.headCount, 1);
      expect(state.regieDays.single.cost.isComplete, isTrue);
      expect(state.regieDecorNameByDayId[dayId], "Studio A");

      expect(state.travelRows, hasLength(1));
      expect(state.travelRows.single.personId, personId);
      expect(state.travelRows.single.totalKmMilli, 20000);
      expect(state.people.map((person) => person.id), contains(personId));
    });
  });
}
