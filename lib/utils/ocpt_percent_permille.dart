// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The decimal separator [ocptPermillePercentTextOf] writes, and the one [ocptPercentPermilleOf]
/// reads alongside the comma — `ocptCostCentsOf`'s own pair (`lib/utils/ocpt_cost_amount.dart`).
const String _decimalPoint = ".";

/// The comma a French keyboard produces for the same separator.
const String _decimalComma = ",";

/// How many per mille make up one per cent: what turns a typed `40` into the `400` per mille
/// `OcptBudgetShare.sharePermille`/`.reinvestPermille` are stored in.
const int _permillePerPercent = 10;

/// How many decimal digits a per mille figure is written with in per cent — one, a per mille being
/// itself a tenth of a per cent and never carrying more precision than that.
const int _percentDigits = 1;

/// Every kind of space a typed or pasted figure may be grouped with, mirroring `ocptCostCentsOf`'s
/// own `_spaces`.
final RegExp _spaces = RegExp(r"\s");

/// The trailing zero [ocptPermillePercentTextOf] drops off a fractional reading, so `40.0` reads as
/// `40`.
final RegExp _trailingZero = RegExp(r"\.0$");

/// Reads [text] as a percentage typed into a field and returns it in **per mille**, or null when
/// it holds no such figure at all — an empty field, something that is not a number, or a negative
/// figure, which is not a share anybody meant.
///
/// The revenue sharing's own reading of `ocptCostCentsOf`'s discipline, for the one figure this
/// mode types as a percentage and stores as a fraction of a whole: `OcptBudgetShare.sharePermille`
/// and `.reinvestPermille` (`lib/utils/ocpt_budget_shares.dart`'s own arithmetic reads both in per
/// mille). Neither `ocptCostCentsOf` (money) nor `ocptVatRateBasisPointsOf`/
/// `ocptMileageRateMilliCentsOf` (a different scale, basis points and thousandths of a cent
/// respectively) fit this one, so this is the sibling `OcptBudgetShareDialog`'s own doc comment
/// points to.
///
/// Forgiving about the shape, strict about the value, exactly as every sibling parser in this
/// codebase is: both decimal separators are accepted, spaces (including a paste's own no-break
/// ones) are dropped, and anything left that is not a non-negative number reads as **no figure at
/// all** — null, never zero, a field half-way through being typed being no free ride.
int? ocptPercentPermilleOf(String text) {
  final normalized = text.replaceAll(_spaces, "").replaceAll(_decimalComma, _decimalPoint);
  if (normalized.isEmpty) {
    return null;
  }

  final percent = double.tryParse(normalized);
  if (percent == null || percent < 0) {
    return null;
  }

  return (percent * _permillePerPercent).round();
}

/// Writes [permille] the way [ocptPercentPermilleOf] reads it back: a plain number of per cent, or
/// an empty string when there is no figure at all.
///
/// No `%` sign: this is the text of an editable field, not a formatted rate — the sign is shown
/// beside it as the field's `suffixText`, chrome the field wears rather than a character this
/// function would write and [ocptPercentPermilleOf] would then have to strip back out.
String ocptPermillePercentTextOf(int? permille) {
  if (permille == null) {
    return "";
  }

  if (permille % _permillePerPercent == 0) {
    return "${permille ~/ _permillePerPercent}";
  }

  return (permille / _permillePerPercent).toStringAsFixed(_percentDigits).replaceFirst(_trailingZero, "");
}
