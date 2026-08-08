// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/utils/ocpt_crew_position_prefill.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

/// Builds a day with the few fields these tests read, everything else neutral.
OcptScheduleAlertDay _buildDay({
  required String id,
  DateTime? date,
  List<OcptScheduleAlertSlot> slots = const [],
  List<OcptTimelineOverrun> overruns = const [],
  List<OcptTimelineFixedEndMiss> fixedEndMisses = const [],
  List<OcptScheduleAlertCalledRole> calledRoles = const [],
}) => OcptScheduleAlertDay(
  id: id,
  date: date ?? DateTime(2026, 1, 5),
  slots: slots,
  overruns: overruns,
  fixedEndMisses: fixedEndMisses,
  calledRoles: calledRoles,
);

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptScheduleAlertSlot _buildSlot({
  required String id,
  required int startMinute,
  int? endMinute,
  String? locationId,
  List<OcptScheduleAlertCrewMember> crew = const [],
  Set<String> personIds = const {},
  Set<String> convokedRoleIds = const {},
}) => OcptScheduleAlertSlot(
  id: id,
  startMinute: startMinute,
  endMinute: endMinute,
  locationId: locationId,
  crew: crew,
  personIds: personIds,
  convokedRoleIds: convokedRoleIds,
);

/// Builds an unavailability window with the few fields these tests read.
OcptScheduleAlertUnavailability _buildUnavailability({
  required String id,
  DateTime? startDate,
  DateTime? endDate,
  required OcptDayPartSlot dayPart,
  int? startMinute,
  int? endMinute,
}) => OcptScheduleAlertUnavailability(
  id: id,
  startDate: startDate ?? DateTime(2026, 1, 5),
  endDate: endDate ?? DateTime(2026, 1, 5),
  dayPart: dayPart,
  startMinute: startMinute,
  endMinute: endMinute,
);

/// Builds a person with the few fields these tests read.
OcptScheduleAlertPerson _buildPerson({
  required String id,
  int? maxDailyPresenceMinutes,
  List<OcptScheduleAlertUnavailability> unavailabilities = const [],
}) => OcptScheduleAlertPerson(
  id: id,
  maxDailyPresenceMinutes: maxDailyPresenceMinutes,
  unavailabilities: unavailabilities,
);

/// Builds a location window with the few fields these tests read; covers every weekday and just
/// the one date by default.
OcptScheduleAlertLocationWindow _buildLocationWindow({
  DateTime? startDate,
  DateTime? endDate,
  int weekdays = ocptEveryWeekdayMask,
  required OcptDayPartSlot dayPart,
  int? startMinute,
  int? endMinute,
}) => OcptScheduleAlertLocationWindow(
  startDate: startDate ?? DateTime(2026, 1, 5),
  endDate: endDate ?? DateTime(2026, 1, 5),
  weekdays: weekdays,
  dayPart: dayPart,
  startMinute: startMinute,
  endMinute: endMinute,
);

void main() {
  group("rule 1 — a person convoked on a day they are unavailable", () {
    test("a full-day unavailability fires for every slot the person is linked to", () {
      final slot = _buildSlot(id: "slot-1", startMinute: 480, endMinute: 600, personIds: {"p1"});
      final day = _buildDay(id: "day-1", slots: [slot]);
      final person = _buildPerson(
        id: "p1",
        unavailabilities: [_buildUnavailability(id: "u1", dayPart: OcptDayPartSlot.fullDay)],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: [person],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      final alert = alerts.whereType<OcptSchedulePersonUnavailableAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.personId, "p1");
      expect(alert.unavailabilityId, "u1");
      expect(alert.slotIds, ["slot-1"]);
    });

    test("an afternoon unavailability fires for a night slot running past 1440", () {
      // 19:00 -> 03:00 the next morning, stored as 1140 -> 1620 (never wrapped).
      final slot = _buildSlot(id: "slot-1", startMinute: 1140, endMinute: 1620, personIds: {"p1"});
      final day = _buildDay(id: "day-1", slots: [slot]);
      final person = _buildPerson(
        id: "p1",
        unavailabilities: [_buildUnavailability(id: "u1", dayPart: OcptDayPartSlot.afternoon)],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: [person],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePersonUnavailableAlert>(), hasLength(1));
    });

    test("a morning unavailability does not fire for that same night slot", () {
      final slot = _buildSlot(id: "slot-1", startMinute: 1140, endMinute: 1620, personIds: {"p1"});
      final day = _buildDay(id: "day-1", slots: [slot]);
      final person = _buildPerson(
        id: "p1",
        unavailabilities: [_buildUnavailability(id: "u1", dayPart: OcptDayPartSlot.morning)],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: [person],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePersonUnavailableAlert>(), isEmpty);
    });

    test("does not fire when the window's date range misses the day's own date", () {
      final slot = _buildSlot(id: "slot-1", startMinute: 480, endMinute: 600, personIds: {"p1"});
      final day = _buildDay(id: "day-1", date: DateTime(2026, 1, 5), slots: [slot]);
      final person = _buildPerson(
        id: "p1",
        unavailabilities: [
          _buildUnavailability(
            id: "u1",
            startDate: DateTime(2026, 1, 6),
            endDate: DateTime(2026, 1, 6),
            dayPart: OcptDayPartSlot.fullDay,
          ),
        ],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: [person],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePersonUnavailableAlert>(), isEmpty);
    });

    test("does not fire for a person not linked to any slot of the day", () {
      final slot = _buildSlot(id: "slot-1", startMinute: 480, endMinute: 600, personIds: {"p2"});
      final day = _buildDay(id: "day-1", slots: [slot]);
      final person = _buildPerson(
        id: "p1",
        unavailabilities: [_buildUnavailability(id: "u1", dayPart: OcptDayPartSlot.fullDay)],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: [person],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePersonUnavailableAlert>(), isEmpty);
    });
  });

  group("rule 2 — a person linked to two overlapping slots of one day", () {
    test("fires when the two slots' own bands strictly overlap", () {
      final slotA = _buildSlot(id: "slot-a", startMinute: 480, endMinute: 600, personIds: {"p1"});
      final slotB = _buildSlot(id: "slot-b", startMinute: 550, endMinute: 650, personIds: {"p1"});
      final day = _buildDay(id: "day-1", slots: [slotA, slotB]);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      final alert = alerts.whereType<OcptSchedulePersonDoubleBookedAlert>().single;
      expect(alert.personId, "p1");
      expect(alert.firstSlotId, "slot-a");
      expect(alert.secondSlotId, "slot-b");
    });

    test("does not fire when two slots merely meet end-to-start", () {
      final slotA = _buildSlot(id: "slot-a", startMinute: 480, endMinute: 600, personIds: {"p1"});
      final slotB = _buildSlot(id: "slot-b", startMinute: 600, endMinute: 700, personIds: {"p1"});
      final day = _buildDay(id: "day-1", slots: [slotA, slotB]);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePersonDoubleBookedAlert>(), isEmpty);
    });

    test("does not fire when one of the slots carries no block at all", () {
      final slotA = _buildSlot(id: "slot-a", startMinute: 480, personIds: {"p1"}); // no endMinute
      final slotB = _buildSlot(id: "slot-b", startMinute: 470, endMinute: 600, personIds: {"p1"});
      final day = _buildDay(id: "day-1", slots: [slotA, slotB]);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePersonDoubleBookedAlert>(), isEmpty);
    });
  });

  group("rule 3 — a slot whose location has no window covering it", () {
    test("fires when a declared window doesn't match the day's own weekday", () {
      final slot = _buildSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        locationId: "loc-1",
      );
      final day = _buildDay(id: "day-1", slots: [slot]);
      final window = _buildLocationWindow(weekdays: 0, dayPart: OcptDayPartSlot.fullDay);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: {"loc-1": [window]},
      );

      final alert = alerts.whereType<OcptScheduleLocationUncoveredAlert>().single;
      expect(alert.slotId, "slot-1");
      expect(alert.locationId, "loc-1");
    });

    test("does not fire when a declared window fully covers the slot's band", () {
      final slot = _buildSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        locationId: "loc-1",
      );
      final day = _buildDay(id: "day-1", slots: [slot]);
      final window = _buildLocationWindow(dayPart: OcptDayPartSlot.fullDay);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: {"loc-1": [window]},
      );

      expect(alerts.whereType<OcptScheduleLocationUncoveredAlert>(), isEmpty);
    });

    test("does not fire when the location declares no window at all", () {
      final slot = _buildSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        locationId: "loc-1",
      );
      final day = _buildDay(id: "day-1", slots: [slot]);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptScheduleLocationUncoveredAlert>(), isEmpty);
    });
  });

  group("rule 4 — a position lost between two slots of one day", () {
    const gaffer = OcptCrewPositionRef(positionId: "gaffer", customLabel: "");

    test("fires when the position held on one slot is held by nobody on the next", () {
      final slot1 = _buildSlot(
        id: "slot-1",
        startMinute: 480,
        crew: [const OcptScheduleAlertCrewMember(personId: "p1", position: gaffer)],
      );
      final slot2 = _buildSlot(id: "slot-2", startMinute: 720);
      final day = _buildDay(id: "day-1", slots: [slot1, slot2]);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      final alert = alerts.whereType<OcptSchedulePositionLostAlert>().single;
      expect(alert.personId, "p1");
      expect(alert.slotId, "slot-2");
      expect(alert.position, gaffer);
    });

    test("does not fire when the position is still held, even by someone else", () {
      final slot1 = _buildSlot(
        id: "slot-1",
        startMinute: 480,
        crew: [const OcptScheduleAlertCrewMember(personId: "p1", position: gaffer)],
      );
      final slot2 = _buildSlot(
        id: "slot-2",
        startMinute: 720,
        crew: [const OcptScheduleAlertCrewMember(personId: "p2", position: gaffer)],
      );
      final day = _buildDay(id: "day-1", slots: [slot1, slot2]);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePositionLostAlert>(), isEmpty);
    });

    test("does not fire on a day with a single slot", () {
      final slot1 = _buildSlot(
        id: "slot-1",
        startMinute: 480,
        crew: [const OcptScheduleAlertCrewMember(personId: "p1", position: gaffer)],
      );
      final day = _buildDay(id: "day-1", slots: [slot1]);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePositionLostAlert>(), isEmpty);
    });
  });

  group("rule 5 — a role called for but convoked in no slot of the day", () {
    test("fires when the role is convoked on no slot at all", () {
      final slot = _buildSlot(id: "slot-1", startMinute: 480);
      final day = _buildDay(
        id: "day-1",
        slots: [slot],
        calledRoles: [const OcptScheduleAlertCalledRole(roleId: "role-1", shotId: "shot-1")],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      final alert = alerts.whereType<OcptScheduleRoleNotConvokedAlert>().single;
      expect(alert.roleId, "role-1");
      expect(alert.shotId, "shot-1");
    });

    test("does not fire when the role is convoked on one slot but not another", () {
      final slot1 = _buildSlot(id: "slot-1", startMinute: 480, convokedRoleIds: {"role-1"});
      final slot2 = _buildSlot(id: "slot-2", startMinute: 720);
      final day = _buildDay(
        id: "day-1",
        slots: [slot1, slot2],
        calledRoles: [const OcptScheduleAlertCalledRole(roleId: "role-1", shotId: "shot-1")],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptScheduleRoleNotConvokedAlert>(), isEmpty);
    });
  });

  group("rule 6 — a role with no actor", () {
    test("fires for an uncast role convoked on a slot", () {
      final slot = _buildSlot(id: "slot-1", startMinute: 480, convokedRoleIds: {"role-1"});
      final day = _buildDay(id: "day-1", slots: [slot]);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: [const OcptScheduleAlertRole(id: "role-1", personId: null)],
        locationWindowsByLocationId: const {},
      );

      final alert = alerts.whereType<OcptScheduleRoleUncastAlert>().single;
      expect(alert.roleId, "role-1");
      expect(alert.dayId, isNull);
    });

    test("does not fire when the role is cast", () {
      final slot = _buildSlot(id: "slot-1", startMinute: 480, convokedRoleIds: {"role-1"});
      final day = _buildDay(id: "day-1", slots: [slot]);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: [const OcptScheduleAlertRole(id: "role-1", personId: "p1")],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptScheduleRoleUncastAlert>(), isEmpty);
    });

    test("does not fire for an uncast role the schedule never uses", () {
      final day = _buildDay(id: "day-1");

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: [const OcptScheduleAlertRole(id: "role-1", personId: null)],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptScheduleRoleUncastAlert>(), isEmpty);
    });
  });

  group("rule 7 — a timeline over-run against a pinned anchor", () {
    test("fires once per OcptTimelineOverrun of the day", () {
      final day = _buildDay(
        id: "day-1",
        overruns: [
          const OcptTimelineOverrun(blockId: "block-1", reachedMinute: 600, anchorMinute: 550),
        ],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      final alert = alerts.whereType<OcptScheduleTimelineOverrunAlert>().single;
      expect(alert.blockId, "block-1");
      expect(alert.reachedMinute, 600);
      expect(alert.anchorMinute, 550);
    });

    test("does not fire on a day with no over-run", () {
      final day = _buildDay(id: "day-1");

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptScheduleTimelineOverrunAlert>(), isEmpty);
    });
  });

  group("rule 8 — a slot whose fixed end its own blocks over-run", () {
    test("fires once per OcptTimelineFixedEndMiss of the day", () {
      final day = _buildDay(
        id: "day-1",
        fixedEndMisses: [
          const OcptTimelineFixedEndMiss(
            slotId: "slot-1",
            fixedEndMinute: 1080,
            actualEndMinute: 1110,
          ),
        ],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      final alert = alerts.whereType<OcptScheduleFixedEndMissedAlert>().single;
      expect(alert.slotId, "slot-1");
      expect(alert.fixedEndMinute, 1080);
      expect(alert.actualEndMinute, 1110);
    });

    test("does not fire on a day with no missed fixed end", () {
      final day = _buildDay(id: "day-1");

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptScheduleFixedEndMissedAlert>(), isEmpty);
    });
  });

  group("rule 9 — a person's day exceeding their own recorded maximum", () {
    test("fires when computed presence exceeds the recorded maximum", () {
      final slot1 = _buildSlot(id: "slot-1", startMinute: 480, endMinute: 540, personIds: {"p1"});
      final slot2 = _buildSlot(id: "slot-2", startMinute: 900, endMinute: 1140, personIds: {"p1"});
      final day = _buildDay(id: "day-1", slots: [slot1, slot2]);
      final person = _buildPerson(id: "p1", maxDailyPresenceMinutes: 600);

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: [person],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      final alert = alerts.whereType<OcptSchedulePresenceExceededAlert>().single;
      expect(alert.personId, "p1");
      expect(alert.presenceMinutes, 660); // 1140 - 480
      expect(alert.maxDailyPresenceMinutes, 600);
    });

    test("does not fire when computed presence exactly equals the recorded maximum", () {
      final slot = _buildSlot(id: "slot-1", startMinute: 480, endMinute: 1080, personIds: {"p1"});
      final day = _buildDay(id: "day-1", slots: [slot]);
      final person = _buildPerson(id: "p1", maxDailyPresenceMinutes: 600); // exactly 1080-480

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: [person],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePresenceExceededAlert>(), isEmpty);
    });

    test("does not fire when nobody has recorded a maximum for that person", () {
      final slot = _buildSlot(id: "slot-1", startMinute: 480, endMinute: 1200, personIds: {"p1"});
      final day = _buildDay(id: "day-1", slots: [slot]);
      final person = _buildPerson(id: "p1"); // maxDailyPresenceMinutes left null

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: [person],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.whereType<OcptSchedulePresenceExceededAlert>(), isEmpty);
    });
  });

  group("ordering", () {
    test("hard alerts sort before soft ones regardless of day order", () {
      final softDay = _buildDay(
        id: "day-1",
        overruns: [
          const OcptTimelineOverrun(blockId: "block-1", reachedMinute: 600, anchorMinute: 550),
        ],
      );
      final hardDay = _buildDay(
        id: "day-2",
        slots: [
          _buildSlot(id: "slot-a", startMinute: 480, endMinute: 600, personIds: {"p1"}),
          _buildSlot(id: "slot-b", startMinute: 550, endMinute: 650, personIds: {"p1"}),
        ],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [softDay, hardDay],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.first, isA<OcptSchedulePersonDoubleBookedAlert>());
      expect(alerts.first.severity, OcptScheduleAlertSeverity.hard);
      expect(alerts.last, isA<OcptScheduleTimelineOverrunAlert>());
      expect(alerts.last.severity, OcptScheduleAlertSeverity.soft);
    });

    test("a role-uncast alert (no day) sorts after every real day of the same severity", () {
      final day = _buildDay(
        id: "day-1",
        slots: [_buildSlot(id: "slot-1", startMinute: 480, convokedRoleIds: {"role-1"})],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [day],
        people: const [],
        roles: [const OcptScheduleAlertRole(id: "role-1", personId: null)],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.single, isA<OcptScheduleRoleUncastAlert>());
    });
  });

  group("an empty schedule", () {
    test("raises no alert at all", () {
      expect(
        ocptComputeScheduleAlerts(
          days: const [],
          people: const [],
          roles: const [],
          locationWindowsByLocationId: const {},
        ),
        isEmpty,
      );
    });
  });

  group("ocptGroupScheduleAlertsByDay", () {
    test("groups every alert under the day it concerns, keeping the order it was given", () {
      final hardDay = _buildDay(
        id: "day-1",
        slots: [
          _buildSlot(id: "slot-a", startMinute: 480, endMinute: 600, personIds: {"p1"}),
          _buildSlot(id: "slot-b", startMinute: 550, endMinute: 650, personIds: {"p1"}),
        ],
      );
      final softDay = _buildDay(
        id: "day-2",
        overruns: [
          const OcptTimelineOverrun(blockId: "block-1", reachedMinute: 600, anchorMinute: 550),
        ],
      );

      final alerts = ocptComputeScheduleAlerts(
        days: [hardDay, softDay],
        people: const [],
        roles: const [],
        locationWindowsByLocationId: const {},
      );
      final grouped = ocptGroupScheduleAlertsByDay(alerts);

      expect(grouped.keys, unorderedEquals(["day-1", "day-2"]));
      expect(grouped["day-1"]!.single, isA<OcptSchedulePersonDoubleBookedAlert>());
      expect(grouped["day-2"]!.single, isA<OcptScheduleTimelineOverrunAlert>());
    });

    test("a day raising nothing has no entry at all", () {
      final grouped = ocptGroupScheduleAlertsByDay(
        ocptComputeScheduleAlerts(
          days: [_buildDay(id: "day-1", slots: [_buildSlot(id: "slot-1", startMinute: 480)])],
          people: const [],
          roles: const [],
          locationWindowsByLocationId: const {},
        ),
      );

      expect(grouped, isEmpty);
    });

    test("a role-uncast alert marks no day, its casting being nobody's day in particular", () {
      final alerts = ocptComputeScheduleAlerts(
        days: [
          _buildDay(
            id: "day-1",
            slots: [_buildSlot(id: "slot-1", startMinute: 480, convokedRoleIds: {"role-1"})],
          ),
        ],
        people: const [],
        roles: [const OcptScheduleAlertRole(id: "role-1", personId: null)],
        locationWindowsByLocationId: const {},
      );

      expect(alerts.single, isA<OcptScheduleRoleUncastAlert>());
      expect(ocptGroupScheduleAlertsByDay(alerts), isEmpty);
    });
  });
}
