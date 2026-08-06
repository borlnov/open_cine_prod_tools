// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How many minutes a full day holds — the modulus [ocptFormatDayMinute] reads a minute against to
/// print a clock face, and nothing else in this file: every other function here works on the raw
/// value with no wrapping at all.
const int _ocptMinutesPerDay = 1440;

/// How many minutes a full hour holds.
const int _ocptMinutesPerHour = 60;

/// Writes [minute] as a `HH:mm` clock reading — `19:00`, `03:00` for `1620`, `00:00` for `0` or
/// `1440`.
///
/// A shooting day's own times (`shooting_slots.crewCallMinute`, `shooting_day_blocks.anchorMinute`,
/// the figures [ocpt_sun_times.dart](ocpt_sun_times.dart) returns…) are stored and computed as
/// **minutes from that day's own midnight, and a value may exceed 1440** or fall below zero: a
/// night slot running 19:00 → 03:00 stores `1140` → `1620`, and an event the sun-times formulas
/// place before local midnight (a location whose real time zone runs well ahead of the device's own
/// — ADR 0016) comes back negative. None of that arithmetic ever takes a modulus, by design: the
/// offset from midnight is the only truth a block's chain (`ocpt_shooting_day_timeline.dart`) or a
/// comparison between two such values needs.
///
/// This formatter is the one place that *does* wrap, and it does so deliberately: it answers "what
/// does a clock on the wall read", which is what every reference call sheet prints, never "how many
/// minutes past this day's midnight". `1620` is `03:00`, the following morning's clock face, not
/// `27:00`; `-181` is `20:59`, the previous evening's. A caller that needs to say *which* day —
/// "the following morning" — says so in words around this formatter's output, since digits alone
/// cannot.
String ocptFormatDayMinute(int minute) {
  final normalized = minute % _ocptMinutesPerDay;
  final hours = normalized ~/ _ocptMinutesPerHour;
  final minutes = normalized % _ocptMinutesPerHour;
  return "${_twoDigits(hours)}:${_twoDigits(minutes)}";
}

/// Reads [text] as a `HH:mm` clock reading and returns the minute [ocptFormatDayMinute] would print
/// it back as, or null when [text] isn't one — an empty field, or something with no clock in it at
/// all.
///
/// The result is always in `0..1439`: a plain clock reading names no day, so unlike
/// [ocptFormatDayMinute] this function cannot invert the wrap. A caller placing the parsed minute
/// on a shooting day that runs past midnight (an anchor meant for the small hours of a night shoot)
/// is the one that knows it needs `+ 1440` and adds it back — typically a "next day" toggle beside
/// the field, not a fact this parser could ever recover from the four digits alone.
int? ocptParseDayMinute(String text) {
  final match = _ocptClockPattern.firstMatch(text.trim());
  if (match == null) {
    return null;
  }

  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  if (hours > 23 || minutes > 59) {
    return null;
  }

  return hours * _ocptMinutesPerHour + minutes;
}

/// Writes [minutes], a length of time rather than a point in the day, as `1 h 30` or `45 min`.
///
/// A bare figure of minutes below an hour reads as minutes alone; at an hour or above, the hour
/// count is always shown and the leftover minutes are dropped entirely when there are none — `60`
/// is `1 h`, never `1 h 00`. A negative length (a shot whose duration shrank the timeline, an
/// over-run's shortfall) keeps its sign in front of the same reading rather than being refused: this
/// is arithmetic on a difference, not a clock, and a difference can run either way.
String ocptFormatMinuteDuration(int minutes) {
  final sign = minutes < 0 ? "-" : "";
  final absoluteMinutes = minutes.abs();
  final hours = absoluteMinutes ~/ _ocptMinutesPerHour;
  final remainder = absoluteMinutes % _ocptMinutesPerHour;

  if (hours == 0) {
    return "$sign$remainder min";
  }
  if (remainder == 0) {
    return "$sign$hours h";
  }
  return "$sign$hours h $remainder";
}

/// The `HH:mm` shape [ocptParseDayMinute] accepts: one or two digits of hour, exactly two of
/// minute.
final RegExp _ocptClockPattern = RegExp(r"^([0-9]{1,2}):([0-9]{2})$");

/// [value] written on two digits, left-padded with a zero.
String _twoDigits(int value) => value.toString().padLeft(2, "0");
