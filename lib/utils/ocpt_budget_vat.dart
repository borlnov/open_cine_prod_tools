// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';

/// How many basis points make up 100 %: what turns 550 (5.5 %) into a fraction, `550 / 10000`.
const int _ocptBasisPointsPerWhole = 10000;

/// The rate a budget line actually reads under, and where it came from: the line's own override
/// when it has one, the project's default otherwise.
///
/// The cost-tracking view paints an overridden rate in the accent colour and an inherited one in
/// grey — this is what it switches on, rather than re-deriving the comparison itself.
class OcptBudgetEffectiveVatRate extends Equatable {
  /// The rate itself, in basis points, or null when **neither** the line nor the project has
  /// recorded one — there is then no rate to read this amount under at all.
  final int? basisPoints;

  /// Whether [basisPoints] came from the line's own override rather than the project's default, or
  /// null when [basisPoints] itself is null: there is then no rate to say the origin of.
  final bool? isOverridden;

  /// Class constructor
  const OcptBudgetEffectiveVatRate({required this.basisPoints, required this.isOverridden});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetEffectiveVatRate(basisPoints: $basisPoints, isOverridden: $isOverridden)";

  /// Object properties
  @override
  List<Object?> get props => [basisPoints, isOverridden];
}

/// The rate a line carrying [lineVatRateBasisPoints] actually reads under, given the project's own
/// [projectVatRateBasisPoints].
///
/// `OcptBudgetLinesTable.vatRateBasisPoints`'s null means "inherit the project's rate", so a null
/// line rate resolves to the project's own value — itself possibly null, meaning "nobody has
/// recorded a rate at all". A non-null line rate always wins, **0 included**: an explicit 0 % is a
/// value the line stated, not an absence to fall through.
OcptBudgetEffectiveVatRate ocptEffectiveVatRateOf({
  required int? lineVatRateBasisPoints,
  required int? projectVatRateBasisPoints,
}) {
  if (lineVatRateBasisPoints != null) {
    return OcptBudgetEffectiveVatRate(basisPoints: lineVatRateBasisPoints, isOverridden: true);
  }

  return OcptBudgetEffectiveVatRate(
    basisPoints: projectVatRateBasisPoints,
    isOverridden: projectVatRateBasisPoints == null ? null : false,
  );
}

/// [money]'s amount **excluding** tax, in cents, given the project's own
/// [projectVatRateBasisPoints] — or null when that figure cannot be known.
///
/// An amount already stated excluding tax ([OcptMoney.isTaxInclusive] false) is its own answer,
/// **whatever the rate is or isn't**: stripping tax out of a figure that never carried any needs no
/// rate at all. An amount stated **including** tax needs the effective rate
/// ([ocptEffectiveVatRateOf]) to strip it back out; when that rate is unknown (neither the line nor
/// the project has recorded one), this returns **null, never zero** — the excluding-tax figure
/// genuinely does not exist yet, and a total built from it must say so rather than silently
/// counting the line as free.
///
/// Rounded to the nearest cent: the fraction of a cent nobody typed is not worth carrying.
int? ocptExcludingTaxAmountCentsOf(OcptMoney money, {required int? projectVatRateBasisPoints}) {
  if (!money.isTaxInclusive) {
    return money.amountCents;
  }

  final rate = ocptEffectiveVatRateOf(
    lineVatRateBasisPoints: money.vatRateBasisPoints,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  ).basisPoints;
  if (rate == null) {
    return null;
  }

  return (money.amountCents * _ocptBasisPointsPerWhole / (_ocptBasisPointsPerWhole + rate))
      .round();
}

/// [money]'s amount **including** tax, in cents, given the project's own
/// [projectVatRateBasisPoints] — or null when that figure cannot be known.
///
/// [ocptExcludingTaxAmountCentsOf]'s mirror: an amount already stated including tax is its own
/// answer regardless of the rate, and an amount stated excluding tax needs the effective rate to
/// gross it up — null, never zero, when that rate is unknown.
///
/// Rounded to the nearest cent, for the reason [ocptExcludingTaxAmountCentsOf] gives.
int? ocptIncludingTaxAmountCentsOf(OcptMoney money, {required int? projectVatRateBasisPoints}) {
  if (money.isTaxInclusive) {
    return money.amountCents;
  }

  final rate = ocptEffectiveVatRateOf(
    lineVatRateBasisPoints: money.vatRateBasisPoints,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  ).basisPoints;
  if (rate == null) {
    return null;
  }

  return (money.amountCents * (_ocptBasisPointsPerWhole + rate) / _ocptBasisPointsPerWhole)
      .round();
}

/// The VAT [money] carries, in cents, given the project's own [projectVatRateBasisPoints] — the
/// difference between [ocptIncludingTaxAmountCentsOf] and [ocptExcludingTaxAmountCentsOf], or null
/// when either of those is: an amount whose excluding-tax figure cannot be known has no VAT figure
/// either, for the same reason.
///
/// An explicit **0 %** rate answers zero here, a genuine, known amount of VAT — not the same fact
/// as a null answer, which means the amount of VAT is itself unrecorded.
int? ocptVatAmountCentsOf(OcptMoney money, {required int? projectVatRateBasisPoints}) {
  final excludingTax = ocptExcludingTaxAmountCentsOf(
    money,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );
  final includingTax = ocptIncludingTaxAmountCentsOf(
    money,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );

  if (excludingTax == null || includingTax == null) {
    return null;
  }

  return includingTax - excludingTax;
}

/// The decimal separator [ocptVatRatePercentTextOf] writes, and the one
/// [ocptVatRateBasisPointsOf] reads alongside the comma.
const String _ocptDecimalPoint = ".";

/// The comma a French keyboard produces for the same separator.
const String _ocptDecimalComma = ",";

/// How many basis points make up one per cent: what turns `20` into `2000` and `5.5` into `550`.
const int _ocptBasisPointsPerPercent = 100;

/// How many digits of per cent a fractional rate is written with before its trailing zeroes are
/// dropped — two, since a basis point is itself a hundredth of a per cent and never carries more
/// precision than that.
const int _ocptPercentDigits = 2;

/// Every kind of space a typed or pasted figure may carry — the ordinary one, and the no-break
/// ones a spreadsheet's own formatting brings along.
final RegExp _ocptSpaces = RegExp(r"\s");

/// The trailing zeroes [ocptVatRatePercentTextOf] drops off a fractional reading, so `5.50` reads
/// as `5.5`.
final RegExp _ocptTrailingZeroes = RegExp(r"0+$");

/// Reads [text] as a VAT rate typed **in per cent** and returns it in **basis points**, or null
/// when it holds no such figure at all — an empty field, something that is not a number, or a
/// negative figure, which is not a rate anybody meant.
///
/// The one place the app turns a typed rate into basis points, so the project settings card and
/// the budget mode's own per-line override can never disagree about what `5,5` means — the reason
/// `ocptCostCentsOf` lives in `lib/utils/` rather than beside the one field that first needed it.
/// It is forgiving about the shape and strict about the value, exactly as that function is: both
/// decimal separators are accepted, spaces are dropped, and anything left that is not a plain
/// number reads as **no rate**.
///
/// **Zero is legal and is returned as `0`**, unlike a minimum rest's own zero
/// (`ocptMinimumRestMinutesOf`): an explicit 0 % is a value somebody states — wages and a
/// copyright assignment carry no VAT — and collapsing it into null would say "nobody has recorded
/// a rate" instead, which this file's whole arithmetic treats as a different fact.
int? ocptVatRateBasisPointsOf(String text) {
  final normalized = text.replaceAll(_ocptSpaces, "").replaceAll(_ocptDecimalComma, _ocptDecimalPoint);
  if (normalized.isEmpty) {
    return null;
  }

  final percent = double.tryParse(normalized);
  if (percent == null) {
    return null;
  }

  final basisPoints = (percent * _ocptBasisPointsPerPercent).round();
  return basisPoints < 0 ? null : basisPoints;
}

/// Writes [basisPoints] the way [ocptVatRateBasisPointsOf] reads it back: a plain number of per
/// cent, or an empty string while nobody has recorded a rate.
///
/// A whole number of per cent is written bare (`2000` is `20`, never `20.0`), and anything else
/// keeps the per cent it fractionally makes, trailing zeroes dropped (`550` is `5.5`). No `%` and
/// no grouping: this is the text of an editable field, not a formatted rate — the sign is shown
/// beside it as the field's `suffixText`, chrome the field wears rather than a character this
/// function would write and [ocptVatRateBasisPointsOf] would then have to strip back out.
String ocptVatRatePercentTextOf(int? basisPoints) {
  if (basisPoints == null) {
    return "";
  }

  if (basisPoints % _ocptBasisPointsPerPercent == 0) {
    return "${basisPoints ~/ _ocptBasisPointsPerPercent}";
  }

  return (basisPoints / _ocptBasisPointsPerPercent)
      .toStringAsFixed(_ocptPercentDigits)
      .replaceFirst(_ocptTrailingZeroes, "");
}

/// The one rate every one of [lines] reads under, through [ocptEffectiveVatRateOf], or null while
/// [lines] is empty, carries no known rate at all, or disagrees about it (either the figure or
/// whether it is overridden) — what the cost-tracking table's own `Quote` sub-line shows the rate
/// for, and only then: "only when the poste's lines all share one known rate"
/// (ADR 0025).
///
/// Equality is [OcptBudgetEffectiveVatRate]'s own (`Equatable`, over both
/// [OcptBudgetEffectiveVatRate.basisPoints] and [OcptBudgetEffectiveVatRate.isOverridden]): two
/// lines reading the very same figure but one by its own override and the other by inheriting the
/// project's identical default do not "share" it in the sense this reads for — which colour to
/// paint the rate in would itself be ambiguous.
OcptBudgetEffectiveVatRate? ocptBudgetPosteUniformVatRateOf(
  List<OcptBudgetLine> lines, {
  required int? projectVatRateBasisPoints,
}) {
  if (lines.isEmpty) {
    return null;
  }

  final first = ocptEffectiveVatRateOf(
    lineVatRateBasisPoints: lines.first.unitPrice.vatRateBasisPoints,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );
  if (first.basisPoints == null) {
    return null;
  }

  for (final line in lines.skip(1)) {
    final rate = ocptEffectiveVatRateOf(
      lineVatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (rate != first) {
      return null;
    }
  }

  return first;
}
