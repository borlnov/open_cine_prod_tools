// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// A quote line's own `Engagé` figure, the expenses tree's own sub-row reading — kept apart from
/// `ocpt_budget_totals.dart` because it reads a **line's own commitments**, a grouping
/// `ocpt_budget_journal.dart`/`ocpt_budget_projection.dart` never need: those two files each read
/// every commitment or every entry of the whole project, grouped by poste, and a line is a poste's
/// own subdivision their own maps carry no key for at all. Everything else the expenses tree's own
/// line row shows — `Devis`, `Reste`, `Coût final`, `Écart` — is answered in full by a function
/// that already exists (`ocptBudgetTotalOf` over the single line, `ocptBudgetRemainingCents`,
/// `ocptBudgetEstimateToCompleteCents`, `ocptBudgetFinalCostCents`, `ocptBudgetVarianceCents`), so
/// this file adds nothing beside [ocptBudgetLineCommittedTotalOf] and its own sibling
/// [ocptBudgetLinePaidTotalOf].
///
/// The tax-inclusive cash total of every **unsettled** commitment in [lineCommitments], honouring
/// the "null, never zero" coverage rule [ocptBudgetCommittedCentsByPosteId] already keeps for a
/// poste — a settled commitment is excluded outright rather than merely counted as zero, for the
/// very same reason: the money it stood for has already left the account and is
/// [ocptBudgetLinePaidTotalOf]'s own figure now, not this one's.
///
/// [lineCommitments] is **every** commitment naming the line, settled or not — this function does
/// its own split, exactly the way `ocptBudgetCommittedCentsByPosteId` takes every commitment
/// naming a poste and does its own: a caller narrows `OcptBudgetSnapshot.commitments` down to one
/// line's own (`commitment.lineId == line.id`) and hands the whole list in, rather than filtering
/// twice over. Reuses [ocptBudgetCommitmentCashCentsOf] rather than re-deriving the tax-inclusive
/// reading, row by row, then summed.
OcptBudgetCoveredTotal ocptBudgetLineCommittedTotalOf(
  List<OcptBudgetCommitment> lineCommitments, {
  required int? projectVatRateBasisPoints,
}) {
  final unsettled = [for (final commitment in lineCommitments) if (!commitment.isSettled) commitment];

  var amountCents = 0;
  var coveredLineCount = 0;
  for (final commitment in unsettled) {
    final cash = ocptBudgetCommitmentCashCentsOf(
      commitment,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (cash == null) {
      continue;
    }

    amountCents += cash;
    coveredLineCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredLineCount,
    lineCount: unsettled.length,
  );
}

/// A quote line's own `Payé` figure: the tax-inclusive debit of the `budget_entries` row that
/// settles each of [lineCommitments]' own **settled** commitments — never an entry read directly,
/// since an entry never names a line, only the commitment it pays
/// (`docs/architecture/budget.md`'s own "a commitment settles by naming the entry that paid it").
///
/// [entries] is searched for each settled commitment's own `OcptBudgetCommitment.settledEntryId`;
/// a commitment whose named entry cannot be found in [entries] — a dangling link, which should not
/// happen — leaves this total covered-but-incomplete rather than silently wrong, exactly as an
/// unreadable rate does. Reuses [ocptBudgetEntryDebitCentsOf] rather than re-deriving the
/// tax-inclusive reading, row by row, then summed.
OcptBudgetCoveredTotal ocptBudgetLinePaidTotalOf(
  List<OcptBudgetCommitment> lineCommitments, {
  required List<OcptBudgetEntry> entries,
  required int? projectVatRateBasisPoints,
}) {
  final settled = [for (final commitment in lineCommitments) if (commitment.isSettled) commitment];

  var amountCents = 0;
  var coveredLineCount = 0;
  for (final commitment in settled) {
    final entry = entries.where((entry) => entry.id == commitment.settledEntryId).firstOrNull;
    if (entry == null) {
      continue;
    }

    final debit = ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints);
    if (debit == null) {
      continue;
    }

    amountCents += debit;
    coveredLineCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredLineCount,
    lineCount: settled.length,
  );
}
