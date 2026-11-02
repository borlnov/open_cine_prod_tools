// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_budget_cnc_accounts.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account_seed.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'ocpt_result_expectations.dart';

/// Seeds the budget quote: the ten CNC accounts and the lines under them.
Future<({String costumesLineId, String Function(String code) accountIdOf})> seedQuote({
  required OcptBudgetQuoteService budgetQuoteService,
  required OcptProjectDatabase database,
}) async {
  // The budget. The ten CNC accounts are seeded by the quote service itself, on this very first
  // read of an empty table — the labels are resolved from `Tr` in the app and written out here,
  // this script having no BuildContext to resolve them against.
  const accountLabels = <String, String>{
    "1": "Artistic rights",
    "2": "Personnel",
    "3": "Cast",
    "4": "Social charges",
    "5": "Sets and costumes",
    "6": "Transport, per diems, logistics",
    "7": "Technical equipment",
    "8": "Laboratory and post-production",
    "9": "Insurance and miscellaneous",
    "10": "Overheads",
  };
  final accounts = await budgetQuoteService
      .loadAccounts(
        database: database,
        seed: [
          for (final account in ocptBudgetCncAccounts)
            OcptBudgetAccountSeed(
              id: account.id,
              code: account.code,
              label: accountLabels[account.code]!,
              simpleLabel: null,
            ),
        ],
      )
      .valueOrFail;
  expect(accounts, hasLength(10));

  String accountIdOf(String code) => accounts.firstWhere((account) => account.code == code).id;

  Future<String> quoteLine(
    String code,
    String label,
    int quantityMilli,
    String unit,
    int unitAmountCents, {
    int? vatRateBasisPoints,
  }) async {
    final lineId = (await budgetQuoteService
        .createLine(
          database: database,
          accountId: accountIdOf(code),
          label: label,
          unitAmountCents: Value(unitAmountCents),
        )
        .valueOrFail);
    await budgetQuoteService
        .updateLine(
          database: database,
          lineId: lineId,
          quantityMilli: Value(quantityMilli),
          unit: Value(unit),
          vatRateBasisPoints: Value(vatRateBasisPoints),
        )
        .okOrFail;

    return lineId;
  }

  await quoteLine("1", "Screenplay rights", 1000, "package", 120000, vatRateBasisPoints: 0);
  await quoteLine("2", "Director of photography", 12000, "day", 25000, vatRateBasisPoints: 0);
  await quoteLine("2", "Sound engineer", 12000, "day", 22000, vatRateBasisPoints: 0);
  await quoteLine("3", "Nora", 12000, "day", 30000, vatRateBasisPoints: 0);
  await quoteLine("3", "Martin", 8000, "day", 30000, vatRateBasisPoints: 0);
  await quoteLine("4", "Employer contributions", 1000, "package", 240000, vatRateBasisPoints: 0);
  final costumesLineId = await quoteLine(
    "5",
    "Period costumes",
    1000,
    "package",
    180000,
    vatRateBasisPoints: 2000,
  );
  await quoteLine(
    "5",
    "Set dressing — the lighthouse",
    1000,
    "package",
    95000,
    vatRateBasisPoints: 2000,
  );
  await quoteLine("6", "Boat charter", 3000, "day", 48000, vatRateBasisPoints: 2000);
  await quoteLine("7", "Camera package", 12000, "day", 39000, vatRateBasisPoints: 2000);
  await quoteLine("8", "Colour grading", 4000, "day", 55000, vatRateBasisPoints: 2000);
  await quoteLine("8", "Sound mix", 3000, "day", 40000, vatRateBasisPoints: 2000);
  await quoteLine("9", "Production insurance", 1000, "package", 85000, vatRateBasisPoints: 2000);
  await quoteLine("10", "Office and telephone", 1000, "package", 60000, vatRateBasisPoints: 2000);

  return (costumesLineId: costumesLineId, accountIdOf: accountIdOf);
}

/// Seeds the financing plan, the commitments and the cash journal.
Future<void> seedFinancing({
  required OcptBudgetFinancingService budgetFinancingService,
  required OcptBudgetJournalService budgetJournalService,
  required OcptBudgetSharingService budgetSharingService,
  required String costumesLineId,
  required OcptProjectDatabase database,
  required String Function(String code) accountIdOf,
}) async {
  // The financing plan. One contribution is reimbursable out of the takings, which is what the
  // sharing view puts before any split at all.
  Future<String> resource(
    OcptBudgetResourceGroupKind groupKind,
    String label,
    int amountCents,
    OcptBudgetResourceStatus status, {
    bool isReimbursable = false,
  }) async {
    final id = (await budgetFinancingService
        .createResource(database: database, label: label)
        .valueOrFail);
    await budgetFinancingService
        .updateResource(
          database: database,
          resourceId: id,
          groupKind: Value(groupKind),
          amountCents: Value(amountCents),
          status: Value(status),
          isReimbursable: Value(isReimbursable),
        )
        .okOrFail;

    return id;
  }

  await resource(
    OcptBudgetResourceGroupKind.subsidy,
    "Regional production fund",
    800000,
    OcptBudgetResourceStatus.confirmed,
  );
  final ownContribution = await resource(
    OcptBudgetResourceGroupKind.cash,
    "The production's own contribution",
    350000,
    OcptBudgetResourceStatus.confirmed,
    isReimbursable: true,
  );
  await resource(
    OcptBudgetResourceGroupKind.inKind,
    "Harbour office lent for the shoot",
    120000,
    OcptBudgetResourceStatus.agreed,
  );

  // What is ordered but not yet paid. One is settled by the entry below it, so the expenses tree
  // reads a whole line → commitment → payment chain; the other two are still owed, which is what
  // the cash-flow page's own upcoming section and its projection read.
  final costumesCommitmentId = (await budgetJournalService
      .createCommitment(
        database: database,
        accountId: accountIdOf("5"),
        lineId: costumesLineId,
        label: "Maison Couronne — period costumes",
        dueDate: DateTime.utc(2026, 9, 20),
        amountCents: 180000,
        vatRateBasisPoints: 2000,
        status: OcptBudgetCommitmentStatus.invoiceReceived,
      )
      .valueOrFail);
  await budgetJournalService
      .createCommitment(
        database: database,
        accountId: accountIdOf("7"),
        label: "Camera package, second week",
        dueDate: DateTime.utc(2026, 9, 30),
        amountCents: 117000,
        vatRateBasisPoints: 2000,
      )
      .maybeValueOrFail;
  await budgetJournalService
      .createCommitment(
        database: database,
        accountId: accountIdOf("8"),
        label: "Studio Lumière — colour grading",
        dueDate: DateTime.utc(2026, 11, 16),
        amountCents: 220000,
        vatRateBasisPoints: 2000,
        status: OcptBudgetCommitmentStatus.contractSigned,
      )
      .maybeValueOrFail;

  // The cash journal, including the credit that makes the reimbursable contribution received.
  await budgetJournalService
      .createEntry(
        database: database,
        date: DateTime.utc(2026, 8, 14),
        label: "The production's own contribution paid in",
        creditCents: 350000,
        resourceId: ownContribution,
      )
      .maybeValueOrFail;
  await budgetJournalService
      .createEntry(
        database: database,
        date: DateTime.utc(2026, 9, 2),
        label: "Camera package, first week",
        accountId: accountIdOf("7"),
        debitCents: 117000,
        vatRateBasisPoints: 2000,
      )
      .maybeValueOrFail;
  await budgetJournalService
      .createEntry(
        database: database,
        date: DateTime.utc(2026, 9, 8),
        label: "Boat charter",
        accountId: accountIdOf("6"),
        debitCents: 144000,
        vatRateBasisPoints: 2000,
      )
      .maybeValueOrFail;
  await budgetJournalService
      .createEntry(
        database: database,
        date: DateTime.utc(2026, 9, 20),
        label: "Maison Couronne — period costumes",
        accountId: accountIdOf("5"),
        commitmentId: costumesCommitmentId,
        debitCents: 180000,
        vatRateBasisPoints: 2000,
      )
      .maybeValueOrFail;

  // The premium came in above the line quoted for it, so account 9 reads over its own quote — the
  // one standing alert the demonstration project raises, and the reason the dashboard has an
  // alerts card to draw at all.
  await budgetJournalService
      .createEntry(
        database: database,
        date: DateTime.utc(2026, 8, 28),
        label: "Production insurance — annual premium",
        accountId: accountIdOf("9"),
        debitCents: 102000,
        vatRateBasisPoints: 2000,
      )
      .maybeValueOrFail;

  // The takings, and what each of them has actually brought in.
  Future<String> revenue(
    DateTime date,
    String label,
    int amountCents,
    OcptBudgetRevenueStatus status,
  ) async {
    final id = await budgetSharingService
        .createRevenue(database: database, date: date, label: label)
        .valueOrFail;
    await budgetSharingService
        .updateRevenue(
          database: database,
          revenueId: id,
          amountCents: Value(amountCents),
          status: Value(status),
        )
        .okOrFail;

    return id;
  }

  final prize = await revenue(
    DateTime.utc(2027, 2, 2),
    "Clermont-Ferrand — audience award",
    300000,
    OcptBudgetRevenueStatus.confirmed,
  );
  final broadcast = await revenue(
    DateTime.utc(2027, 3, 18),
    "Regional distribution grant",
    220000,
    OcptBudgetRevenueStatus.confirmed,
  );
  await revenue(
    DateTime.utc(2027, 5, 30),
    "Television pre-buy — short film slot",
    100000,
    OcptBudgetRevenueStatus.invoiced,
  );

  await budgetJournalService
      .createEntry(
        database: database,
        date: DateTime.utc(2027, 2, 2),
        label: "Audience award paid in",
        creditCents: 300000,
        revenueId: prize,
      )
      .maybeValueOrFail;
  await budgetJournalService
      .createEntry(
        database: database,
        date: DateTime.utc(2027, 3, 18),
        label: "Distribution grant paid in",
        creditCents: 220000,
        revenueId: broadcast,
      )
      .maybeValueOrFail;
}

/// Seeds the revenue sharing: the takings and the shares that split them.
Future<void> seedSharing({
  required OcptBudgetJournalService budgetJournalService,
  required OcptBudgetSharingService budgetSharingService,
  required OcptProjectDatabase database,
}) async {
  // The split. The shares deliberately add up to exactly 1000 per mille here, so the
  // demonstration project shows a plan that balances; the view states the sum whenever one does
  // not.
  Future<String> share(String label, int sharePermille, int reinvestPermille) async {
    final id = await budgetSharingService.createShare(database: database, label: label).valueOrFail;
    await budgetSharingService
        .updateShare(
          database: database,
          shareId: id,
          sharePermille: Value(sharePermille),
          reinvestPermille: Value(reinvestPermille),
        )
        .okOrFail;

    return id;
  }

  await share("Director", 400, 1000);
  await share("Production", 250, 0);
  await share("Director of photography", 150, 0);
  await share("Nora", 100, 0);
  final editor = await share("Editor", 100, 500);

  await budgetJournalService
      .createEntry(
        database: database,
        date: DateTime.utc(2027, 6, 12),
        label: "Editor's share, first instalment",
        debitCents: 8000,
        shareId: editor,
      )
      .maybeValueOrFail;
}
