// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_snapshot_loader.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'budget_bloc_test_doubles.dart';
import 'budget_write_failure_test_doubles.dart';

/// What the budget does when the database refuses a write of the revenue sharing, or cannot read
/// it, with a real SQLite failure: the handler stops where the exception stopped it, nothing is
/// read again, and the same event goes through once the refusal is lifted.
void main() {
  final harness = BudgetFailureHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  final revenueFields = OcptBudgetRevenueFormFields(
    date: DateTime.utc(2026, 5),
    label: "Created",
    amountCents: 5000,
    status: OcptBudgetRevenueStatus.confirmed,
    notes: "",
  );
  const shareFields = OcptBudgetShareFormFields(
    personId: null,
    label: "Created",
    sharePermille: 100,
    reinvestPermille: 0,
    notes: "",
  );

  /// The mode built on a project holding two takings and two shares, with the bloc of the sharing
  /// view and the ids of what was seeded.
  Future<({OcptBudgetSharingBloc view, List<String> revenueIds, List<String> shareIds})>
  build() async {
    final database = harness.projectsManager.currentProject!.database;
    final service = harness.projectsManager.budgetSharingService;
    final revenueIds = [
      for (final label in ["First", "Second"])
        await service
            .createRevenue(database: database, date: DateTime.utc(2026, 3), label: label)
            .valueOrFail,
    ];
    final shareIds = [
      for (final label in ["First", "Second"])
        await service.createShare(database: database, label: label).valueOrFail,
    ];
    final mode = await harness.buildBloc();
    final view = OcptBudgetSharingBloc(modeBloc: mode, projectsManager: harness.projectsManager);
    addTearDown(view.close);
    await harness.settle();

    return (view: view, revenueIds: revenueIds, shareIds: shareIds);
  }

  /// The handlers, each with the table and the verb that fail it, the event, and what proves it
  /// went through.
  final cases =
      <
        String,
        ({
          String table,
          String verb,
          OcptBudgetSharingEvent Function(List<String> revenues, List<String> shares) event,
          bool Function(OcptBudgetBloc mode) done,
        })
      >{
        "creating a taking": (
          table: "budget_revenues",
          verb: "INSERT",
          event: (_, _) => OcptBudgetRevenueCreationConfirmedEvent(fields: revenueFields),
          done: (mode) => mode.state.revenues.any((revenue) => revenue.label == "Created"),
        ),
        "writing the fields of a created taking": (
          table: "budget_revenues",
          verb: "UPDATE",
          event: (_, _) => OcptBudgetRevenueCreationConfirmedEvent(fields: revenueFields),
          done: (mode) => mode.state.revenues.any(
            (revenue) => revenue.label == "Created" && revenue.amountCents == 5000,
          ),
        ),
        "updating a taking": (
          table: "budget_revenues",
          verb: "UPDATE",
          event: (revenues, _) => OcptBudgetRevenueUpdateConfirmedEvent(
            revenueId: revenues.first,
            fields: revenueFields,
          ),
          done: (mode) => mode.state.revenues.any((revenue) => revenue.label == "Created"),
        ),
        "reordering a taking": (
          table: "budget_revenues",
          verb: "UPDATE",
          event: (revenues, _) =>
              OcptBudgetRevenueReorderedEvent(revenueId: revenues.last, newPosition: 0),
          done: (mode) => mode.state.revenues.first.label == "Second",
        ),
        "deleting a taking": (
          table: "budget_revenues",
          verb: "UPDATE",
          event: (revenues, _) =>
              OcptBudgetRevenueDeletionConfirmedEvent(revenueId: revenues.first),
          done: (mode) => mode.state.revenues.length == 1,
        ),
        "creating a share": (
          table: "budget_shares",
          verb: "INSERT",
          event: (_, _) => const OcptBudgetShareCreationConfirmedEvent(fields: shareFields),
          done: (mode) => mode.state.shares.any((share) => share.label == "Created"),
        ),
        "writing the fields of a created share": (
          table: "budget_shares",
          verb: "UPDATE",
          event: (_, _) => const OcptBudgetShareCreationConfirmedEvent(fields: shareFields),
          done: (mode) => mode.state.shares.any(
            (share) => share.label == "Created" && share.sharePermille == 100,
          ),
        ),
        "updating a share": (
          table: "budget_shares",
          verb: "UPDATE",
          event: (_, shares) =>
              OcptBudgetShareUpdateConfirmedEvent(shareId: shares.first, fields: shareFields),
          done: (mode) => mode.state.shares.any((share) => share.label == "Created"),
        ),
        "reordering a share": (
          table: "budget_shares",
          verb: "UPDATE",
          event: (_, shares) => OcptBudgetShareReorderedEvent(shareId: shares.last, newPosition: 0),
          done: (mode) => mode.state.shares.first.label == "Second",
        ),
        "deleting a share": (
          table: "budget_shares",
          verb: "UPDATE",
          event: (_, shares) => OcptBudgetShareDeletionConfirmedEvent(shareId: shares.first),
          done: (mode) => mode.state.shares.length == 1,
        ),
      };

  for (final entry in cases.entries) {
    final test_ = entry.value;
    test(
      "${entry.key} stops, leaves what is stored as it was, and goes through once lifted",
      () async {
        final built = await build();
        final held = harness.state;
        await harness.refuse(test_.verb, test_.table);

        built.view.add(test_.event(built.revenueIds, built.shareIds));
        await harness.settle();

        if (entry.key.startsWith("creating a ") ||
            entry.key.startsWith("writing the fields of a")) {
          // The creation is one transaction: the screen is read again, and shows what is stored.
          expect(harness.state.reloadEpoch, isNot(held.reloadEpoch));
          expect(harness.state.revenues, held.revenues);
          expect(harness.state.shares, held.shares);
        } else {
          expect(
            harness.state.reloadEpoch,
            held.reloadEpoch,
            reason: "the mode was read again after a failed write",
          );
        }
        expect(harness.state.selection, held.selection);

        await harness.lift(test_.verb, test_.table);
        built.view.add(test_.event(built.revenueIds, built.shareIds));
        await harness.settle();

        expect(test_.done(harness.modeBloc!), isTrue);
      },
    );
  }

  group("an entry that names a taking or a share still to be made", () {
    /// The fields of an entry creating [newRevenue] or [newShare] along with itself.
    OcptBudgetEntryFormFields entryFields({
      OcptBudgetRevenueFormFields? newRevenue,
      OcptBudgetShareFormFields? newShare,
    }) => OcptBudgetEntryFormFields(
      date: DateTime(2026, 6),
      label: "Prize paid",
      accountId: null,
      resourceId: null,
      revenueId: null,
      shareId: null,
      newRevenue: newRevenue,
      newShare: newShare,
      isDebit: false,
      amountCents: 1000,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    /// The mode and the cash journal view over it, holding one entry created without anything new.
    Future<({OcptBudgetCashJournalBloc view, String entryId})> buildJournal() async {
      final mode = await harness.buildBloc();
      final view = OcptBudgetCashJournalBloc(
        modeBloc: mode,
        projectsManager: harness.projectsManager,
      );
      addTearDown(view.close);
      view.add(OcptBudgetEntryCreationConfirmedEvent(fields: entryFields()));
      await harness.settle();

      return (view: view, entryId: harness.state.entries.single.id);
    }

    final journalCases =
        <
          String,
          ({
            String table,
            String verb,
            OcptBudgetCashJournalEvent Function(String entryId) event,
            bool Function(OcptBudgetBloc mode) done,
          })
        >{
          "creating an entry with a new taking": (
            table: "budget_revenues",
            verb: "INSERT",
            event: (_) => OcptBudgetEntryCreationConfirmedEvent(
              fields: entryFields(newRevenue: revenueFields),
            ),
            done: (mode) => mode.state.entries.length == 2 && mode.state.revenues.length == 1,
          ),
          "creating an entry with a new share": (
            table: "budget_shares",
            verb: "INSERT",
            event: (_) =>
                OcptBudgetEntryCreationConfirmedEvent(fields: entryFields(newShare: shareFields)),
            done: (mode) => mode.state.entries.length == 2 && mode.state.shares.length == 1,
          ),
          "creating an entry with a new taking whose fields cannot be written": (
            table: "budget_revenues",
            verb: "UPDATE",
            event: (_) => OcptBudgetEntryCreationConfirmedEvent(
              fields: entryFields(newRevenue: revenueFields),
            ),
            done: (mode) => mode.state.entries.length == 2,
          ),
          "updating an entry with a new taking": (
            table: "budget_revenues",
            verb: "INSERT",
            event: (id) => OcptBudgetEntryUpdateConfirmedEvent(
              entryId: id,
              fields: entryFields(newRevenue: revenueFields),
            ),
            done: (mode) => mode.state.revenues.length == 1,
          ),
          "updating an entry with a new share": (
            table: "budget_shares",
            verb: "INSERT",
            event: (id) => OcptBudgetEntryUpdateConfirmedEvent(
              entryId: id,
              fields: entryFields(newShare: shareFields),
            ),
            done: (mode) => mode.state.shares.length == 1,
          ),
        };

    for (final entry in journalCases.entries) {
      final test_ = entry.value;
      test(
        "${entry.key} stops before the entry is written, and goes through once lifted",
        () async {
          final built = await buildJournal();
          final held = harness.state;
          await harness.refuse(test_.verb, test_.table);

          built.view.add(test_.event(built.entryId));
          await harness.settle();

          expect(
            harness.state.reloadEpoch,
            held.reloadEpoch,
            reason: "the mode was read again after a failed write",
          );
          expect(harness.state.entries, held.entries);

          await harness.lift(test_.verb, test_.table);
          built.view.add(test_.event(built.entryId));
          await harness.settle();

          expect(test_.done(harness.modeBloc!), isTrue);
        },
      );
    }
  });

  group("when the takings or the shares cannot be read", () {
    for (final table in ["budget_revenues", "budget_shares"]) {
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

        expect(bloc.state, same(held));
      });
    }
  });
}
