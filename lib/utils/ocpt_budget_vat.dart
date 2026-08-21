// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
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
