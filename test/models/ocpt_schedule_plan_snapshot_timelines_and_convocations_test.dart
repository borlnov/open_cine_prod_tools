// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'ocpt_schedule_plan_snapshot_test_doubles.dart';

void main() {
  group("timelinesOfDay", () {
    test("resolves an end-anchored slot's own hours against a start-anchored one", () {
      final startSlot = buildSlot(id: "slot-start", anchorMinute: 480);
      final endSlot = buildSlot(
        id: "slot-end",
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 720,
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [startSlot, endSlot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(id: "block-start", slotId: "slot-start", durationMinutes: 60),
            buildBlock(id: "block-end", slotId: "slot-end", durationMinutes: 90),
          ],
        },
      );

      final timelines = snapshot.timelinesOfDay("day-1")!;

      expect(timelines.bySlotId["slot-start"]!.startMinute, 480);
      expect(timelines.bySlotId["slot-start"]!.endMinute, 540);
      // The end-anchored slot starts at 720 − 90 = 630 and lands exactly on its own fixed end.
      expect(timelines.bySlotId["slot-end"]!.startMinute, 630);
      expect(timelines.bySlotId["slot-end"]!.endMinute, 720);
      expect(timelines.dayStartMinute, 480);
      expect(timelines.dayEndMinute, 720);
    });

    test("a night slot crossing midnight keeps its minutes above 1440", () {
      final slot = buildSlot(id: "slot-1", anchorMinute: 1140); // 19:00
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [buildBlock(id: "block-1", slotId: "slot-1", durationMinutes: 480)],
        },
      );

      final timeline = snapshot.timelinesOfDay("day-1")!.bySlotId["slot-1"]!;

      // 19:00 + 8h = 03:00 the next day, stored as 1620 rather than wrapped to 180.
      expect(timeline.startMinute, 1140);
      expect(timeline.endMinute, 1620);
    });
  });

  group("convocationsOfDay", () {
    test("a slot with no block gives a convoked person no PAT band, departing on arrival", () {
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      expect(convocation.personId, "person-1");
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 480);
      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
    });

    test("a person on two slots reads one band spanning both, gaps included", () {
      final morning = buildSlot(
        id: "slot-morning",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1")],
      );
      final evening = buildSlot(
        id: "slot-evening",
        anchorMinute: 1080,
        crew: [buildCrewMember(id: "crew-2", slotId: "slot-evening", personId: "person-1")],
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [morning, evening],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-morning",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
            buildBlock(
              id: "block-evening",
              slotId: "slot-evening",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-2",
              durationMinutes: 60,
            ),
          ],
        },
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      expect(convocation.arrivalMinute, 480);
      // The band spans from the morning's own shot to the evening's own, the gap between the two
      // slots included — it is not clipped to either slot alone.
      expect(convocation.patStartMinute, 480);
      expect(convocation.patEndMinute, 1140);
      expect(convocation.departureMinute, 1140);
      expect(convocation.slotIds, ["slot-morning", "slot-evening"]);
    });

    test("an uncast role gets its own convocation; a cast one resolves through roles.personId", () {
      final castRole = buildRole(id: "role-cast", name: "Alice", personId: "person-1");
      final uncastRole = buildRole(id: "role-uncast", name: "Bob");
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        cast: [
          buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-cast"),
          buildCastMember(id: "cast-2", slotId: "slot-1", roleId: "role-uncast"),
        ],
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        roles: [castRole, uncastRole],
      );

      final convocations = snapshot.convocationsOfDay("day-1");

      expect(convocations, hasLength(2));
      final castConvocation = convocations.firstWhere((c) => c.personId == "person-1");
      expect(castConvocation.roleId, isNull);
      final uncastConvocation = convocations.firstWhere((c) => c.roleId == "role-uncast");
      expect(uncastConvocation.personId, isNull);
    });

    test(
      "a guest reads as its own convocation, with an arrival and a departure but no PAT band",
      () {
        final slot = buildSlot(
          id: "slot-1",
          anchorMinute: 480,
          guests: [buildGuest(id: "guest-1", slotId: "slot-1", personId: "person-guest")],
        );
        final day = buildDay(id: "day-1", dayNumber: 1);
        final snapshot = buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [
              buildBlock(
                id: "block-1",
                slotId: "slot-1",
                kind: OcptShootingBlockKind.shot,
                shotId: "shot-1",
                durationMinutes: 60,
              ),
            ],
          },
        );

        final convocation = snapshot.convocationsOfDay("day-1").single;

        expect(convocation.isGuest, isTrue);
        expect(convocation.guestPersonId, "person-guest");
        expect(convocation.personId, isNull);
        expect(convocation.arrivalMinute, 480);
        expect(convocation.departureMinute, 540);
        expect(convocation.patStartMinute, isNull);
        expect(convocation.patEndMinute, isNull);
      },
    );

    test("a candidate convoked on a day reads a band over its auditions", () {
      final person = buildPerson(id: "person-1", firstName: "Camille");
      final candidacy = buildCandidacy(id: "candidacy-1", roleId: "role-1", person: person);
      final slot = buildSlot(id: "slot-1", anchorMinute: 540);
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(id: "block-arrival", slotId: "slot-1", durationMinutes: 15),
            buildBlock(
              id: "block-audition",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 20,
              candidates: [
                buildBlockCandidate(
                  id: "convocation-1",
                  blockId: "block-audition",
                  roleCandidateId: "candidacy-1",
                ),
              ],
            ),
          ],
        },
        people: [person],
        roleCandidates: [candidacy],
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      // Every figure comes off the audition itself, never off the slot: the fifteen minutes of
      // preparation before it belong to the unit, not to the candidate expected at 09:15.
      expect(convocation.isSeenForAPart, isTrue);
      expect(convocation.roleCandidateIds, {"candidacy-1"});
      expect(convocation.arrivalMinute, 555);
      expect(convocation.patStartMinute, 555);
      expect(convocation.patEndMinute, 575);
      expect(convocation.departureMinute, 575);
    });

    test("two candidacies on one block share its hour, each their own convocation", () {
      // Two actors of two different parts read together: one block, two rows, two convocations.
      final marie = buildPerson(id: "person-1", firstName: "Camille");
      final julien = buildPerson(id: "person-2", firstName: "Alice");
      final snapshot = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [buildSlot(id: "slot-1", anchorMinute: 600)],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-audition",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 40,
              candidates: [
                buildBlockCandidate(
                  id: "convocation-1",
                  blockId: "block-audition",
                  roleCandidateId: "candidacy-marie",
                ),
                buildBlockCandidate(
                  id: "convocation-2",
                  blockId: "block-audition",
                  roleCandidateId: "candidacy-julien",
                ),
              ],
            ),
          ],
        },
        people: [marie, julien],
        roleCandidates: [
          buildCandidacy(id: "candidacy-marie", roleId: "role-1", person: marie),
          buildCandidacy(id: "candidacy-julien", roleId: "role-2", person: julien),
        ],
      );

      final convocations = snapshot.convocationsOfDay("day-1");

      expect(convocations, hasLength(2));
      for (final convocation in convocations) {
        expect(convocation.arrivalMinute, 600);
        expect(convocation.departureMinute, 640);
      }
    });

    test("a rehearsal block opens a band exactly as a shot does", () {
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 540,
        cast: [buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-rehearsal",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.rehearsal,
              durationMinutes: 90,
            ),
          ],
        },
        roles: [buildRole(id: "role-1", name: "MARIE", personId: "person-1")],
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      expect(convocation.personId, "person-1");
      expect(convocation.patStartMinute, 540);
      expect(convocation.patEndMinute, 630);
    });

    test("an audition before a slot's shots never opens its cast's PAT band", () {
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 540,
        cast: [buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-audition",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 60,
            ),
            buildBlock(
              id: "block-shot",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        roles: [buildRole(id: "role-1", name: "MARIE", personId: "person-1")],
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      // Here from the audition's start, ready to shoot only at the first take.
      expect(convocation.arrivalMinute, 540);
      expect(convocation.patStartMinute, 600);
      expect(convocation.patEndMinute, 660);
      expect(convocation.isPatBand, isTrue);
    });

    test("a convocation onto a candidacy that has since been removed convokes nobody", () {
      // No cascade drops a `shooting_block_candidates` row when its candidacy is removed — the row
      // is read defensively instead, and drops out here.
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [buildSlot(id: "slot-1", anchorMinute: 540)],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-audition",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 20,
              candidates: [
                buildBlockCandidate(
                  id: "convocation-1",
                  blockId: "block-audition",
                  roleCandidateId: "gone",
                ),
              ],
            ),
          ],
        },
      );

      expect(snapshot.convocationsOfDay("day-1"), isEmpty);
    });
  });

  group("sunTimesOfDay", () {
    test("returns null while the day's first location has no coordinates pinned", () {
      final location = buildLocation(id: "location-1");
      final slot = buildSlot(id: "slot-1", locationId: "location-1", anchorMinute: 480);
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        locations: [location],
      );

      expect(snapshot.sunTimesOfDay("day-1"), isNull);
    });
  });

  group("a day with no live slot at all", () {
    test("firstLocationOfDay and dayArrivalMinute both answer null", () {
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(days: [day], slotsByDayId: const {});

      expect(snapshot.firstLocationOfDay("day-1"), isNull);
      expect(snapshot.dayArrivalMinute("day-1"), isNull);
      expect(snapshot.timelinesOfDay("day-1"), isNull);
      expect(snapshot.convocationsOfDay("day-1"), isEmpty);
    });
  });
}
