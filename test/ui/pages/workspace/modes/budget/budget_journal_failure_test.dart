// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_snapshot_loader.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'budget_bloc_test_doubles.dart';
import 'budget_write_failure_test_doubles.dart';

/// The ids of what the tests seed, and the views they drive.
typedef Seeded = ({
  OcptBudgetCashJournalBloc view,
  OcptBudgetExpensesBloc expenses,
  String account,
  String line,
  String entry,
  String commitment,
  String settledCommitment,
});

/// What the budget does when the database refuses a write of the cash journal, or cannot read it,
/// with a real SQLite failure: the handler stops where the exception stopped it, nothing is read
/// again, and the same event goes through once the refusal is lifted.
void main() {
  final harness = BudgetFailureHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// The fields of an entry of the account [accountId], with the voucher [receiptPath] if any.
  OcptBudgetEntryFormFields entryFields(String accountId, {String? receiptPath}) =>
      OcptBudgetEntryFormFields(
        date: DateTime(2026, 4),
        label: "Rental",
        accountId: accountId,
        resourceId: null,
        revenueId: null,
        shareId: null,
        isDebit: true,
        amountCents: 1000,
        isTaxInclusive: true,
        vatRateBasisPoints: null,
        voucherNumber: null,
        pickedReceiptPath: receiptPath,
        isReceiptDetached: false,
      );

  /// The fields of a commitment of the account [accountId].
  OcptBudgetCommitmentFormFields commitmentFields(String accountId) =>
      OcptBudgetCommitmentFormFields(
        dueDate: DateTime(2026, 6),
        label: "Deposit",
        accountId: accountId,
        amountCents: 5000,
        isTaxInclusive: true,
        vatRateBasisPoints: null,
        status: OcptBudgetCommitmentStatus.quoteAccepted,
      );

  /// Seed an account with a line, an off-line debit entry, an off-line commitment and a commitment
  /// that an entry settles, then build the mode and the two views that write the journal.
  Future<Seeded> build() async {
    final database = harness.projectsManager.currentProject!.database;
    final quote = harness.projectsManager.budgetQuoteService;
    final journal = harness.projectsManager.budgetJournalService;
    final account = await quote.createAccount(database: database, label: "Camera").valueOrFail;
    final line = await quote
        .createLine(database: database, accountId: account, label: "Camera deposit")
        .valueOrFail;
    final entry = await journal
        .createEntry(
          database: database,
          date: DateTime(2026, 3),
          label: "Till receipt",
          accountId: account,
          debitCents: 700,
        )
        .valueOrFail;
    final commitment = await journal
        .createCommitment(database: database, accountId: account, label: "Lights")
        .valueOrFail;
    final settledCommitment = await journal
        .createCommitment(database: database, accountId: account, label: "Van")
        .valueOrFail;
    await journal
        .createEntry(
          database: database,
          date: DateTime(2026, 3, 2),
          label: "Van payment",
          accountId: account,
          commitmentId: settledCommitment,
          debitCents: 300,
        )
        .valueOrFail;
    final mode = await harness.buildBloc();
    final view = OcptBudgetCashJournalBloc(
      modeBloc: mode,
      projectsManager: harness.projectsManager,
    );
    addTearDown(view.close);
    final expenses = OcptBudgetExpensesBloc(
      modeBloc: mode,
      projectsManager: harness.projectsManager,
    );
    addTearDown(expenses.close);
    await harness.settle();

    return (
      view: view,
      expenses: expenses,
      account: account,
      line: line,
      entry: entry,
      commitment: commitment,
      settledCommitment: settledCommitment,
    );
  }

  /// The handlers, each with the table and the verb that fail it, and a function dispatching the
  /// event to the view that handles it.
  final cases = <String, ({String table, String verb, void Function(Seeded seeded) dispatch})>{
    "creating an entry": (
      table: "budget_entries",
      verb: "INSERT",
      dispatch: (s) =>
          s.view.add(OcptBudgetEntryCreationConfirmedEvent(fields: entryFields(s.account))),
    ),
    "creating an entry whose voucher is refused": (
      table: "assets",
      verb: "INSERT",
      dispatch: (s) => s.view.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: entryFields(s.account, receiptPath: "/receipts/a.pdf"),
        ),
      ),
    ),
    "updating an entry": (
      table: "budget_entries",
      verb: "UPDATE",
      dispatch: (s) => s.view.add(
        OcptBudgetEntryUpdateConfirmedEvent(entryId: s.entry, fields: entryFields(s.account)),
      ),
    ),
    "updating an entry whose voucher is refused": (
      table: "assets",
      verb: "INSERT",
      dispatch: (s) => s.view.add(
        OcptBudgetEntryUpdateConfirmedEvent(
          entryId: s.entry,
          fields: entryFields(s.account, receiptPath: "/receipts/a.pdf"),
        ),
      ),
    ),
    "deleting an entry": (
      table: "budget_entries",
      verb: "UPDATE",
      dispatch: (s) => s.view.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: s.entry)),
    ),
    "creating a commitment": (
      table: "budget_commitments",
      verb: "INSERT",
      dispatch: (s) => s.view.add(
        OcptBudgetCommitmentCreationConfirmedEvent(fields: commitmentFields(s.account)),
      ),
    ),
    "updating a commitment": (
      table: "budget_commitments",
      verb: "UPDATE",
      dispatch: (s) => s.view.add(
        OcptBudgetCommitmentUpdateConfirmedEvent(
          commitmentId: s.commitment,
          fields: commitmentFields(s.account),
        ),
      ),
    ),
    "deleting a commitment": (
      table: "budget_commitments",
      verb: "UPDATE",
      dispatch: (s) =>
          s.view.add(OcptBudgetCommitmentDeletionConfirmedEvent(commitmentId: s.commitment)),
    ),
    "settling a commitment": (
      table: "budget_entries",
      verb: "INSERT",
      dispatch: (s) => s.view.add(
        OcptBudgetCommitmentSettlementConfirmedEvent(
          commitmentId: s.commitment,
          fields: entryFields(s.account),
        ),
      ),
    ),
    "settling a commitment whose voucher is refused": (
      table: "assets",
      verb: "INSERT",
      dispatch: (s) => s.view.add(
        OcptBudgetCommitmentSettlementConfirmedEvent(
          commitmentId: s.commitment,
          fields: entryFields(s.account, receiptPath: "/receipts/a.pdf"),
        ),
      ),
    ),
    "promoting an entry whose commitment is refused": (
      table: "budget_commitments",
      verb: "INSERT",
      dispatch: (s) => s.view.add(OcptBudgetEntryPromotedToQuoteEvent(entryId: s.entry)),
    ),
    "promoting an entry whose relink is refused": (
      table: "budget_entries",
      verb: "UPDATE",
      dispatch: (s) => s.view.add(OcptBudgetEntryPromotedToQuoteEvent(entryId: s.entry)),
    ),
    "moving an entry off the quote": (
      table: "budget_entries",
      verb: "UPDATE",
      dispatch: (s) => s.view.add(OcptBudgetEntryMovedOffQuoteEvent(entryId: s.entry)),
    ),
    "promoting a commitment whose relink is refused": (
      table: "budget_commitments",
      verb: "UPDATE",
      dispatch: (s) =>
          s.view.add(OcptBudgetCommitmentPromotedToQuoteEvent(commitmentId: s.commitment)),
    ),
    "undoing the settlement of a commitment": (
      table: "budget_entries",
      verb: "UPDATE",
      dispatch: (s) =>
          s.view.add(OcptBudgetCommitmentUnsettleRequestedEvent(commitmentId: s.settledCommitment)),
    ),
    "paying a line directly, its commitment refused": (
      table: "budget_commitments",
      verb: "INSERT",
      dispatch: (s) => s.expenses.add(
        OcptBudgetLinePaidDirectlyEvent(lineId: s.line, fields: entryFields(s.account)),
      ),
    ),
    "paying a line directly, its entry refused": (
      table: "budget_entries",
      verb: "INSERT",
      dispatch: (s) => s.expenses.add(
        OcptBudgetLinePaidDirectlyEvent(lineId: s.line, fields: entryFields(s.account)),
      ),
    ),
    "paying a line directly, its voucher refused": (
      table: "assets",
      verb: "INSERT",
      dispatch: (s) => s.expenses.add(
        OcptBudgetLinePaidDirectlyEvent(
          lineId: s.line,
          fields: entryFields(s.account, receiptPath: "/receipts/a.pdf"),
        ),
      ),
    ),
  };

  for (final entry in cases.entries) {
    final case_ = entry.value;
    test(
      "${entry.key} stops, reads nothing again, and goes through once the refusal is lifted",
      () async {
        final seeded = await build();
        final held = harness.state;
        await harness.refuse(case_.verb, case_.table);

        case_.dispatch(seeded);
        await harness.settle();

        if (entry.key.startsWith("paying a line directly")) {
          // One transaction: nothing is left behind, and the screen is read again.
          expect(harness.state.reloadEpoch, isNot(held.reloadEpoch));
          expect(harness.state.commitments, held.commitments);
          expect(harness.state.entries, held.entries);
        } else {
          expect(
            harness.state.reloadEpoch,
            held.reloadEpoch,
            reason: "the mode was read again after a failed write",
          );
        }
        expect(harness.state.selection, held.selection);

        await harness.lift(case_.verb, case_.table);
        case_.dispatch(seeded);
        await harness.settle();

        expect(harness.state.reloadEpoch, isNot(held.reloadEpoch));
      },
    );
  }

  test("an unsettled commitment stays settled while its entry cannot be written", () async {
    final seeded = await build();
    await harness.refuse("UPDATE", "budget_entries");

    seeded.view.add(
      OcptBudgetCommitmentUnsettleRequestedEvent(commitmentId: seeded.settledCommitment),
    );
    await harness.settle();

    expect(
      harness.state.entries.where((entry) => entry.commitmentId == seeded.settledCommitment),
      isNotEmpty,
    );
  });

  group("when a table the budget is read from is gone", () {
    for (final table in ["budget_entries", "budget_commitments", "assets", "elements"]) {
      /// Make [table] unreadable.
      Future<void> lose() => harness.projectsManager.currentProject!.database.customStatement(
        "ALTER TABLE $table RENAME TO ${table}_gone",
      );

      test("the loader answers the failure of $table instead of a budget", () async {
        await harness.buildBloc();
        await lose();
        final loader = OcptBudgetSnapshotLoader(
          projectsManager: harness.projectsManager,
          seed: smallSeed,
        );

        final read = await loader.load(harness.projectsManager.currentProject!);

        expect(read.status, OcptDatabaseStatus.databaseError);
        expect(read.value, isNull);
      });

      test("a mode that cannot read $table stays loading", () async {
        await lose();

        final bloc = await harness.buildBloc(isWaitingForLoad: false);
        await harness.settle();

        expect(bloc.state.isLoading, isTrue);
      });

      test("reading the budget again answers false when $table is gone", () async {
        final bloc = await harness.buildBloc();
        final held = bloc.state;
        await lose();

        expect(await bloc.reload({OcptBudgetReloadScope.snapshot}), isFalse);

        expect(bloc.state, same(held));
      });

      test("a change of the settings reads nothing the mode does not hold, $table gone", () async {
        final bloc = await harness.buildBloc();
        final held = bloc.state;
        await lose();

        bloc.add(const OcptBudgetProjectSettingsChangedEvent());
        await harness.settle();

        // The working copy capture of the versions panel reads the same tables, so the whole state
        // is not compared: what the mode read is.
        expect(bloc.state.snapshot, same(held.snapshot));
        expect(bloc.state.reloadEpoch, held.reloadEpoch);
      });
    }
  });
}
