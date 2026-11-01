// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_unavailability.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_scene_effect_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'ocpt_schedule_plan_snapshot_test_doubles.dart';

/// Builds a permit document (an `assets` row of kind [OcptAssetKind.document]) with the few fields
/// these tests read, everything else neutral.
OcptAssetRef _buildPermitDocument({
  required String id,
  required String locationId,
  DateTime? validFrom,
  DateTime? validUntil,
}) => OcptAssetRef(
  id: id,
  kind: OcptAssetKind.document,
  path: "",
  label: "",
  addedAt: DateTime(2026),
  personId: null,
  locationId: locationId,
  elementId: null,
  validFrom: validFrom,
  validUntil: validUntil,
);

/// Builds an unavailability window with the few fields these tests read, everything else neutral.
OcptPersonUnavailability _buildUnavailability({
  required String id,
  required String personId,
  required DateTime startDate,
  required DateTime endDate,
}) => OcptPersonUnavailability(
  id: id,
  personId: personId,
  startDate: startDate,
  endDate: endDate,
  slot: OcptDayPartSlot.fullDay,
  startMinute: null,
  endMinute: null,
  reason: "",
);

/// Builds a shot list holding two scenes — `scene-1` (`INT. KITCHEN - DAY`) and `scene-2`
/// (`EXT. STREET - NIGHT`) — what `effectCategoryOfDay`'s own "mixed" test places its two shots in.
OcptShotListSnapshot _buildTwoSceneShotList({
  required List<OcptShot> sceneOneShots,
  required List<OcptShot> sceneTwoShots,
}) => OcptShotListSnapshot.build(
  screenplayId: "screenplay-1",
  sequences: [
    OcptSceneShotSequence(
      sceneId: "scene-1",
      heading: "INT. KITCHEN - DAY",
      sceneNumber: null,
      displaySceneNumber: "1",
      charStart: 0,
      charEnd: 0,
      shots: sceneOneShots,
    ),
    OcptSceneShotSequence(
      sceneId: "scene-2",
      heading: "EXT. STREET - NIGHT",
      sceneNumber: null,
      displaySceneNumber: "2",
      charStart: 0,
      charEnd: 0,
      shots: sceneTwoShots,
    ),
  ],
);

void main() {
  group("effectCategoryOfDay", () {
    test("null while nothing is placed on the day at all", () {
      final day = buildDay(id: "day-1", dayNumber: 1);
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
      );

      expect(snapshot.effectCategoryOfDay("day-1"), isNull);
    });

    test("a single category when every placed shot's own scene heading agrees", () {
      final shot = buildShot(id: "shot-1"); // scene-1: INT. KITCHEN - DAY
      final day = buildDay(id: "day-1", dayNumber: 1);
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);
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
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      expect(snapshot.effectCategoryOfDay("day-1"), OcptSceneEffectCategory.interiorDay);
    });

    test("mixed when two placed shots' own scenes disagree", () {
      final sceneOneShot = buildShot(id: "shot-1"); // INT. KITCHEN - DAY
      final sceneTwoShot = buildShot(id: "shot-2", sceneId: "scene-2"); // EXT. STREET - NIGHT
      final day = buildDay(id: "day-1", dayNumber: 1);
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);
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
            buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-2",
              durationMinutes: 60,
            ),
          ],
        },
        shotLists: [
          _buildTwoSceneShotList(sceneOneShots: [sceneOneShot], sceneTwoShots: [sceneTwoShot]),
        ],
      );

      expect(snapshot.effectCategoryOfDay("day-1"), OcptSceneEffectCategory.mixed);
    });

    test("a hold block naming a sequence with a known heading contributes nothing — only a shot "
        "block's own scene counts", () {
      final day = buildDay(id: "day-1", dayNumber: 1);
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            const OcptShootingDayBlock(
              id: "hold-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.hold,
              shotId: null,
              sceneId: "scene-1",
              candidates: [],
              label: "",
              durationMinutes: 60,
              anchorMinute: null,
              notes: "",
              crewNote: "",
            ),
          ],
        },
        shotLists: [buildShotList(shots: const [])],
      );

      expect(snapshot.effectCategoryOfDay("day-1"), isNull);
    });
  });

  group("alerts", () {
    test("a person linked to two overlapping slots surfaces as a double-booking alert", () {
      final slotA = buildSlot(
        id: "slot-a",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-a", personId: "person-1")],
      );
      final slotB = buildSlot(
        id: "slot-b",
        anchorMinute: 550,
        crew: [buildCrewMember(id: "crew-2", slotId: "slot-b", personId: "person-1")],
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slotA, slotB],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(id: "block-a", slotId: "slot-a", durationMinutes: 200),
            buildBlock(id: "block-b", slotId: "slot-b", durationMinutes: 200),
          ],
        },
      );

      final alert = snapshot.alerts.whereType<OcptSchedulePersonDoubleBookedAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.personId, "person-1");
    });

    test("a shot's character matched to a role convoked nowhere surfaces the role-not-convoked "
        "alert", () {
      final role = buildRole(id: "role-1", name: "Alice");
      final shot = buildShot(id: "shot-1", characters: const ["ALICE"]);
      final slot = buildSlot(id: "slot-1", anchorMinute: 480); // nobody cast on it
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-shot",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        shotLists: [
          buildShotList(shots: [shot]),
        ],
        roles: [role],
      );

      final alert = snapshot.alerts.whereType<OcptScheduleRoleNotConvokedAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.roleId, "role-1");
      expect(alert.shotId, "shot-1");
    });

    test("a day spent rehearsing double-books a person exactly as a shooting one does", () {
      // Every alert about people is blind to what a day holds, and deliberately: a rehearsal eats
      // a person's day like a shoot does, and the plan is just as broken either way.
      final slotA = buildSlot(
        id: "slot-a",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-a", personId: "person-1")],
      );
      final slotB = buildSlot(
        id: "slot-b",
        anchorMinute: 550,
        crew: [buildCrewMember(id: "crew-2", slotId: "slot-b", personId: "person-1")],
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slotA, slotB],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-a",
              slotId: "slot-a",
              kind: OcptShootingBlockKind.rehearsal,
              durationMinutes: 200,
            ),
            buildBlock(
              id: "block-b",
              slotId: "slot-b",
              kind: OcptShootingBlockKind.rehearsal,
              durationMinutes: 200,
            ),
          ],
        },
      );

      final alert = snapshot.alerts.whereType<OcptSchedulePersonDoubleBookedAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.personId, "person-1");
    });

    test("a day of auditions raises no role-not-convoked alert, carrying no shot to call one", () {
      // The rule is about a role a **placed shot** plays, so it finds nothing on a day whose
      // timetable holds auditions alone: it needs no special case of its own, and gets none.
      final role = buildRole(id: "role-1", name: "Alice");
      final shot = buildShot(id: "shot-1", characters: const ["ALICE"]);
      final slot = buildSlot(id: "slot-1", anchorMinute: 540);
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
              durationMinutes: 20,
            ),
          ],
        },
        shotLists: [
          buildShotList(shots: [shot]),
        ],
        roles: [role],
      );

      expect(snapshot.alerts.whereType<OcptScheduleRoleNotConvokedAlert>(), isEmpty);
    });

    test("a candidate's own convocation raises nothing at all", () {
      // Deliberately, and on the guests' own argument: a candidate holds no position to lose, has
      // no daily maximum of the production's making and is not cast. Their convocation is read
      // everywhere it is owed an hour, and nowhere a rule is about somebody's work.
      final person = buildPerson(id: "person-1", firstName: "Camille");
      final candidacy = buildCandidacy(id: "candidacy-1", roleId: "role-1", person: person);
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
                  roleCandidateId: "candidacy-1",
                ),
              ],
            ),
          ],
        },
        people: [person],
        roleCandidates: [candidacy],
      );

      expect(snapshot.alerts, isEmpty);
      // And they are convoked all the same: the reading the `Convocations` tab gives is untouched
      // by the alerts saying nothing about them.
      expect(snapshot.convocationsOfDay("day-1").single.roleCandidateIds, {"candidacy-1"});
    });

    test("a location's dated permit document not covering the day surfaces the permit alert", () {
      final location = buildLocation(
        id: "location-1",
        permitDocument: _buildPermitDocument(
          id: "permit-1",
          locationId: "location-1",
          validFrom: DateTime(2026, 2),
          validUntil: DateTime(2026, 2, 28),
        ),
      );
      final slot = buildSlot(id: "slot-1", locationId: "location-1", anchorMinute: 480);
      final day = buildDay(id: "day-1", dayNumber: 1); // date: 2026-01-01, per buildDay
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        locations: [location],
      );

      final alert = snapshot.alerts.whereType<OcptSchedulePermitNotValidAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.slotId, "slot-1");
      expect(alert.locationId, "location-1");
    });

    test("a permit document recording neither date raises nothing — the same reading as no permit "
        "at all", () {
      final location = buildLocation(
        id: "location-1",
        permitDocument: _buildPermitDocument(id: "permit-1", locationId: "location-1"),
      );
      final slot = buildSlot(id: "slot-1", locationId: "location-1", anchorMinute: 480);
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        locations: [location],
      );

      expect(snapshot.alerts.whereType<OcptSchedulePermitNotValidAlert>(), isEmpty);
    });

    test("is computed once, not once per read", () {
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(days: [day], slotsByDayId: const {});

      expect(identical(snapshot.alerts, snapshot.alerts), isTrue);
    });
  });

  group("presenceCellOf", () {
    test("reads working when the person is convoked on a slot of the day", () {
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final person = buildPerson(id: "person-1");
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        people: [person],
      );

      final code = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(code, OcptPresenceCode.working);
    });

    test("a guest is never working — attending is not being convoked to work", () {
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        guests: [buildGuest(id: "guest-1", slotId: "slot-1", personId: "person-1")],
      );
      final day = buildDay(id: "day-1", dayNumber: 1);
      final person = buildPerson(id: "person-1");
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        people: [person],
      );

      final code = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(code, isNot(OcptPresenceCode.working));
    });

    test("reads unavailable when not convoked but a window covers the day's date", () {
      final day = buildDay(id: "day-1", dayNumber: 1); // 2026-01-01, per buildDay
      final person = buildPerson(
        id: "person-1",
        unavailabilities: [
          _buildUnavailability(
            id: "unavailability-1",
            personId: "person-1",
            startDate: DateTime(2025, 12, 31),
            endDate: DateTime(2026, 1, 3),
          ),
        ],
      );
      final snapshot = buildSnapshot(days: [day], slotsByDayId: const {}, people: [person]);

      final code = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(code, OcptPresenceCode.unavailable);
    });

    test("reads blank — neither convoked nor covered by a window", () {
      final day = buildDay(id: "day-1", dayNumber: 1);
      final person = buildPerson(id: "person-1");
      final snapshot = buildSnapshot(days: [day], slotsByDayId: const {}, people: [person]);

      final code = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(code, isNull);
    });
  });

  group("sceneIdsOfDay", () {
    test("the scene ids of the day's own shot blocks, deduplicated", () {
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);
      final day = buildDay(id: "day-1", dayNumber: 1);
      final shotOne = buildShot(id: "shot-1");
      final shotTwo = buildShot(id: "shot-2");
      final shotThree = buildShot(id: "shot-3", sceneId: "scene-2");
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
            ),
            buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-2",
            ),
            buildBlock(
              id: "block-3",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-3",
            ),
            // A milestone block names no shot and contributes nothing.
            buildBlock(id: "block-4", slotId: "slot-1", kind: OcptShootingBlockKind.meal),
          ],
        },
        shotLists: [
          buildShotList(shots: [shotOne, shotTwo, shotThree]),
        ],
      );

      expect(snapshot.sceneIdsOfDay("day-1"), {"scene-1", "scene-2"});
    });

    test("empty for a day with no shot block at all", () {
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(days: [day], slotsByDayId: const {});

      expect(snapshot.sceneIdsOfDay("day-1"), isEmpty);
    });
  });
}
