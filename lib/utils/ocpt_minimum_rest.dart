// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The decimal separator [ocptMinimumRestHoursTextOf] writes, and the one
/// [ocptMinimumRestMinutesOf] reads alongside the comma.
const String _decimalPoint = ".";

/// The comma a French keyboard produces for the same separator.
const String _decimalComma = ",";

/// How many minutes one hour holds: what makes `11.5` into `690`.
const int _minutesPerHour = 60;

/// How many digits of hour a fractional reading is written with before its trailing zeroes are
/// dropped — two, so a quarter of an hour survives the round trip (`11.25`).
const int _hourDigits = 2;

/// Every kind of space a typed or pasted figure may carry — the ordinary one, and the no-break ones
/// a spreadsheet's own formatting brings along.
final RegExp _spaces = RegExp(r"\s");

/// The trailing zeroes [ocptMinimumRestHoursTextOf] drops off a fractional reading, so `11.50`
/// reads as `11.5`.
final RegExp _trailingZeroes = RegExp(r"0+$");

/// Reads [text] as a minimum rest typed **in hours** and returns it in **minutes**, or null when it
/// holds no such figure at all — an empty field, something that is not a number, or a figure that
/// is not a positive length of time.
///
/// The one place the app turns what is typed into `project_info.minimumRestMinutes`, mirroring
/// [ocptCostCentsOf](ocpt_cost_amount.dart)'s own shape: the column stays in minutes, because that
/// is the unit every rest computation and `OcptScheduleRestTimeAlert` already work in, but nobody
/// says a turnaround in minutes — a production says "eleven hours", so hours is what the field
/// takes. Both decimal separators are accepted, since the app ships in `en_GB` and in French and
/// the same user switches between them, and spaces are dropped so a pasted figure still reads.
///
/// Rounding is to the nearest minute: an hour figure carrying more precision than that names no
/// gesture anybody made.
///
/// **Zero and negative are refused**, unlike `ocptMaxDailyPresenceMinutesOf`'s own zero: this is a
/// *minimum*, and "no rest at all is owed" is not what an empty field means either — see
/// `OcptProjectSettingsMinimumRestSection`, which clears the project's figure on an empty
/// submission and reverts the field on anything this function refuses.
int? ocptMinimumRestMinutesOf(String text) {
  final normalized = text.replaceAll(_spaces, "").replaceAll(_decimalComma, _decimalPoint);
  if (normalized.isEmpty) {
    return null;
  }

  final hours = double.tryParse(normalized);
  if (hours == null) {
    return null;
  }

  final minutes = (hours * _minutesPerHour).round();
  return minutes <= 0 ? null : minutes;
}

/// Writes [minutes] the way [ocptMinimumRestMinutesOf] reads it back: a plain number of hours, or
/// an empty string while nobody has recorded a minimum.
///
/// A whole number of hours is written bare (`660` is `11`, never `11.0`), and anything else keeps
/// the hours it fractionally makes, trailing zeroes dropped (`690` is `11.5`). No unit and no
/// grouping: this is the text of an editable field, not a formatted duration — the `h` is shown
/// beside it as the field's `suffixText`, chrome the field wears rather than a character this
/// function would write and [ocptMinimumRestMinutesOf] would then have to strip back out.
String ocptMinimumRestHoursTextOf(int? minutes) {
  if (minutes == null) {
    return "";
  }

  if (minutes % _minutesPerHour == 0) {
    return "${minutes ~/ _minutesPerHour}";
  }

  return (minutes / _minutesPerHour)
      .toStringAsFixed(_hourDigits)
      .replaceFirst(_trailingZeroes, "");
}
