// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_financing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_snapshot_loader.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'budget_bloc_test_doubles.dart';
import 'budget_write_failure_test_doubles.dart';

/// What the budget does when the database refuses a write of the financing plan, or cannot read
/// it, with a real SQLite failure: the handler stops where the exception stopped it, nothing is
/// read again, and the same event goes through once the refusal is lifted.
void main() {
  final harness = BudgetFailureHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  const resourceFields = OcptBudgetResourceFormFields(
    groupKind: OcptBudgetResourceGroupKind.cash,
    personId: null,
    label: "Created",
    amountCents: 5000,
    status: OcptBudgetResourceStatus.agreed,
    isReimbursable: false,
    notes: "",
    accountId: null,
  );

  /// The mode built on a project holding two resources, with the bloc of the financing view.
  Future<({OcptBudgetFinancingBloc view, List<String> resourceIds})> build() async {
    final database = harness.projectsManager.currentProject!.database;
    final service = harness.projectsManager.budgetFinancingService;
    final resourceIds = [
      for (final label in ["First", "Second"])
        await service.createResource(database: database, label: label).valueOrFail,
    ];
    final mode = await harness.buildBloc();
    final view = OcptBudgetFinancingBloc(modeBloc: mode, projectsManager: harness.projectsManager);
    addTearDown(view.close);
    await harness.settle();

    return (view: view, resourceIds: resourceIds);
  }

  /// The handlers, each with the verb that fails it, the event, and what proves it went through.
  final cases =
      <
        String,
        ({
          String verb,
          OcptBudgetFinancingEvent Function(List<String> resources) event,
          bool Function(OcptBudgetBloc mode) done,
        })
      >{
        "creating a resource": (
          verb: "INSERT",
          event: (_) => const OcptBudgetResourceCreationConfirmedEvent(fields: resourceFields),
          done: (mode) => mode.state.resources.any((resource) => resource.label == "Created"),
        ),
        "writing the fields of a created resource": (
          verb: "UPDATE",
          event: (_) => const OcptBudgetResourceCreationConfirmedEvent(fields: resourceFields),
          done: (mode) => mode.state.resources.any(
            (resource) => resource.label == "Created" && resource.amountCents == 5000,
          ),
        ),
        "updating a resource": (
          verb: "UPDATE",
          event: (resources) => OcptBudgetResourceUpdateConfirmedEvent(
            resourceId: resources.first,
            fields: resourceFields,
          ),
          done: (mode) => mode.state.resources.any((resource) => resource.label == "Created"),
        ),
        "deleting a resource": (
          verb: "UPDATE",
          event: (resources) =>
              OcptBudgetResourceDeletionConfirmedEvent(resourceId: resources.first),
          done: (mode) => mode.state.resources.length == 1,
        ),
      };

  for (final entry in cases.entries) {
    final test_ = entry.value;
    test(
      "${entry.key} stops, reads nothing again, and goes through once the refusal is lifted",
      () async {
        final built = await build();
        final held = harness.state;
        await harness.refuse(test_.verb, "budget_resources");

        built.view.add(test_.event(built.resourceIds));
        await harness.settle();

        expect(
          harness.state.reloadEpoch,
          held.reloadEpoch,
          reason: "the mode was read again after a failed write",
        );
        expect(harness.state.selection, held.selection);

        await harness.lift(test_.verb, "budget_resources");
        built.view.add(test_.event(built.resourceIds));
        await harness.settle();

        expect(test_.done(harness.modeBloc!), isTrue);
      },
    );
  }

  group("an entry that names a resource still to be made", () {
    /// The fields of an entry creating [newResource] along with itself.
    OcptBudgetEntryFormFields entryFields({OcptBudgetResourceFormFields? newResource}) =>
        OcptBudgetEntryFormFields(
          date: DateTime(2026, 6),
          label: "Grant received",
          accountId: null,
          resourceId: null,
          revenueId: null,
          shareId: null,
          newResource: newResource,
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
            String verb,
            OcptBudgetCashJournalEvent Function(String entryId) event,
            bool Function(OcptBudgetBloc mode) done,
          })
        >{
          "creating an entry with a new resource": (
            verb: "INSERT",
            event: (_) => OcptBudgetEntryCreationConfirmedEvent(
              fields: entryFields(newResource: resourceFields),
            ),
            done: (mode) => mode.state.entries.length == 2 && mode.state.resources.length == 1,
          ),
          "creating an entry with a new resource whose fields cannot be written": (
            verb: "UPDATE",
            event: (_) => OcptBudgetEntryCreationConfirmedEvent(
              fields: entryFields(newResource: resourceFields),
            ),
            done: (mode) => mode.state.entries.length == 2,
          ),
          "updating an entry with a new resource": (
            verb: "INSERT",
            event: (id) => OcptBudgetEntryUpdateConfirmedEvent(
              entryId: id,
              fields: entryFields(newResource: resourceFields),
            ),
            done: (mode) => mode.state.resources.length == 1,
          ),
        };

    for (final entry in journalCases.entries) {
      final test_ = entry.value;
      test(
        "${entry.key} stops before the entry is written, and goes through once lifted",
        () async {
          final built = await buildJournal();
          final held = harness.state;
          await harness.refuse(test_.verb, "budget_resources");

          built.view.add(test_.event(built.entryId));
          await harness.settle();

          expect(
            harness.state.reloadEpoch,
            held.reloadEpoch,
            reason: "the mode was read again after a failed write",
          );
          expect(harness.state.entries, held.entries);

          await harness.lift(test_.verb, "budget_resources");
          built.view.add(test_.event(built.entryId));
          await harness.settle();

          expect(test_.done(harness.modeBloc!), isTrue);
        },
      );
    }
  });

  group("when the resources or the mileage rates cannot be read", () {
    for (final table in ["budget_resources", "budget_mileage_rates"]) {
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
