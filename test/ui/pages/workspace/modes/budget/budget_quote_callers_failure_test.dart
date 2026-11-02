// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_provision_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_financing_bloc.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'budget_write_failure_test_doubles.dart';

/// What the budget does when the database refuses a write of the quote that a financing or a cash
/// journal handler makes beside its own: the handler stops where the exception stopped it, nothing
/// is read again, and the same event goes through once the refusal is lifted.
void main() {
  final harness = BudgetFailureHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// The fields of an in-kind contribution balanced in account [accountId].
  OcptBudgetResourceFormFields inKind(String accountId, String label) =>
      OcptBudgetResourceFormFields(
        groupKind: OcptBudgetResourceGroupKind.inKind,
        personId: null,
        label: label,
        amountCents: 40000,
        status: OcptBudgetResourceStatus.agreed,
        isReimbursable: false,
        notes: "",
        accountId: accountId,
      );

  /// Seed an account, build the mode on it and give back the financing view and the account id.
  Future<(OcptBudgetFinancingBloc, String)> buildFinancing() async {
    final database = harness.projectsManager.currentProject!.database;
    final accountId = await harness.projectsManager.budgetQuoteService
        .createAccount(database: database, label: "Camera")
        .valueOrFail;
    final mode = await harness.buildBloc();
    final view = OcptBudgetFinancingBloc(modeBloc: mode, projectsManager: harness.projectsManager);
    addTearDown(view.close);
    await harness.settle();

    return (view, accountId);
  }

  /// Tell whether the mode holds an in-kind line balancing a resource called [label].
  bool hasCounterpart(OcptBudgetBloc mode, String label) => mode.state.accounts.any(
    (account) => account.lines.any((line) => line.inKindResourceId != null && line.label == label),
  );

  group("the financing view", () {
    test("a provisioning that cannot be written stops, and goes through once lifted", () async {
      final (view, accountId) = await buildFinancing();
      final held = harness.state;
      await harness.refuse("INSERT", "budget_lines");

      void provision() => view.add(
        OcptBudgetProvisionConfirmedEvent(
          accountId: accountId,
          entries: const [
            OcptBudgetProvisionEntry(
              kind: OcptBudgetProvisionKind.meal,
              lineId: null,
              label: "Meals",
              quantityMilli: 4000,
              unitAmountCents: 1200,
              outcome: OcptBudgetProvisionOutcome.created,
            ),
          ],
        ),
      );
      provision();
      await harness.settle();

      expect(harness.state.reloadEpoch, held.reloadEpoch);

      await harness.lift("INSERT", "budget_lines");
      provision();
      await harness.settle();

      expect(harness.state.accounts.first.lines.any((line) => line.label == "Meals"), isTrue);
    });

    test("creating an in-kind resource stops when its counterpart line is refused", () async {
      final (view, accountId) = await buildFinancing();
      final held = harness.state;
      await harness.refuse("INSERT", "budget_lines");

      view.add(OcptBudgetResourceCreationConfirmedEvent(fields: inKind(accountId, "Camera loan")));
      await harness.settle();

      expect(harness.state.reloadEpoch, held.reloadEpoch);
      expect(harness.state.selection, held.selection);

      await harness.lift("INSERT", "budget_lines");
      view.add(OcptBudgetResourceCreationConfirmedEvent(fields: inKind(accountId, "Camera loan")));
      await harness.settle();

      expect(hasCounterpart(harness.modeBloc!, "Camera loan"), isTrue);
    });

    test("updating an in-kind resource stops when its counterpart line is refused", () async {
      final (view, accountId) = await buildFinancing();
      view.add(OcptBudgetResourceCreationConfirmedEvent(fields: inKind(accountId, "Camera loan")));
      await harness.settle();
      final resourceId = harness.state.resources.single.id;
      final held = harness.state;
      await harness.refuse("UPDATE", "budget_lines");

      view.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId,
          fields: inKind(accountId, "Camera lent"),
        ),
      );
      await harness.settle();

      expect(harness.state.reloadEpoch, held.reloadEpoch);

      await harness.lift("UPDATE", "budget_lines");
      view.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId,
          fields: inKind(accountId, "Camera lent"),
        ),
      );
      await harness.settle();

      expect(hasCounterpart(harness.modeBloc!, "Camera lent"), isTrue);
    });

    test("deleting an in-kind resource stops when its counterpart line is refused", () async {
      final (view, accountId) = await buildFinancing();
      view.add(OcptBudgetResourceCreationConfirmedEvent(fields: inKind(accountId, "Camera loan")));
      await harness.settle();
      final resourceId = harness.state.resources.single.id;
      final held = harness.state;
      await harness.refuse("UPDATE", "budget_lines");

      view.add(OcptBudgetResourceDeletionConfirmedEvent(resourceId: resourceId));
      await harness.settle();

      expect(harness.state.reloadEpoch, held.reloadEpoch);

      await harness.lift("UPDATE", "budget_lines");
      view.add(OcptBudgetResourceDeletionConfirmedEvent(resourceId: resourceId));
      await harness.settle();

      expect(harness.state.resources, isEmpty);
      expect(hasCounterpart(harness.modeBloc!, "Camera loan"), isFalse);
    });

    test("changing an in-kind resource to another account stops on the line it deletes", () async {
      final (view, accountId) = await buildFinancing();
      final otherAccountId = await harness.projectsManager.budgetQuoteService
          .createAccount(
            database: harness.projectsManager.currentProject!.database,
            label: "Lighting",
          )
          .valueOrFail;
      await harness.modeBloc!.reload({OcptBudgetReloadScope.snapshot});
      view.add(OcptBudgetResourceCreationConfirmedEvent(fields: inKind(accountId, "Camera loan")));
      await harness.settle();
      final resourceId = harness.state.resources.single.id;
      final held = harness.state;
      await harness.refuse("UPDATE", "budget_lines");

      view.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId,
          fields: inKind(otherAccountId, "Camera loan"),
        ),
      );
      await harness.settle();

      expect(harness.state.reloadEpoch, held.reloadEpoch);
      expect(harness.state.accounts.last.lines, isEmpty, reason: "no line was minted after it");
    });
  });

  group("the cash journal view", () {
    /// Seed an account, build the mode and the cash journal view over it, and create an off-line
    /// debit entry and an off-line commitment in that account.
    Future<OcptBudgetCashJournalBloc> buildJournal() async {
      final database = harness.projectsManager.currentProject!.database;
      final accountId = await harness.projectsManager.budgetQuoteService
          .createAccount(database: database, label: "Camera")
          .valueOrFail;
      final mode = await harness.buildBloc();
      final view = OcptBudgetCashJournalBloc(
        modeBloc: mode,
        projectsManager: harness.projectsManager,
      );
      addTearDown(view.close);
      view.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: DateTime(2026, 3),
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
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
      view.add(
        OcptBudgetCommitmentCreationConfirmedEvent(
          fields: OcptBudgetCommitmentFormFields(
            dueDate: DateTime(2026, 6),
            label: "Deposit",
            accountId: accountId,
            amountCents: 5000,
            isTaxInclusive: true,
            vatRateBasisPoints: null,
            status: OcptBudgetCommitmentStatus.quoteAccepted,
          ),
        ),
      );
      await harness.settle();

      return view;
    }

    test("promoting an entry to the quote stops when the line is refused", () async {
      final view = await buildJournal();
      final entryId = harness.state.entries.single.id;
      final held = harness.state;
      await harness.refuse("INSERT", "budget_lines");

      view.add(OcptBudgetEntryPromotedToQuoteEvent(entryId: entryId));
      await harness.settle();

      expect(harness.state.reloadEpoch, held.reloadEpoch);
      expect(harness.state.commitments, held.commitments, reason: "no commitment was made");

      await harness.lift("INSERT", "budget_lines");
      view.add(OcptBudgetEntryPromotedToQuoteEvent(entryId: entryId));
      await harness.settle();

      expect(harness.state.entries.single.commitmentId, isNotNull);
    });

    test("promoting a commitment to the quote stops when the line is refused", () async {
      final view = await buildJournal();
      final commitmentId = harness.state.commitments.single.id;
      final held = harness.state;
      await harness.refuse("INSERT", "budget_lines");

      view.add(OcptBudgetCommitmentPromotedToQuoteEvent(commitmentId: commitmentId));
      await harness.settle();

      expect(harness.state.reloadEpoch, held.reloadEpoch);

      await harness.lift("INSERT", "budget_lines");
      view.add(OcptBudgetCommitmentPromotedToQuoteEvent(commitmentId: commitmentId));
      await harness.settle();

      expect(harness.state.commitments.single.lineId, isNotNull);
    });
  });
}
