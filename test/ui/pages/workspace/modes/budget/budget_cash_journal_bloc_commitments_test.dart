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
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'budget_cash_journal_bloc_test_doubles.dart';

/// Run the tests of the budget cash journal bloc commitments.
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

  group("creating a commitment", () {
    test("writes every field, a fresh commitment reading unsettled", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      journalBloc.add(
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
      expect(
        ocptBudgetCommitmentIsSettledOf(commitment, state.entries, projectVatRateBasisPoints: null),
        isFalse,
      );
    });
  });

  group("editing a commitment", () {
    test("writes every field back, never the poste", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
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

      journalBloc.add(
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
      final state = await waitForState(
        bloc,
        (state) => state.commitments.single.label == "Renamed",
      );

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
      final journalBloc = buildJournal(bloc);
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

      journalBloc.add(OcptBudgetCommitmentDeletionConfirmedEvent(commitmentId: commitmentId!));
      final state = await waitForState(bloc, (state) => state.commitments.isEmpty);

      expect(state.commitments, isEmpty);
    });
  });

  group("settling a commitment", () {
    test("creates a debit entry naming the commitment it pays", () async {
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
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => ocptBudgetCommitmentIsSettledOf(
          state.commitments.single,
          state.entries,
          projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
        ),
      );

      expect(state.entries, hasLength(1));
      final entry = state.entries.single;
      expect(entry.debitCents, 5000);
      expect(entry.creditCents, 0);
      final commitment = state.commitments.single;
      expect(entry.commitmentId, commitment.id);
      // Settled, it no longer counts as committed against the poste.
      expect(state.committedCentsOf(posteId), 0);
    });
  });

  group("unsettling a commitment", () {
    test("clears the link but leaves the journal entry alone", () async {
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
      final entryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026, 4),
        label: "Camera deposit",
        posteId: posteId,
        commitmentId: commitmentId,
        debitCents: 5000,
      );
      expect(entryId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(
        bloc,
        (state) =>
            state.commitments.isNotEmpty &&
            ocptBudgetCommitmentIsSettledOf(
              state.commitments.single,
              state.entries,
              projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
            ),
      );

      journalBloc.add(OcptBudgetCommitmentUnsettleRequestedEvent(commitmentId: commitmentId!));
      final state = await waitForState(
        bloc,
        (state) => !ocptBudgetCommitmentIsSettledOf(
          state.commitments.single,
          state.entries,
          projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
        ),
      );

      expect(state.entries.single.commitmentId, isNull);
      // The journal entry itself is untouched.
      expect(state.entries, hasLength(1));
      expect(state.entries.single.id, entryId);
    });

    test("clears the link on every entry naming the commitment, not just the first", () async {
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
      final firstEntryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026, 4),
        label: "Deposit",
        posteId: posteId,
        commitmentId: commitmentId,
        debitCents: 3000,
      );
      final secondEntryId = await projectsManager.budgetJournalService.createEntry(
        database: project.database,
        date: DateTime(2026, 5),
        label: "Balance",
        posteId: posteId,
        commitmentId: commitmentId,
        debitCents: 2000,
      );
      expect(firstEntryId, isNotNull);
      expect(secondEntryId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(
        bloc,
        (state) =>
            state.commitments.isNotEmpty &&
            ocptBudgetCommitmentIsSettledOf(
              state.commitments.single,
              state.entries,
              projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
            ),
      );

      journalBloc.add(OcptBudgetCommitmentUnsettleRequestedEvent(commitmentId: commitmentId!));
      final state = await waitForState(
        bloc,
        (state) => state.entries.every((entry) => entry.commitmentId == null),
      );

      // Both entries are unlinked, and both survive untouched otherwise.
      expect(state.entries, hasLength(2));
      expect(state.entries.map((entry) => entry.commitmentId), everyElement(isNull));
      expect(
        state.entries.map((entry) => entry.id),
        containsAll(<String>[firstEntryId!, secondEntryId!]),
      );
    });
  });

  group("an entry naming a resource", () {
    test("writes resourceId, and it shows up in receivedByResourceId once credited", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Regional grant",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);

      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Grant instalment",
            posteId: null,
            resourceId: resourceId,
            revenueId: null,
            shareId: null,
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
      final journalBloc = buildJournal(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
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

      journalBloc.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: entryId!,
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Grant instalment",
            posteId: null,
            resourceId: resourceId,
            revenueId: null,
            shareId: null,
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

  group("an entry naming a revenue", () {
    test("writes revenueId, and it shows up in receivedByRevenueId once credited", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Festival prize",
      );
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);

      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Prize received",
            posteId: null,
            resourceId: null,
            revenueId: revenueId,
            shareId: null,
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

      expect(state.entries.single.revenueId, revenueId);
      expect(state.receivedByRevenueId[revenueId]?.amountCents, 5000);
      expect(state.receivedRevenueCentsOf(revenueId!), 5000);
    });
  });

  group("an entry naming a share", () {
    test("writes shareId, and it shows up in paidByShareId once debited", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final shareId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "Production",
      );
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.isNotEmpty);

      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
            label: "Payout",
            posteId: null,
            resourceId: null,
            revenueId: null,
            shareId: shareId,
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

      expect(state.entries.single.shareId, shareId);
      expect(state.paidByShareId[shareId]?.amountCents, 5000);
      expect(state.paidShareCentsOf(shareId!), 5000);
    });
  });

  group("the events of the cash journal bloc", () {
    /// The name of each event of the cash journal hierarchy: the switch names every one, so an
    /// event added to the hierarchy does not compile until this list, and the test below, know it.
    String nameOf(OcptBudgetCashJournalEvent event) => switch (event) {
      OcptBudgetEntryCreationConfirmedEvent() => "entry created",
      OcptBudgetEntryUpdateConfirmedEvent() => "entry updated",
      OcptBudgetEntryDeletionConfirmedEvent() => "entry deleted",
      OcptBudgetEntryPromotedToQuoteEvent() => "entry promoted",
      OcptBudgetEntryMovedOffQuoteEvent() => "entry moved off quote",
      OcptBudgetCommitmentCreationConfirmedEvent() => "commitment created",
      OcptBudgetCommitmentUpdateConfirmedEvent() => "commitment updated",
      OcptBudgetCommitmentDeletionConfirmedEvent() => "commitment deleted",
      OcptBudgetCommitmentSettlementConfirmedEvent() => "commitment settled",
      OcptBudgetCommitmentPromotedToQuoteEvent() => "commitment promoted",
      OcptBudgetCommitmentUnsettleRequestedEvent() => "commitment unsettled",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final journalBloc = buildJournal(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      final handled = <String>[];
      Future<void> proves(
        OcptBudgetCashJournalEvent event,
        bool Function(OcptBudgetState) effect,
      ) async {
        journalBloc.add(event);
        await waitForState(bloc, effect);
        handled.add(nameOf(event));
      }

      OcptBudgetEntryFormFields entry(String label) => OcptBudgetEntryFormFields(
        date: DateTime(2026, 3),
        label: label,
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
      );
      OcptBudgetCommitmentFormFields commitment(String label) => OcptBudgetCommitmentFormFields(
        dueDate: DateTime(2026, 6),
        label: label,
        posteId: posteId,
        amountCents: 5000,
        isTaxInclusive: true,
        vatRateBasisPoints: null,
        status: OcptBudgetCommitmentStatus.quoteAccepted,
      );

      // An event nobody handles is ignored silently, so each is proven by its effect.
      await proves(
        OcptBudgetEntryCreationConfirmedEvent(fields: entry("First")),
        (state) => state.entries.length == 1,
      );
      final entryId = bloc.state.entries.single.id;
      await proves(
        OcptBudgetEntryUpdateConfirmedEvent(entryId: entryId, fields: entry("Renamed")),
        (state) => state.entries.single.label == "Renamed",
      );
      await proves(
        OcptBudgetEntryMovedOffQuoteEvent(entryId: entryId),
        (state) => state.entries.single.posteId == null,
      );
      await proves(
        OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId),
        (state) => state.entries.isEmpty,
      );

      await proves(
        OcptBudgetCommitmentCreationConfirmedEvent(fields: commitment("Deposit")),
        (state) => state.commitments.length == 1,
      );
      final commitmentId = bloc.state.commitments.single.id;
      await proves(
        OcptBudgetCommitmentUpdateConfirmedEvent(
          commitmentId: commitmentId,
          fields: commitment("Renamed"),
        ),
        (state) => state.commitments.single.label == "Renamed",
      );
      await proves(
        OcptBudgetCommitmentSettlementConfirmedEvent(
          commitmentId: commitmentId,
          fields: entry("Paid"),
        ),
        (state) => state.entries.length == 1,
      );
      await proves(
        OcptBudgetCommitmentUnsettleRequestedEvent(commitmentId: commitmentId),
        (state) => state.entries.single.commitmentId == null,
      );
      await proves(
        OcptBudgetEntryPromotedToQuoteEvent(entryId: bloc.state.entries.single.id),
        (state) => state.entries.single.commitmentId != null,
      );
      await proves(
        OcptBudgetCommitmentPromotedToQuoteEvent(commitmentId: commitmentId),
        (state) =>
            state.commitments.firstWhere((commitment) => commitment.id == commitmentId).lineId !=
            null,
      );
      await proves(
        OcptBudgetCommitmentDeletionConfirmedEvent(commitmentId: commitmentId),
        (state) => state.commitments.length == 1,
      );

      expect(handled.toSet(), hasLength(11), reason: "one proof per event of the hierarchy");
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      buildJournal(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);
    });
  });
}
