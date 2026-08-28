// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_allowances.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// What a defrayed person has actually advanced, been reimbursed, and is still owed — the régie's
/// own running account, read the very same way every other document in this mode already reads
/// what has moved: summed off the rows that name the person, never a stored counter kept in step
/// by hand.
///
/// **What a person has advanced is typed, what they have been reimbursed is summed off the
/// journal.** `budget_allowances` is what a production types row by row
/// (`OcptBudgetAllowancesTable`'s own doc comment argues why nothing here is deduced from the
/// schedule), and [ocptBudgetPersonAdvancedCents] simply totals it, through
/// [ocptBudgetAllowanceCentsOf], for one person. What they have been paid back is a different
/// ledger entirely — `budget_entries`, through its own [OcptBudgetEntry.personId] — read exactly
/// the way `ocptBudgetPaidByCommitmentId` (`lib/utils/ocpt_budget_projection.dart`) reads what has
/// been paid against a commitment: **only [OcptBudgetEntry.debitCents] is read**, a reimbursement
/// being money leaving the account, never a credit naming the person, and **a person no entry
/// names has no key at all** in [ocptBudgetReimbursedByPersonId], the same "nothing has moved" /
/// "something moved, netting to zero" distinction every other grouping in this mode keeps.
///
/// A defrayal carries no money triple of its own (`OcptBudgetAllowancesTable`'s own doc comment):
/// [ocptBudgetAllowanceAmountCents] already turns [OcptBudgetAllowance.quantityMilli] and
/// [OcptBudgetAllowance.unitAmountMilliCents] into a plain amount that needs no VAT rate at all, so
/// [ocptBudgetPersonAdvancedCents] answers a plain `int`, never an [OcptBudgetCoveredTotal] — there
/// is nothing here that could be incomplete. What has been reimbursed, by contrast, is read off
/// `budget_entries`, which does carry the money triple, so it keeps the "null, never zero"
/// discipline every other journal reading in this mode does.

/// What has been reimbursed against each defrayed person, given the project's own
/// [projectVatRateBasisPoints]: per person, the tax-inclusive sum of every `budget_entries` debit
/// naming them through `budget_entries.personId`.
///
/// Mirrors `ocptBudgetPaidByCommitmentId` (`lib/utils/ocpt_budget_projection.dart`) precisely — see
/// this file's own doc comment for the argument and for why a credit naming a person is not
/// subtracted here.
Map<String, OcptBudgetCoveredTotal> ocptBudgetReimbursedByPersonId(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  final entriesByPersonId = <String, List<OcptBudgetEntry>>{};
  for (final entry in entries) {
    final personId = entry.personId;
    if (personId == null) {
      continue;
    }

    entriesByPersonId.putIfAbsent(personId, () => []).add(entry);
  }

  return {
    for (final personEntries in entriesByPersonId.entries)
      personEntries.key: _ocptBudgetReimbursedTotalOf(
        personEntries.value,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      ),
  };
}

/// [entries]' own reimbursed total against one person — the tax-inclusive sum of every debit, row
/// by row, then summed — paired with how many of them actually carried a known rate. The one
/// person-scoped loop [ocptBudgetReimbursedByPersonId] runs once per person, kept separate so that
/// function stays a plain grouping followed by one reading per group, exactly the shape
/// `_ocptBudgetCommitmentPaidTotalOf` (`lib/utils/ocpt_budget_projection.dart`) already keeps for a
/// commitment.
OcptBudgetCoveredTotal _ocptBudgetReimbursedTotalOf(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  var amountCents = 0;
  var coveredEntryCount = 0;

  for (final entry in entries) {
    final debit = ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints);
    if (debit == null) {
      continue;
    }

    amountCents += debit;
    coveredEntryCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredEntryCount,
    lineCount: entries.length,
  );
}

/// [personId]'s own reimbursed total, read off [entries] — [ocptBudgetReimbursedByPersonId] narrowed
/// to this one person, doing its own narrowing rather than asking every caller to group [entries]
/// itself first, exactly the reason `ocptBudgetCommitmentPaidCentsOf`
/// (`lib/utils/ocpt_budget_projection.dart`) does its own.
OcptBudgetCoveredTotal ocptBudgetPersonReimbursedCentsOf(
  String personId,
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) => _ocptBudgetReimbursedTotalOf(
  [for (final entry in entries) if (entry.personId == personId) entry],
  projectVatRateBasisPoints: projectVatRateBasisPoints,
);

/// What [personId] has advanced, across every one of [allowances] naming them — the plain sum of
/// [ocptBudgetAllowanceAmountCents], needing no VAT rate at all: see this file's own doc comment for
/// why a defrayal answers a plain amount rather than an [OcptBudgetCoveredTotal].
int ocptBudgetPersonAdvancedCents(String personId, List<OcptBudgetAllowance> allowances) =>
    allowances
        .where((allowance) => allowance.personId == personId)
        .fold(0, (sum, allowance) => sum + ocptBudgetAllowanceCentsOf(allowance));

/// What is still owed to a person who has advanced [advancedCents] and been reimbursed
/// [reimbursedCents].
///
/// **Not clamped at zero**, for the reason `ocptBudgetResourceOutstandingCents`
/// (`lib/utils/ocpt_budget_financing.dart`) is not: a reimbursement can overshoot what was actually
/// advanced, and clamping that away would erase exactly the fact a reader most wants from this
/// figure — that this person has been paid back more than they put in, not merely paid back in
/// full.
int ocptBudgetPersonOutstandingCents({required int advancedCents, required int reimbursedCents}) =>
    advancedCents - reimbursedCents;
