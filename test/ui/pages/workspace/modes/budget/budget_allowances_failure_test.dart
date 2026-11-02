// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_financing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_snapshot_loader.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'budget_bloc_test_doubles.dart';
import 'budget_write_failure_test_doubles.dart';

/// What the budget does when the database refuses a write of the defrayals, or cannot read them,
/// with a real SQLite failure: the handler stops where the exception stopped it, nothing is read
/// again, and the same event goes through once the refusal is lifted.
void main() {
  final harness = BudgetFailureHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  const fields = OcptBudgetAllowanceFormFields(
    personId: null,
    kind: OcptBudgetAllowanceKind.travel,
    label: "Renamed",
    date: null,
    endDate: null,
    quantityMilli: 1000,
    unitAmountMilliCents: 100000,
    notes: "",
  );

  /// Seed a defrayal and build the mode on it, with the bloc of the financing view.
  Future<({OcptBudgetFinancingBloc view, String allowanceId})> build() async {
    final database = harness.projectsManager.currentProject!.database;
    final allowanceId = await harness.projectsManager.budgetAllowancesService
        .createAllowance(
          database: database,
          personId: null,
          kind: OcptBudgetAllowanceKind.travel,
          label: "First",
          date: null,
          endDate: null,
          quantityMilli: 1000,
          unitAmountMilliCents: 100000,
          notes: "",
        )
        .valueOrFail;
    final mode = await harness.buildBloc();
    final view = OcptBudgetFinancingBloc(modeBloc: mode, projectsManager: harness.projectsManager);
    addTearDown(view.close);

    return (view: view, allowanceId: allowanceId);
  }

  /// The handlers, each with the refusal that fails it, the event, and what proves it went through.
  final cases =
      <
        String,
        ({
          String verb,
          OcptBudgetFinancingEvent Function(String allowanceId) event,
          bool Function(List<String> labels) done,
        })
      >{
        "creating a defrayal": (
          verb: "INSERT",
          event: (_) => const OcptBudgetAllowanceCreationConfirmedEvent(fields: fields),
          done: (labels) => labels.length == 2,
        ),
        "updating a defrayal": (
          verb: "UPDATE",
          event: (id) => OcptBudgetAllowanceUpdateConfirmedEvent(allowanceId: id, fields: fields),
          done: (labels) => labels.single == "Renamed",
        ),
        "deleting a defrayal": (
          verb: "UPDATE",
          event: (id) => OcptBudgetAllowanceDeletionConfirmedEvent(allowanceId: id),
          done: (labels) => labels.isEmpty,
        ),
      };

  for (final entry in cases.entries) {
    test(
      "${entry.key} stops, reads nothing again, and goes through once the refusal is lifted",
      () async {
        final built = await build();
        final held = harness.state;
        await harness.refuse(entry.value.verb, "budget_allowances");

        built.view.add(entry.value.event(built.allowanceId));
        await harness.settle();

        expect(
          harness.state.reloadEpoch,
          held.reloadEpoch,
          reason: "the mode was read again after a failed write",
        );
        expect([for (final allowance in harness.state.allowances) allowance.label], ["First"]);

        await harness.lift(entry.value.verb, "budget_allowances");
        built.view.add(entry.value.event(built.allowanceId));
        await harness.settle();

        expect(
          entry.value.done([for (final allowance in harness.state.allowances) allowance.label]),
          isTrue,
        );
      },
    );
  }

  group("when the defrayals cannot be read", () {
    /// Make the defrayals unreadable.
    Future<void> loseTheAllowances() => harness.projectsManager.currentProject!.database
        .customStatement("ALTER TABLE budget_allowances RENAME TO budget_allowances_gone");

    test("the loader answers the failure instead of a budget", () async {
      await harness.buildBloc();
      await loseTheAllowances();
      final loader = OcptBudgetSnapshotLoader(
        projectsManager: harness.projectsManager,
        seed: smallSeed,
      );

      final read = await loader.load(harness.projectsManager.currentProject!);

      expect(read.status, OcptDatabaseStatus.databaseError);
      expect(read.value, isNull);
    });

    test("a mode that cannot read them stays loading", () async {
      await loseTheAllowances();

      final bloc = await harness.buildBloc(isWaitingForLoad: false);
      await harness.settle();

      expect(bloc.state.isLoading, isTrue);
    });

    test("reading the budget again answers false and leaves the state as it was", () async {
      final bloc = await harness.buildBloc();
      final held = bloc.state;
      await loseTheAllowances();

      expect(await bloc.reload({OcptBudgetReloadScope.snapshot}), isFalse);

      expect(bloc.state, same(held));
    });

    test("a change of the project's settings reads nothing the mode does not hold", () async {
      final bloc = await harness.buildBloc();
      final held = bloc.state;
      await loseTheAllowances();

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await harness.settle();

      expect(bloc.state, same(held));
    });
  });
}
