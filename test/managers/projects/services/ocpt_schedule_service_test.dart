// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const scheduleService = OcptScheduleService();
  const peopleService = OcptPeopleService();
  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Inserts the screenplay every day/slot/shot in these tests hangs off.
  Future<void> insertScreenplay() => database
      .into(database.ocptScreenplaysTable)
      .insert(
        OcptScreenplaysTableCompanion.insert(
          id: screenplayId,
          title: "Draft",
          updatedAt: DateTime.now(),
        ),
      );

  /// Inserts a role, satisfying `shooting_slot_cast.roleId`'s foreign key without going through
  /// `OcptRoleIndexService`'s reconciliation, exactly as `ocpt_breakdown_service_test.dart` does.
  Future<String> createRole(String id, {String name = "LÉA"}) async {
    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(
            id: id,
            screenplayId: screenplayId,
            name: name,
            kind: OcptRoleKind.silent,
          ),
        );
    return id;
  }

  /// Inserts an orphaned shot (no scene), satisfying `shooting_day_blocks.shotId`'s foreign key
  /// without the shot list's own scene machinery, which this service has no business exercising.
  Future<String> createShot(String id) async {
    await database
        .into(database.ocptShotsTable)
        .insert(OcptShotsTableCompanion.insert(id: id, screenplayId: screenplayId, position: 0));
    return id;
  }

  /// The day row [id], tombstoned or not.
  Future<OcptShootingDayRow> readDay(String id) => (database.select(
    database.ocptShootingDaysTable,
  )..where((row) => row.id.equals(id))).getSingle();

  /// Every group row of day [dayId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingDayGroupRow>> readAllGroups(String dayId) =>
      (database.select(database.ocptShootingDayGroupsTable)
            ..where((row) => row.shootingDayId.equals(dayId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every live group row of day [dayId], in `sortKey` order.
  Future<List<OcptShootingDayGroupRow>> readLiveGroups(String dayId) async =>
      (await readAllGroups(dayId)).where((row) => !row.isDeleted).toList();

  /// Every slot row of day [dayId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingSlotRow>> readAllSlots(String dayId) =>
      (database.select(database.ocptShootingSlotsTable)
            ..where((row) => row.shootingDayId.equals(dayId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every live slot row of day [dayId], in `sortKey` order.
  Future<List<OcptShootingSlotRow>> readLiveSlots(String dayId) async =>
      (await readAllSlots(dayId)).where((row) => !row.isDeleted).toList();

  /// Every crew row of slot [slotId], tombstoned or not.
  Future<List<OcptShootingSlotCrewRow>> readAllCrew(String slotId) =>
      (database.select(database.ocptShootingSlotCrewTable)
            ..where((row) => row.slotId.equals(slotId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every cast row of slot [slotId], tombstoned or not.
  Future<List<OcptShootingSlotCastRow>> readAllCast(String slotId) =>
      (database.select(database.ocptShootingSlotCastTable)
            ..where((row) => row.slotId.equals(slotId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every block row of day [dayId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingDayBlockRow>> readAllBlocks(String dayId) =>
      (database.select(database.ocptShootingDayBlocksTable)
            ..where((row) => row.shootingDayId.equals(dayId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// The block row [id], tombstoned or not.
  Future<OcptShootingDayBlockRow> readBlock(String id) => (database.select(
    database.ocptShootingDayBlocksTable,
  )..where((row) => row.id.equals(id))).getSingle();

  group("days", () {
    setUp(insertScreenplay);

    test(
      "createDay mints exactly one slot with the default start minute, and no groups when "
      "there is no previous day",
      () async {
        final dayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ))!;

        final slots = await readLiveSlots(dayId);
        expect(slots, hasLength(1));
        expect(slots.single.label, "");
        expect(slots.single.startMinute, 480);

        expect(await readLiveGroups(dayId), isEmpty);
      },
    );

    test("createDay copies the previous day's groups, labels and figures alike", () async {
      final firstDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final sourceGroupId = (await scheduleService.createGroup(
        database: database,
        shootingDayId: firstDayId,
        label: "Machinerie",
        leadMinutes: 20,
      ))!;

      final secondDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;

      final copiedGroups = await readLiveGroups(secondDayId);
      expect(copiedGroups, hasLength(1));
      expect(copiedGroups.single.id, isNot(sourceGroupId));
      expect(copiedGroups.single.label, "Machinerie");
      expect(copiedGroups.single.leadMinutes, 20);

      // The source group is untouched, and the two are independent from here on.
      final sourceGroups = await readLiveGroups(firstDayId);
      expect(sourceGroups.single.id, sourceGroupId);
    });

    test("loadSchedule ranks days by sortKey and updates after a reorder", () async {
      final firstId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final secondId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;
      final thirdId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 12),
      ))!;

      var snapshot = await scheduleService.loadSchedule(
        database: database,
        screenplayId: screenplayId,
      );
      expect(snapshot.days.map((day) => day.id), [firstId, secondId, thirdId]);
      expect(snapshot.days.map((day) => day.dayNumber), [1, 2, 3]);

      await scheduleService.reorderDay(database: database, dayId: thirdId, newPosition: 0);

      snapshot = await scheduleService.loadSchedule(database: database, screenplayId: screenplayId);
      expect(snapshot.days.map((day) => day.id), [thirdId, firstId, secondId]);
      expect(snapshot.days.map((day) => day.dayNumber), [1, 2, 3]);
    });

    test("deleteDay tombstones the day and everything hanging off it", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slots = await readLiveSlots(dayId);
      final slotId = slots.single.id;
      final groupId = (await scheduleService.createGroup(
        database: database,
        shootingDayId: dayId,
        label: "Équipe image",
      ))!;

      final personId = (await peopleService.createPerson(database: database))!;
      final roleId = await createRole("role-1");
      final shotId = await createShot("shot-1");

      await scheduleService.addSlotCrewMember(database: database, slotId: slotId, personId: personId);
      await scheduleService.addSlotCastRole(database: database, slotId: slotId, roleId: roleId);
      await scheduleService.placeShot(database: database, slotId: slotId, shotId: shotId);

      await scheduleService.deleteDay(database: database, dayId: dayId);

      expect((await readDay(dayId)).isDeleted, isTrue);
      final allGroups = await readAllGroups(dayId);
      expect(allGroups, hasLength(1));
      expect(allGroups.single.id, groupId);
      expect(allGroups.single.isDeleted, isTrue);
      final allSlots = await readAllSlots(dayId);
      expect(allSlots, hasLength(1));
      expect(allSlots.single.isDeleted, isTrue);
      expect((await readAllCrew(slotId)).every((row) => row.isDeleted), isTrue);
      expect((await readAllCast(slotId)).every((row) => row.isDeleted), isTrue);
      expect((await readAllBlocks(dayId)).every((row) => row.isDeleted), isTrue);

      final snapshot = await scheduleService.loadSchedule(
        database: database,
        screenplayId: screenplayId,
      );
      expect(snapshot.days, isEmpty);
    });

    test(
      "duplicateDay copies the slots, crew, cast and groups with fresh ids, remapping groupId "
      "by label, and neither the shots nor the crew note",
      () async {
        final sourceDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ))!;
        final sourceSlotId = (await readLiveSlots(sourceDayId)).single.id;
        final sourceGroupId = (await scheduleService.createGroup(
          database: database,
          shootingDayId: sourceDayId,
          label: "Équipe image",
          leadMinutes: 30,
        ))!;

        await scheduleService.updateSlot(
          database: database,
          slotId: sourceSlotId,
          label: const Value("Matin"),
          startMinute: const Value(420),
        );
        await scheduleService.updateDay(
          database: database,
          dayId: sourceDayId,
          crewNote: const Value("Apporter les parapluies"),
        );

        final personId = (await peopleService.createPerson(database: database))!;
        final roleId = await createRole("role-1");
        final shotId = await createShot("shot-1");

        final sourceCrewId = (await scheduleService.addSlotCrewMember(
          database: database,
          slotId: sourceSlotId,
          personId: personId,
          positionId: "director",
        ))!;
        await scheduleService.updateSlotCrewMember(
          database: database,
          crewMemberId: sourceCrewId,
          groupId: Value(sourceGroupId),
        );

        final sourceCastId = (await scheduleService.addSlotCastRole(
          database: database,
          slotId: sourceSlotId,
          roleId: roleId,
        ))!;
        await scheduleService.updateSlotCastRole(
          database: database,
          castRoleId: sourceCastId,
          leadMinutes: const Value(25),
        );

        await scheduleService.placeShot(database: database, slotId: sourceSlotId, shotId: shotId);

        final newDayId = (await scheduleService.duplicateDay(
          database: database,
          sourceDayId: sourceDayId,
          date: DateTime(2026, 8, 20),
        ))!;

        expect(newDayId, isNot(sourceDayId));
        final newDay = await readDay(newDayId);
        expect(newDay.crewNote, "");
        expect(newDay.status, OcptShootingDayStatus.planned);

        final newGroups = await readLiveGroups(newDayId);
        expect(newGroups, hasLength(1));
        expect(newGroups.single.id, isNot(sourceGroupId));
        expect(newGroups.single.label, "Équipe image");
        expect(newGroups.single.leadMinutes, 30);

        final newSlots = await readLiveSlots(newDayId);
        expect(newSlots, hasLength(1));
        final newSlot = newSlots.single;
        expect(newSlot.id, isNot(sourceSlotId));
        expect(newSlot.label, "Matin");
        expect(newSlot.startMinute, 420);

        final newCrew = await readAllCrew(newSlot.id);
        expect(newCrew, hasLength(1));
        expect(newCrew.single.id, isNot(sourceCrewId));
        expect(newCrew.single.personId, personId);
        expect(newCrew.single.positionId, "director");
        // The crew row's own group is remapped onto the new day's own copy of it.
        expect(newCrew.single.groupId, newGroups.single.id);
        expect(newCrew.single.groupId, isNot(sourceGroupId));
        expect(newCrew.single.leadMinutes, isNull);

        final newCast = await readAllCast(newSlot.id);
        expect(newCast, hasLength(1));
        expect(newCast.single.id, isNot(sourceCastId));
        expect(newCast.single.roleId, roleId);
        expect(newCast.single.groupId, isNull);
        expect(newCast.single.leadMinutes, 25);

        // Neither the placed shot nor its block travelled to the new day.
        expect(await readAllBlocks(newDayId), isEmpty);
      },
    );

    test("duplicateDay mints the default slot when the source day has no live slot left", () async {
      final sourceDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final sourceSlotId = (await readLiveSlots(sourceDayId)).single.id;
      await scheduleService.deleteSlot(database: database, slotId: sourceSlotId);

      final newDayId = (await scheduleService.duplicateDay(
        database: database,
        sourceDayId: sourceDayId,
        date: DateTime(2026, 8, 20),
      ))!;

      final newSlots = await readLiveSlots(newDayId);
      expect(newSlots, hasLength(1));
      expect(newSlots.single.startMinute, 480);
    });
  });

  group("groups", () {
    late String dayId;

    setUp(() async {
      await insertScreenplay();
      dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
    });

    test("createGroup appends to the day's groups, defaulting label and lead time", () async {
      final groupId = (await scheduleService.createGroup(
        database: database,
        shootingDayId: dayId,
      ))!;

      final groups = await readLiveGroups(dayId);
      expect(groups.single.id, groupId);
      expect(groups.single.label, "");
      expect(groups.single.leadMinutes, 0);
    });

    test("updateGroup writes only the fields passed", () async {
      final groupId = (await scheduleService.createGroup(
        database: database,
        shootingDayId: dayId,
        label: "Figuration",
        leadMinutes: 15,
      ))!;

      await scheduleService.updateGroup(
        database: database,
        groupId: groupId,
        leadMinutes: const Value(45),
      );

      final group = (await readLiveGroups(dayId)).single;
      expect(group.label, "Figuration");
      expect(group.leadMinutes, 45);
    });

    test(
      "deleteGroup tombstones the group and nulls the groupId of every crew and cast row "
      "pointing at it",
      () async {
        final groupId = (await scheduleService.createGroup(
          database: database,
          shootingDayId: dayId,
          label: "Équipe technique",
        ))!;
        final slotId = (await readLiveSlots(dayId)).single.id;

        final personId = (await peopleService.createPerson(database: database))!;
        final crewId = (await scheduleService.addSlotCrewMember(
          database: database,
          slotId: slotId,
          personId: personId,
        ))!;
        await scheduleService.updateSlotCrewMember(
          database: database,
          crewMemberId: crewId,
          groupId: Value(groupId),
        );

        final roleId = await createRole("role-1");
        final castId = (await scheduleService.addSlotCastRole(
          database: database,
          slotId: slotId,
          roleId: roleId,
        ))!;
        await scheduleService.updateSlotCastRole(
          database: database,
          castRoleId: castId,
          groupId: Value(groupId),
        );

        await scheduleService.deleteGroup(database: database, groupId: groupId);

        final groups = await readAllGroups(dayId);
        expect(groups.single.isDeleted, isTrue);

        final crewRow = (await readAllCrew(slotId)).single;
        expect(crewRow.isDeleted, isFalse);
        expect(crewRow.groupId, isNull);

        final castRow = (await readAllCast(slotId)).single;
        expect(castRow.isDeleted, isFalse);
        expect(castRow.groupId, isNull);
      },
    );
  });

  group("slots", () {
    setUp(insertScreenplay);

    test(
      "deleteSlot moves its live blocks, in order, to the end of the day's first other live "
      "slot",
      () async {
        final dayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ))!;
        final slotA = (await readLiveSlots(dayId)).single.id;
        final slotB = (await scheduleService.createSlot(
          database: database,
          shootingDayId: dayId,
          startMinute: 1080,
          label: "Soir",
        ))!;

        final x1 = (await scheduleService.createBlock(
          database: database,
          slotId: slotB,
          kind: OcptShootingBlockKind.preparation,
        ))!;
        final x2 = (await scheduleService.createBlock(
          database: database,
          slotId: slotB,
          kind: OcptShootingBlockKind.hairMakeUp,
        ))!;
        final y1 = (await scheduleService.createBlock(
          database: database,
          slotId: slotA,
          kind: OcptShootingBlockKind.meal,
        ))!;
        final y2 = (await scheduleService.createBlock(
          database: database,
          slotId: slotA,
          kind: OcptShootingBlockKind.wrap,
        ))!;

        await scheduleService.deleteSlot(database: database, slotId: slotA);

        expect((await readAllSlots(dayId)).firstWhere((row) => row.id == slotA).isDeleted, isTrue);

        final blocks = await readAllBlocks(dayId);
        expect(blocks.every((row) => !row.isDeleted), isTrue);
        expect(blocks.every((row) => row.slotId == slotB), isTrue);
        expect(blocks.map((row) => row.id), [x1, x2, y1, y2]);
      },
    );

    test("deleteSlot tombstones its own blocks too when it is the day's last live slot", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;

      final y1 = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.meal,
      ))!;
      final y2 = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.wrap,
      ))!;

      await scheduleService.deleteSlot(database: database, slotId: slotId);

      expect((await readAllSlots(dayId)).single.isDeleted, isTrue);
      final blocks = await readAllBlocks(dayId);
      expect(blocks.map((row) => row.id).toSet(), {y1, y2});
      expect(blocks.every((row) => row.isDeleted), isTrue);
    });

    test(
      "addSlotCrewMember seeds the lead time from that person's and position's most recent "
      "convocation",
      () async {
        final firstDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ))!;
        final firstSlotId = (await readLiveSlots(firstDayId)).single.id;
        final personId = (await peopleService.createPerson(database: database))!;

        final firstCrewId = (await scheduleService.addSlotCrewMember(
          database: database,
          slotId: firstSlotId,
          personId: personId,
          positionId: "grip",
        ))!;
        await scheduleService.updateSlotCrewMember(
          database: database,
          crewMemberId: firstCrewId,
          leadMinutes: const Value(90),
        );

        final secondDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 11),
        ))!;
        final secondSlotId = (await readLiveSlots(secondDayId)).single.id;

        final secondCrewId = (await scheduleService.addSlotCrewMember(
          database: database,
          slotId: secondSlotId,
          personId: personId,
          positionId: "grip",
        ))!;

        final seeded = (await readAllCrew(secondSlotId)).firstWhere(
          (row) => row.id == secondCrewId,
        );
        expect(seeded.leadMinutes, 90);
        expect(seeded.groupId, isNull);
      },
    );

    test(
      "addSlotCrewMember seeds the group, matched by label onto the target day's own copy",
      () async {
        final firstDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ))!;
        final firstSlotId = (await readLiveSlots(firstDayId)).single.id;
        final firstGroupId = (await scheduleService.createGroup(
          database: database,
          shootingDayId: firstDayId,
          label: "Machinerie",
          leadMinutes: 20,
        ))!;
        final personId = (await peopleService.createPerson(database: database))!;

        final firstCrewId = (await scheduleService.addSlotCrewMember(
          database: database,
          slotId: firstSlotId,
          personId: personId,
          positionId: "grip",
        ))!;
        await scheduleService.updateSlotCrewMember(
          database: database,
          crewMemberId: firstCrewId,
          groupId: Value(firstGroupId),
        );

        // Created after the group, so it inherits its own copy of "Machinerie".
        final secondDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 11),
        ))!;
        final secondSlotId = (await readLiveSlots(secondDayId)).single.id;
        final secondGroupId = (await readLiveGroups(secondDayId)).single.id;
        expect(secondGroupId, isNot(firstGroupId));

        final secondCrewId = (await scheduleService.addSlotCrewMember(
          database: database,
          slotId: secondSlotId,
          personId: personId,
          positionId: "grip",
        ))!;

        final seeded = (await readAllCrew(secondSlotId)).firstWhere(
          (row) => row.id == secondCrewId,
        );
        expect(seeded.groupId, secondGroupId);
        expect(seeded.groupId, isNot(firstGroupId));
        // The source row's own figure (null, inheriting the group's) travels verbatim.
        expect(seeded.leadMinutes, isNull);
      },
    );

    test(
      "addSlotCrewMember seeds no group when the target day has none of that label",
      () async {
        final firstDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ))!;
        // Created before the group exists, so it never inherited a copy of it.
        final secondDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 11),
        ))!;

        final firstSlotId = (await readLiveSlots(firstDayId)).single.id;
        final groupId = (await scheduleService.createGroup(
          database: database,
          shootingDayId: firstDayId,
          label: "Maquillage",
          leadMinutes: 45,
        ))!;
        final personId = (await peopleService.createPerson(database: database))!;

        final firstCrewId = (await scheduleService.addSlotCrewMember(
          database: database,
          slotId: firstSlotId,
          personId: personId,
          positionId: "hmc",
        ))!;
        await scheduleService.updateSlotCrewMember(
          database: database,
          crewMemberId: firstCrewId,
          groupId: Value(groupId),
        );

        final secondSlotId = (await readLiveSlots(secondDayId)).single.id;
        final secondCrewId = (await scheduleService.addSlotCrewMember(
          database: database,
          slotId: secondSlotId,
          personId: personId,
          positionId: "hmc",
        ))!;

        expect(await readLiveGroups(secondDayId), isEmpty);
        final seeded = (await readAllCrew(secondSlotId)).firstWhere(
          (row) => row.id == secondCrewId,
        );
        expect(seeded.groupId, isNull);
      },
    );

    test(
      "addSlotCastRole seeds the lead time and group from that role's most recent convocation",
      () async {
        final firstDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ))!;
        final firstSlotId = (await readLiveSlots(firstDayId)).single.id;
        final groupId = (await scheduleService.createGroup(
          database: database,
          shootingDayId: firstDayId,
          label: "Figuration",
          leadMinutes: 60,
        ))!;
        final roleId = await createRole("role-1");

        final firstCastId = (await scheduleService.addSlotCastRole(
          database: database,
          slotId: firstSlotId,
          roleId: roleId,
        ))!;
        await scheduleService.updateSlotCastRole(
          database: database,
          castRoleId: firstCastId,
          groupId: Value(groupId),
        );

        final secondDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 11),
        ))!;
        final secondSlotId = (await readLiveSlots(secondDayId)).single.id;
        final secondGroupId = (await readLiveGroups(secondDayId)).single.id;

        final secondCastId = (await scheduleService.addSlotCastRole(
          database: database,
          slotId: secondSlotId,
          roleId: roleId,
        ))!;

        final seeded = (await readAllCast(secondSlotId)).firstWhere(
          (row) => row.id == secondCastId,
        );
        expect(seeded.groupId, secondGroupId);
        expect(seeded.leadMinutes, isNull);
      },
    );

    test("addSlotCastRole refuses convoking the same role twice in one slot", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;
      final roleId = await createRole("role-1");

      final firstId = await scheduleService.addSlotCastRole(
        database: database,
        slotId: slotId,
        roleId: roleId,
      );
      final secondId = await scheduleService.addSlotCastRole(
        database: database,
        slotId: slotId,
        roleId: roleId,
      );

      expect(secondId, firstId);
      expect(await readAllCast(slotId), hasLength(1));
    });
  });

  group("the timetable", () {
    setUp(insertScreenplay);

    test("placeShot on an already-placed shot moves its block instead of duplicating it", () async {
      final firstDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final firstSlotId = (await readLiveSlots(firstDayId)).single.id;
      final secondDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;
      final secondSlotId = (await readLiveSlots(secondDayId)).single.id;
      final shotId = await createShot("shot-1");

      final firstBlockId = (await scheduleService.placeShot(
        database: database,
        slotId: firstSlotId,
        shotId: shotId,
      ))!;
      final secondBlockId = (await scheduleService.placeShot(
        database: database,
        slotId: secondSlotId,
        shotId: shotId,
      ))!;

      expect(secondBlockId, firstBlockId);

      final firstDayBlocks = (await readAllBlocks(firstDayId)).where((row) => !row.isDeleted);
      expect(firstDayBlocks, isEmpty);

      final secondDayBlocks = await readAllBlocks(secondDayId);
      expect(secondDayBlocks.where((row) => !row.isDeleted), hasLength(1));
      expect(secondDayBlocks.single.slotId, secondSlotId);
      expect(secondDayBlocks.single.shotId, shotId);
      expect(secondDayBlocks.single.kind, OcptShootingBlockKind.shot);
    });

    test("unplaceShot tombstones the shot's block and drops it from loadShotPlacements", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;
      final shotId = await createShot("shot-1");

      await scheduleService.placeShot(database: database, slotId: slotId, shotId: shotId);
      var placements = await scheduleService.loadShotPlacements(
        database: database,
        screenplayId: screenplayId,
      );
      expect(placements[shotId]!.dayId, dayId);
      expect(placements[shotId]!.dayNumber, 1);

      await scheduleService.unplaceShot(database: database, shotId: shotId);

      placements = await scheduleService.loadShotPlacements(
        database: database,
        screenplayId: screenplayId,
      );
      expect(placements.containsKey(shotId), isFalse);

      final blocks = await readAllBlocks(dayId);
      expect(blocks.single.isDeleted, isTrue);
    });

    test("moveBlockToSlot moves a block to another slot, and to that slot's day with it", () async {
      final sourceDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final targetDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;
      final sourceSlotId = (await readLiveSlots(sourceDayId)).single.id;
      final targetSlotId = (await readLiveSlots(targetDayId)).single.id;

      final blockId = (await scheduleService.createBlock(
        database: database,
        slotId: sourceSlotId,
        kind: OcptShootingBlockKind.meal,
        label: "Repas",
      ))!;

      await scheduleService.moveBlockToSlot(
        database: database,
        blockId: blockId,
        targetSlotId: targetSlotId,
        newPosition: 0,
      );

      final moved = await readBlock(blockId);
      expect(moved.shootingDayId, targetDayId);
      expect(moved.slotId, targetSlotId);
      expect(moved.kind, OcptShootingBlockKind.meal);
      expect(moved.label, "Repas");
    });

    test("createBlock refuses kind shot, which only placeShot may write", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;

      final blockId = await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.shot,
      );

      expect(blockId, isNull);
      expect(await readAllBlocks(dayId), isEmpty);
    });

    test("reorderBlock writes exactly one row within a slot's own timetable", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;

      final firstId = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.preparation,
      ))!;
      final secondId = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.meal,
      ))!;

      await scheduleService.reorderBlock(database: database, blockId: secondId, newPosition: 0);

      final blocks = await readAllBlocks(dayId);
      expect(blocks.map((row) => row.id), [secondId, firstId]);
    });
  });

  group("read-only preview", () {
    test("every write is refused on a preview database", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      expect(
        await scheduleService.createDay(
          database: preview,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ),
        isNull,
      );
      await scheduleService.updateDay(database: preview, dayId: "missing-day");
      await scheduleService.reorderDay(database: preview, dayId: "missing-day", newPosition: 0);
      await scheduleService.deleteDay(database: preview, dayId: "missing-day");
      expect(
        await scheduleService.duplicateDay(
          database: preview,
          sourceDayId: "missing-day",
          date: DateTime(2026, 8, 20),
        ),
        isNull,
      );

      expect(
        await scheduleService.createGroup(database: preview, shootingDayId: "missing-day"),
        isNull,
      );
      await scheduleService.updateGroup(database: preview, groupId: "missing-group");
      await scheduleService.deleteGroup(database: preview, groupId: "missing-group");

      expect(
        await scheduleService.createSlot(
          database: preview,
          shootingDayId: "missing-day",
          startMinute: 480,
        ),
        isNull,
      );
      await scheduleService.updateSlot(database: preview, slotId: "missing-slot");
      await scheduleService.reorderSlot(database: preview, slotId: "missing-slot", newPosition: 0);
      await scheduleService.deleteSlot(database: preview, slotId: "missing-slot");

      expect(
        await scheduleService.addSlotCrewMember(
          database: preview,
          slotId: "missing-slot",
          personId: "missing-person",
        ),
        isNull,
      );
      await scheduleService.updateSlotCrewMember(database: preview, crewMemberId: "missing-crew");
      await scheduleService.removeSlotCrewMember(database: preview, crewMemberId: "missing-crew");

      expect(
        await scheduleService.addSlotCastRole(
          database: preview,
          slotId: "missing-slot",
          roleId: "missing-role",
        ),
        isNull,
      );
      await scheduleService.updateSlotCastRole(database: preview, castRoleId: "missing-cast");
      await scheduleService.removeSlotCastRole(database: preview, castRoleId: "missing-cast");

      expect(
        await scheduleService.placeShot(
          database: preview,
          slotId: "missing-slot",
          shotId: "missing-shot",
        ),
        isNull,
      );
      await scheduleService.unplaceShot(database: preview, shotId: "missing-shot");
      await scheduleService.deleteBlock(database: preview, blockId: "missing-block");
      expect(
        await scheduleService.createBlock(
          database: preview,
          slotId: "missing-slot",
          kind: OcptShootingBlockKind.meal,
        ),
        isNull,
      );
      await scheduleService.updateBlock(database: preview, blockId: "missing-block");
      await scheduleService.reorderBlock(
        database: preview,
        blockId: "missing-block",
        newPosition: 0,
      );
      await scheduleService.moveBlockToSlot(
        database: preview,
        blockId: "missing-block",
        targetSlotId: "missing-slot",
        newPosition: 0,
      );

      final snapshot = await scheduleService.loadSchedule(
        database: preview,
        screenplayId: screenplayId,
      );
      expect(snapshot.days, isEmpty);
    });
  });
}
