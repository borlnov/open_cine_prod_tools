// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
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
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

/// Run the tests of the project versions service create and load.
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

  // Used directly by the `hydratePreview` storyboard/floor plan test below, so the panel, its
  // image asset, its annotation, the case, its symbols and its arrow are all written the same
  // way the board and the floor plans view themselves would, rather
  // than by hand-inserted rows.
  final storyboardService = OcptStoryboardService(
    logger: const SilentLogger(),
    assetsService: assetsService,
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

  /// Inserts the shot [id] of scene [sceneId], tombstoned when [isDeleted].
  Future<void> insertShot({required String id, required String sceneId, bool isDeleted = false}) =>
      database
          .into(database.ocptShotsTable)
          .insert(
            OcptShotsTableCompanion.insert(
              id: id,
              screenplayId: screenplayId,
              sceneId: Value(sceneId),
              position: 0,
              sortKey: const Value("V"),
              framing: const Value("Low angle"),
              status: const Value(OcptShotStatus.shot),
              isDeleted: Value(isDeleted),
            ),
          );

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

  group("createVersion", () {
    test("records the version, its provenance and its measured summary", () async {
      await insertScene(id: "scene-1");
      await insertShot(id: "shot-1", sceneId: "scene-1");

      final version = await createVersion(note: "Before the rewrite");

      expect(version.name, "v1 — First read");
      expect(version.note, "Before the rewrite");
      expect(version.isBase, isTrue);
      expect(version.summary.pageCount, 1);
      expect(version.summary.brokenDownSequenceCount, 1);

      final row = await database.select(database.ocptProjectVersionsTable).getSingle();
      expect(row.id, version.id);
      expect(row.appVersion, appVersion);
      expect(row.createdByDeviceId, deviceId);
      expect(row.payloadFormat, OcptProjectVersionCodec.currentPayloadFormat);
      expect(row.createdAt, version.createdAt);
    });

    test("makes the new version the one the working copy descends from", () async {
      final first = await createVersion(name: "v1");
      expect(await readCurrentVersionId(), first.id);

      final second = await createVersion(name: "v2");
      expect(await readCurrentVersionId(), second.id);
    });

    test("captures the project's rows verbatim, tombstones and scene ids included", () async {
      await insertScene(id: "scene-1");
      await insertScene(id: "scene-gone", isDeleted: true);
      await insertShot(id: "shot-1", sceneId: "scene-1");
      await insertShot(id: "shot-gone", sceneId: "scene-1", isDeleted: true);

      final version = await createVersion();
      final payload = await readPayload(version.id);

      // Every row is there, tombstoned ones included: a version holding only the live rows would
      // resurrect, on restore, everything the user had deleted since.
      expect(payload.scenes.map((row) => row.id), containsAll(["scene-1", "scene-gone"]));
      expect(payload.shots.map((row) => row.id), containsAll(["shot-1", "shot-gone"]));
      expect(payload.scenes.firstWhere((row) => row.id == "scene-gone").isDeleted, isTrue);
      expect(payload.shots.firstWhere((row) => row.id == "shot-gone").isDeleted, isTrue);

      // And they are the rows themselves, not a re-derivation of them.
      final shot = payload.shots.firstWhere((row) => row.id == "shot-1");
      expect(shot.sceneId, "scene-1");
      expect(shot.sortKey, "V");
      expect(shot.framing, "Low angle");
      expect(shot.status, OcptShotStatus.shot);
      expect(payload.screenplays.single.fountainText, "INT. HOUSE - DAY\n\nCLARA enters.");
    });

    test("captures the version stamps of the tables it carries, and no others", () async {
      await insertScene(id: "scene-1");
      await insertShot(id: "shot-1", sceneId: "scene-1");

      await database
          .into(database.ocptRowFieldVersionsTable)
          .insert(
            OcptRowFieldVersionsTableCompanion.insert(
              targetTableName: "shots",
              rowId: "shot-1",
              columnName: "framing",
              version: 7,
              deviceId: "device-0",
            ),
          );
      await database
          .into(database.ocptRowFieldVersionsTable)
          .insert(
            OcptRowFieldVersionsTableCompanion.insert(
              targetTableName: "project_info",
              rowId: "1",
              columnName: "pageFormat",
              version: 2,
              deviceId: "device-0",
            ),
          );

      final payload = await readPayload((await createVersion()).id);

      expect(payload.rowFieldVersions, hasLength(1));
      expect(payload.rowFieldVersions.single.targetTableName, "shots");
      expect(payload.rowFieldVersions.single.version, 7);
    });

    test("captures the whole page setup: the project's format and the app's margins", () async {
      final payload = await readPayload((await createVersion()).id);

      expect(payload.pageSetup.format, OcptPageFormat.a4);
      expect(payload.pageSetup.margins, margins);
      expect(payload.settingsJson, '{"someSetting":true}');
    });

    test("captures the project's learned words, tombstones included", () async {
      await database
          .into(database.ocptProjectDictionaryWordsTable)
          .insert(OcptProjectDictionaryWordsTableCompanion.insert(id: "word-1", word: "Séquence"));
      await database
          .into(database.ocptProjectDictionaryWordsTable)
          .insert(
            OcptProjectDictionaryWordsTableCompanion.insert(
              id: "word-2",
              word: "Marc",
              isDeleted: const Value(true),
            ),
          );

      final payload = await readPayload((await createVersion()).id);

      expect(
        payload.projectDictionaryWords.map((row) => row.id),
        containsAll(["word-1", "word-2"]),
      );
      expect(
        payload.projectDictionaryWords.firstWhere((row) => row.id == "word-1").isDeleted,
        isFalse,
      );
      expect(
        payload.projectDictionaryWords.firstWhere((row) => row.id == "word-2").isDeleted,
        isTrue,
      );
    });

    test("stamps the row with the content digest of the payload it just captured", () async {
      await insertScene(id: "scene-1");
      await insertShot(id: "shot-1", sceneId: "scene-1");

      final version = await createVersion();
      final payload = await readPayload(version.id);

      final row = await database.select(database.ocptProjectVersionsTable).getSingle();
      expect(row.contentDigest, codec.contentDigest(payload));
    });
  });

  group("listVersions", () {
    test("lists the versions newest first, flagging the current one alone", () async {
      final first = await createVersion(name: "v1");
      final second = await createVersion(name: "v2");
      final third = await createVersion(name: "v3");

      // The pointer follows the last creation, so make an older one current again by hand: the
      // list must read it off the header rather than assume the newest is the current one.
      await database
          .update(database.ocptProjectInfoTable)
          .write(OcptProjectInfoTableCompanion(currentVersionId: Value(second.id)));

      final versions = await service.listVersions(database: database);

      expect(versions.map((version) => version.id), [third.id, second.id, first.id]);
      expect(versions.map((version) => version.isBase), [false, true, false]);
    });

    test("renders a version whose stored counters can't be read rather than hiding it", () async {
      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-broken",
              name: "v1 — Written by something else",
              createdAt: DateTime.utc(2026, 6, 2),
              appVersion: appVersion,
              payloadFormat: OcptProjectVersionCodec.currentPayloadFormat,
              // Listing must not deserialize payloads at all: an unreadable one changes nothing.
              payload: "not json",
              summaryJson: "not json",
              createdByDeviceId: deviceId,
            ),
          );

      final versions = await service.listVersions(database: database);

      expect(versions.single.name, "v1 — Written by something else");
      expect(versions.single.summary.pageCount, 0);
    });

    test("a project which never had a version lists none", () async {
      expect(await service.listVersions(database: database), isEmpty);
    });
  });

  group("loadVersion", () {
    test("loads one version's card fields, flagged current off the project header", () async {
      await createVersion(name: "v1");
      final second = await createVersion(name: "v2 — Shot list", note: "Seq. 1 to 3");

      final version = await service.loadVersion(database: database, id: second.id);

      expect(version?.id, second.id);
      expect(version?.name, "v2 — Shot list");
      expect(version?.note, "Seq. 1 to 3");
      expect(version?.createdAt, second.createdAt);
      expect(version?.summary, second.summary);
      expect(version?.isBase, isTrue);
    });

    test("returns null for a version this project doesn't have", () async {
      await createVersion();

      expect(await service.loadVersion(database: database, id: "no-such-version"), isNull);
    });
  });

  group("loadPayload", () {
    test("decodes the payload stored with the version", () async {
      await insertScene(id: "scene-1");
      await insertShot(id: "shot-1", sceneId: "scene-1");
      final version = await createVersion();

      final result = await service.loadPayload(database: database, id: version.id);

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value?.scenes.single.id, "scene-1");
      expect(result.value?.shots.single.id, "shot-1");
      expect(result.value?.pageSetup.margins, margins);
    });

    test("refuses a payload written in a format this build doesn't know", () async {
      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-from-the-future",
              name: "v1 — Written by a later build",
              createdAt: DateTime.utc(2026, 6, 2),
              appVersion: "99.0.0",
              payloadFormat: OcptProjectVersionCodec.currentPayloadFormat + 1,
              payload: '{"payloadFormat":${OcptProjectVersionCodec.currentPayloadFormat + 1}}',
              summaryJson: "{}",
              createdByDeviceId: deviceId,
            ),
          );

      final result = await service.loadPayload(database: database, id: "version-from-the-future");

      expect(result.status, OcptProjectVersionPayloadStatus.unsupportedFutureFormat);
      expect(result.value, isNull);
    });

    test("reports a version this project doesn't have rather than throwing", () async {
      final result = await service.loadPayload(database: database, id: "no-such-version");

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
      expect(result.value, isNull);
    });
  });

  group("hydratePreview", () {
    test("writes the payload's rows verbatim into an empty preview database", () async {
      await insertScene(id: "scene-1");
      await insertScene(id: "scene-gone", isDeleted: true);
      await insertShot(id: "shot-1", sceneId: "scene-1");
      await insertShot(id: "shot-gone", sceneId: "scene-1", isDeleted: true);
      await database
          .into(database.ocptRolesTable)
          .insert(
            OcptRolesTableCompanion.insert(
              id: "role-1",
              name: "CLARA",
              kind: OcptRoleKind.speaking,
            ),
          );
      await database
          .into(database.ocptShotCharactersTable)
          .insert(
            OcptShotCharactersTableCompanion.insert(
              shotId: "shot-1",
              roleId: "role-1",
              position: 0,
              sortKey: const Value("V"),
            ),
          );
      await database
          .into(database.ocptShotCoveragesTable)
          .insert(
            OcptShotCoveragesTableCompanion.insert(
              id: "coverage-1",
              shotId: "shot-1",
              sceneId: "scene-1",
              startOffset: 0,
              endOffset: 5,
              coveredTextDigest: "digest",
            ),
          );
      await database
          .into(database.ocptRowFieldVersionsTable)
          .insert(
            OcptRowFieldVersionsTableCompanion.insert(
              targetTableName: "shots",
              rowId: "shot-1",
              columnName: "framing",
              version: 7,
              deviceId: "device-0",
            ),
          );
      final elementId = (await elementsService.createElement(
        database: database,
        name: "Desk lamp",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      ))!;
      await breakdownService.createTag(
        database: database,
        sceneId: "scene-1",
        startOffset: 0,
        endOffset: 4,
        taggedText: "desk",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId,
      );
      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: "scene-1",
        status: const Value(OcptBreakdownSceneStatus.inProgress),
        notes: const Value("Check the lamp"),
      );

      final payload = await readPayload((await createVersion()).id);

      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      await service.hydratePreview(
        database: preview,
        projectInfo: await database.select(database.ocptProjectInfoTable).getSingle(),
        payload: payload,
      );

      expect(await preview.select(preview.ocptScreenplaysTable).get(), payload.screenplays);
      expect(await preview.select(preview.ocptScenesTable).get(), payload.scenes);
      expect(await preview.select(preview.ocptShotsTable).get(), payload.shots);
      expect(await preview.select(preview.ocptShotCharactersTable).get(), payload.shotCharacters);
      expect(await preview.select(preview.ocptShotCoveragesTable).get(), payload.shotCoverages);
      expect(await preview.select(preview.ocptBreakdownTagsTable).get(), payload.breakdownTags);
      expect(await preview.select(preview.ocptSceneBreakdownsTable).get(), payload.sceneBreakdowns);
      expect(
        await preview.select(preview.ocptRowFieldVersionsTable).get(),
        payload.rowFieldVersions,
      );
    });

    test("the storyboard and floor plan tables — a panel with an image asset, its annotation, a "
        "linked set's plan, a shot-scoped symbol, a scene-scope override and an arrow — all come "
        "back", () async {
      // Regression test for a past preview bug: `hydratePreview` held its own hand-written
      // insert list, separate from `_applyPayload`'s, and was never updated when
      // these five tables were added — so a version captured with a storyboard panel previewed
      // as an empty board. Every row here is written through the real services, exactly as the
      // board and the floor plans view themselves would.
      await insertScene(id: "scene-1");
      await insertShot(id: "shot-1", sceneId: "scene-1");

      final panelId = (await storyboardService.addPanel(database: database, shotId: "shot-1"))!;
      await storyboardService.replacePanelImage(
        database: database,
        panelId: panelId,
        path: "/frames/shot-1.png",
      );
      await storyboardService.updatePanelComment(
        database: database,
        panelId: panelId,
        comment: "Push in on the door",
      );
      final annotationId = (await storyboardService.addAnnotation(
        database: database,
        panelId: panelId,
        kind: OcptStoryboardAnnotationKind.movementArrow,
        x1: 0.1,
        y1: 0.2,
        x2: 0.8,
        y2: 0.6,
        text: "walks to the door",
      ))!;

      final setId = (await locationsService.createSetLinkedToScene(
        database: database,
        sceneId: "scene-1",
        name: "Kitchen",
      ))!;
      final cameraId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        xM: 1.2,
        yM: 3.4,
        fovReachM: 5.5,
        label: "A",
      ))!;
      final characterId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
        xM: 2.5,
        yM: 1.1,
        label: "CLARA",
      ))!;
      final arrowId = (await floorPlanService.addArrow(
        database: database,
        setId: setId,
        shotId: "shot-1",
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: characterId,
        toSymbolId: cameraId,
        label: "crosses to the camera",
      ))!;
      // A set-scope décor symbol, and a scene-scope override replacing it in scene-1 — the
      // override rule must survive a preview too.
      final originalWallId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
        label: "North wall",
      ))!;
      final overrideWallId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: "scene-1",
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0.5,
        yM: 0.5,
        label: "North wall, re-dressed",
        overridesSymbolId: originalWallId,
        isHidden: true,
      ))!;

      final payload = await readPayload((await createVersion()).id);

      // The payload itself must already carry every one of the rows just written — a gap here
      // would mean `_capturePayload` dropped them, not `hydratePreview`.
      expect(payload.storyboardPanels.map((row) => row.id), [panelId]);
      expect(payload.storyboardAnnotations.map((row) => row.id), [annotationId]);
      expect(payload.floorPlanSets.map((row) => row.id), [setId]);
      expect(payload.floorPlanSymbols.map((row) => row.id).toSet(), {
        cameraId,
        characterId,
        originalWallId,
        overrideWallId,
      });
      expect(payload.floorPlanArrows.map((row) => row.id), [arrowId]);

      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      await service.hydratePreview(
        database: preview,
        projectInfo: await database.select(database.ocptProjectInfoTable).getSingle(),
        payload: payload,
      );

      final restoredPanel = await (preview.select(
        preview.ocptStoryboardPanelsTable,
      )..where((table) => table.id.equals(panelId))).getSingle();
      expect(restoredPanel.shotId, "shot-1");
      expect(restoredPanel.comment, "Push in on the door");
      expect(restoredPanel.imageAssetId, isNotNull);

      final restoredAsset = await (preview.select(
        preview.ocptAssetsTable,
      )..where((table) => table.id.equals(restoredPanel.imageAssetId!))).getSingle();
      expect(restoredAsset.path, "/frames/shot-1.png");

      final restoredAnnotation = await (preview.select(
        preview.ocptStoryboardAnnotationsTable,
      )..where((table) => table.id.equals(annotationId))).getSingle();
      expect(restoredAnnotation.panelId, panelId);
      expect(restoredAnnotation.kind, OcptStoryboardAnnotationKind.movementArrow);
      expect(restoredAnnotation.x1, 0.1);
      expect(restoredAnnotation.y2, 0.6);
      expect(restoredAnnotation.labelText, "walks to the door");

      final restoredPlan = await (preview.select(
        preview.ocptFloorPlanSetsTable,
      )..where((table) => table.id.equals(setId))).getSingle();
      expect(restoredPlan.id, setId);

      // The Resources set and its `scene_sets` link survived the preview too — `floor_plan_sets
      // .id` being `sets.id` means the plan is meaningless without them.
      final restoredSet = await (preview.select(
        preview.ocptSetsTable,
      )..where((table) => table.id.equals(setId))).getSingle();
      expect(restoredSet.name, "Kitchen");
      final restoredLink = (await (preview.select(
        preview.ocptSceneSetsTable,
      )..where((table) => table.setId.equals(setId))).getSingle());
      expect(restoredLink.sceneId, "scene-1");
      expect(restoredLink.isDeleted, isFalse);

      // The scene-scope override survived, still naming its set-scope original.
      final restoredOverride = await (preview.select(
        preview.ocptFloorPlanSymbolsTable,
      )..where((table) => table.id.equals(overrideWallId))).getSingle();
      expect(restoredOverride.sceneId, "scene-1");
      expect(restoredOverride.overridesSymbolId, originalWallId);
      expect(restoredOverride.label, "North wall, re-dressed");
      // isHidden must survive the preview too — a fresh column, and a second hand-written insert
      // list (`hydratePreview`'s own) that a new synchronised field can just as easily be added to
      // one of the two write paths and not the other (see `_applyPayload`'s own sibling check
      // below).
      expect(restoredOverride.isHidden, isTrue);

      final restoredCamera = await (preview.select(
        preview.ocptFloorPlanSymbolsTable,
      )..where((table) => table.id.equals(cameraId))).getSingle();
      expect(restoredCamera.setId, setId);
      expect(restoredCamera.shotId, "shot-1");
      expect(restoredCamera.layer, OcptFloorPlanLayer.cameras);
      expect(restoredCamera.xM, 1.2);
      expect(restoredCamera.yM, 3.4);
      expect(restoredCamera.fovReachM, 5.5);

      final restoredArrow = await (preview.select(
        preview.ocptFloorPlanArrowsTable,
      )..where((table) => table.id.equals(arrowId))).getSingle();
      expect(restoredArrow.setId, setId);
      expect(restoredArrow.shotId, "shot-1");
      expect(restoredArrow.kind, OcptFloorPlanArrowKind.movement);
      expect(restoredArrow.fromSymbolId, characterId);
      expect(restoredArrow.toSymbolId, cameraId);
    });

    test("gives the preview a header of the project's own, pointing at no version", () async {
      final payload = await readPayload((await createVersion()).id);

      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      await service.hydratePreview(
        database: preview,
        projectInfo: await database.select(database.ocptProjectInfoTable).getSingle(),
        payload: payload,
      );

      final info = await preview.select(preview.ocptProjectInfoTable).getSingle();
      expect(info.name, "My Movie");
      expect(info.createdAt, DateTime.utc(2026, 1, 4));
      expect(info.appVersionAtCreation, appVersion);
      // The page format and the settings are the payload's; the version list is not copied at all,
      // so the pointer into it has nothing to point at.
      expect(info.pageFormat, payload.pageSetup.format);
      expect(info.settingsJson, payload.settingsJson);
      expect(info.currentVersionId, isNull);
      expect(await preview.select(preview.ocptProjectVersionsTable).get(), isEmpty);
    });
  });

  group("restoreVersion", () {
    const capturedText = "INT. HOUSE - DAY\n\nCLARA enters.";

    const rewrittenText = "EXT. STREET - NIGHT\n\nThe rewrite.";

    /// The screenplay's text as the project currently holds it.
    Future<String> readScreenplayText() async =>
        (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText;

    /// The shot [id] as the project currently holds it, tombstone included.
    Future<OcptShotRow?> readShot(String id) => (database.select(
      database.ocptShotsTable,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

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

    /// Captures the project as a version, then makes the working copy diverge from it: the
    /// screenplay is rewritten, one shot is edited, and another is added.
    Future<OcptProjectVersion> createDivergedProject() async {
      await insertScene(id: "scene-1");
      await insertShot(id: "shot-1", sceneId: "scene-1");

      final version = await createVersion();

      await database
          .update(database.ocptScreenplaysTable)
          .write(const OcptScreenplaysTableCompanion(fountainText: Value(rewrittenText)));
      await (database.update(database.ocptShotsTable)..where((table) => table.id.equals("shot-1")))
          .write(const OcptShotsTableCompanion(framing: Value("High angle")));
      await insertShot(id: "shot-2", sceneId: "scene-1");

      return version;
    }

    test("puts back what the version held, and points the project at it", () async {
      final version = await createDivergedProject();

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      expect(await readScreenplayText(), capturedText);
      expect((await readShot("shot-1"))?.framing, "Low angle");
      expect(await readCurrentVersionId(), version.id);

      // The margins the caller has to finish restoring — they are a preference, so this service
      // hands them back rather than writing them.
      expect(result.value?.margins, margins);
      expect(result.value?.format, OcptPageFormat.a4);
    });

    test("a hidden floor-plan override's own isHidden survives the restore too", () async {
      // `_applyPayload`'s own write path — `hydratePreview`'s own equivalent is asserted
      // separately, since a synchronised table (or, here, a synchronised column) has to be wired
      // into both (see [[versions-service-two-payload-write-paths]]).
      await insertScene(id: "scene-1");
      final setId = (await locationsService.createSetLinkedToScene(
        database: database,
        sceneId: "scene-1",
        name: "Kitchen",
      ))!;
      final originalId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;
      final overrideId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: "scene-1",
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 1,
        yM: 1,
        overridesSymbolId: originalId,
        isHidden: true,
      ))!;

      final version = await createVersion();
      // Diverge: unhide the override in the working copy, so restoring is a real change.
      await floorPlanService.updateSymbol(
        database: database,
        symbolId: overrideId,
        isHidden: const Value(false),
      );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      final restored = await (database.select(
        database.ocptFloorPlanSymbolsTable,
      )..where((table) => table.id.equals(overrideId))).getSingle();
      expect(restored.isHidden, isTrue);
    });

    test("tombstones what the version didn't hold instead of deleting it", () async {
      final version = await createDivergedProject();

      await restore(version.id);

      final droppedShot = await readShot("shot-2");
      expect(droppedShot, isNotNull, reason: "the row must still be there, as a tombstone");
      expect(droppedShot?.isDeleted, isTrue);

      // And the shot list the user sees is the version's own.
      final liveShots = await (database.select(
        database.ocptShotsTable,
      )..where((table) => table.isDeleted.equals(false))).get();
      expect(liveShots.map((shot) => shot.id), ["shot-1"]);
    });
  });
}
