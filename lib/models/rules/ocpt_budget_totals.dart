// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_account_strain.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';

/// How many thousandths make up one whole unit: what turns `quantityMilli` (1500 for 1.5 day) back
/// into a plain multiplier.
const int _ocptQuantityMilliPerUnit = 1000;

/// The ratio, above which an account is flagged **near** its quote rather than merely **within** it
/// — 90 %, the figure [ocptBudgetAccountStrainOf]'s own strain reading is drawn at.
const double _ocptBudgetNearStrainRatio = 0.9;

/// Get [line]'s own total, in cents, in whatever tax basis it was typed in — never converted:
/// `quantityMilli × unitAmountCents ÷ 1000`, rounded to the nearest cent.
int ocptBudgetLineTotalCents(OcptBudgetLine line) =>
    (line.quantityMilli * line.unitPrice.amountCents / _ocptQuantityMilliPerUnit).round();

/// Get [line]'s own total **excluding tax**, in cents, given the project's own
/// [projectVatRateBasisPoints] — or null when that figure cannot be known, exactly as
/// `ocptExcludingTaxAmountCentsOf` reads for a single amount.
///
/// Computed by converting [ocptBudgetLineTotalCents] itself, at the line's own basis and rate,
/// rather than converting the unit price and then multiplying: a rate conversion is linear, so the
/// two commute, and going through the already-summed total is what lets
/// [ocptBudgetExcludingTaxTotalOf] below sum a table **row by row and then convert**, never the
/// other way round.
int? ocptBudgetLineExcludingTaxTotalCents(
  OcptBudgetLine line, {
  required int? projectVatRateBasisPoints,
}) => ocptExcludingTaxAmountCentsOf(
  OcptMoney(
    amountCents: ocptBudgetLineTotalCents(line),
    isTaxInclusive: line.unitPrice.isTaxInclusive,
    vatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
  ),
  projectVatRateBasisPoints: projectVatRateBasisPoints,
);

/// Get [account]'s quoted total, in cents, in the tax-inclusive-as-typed basis: the sum of
/// [ocptBudgetLineTotalCents] over its own [OcptBudgetAccount.lines].
///
/// **Row by row, then summed** — never the other way round: `OcptBudgetAccountsTable`'s own doc
/// comment is why this is computed rather than read off a stored column, and computing it any other
/// order would let a rounding at the account level disagree, by a cent, with the sum a reader gets
/// by adding the lines up themselves.
int ocptBudgetAccountQuotedTotalCents(OcptBudgetAccount account) =>
    account.lines.fold(0, (sum, line) => sum + ocptBudgetLineTotalCents(line));

/// Get the whole project's quoted total, in cents: the sum of [ocptBudgetAccountQuotedTotalCents]
/// over
/// [accounts] — row by row, account by account, then summed, for the same reason that method is.
int ocptBudgetProjectQuotedTotalCents(List<OcptBudgetAccount> accounts) =>
    accounts.fold(0, (sum, account) => sum + ocptBudgetAccountQuotedTotalCents(account));

/// Get what each account has settled **in kind**, keyed by `OcptBudgetAccount.id`: the sum of
/// [ocptBudgetLineTotalCents] over its own lines whose [OcptBudgetLine.inKindResourceId] is not
/// null — a counterpart line minted to balance an in-kind contribution
/// (`docs/architecture/budget.md`, "A balanced in-kind contribution"). This is the settled-in-kind
/// twin of `ocptBudgetPaidCentsByAccountId` (`lib/models/rules/ocpt_budget_journal.dart`): the same
/// reading, over the quote's own counterpart lines rather than over the journal's own entries.
///
/// **An account with no such line has no key in the map** — mirroring
/// `ocptBudgetPaidCentsByAccountId`'s own "no key for nothing" discipline: a caller can tell "no
/// in-kind line settles this account" apart from "one does, and it happens to total zero" (which
/// cannot actually occur here, since a counterpart line is always minted at the contribution's own
/// non-zero valuation, but the discipline is kept anyway, for the same reason every other
/// per-account map in this file keeps it).
///
/// **A plain `int`, not an [OcptBudgetCoveredTotal], and no `projectVatRateBasisPoints` parameter**
/// — unlike every other reading in this file that sums money moved. A counterpart line is **frozen
/// at 0 % VAT** (`OcptBudgetLine.unitPrice.vatRateBasisPoints`), an explicit "no VAT applies"
/// rather than a null inheriting the project's own rate, precisely so its typed total reads the
/// same whichever tax basis the header is on — there is no rate to be missing, so there is nothing
/// for [OcptBudgetCoveredTotal.isComplete] to ever say about it, and no basis to convert by.
///
/// Takes [accounts] with their own lines already loaded, exactly as
/// [ocptBudgetAccountQuotedTotalCents] does — this file does no database access of its own.
Map<String, int> ocptBudgetInKindCoveredCentsByAccountId(List<OcptBudgetAccount> accounts) {
  final coveredCentsByAccountId = <String, int>{};

  for (final account in accounts) {
    final counterpartLines = account.lines.where((line) => line.inKindResourceId != null);
    if (counterpartLines.isEmpty) {
      continue;
    }

    coveredCentsByAccountId[account.id] = counterpartLines.fold(
      0,
      (sum, line) => sum + ocptBudgetLineTotalCents(line),
    );
  }

  return coveredCentsByAccountId;
}

/// Get the counterpart quote line balancing in-kind contribution [resourceId] — the one line,
/// across
/// every account, whose [OcptBudgetLine.inKindResourceId] names it — or null while it has none: an
/// ordinary contribution not (or not yet) in kind, or one whose line has not been minted.
///
/// **There is always at most one.** `OcptBudgetFinancingService`'s own in-kind
/// reconciliation keeps exactly one counterpart line per in-kind contribution in step across
/// every edit, so this never has more than one match to choose between — see
/// `docs/architecture/budget.md`, "A balanced in-kind contribution", for the single-line invariant.
///
/// Takes [accounts] with their own lines already loaded, exactly as
/// [ocptBudgetInKindCoveredCentsByAccountId] does — this file does no database access of its own,
/// and both the mode's own resource detail panel/dialog (reading the account a contribution
/// offsets) and the mode's own views share this one lookup.
OcptBudgetLine? ocptBudgetInKindCounterpartLineOf(
  List<OcptBudgetAccount> accounts,
  String resourceId,
) {
  for (final account in accounts) {
    for (final line in account.lines) {
      if (line.inKindResourceId == resourceId) {
        return line;
      }
    }
  }

  return null;
}

/// Get [totals]' own combined figure — the sum of every [OcptBudgetCoveredTotal.amountCents],
/// paired
/// with how many of the underlying rows actually carried a known rate: a plain reduction over
/// already-computed pure structures, not a rule of its own.
///
/// Shared by every reading that folds more than one [OcptBudgetCoveredTotal] into one grand
/// total — the cost-tracking table's own total row, folding the per-account `Paid` totals and the
/// off-quote total (`lib/models/rules/ocpt_budget_journal.dart`'s own
/// `ocptBudgetOffQuotePaidTotalOf`) into its own `Paid` cell, among the other readings that fold
/// more than one of these together.
OcptBudgetCoveredTotal ocptBudgetCoveredTotalsFoldOf(Iterable<OcptBudgetCoveredTotal> totals) {
  var amountCents = 0;
  var coveredLineCount = 0;
  var lineCount = 0;

  for (final total in totals) {
    amountCents += total.amountCents;
    coveredLineCount += total.coveredLineCount;
    lineCount += total.lineCount;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredLineCount,
    lineCount: lineCount,
  );
}

/// Get the excluding-tax total of [lines], given the project's own [projectVatRateBasisPoints],
/// paired
/// with how many of them that figure actually covers.
///
/// **Row by row, then summed** — [ocptBudgetLineExcludingTaxTotalCents] is computed for each line
/// individually before the covered ones are added together, so a table mixing tax-inclusive and
/// tax-exclusive lines, or lines at different rates, still totals correctly: converting a summed
/// tax-inclusive total by a single rate would silently assume every line shared it.
OcptBudgetCoveredTotal ocptBudgetExcludingTaxTotalOf(
  List<OcptBudgetLine> lines, {
  required int? projectVatRateBasisPoints,
}) {
  var amountCents = 0;
  var coveredLineCount = 0;

  for (final line in lines) {
    final excludingTax = ocptBudgetLineExcludingTaxTotalCents(
      line,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (excludingTax == null) {
      continue;
    }

    amountCents += excludingTax;
    coveredLineCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredLineCount,
    lineCount: lines.length,
  );
}

/// Get what is left of an account quoted at [quotedAmountCents], having paid [paidCents], committed
/// [committedCents] and settled [inKindCoveredCents] against it — negative once the account has
/// gone over its quote.
///
/// [inKindCoveredCents] — [ocptBudgetInKindCoveredCentsByAccountId]'s own per-account figure — is
/// folded in **alongside** [paidCents] and [committedCents], not into either: a counterpart line
/// adds equally to the account's own quote ([ocptBudgetAccountQuotedTotalCents] already counts it,
/// being a real quote line) and to this settled side, so it nets to no remainder rather than
/// reading as an unspent one. It is kept a separate parameter, rather than folded into [paidCents]
/// before this is called, precisely so it never reaches a **cash** reading — see
/// `ocptBudgetPaidCentsByAccountId`/`OcptBudgetCashTotals.balanceCents`, which never see it.
///
/// [paidCents], [committedCents] and [inKindCoveredCents] are **parameters, not reads of their
/// own**: this file stays free of any database access, exactly like every other one under
/// `lib/models/rules/` — reading `budget_entries`, `budget_commitments` and the quote's own
/// counterpart lines (`lib/models/rules/ocpt_budget_journal.dart`,
/// `lib/models/rules/ocpt_budget_projection.dart`, this file's own
/// [ocptBudgetInKindCoveredCentsByAccountId]) into the per-account totals a caller hands in here is
/// the mode's own job (`OcptBudgetSnapshot.build`).
int ocptBudgetRemainingCents({
  required int quotedAmountCents,
  required int paidCents,
  required int committedCents,
  required int inKindCoveredCents,
}) => quotedAmountCents - paidCents - committedCents - inKindCoveredCents;

/// Tell how far an account quoted at [quotedAmountCents] sits from what has actually moved against
/// it —
/// [paidCents] plus [committedCents] plus [inKindCoveredCents], minus the quote. Positive once the
/// account has gone over, negative while it still has room: [ocptBudgetRemainingCents]'s own figure
/// with the sign read the other way round, for the financial report's "quoted vs. actual" reading
/// rather than the cost-tracking table's own `Reste` "what is left" one.
///
/// [inKindCoveredCents] is folded in for the same reason [ocptBudgetRemainingCents] folds it in —
/// see that function's own doc comment.
int ocptBudgetVarianceCents({
  required int quotedAmountCents,
  required int paidCents,
  required int committedCents,
  required int inKindCoveredCents,
}) => paidCents + committedCents + inKindCoveredCents - quotedAmountCents;

/// Get what is still expected to be spent on an account quoted at [quotedAmountCents] beyond what
/// has already been [paidCents], [committedCents] and [inKindCoveredCents] against it.
///
/// [typedEstimateToCompleteCents] **is** the answer, verbatim, whenever it is non-null: a human has
/// adjusted the figure, and this util never second-guesses a typed one. While it is null the answer
/// is derived, and the derived figure is exactly `max(0, ocptBudgetRemainingCents(...))` —
/// [ocptBudgetRemainingCents] is already the "what is left" reading, so this restates it rather
/// than re-deriving the subtraction. Clamped at zero because an account already over its quote has
/// nothing left to *expect* spending, not a negative expectation.
///
/// **Not the same reading as [ocptBudgetVarianceCents]**, which sits a few lines above and answers
/// `paid + committed − quote` — what has already moved, against the plan. This one asks what is
/// still to come. See [ocptBudgetFinalCostVarianceCents] for the two readings meeting again, this
/// time both against a final cost rather than against the quote directly.
///
/// [quotedAmountCents], [paidCents], [committedCents] and [inKindCoveredCents] are **parameters,
/// not reads of their own** — this file stays free of any database access, exactly as
/// [ocptBudgetRemainingCents] already is, and the figures are assumed already resolved in whichever
/// tax basis the caller's own header asks for ([ocptBudgetTotalOf]'s own reading of the quote):
/// there is no basis parameter here, and no reach into `ocpt_budget_vat.dart`, for the same reason
/// [ocptBudgetRemainingCents]
/// and [ocptBudgetVarianceCents] beside it take no basis either. The "null, never zero" coverage
/// discipline lives one level up, in the [OcptBudgetCoveredTotal] that produced the figure a caller
/// hands in here — not in this plain arithmetic, which is why this function neither takes nor
/// returns one.
int ocptBudgetEstimateToCompleteCents({
  required int quotedAmountCents,
  required int paidCents,
  required int committedCents,
  required int inKindCoveredCents,
  required int? typedEstimateToCompleteCents,
}) {
  if (typedEstimateToCompleteCents != null) {
    return typedEstimateToCompleteCents;
  }

  return math.max(
    0,
    ocptBudgetRemainingCents(
      quotedAmountCents: quotedAmountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      inKindCoveredCents: inKindCoveredCents,
    ),
  );
}

/// Get the whole of what an account is now expected to have cost by the end: [paidCents] plus
/// [committedCents] plus [estimateToCompleteCents].
///
/// [estimateToCompleteCents] is taken **already resolved** — [ocptBudgetEstimateToCompleteCents]
/// called once, by the caller, rather than resolved again in here — so a caller can never
/// accidentally hand the typed figure to one call and the derived one to another: there is exactly
/// one place in the caller's own code where "derived or typed?" is decided.
int ocptBudgetFinalCostCents({
  required int paidCents,
  required int committedCents,
  required int estimateToCompleteCents,
}) => paidCents + committedCents + estimateToCompleteCents;

/// Tell how far an account quoted at [quotedAmountCents] sits from [finalCostCents], the whole of
/// what it
/// is now expected to have cost by the end ([ocptBudgetFinalCostCents]). Positive once the account
/// is expected to end over its quote, negative while it is expected to come in under.
///
/// **Read the name carefully — this is not [ocptBudgetVarianceCents].** That one already exists,
/// reads `paid + committed − quote`, and is what the header's alerts band and the financial report
/// PDF print today; it stays exactly as it is and keeps every one of its callers. This one reads
/// against the final cost instead, which includes the estimate to complete — a **different fact**,
/// not a second way of stating the same one. The two happen to agree whenever the account is over
/// its quote and the estimate is left to derive itself, since a derived estimate is then zero and
/// [finalCostCents] collapses to `paid + committed`; and this one reads zero whenever the account
/// is not over its quote and the estimate is derived, since a derived estimate then makes
/// [finalCostCents] equal the quote exactly. That collapse is exactly why a human has to be able to
/// type the estimate to complete: only then does this column say anything [ocptBudgetVarianceCents]
/// does not.
int ocptBudgetFinalCostVarianceCents({
  required int quotedAmountCents,
  required int finalCostCents,
}) => finalCostCents - quotedAmountCents;

/// Tell how much of an account quoted at [quotedAmountCents] has been consumed by [paidCents] plus
/// [committedCents] plus [inKindCoveredCents], as a ratio (`1.0` meaning exactly on quote) — or
/// null when the account carries no quote at all ([quotedAmountCents] zero), where a ratio would be
/// a division by zero rather than a figure.
///
/// [inKindCoveredCents] is folded into the consumed side for the same reason
/// [ocptBudgetRemainingCents] folds it in — see that function's own doc comment.
double? ocptBudgetConsumedRatioOf({
  required int quotedAmountCents,
  required int paidCents,
  required int committedCents,
  required int inKindCoveredCents,
}) {
  if (quotedAmountCents == 0) {
    return null;
  }

  return (paidCents + committedCents + inKindCoveredCents) / quotedAmountCents;
}

/// Tell how stretched an account quoted at [quotedAmountCents] is, having paid [paidCents],
/// committed [committedCents] and settled [inKindCoveredCents] in kind against it.
///
/// An account with no quote at all ([quotedAmountCents] zero) reads
/// [OcptBudgetAccountStrain.within] whatever has been paid, committed or settled in kind against it
/// — spending zero more against nothing is not a state the header's alerts band alerts on — unless
/// something genuinely has moved, in which case there is no quote left to be within, and it reads
/// [OcptBudgetAccountStrain.over].
///
/// [inKindCoveredCents] is folded into the consumed side for the same reason
/// [ocptBudgetRemainingCents] folds it in — see that function's own doc comment: a counterpart line
/// adds equally to the quote and to this settled side, so it can never push an account over on its
/// own.
OcptBudgetAccountStrain ocptBudgetAccountStrainOf({
  required int quotedAmountCents,
  required int paidCents,
  required int committedCents,
  required int inKindCoveredCents,
}) {
  final consumedCents = paidCents + committedCents + inKindCoveredCents;

  if (consumedCents > quotedAmountCents) {
    return OcptBudgetAccountStrain.over;
  }

  final ratio = ocptBudgetConsumedRatioOf(
    quotedAmountCents: quotedAmountCents,
    paidCents: paidCents,
    committedCents: committedCents,
    inKindCoveredCents: inKindCoveredCents,
  );
  if (ratio != null && ratio > _ocptBudgetNearStrainRatio) {
    return OcptBudgetAccountStrain.near;
  }

  return OcptBudgetAccountStrain.within;
}

/// Get [lines]' own total read in [basis], paired with how many of them that reading actually
/// covers —
/// `ocpt_budget_vat.dart`'s "null, never zero" rule applied to a whole basis rather than
/// to the excluding-tax one alone, which is all `ocptBudgetExcludingTaxTotalOf` itself answers.
///
/// **Every row is converted individually and then summed, never the other way round**
/// (ADR 0025): [OcptBudgetTaxBasis.excludingTax] delegates to
/// [ocptBudgetExcludingTaxTotalOf] directly, and [OcptBudgetTaxBasis.includingTax] mirrors it
/// through [ocptIncludingTaxAmountCentsOf] over each line's own already-summed total
/// ([ocptBudgetLineTotalCents]) — a line already typed tax-inclusive needs no rate at all to answer
/// that reading (its own figure already is the answer), so only a line typed tax-exclusive with no
/// known rate is ever the reason [OcptBudgetCoveredTotal.isComplete] reads false under this basis,
/// exactly as only a tax-inclusive line with no known rate is the reason under the other one.
OcptBudgetCoveredTotal ocptBudgetTotalOf(
  List<OcptBudgetLine> lines, {
  required OcptBudgetTaxBasis basis,
  required int? projectVatRateBasisPoints,
}) {
  if (basis == OcptBudgetTaxBasis.excludingTax) {
    return ocptBudgetExcludingTaxTotalOf(
      lines,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
  }

  var amountCents = 0;
  var coveredLineCount = 0;

  for (final line in lines) {
    final includingTax = ocptIncludingTaxAmountCentsOf(
      OcptMoney(
        amountCents: ocptBudgetLineTotalCents(line),
        isTaxInclusive: line.unitPrice.isTaxInclusive,
        vatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
      ),
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (includingTax == null) {
      continue;
    }

    amountCents += includingTax;
    coveredLineCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredLineCount,
    lineCount: lines.length,
  );
}
