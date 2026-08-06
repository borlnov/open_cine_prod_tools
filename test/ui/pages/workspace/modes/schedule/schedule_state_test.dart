// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
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
);

void main() {
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
        shotListSnapshot: OcptShotListSnapshot.build(
          screenplayId: "screenplay-1",
          sequences: const [sceneSequence, orphanSequence],
        ),
      );

      expect(state.sceneSequences, [sceneSequence]);
    });

    test("reads empty while no shot list has loaded yet", () {
      expect(OcptScheduleState.init().sceneSequences, isEmpty);
    });
  });

  group("convocationsOfSlot", () {
    test(
      "a hold naming a scene the breakdown tagged a role in makes that role's own band follow "
      "the hold's own block rather than the whole slot",
      () {
        const slot = OcptShootingSlot(
          id: "slot-1",
          shootingDayId: "day-1",
          label: "",
          locationId: null,
          setId: null,
          startMinute: 480,
          notes: "",
          crew: [],
          cast: [
            OcptShootingSlotCastMember(
              id: "cast-1",
              slotId: "slot-1",
              roleId: "role-1",
              groupId: null,
              leadMinutes: null,
              notes: "",
            ),
          ],
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
          screenplayId: "screenplay-1",
          date: DateTime(2026),
          dayNumber: 1,
          status: OcptShootingDayStatus.planned,
          crewNote: "",
          weatherNote: "",
          notes: "",
        );
        final snapshot = OcptScheduleSnapshot.build(
          screenplayId: "screenplay-1",
          days: [day],
          groupsByDayId: const {},
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [hold, meal],
          },
        );

        final state = OcptScheduleState.init().copyWith(
          snapshot: snapshot,
          roleIdsBySceneId: const {
            "scene-1": {"role-1"},
          },
        );

        final convocations = state.convocationsOfSlot("slot-1")!;
        final castConvocation = convocations.cast.single;

        // The slot's own band (both blocks) runs 08:00 → 10:00; the hold's own block, which is what
        // names the role, only runs 08:00 → 09:00. The band tracking the hold rather than the whole
        // slot is exactly what proves a hold's roles are read out of the breakdown now, rather than
        // resolving to nothing and falling back to the slot's own bounds.
        expect(castConvocation.patStartMinute, 480);
        expect(castConvocation.patEndMinute, 540);
      },
    );

    test("a hold naming no scene leaves every role convoked keeping the slot's own bounds", () {
      const slot = OcptShootingSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        label: "",
        locationId: null,
        setId: null,
        startMinute: 480,
        notes: "",
        crew: [],
        cast: [
          OcptShootingSlotCastMember(
            id: "cast-1",
            slotId: "slot-1",
            roleId: "role-1",
            groupId: null,
            leadMinutes: null,
            notes: "",
          ),
        ],
      );
      final hold = _buildBlock(id: "block-hold", slotId: "slot-1", kind: OcptShootingBlockKind.hold);
      final day = OcptShootingDay(
        id: "day-1",
        screenplayId: "screenplay-1",
        date: DateTime(2026),
        dayNumber: 1,
        status: OcptShootingDayStatus.planned,
        crewNote: "",
        weatherNote: "",
        notes: "",
      );
      final snapshot = OcptScheduleSnapshot.build(
        screenplayId: "screenplay-1",
        days: [day],
        groupsByDayId: const {},
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [hold],
        },
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      final convocations = state.convocationsOfSlot("slot-1")!;
      final castConvocation = convocations.cast.single;

      expect(castConvocation.patStartMinute, 480);
      expect(castConvocation.patEndMinute, 510);
    });
  });

  group("placedDayNumbersByShotId", () {
    OcptShootingDay buildDay({required String id, required int dayNumber}) => OcptShootingDay(
      id: id,
      screenplayId: "screenplay-1",
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
    );

    test("a shot placed twice on the same day reports that day's number once", () {
      final day = buildDay(id: "day-1", dayNumber: 3);
      final snapshot = OcptScheduleSnapshot.build(
        screenplayId: "screenplay-1",
        days: [day],
        groupsByDayId: const {},
        slotsByDayId: const {},
        blocksByDayId: {
          "day-1": [
            buildShotBlock(id: "block-1", slotId: "slot-1", shotId: "shot-1"),
            buildShotBlock(id: "block-2", slotId: "slot-1", shotId: "shot-1"),
          ],
        },
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      expect(state.placedDayNumbersByShotId, {"shot-1": [3]});
    });

    test("a shot placed on two different days reports both, ascending", () {
      final dayThree = buildDay(id: "day-1", dayNumber: 3);
      final dayFive = buildDay(id: "day-2", dayNumber: 5);
      final snapshot = OcptScheduleSnapshot.build(
        screenplayId: "screenplay-1",
        days: [dayThree, dayFive],
        groupsByDayId: const {},
        slotsByDayId: const {},
        blocksByDayId: {
          "day-2": [buildShotBlock(id: "block-2", slotId: "slot-2", shotId: "shot-1")],
          "day-1": [buildShotBlock(id: "block-1", slotId: "slot-1", shotId: "shot-1")],
        },
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      expect(state.placedDayNumbersByShotId, {"shot-1": [3, 5]});
    });

    test("a shot with no live block placing it has no entry at all", () {
      final day = buildDay(id: "day-1", dayNumber: 3);
      final snapshot = OcptScheduleSnapshot.build(
        screenplayId: "screenplay-1",
        days: [day],
        groupsByDayId: const {},
        slotsByDayId: const {},
        blocksByDayId: const {},
      );

      final state = OcptScheduleState.init().copyWith(snapshot: snapshot);

      expect(state.placedDayNumbersByShotId, isEmpty);
    });

    test("reads empty while no schedule has loaded yet", () {
      expect(OcptScheduleState.init().placedDayNumbersByShotId, isEmpty);
    });
  });
}
