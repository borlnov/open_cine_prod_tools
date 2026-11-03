// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import '../../../ocpt_result_expectations.dart';
import 'ocpt_role_index_service_test_doubles.dart';

/// Inserts a bare shot of [screenplayId], everything else at a neutral value: `mergeRole`'s
/// `shot_characters` tests only need a shot to attach a role to.
Future<void> _insertShot(
  OcptProjectDatabase database, {
  required String id,
  required String screenplayId,
}) => database
    .into(database.ocptShotsTable)
    .insert(OcptShotsTableCompanion.insert(id: id, screenplayId: screenplayId, position: 0));

/// Inserts a `shot_characters` row directly — `mergeRole` and `deleteRole`'s own tests write this
/// table underneath the service under test, so they bypass `OcptShotListService.attachCharacter`
/// entirely.
Future<void> _insertShotCharacter(
  OcptProjectDatabase database, {
  required String shotId,
  required String roleId,
  int position = 0,
  String sortKey = "",
}) => database
    .into(database.ocptShotCharactersTable)
    .insert(
      OcptShotCharactersTableCompanion.insert(
        shotId: shotId,
        roleId: roleId,
        position: position,
        sortKey: Value(sortKey),
      ),
    );

/// Inserts a bare shooting day, everything else at a neutral value.
Future<void> _insertShootingDay(OcptProjectDatabase database, {required String id}) => database
    .into(database.ocptShootingDaysTable)
    .insert(OcptShootingDaysTableCompanion.insert(id: id, date: DateTime(2026)));

/// Inserts a bare shooting slot of [shootingDayId], everything else at a neutral value.
Future<void> _insertShootingSlot(
  OcptProjectDatabase database, {
  required String id,
  required String shootingDayId,
}) => database
    .into(database.ocptShootingSlotsTable)
    .insert(OcptShootingSlotsTableCompanion.insert(id: id, shootingDayId: shootingDayId));

/// Inserts a `shooting_slot_cast` row convoking [roleId] on [slotId] directly.
Future<void> _insertSlotCast(
  OcptProjectDatabase database, {
  required String id,
  required String slotId,
  required String roleId,
}) => database
    .into(database.ocptShootingSlotCastTable)
    .insert(OcptShootingSlotCastTableCompanion.insert(id: id, slotId: slotId, roleId: roleId));

/// Inserts a bare scene of [screenplayId], everything else at a neutral value: `mergeRole`'s
/// `breakdown_tags` tests only need a scene to anchor a tag to.
Future<void> _insertScene(
  OcptProjectDatabase database, {
  required String id,
  required String screenplayId,
}) => database
    .into(database.ocptScenesTable)
    .insert(
      OcptScenesTableCompanion.insert(
        id: id,
        screenplayId: screenplayId,
        position: 0,
        heading: "INT. HOUSE - DAY",
        charStart: 0,
        charEnd: 10,
      ),
    );

/// Inserts a `breakdown_tags` row of `targetKind` [OcptBreakdownTargetKind.role] pointing at
/// [roleId], anchored on [sceneId].
Future<void> _insertRoleTag(
  OcptProjectDatabase database, {
  required String id,
  required String sceneId,
  required String roleId,
}) => database
    .into(database.ocptBreakdownTagsTable)
    .insert(
      OcptBreakdownTagsTableCompanion.insert(
        id: id,
        sceneId: sceneId,
        targetKind: OcptBreakdownTargetKind.role,
        roleId: Value(roleId),
        startOffset: 0,
        endOffset: 5,
        taggedText: "CLARA",
      ),
    );

/// Run the tests of the role index service merge and delete.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";

  final assetsService = OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId);

  final elementsService = OcptElementsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );

  final roleIndexService = OcptRoleIndexService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
    deviceId: testDeviceId,
  );

  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> reconcile(String source) => roleIndexService.reconcile(
    database: database,
    screenplayId: screenplayId,
    document: parse(source),
    stamps: null,
  );

  group("mergeRole", () {
    late String sourceRoleId;
    late String targetRoleId;

    setUp(() async {
      sourceRoleId = (await roleIndexService
          .addRole(
            database: database,
            screenplayId: screenplayId,
            name: "Source",
            kind: OcptRoleKind.silent,
          )
          .valueOrFail);
      targetRoleId = (await roleIndexService
          .addRole(
            database: database,
            screenplayId: screenplayId,
            name: "Target",
            kind: OcptRoleKind.silent,
          )
          .valueOrFail);
    });

    test("is a no-op when source and target are the same id", () async {
      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: sourceRoleId)
          .okOrFail;

      final roles = await roleIndexService.loadRoles(database: database).valueOrFail;
      expect(roles.map((role) => role.id).toSet(), {sourceRoleId, targetRoleId});
    });

    test("is a no-op when source is missing or already tombstoned", () async {
      await roleIndexService.deleteRole(database: database, roleId: sourceRoleId).okOrFail;

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final roles = await roleIndexService.loadRoles(database: database).valueOrFail;
      expect(roles.map((role) => role.id), [targetRoleId]);
    });

    test("is a no-op when target is missing or already tombstoned", () async {
      await roleIndexService.deleteRole(database: database, roleId: targetRoleId).okOrFail;

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final roles = await roleIndexService.loadRoles(database: database).valueOrFail;
      expect(roles.map((role) => role.id), [sourceRoleId]);
    });

    test("tombstones source, and the survivor is whichever id was passed as target", () async {
      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final roles = await roleIndexService.loadRoles(database: database).valueOrFail;
      expect(roles.map((role) => role.id), [targetRoleId]);

      final sourceRow = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(sourceRoleId))).getSingle();
      expect(sourceRow.isDeleted, isTrue);
    });

    test(
      "is purely mechanical: it never decides who survives, only who was passed as target",
      () async {
        // sourceRoleId, here, is the reconciled speaking role — passed as *source* on purpose, to
        // prove mergeRole applies no "speaking wins" rule of its own: that rule is the caller's,
        // per this method's own doc comment.
        await reconcile('''
INT. HOUSE - DAY

CLARA
Hello.
''');
        final speakingRoleId = (await roleIndexService.loadRoles(database: database).valueOrFail)
            .firstWhere((role) => role.name == "CLARA")
            .id;

        await roleIndexService
            .mergeRole(database: database, sourceRoleId: speakingRoleId, targetRoleId: targetRoleId)
            .okOrFail;

        final survivor = (await roleIndexService.loadRoles(database: database).valueOrFail)
            .singleWhere((role) => role.id == targetRoleId);
        expect(survivor.isFromScreenplay, isFalse);
      },
    );

    test(
      "moves shot_characters onto target keeping position/sortKey, dedups where target is already "
      "attached",
      () async {
        await _insertShot(database, id: "shot-a", screenplayId: screenplayId);
        await _insertShot(database, id: "shot-b", screenplayId: screenplayId);
        // shot-a only has source: a plain re-point.
        await _insertShotCharacter(
          database,
          shotId: "shot-a",
          roleId: sourceRoleId,
          position: 3,
          sortKey: "m",
        );
        // shot-b already has both: source's row must simply be dropped.
        await _insertShotCharacter(database, shotId: "shot-b", roleId: sourceRoleId, sortKey: "a");
        await _insertShotCharacter(
          database,
          shotId: "shot-b",
          roleId: targetRoleId,
          position: 1,
          sortKey: "b",
        );

        await roleIndexService
            .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
            .okOrFail;

        final rows = await database.select(database.ocptShotCharactersTable).get();

        final shotALive = rows.where((row) => row.shotId == "shot-a" && !row.isDeleted);
        expect(shotALive, hasLength(1));
        expect(shotALive.single.roleId, targetRoleId);
        expect(shotALive.single.position, 3);
        expect(shotALive.single.sortKey, "m");

        final shotBLive = rows.where((row) => row.shotId == "shot-b" && !row.isDeleted);
        expect(shotBLive, hasLength(1));
        expect(shotBLive.single.roleId, targetRoleId);
        // target's own row, untouched by the merge.
        expect(shotBLive.single.position, 1);

        final shotBSourceTombstone = rows.singleWhere(
          (row) => row.shotId == "shot-b" && row.roleId == sourceRoleId,
        );
        expect(shotBSourceTombstone.isDeleted, isTrue);
      },
    );

    test(
      "re-points shooting_slot_cast in place, dedups (tombstoning source) where the slot already "
      "convokes target",
      () async {
        await _insertShootingDay(database, id: "day-1");
        await _insertShootingSlot(database, id: "slot-a", shootingDayId: "day-1");
        await _insertShootingSlot(database, id: "slot-b", shootingDayId: "day-1");
        await _insertSlotCast(database, id: "cast-a", slotId: "slot-a", roleId: sourceRoleId);
        await _insertSlotCast(
          database,
          id: "cast-b-source",
          slotId: "slot-b",
          roleId: sourceRoleId,
        );
        await _insertSlotCast(
          database,
          id: "cast-b-target",
          slotId: "slot-b",
          roleId: targetRoleId,
        );

        await roleIndexService
            .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
            .okOrFail;

        final rows = await database.select(database.ocptShootingSlotCastTable).get();

        // slot-a: source's own row is re-pointed in place, its id unchanged.
        final castA = rows.singleWhere((row) => row.id == "cast-a");
        expect(castA.roleId, targetRoleId);
        expect(castA.isDeleted, isFalse);

        // slot-b: target was already convoked, so source's convocation is dropped rather than
        // duplicating one.
        final castBSource = rows.singleWhere((row) => row.id == "cast-b-source");
        expect(castBSource.isDeleted, isTrue);
        final castBTarget = rows.singleWhere((row) => row.id == "cast-b-target");
        expect(castBTarget.isDeleted, isFalse);
        expect(castBTarget.roleId, targetRoleId);
      },
    );

    test("re-points every breakdown_tags row onto target, with no dedup between tags", () async {
      await _insertScene(database, id: "scene-1", screenplayId: screenplayId);
      await _insertRoleTag(database, id: "tag-1", sceneId: "scene-1", roleId: sourceRoleId);
      await _insertRoleTag(database, id: "tag-2", sceneId: "scene-1", roleId: sourceRoleId);

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final tags = await database.select(database.ocptBreakdownTagsTable).get();
      expect(tags.every((tag) => !tag.isDeleted), isTrue);
      expect(tags.map((tag) => tag.roleId).toSet(), {targetRoleId});
    });

    test("carries role_elements onto target, deduping by elementId", () async {
      final elementA = (await elementsService
          .createElement(
            database: database,
            name: "Manteau",
            category: OcptElementCategory.costume,
            sourceKind: OcptElementSourceKind.owned,
          )
          .valueOrFail);
      final elementB = (await elementsService
          .createElement(
            database: database,
            name: "Chapeau",
            category: OcptElementCategory.costume,
            sourceKind: OcptElementSourceKind.owned,
          )
          .valueOrFail);
      // target already has elementA; source has both elementA (duplicate) and elementB (new).
      await elementsService
          .addRoleElement(database: database, roleId: targetRoleId, elementId: elementA)
          .maybeValueOrFail;
      await elementsService
          .addRoleElement(database: database, roleId: sourceRoleId, elementId: elementA)
          .maybeValueOrFail;
      await elementsService
          .addRoleElement(database: database, roleId: sourceRoleId, elementId: elementB)
          .maybeValueOrFail;

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final links = await database.select(database.ocptRoleElementsTable).get();
      final targetLiveElementIds = links
          .where((link) => link.roleId == targetRoleId && !link.isDeleted)
          .map((link) => link.elementId)
          .toSet();
      expect(targetLiveElementIds, {elementA, elementB});

      final sourceDuplicateLink = links.singleWhere(
        (link) => link.roleId == sourceRoleId && link.elementId == elementA,
      );
      expect(sourceDuplicateLink.isDeleted, isTrue);
    });

    test("carries role_candidates onto target, deduping by personId", () async {
      final personA = "person-a";
      final personB = "person-b";
      for (final id in [personA, personB]) {
        await database
            .into(database.ocptPeopleTable)
            .insert(OcptPeopleTableCompanion.insert(id: id));
      }
      await OcptRoleCandidatesService(
        logger: const SilentLogger(),
        deviceId: testDeviceId,
      ).addCandidate(database: database, roleId: targetRoleId, personId: personA).maybeValueOrFail;
      await OcptRoleCandidatesService(
        logger: const SilentLogger(),
        deviceId: testDeviceId,
      ).addCandidate(database: database, roleId: sourceRoleId, personId: personA).maybeValueOrFail;
      await OcptRoleCandidatesService(
        logger: const SilentLogger(),
        deviceId: testDeviceId,
      ).addCandidate(database: database, roleId: sourceRoleId, personId: personB).maybeValueOrFail;

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final candidates = await database.select(database.ocptRoleCandidatesTable).get();
      final targetLivePersonIds = candidates
          .where((row) => row.roleId == targetRoleId && !row.isDeleted)
          .map((row) => row.personId)
          .toSet();
      expect(targetLivePersonIds, {personA, personB});

      final sourceDuplicate = candidates.singleWhere(
        (row) => row.roleId == sourceRoleId && row.personId == personA,
      );
      expect(sourceDuplicate.isDeleted, isTrue);
    });

    test("carries role_episodes onto target, deduping by screenplayId", () async {
      const otherScreenplayId = "screenplay-merge-2";
      await database
          .into(database.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: otherScreenplayId,
              title: "Other",
              updatedAt: DateTime.now(),
            ),
          );
      // source is already linked to screenplayId (via addRole in setUp) — the shared episode, a
      // duplicate target must drop — and gets a second link the target lacks.
      await roleIndexService
          .setRoleEpisodes(
            database: database,
            roleId: sourceRoleId,
            screenplayIds: {screenplayId, otherScreenplayId},
          )
          .okOrFail;

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final survivor = (await roleIndexService.loadRoles(database: database).valueOrFail)
          .singleWhere((role) => role.id == targetRoleId);
      expect(survivor.episodeIds.toSet(), {screenplayId, otherScreenplayId});

      final sourceSharedLink =
          await (database.select(database.ocptRoleEpisodesTable)..where(
                (table) =>
                    table.roleId.equals(sourceRoleId) & table.screenplayId.equals(screenplayId),
              ))
              .getSingle();
      expect(sourceSharedLink.isDeleted, isTrue);
    });

    test("carries source's personId onto target only when target has none of its own", () async {
      const personId = "person-carry";
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: personId));
      await roleIndexService
          .updateRole(database: database, roleId: sourceRoleId, personId: const Value(personId))
          .okOrFail;

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final survivor = (await roleIndexService.loadRoles(database: database).valueOrFail)
          .singleWhere((role) => role.id == targetRoleId);
      expect(survivor.personId, personId);
    });

    test("never overwrites target's own personId with source's", () async {
      const sourcePersonId = "person-source";
      const targetPersonId = "person-target";
      for (final id in [sourcePersonId, targetPersonId]) {
        await database
            .into(database.ocptPeopleTable)
            .insert(OcptPeopleTableCompanion.insert(id: id));
      }
      await roleIndexService
          .updateRole(
            database: database,
            roleId: sourceRoleId,
            personId: const Value(sourcePersonId),
          )
          .okOrFail;
      await roleIndexService
          .updateRole(
            database: database,
            roleId: targetRoleId,
            personId: const Value(targetPersonId),
          )
          .okOrFail;

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final survivor = (await roleIndexService.loadRoles(database: database).valueOrFail)
          .singleWhere((role) => role.id == targetRoleId);
      expect(survivor.personId, targetPersonId);
    });

    test("carries source's castingNotes onto target only when target's own are empty", () async {
      await roleIndexService
          .updateRole(
            database: database,
            roleId: sourceRoleId,
            castingNotes: const Value("Great fit"),
          )
          .okOrFail;

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final survivor = (await roleIndexService.loadRoles(database: database).valueOrFail)
          .singleWhere((role) => role.id == targetRoleId);
      expect(survivor.castingNotes, "Great fit");
    });

    test("never overwrites target's own castingNotes with source's", () async {
      await roleIndexService
          .updateRole(
            database: database,
            roleId: sourceRoleId,
            castingNotes: const Value("From source"),
          )
          .okOrFail;
      await roleIndexService
          .updateRole(
            database: database,
            roleId: targetRoleId,
            castingNotes: const Value("From target"),
          )
          .okOrFail;

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final survivor = (await roleIndexService.loadRoles(database: database).valueOrFail)
          .singleWhere((role) => role.id == targetRoleId);
      expect(survivor.castingNotes, "From target");
    });

    test("never touches target's kind, sortKey, isFromScreenplay or orphanedName", () async {
      final before = (await roleIndexService.loadRoles(database: database).valueOrFail).singleWhere(
        (role) => role.id == targetRoleId,
      );

      await roleIndexService
          .mergeRole(database: database, sourceRoleId: sourceRoleId, targetRoleId: targetRoleId)
          .okOrFail;

      final after = (await roleIndexService.loadRoles(database: database).valueOrFail).singleWhere(
        (role) => role.id == targetRoleId,
      );
      expect(after.kind, before.kind);
      expect(after.isFromScreenplay, before.isFromScreenplay);
      expect(after.orphanedName, before.orphanedName);

      final targetRow = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(targetRoleId))).getSingle();
      expect(targetRow.sortKey, isNotEmpty);
    });
  });

  group("deleteRole cascade (decision 5)", () {
    test("tombstones the shot_characters rows naming the role", () async {
      final roleId = (await roleIndexService
          .addRole(
            database: database,
            screenplayId: screenplayId,
            name: "CLARA",
            kind: OcptRoleKind.extra,
          )
          .valueOrFail);
      await _insertShot(database, id: "shot-1", screenplayId: screenplayId);
      await _insertShotCharacter(database, shotId: "shot-1", roleId: roleId);

      await roleIndexService.deleteRole(database: database, roleId: roleId).okOrFail;

      final row = await (database.select(
        database.ocptShotCharactersTable,
      )..where((table) => table.shotId.equals("shot-1") & table.roleId.equals(roleId))).getSingle();
      expect(row.isDeleted, isTrue);
    });

    test("tombstones the breakdown_tags rows naming the role", () async {
      final roleId = (await roleIndexService
          .addRole(
            database: database,
            screenplayId: screenplayId,
            name: "CLARA",
            kind: OcptRoleKind.extra,
          )
          .valueOrFail);
      await _insertScene(database, id: "scene-1", screenplayId: screenplayId);
      await _insertRoleTag(database, id: "tag-1", sceneId: "scene-1", roleId: roleId);

      await roleIndexService.deleteRole(database: database, roleId: roleId).okOrFail;

      final tag = await (database.select(
        database.ocptBreakdownTagsTable,
      )..where((table) => table.id.equals("tag-1"))).getSingle();
      expect(tag.isDeleted, isTrue);
    });

    test("leaves shooting_slot_cast untouched — decision 5's own scope", () async {
      final roleId = (await roleIndexService
          .addRole(
            database: database,
            screenplayId: screenplayId,
            name: "CLARA",
            kind: OcptRoleKind.extra,
          )
          .valueOrFail);
      await _insertShootingDay(database, id: "day-1");
      await _insertShootingSlot(database, id: "slot-1", shootingDayId: "day-1");
      await _insertSlotCast(database, id: "cast-1", slotId: "slot-1", roleId: roleId);

      await roleIndexService.deleteRole(database: database, roleId: roleId).okOrFail;

      final cast = await (database.select(
        database.ocptShootingSlotCastTable,
      )..where((table) => table.id.equals("cast-1"))).getSingle();
      expect(cast.isDeleted, isFalse);
      expect(cast.roleId, roleId);
    });
  });
}
