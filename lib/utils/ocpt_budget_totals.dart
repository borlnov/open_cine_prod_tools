// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';

/// How many thousandths make up one whole unit: what turns `quantityMilli` (1500 for 1.5 day) back
/// into a plain multiplier.
const int _ocptQuantityMilliPerUnit = 1000;

/// The ratio, above which a poste is flagged **near** its quote rather than merely **within** it —
/// 90 %, the figure the dashboard's own strain reading is drawn at.
const double _ocptBudgetNearStrainRatio = 0.9;

/// [line]'s own total, in cents, in whatever tax basis it was typed in — never converted:
/// `quantityMilli × unitAmountCents ÷ 1000`, rounded to the nearest cent.
int ocptBudgetLineTotalCents(OcptBudgetLine line) =>
    (line.quantityMilli * line.unitPrice.amountCents / _ocptQuantityMilliPerUnit).round();

/// [line]'s own total **excluding tax**, in cents, given the project's own
/// [projectVatRateBasisPoints] — or null when that figure cannot be known, exactly as
/// `ocptExcludingTaxAmountCentsOf` reads for a single amount.
///
/// Computed by converting [ocptBudgetLineTotalCents] itself, at the line's own basis and rate,
/// rather than converting the unit price and then multiplying: a rate conversion is linear, so the
/// two commute, and going through the already-summed total is what lets [ocptBudgetExcludingTaxTotalOf]
/// below sum a table **row by row and then convert**, never the other way round.
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

/// [poste]'s quoted total, in cents, in the tax-inclusive-as-typed basis: the sum of
/// [ocptBudgetLineTotalCents] over its own [OcptBudgetPoste.lines].
///
/// **Row by row, then summed** — never the other way round: `OcptBudgetPostesTable`'s own doc
/// comment is why this is computed rather than read off a stored column, and computing it any other
/// order would let a rounding at the poste level disagree, by a cent, with the sum a reader gets by
/// adding the lines up themselves.
int ocptBudgetPosteQuotedTotalCents(OcptBudgetPoste poste) =>
    poste.lines.fold(0, (sum, line) => sum + ocptBudgetLineTotalCents(line));

/// The whole project's quoted total, in cents: the sum of [ocptBudgetPosteQuotedTotalCents] over
/// [postes] — row by row, poste by poste, then summed, for the same reason that method is.
int ocptBudgetProjectQuotedTotalCents(List<OcptBudgetPoste> postes) =>
    postes.fold(0, (sum, poste) => sum + ocptBudgetPosteQuotedTotalCents(poste));

/// A total, paired with how many of the rows it was asked to sum actually carried a known rate —
/// `lib/utils/ocpt_budget_vat.dart`'s "null, never zero" rule applied to a whole table: a row whose
/// rate nobody has recorded contributes to neither [amountCents] nor [coveredLineCount], so the
/// coverage the UI reports (`10,349 € · over 2 of the 5 postes`) is a plain fact about the data, not
/// a string this class formats.
///
/// **A "line" here is any row a total was asked to sum** — a quote line
/// (`ocptBudgetExcludingTaxTotalOf`/`ocptBudgetTotalOf`), a journal entry
/// (`lib/utils/ocpt_budget_journal.dart`), a commitment (`lib/utils/ocpt_budget_projection.dart`)
/// or a catering-and-travel figure (`lib/utils/ocpt_budget_regie.dart`) — a day's own meals and
/// snacks, or a traveller's own mileage reimbursement: this class is shared across every one of
/// them rather than reimplemented per table, since the coverage arithmetic and the honesty it
/// argues for are exactly the same regardless of what is being priced.
///
/// **No `Tr` and no formatted string here** — `lib/utils/` is pure; the mode's own view resolves the
/// words.
class OcptBudgetCoveredTotal extends Equatable {
  /// The sum of every covered line's own total, in cents.
  final int amountCents;

  /// How many of [lineCount] lines — a quote line, a journal entry or a commitment — actually
  /// carried a known rate and were summed into [amountCents].
  final int coveredLineCount;

  /// How many lines — quote lines, journal entries or commitments, whichever this total sums —
  /// were asked for, covered or not.
  final int lineCount;

  /// Whether every line carried a known rate — [coveredLineCount] equals [lineCount]. Once true,
  /// the UI stops saying how many lines the figure covers: it has become the complete answer.
  bool get isComplete => coveredLineCount == lineCount;

  /// Class constructor
  const OcptBudgetCoveredTotal({
    required this.amountCents,
    required this.coveredLineCount,
    required this.lineCount,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetCoveredTotal(amountCents: $amountCents, coveredLineCount: $coveredLineCount, "
      "lineCount: $lineCount)";

  /// Object properties
  @override
  List<Object?> get props => [amountCents, coveredLineCount, lineCount];
}

/// [totals]' own combined figure — the sum of every [OcptBudgetCoveredTotal.amountCents], paired
/// with how many of the underlying rows actually carried a known rate: a plain reduction over
/// already-computed pure structures, not a rule of its own.
///
/// Shared by every reading that folds more than one [OcptBudgetCoveredTotal] into one grand
/// total — the dashboard's own `Paid`/`Committed` KPIs, folding the per-poste totals (and, for
/// `Paid`, the off-quote total, `lib/utils/ocpt_budget_journal.dart`'s own
/// `ocptBudgetOffQuotePaidTotalOf`), and the cost-tracking table's own total row, folding the very
/// same two into its own `Paid` cell.
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

/// The excluding-tax total of [lines], given the project's own [projectVatRateBasisPoints], paired
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

/// How stretched a poste is against its own quote — the colour the cost-tracking view paints it in
/// is the widget's own business, not this pure util's: it switches over this enum rather than
/// re-deriving the comparison.
enum OcptBudgetPosteStrain {
  /// Paid plus committed is at or below [_ocptBudgetNearStrainRatio] of the quote.
  within,

  /// Paid plus committed is above [_ocptBudgetNearStrainRatio] of the quote, but not over it yet.
  near,

  /// Paid plus committed exceeds the quote.
  over,
}

/// What is left of a poste quoted at [quotedAmountCents], having paid [paidCents] and committed
/// [committedCents] against it — negative once the poste has gone over its quote.
///
/// [paidCents] and [committedCents] are **parameters, not reads of their own**: this file stays
/// free of any database access, exactly like every other one under `lib/utils/` — reading
/// `budget_entries` and `budget_commitments` (`lib/utils/ocpt_budget_journal.dart`,
/// `lib/utils/ocpt_budget_projection.dart`) into the two per-poste totals a caller hands in here is
/// the mode's own job (`OcptBudgetSnapshot.build`).
int ocptBudgetRemainingCents({
  required int quotedAmountCents,
  required int paidCents,
  required int committedCents,
}) => quotedAmountCents - paidCents - committedCents;

/// How far a poste quoted at [quotedAmountCents] sits from what has actually moved against it —
/// [paidCents] plus [committedCents], minus the quote. Positive once the poste has gone over,
/// negative while it still has room: [ocptBudgetRemainingCents]'s own figure with the sign read the
/// other way round, for the financial report's "quoted vs. actual" reading rather than the
/// dashboard's "what is left" one.
int ocptBudgetVarianceCents({
  required int quotedAmountCents,
  required int paidCents,
  required int committedCents,
}) => paidCents + committedCents - quotedAmountCents;

/// How much of a poste quoted at [quotedAmountCents] has been consumed by [paidCents] plus
/// [committedCents], as a ratio (`1.0` meaning exactly on quote) — or null when the poste carries no
/// quote at all ([quotedAmountCents] zero), where a ratio would be a division by zero rather than a
/// figure.
double? ocptBudgetConsumedRatioOf({
  required int quotedAmountCents,
  required int paidCents,
  required int committedCents,
}) {
  if (quotedAmountCents == 0) {
    return null;
  }

  return (paidCents + committedCents) / quotedAmountCents;
}

/// How stretched a poste quoted at [quotedAmountCents] is, having paid [paidCents] and committed
/// [committedCents] against it.
///
/// A poste with no quote at all ([quotedAmountCents] zero) reads [OcptBudgetPosteStrain.within]
/// whatever has been paid or committed against it — spending zero more against nothing is not a
/// state this dashboard alerts on — unless something genuinely has moved, in which case there is no
/// quote left to be within, and it reads [OcptBudgetPosteStrain.over].
OcptBudgetPosteStrain ocptBudgetPosteStrainOf({
  required int quotedAmountCents,
  required int paidCents,
  required int committedCents,
}) {
  final consumedCents = paidCents + committedCents;

  if (consumedCents > quotedAmountCents) {
    return OcptBudgetPosteStrain.over;
  }

  final ratio = ocptBudgetConsumedRatioOf(
    quotedAmountCents: quotedAmountCents,
    paidCents: paidCents,
    committedCents: committedCents,
  );
  if (ratio != null && ratio > _ocptBudgetNearStrainRatio) {
    return OcptBudgetPosteStrain.near;
  }

  return OcptBudgetPosteStrain.within;
}

/// [lines]' own total read in [basis], paired with how many of them that reading actually covers —
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
    return ocptBudgetExcludingTaxTotalOf(lines, projectVatRateBasisPoints: projectVatRateBasisPoints);
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
