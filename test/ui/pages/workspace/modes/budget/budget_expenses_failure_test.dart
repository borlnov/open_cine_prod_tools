// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_snapshot_loader.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'budget_bloc_test_doubles.dart';
import 'budget_write_failure_test_doubles.dart';

/// The ids of what the tests seed, and the view they drive.
typedef Seeded = ({
  OcptBudgetExpensesBloc view,
  String firstAccount,
  String secondAccount,
  String line,
  String elementId,
});

/// What the budget does when the database refuses a write of the quote, or cannot read it, with a
/// real SQLite failure: the handler stops where the exception stopped it, nothing is read again,
/// and the same event goes through once the refusal is lifted.
void main() {
  final harness = BudgetFailureHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Seed two accounts, a line and an element, build the mode on them and the expenses view.
  Future<Seeded> build() async {
    final database = harness.projectsManager.currentProject!.database;
    final quote = harness.projectsManager.budgetQuoteService;
    final firstAccount = await quote.createAccount(database: database, label: "Cast").valueOrFail;
    final secondAccount = await quote.createAccount(database: database, label: "Crew").valueOrFail;
    final line = await quote
        .createLine(database: database, accountId: firstAccount, label: "Lead")
        .valueOrFail;
    await quote
        .updateAccount(
          database: database,
          accountId: secondAccount,
          estimateToCompleteCents: const Value(5000),
        )
        .okOrFail;
    await quote
        .updateLine(database: database, lineId: line, vatRateBasisPoints: const Value(550))
        .okOrFail;
    final elementId = (await harness.projectsManager.elementsService
        .createElement(
          database: database,
          name: "Camera body",
          category: OcptElementCategory.camera,
          sourceKind: OcptElementSourceKind.owned,
        )
        .valueOrFail);
    final mode = await harness.buildBloc();
    final view = OcptBudgetExpensesBloc(modeBloc: mode, projectsManager: harness.projectsManager);
    addTearDown(view.close);
    await harness.settle();

    return (
      view: view,
      firstAccount: firstAccount,
      secondAccount: secondAccount,
      line: line,
      elementId: elementId,
    );
  }

  /// The handlers, each with the table and the verb that fail it, the event, and what proves it
  /// went through.
  final cases =
      <
        String,
        ({
          String table,
          String verb,
          OcptBudgetExpensesEvent Function(Seeded seeded) event,
          bool Function(OcptBudgetBloc mode) done,
        })
      >{
        "creating an account": (
          table: "budget_postes",
          verb: "INSERT",
          event: (_) => const OcptBudgetAccountCreatedEvent(),
          done: (mode) => mode.state.accounts.length == 3,
        ),
        "reordering an account": (
          table: "budget_postes",
          verb: "UPDATE",
          event: (s) => OcptBudgetAccountReorderedEvent(accountId: s.secondAccount, newPosition: 0),
          done: (mode) => mode.state.accounts.first.label == "Crew",
        ),
        "deleting an account": (
          table: "budget_postes",
          verb: "UPDATE",
          event: (s) => OcptBudgetAccountDeletionConfirmedEvent(accountId: s.secondAccount),
          done: (mode) => mode.state.accounts.length == 1,
        ),
        "deriving the estimate to complete": (
          table: "budget_postes",
          verb: "UPDATE",
          event: (s) =>
              OcptBudgetAccountEstimateToCompleteDerivedRequestedEvent(accountId: s.secondAccount),
          done: (mode) => mode.state.accounts.last.estimateToCompleteCents == null,
        ),
        "creating a line": (
          table: "budget_lines",
          verb: "INSERT",
          event: (s) => OcptBudgetLineCreatedEvent(accountId: s.firstAccount),
          done: (mode) => mode.state.accounts.first.lines.length == 2,
        ),
        "creating a line from an element": (
          table: "budget_lines",
          verb: "INSERT",
          event: (s) => OcptBudgetLineCreatedFromElementEvent(
            accountId: s.firstAccount,
            elementId: s.elementId,
          ),
          done: (mode) =>
              mode.state.accounts.first.lines.any((line) => line.label == "Camera body"),
        ),
        "deleting a line": (
          table: "budget_lines",
          verb: "UPDATE",
          event: (s) => OcptBudgetLineDeletionConfirmedEvent(lineId: s.line),
          done: (mode) => mode.state.accounts.first.lines.isEmpty,
        ),
        "changing the tax basis of a line": (
          table: "budget_lines",
          verb: "UPDATE",
          event: (s) =>
              OcptBudgetLineTaxInclusiveChangedEvent(lineId: s.line, isTaxInclusive: false),
          done: (mode) => !mode.state.accounts.first.lines.single.unitPrice.isTaxInclusive,
        ),
        "putting the VAT rate of a line back to the default": (
          table: "budget_lines",
          verb: "UPDATE",
          event: (s) => OcptBudgetLineVatRateInheritedRequestedEvent(lineId: s.line),
          done: (mode) =>
              mode.state.accounts.first.lines.single.unitPrice.vatRateBasisPoints == null,
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

        seeded.view.add(case_.event(seeded));
        await harness.settle();

        expect(
          harness.state.reloadEpoch,
          held.reloadEpoch,
          reason: "the mode was read again after a failed write",
        );
        expect(harness.state.selection, held.selection);

        await harness.lift(case_.verb, case_.table);
        seeded.view.add(case_.event(seeded));
        await harness.settle();

        expect(case_.done(harness.modeBloc!), isTrue);
      },
    );
  }

  group("flushing the typed edits", () {
    /// Type [value] into [field] of [targetId] and give the view its edit.
    Future<void> type(Seeded seeded, String targetId, OcptBudgetField field, String value) async {
      seeded.view.add(
        OcptBudgetFieldChangedEvent(targetId: targetId, field: field, rawValue: value),
      );
      await harness.settle();
    }

    test("a refused write answers failed, keeps the edit and reads nothing again", () async {
      final seeded = await build();
      await type(seeded, seeded.line, OcptBudgetField.lineLabel, "Renamed");
      final held = harness.state;
      await harness.refuse("UPDATE", "budget_lines");

      final status = await seeded.view.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.failed);
      expect(seeded.view.state.pendingFieldEdits, isNotEmpty);
      expect(harness.state.reloadEpoch, held.reloadEpoch);

      await harness.lift("UPDATE", "budget_lines");

      expect(await seeded.view.flushPendingWrites(), OcptPendingWritesStatus.ok);
      expect(harness.state.accounts.first.lines.single.label, "Renamed");
      expect(seeded.view.state.pendingFieldEdits, isEmpty);
    });

    test("a refused write stops the edits after it", () async {
      final seeded = await build();
      await type(seeded, seeded.firstAccount, OcptBudgetField.accountLabel, "Renamed cast");
      await type(seeded, seeded.line, OcptBudgetField.lineLabel, "Renamed lead");
      await harness.refuse("UPDATE", "budget_postes");

      final status = await seeded.view.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.failed);
      final database = harness.projectsManager.currentProject!.database;
      final row = await database
          .customSelect(
            "SELECT label AS value FROM budget_lines WHERE id = ?",
            variables: [Variable.withString(seeded.line)],
          )
          .getSingle();
      expect(row.read<String>("value"), "Lead");
    });

    test("a refused write leaves the edit to the next flush that has no state", () async {
      final seeded = await build();
      await type(seeded, seeded.line, OcptBudgetField.lineLabel, "Renamed");
      final held = harness.state;
      await harness.refuse("UPDATE", "budget_lines");

      await seeded.view.flushPendingWritesWithoutState();

      expect(harness.state, same(held));
      expect(seeded.view.state.pendingFieldEdits, isNotEmpty);

      await harness.lift("UPDATE", "budget_lines");
      await seeded.view.flushPendingWritesWithoutState();
      await harness.modeBloc!.reload({OcptBudgetReloadScope.snapshot});

      expect(harness.state.accounts.first.lines.single.label, "Renamed");
    });

    test("a write that landed but cannot be read back answers failed", () async {
      final seeded = await build();
      await type(seeded, seeded.line, OcptBudgetField.lineLabel, "Renamed");
      await harness.projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER poison AFTER UPDATE ON budget_lines "
        "BEGIN UPDATE budget_lines SET quantity_milli = 'unreadable'; END",
      );

      expect(await seeded.view.flushPendingWrites(), OcptPendingWritesStatus.failed);
      expect(seeded.view.state.pendingFieldEdits, isNotEmpty);
    });
  });

  group("when the quote cannot be read", () {
    for (final table in ["budget_postes", "budget_lines"]) {
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
