// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The decimal separator [ocptMileageRateTextOf] writes, and the one [ocptMileageRateMilliCentsOf]
/// reads alongside the comma — `ocptCostCentsOf`'s own pair (`lib/utils/ocpt_cost_amount.dart`).
const String _decimalPoint = ".";

/// The comma a French keyboard produces for the same separator.
const String _decimalComma = ",";

/// How many thousandths of a cent one cent is worth: what makes `0.529` into `52900`.
const int _milliCentsPerCent = 100000;

/// How many decimal digits a mileage rate is written with.
const int _rateDigits = 3;

/// Every kind of space a typed or pasted rate may be grouped with, mirroring `ocptCostCentsOf`'s
/// own `_spaces`.
final RegExp _spaces = RegExp(r"\s");

/// Reads [text] as a per-kilometre reimbursement rate and returns it in **thousandths of a
/// cent**, or null when it holds no rate at all — an empty field, or something that is not a
/// number.
///
/// **This is not `ocptCostCentsOf` with a different name.** That function rounds to the nearest
/// cent because a receipt is never printed to a thousandth of a euro; a mileage scale is the
/// opposite case — a real one is quoted to **three decimals** (`0.529 €/km`, `0.601`, `0.395`),
/// and a function that rounded one of those to the nearest cent (`0.53`) would hand back a figure
/// the user never typed, which is exactly what `docs/architecture/budget.md`'s own money rule
/// forbids: an amount is stored exactly as it was typed, and never reconstructed. Cents alone
/// cannot state `0.529` at all, so this reads and writes in thousandths of a cent instead — the
/// unit `OcptBudgetMileageRatesTable.ratePerKmMilliCents` itself is stored in.
///
/// Forgiving about the shape, strict about the value, exactly as `ocptCostCentsOf` is: both
/// decimal separators are accepted, spaces (including a paste's own no-break ones) are dropped,
/// and anything left that is not a non-negative number reads as **no rate**, never as zero — a
/// field half-way through being typed is not a free ride.
///
/// Rounded to the nearest thousandth of a cent: a fourth decimal is more precision than any
/// mileage scale is ever quoted with, and the fraction a user cannot type is not worth carrying.
int? ocptMileageRateMilliCentsOf(String text) {
  final normalized = text.replaceAll(_spaces, "").replaceAll(_decimalComma, _decimalPoint);
  if (normalized.isEmpty) {
    return null;
  }

  final rate = double.tryParse(normalized);
  if (rate == null || rate < 0) {
    return null;
  }

  return (rate * _milliCentsPerCent).round();
}

/// Writes [milliCents] the way [ocptMileageRateMilliCentsOf] reads it back: a plain number with
/// three decimals, or an empty string when there is no rate at all.
///
/// No currency symbol and no unit: this is the text of an editable field, not a formatted price
/// per kilometre. Both are chrome the field wears as its `suffixText`
/// (`OcptProjectSettingsMileageRatesSection`) rather than characters this function would have to
/// write and [ocptMileageRateMilliCentsOf] would then have to strip back out — `ocptCostTextOf`'s
/// own reasoning, applied to a rate rather than to a lump sum.
String ocptMileageRateTextOf(int? milliCents) {
  if (milliCents == null) {
    return "";
  }

  return (milliCents / _milliCentsPerCent).toStringAsFixed(_rateDigits);
}
