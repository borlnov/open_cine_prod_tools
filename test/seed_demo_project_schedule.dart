// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'ocpt_result_expectations.dart';

/// Seeds the shooting schedule: three days, their slots, convocations and blocks.
Future<void> seedSchedule({
  required String boatSetId,
  required String cafeSetId,
  required Map<String, String> crewIds,
  required OcptProjectDatabase database,
  required String harbourId,
  required String pierSetId,
  required Map<String, String> roleIdByName,
  required List<String> sceneIds,
  required OcptScheduleService scheduleService,
  required String seaId,
  required Map<int, List<String>> shotsByScene,
}) async {
  // ------------------------------------------------------------------------------- the schedule

  /// The id of the slot [OcptScheduleService.createDay] minted with day [dayId].
  Future<String> firstSlotOf(String dayId) async {
    final rows =
        await (database.select(database.ocptShootingSlotsTable)
              ..where((row) => row.shootingDayId.equals(dayId))
              ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
            .get();
    return rows.firstWhere((row) => !row.isDeleted).id;
  }

  /// Pins slot [slotId] to start at [minute] past its day's own midnight.
  Future<void> startAt(String slotId, int minute) => scheduleService
      .setSlotAnchor(
        database: database,
        slotId: slotId,
        edge: OcptShootingSlotAnchorEdge.start,
        minute: minute,
      )
      .valueOrFail;

  /// Convokes [positionIds] and [roleNames] on slot [slotId].
  Future<void> convoke(
    String slotId, {
    required List<String> positionIds,
    required List<String> roleNames,
  }) async {
    for (final positionId in positionIds) {
      await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: crewIds[positionId]!)
          .maybeValueOrFail;
    }
    for (final roleName in roleNames) {
      await scheduleService
          .addSlotCastRole(database: database, slotId: slotId, roleId: roleIdByName[roleName]!)
          .maybeValueOrFail;
    }
  }

  /// Appends a milestone block of [kind] lasting [minutes] to slot [slotId].
  Future<void> milestone(
    String slotId,
    OcptShootingBlockKind kind,
    int minutes, {
    String label = "",
    String crewNote = "",
  }) async {
    final blockId = (await scheduleService
        .createBlock(
          database: database,
          slotId: slotId,
          kind: kind,
          label: label,
          durationMinutes: minutes,
        )
        .valueOrFail);
    if (crewNote.isNotEmpty) {
      await scheduleService
          .updateBlock(database: database, blockId: blockId, crewNote: Value(crewNote))
          .okOrFail;
    }
  }

  /// Places shot [shotId] on slot [slotId] for [minutes] of shooting time.
  Future<void> place(String slotId, String shotId, int minutes) async {
    final blockId = (await scheduleService
        .placeShot(database: database, slotId: slotId, shotId: shotId)
        .valueOrFail);
    await scheduleService
        .updateBlock(database: database, blockId: blockId, durationMinutes: Value(minutes))
        .okOrFail;
  }

  // Day 1 — the cafe in the morning, the pier in the afternoon.
  final day1 = (await scheduleService
      .createDay(database: database, date: DateTime(2026, 9, 15))
      .valueOrFail);
  await scheduleService
      .updateDay(
        database: database,
        dayId: day1,
        crewNote: const Value(
          "Unit base behind the fish market. The cafe opens to the public at 12:00 — everything "
          "inside is shot before that.",
        ),
        weatherNote: const Value("Rain until 09:00, clearing westerly 4."),
      )
      .okOrFail;
  final day1Cafe = await firstSlotOf(day1);
  await scheduleService
      .updateSlot(
        database: database,
        slotId: day1Cafe,
        label: const Value("Unit 1 — cafe"),
        locationId: Value(harbourId),
        setId: Value(cafeSetId),
        notes: const Value("Key holder: Mme Quéré, 06:30 on the terrace."),
      )
      .okOrFail;
  await startAt(day1Cafe, 7 * 60);
  await convoke(
    day1Cafe,
    positionIds: const [
      "director",
      "firstAssistantDirector",
      "directorOfPhotography",
      "scriptSupervisor",
      "soundEngineer",
      "gaffer",
      "makeupArtist",
      "productionManager",
    ],
    roleNames: const ["NORA", "OWNER"],
  );
  await scheduleService
      .addSlotGuest(
        database: database,
        slotId: day1Cafe,
        freeName: "Harbour master",
        reason: "Lends the quay, 08:00",
      )
      .maybeValueOrFail;
  await milestone(day1Cafe, OcptShootingBlockKind.preparation, 45, label: "Set up");
  await milestone(
    day1Cafe,
    OcptShootingBlockKind.hairMakeUp,
    45,
    crewNote: "Nora arrives wet — hair kept damp all morning.",
  );
  await place(day1Cafe, shotsByScene[0]![0], 60);
  await place(day1Cafe, shotsByScene[0]![1], 45);
  await milestone(day1Cafe, OcptShootingBlockKind.meal, 60, label: "Lunch");
  await place(day1Cafe, shotsByScene[0]![2], 40);
  await place(day1Cafe, shotsByScene[0]![3], 40);
  await milestone(day1Cafe, OcptShootingBlockKind.wrap, 30);

  final day1Pier = (await scheduleService
      .createSlot(
        database: database,
        shootingDayId: day1,
        anchorMinute: 13 * 60 + 30,
        label: "Unit 2 — pier",
        locationId: harbourId,
        setId: pierSetId,
        notes: "Planks are slick — grip lays matting before anybody walks out.",
      )
      .valueOrFail);
  await convoke(
    day1Pier,
    positionIds: const [
      "director",
      "firstAssistantDirector",
      "directorOfPhotography",
      "gaffer",
      "productionManager",
    ],
    roleNames: const ["NORA", "MARTIN"],
  );
  await milestone(day1Pier, OcptShootingBlockKind.travel, 20, label: "To the pier");
  await milestone(day1Pier, OcptShootingBlockKind.preparation, 40, label: "Crane set up");
  await place(day1Pier, shotsByScene[2]![0], 75);
  await place(day1Pier, shotsByScene[2]![1], 50);
  await milestone(day1Pier, OcptShootingBlockKind.wrap, 30);

  await scheduleService
      .createDayEvent(
        database: database,
        dayId: day1,
        minute: 17 * 60,
        label: "Fish auction — the quay fills up",
      )
      .maybeValueOrFail;

  // Day 2 — the rest of the cafe, then the end of the pier.
  final day2 = (await scheduleService
      .createDay(database: database, date: DateTime(2026, 9, 16))
      .valueOrFail);
  await scheduleService
      .updateDay(
        database: database,
        dayId: day2,
        weatherNote: const Value("Overcast, southerly 3, no rain expected."),
      )
      .okOrFail;
  final day2Cafe = await firstSlotOf(day2);
  await scheduleService
      .updateSlot(
        database: database,
        slotId: day2Cafe,
        label: const Value("Unit 1 — cafe"),
        locationId: Value(harbourId),
        setId: Value(cafeSetId),
      )
      .okOrFail;
  await startAt(day2Cafe, 8 * 60);
  await convoke(
    day2Cafe,
    positionIds: const [
      "director",
      "firstAssistantDirector",
      "directorOfPhotography",
      "scriptSupervisor",
      "soundEngineer",
      "makeupArtist",
    ],
    roleNames: const ["NORA", "OWNER"],
  );
  await milestone(day2Cafe, OcptShootingBlockKind.preparation, 40, label: "Set up");
  await place(day2Cafe, shotsByScene[1]![0], 50);
  await place(day2Cafe, shotsByScene[1]![1], 40);
  await milestone(day2Cafe, OcptShootingBlockKind.meal, 60, label: "Lunch");
  await milestone(day2Cafe, OcptShootingBlockKind.wrap, 30);

  final day2Pier = (await scheduleService
      .createSlot(
        database: database,
        shootingDayId: day2,
        anchorMinute: 14 * 60,
        label: "Unit 2 — pier",
        locationId: harbourId,
        setId: pierSetId,
      )
      .valueOrFail);
  await convoke(
    day2Pier,
    positionIds: const [
      "director",
      "firstAssistantDirector",
      "directorOfPhotography",
      "gaffer",
      "soundEngineer",
    ],
    roleNames: const ["NORA", "MARTIN"],
  );
  await milestone(day2Pier, OcptShootingBlockKind.travel, 20, label: "To the pier");
  await place(day2Pier, shotsByScene[2]![2], 45);
  await place(day2Pier, shotsByScene[2]![3], 60);
  await milestone(day2Pier, OcptShootingBlockKind.wrap, 30);

  // Day 3 — at sea, one unit, an early call and a hold for the sequence not yet shot-listed.
  final day3 = (await scheduleService
      .createDay(database: database, date: DateTime(2026, 9, 17))
      .valueOrFail);
  await scheduleService
      .updateDay(
        database: database,
        dayId: day3,
        status: const Value(OcptShootingDayStatus.planned),
        crewNote: const Value("Skipper decides at 05:00 whether the bay is workable."),
        weatherNote: const Value("Swell 1.5 m falling, westerly 3."),
      )
      .okOrFail;
  final day3Sea = await firstSlotOf(day3);
  await scheduleService
      .updateSlot(
        database: database,
        slotId: day3Sea,
        label: const Value("Unit 1 — at sea"),
        locationId: Value(seaId),
        setId: Value(boatSetId),
        notes: const Value("Six on board, no more. Everything else stays on the quay."),
      )
      .okOrFail;
  await startAt(day3Sea, 6 * 60);
  await convoke(
    day3Sea,
    positionIds: const [
      "director",
      "firstAssistantDirector",
      "directorOfPhotography",
      "soundEngineer",
      "productionManager",
    ],
    roleNames: const ["NORA", "MARTIN"],
  );
  await milestone(day3Sea, OcptShootingBlockKind.preparation, 45, label: "Load the boat");
  await milestone(day3Sea, OcptShootingBlockKind.travel, 40, label: "Out to the bay");
  await place(day3Sea, shotsByScene[3]![0], 70);
  await place(day3Sea, shotsByScene[3]![1], 50);
  await milestone(day3Sea, OcptShootingBlockKind.meal, 45, label: "On board");
  final holdId = (await scheduleService
      .createBlock(
        database: database,
        slotId: day3Sea,
        kind: OcptShootingBlockKind.hold,
        sceneId: sceneIds[3],
        label: "Kept for the end of the sequence",
        durationMinutes: 60,
      )
      .valueOrFail);
  expect(holdId, isNotEmpty);
  await milestone(day3Sea, OcptShootingBlockKind.travel, 40, label: "Back in");
  await milestone(day3Sea, OcptShootingBlockKind.wrap, 30);
}
