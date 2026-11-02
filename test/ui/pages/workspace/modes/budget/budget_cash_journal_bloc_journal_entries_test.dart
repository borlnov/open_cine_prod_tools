// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'budget_cash_journal_bloc_test_doubles.dart';

/// Run the tests of the budget cash journal bloc journal entries.
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_cash_journal_bloc_test_test_");
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

  /// Builds the mode bloc wired to the test project, seeded with [seed] (defaulting to
  /// [smallSeed]).
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

  group("the cash journal", () {
    test(
      "loads its entries, and paidCentsOf reflects a poste that has actually been paid",
      () async {
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
      },
    );
  });

  group("creating a cash-journal entry", () {
    test("a taking named as still to be made is created, and the entry names it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 6),
            label: "Festival prize paid",
            posteId: null,
            resourceId: null,
            revenueId: null,
            shareId: null,
            newRevenue: OcptBudgetRevenueFormFields(
              date: DateTime(2026, 5),
              label: "Clermont-Ferrand — grand prix",
              amountCents: 200000,
              status: OcptBudgetRevenueStatus.expected,
              notes: "",
            ),
            isDebit: false,
            amountCents: 200000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.entries.isNotEmpty);

      // The taking is written exactly as the sharing view would have written it — every field,
      // not just the label the journal needed to name it by.
      expect(state.revenues, hasLength(1));
      final revenue = state.revenues.single;
      expect(revenue.label, "Clermont-Ferrand — grand prix");
      expect(revenue.date, DateTime(2026, 5));
      expect(revenue.amountCents, 200000);

      // And the movement points at it, so the sharing view reads the money as actually received
      // rather than as an unattached credit.
      expect(state.entries.single.revenueId, revenue.id);
    });

    test("writes the typed amount onto debitCents when isDebit is true", () async {
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
      final journalBloc = buildJournal(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3, 2),
            label: "Grant received",
            posteId: null,
            resourceId: null,
            revenueId: null,
            shareId: null,
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
      final journalBloc = buildJournal(bloc);
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

      journalBloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026),
            label: "Original",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
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
      final journalBloc = buildJournal(bloc);
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

      journalBloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026),
            label: "Original",
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
      final journalBloc = buildJournal(bloc);
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

      journalBloc.add(
        OcptBudgetCommitmentSettlementConfirmedEvent(
          commitmentId: commitmentId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 4),
            label: "Camera deposit",
            posteId: posteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
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
        (state) =>
            ocptBudgetCommitmentIsSettledOf(
              state.commitments.single,
              state.entries,
              projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
            ) &&
            state.receiptsByEntryId.isNotEmpty,
      );

      final settledEntry = state.entries.single;
      expect(state.receiptsByEntryId[settledEntry.id]?.path, "/tmp/invoice.pdf");
    });
  });

  group("editing a cash-journal entry", () {
    test("writes every field back, the voucher number included", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
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

      journalBloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 2, 2),
            label: "Renamed",
            posteId: otherPosteId,
            resourceId: null,
            revenueId: null,
            shareId: null,
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
      final journalBloc = buildJournal(bloc);
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

      journalBloc.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId!));
      final state = await waitForState(bloc, (state) => state.entries.isEmpty);

      expect(state.entries, isEmpty);
    });
  });

  group("promoting a quote line into a commitment", () {
    test("the commitment names the line it came from, and the line stays put", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final expensesBloc = buildExpenses(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      expensesBloc.add(OcptBudgetLineCreatedEvent(posteId: posteId));
      final withLine = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);
      final lineId = withLine.postes.first.lines.single.id;

      journalBloc.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          lineId: lineId,
          fields: OcptBudgetCommitmentFormFields(
            dueDate: DateTime(2026, 6),
            label: "Camera deposit",
            posteId: posteId,
            amountCents: 145000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      expect(state.commitments.single.lineId, lineId);
      // A promotion, not a move: the estimate stays, which is what makes comparing it with what
      // is actually owed possible at all.
      expect(state.postes.first.lines.map((line) => line.id), [lineId]);
    });

    test("a commitment typed from scratch names no line", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      journalBloc.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          fields: OcptBudgetCommitmentFormFields(
            dueDate: null,
            label: "Insurance",
            posteId: loaded.postes.first.id,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.commitments.isNotEmpty);

      expect(state.commitments.single.lineId, isNull);
    });
  });

  group("promoting an off-line debit entry into the quote", () {
    test("mints a line and a settled commitment, re-pointing the very same entry", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      // An off-line debit against a poste with no quote yet — over its (empty) quote by
      // construction.
      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 4),
            label: "Generator rental",
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
      expect(
        ocptBudgetVarianceCents(
          quotedAmountCents: ocptBudgetPosteQuotedTotalCents(withEntry.postes.first),
          paidCents: withEntry.paidCentsOf(posteId),
          committedCents: withEntry.committedCentsOf(posteId),
          inKindCoveredCents: withEntry.inKindCoveredCentsOf(posteId),
        ),
        5000,
      );

      journalBloc.add(OcptBudgetEntryPromotedToQuoteEvent(entryId: entryId));
      final state = await waitForState(
        bloc,
        (state) => state.postes.first.lines.isNotEmpty && state.commitments.isNotEmpty,
      );

      // One line, mirroring the entry exactly.
      expect(state.postes.first.lines, hasLength(1));
      final line = state.postes.first.lines.single;
      expect(line.label, "Generator rental");
      expect(line.quantityMilli, 1000);
      expect(line.unitPrice.amountCents, 5000);
      expect(line.unitPrice.isTaxInclusive, isTrue);

      // One commitment, made from that line, naming it.
      expect(state.commitments, hasLength(1));
      final commitment = state.commitments.single;
      expect(commitment.lineId, line.id);
      expect(commitment.amount.amountCents, 5000);

      // The very same entry now settles it — never a second one.
      expect(state.entries, hasLength(1));
      final entry = state.entries.single;
      expect(entry.id, entryId);
      expect(entry.commitmentId, commitment.id);
      expect(entry.debitCents, 5000);

      // The overrun is gone: quoted, paid and committed now agree.
      expect(
        ocptBudgetVarianceCents(
          quotedAmountCents: ocptBudgetPosteQuotedTotalCents(state.postes.first),
          paidCents: state.paidCentsOf(posteId),
          committedCents: state.committedCentsOf(posteId),
          inKindCoveredCents: state.inKindCoveredCentsOf(posteId),
        ),
        0,
      );
    });

    test("does nothing on an entry that already names a commitment", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
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
      final withCommitment = await waitForState(
        bloc,
        (state) => state.commitments.isNotEmpty && state.entries.isNotEmpty,
      );
      final entryId = withCommitment.entries.single.id;

      journalBloc.add(OcptBudgetEntryPromotedToQuoteEvent(entryId: entryId));
      await pumpEventQueue();

      // No second line, no second commitment: the guard bailed.
      expect(bloc.state.postes.first.lines, hasLength(1));
      expect(bloc.state.commitments, hasLength(1));
    });
  });

  group("promoting an off-line commitment into the quote", () {
    test("mints a line and re-points the very same commitment at it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      // An off-line commitment (no lineId) against a poste with no quote yet — over its (empty)
      // quote by construction.
      journalBloc.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          fields: OcptBudgetCommitmentFormFields(
            dueDate: DateTime(2026, 6),
            label: "Green brief",
            posteId: posteId,
            amountCents: 890,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      final withCommitment = await waitForState(bloc, (state) => state.commitments.isNotEmpty);
      final commitmentId = withCommitment.commitments.single.id;
      expect(withCommitment.commitments.single.lineId, isNull);
      expect(
        ocptBudgetVarianceCents(
          quotedAmountCents: ocptBudgetPosteQuotedTotalCents(withCommitment.postes.first),
          paidCents: withCommitment.paidCentsOf(posteId),
          committedCents: withCommitment.committedCentsOf(posteId),
          inKindCoveredCents: withCommitment.inKindCoveredCentsOf(posteId),
        ),
        890,
      );

      journalBloc.add(OcptBudgetCommitmentPromotedToQuoteEvent(commitmentId: commitmentId));
      final state = await waitForState(bloc, (state) => state.postes.first.lines.isNotEmpty);

      // One line, mirroring the commitment exactly.
      expect(state.postes.first.lines, hasLength(1));
      final line = state.postes.first.lines.single;
      expect(line.label, "Green brief");
      expect(line.quantityMilli, 1000);
      expect(line.unitPrice.amountCents, 890);
      expect(line.unitPrice.isTaxInclusive, isTrue);

      // The very same commitment now names that line — never a second commitment.
      expect(state.commitments, hasLength(1));
      expect(state.commitments.single.id, commitmentId);
      expect(state.commitments.single.lineId, line.id);

      // The overrun is gone: the quote now covers what was committed.
      expect(
        ocptBudgetVarianceCents(
          quotedAmountCents: ocptBudgetPosteQuotedTotalCents(state.postes.first),
          paidCents: state.paidCentsOf(posteId),
          committedCents: state.committedCentsOf(posteId),
          inKindCoveredCents: state.inKindCoveredCentsOf(posteId),
        ),
        0,
      );
    });

    test("does nothing on a commitment that already names a line", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
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
      final withCommitment = await waitForState(bloc, (state) => state.commitments.isNotEmpty);
      final commitmentId = withCommitment.commitments.single.id;

      journalBloc.add(OcptBudgetCommitmentPromotedToQuoteEvent(commitmentId: commitmentId));
      await pumpEventQueue();

      // No second line minted: the guard bailed on an already line-nested commitment.
      expect(bloc.state.postes.first.lines, hasLength(1));
      expect(bloc.state.commitments, hasLength(1));
    });
  });

  group("moving an off-line debit entry off-quote", () {
    test("clears the entry's own poste and nothing else", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 4),
            label: "Generator rental",
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

      journalBloc.add(OcptBudgetEntryMovedOffQuoteEvent(entryId: entryId));
      final state = await waitForState(bloc, (state) => state.entries.single.posteId == null);

      final entry = state.entries.single;
      expect(entry.id, entryId);
      expect(entry.posteId, isNull);
      expect(entry.debitCents, 5000);
      expect(entry.commitmentId, isNull);
      // Nothing was promoted: the poste's own quote is untouched.
      expect(state.postes.first.lines, isEmpty);
    });

    test("does nothing on an entry that already names a commitment", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
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
      final withCommitment = await waitForState(
        bloc,
        (state) => state.commitments.isNotEmpty && state.entries.isNotEmpty,
      );
      final entryId = withCommitment.entries.single.id;

      journalBloc.add(OcptBudgetEntryMovedOffQuoteEvent(entryId: entryId));
      await pumpEventQueue();

      expect(bloc.state.entries.single.posteId, posteId);
    });
  });
}
