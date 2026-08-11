// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required String id,
  required String slotId,
  OcptShootingBlockKind kind = OcptShootingBlockKind.preparation,
  String? sceneId,
  int durationMinutes = 30,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: slotId,
  kind: kind,
  shotId: null,
  sceneId: sceneId,
  label: "",
  durationMinutes: durationMinutes,
  anchorMinute: null,
  notes: "",
  crewNote: "",
);

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({required String id, required String code}) => OcptShot(
  id: id,
  screenplayId: "screenplay-1",
  sceneId: "scene-1",
  orphanedHeading: null,
  position: 0,
  shotSize: "GP",
  abbreviation: "GP",
  framing: "",
  cameraMove: "",
  lens: "",
  recordingFormat: "",
  estimatedDurationMs: null,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: OcptShotStatus.toShoot,
  difficultySet: 0,
  difficultyCamera: 0,
  difficultyActing: 0,
  difficultySound: 0,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: const [],
  coverageRanges: const [],
  code: code,
  averageDifficulty: 0,
);

void main() {
  group("unplacedGroups", () {
    test("reports each group's own episode alongside its sequence", () {
      final state = OcptScheduleState.init().copyWith(
        shotListSnapshots: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: [
              OcptSceneShotSequence(
                sceneId: "scene-1",
                heading: "INT. KITCHEN - DAY",
                sceneNumber: null,
                displaySceneNumber: "4A",
                charStart: 0,
                charEnd: 0,
                shots: [_buildShot(id: "shot-1", code: "4A/1")],
              ),
            ],
          ),
        ],
      );

      final group = state.unplacedGroups.single;
      expect(group.screenplayId, "screenplay-1");
      expect(group.sequenceId, "scene-1");
    });

    test("two orphan groups from two episodes are two distinct groups, not one", () {
      // OcptOrphanShotSequence.sequenceId is the constant "orphans", so without screenplayId the
      // pair of groups below would collide into one.
      final state = OcptScheduleState.init().copyWith(
        shotListSnapshots: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: [
              OcptOrphanShotSequence(shots: [_buildShot(id: "shot-1", code: "?/1")]),
            ],
          ),
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-2",
            sequences: [
              OcptOrphanShotSequence(shots: [_buildShot(id: "shot-2", code: "?/1")]),
            ],
          ),
        ],
      );

      expect(state.unplacedGroups, hasLength(2));
      expect(state.unplacedGroups[0].screenplayId, "screenplay-1");
      expect(state.unplacedGroups[0].sequenceId, OcptOrphanShotSequence.sequenceId);
      expect(state.unplacedGroups[1].screenplayId, "screenplay-2");
      expect(state.unplacedGroups[1].sequenceId, OcptOrphanShotSequence.sequenceId);
    });
  });

  group("sceneSequences", () {
    test("keeps every real scene and drops the orphan group", () {
      const sceneSequence = OcptSceneShotSequence(
        sceneId: "scene-1",
        heading: "INT. KITCHEN - DAY",
        sceneNumber: null,
        displaySceneNumber: "4A",
        charStart: 0,
        charEnd: 0,
        shots: [],
      );
      const orphanSequence = OcptOrphanShotSequence(shots: []);

      final state = OcptScheduleState.init().copyWith(
        shotListSnapshots: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: const [sceneSequence, orphanSequence],
          ),
        ],
      );

      expect(state.sceneSequences, [sceneSequence]);
    });

    test("reads empty while no shot list has loaded yet", () {
      expect(OcptScheduleState.init().sceneSequences, isEmpty);
    });
  });

  group("convocationsOfDay", () {
    test(
      "a hold's own block counts as shooting time, giving the role it names a band tracking it "
      "rather than the whole slot",
      () {
        const slot = OcptShootingSlot(
          id: "slot-1",
          shootingDayId: "day-1",
          label: "",
          locationId: null,
          setId: null,
          anchorEdge: OcptShootingSlotAnchorEdge.start,
          anchorMinute: 480,
          anchorSlotId: null,
          notes: "",
          crew: [],
          cast: [
            OcptShootingSlotCastMember(
              id: "cast-1",
              slotId: "slot-1",
              roleId: "role-1",
              notes: "",
            ),
          ],
          guests: [],
        );
        final hold = _buildBlock(
          id: "block-hold",
          slotId: "slot-1",
          kind: OcptShootingBlockKind.hold,
          sceneId: "scene-1",
          durationMinutes: 60,
        );
        final meal = _buildBlock(
          id: "block-meal",
          slotId: "slot-1",
          kind: OcptShootingBlockKind.meal,
          durationMinutes: 60,
        );
        final day = OcptShootingDay(
          id: "day-1",
          date: DateTime(2026),
          dayNumber: 1,
          status: OcptShootingDayStatus.planned,
          crewNote: "",
          weatherNote: "",
          notes: "",
        );
        final snapshot = OcptScheduleSnapshot.build(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [hold, meal],
          },
          eventsByDayId: const {},
        );

        final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

        final convocation = state.convocationsOfDay("day-1").single;

        // The slot's own band (both blocks) runs 08:00 → 10:00; the hold's own block, which is a
        // shooting block under ADR 0018, only runs 08:00 → 09:00 — the meal that follows it never
        // opens or closes a band.
        expect(convocation.roleId, "role-1");
        expect(convocation.patStartMinute, 480);
        expect(convocation.patEndMinute, 540);
      },
    );

    test("a slot carrying only preparation gives its role no PAT band at all", () {
      const slot = OcptShootingSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        label: "",
        locationId: null,
        setId: null,
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorMinute: 480,
        anchorSlotId: null,
        notes: "",
        crew: [],
        cast: [
          OcptShootingSlotCastMember(
            id: "cast-1",
            slotId: "slot-1",
            roleId: "role-1",
            notes: "",
          ),
        ],
        guests: [],
      );
      final preparation = _buildBlock(id: "block-1", slotId: "slot-1");
      final day = OcptShootingDay(
        id: "day-1",
        date: DateTime(2026),
        dayNumber: 1,
        status: OcptShootingDayStatus.planned,
        crewNote: "",
        weatherNote: "",
        notes: "",
      );
      final snapshot = OcptScheduleSnapshot.build(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [preparation],
        },
        eventsByDayId: const {},
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      final convocation = state.convocationsOfDay("day-1").single;

      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 510);
    });

    test("reads empty while the day has no live slot at all", () {
      expect(OcptScheduleState.init().convocationsOfDay("day-1"), isEmpty);
    });
  });

  group("dayArrivalMinute", () {
    test("the earliest of the day's own slot starts", () {
      const earlySlot = OcptShootingSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        label: "",
        locationId: null,
        setId: null,
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorMinute: 420,
        anchorSlotId: null,
        notes: "",
        crew: [],
        cast: [],
        guests: [],
      );
      const laterSlot = OcptShootingSlot(
        id: "slot-2",
        shootingDayId: "day-1",
        label: "",
        locationId: null,
        setId: null,
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorMinute: 480,
        anchorSlotId: null,
        notes: "",
        crew: [],
        cast: [],
        guests: [],
      );
      final day = OcptShootingDay(
        id: "day-1",
        date: DateTime(2026),
        dayNumber: 1,
        status: OcptShootingDayStatus.planned,
        crewNote: "",
        weatherNote: "",
        notes: "",
      );
      final snapshot = OcptScheduleSnapshot.build(
        days: [day],
        slotsByDayId: {
          "day-1": [laterSlot, earlySlot],
        },
        blocksByDayId: const {},
        eventsByDayId: const {},
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      expect(state.dayArrivalMinute("day-1"), 420);
    });

    test("an end-anchored slot's own resolved start counts, not the hour it stores", () {
      // The slot is pinned to finish at 12:00 and holds an hour of work, so it starts at 11:00 —
      // which is what a day's arrival reads, never the 720 stored on the row.
      const endAnchoredSlot = OcptShootingSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        label: "",
        locationId: null,
        setId: null,
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 720,
        anchorSlotId: null,
        notes: "",
        crew: [],
        cast: [],
        guests: [],
      );
      final day = OcptShootingDay(
        id: "day-1",
        date: DateTime(2026),
        dayNumber: 1,
        status: OcptShootingDayStatus.planned,
        crewNote: "",
        weatherNote: "",
        notes: "",
      );
      final snapshot = OcptScheduleSnapshot.build(
        days: [day],
        slotsByDayId: const {
          "day-1": [endAnchoredSlot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", slotId: "slot-1", durationMinutes: 60)],
        },
        eventsByDayId: const {},
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      expect(state.dayArrivalMinute("day-1"), 660);
    });

    test("a day with no live slot at all answers null", () {
      expect(OcptScheduleState.init().dayArrivalMinute("day-1"), isNull);
    });
  });

  group("placedDayNumbersByShotId", () {
    OcptShootingDay buildDay({required String id, required int dayNumber}) => OcptShootingDay(
      id: id,
      date: DateTime(2026, 1, dayNumber),
      dayNumber: dayNumber,
      status: OcptShootingDayStatus.planned,
      crewNote: "",
      weatherNote: "",
      notes: "",
    );

    OcptShootingDayBlock buildShotBlock({
      required String id,
      required String slotId,
      required String shotId,
    }) => OcptShootingDayBlock(
      id: id,
      shootingDayId: "irrelevant",
      slotId: slotId,
      kind: OcptShootingBlockKind.shot,
      shotId: shotId,
      sceneId: null,
      label: "",
      durationMinutes: null,
      anchorMinute: null,
      notes: "",
      crewNote: "",
    );

    test("a shot placed twice on the same day reports that day's number once", () {
      final day = buildDay(id: "day-1", dayNumber: 3);
      final snapshot = OcptScheduleSnapshot.build(
        days: [day],
        slotsByDayId: const {},
        blocksByDayId: {
          "day-1": [
            buildShotBlock(id: "block-1", slotId: "slot-1", shotId: "shot-1"),
            buildShotBlock(id: "block-2", slotId: "slot-1", shotId: "shot-1"),
          ],
        },
        eventsByDayId: const {},
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      expect(state.placedDayNumbersByShotId, {"shot-1": [3]});
    });

    test("a shot placed on two different days reports both, ascending", () {
      final dayThree = buildDay(id: "day-1", dayNumber: 3);
      final dayFive = buildDay(id: "day-2", dayNumber: 5);
      final snapshot = OcptScheduleSnapshot.build(
        days: [dayThree, dayFive],
        slotsByDayId: const {},
        blocksByDayId: {
          "day-2": [buildShotBlock(id: "block-2", slotId: "slot-2", shotId: "shot-1")],
          "day-1": [buildShotBlock(id: "block-1", slotId: "slot-1", shotId: "shot-1")],
        },
        eventsByDayId: const {},
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      expect(state.placedDayNumbersByShotId, {"shot-1": [3, 5]});
    });

    test("a shot with no live block placing it has no entry at all", () {
      final day = buildDay(id: "day-1", dayNumber: 3);
      final snapshot = OcptScheduleSnapshot.build(
        days: [day],
        slotsByDayId: const {},
        blocksByDayId: const {},
        eventsByDayId: const {},
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      expect(state.placedDayNumbersByShotId, isEmpty);
    });

    test("reads empty while no schedule has loaded yet", () {
      expect(OcptScheduleState.init().placedDayNumbersByShotId, isEmpty);
    });
  });
}
