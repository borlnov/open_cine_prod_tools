// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_regie.dart';

void main() {
  OcptShootingDay buildDay({String id = "day-1", int dayNumber = 1, DateTime? date}) =>
      OcptShootingDay(
        id: id,
        date: date ?? DateTime(2026, 3, 2),
        dayNumber: dayNumber,
        status: OcptShootingDayStatus.planned,
        crewNote: "",
        weatherNote: "",
        notes: "",
      );

  OcptShootingSlotCrewMember buildCrew({
    String id = "crew-1",
    String slotId = "slot-1",
    required String personId,
  }) => OcptShootingSlotCrewMember(
    id: id,
    slotId: slotId,
    personId: personId,
    positionId: "gaffer",
    customLabel: "",
    notes: "",
  );

  OcptShootingSlotCastMember buildCast({
    String id = "cast-1",
    String slotId = "slot-1",
    required String roleId,
  }) => OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

  OcptShootingSlot buildSlot({
    String id = "slot-1",
    String shootingDayId = "day-1",
    List<OcptShootingSlotCrewMember> crew = const [],
    List<OcptShootingSlotCastMember> cast = const [],
  }) => OcptShootingSlot(
    id: id,
    shootingDayId: shootingDayId,
    label: "Matin",
    locationId: null,
    setId: null,
    anchorEdge: OcptShootingSlotAnchorEdge.start,
    anchorMinute: 480,
    anchorSlotId: null,
    notes: "",
    crew: crew,
    cast: cast,
    guests: const [],
  );

  OcptShootingDayBlock buildMealBlock({
    String id = "block-1",
    String dayId = "day-1",
    required String slotId,
  }) => OcptShootingDayBlock(
    id: id,
    shootingDayId: dayId,
    slotId: slotId,
    kind: OcptShootingBlockKind.meal,
    shotId: null,
    sceneId: null,
    candidates: const [],
    label: "",
    durationMinutes: null,
    anchorMinute: null,
    notes: "",
    crewNote: "",
  );

  OcptShootingDayBlock buildShotBlock({
    String id = "block-shot",
    String dayId = "day-1",
    required String slotId,
  }) => OcptShootingDayBlock(
    id: id,
    shootingDayId: dayId,
    slotId: slotId,
    kind: OcptShootingBlockKind.shot,
    shotId: "shot-1",
    sceneId: null,
    candidates: const [],
    label: "",
    durationMinutes: null,
    anchorMinute: null,
    notes: "",
    crewNote: "",
  );

  group("ocptBudgetRegieDaysOf — the buffet's own reading (unaffected)", () {
    test("a person linked to three slots of one day is counted once", () {
      final day = buildDay();
      final slots = [
        buildSlot(id: "s1", crew: [buildCrew(id: "c1", slotId: "s1", personId: "p1")]),
        buildSlot(id: "s2", crew: [buildCrew(id: "c2", slotId: "s2", personId: "p1")]),
        buildSlot(id: "s3", crew: [buildCrew(id: "c3", slotId: "s3", personId: "p1")]),
      ];

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": slots},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );

      expect(days.single.crewCount, 1);
      expect(days.single.buffetCount, 1);
    });

    test("an extra role counts as an extra, an unknown role counts as cast", () {
      final day = buildDay();
      final slot = buildSlot(
        cast: [
          buildCast(id: "ca1", roleId: "extra-role"),
          buildCast(id: "ca2", roleId: "unknown-role"),
          buildCast(id: "ca3", roleId: "speaking-role"),
        ],
      );

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: const {},
        roleKindById: const {
          "extra-role": OcptRoleKind.extra,
          "speaking-role": OcptRoleKind.speaking,
          // "unknown-role" is deliberately absent.
        },
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );

      expect(days.single.extraCount, 1);
      expect(days.single.castCount, 2);
      expect(days.single.buffetCount, 3);
    });

    test("a guest changes no count at all", () {
      final day = buildDay();
      final slot = buildSlot();

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: 1500,
        buffetPriceCents: 300,
      );

      expect(days.single.buffetCount, 0);
      expect(days.single.cost.amountCents, 0);
      expect(days.single.cost.isComplete, isTrue);
    });

    test("never reorders the days it is given", () {
      final dayB = buildDay(id: "day-b", dayNumber: 2, date: DateTime(2026, 3, 3));
      final dayA = buildDay(id: "day-a", date: DateTime(2026, 3, 2));

      final days = ocptBudgetRegieDaysOf(
        days: [dayB, dayA],
        slotsByDayId: const {},
        blocksByDayId: const {},
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: null,
        buffetPriceCents: null,
      );

      expect(days.map((d) => d.dayId), ["day-b", "day-a"]);
    });
  });

  group("ocptBudgetRegieDaysOf — meals are read off the timetable's own meal blocks", () {
    test("a day with no meal block at all reads an empty sitting list, not a zero meal", () {
      final day = buildDay();
      final slot = buildSlot(crew: [buildCrew(personId: "p1")]);

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: {
          "day-1": [buildShotBlock(slotId: "slot-1")],
        },
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: 1500,
        buffetPriceCents: null,
      );

      expect(days.single.mealSittings, isEmpty);
      expect(days.single.mealCount, 0);
    });

    test("a slot holding a lunch block and a dinner block feeds its heads twice", () {
      final day = buildDay();
      final slot = buildSlot(
        id: "s1",
        crew: [buildCrew(id: "c1", slotId: "s1", personId: "p1"), buildCrew(id: "c2", slotId: "s1", personId: "p2")],
      );

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: {
          "day-1": [
            buildMealBlock(id: "lunch", slotId: "s1"),
            buildMealBlock(id: "dinner", slotId: "s1"),
          ],
        },
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: 1000,
        buffetPriceCents: null,
      );

      final day0 = days.single;
      expect(day0.mealSittings, hasLength(2));
      expect(day0.mealSittings[0].headCount, 2);
      expect(day0.mealSittings[1].headCount, 2);
      // Fed twice: once at lunch, once at dinner.
      expect(day0.mealCount, 4);
      expect(day0.cost.amountCents, 4 * 1000);
    });

    test("two parallel slots each with their own meal block feed their own heads only", () {
      final day = buildDay();
      final slots = [
        buildSlot(id: "s1", crew: [buildCrew(id: "c1", slotId: "s1", personId: "p1")]),
        buildSlot(id: "s2", crew: [buildCrew(id: "c2", slotId: "s2", personId: "p2")]),
      ];

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": slots},
        blocksByDayId: {
          "day-1": [buildMealBlock(id: "b1", slotId: "s1"), buildMealBlock(id: "b2", slotId: "s2")],
        },
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: 1000,
        buffetPriceCents: null,
      );

      final day0 = days.single;
      expect(day0.mealSittings.map((s) => s.headCount), [1, 1]);
      expect(day0.mealCount, 2);
    });

    test("a slot with no meal block feeds nobody, even though another slot of the day does", () {
      final day = buildDay();
      final slots = [
        buildSlot(id: "s1", crew: [buildCrew(id: "c1", slotId: "s1", personId: "p1")]),
        buildSlot(id: "s2", crew: [buildCrew(id: "c2", slotId: "s2", personId: "p2")]),
      ];

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": slots},
        blocksByDayId: {
          "day-1": [buildMealBlock(id: "b1", slotId: "s1")],
        },
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: 1000,
        buffetPriceCents: null,
      );

      final day0 = days.single;
      expect(day0.mealSittings, hasLength(1));
      expect(day0.mealSittings.single.headCount, 1);
      expect(day0.mealCount, 1);
    });

    test("a person who is both crew and cast on the same meal block's slot eats once", () {
      final day = buildDay();
      final slot = buildSlot(
        id: "s1",
        crew: [buildCrew(id: "c1", slotId: "s1", personId: "p1")],
        cast: [buildCast(id: "ca1", slotId: "s1", roleId: "role-1")],
      );

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: {
          "day-1": [buildMealBlock(slotId: "s1")],
        },
        roleKindById: const {},
        // role-1 is played by the very same person already on the crew list.
        personIdByRoleId: const {"role-1": "p1"},
        mealPriceCents: 1000,
        buffetPriceCents: null,
      );

      expect(days.single.mealSittings.single.headCount, 1);
    });

    test("a role with no person recorded cannot be deduplicated, and counts on its own", () {
      final day = buildDay();
      final slot = buildSlot(
        id: "s1",
        crew: [buildCrew(id: "c1", slotId: "s1", personId: "p1")],
        cast: [buildCast(id: "ca1", slotId: "s1", roleId: "role-1")],
      );

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: {
          "day-1": [buildMealBlock(slotId: "s1")],
        },
        roleKindById: const {},
        // role-1 is not cast yet: personIdByRoleId carries no entry for it.
        personIdByRoleId: const {},
        mealPriceCents: 1000,
        buffetPriceCents: null,
      );

      // 1 crew + 1 uncastable role = 2, even though they might turn out to be the same person.
      expect(days.single.mealSittings.single.headCount, 2);
    });

    test("a meal price with no buffet price reads a real, partial cost", () {
      final day = buildDay();
      final slot = buildSlot(crew: [buildCrew(id: "c1", personId: "p1"), buildCrew(id: "c2", personId: "p2")]);

      final days = ocptBudgetRegieDaysOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: {
          "day-1": [buildMealBlock(slotId: "slot-1")],
        },
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: 1500,
        buffetPriceCents: null,
      );

      final cost = days.single.cost;
      expect(days.single.mealCount, 2);
      expect(cost.amountCents, 3000);
      expect(cost.coveredLineCount, 1);
      expect(cost.lineCount, 2);
      expect(cost.isComplete, isFalse);
    });
  });

  group("ocptBudgetRegieTotalsOf", () {
    test("folds head count, meals, buffet servings and cost across every day", () {
      final days = ocptBudgetRegieDaysOf(
        days: [buildDay(id: "d1"), buildDay(id: "d2", dayNumber: 2)],
        slotsByDayId: {
          "d1": [
            buildSlot(shootingDayId: "d1", crew: [buildCrew(personId: "p1")]),
          ],
          "d2": [
            buildSlot(
              shootingDayId: "d2",
              crew: [buildCrew(personId: "p1"), buildCrew(id: "c2", personId: "p2")],
            ),
          ],
        },
        blocksByDayId: {
          "d1": [buildMealBlock(id: "m1", dayId: "d1", slotId: "slot-1")],
          "d2": [buildMealBlock(id: "m2", dayId: "d2", slotId: "slot-1")],
        },
        roleKindById: const {},
        personIdByRoleId: const {},
        mealPriceCents: 1000,
        buffetPriceCents: 200,
      );

      final totals = ocptBudgetRegieTotalsOf(days);

      expect(totals.headCount, 3);
      expect(totals.mealCount, 3);
      expect(totals.buffetCount, 3);
      expect(totals.cost.amountCents, 3 * 1000 + 3 * 200);
      expect(totals.cost.isComplete, isTrue);
    });
  });

  group("ocptBudgetTravelRowsOf / ocptBudgetTravelTotalsOf", () {
    test("168 km at 0.529 €/km comes out at exactly 8887 cents", () {
      final day = buildDay();
      final slot = buildSlot(crew: [buildCrew(personId: "p1")]);

      final rows = ocptBudgetTravelRowsOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        personIdByRoleId: const {},
        // A single return trip: fabricate a 84 km one-way commute so returnTripCount(1) * 2 * 84000
        // is 168000 milli-km, matching the reference figure directly.
        commuteKmMilliByPersonId: const {"p1": 84000},
        mileageRateIdByPersonId: const {"p1": "rate-1"},
        ratePerKmMilliCentsByRateId: const {"rate-1": 52900},
      );

      expect(rows.single.totalKmMilli, 168000);
      expect(rows.single.amountCents, 8887);
    });

    test("3 return trips of a 28 km one-way commute agree to the cent with the direct figure", () {
      final days = [
        buildDay(id: "d1", date: DateTime(2026, 3)),
        buildDay(id: "d2", dayNumber: 2, date: DateTime(2026, 3, 2)),
        buildDay(id: "d3", dayNumber: 3, date: DateTime(2026, 3, 3)),
      ];

      final rows = ocptBudgetTravelRowsOf(
        days: days,
        slotsByDayId: {
          "d1": [buildSlot(id: "s1", shootingDayId: "d1", crew: [buildCrew(id: "c1", slotId: "s1", personId: "p1")])],
          "d2": [buildSlot(id: "s2", shootingDayId: "d2", crew: [buildCrew(id: "c2", slotId: "s2", personId: "p1")])],
          "d3": [buildSlot(id: "s3", shootingDayId: "d3", crew: [buildCrew(id: "c3", slotId: "s3", personId: "p1")])],
        },
        personIdByRoleId: const {},
        commuteKmMilliByPersonId: const {"p1": 28000},
        mileageRateIdByPersonId: const {"p1": "rate-1"},
        ratePerKmMilliCentsByRateId: const {"rate-1": 52900},
      );

      expect(rows.single.returnTripCount, 3);
      expect(rows.single.totalKmMilli, 168000);
      expect(rows.single.amountCents, 8887);
    });

    test("a person linked to two slots of the same day makes one return trip", () {
      final day = buildDay();
      final slots = [
        buildSlot(id: "s1", crew: [buildCrew(id: "c1", slotId: "s1", personId: "p1")]),
        buildSlot(id: "s2", crew: [buildCrew(id: "c2", slotId: "s2", personId: "p1")]),
      ];

      final rows = ocptBudgetTravelRowsOf(
        days: [day],
        slotsByDayId: {"day-1": slots},
        personIdByRoleId: const {},
        commuteKmMilliByPersonId: const {"p1": 10000},
        mileageRateIdByPersonId: const {},
        ratePerKmMilliCentsByRateId: const {},
      );

      expect(rows.single.returnTripCount, 1);
    });

    test("cast is resolved to the person playing the role, guests are excluded", () {
      final day = buildDay();
      final slot = buildSlot(cast: [buildCast(roleId: "role-1")]);

      final rows = ocptBudgetTravelRowsOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        personIdByRoleId: const {"role-1": "p1"},
        commuteKmMilliByPersonId: const {"p1": 5000},
        mileageRateIdByPersonId: const {},
        ratePerKmMilliCentsByRateId: const {},
      );

      expect(rows.single.personId, "p1");
    });

    test("a distance with no rate, and a rate with no distance, are both listed and both silent", () {
      final day = buildDay();
      final slot = buildSlot(
        crew: [buildCrew(id: "c1", personId: "p1"), buildCrew(id: "c2", personId: "p2")],
      );

      final rows = ocptBudgetTravelRowsOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        personIdByRoleId: const {},
        // p1 has a distance but no rate; p2 has a rate but no distance.
        commuteKmMilliByPersonId: const {"p1": 5000},
        mileageRateIdByPersonId: const {"p2": "rate-1"},
        ratePerKmMilliCentsByRateId: const {"rate-1": 52900},
      );

      final byPerson = {for (final row in rows) row.personId: row};

      expect(byPerson.containsKey("p1"), isTrue);
      expect(byPerson["p1"]!.totalKmMilli, isNotNull);
      expect(byPerson["p1"]!.amountCents, isNull);

      expect(byPerson.containsKey("p2"), isTrue);
      expect(byPerson["p2"]!.totalKmMilli, isNull);
      expect(byPerson["p2"]!.amountCents, isNull);
    });

    test("a rate id naming nothing this project holds reads silent", () {
      final day = buildDay();
      final slot = buildSlot(crew: [buildCrew(personId: "p1")]);

      final rows = ocptBudgetTravelRowsOf(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        personIdByRoleId: const {},
        commuteKmMilliByPersonId: const {"p1": 5000},
        mileageRateIdByPersonId: const {"p1": "deleted-rate"},
        ratePerKmMilliCentsByRateId: const {},
      );

      expect(rows.single.amountCents, isNull);
    });

    test("rows sort by return trip count descending, ties broken by personId", () {
      final days = [
        buildDay(id: "d1", date: DateTime(2026, 3)),
        buildDay(id: "d2", dayNumber: 2, date: DateTime(2026, 3, 2)),
      ];

      final rows = ocptBudgetTravelRowsOf(
        days: days,
        slotsByDayId: {
          "d1": [
            buildSlot(
              id: "s1",
              shootingDayId: "d1",
              crew: [
                buildCrew(id: "c1", slotId: "s1", personId: "zebra"),
                buildCrew(id: "c2", slotId: "s1", personId: "apple"),
              ],
            ),
          ],
          "d2": [buildSlot(id: "s2", shootingDayId: "d2", crew: [buildCrew(id: "c3", slotId: "s2", personId: "apple")])],
        },
        personIdByRoleId: const {},
        commuteKmMilliByPersonId: const {},
        mileageRateIdByPersonId: const {},
        ratePerKmMilliCentsByRateId: const {},
      );

      expect(rows.map((r) => r.personId), ["apple", "zebra"]);
    });

    test("totals sum distance over the rows that carry one, and fold the money", () {
      final rows = [
        const OcptBudgetTravelRow(
          personId: "p1",
          returnTripCount: 2,
          totalKmMilli: 20000,
          amountCents: 1000,
        ),
        const OcptBudgetTravelRow(
          personId: "p2",
          returnTripCount: 1,
          totalKmMilli: null,
          amountCents: null,
        ),
        const OcptBudgetTravelRow(
          personId: "p3",
          returnTripCount: 3,
          totalKmMilli: 30000,
          amountCents: 2000,
        ),
      ];

      final totals = ocptBudgetTravelTotalsOf(rows);

      expect(totals.totalKmMilli, 50000);
      expect(totals.cost.amountCents, 3000);
      expect(totals.cost.coveredLineCount, 2);
      expect(totals.cost.lineCount, 3);
      expect(totals.cost.isComplete, isFalse);
    });
  });
}
