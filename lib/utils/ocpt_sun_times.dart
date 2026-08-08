// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

/// How many minutes a degree of longitude is worth in solar time: the Earth turns 360° in 1440
/// minutes, so one degree is four.
const double _ocptMinutesPerDegreeOfLongitude = 4;

/// The sun's centre sits this many degrees below the horizon at sunrise and sunset: the geometric
/// 90° plus atmospheric refraction (about 34′) plus the sun's own apparent half-diameter (about
/// 16′) — the standard NOAA constant.
const double _ocptSunriseSunsetZenithDegrees = 90.833;

/// The sun's depth below the horizon marking civil twilight, in degrees: bright enough to work
/// outdoors with no artificial light, dim enough that the brightest stars and planets show.
const double _ocptCivilZenithDegrees = 96;

/// The sun's depth below the horizon marking nautical twilight, in degrees: the horizon is still
/// distinguishable against the sky, historically enough to take a star sight by it.
const double _ocptNauticalZenithDegrees = 102;

/// The sun's depth below the horizon marking astronomical twilight, in degrees: past this the sky
/// is as dark as the sun itself ever lets it get — no last trace of scattered sunlight remains.
const double _ocptAstronomicalZenithDegrees = 108;

/// The five sun and twilight figures a call sheet prints, for one date and one place — sunrise,
/// sunset, and the civil, nautical and astronomical twilights at both ends of the day (§7 of
/// `docs/plans/schedule-mode.md`, recorded as ADR 0016).
///
/// Every figure is in **minutes from `date`'s own local midnight, wrapping nothing** — the same
/// convention `shooting_day_blocks` and `ocpt_shooting_day_timeline.dart` use. A figure that falls
/// before local midnight (a location whose real time zone runs well ahead of the device's own, see
/// [ocptSunTimesOf]) comes back negative; one that falls after the following midnight (a place far
/// enough north or south that a "night" sunset lands past 24:00) comes back at 1440 or more.
/// `ocptFormatDayMinute` (`ocpt_day_minute.dart`) already reads either correctly as a clock face.
///
/// Every figure is also **independently nullable**. Above roughly the polar circles the sun can
/// stay above the horizon all day (no sunrise, no sunset, no twilight of any depth) or below it
/// deep enough that a phase never starts or never ends at all — and a location need not be
/// anywhere near a pole to lose just its astronomical twilight for a few weeks around its own
/// summer solstice: Paris (48.85°N) already does. A null figure means exactly that this one does
/// not exist on this day at this place; a caller prints nothing rather than a plausible wrong time.
class OcptSunTimes {
  /// Builds a computed set of sun times. Callers get one of these from [ocptSunTimesOf]; the
  /// constructor is public only so tests can build fixtures without going through the algorithm.
  const OcptSunTimes({
    required this.sunriseMinute,
    required this.sunsetMinute,
    required this.civilDawnMinute,
    required this.civilDuskMinute,
    required this.nauticalDawnMinute,
    required this.nauticalDuskMinute,
    required this.astronomicalDawnMinute,
    required this.astronomicalDuskMinute,
    required this.utcOffsetUsed,
  });

  /// When the sun's upper edge crosses the horizon in the morning, or null above the polar circle
  /// in summer (the sun never sets the night before) or in winter (it never rises at all).
  final int? sunriseMinute;

  /// When the sun's upper edge crosses the horizon in the evening, or null for the same reasons as
  /// [sunriseMinute].
  final int? sunsetMinute;

  /// When the sun reaches 6° below the horizon in the morning, or null when it never gets that
  /// dark (a summer night far enough north or south) or never gets that bright (a winter day that
  /// never rises past this depth).
  final int? civilDawnMinute;

  /// The evening counterpart of [civilDawnMinute].
  final int? civilDuskMinute;

  /// When the sun reaches 12° below the horizon in the morning, or null for the same reasons as
  /// [civilDawnMinute] at a shallower depth.
  final int? nauticalDawnMinute;

  /// The evening counterpart of [nauticalDawnMinute].
  final int? nauticalDuskMinute;

  /// When the sun reaches 18° below the horizon in the morning — full astronomical night — or null
  /// for the same reasons, at the depth most likely to be missing away from the poles too.
  final int? astronomicalDawnMinute;

  /// The evening counterpart of [astronomicalDawnMinute].
  final int? astronomicalDuskMinute;

  /// The device's own UTC offset for `date` (see [ocptSunTimesOf]) that every minute above was
  /// converted through, so a caller can show which one was used rather than leaving it implicit.
  final Duration utcOffsetUsed;
}

/// Computes [OcptSunTimes] for [date] at [latitudeDegrees]/[longitudeDegrees] — positive north and
/// east respectively, matching `locations.latitude`/`locations.longitude` — entirely offline.
///
/// This is the NOAA General Solar Position Calculations' low-precision formulas (the ones on
/// <https://gml.noaa.gov/grad/solcalc/solareqns.PDF>), where declination and the equation of time
/// are a function of where in the year [date] falls, and every one of the eight figures is the same
/// hour-angle equation run at four depths below the horizon and at each end of the day. No table, no
/// network call and no external service is involved: the same shoot planned offline in a field with
/// no signal gets the same numbers as one planned in an office.
///
/// NOAA's own formulas evaluate declination and the equation of time once, at solar noon, which is
/// accurate to a minute or two near a solstice (where both move slowly) but drifts several minutes
/// wide near an equinox and at a high latitude (where both move fastest, and a sunrise or sunset
/// many hours from noon carries that drift the furthest). [_ocptEventUtcMinute] instead solves each
/// figure **twice**: once with noon's own declination, to get a first estimate of when the event
/// falls, then again with the declination *at that estimated moment* — the position the sun is
/// actually near when the event happens, rather than the position it was in at noon. A third pass
/// would sharpen this further by a matter of seconds; two is where the returns stop being worth the
/// extra trigonometry for a figure this app only ever rounds to the minute.
///
/// [date] is read as a **local** date (`date.toLocal()`; only its year/month/day matter) and its own
/// [DateTime.timeZoneOffset] — the device's own UTC offset *for that date*, which already accounts
/// for a daylight-saving change partway through the year — is the one every figure is converted
/// through and the one [OcptSunTimes.utcOffsetUsed] reports back. **This is correct for a production
/// shooting in its own time zone, which is every case this app has so far, and wrong by the exact
/// difference for one shooting abroad on a device still set to home.** That limitation is written
/// down rather than hidden: [OcptSunTimes.utcOffsetUsed] is what lets the day inspector say which
/// offset it used instead of presenting a number with no way to tell it might be off, and a future
/// version that needs to be right abroad has one clearly-named thing to replace — reading the
/// offset off the device — rather than a computation to re-derive from scratch. See ADR 0016.
///
/// No coordinates, no result to compute in the first place: a day with no location on its first
/// slot has nothing to call [ocptSunTimesOf] with, and that is the caller's decision, not this
/// function's — it always requires both coordinates.
OcptSunTimes ocptSunTimesOf({
  required DateTime date,
  required double latitudeDegrees,
  required double longitudeDegrees,
}) {
  final local = date.toLocal();
  final offset = local.timeZoneOffset;
  final dayOfYear = _ocptDayOfYear(local);

  int? deviceMinuteOf(double? utcMinute) =>
      utcMinute == null ? null : (utcMinute + offset.inMinutes).round();

  int? eventMinuteAt(double zenithDegrees, {required bool sunrise}) => deviceMinuteOf(
    _ocptEventUtcMinute(
      dayOfYear: dayOfYear,
      latitudeDegrees: latitudeDegrees,
      longitudeDegrees: longitudeDegrees,
      zenithDegrees: zenithDegrees,
      sunrise: sunrise,
    ),
  );

  return OcptSunTimes(
    sunriseMinute: eventMinuteAt(_ocptSunriseSunsetZenithDegrees, sunrise: true),
    sunsetMinute: eventMinuteAt(_ocptSunriseSunsetZenithDegrees, sunrise: false),
    civilDawnMinute: eventMinuteAt(_ocptCivilZenithDegrees, sunrise: true),
    civilDuskMinute: eventMinuteAt(_ocptCivilZenithDegrees, sunrise: false),
    nauticalDawnMinute: eventMinuteAt(_ocptNauticalZenithDegrees, sunrise: true),
    nauticalDuskMinute: eventMinuteAt(_ocptNauticalZenithDegrees, sunrise: false),
    astronomicalDawnMinute: eventMinuteAt(_ocptAstronomicalZenithDegrees, sunrise: true),
    astronomicalDuskMinute: eventMinuteAt(_ocptAstronomicalZenithDegrees, sunrise: false),
    utcOffsetUsed: offset,
  );
}

/// One sun event (a sunrise, a sunset, or a twilight's start or end), in UTC minutes from midnight
/// of the day [dayOfYear] names — solved twice, as this file's top doc comment explains: once
/// against noon's own solar position, then again against the solar position at that first estimate,
/// which is what keeps the result close to accurate away from the solstices.
///
/// Null when the sun never reaches [zenithDegrees] below the horizon that day at that latitude (a
/// summer night that never gets dark enough) or never rises above it in the first place (a winter
/// day that never gets bright enough) — both read off the same out-of-range cosine inside
/// [_ocptHourAngleRadians], which is the whole reason every [OcptSunTimes] figure is independently
/// nullable rather than the type carrying one "polar" flag: the four depths (sunrise/sunset, civil,
/// nautical, astronomical) go out of range at different latitudes, so a place can lose its
/// astronomical twilight for weeks while still having an ordinary sunrise and sunset.
double? _ocptEventUtcMinute({
  required int dayOfYear,
  required double latitudeDegrees,
  required double longitudeDegrees,
  required double zenithDegrees,
  required bool sunrise,
}) {
  double? solve(double fractionalDayOfYear) {
    final position = _ocptSolarPositionAt(fractionalDayOfYear);
    final solarNoonUtcMinute =
        720 - _ocptMinutesPerDegreeOfLongitude * longitudeDegrees - position.equationOfTimeMinutes;

    final hourAngleRadians = _ocptHourAngleRadians(
      zenithDegrees: zenithDegrees,
      latitudeDegrees: latitudeDegrees,
      declinationRadians: position.declinationRadians,
    );
    if (hourAngleRadians == null) {
      return null;
    }

    final halfDayMinutes = _ocptMinutesPerDegreeOfLongitude * hourAngleRadians * 180 / math.pi;
    return sunrise ? solarNoonUtcMinute - halfDayMinutes : solarNoonUtcMinute + halfDayMinutes;
  }

  final firstPassMinute = solve((dayOfYear - 1).toDouble());
  if (firstPassMinute == null) {
    return null;
  }

  // The second pass' own fractional day of year is where the first pass placed the event, not
  // where it started looking (noon): a sunrise several hours before noon is solved again against
  // the sun's position at that earlier hour.
  return solve((dayOfYear - 1) + firstPassMinute / 1440) ?? firstPassMinute;
}

/// The declination and the equation of time for [fractionalDayOfYear] — 0 at midnight of 1 January,
/// growing by a full unit per day — the two quantities every [_ocptEventUtcMinute] pass needs and
/// the only place either is computed.
({double equationOfTimeMinutes, double declinationRadians}) _ocptSolarPositionAt(
  double fractionalDayOfYear,
) {
  final fractionalYear = 2 * math.pi / 365 * fractionalDayOfYear;

  final equationOfTimeMinutes =
      229.18 *
      (0.000075 +
          0.001868 * math.cos(fractionalYear) -
          0.032077 * math.sin(fractionalYear) -
          0.014615 * math.cos(2 * fractionalYear) -
          0.040849 * math.sin(2 * fractionalYear));

  final declinationRadians =
      0.006918 -
      0.399912 * math.cos(fractionalYear) +
      0.070257 * math.sin(fractionalYear) -
      0.006758 * math.cos(2 * fractionalYear) +
      0.000907 * math.sin(2 * fractionalYear) -
      0.002697 * math.cos(3 * fractionalYear) +
      0.00148 * math.sin(3 * fractionalYear);

  return (equationOfTimeMinutes: equationOfTimeMinutes, declinationRadians: declinationRadians);
}

/// The half-day length as an hour angle, in radians and always non-negative when it exists: how
/// long before and after solar noon the sun takes to reach [zenithDegrees] below the horizon, given
/// [declinationRadians] (see [_ocptSolarPositionAt]).
///
/// Null exactly when the cosine this solves for falls outside `[-1, 1]` — the sun never reaches
/// that depth, or never rises above it, that day at that latitude.
double? _ocptHourAngleRadians({
  required double zenithDegrees,
  required double latitudeDegrees,
  required double declinationRadians,
}) {
  final zenithRadians = zenithDegrees * math.pi / 180;
  final latitudeRadians = latitudeDegrees * math.pi / 180;

  final cosineOfHourAngle =
      math.cos(zenithRadians) / (math.cos(latitudeRadians) * math.cos(declinationRadians)) -
      math.tan(latitudeRadians) * math.tan(declinationRadians);

  if (cosineOfHourAngle < -1 || cosineOfHourAngle > 1) {
    return null;
  }

  return math.acos(cosineOfHourAngle);
}

/// [local]'s ordinal day within its own year, 1 for 1 January.
int _ocptDayOfYear(DateTime local) =>
    DateTime(local.year, local.month, local.day).difference(DateTime(local.year)).inDays + 1;
