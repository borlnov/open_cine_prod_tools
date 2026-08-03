// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The decimal separator [ocptCostTextOf] writes, and the one [ocptCostCentsOf] reads alongside the
/// comma.
const String _decimalPoint = ".";

/// The comma a French keyboard produces for the same separator.
const String _decimalComma = ",";

/// How many cents one unit of currency is worth: what makes `12.50` into `1250`.
const int _centsPerUnit = 100;

/// How many digits of cents an amount is written with.
const int _centDigits = 2;

/// Every kind of space a typed or pasted amount may be grouped with — the ordinary one, and the
/// no-break ones a spreadsheet's own formatting carries into a paste.
final RegExp _spaces = RegExp(r"\s");

/// Reads [text] as an amount of money and returns it in **cents**, or null when it holds no amount
/// at all — an empty field, or something that is not a number.
///
/// The one place the app turns typed money into `elements.cost`, so the sheet, the bloc and any
/// later reader of that column can never disagree about what `12,50` means. It is deliberately
/// forgiving about the shape and strict about the value:
///
/// - both decimal separators are accepted, since the app ships in `en_GB` and in French and the
///   same user switches between them;
/// - spaces (including the non-breaking ones a paste from a spreadsheet carries) are dropped, so a
///   grouped `1 200` reads as twelve hundred;
/// - anything left that is not a plain number reads as **no amount**, never as zero: a field
///   half-way through being typed is not a free prop.
///
/// Rounding is to the nearest cent: a third of a euro is 33 cents, and the fraction of a cent a
/// user cannot type is not worth carrying.
int? ocptCostCentsOf(String text) {
  final normalized = text.replaceAll(_spaces, "").replaceAll(_decimalComma, _decimalPoint);
  if (normalized.isEmpty) {
    return null;
  }

  final amount = double.tryParse(normalized);
  if (amount == null) {
    return null;
  }

  return (amount * _centsPerUnit).round();
}

/// Writes [cents] the way [ocptCostCentsOf] reads it back: a plain number with two decimals, or an
/// empty string when there is no amount at all.
///
/// No currency symbol and no grouping: this is the text of an editable field, not a formatted
/// price. What currency a production counts in is a project-wide question nothing in the app asks
/// yet, and a grouped `1 200.00` would have to be un-grouped again on the very next keystroke.
String ocptCostTextOf(int? cents) {
  if (cents == null) {
    return "";
  }

  return (cents / _centsPerUnit).toStringAsFixed(_centDigits);
}
