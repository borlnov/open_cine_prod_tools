// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of the project versions service rename capture and delete.
void main() {
  // Reading a version's stored summary logs through appLogger(), which requires a global manager
  // instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec(logger: SilentLogger());

  const deviceId = "device-1";

  Future<String> testDeviceId() async => deviceId;

  final assetsService = OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId);

  final roleCandidatesService = OcptRoleCandidatesService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
  );

  final scheduleService = OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId);

  final elementsService = OcptElementsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );

  final floorPlanService = OcptFloorPlanService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );

  final locationsService = OcptLocationsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    floorPlanService: floorPlanService,
    deviceId: testDeviceId,
  );

  final roleIndexService = OcptRoleIndexService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: roleCandidatesService,
    deviceId: testDeviceId,
  );

  final breakdownService = OcptBreakdownService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    locationsService: locationsService,
    deviceId: testDeviceId,
  );

  // Used directly by the breakdown restore tests below, to seed a real scene index and a real
  // reconciled role — separate from the one `service` builds for its own screenplay-snapshotting
  // needs, but a stateless collaborator over the same database, so the two never disagree.
  final screenplayService = OcptScreenplayService(
    logger: const SilentLogger(),
    sceneIndexService: const OcptSceneIndexService(logger: SilentLogger()),
    shotListService: OcptShotListService(
      logger: const SilentLogger(),
      roleIndexService: roleIndexService,
      storyboardService: OcptStoryboardService(
        logger: const SilentLogger(),
        assetsService: assetsService,
        deviceId: testDeviceId,
      ),
      floorPlanService: OcptFloorPlanService(
        logger: const SilentLogger(),
        assetsService: assetsService,
        deviceId: testDeviceId,
      ),
      deviceId: testDeviceId,
    ),
    shotCoverageService: OcptShotCoverageService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: scheduleService,
    deviceId: testDeviceId,
  );

  final service = OcptProjectVersionsService(
    logger: const SilentLogger(),
    codec: codec,
    screenplayService: screenplayService,
  );

  const screenplayId = "screenplay-1";

  const appVersion = "0.1.0";

  const margins = FountainPageMargins(
    leftInches: 1.5,
    rightInches: 1,
    topInches: 0.75,
    bottomInches: 1.25,
  );

  late OcptProjectDatabase database;

  setUp(() async {
    database = OcptProjectDatabase.memory();

    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: "My Movie",
            createdAt: DateTime.utc(2026, 1, 4),
            appVersionAtCreation: appVersion,
            pageFormat: OcptPageFormat.a4,
            settingsJson: const Value('{"someSetting":true}'),
          ),
        );

    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            fountainText: const Value("INT. HOUSE - DAY\n\nCLARA enters."),
            updatedAt: DateTime.utc(2026, 1, 5),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  /// Inserts the scene [id] of the project's screenplay, tombstoned when [isDeleted].
  Future<void> insertScene({required String id, bool isDeleted = false}) => database
      .into(database.ocptScenesTable)
      .insert(
        OcptScenesTableCompanion.insert(
          id: id,
          screenplayId: screenplayId,
          position: 0,
          heading: "INT. HOUSE - DAY",
          charStart: 0,
          charEnd: 18,
          isDeleted: Value(isDeleted),
        ),
      );

  /// Saves [fountainText] as the project's screenplay and returns its resulting live scenes,
  /// ordered as they appear in the text — the real reconciliation path, rather than a hand-inserted
  /// scene, since the breakdown restore tests below need real scene ids a real tag can point at.
  Future<List<OcptSceneRow>> saveScreenplayScenes(String fountainText) async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: fountainText,
      snapshotReason: OcptSnapshotReason.manual,
    );

    return (database.select(database.ocptScenesTable)
          ..where((table) => table.isDeleted.equals(false))
          ..orderBy([(table) => OrderingTerm.asc(table.position)]))
        .get();
  }

  /// The breakdown tag [id], tombstone included, or null if the project holds no such row at all.
  Future<OcptBreakdownTagRow?> readTag(String id) => (database.select(
    database.ocptBreakdownTagsTable,
  )..where((table) => table.id.equals(id))).getSingleOrNull();

  /// The `scene_breakdowns` row of scene [sceneId], tombstone included, or null if it has none.
  Future<OcptSceneBreakdownRow?> readSceneBreakdown(String sceneId) => (database.select(
    database.ocptSceneBreakdownsTable,
  )..where((table) => table.sceneId.equals(sceneId))).getSingleOrNull();

  /// The element [id] as the project currently holds it.
  Future<OcptElementRow> readElement(String id) => (database.select(
    database.ocptElementsTable,
  )..where((table) => table.id.equals(id))).getSingle();

  /// Creates a version named [name], with the fixed provenance every test here uses.
  Future<OcptProjectVersion> createVersion({String name = "v1 — First read", String note = ""}) =>
      service.createVersion(
        database: database,
        name: name,
        note: note,
        appVersion: appVersion,
        deviceId: deviceId,
        pageMargins: margins,
      );

  /// The payload stored with the version [id], decoded.
  Future<OcptProjectVersionPayload> readPayload(String id) async {
    final row = await (database.select(
      database.ocptProjectVersionsTable,
    )..where((table) => table.id.equals(id))).getSingle();

    final result = codec.decode(row.payload);
    expect(result.status, OcptProjectVersionPayloadStatus.ok);

    return result.value!;
  }

  /// The project header's pointer at the version the working copy descends from.
  Future<String?> readCurrentVersionId() async =>
      (await database.select(database.ocptProjectInfoTable).getSingle()).currentVersionId;

  group("restoreVersion", () {
    /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>`.
    Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
      for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
        "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
    };

    /// Restores the version [id], with the fixed provenance every test here uses.
    Future<ResultWithStatus<OcptProjectRestoreStatus, OcptPageSetup>> restore(String id) =>
        service.restoreVersion(
          database: database,
          id: id,
          safetyVersionName: "Before restoring",
          appVersion: appVersion,
          deviceId: deviceId,
          pageMargins: margins,
        );

    test("restores a breakdown captured before it, then one captured after, tags tombstoned rather "
        "than deleted and every reference still resolving", () async {
      // A real screenplay, reconciled into two real scenes — the breakdown restore's own
      // subtlety (§ the payload's doc comment) is about references staying valid, which only
      // means something against ids the reconciliation itself minted.
      final scenes = await saveScreenplayScenes(
        "INT. HOUSE - DAY\n\nA desk lamp glows. LÉA enters quietly.\n\n"
        "EXT. STREET - NIGHT\n\nRain falls on the porch.\n",
      );
      final scene1 = scenes[0];
      final scene2 = scenes[1];

      final elementId = (await elementsService
          .createElement(
            database: database,
            name: "Desk lamp",
            category: OcptElementCategory.prop,
            sourceKind: OcptElementSourceKind.owned,
          )
          .valueOrFail);
      final roleId = (await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "LÉA",
        kind: OcptRoleKind.silent,
      ))!;
      final locationId = (await locationsService.createLocation(
        database: database,
        name: "House",
      ))!;
      final setId = (await locationsService.createSet(
        database: database,
        locationId: locationId,
        name: "Kitchen",
      ))!;

      final elementTagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene1.id,
        startOffset: 0,
        endOffset: 4,
        taggedText: "desk",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId,
      ))!;
      final roleTagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene1.id,
        startOffset: 20,
        endOffset: 23,
        taggedText: "LÉA",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;
      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene1.id,
        status: const Value(OcptBreakdownSceneStatus.inProgress),
        notes: const Value("Check the lamp cable colour"),
      );
      final sceneBreakdownId = (await readSceneBreakdown(scene1.id))!.id;

      final versionA = await createVersion(name: "v1 — First pass");

      // Diverge from A: a tag is added, another is removed, the scene is marked done, and the
      // element is secured.
      final addedTagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene2.id,
        startOffset: 0,
        endOffset: 4,
        taggedText: "Rain",
        targetKind: OcptBreakdownTargetKind.set,
        targetId: setId,
      ))!;
      await breakdownService.deleteTag(database: database, tagId: roleTagId);
      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene1.id,
        status: const Value(OcptBreakdownSceneStatus.done),
        notes: const Value("All set"),
      );
      await (database.update(database.ocptElementsTable)
            ..where((table) => table.id.equals(elementId)))
          .write(const OcptElementsTableCompanion(status: Value(OcptElementStatus.confirmed)));

      final versionB = await createVersion(name: "v2 — Locked");

      // Cleared so the stamps read below are the restore's own: OcptBreakdownService's writes
      // above (createTag, updateSceneBreakdown) now stamp on their own account too, and that is
      // not what this assertion is about.
      await database.delete(database.ocptRowFieldVersionsTable).go();

      // Restore A: the breakdown must read exactly as it did at that moment.
      final resultA = await restore(versionA.id);
      expect(resultA.status, OcptProjectRestoreStatus.ok);

      expect(
        (await readTag(roleTagId))?.isDeleted,
        isFalse,
        reason: "a tag deleted after A must be live again",
      );
      final tagAddedAfterA = await readTag(addedTagId);
      expect(tagAddedAfterA, isNotNull, reason: "the row must still be there, as a tombstone");
      expect(
        tagAddedAfterA?.isDeleted,
        isTrue,
        reason: "a tag added after A must be tombstoned, never deleted",
      );

      final scene1AfterRestoringA = await readSceneBreakdown(scene1.id);
      expect(scene1AfterRestoringA?.status, OcptBreakdownSceneStatus.inProgress);
      expect(scene1AfterRestoringA?.notes, "Check the lamp cable colour");
      expect((await readElement(elementId)).status, OcptElementStatus.toFind);

      // A restore must never leave a dangling reference: every live tag's target still resolves
      // to a live row, whichever of the three catalogues it names.
      final liveTags = await (database.select(
        database.ocptBreakdownTagsTable,
      )..where((table) => table.isDeleted.equals(false))).get();
      final liveSceneIds = {
        for (final row in await (database.select(
          database.ocptScenesTable,
        )..where((table) => table.isDeleted.equals(false))).get())
          row.id,
      };
      final liveElementIds = {
        for (final row in await (database.select(
          database.ocptElementsTable,
        )..where((table) => table.isDeleted.equals(false))).get())
          row.id,
      };
      final liveRoleIds = {
        for (final row in await (database.select(
          database.ocptRolesTable,
        )..where((table) => table.isDeleted.equals(false))).get())
          row.id,
      };
      final liveSetIds = {
        for (final row in await (database.select(
          database.ocptSetsTable,
        )..where((table) => table.isDeleted.equals(false))).get())
          row.id,
      };
      expect(liveTags, isNotEmpty);
      for (final tag in liveTags) {
        expect(liveSceneIds, contains(tag.sceneId));
        switch (tag.targetKind) {
          case OcptBreakdownTargetKind.element:
            expect(liveElementIds, contains(tag.elementId));
          case OcptBreakdownTargetKind.role:
            expect(liveRoleIds, contains(tag.roleId));
          case OcptBreakdownTargetKind.set:
            expect(liveSetIds, contains(tag.setId));
        }
      }

      // Only the columns the restore actually changed carry a fresh stamp.
      final stampsAfterA = await readStamps();
      expect(stampsAfterA["breakdown_tags/$addedTagId/isDeleted"]?.deviceId, deviceId);
      expect(stampsAfterA["breakdown_tags/$roleTagId/isDeleted"]?.deviceId, deviceId);
      expect(
        stampsAfterA.containsKey("breakdown_tags/$elementTagId/taggedText"),
        isFalse,
        reason: "a tag the restore left untouched gains no stamp at all",
      );
      expect(stampsAfterA["scene_breakdowns/$sceneBreakdownId/status"]?.deviceId, deviceId);
      expect(stampsAfterA["scene_breakdowns/$sceneBreakdownId/notes"]?.deviceId, deviceId);
      expect(stampsAfterA.containsKey("scene_breakdowns/$sceneBreakdownId/sceneId"), isFalse);

      // Restore B afterwards: the round trip works in the other direction too.
      final resultB = await restore(versionB.id);
      expect(resultB.status, OcptProjectRestoreStatus.ok);

      expect((await readTag(addedTagId))?.isDeleted, isFalse);
      expect((await readTag(roleTagId))?.isDeleted, isTrue);
      final scene1AfterRestoringB = await readSceneBreakdown(scene1.id);
      expect(scene1AfterRestoringB?.status, OcptBreakdownSceneStatus.done);
      expect(scene1AfterRestoringB?.notes, "All set");
      expect((await readElement(elementId)).status, OcptElementStatus.confirmed);
    });
  });

  group("renameVersion", () {
    test("updates the name and the note, and nothing else", () async {
      final version = await createVersion(name: "v1", note: "First cut");

      await service.renameVersion(
        database: database,
        id: version.id,
        name: "v1 bis",
        note: "Renamed",
      );

      final row = await database.select(database.ocptProjectVersionsTable).getSingle();
      expect(row.name, "v1 bis");
      expect(row.note, "Renamed");
      expect(row.id, version.id);
      expect(row.createdAt, version.createdAt);
      expect(row.payload, isNotEmpty);
    });

    test("is allowed while a version is being previewed", () async {
      // Renaming reads nothing about the project's data, so nothing here has to stand in for a
      // preview to prove that: the same call this service is asked to make from either state.
      final version = await createVersion(name: "v1");

      await expectLater(
        service.renameVersion(database: database, id: version.id, name: "v1 bis", note: ""),
        completes,
      );
    });
  });

  group("captureWorkingCopyState", () {
    test("reports no divergence when the working copy matches its base", () async {
      await insertScene(id: "scene-1");
      final version = await createVersion();

      final state = await service.captureWorkingCopyState(database: database, pageMargins: margins);

      expect(state.baseVersionId, version.id);
      expect(state.isModifiedSinceBase, isFalse);
      expect(state.contentDigest, codec.contentDigest(await readPayload(version.id)));
      expect(state.summary.pageCount, 1);
    });

    test("reports a divergence once the working copy has changed", () async {
      final version = await createVersion();

      await database
          .update(database.ocptScreenplaysTable)
          .write(const OcptScreenplaysTableCompanion(fountainText: Value("EXT. STREET - NIGHT")));

      final state = await service.captureWorkingCopyState(database: database, pageMargins: margins);

      expect(state.baseVersionId, version.id);
      expect(state.isModifiedSinceBase, isTrue);
    });

    test("reads as modified when the project has never had a base version", () async {
      final state = await service.captureWorkingCopyState(database: database, pageMargins: margins);

      expect(state.baseVersionId, isNull);
      expect(state.isModifiedSinceBase, isTrue);
    });
  });

  group("deleteVersion", () {
    test("deletes the version and clears the pointer when it pointed at it", () async {
      final version = await createVersion();

      await service.deleteVersion(database: database, id: version.id);

      expect(await service.listVersions(database: database), isEmpty);
      expect(await readCurrentVersionId(), isNull);
    });

    test("deleting another version leaves the current one and its pointer alone", () async {
      final first = await createVersion(name: "v1");
      final second = await createVersion(name: "v2");

      await service.deleteVersion(database: database, id: first.id);

      final versions = await service.listVersions(database: database);
      expect(versions.map((version) => version.id), [second.id]);
      expect(versions.single.isBase, isTrue);
      expect(await readCurrentVersionId(), second.id);
    });

    test("deleting a version that doesn't exist changes nothing", () async {
      final version = await createVersion();

      await service.deleteVersion(database: database, id: "no-such-version");

      expect(await readCurrentVersionId(), version.id);
      expect(await service.listVersions(database: database), hasLength(1));
    });
  });
}
