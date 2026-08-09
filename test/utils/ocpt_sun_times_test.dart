// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// How far a computed figure may sit from a published reference before a test fails — "a couple of
/// minutes", per the NOAA low-precision formula's own documented accuracy away from the poles. The
/// figures asserted against below were cross-checked against api.sunrise-sunset.org (itself an
/// independent NOAA-derived implementation) for the same coordinates and dates.
const _ocptTypicalToleranceMinutes = 3;

/// The wider tolerance a sunrise or sunset needs at a latitude where the sun crosses the horizon at
/// a very shallow angle (Reykjavik in June is close to the Arctic Circle): the same small error in
/// the sun's computed position corresponds to a much larger error in *when* it crosses a given
/// depth, because the sun is moving almost sideways rather than upward at that point in its path.
/// This is a property of the geometry, not a sign either algorithm is wrong.
const _ocptGrazingAngleToleranceMinutes = 8;

/// Fails unless [actual] is within [toleranceMinutes] of [expected], with both null read as
/// "no such event" — which must match exactly, since a wrong null is a wrong answer no tolerance
/// should paper over.
void _expectCloseTo(int? actual, int? expected, {int toleranceMinutes = _ocptTypicalToleranceMinutes}) {
  if (expected == null) {
    expect(actual, isNull);
    return;
  }
  expect(actual, isNotNull);
  expect(
    (actual! - expected).abs(),
    lessThanOrEqualTo(toleranceMinutes),
    reason: "expected $actual to be within $toleranceMinutes minutes of $expected",
  );
}

void main() {
  group("Paris — summer solstice (48.8566N, 2.3522E)", () {
    // Reference (api.sunrise-sunset.org, 2026-06-21, converted to this container's UTC clock):
    // sunrise 03:44:59, sunset 19:59:51, civil 03:04:21 / 20:40:28, nautical 02:03:37 / 21:41:12,
    // astronomical: does not occur (the sky never gets that dark this close to the solstice at
    // this latitude — see the "even a temperate city" group below).
    final result = ocptSunTimesOf(date: DateTime(2026, 6, 21), latitudeDegrees: 48.8566, longitudeDegrees: 2.3522);

    test("sunrise and sunset", () {
      _expectCloseTo(result.sunriseMinute, 225);
      _expectCloseTo(result.sunsetMinute, 1200);
    });

    test("civil and nautical twilight", () {
      _expectCloseTo(result.civilDawnMinute, 184);
      _expectCloseTo(result.civilDuskMinute, 1240);
      _expectCloseTo(result.nauticalDawnMinute, 124);
      _expectCloseTo(result.nauticalDuskMinute, 1301);
    });

    test("astronomical twilight does not occur — a mid-latitude city, not a polar one", () {
      // Paris sits at 48.85N, nowhere near the Arctic Circle, and still loses its astronomical
      // twilight for a few weeks around its own summer solstice: the sun never dips a full 18°
      // below the horizon in that short a night. This is exactly why every OcptSunTimes figure is
      // independently nullable rather than the type carrying one "polar" flag.
      _expectCloseTo(result.astronomicalDawnMinute, null);
      _expectCloseTo(result.astronomicalDuskMinute, null);
    });
  });

  group("Paris — winter solstice", () {
    // Reference: sunrise 07:39:17, sunset 15:58:01, civil 07:04:01 / 16:33:16,
    // nautical 06:23:33 / 17:13:44, astronomical 05:45:02 / 17:52:15.
    final result = ocptSunTimesOf(date: DateTime(2026, 12, 21), latitudeDegrees: 48.8566, longitudeDegrees: 2.3522);

    test("every figure is present and short-day-shaped", () {
      _expectCloseTo(result.sunriseMinute, 459);
      _expectCloseTo(result.sunsetMinute, 958);
      _expectCloseTo(result.civilDawnMinute, 424);
      _expectCloseTo(result.civilDuskMinute, 993);
      _expectCloseTo(result.nauticalDawnMinute, 384);
      _expectCloseTo(result.nauticalDuskMinute, 1034);
      _expectCloseTo(result.astronomicalDawnMinute, 345);
      _expectCloseTo(result.astronomicalDuskMinute, 1072);
    });

    test("the day is shorter than the summer solstice's", () {
      final summer = ocptSunTimesOf(
        date: DateTime(2026, 6, 21),
        latitudeDegrees: 48.8566,
        longitudeDegrees: 2.3522,
      );
      final winterDayLength = result.sunsetMinute! - result.sunriseMinute!;
      final summerDayLength = summer.sunsetMinute! - summer.sunriseMinute!;
      expect(winterDayLength, lessThan(summerDayLength));
    });
  });

  group("Paris — spring equinox", () {
    // Reference: sunrise 05:51:33, sunset 18:04:32, civil 05:21:41 / 18:34:24,
    // nautical 04:44:34 / 19:11:31, astronomical 04:06:13 / 19:49:52.
    final result = ocptSunTimesOf(date: DateTime(2026, 3, 20), latitudeDegrees: 48.8566, longitudeDegrees: 2.3522);

    test("every figure is present", () {
      _expectCloseTo(result.sunriseMinute, 352);
      _expectCloseTo(result.sunsetMinute, 1085);
      _expectCloseTo(result.civilDawnMinute, 322);
      _expectCloseTo(result.civilDuskMinute, 1114);
      _expectCloseTo(result.nauticalDawnMinute, 285);
      _expectCloseTo(result.nauticalDuskMinute, 1152);
      _expectCloseTo(result.astronomicalDawnMinute, 246);
      _expectCloseTo(result.astronomicalDuskMinute, 1190);
    });

    test("day and night are close to equal length, as the name promises", () {
      // Not exactly 12 hours: refraction and the sun's own apparent radius (both folded into the
      // 90.833° sunrise/sunset zenith) make the day a few minutes longer than the night even on
      // the equinox itself — the reference figures above already show it (sunset - sunrise is
      // about 12h13m, not 12h00m), so the assertion follows the same reference rather than the
      // idealised 12h00m the name suggests.
      final dayLength = result.sunsetMinute! - result.sunriseMinute!;
      const referenceDayLength = 1085 - 352;
      expect((dayLength - referenceDayLength).abs(), lessThan(_ocptTypicalToleranceMinutes * 2));
    });
  });

  group("Reykjavik — summer solstice, a bright night (64.1466N, -21.9426E)", () {
    // Reference: sunrise 02:47:48, sunset (the following day) 00:11:25 — i.e. 1451 minutes from
    // this day's own midnight, past the 1440 mark, exactly as a night shoot's own blocks read
    // (ocpt_shooting_day_timeline.dart). None of the three twilight phases occur as distinct
    // events: the sky never gets dark enough to lose civil twilight at all, so it stays that
    // bright the whole short "night" — Iceland's famous bright nights.
    final result = ocptSunTimesOf(
      date: DateTime(2026, 6, 21),
      latitudeDegrees: 64.1466,
      longitudeDegrees: -21.9426,
    );

    test("sunrise and sunset, sunset landing past midnight", () {
      _expectCloseTo(result.sunriseMinute, 168, toleranceMinutes: _ocptGrazingAngleToleranceMinutes);
      _expectCloseTo(result.sunsetMinute, 1451, toleranceMinutes: _ocptGrazingAngleToleranceMinutes);
      expect(result.sunsetMinute, greaterThan(1440));
    });

    test("no civil, nautical or astronomical twilight is distinct that night", () {
      _expectCloseTo(result.civilDawnMinute, null);
      _expectCloseTo(result.civilDuskMinute, null);
      _expectCloseTo(result.nauticalDawnMinute, null);
      _expectCloseTo(result.nauticalDuskMinute, null);
      _expectCloseTo(result.astronomicalDawnMinute, null);
      _expectCloseTo(result.astronomicalDuskMinute, null);
    });
  });

  group("Longyearbyen, Svalbard — the polar case (78.2232N, 15.6267E)", () {
    test("midnight sun in June: nothing crosses the horizon at all", () {
      final result = ocptSunTimesOf(date: DateTime(2026, 6, 21), latitudeDegrees: 78.2232, longitudeDegrees: 15.6267);

      expect(result.sunriseMinute, isNull);
      expect(result.sunsetMinute, isNull);
      expect(result.civilDawnMinute, isNull);
      expect(result.civilDuskMinute, isNull);
      expect(result.nauticalDawnMinute, isNull);
      expect(result.nauticalDuskMinute, isNull);
      expect(result.astronomicalDawnMinute, isNull);
      expect(result.astronomicalDuskMinute, isNull);
    });

    test("polar night in December: the sun still climbs high enough for a dim midday glow", () {
      // Reference: sunrise/sunset/civil twilight do not occur, but nautical (09:58:10 / 11:52:54)
      // and astronomical (06:37:08 / 15:13:56) twilight do — a brief, dim brightening around local
      // noon even though the sun itself never comes close to the horizon. Each figure is
      // independently nullable for exactly this reason.
      final result = ocptSunTimesOf(
        date: DateTime(2026, 12, 21),
        latitudeDegrees: 78.2232,
        longitudeDegrees: 15.6267,
      );

      expect(result.sunriseMinute, isNull);
      expect(result.sunsetMinute, isNull);
      expect(result.civilDawnMinute, isNull);
      expect(result.civilDuskMinute, isNull);
      _expectCloseTo(result.nauticalDawnMinute, 598);
      _expectCloseTo(result.nauticalDuskMinute, 713);
      _expectCloseTo(result.astronomicalDawnMinute, 397);
      _expectCloseTo(result.astronomicalDuskMinute, 914);
    });
  });

  group("Sydney — the southern hemisphere (33.8688S, 151.2093E)", () {
    test("June is winter there: a short day", () {
      // Reference: sunrise 20:58:34 the previous UTC day (this container's own offset is zero, so
      // the raw figure is negative, exactly as ocpt_day_minute.dart documents for an event before
      // local midnight), sunset 06:55:13. Seasons are flipped from the northern-hemisphere cases
      // above: December is Sydney's summer solstice, June its winter one.
      final result = ocptSunTimesOf(
        date: DateTime(2026, 6, 21),
        latitudeDegrees: -33.8688,
        longitudeDegrees: 151.2093,
      );

      _expectCloseTo(result.sunriseMinute, -181);
      _expectCloseTo(result.sunsetMinute, 415);
      expect(result.sunriseMinute, lessThan(0));
    });

    test("December is summer there: a long day, longer than June's", () {
      // Reference: sunrise 18:39:17 the previous UTC day, sunset 09:06:45.
      final december = ocptSunTimesOf(
        date: DateTime(2026, 12, 21),
        latitudeDegrees: -33.8688,
        longitudeDegrees: 151.2093,
      );
      final june = ocptSunTimesOf(date: DateTime(2026, 6, 21), latitudeDegrees: -33.8688, longitudeDegrees: 151.2093);

      _expectCloseTo(december.sunriseMinute, -321);
      _expectCloseTo(december.sunsetMinute, 547);

      final decemberDayLength = december.sunsetMinute! - december.sunriseMinute!;
      final juneDayLength = june.sunsetMinute! - june.sunriseMinute!;
      expect(decemberDayLength, greaterThan(juneDayLength));
    });
  });

  group("the offset every figure was converted through", () {
    test("is reported back, and matches the date's own local offset", () {
      final date = DateTime(2026, 6, 21);
      final result = ocptSunTimesOf(date: date, latitudeDegrees: 48.8566, longitudeDegrees: 2.3522);

      expect(result.utcOffsetUsed, date.timeZoneOffset);
    });
  });
}
