// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of the schedule service auditions.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";

  final scheduleService = OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId);

  final peopleService = OcptPeopleService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
    assetsService: OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId),
    roleCandidatesService: OcptRoleCandidatesService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
  );

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
  /// `OcptRoleIndexService`'s reconciliation, exactly as
  /// `ocpt_breakdown_service_reconcile_and_stamps_test.dart` does.
  Future<String> createRole(String id, {String name = "LÉA"}) async {
    await database
        .into(database.ocptRolesTable)
        .insert(OcptRolesTableCompanion.insert(id: id, name: name, kind: OcptRoleKind.silent));
    return id;
  }

  /// Inserts a scene, satisfying `shooting_day_blocks.sceneId`'s foreign key without going through
  /// `OcptSceneIndexService`'s reconciliation, which this service has no business exercising.
  Future<String> createScene(String id) async {
    await database
        .into(database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: id,
            screenplayId: screenplayId,
            position: 0,
            heading: "INT. CUISINE - JOUR",
            charStart: 0,
            charEnd: 1,
          ),
        );
    return id;
  }

  /// Every slot row of day [dayId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingSlotRow>> readAllSlots(String dayId) =>
      (database.select(database.ocptShootingSlotsTable)
            ..where((row) => row.shootingDayId.equals(dayId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every live slot row of day [dayId], in `sortKey` order.
  Future<List<OcptShootingSlotRow>> readLiveSlots(String dayId) async =>
      (await readAllSlots(dayId)).where((row) => !row.isDeleted).toList();

  /// The block row [id], tombstoned or not.
  Future<OcptShootingDayBlockRow> readBlock(String id) => (database.select(
    database.ocptShootingDayBlocksTable,
  )..where((row) => row.id.equals(id))).getSingle();

  /// Every candidate row of block [blockId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingBlockCandidateRow>> readAllBlockCandidates(String blockId) =>
      (database.select(database.ocptShootingBlockCandidatesTable)
            ..where((row) => row.blockId.equals(blockId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Inserts a candidacy — somebody seen for a part — satisfying the foreign keys
  /// `shooting_block_candidates` needs, without going through
  /// `OcptRoleCandidatesService`, whose own retained rule this service has no business exercising.
  Future<String> createCandidacy(
    String id, {
    required String roleId,
    required String personId,
  }) async {
    await database
        .into(database.ocptRoleCandidatesTable)
        .insert(
          OcptRoleCandidatesTableCompanion.insert(id: id, roleId: roleId, personId: personId),
        );
    return id;
  }

  group("auditions and the candidates convoked for them", () {
    setUp(insertScreenplay);

    /// A day carrying one slot, with a part and somebody seen for it: what every test below plans
    /// an audition on.
    Future<(String dayId, String slotId, String roleId, String candidacyId)> createCastingDay({
      String suffix = "",
    }) async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final roleId = await createRole("role$suffix");
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      final candidacyId = await createCandidacy(
        "candidacy$suffix",
        roleId: roleId,
        personId: personId,
      );

      return (dayId, slotId, roleId, candidacyId);
    }

    test("createBlock mints an audition naming nobody, which is an ordinary state", () async {
      final (dayId, slotId, _, _) = await createCastingDay();

      final blockId = await scheduleService
          .createBlock(
            database: database,
            slotId: slotId,
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 20,
          )
          .maybeValueOrFail;

      expect(blockId, isNotNull);
      final block = await readBlock(blockId!);
      expect(block.kind, OcptShootingBlockKind.audition);
      expect(block.shootingDayId, dayId);
      expect(await readAllBlockCandidates(blockId), isEmpty);
    });

    test("createBlock keeps a rehearsal's own sequence, exactly as a hold's", () async {
      final (_, slotId, _, _) = await createCastingDay();
      final sceneId = await createScene("scene-1");

      final blockId = (await scheduleService
          .createBlock(
            database: database,
            slotId: slotId,
            kind: OcptShootingBlockKind.rehearsal,
            sceneId: sceneId,
          )
          .valueOrFail);

      expect((await readBlock(blockId)).sceneId, sceneId);
    });

    test("updateBlock turning a hold into a rehearsal keeps the sequence it was holding", () async {
      final (_, slotId, _, _) = await createCastingDay();
      final sceneId = await createScene("scene-1");
      final blockId = (await scheduleService
          .createBlock(
            database: database,
            slotId: slotId,
            kind: OcptShootingBlockKind.hold,
            sceneId: sceneId,
          )
          .valueOrFail);

      await scheduleService
          .updateBlock(
            database: database,
            blockId: blockId,
            kind: const Value(OcptShootingBlockKind.rehearsal),
          )
          .okOrFail;

      expect((await readBlock(blockId)).sceneId, sceneId);
    });

    test("addBlockCandidate mints a convocation, reloaded by loadSchedule", () async {
      final (dayId, slotId, _, candidacyId) = await createCastingDay();
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);

      final convocationId = await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .maybeValueOrFail;

      expect(convocationId, isNotNull);
      final snapshot = await scheduleService.loadSchedule(database: database).valueOrFail;
      final candidate = snapshot.blocksByDayId[dayId]!.single.candidates.single;
      expect(candidate.id, convocationId);
      expect(candidate.blockId, blockId);
      expect(candidate.roleCandidateId, candidacyId);
    });

    test("addBlockCandidate names two candidacies on one block, in the order given", () async {
      // Two actors of two different parts read together, which is the whole reason several rows
      // may hang off one block.
      final (dayId, slotId, _, first) = await createCastingDay();
      final second = await createCandidacy(
        "candidacy-2",
        roleId: await createRole("role-2"),
        personId: (await peopleService.createPerson(database: database).valueOrFail),
      );
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);

      await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: first)
          .maybeValueOrFail;
      await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: second)
          .maybeValueOrFail;

      final snapshot = await scheduleService.loadSchedule(database: database).valueOrFail;
      expect(
        snapshot.blocksByDayId[dayId]!.single.candidates.map(
          (candidate) => candidate.roleCandidateId,
        ),
        [first, second],
      );
    });

    test("addBlockCandidate refuses a block that is not an audition", () async {
      final (_, slotId, _, candidacyId) = await createCastingDay();
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.meal)
          .valueOrFail);

      final convocationId = await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .maybeValueOrFail;

      expect(convocationId, isNull);
      expect(await readAllBlockCandidates(blockId), isEmpty);
    });

    test("addBlockCandidate refuses a second row for a pair the block already names", () async {
      final (_, slotId, _, candidacyId) = await createCastingDay();
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);

      final first = await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .maybeValueOrFail;
      final second = await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .maybeValueOrFail;

      expect(second, first);
      expect(await readAllBlockCandidates(blockId), hasLength(1));
    });

    test(
      "addBlockCandidate revives a convocation removed earlier rather than duplicating",
      () async {
        final (_, slotId, _, candidacyId) = await createCastingDay();
        final blockId = (await scheduleService
            .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
            .valueOrFail);
        final convocationId = (await scheduleService
            .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
            .valueOrFail);
        await scheduleService
            .removeBlockCandidate(database: database, blockCandidateId: convocationId)
            .okOrFail;

        final revived = await scheduleService
            .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
            .maybeValueOrFail;

        expect(revived, convocationId);
        final rows = await readAllBlockCandidates(blockId);
        expect(rows, hasLength(1));
        expect(rows.single.isDeleted, isFalse);
      },
    );

    test("reorderBlockCandidate writes one row and re-reads in the new order", () async {
      final (dayId, slotId, _, first) = await createCastingDay();
      final second = await createCandidacy(
        "candidacy-2",
        roleId: await createRole("role-2"),
        personId: (await peopleService.createPerson(database: database).valueOrFail),
      );
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);
      await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: first)
          .maybeValueOrFail;
      final secondConvocationId = (await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: second)
          .valueOrFail);

      await scheduleService
          .reorderBlockCandidate(
            database: database,
            blockCandidateId: secondConvocationId,
            newPosition: 0,
          )
          .okOrFail;

      final snapshot = await scheduleService.loadSchedule(database: database).valueOrFail;
      expect(
        snapshot.blocksByDayId[dayId]!.single.candidates.map(
          (candidate) => candidate.roleCandidateId,
        ),
        [second, first],
      );
    });

    test("removeBlockCandidate tombstones the link and leaves the audition alone", () async {
      final (_, slotId, _, candidacyId) = await createCastingDay();
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);
      final convocationId = (await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .valueOrFail);

      await scheduleService
          .removeBlockCandidate(database: database, blockCandidateId: convocationId)
          .okOrFail;

      expect((await readAllBlockCandidates(blockId)).single.isDeleted, isTrue);
      expect((await readBlock(blockId)).isDeleted, isFalse);
    });

    test("updateBlock turning an audition into anything else drops its candidacies", () async {
      final (_, slotId, _, candidacyId) = await createCastingDay();
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);
      await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .maybeValueOrFail;

      await scheduleService
          .updateBlock(
            database: database,
            blockId: blockId,
            kind: const Value(OcptShootingBlockKind.pause),
          )
          .okOrFail;

      expect((await readBlock(blockId)).kind, OcptShootingBlockKind.pause);
      expect((await readAllBlockCandidates(blockId)).single.isDeleted, isTrue);
    });

    test("updateBlock editing an audition's own duration leaves its candidacies alone", () async {
      final (_, slotId, _, candidacyId) = await createCastingDay();
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);
      await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .maybeValueOrFail;

      await scheduleService
          .updateBlock(database: database, blockId: blockId, durationMinutes: const Value(25))
          .okOrFail;

      expect((await readBlock(blockId)).durationMinutes, 25);
      expect((await readAllBlockCandidates(blockId)).single.isDeleted, isFalse);
    });

    test("deleteBlock carries the candidacies it named off with it", () async {
      final (_, slotId, _, candidacyId) = await createCastingDay();
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);
      await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .maybeValueOrFail;

      await scheduleService.deleteBlock(database: database, blockId: blockId).okOrFail;

      expect((await readAllBlockCandidates(blockId)).single.isDeleted, isTrue);
      // The candidacy itself outlives the audition that was going to see it.
      expect(
        (await database.select(database.ocptRoleCandidatesTable).getSingle()).isDeleted,
        isFalse,
      );
    });

    test("deleting a day's last slot carries its auditions' candidacies off too", () async {
      final (_, slotId, _, candidacyId) = await createCastingDay();
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);
      await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .maybeValueOrFail;

      await scheduleService.deleteSlot(database: database, slotId: slotId).okOrFail;

      expect((await readAllBlockCandidates(blockId)).single.isDeleted, isTrue);
    });

    test("deleting a day carries every candidacy of its auditions off with it", () async {
      final (dayId, slotId, _, candidacyId) = await createCastingDay();
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);
      await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .maybeValueOrFail;

      await scheduleService.deleteDay(database: database, dayId: dayId).okOrFail;

      expect((await readAllBlockCandidates(blockId)).single.isDeleted, isTrue);
    });

    test("every candidate write is refused on a preview database", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      expect(
        await scheduleService
            .addBlockCandidate(
              database: preview,
              blockId: "missing-block",
              roleCandidateId: "missing-candidacy",
            )
            .maybeValueOrFail,
        isNull,
      );
      await scheduleService
          .updateBlockCandidate(
            database: preview,
            blockCandidateId: "missing-convocation",
            notes: const Value("nope"),
          )
          .okOrFail;
      await scheduleService
          .reorderBlockCandidate(
            database: preview,
            blockCandidateId: "missing-convocation",
            newPosition: 0,
          )
          .okOrFail;
      await scheduleService
          .removeBlockCandidate(database: preview, blockCandidateId: "missing-convocation")
          .okOrFail;

      expect(await preview.select(preview.ocptShootingBlockCandidatesTable).get(), isEmpty);
    });
  });
}
