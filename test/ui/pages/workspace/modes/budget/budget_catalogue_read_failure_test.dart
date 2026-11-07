// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_snapshot_loader.dart';
import 'budget_bloc_test_doubles.dart';
import 'budget_write_failure_test_doubles.dart';

/// What the budget mode does when it cannot read the address book or the locations it is loaded
/// with, with a real SQLite failure (the table is gone): the loader answers the failure instead of
/// a budget, the mode stays loading, and reading again answers false and keeps the state.
void main() {
  final harness = BudgetFailureHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  for (final (name, table) in [("address book", "people"), ("locations", "locations")]) {
    group("when the $name cannot be read", () {
      /// Make the [table] unreadable.
      Future<void> lose() => harness.projectsManager.currentProject!.database.customStatement(
        "ALTER TABLE $table RENAME TO ${table}_gone",
      );

      test("the loader answers the failure instead of a budget", () async {
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

      test("a mode that cannot read it stays loading", () async {
        await lose();

        final bloc = await harness.buildBloc(isWaitingForLoad: false);
        await harness.settle();

        expect(bloc.state.isLoading, isTrue);
      });

      test("reading the budget again answers false and keeps the state", () async {
        final bloc = await harness.buildBloc();
        final held = bloc.state;
        await lose();

        expect(await bloc.reload({OcptBudgetReloadScope.snapshot}), isFalse);

        expect(bloc.state, same(held));
      });
    });
  }
}
