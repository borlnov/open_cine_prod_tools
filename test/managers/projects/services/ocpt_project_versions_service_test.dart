// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

void main() {
  // Reading a version's stored summary logs through appLogger(), which requires a global manager
  // instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec();
  const peopleService = OcptPeopleService();
  const scheduleService = OcptScheduleService();
  const roleIndexService = OcptRoleIndexService();
  const elementsService = OcptElementsService();
  const locationsService = OcptLocationsService();
  const breakdownService = OcptBreakdownService(
    elementsService: elementsService,
    locationsService: locationsService,
  );
  const deviceId = "device-1";
  Future<String> testDeviceId() async => deviceId;
  // Used directly by the breakdown restore tests below, to seed a real scene index and a real
  // reconciled role — separate from the one `service` builds for its own screenplay-snapshotting
  // needs, but a stateless collaborator over the same database, so the two never disagree.
  final screenplayService = OcptScreenplayService(
    sceneIndexService: const OcptSceneIndexService(),
    shotListService: OcptShotListService(deviceId: testDeviceId),
    shotCoverageService: OcptShotCoverageService(deviceId: testDeviceId),
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: scheduleService,
    deviceId: testDeviceId,
  );
  final service = OcptProjectVersionsService(codec: codec, screenplayService: screenplayService);
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
  Future<void> insertShot({
    required String id,
    required String sceneId,
    bool isDeleted = false,
  }) => database
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

  /// Inserts the shooting day [id], belonging to no episode, tombstoned when [isDeleted].
  Future<void> insertShootingDay({
    required String id,
    DateTime? date,
    String sortKey = "V",
    bool isDeleted = false,
  }) => database
      .into(database.ocptShootingDaysTable)
      .insert(
        OcptShootingDaysTableCompanion.insert(
          id: id,
          date: date ?? DateTime.utc(2026, 3, 10),
          sortKey: Value(sortKey),
          isDeleted: Value(isDeleted),
        ),
      );

  /// Inserts the shooting slot [id] of shooting day [shootingDayId], tombstoned when [isDeleted].
  Future<void> insertShootingSlot({
    required String id,
    required String shootingDayId,
    String sortKey = "V",
    int anchorMinute = 420,
    bool isDeleted = false,
  }) => database
      .into(database.ocptShootingSlotsTable)
      .insert(
        OcptShootingSlotsTableCompanion.insert(
          id: id,
          shootingDayId: shootingDayId,
          sortKey: Value(sortKey),
          anchorMinute: Value(anchorMinute),
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
      expect(
        payload.scenes.firstWhere((row) => row.id == "scene-gone").isDeleted,
        isTrue,
      );
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
          .insert(
            OcptProjectDictionaryWordsTableCompanion.insert(id: "word-1", word: "Séquence"),
          );
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

      expect(payload.projectDictionaryWords.map((row) => row.id), containsAll(["word-1", "word-2"]));
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
          .into(database.ocptShotCharactersTable)
          .insert(
            OcptShotCharactersTableCompanion.insert(
              shotId: "shot-1",
              characterName: "CLARA",
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
      expect(
        await preview.select(preview.ocptSceneBreakdownsTable).get(),
        payload.sceneBreakdowns,
      );
      expect(
        await preview.select(preview.ocptRowFieldVersionsTable).get(),
        payload.rowFieldVersions,
      );
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

    /// Captures the project as a version, then makes the working copy diverge from it: the
    /// screenplay is rewritten, one shot is edited, and another is added.
    Future<OcptProjectVersion> createDivergedProject() async {
      await insertScene(id: "scene-1");
      await insertShot(id: "shot-1", sceneId: "scene-1");

      final version = await createVersion();

      await database
          .update(database.ocptScreenplaysTable)
          .write(const OcptScreenplaysTableCompanion(fountainText: Value(rewrittenText)));
      await (database.update(
        database.ocptShotsTable,
      )..where((table) => table.id.equals("shot-1"))).write(
        const OcptShotsTableCompanion(framing: Value("High angle")),
      );
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

    test("stamps every column it changed, above what that column already held", () async {
      final version = await createDivergedProject();

      // As if the edit that rewrote the framing had been stamped by the changeset engine.
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

      await restore(version.id);

      final stamps = await readStamps();

      // A column the restore rewrote reads, to every other replica, as the most recent edit there
      // is — which is exactly what it is.
      expect(stamps["shots/shot-1/framing"]?.version, 8);
      expect(stamps["shots/shot-1/framing"]?.deviceId, deviceId);

      // A row the version didn't hold is tombstoned, and the tombstone is stamped like any other
      // write.
      expect(stamps["shots/shot-2/isDeleted"]?.version, 1);
      expect(stamps["shots/shot-2/isDeleted"]?.deviceId, deviceId);

      // A column whose value already matched the version is left alone: a restore must not stomp
      // an unrelated concurrent edit that happened to agree with it.
      expect(stamps.containsKey("shots/shot-1/lens"), isFalse);
      expect(stamps.containsKey("shots/shot-1/sortKey"), isFalse);
    });

    test("snapshots the screenplay before writing the version's text over it", () async {
      final version = await createDivergedProject();

      await restore(version.id);

      final snapshots = await (database.select(
        database.ocptScreenplaySnapshotsTable,
      )..where((table) => table.reason.equalsValue(OcptSnapshotReason.restore))).get();

      // The three-way merge a screenplay is reconciled with looks for a common snapshot, and a
      // restore replaces the whole text in one write: without this row, the merge base would skip
      // the discontinuity entirely.
      expect(snapshots.single.fountainText, rewrittenText);
    });

    test("brings the scenes back with their own ids, leaving no shot pointing at nothing", () async {
      final version = await createDivergedProject();

      // A scene the version never held, with a shot of its own hanging off it.
      await insertScene(id: "scene-later");
      await insertShot(id: "shot-later", sceneId: "scene-later");

      await restore(version.id);

      final scenes = await database.select(database.ocptScenesTable).get();
      expect(scenes.map((scene) => scene.id), containsAll(["scene-1", "scene-later"]));
      expect(scenes.firstWhere((scene) => scene.id == "scene-1").isDeleted, isFalse);
      expect(scenes.firstWhere((scene) => scene.id == "scene-later").isDeleted, isTrue);

      // Every shot the user is left with points at a scene the version carried: the ids are the
      // payload's own, never re-derived, which is what keeps the references it holds valid.
      final liveSceneIds = {
        for (final scene in scenes.where((scene) => !scene.isDeleted)) scene.id,
      };
      final liveShots = await (database.select(
        database.ocptShotsTable,
      )..where((table) => table.isDeleted.equals(false))).get();

      expect(liveShots, isNotEmpty);
      for (final shot in liveShots) {
        expect(liveSceneIds, contains(shot.sceneId));
      }
    });

    test("keeps the state it replaces as a version, restorable in its turn", () async {
      final version = await createDivergedProject();

      await restore(version.id);

      final versions = await service.listVersions(database: database);
      final safety = versions.firstWhere((entry) => entry.name == "Before restoring");

      // The project descends from the version it was put back on, not from the safety copy taken
      // on the way there.
      expect(versions.singleWhere((entry) => entry.id == version.id).isBase, isTrue);
      expect(safety.isBase, isFalse);

      // Undoing the restore is restoring the safety version, and it brings the whole diverged
      // state back.
      expect((await restore(safety.id)).status, OcptProjectRestoreStatus.ok);
      expect(await readScreenplayText(), rewrittenText);
      expect((await readShot("shot-1"))?.framing, "High angle");
      expect((await readShot("shot-2"))?.isDeleted, isFalse);
      expect(await readCurrentVersionId(), safety.id);
    });

    test("a restore from a dirty working copy adds exactly one safety version", () async {
      final version = await createDivergedProject();

      await restore(version.id);

      final versions = await service.listVersions(database: database);
      expect(versions.map((entry) => entry.name), ["Before restoring", "v1 — First read"]);
    });

    test("a restore from a clean working copy adds no version", () async {
      await insertScene(id: "scene-1");
      final first = await createVersion(name: "v1");
      // Nothing changed since v1, so a second capture right after it is content-identical: this is
      // what lets the working copy stay "clean" against a base other than the one being restored.
      final second = await createVersion(name: "v2");

      final result = await restore(first.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      // The list is exactly what it was — no safety version — apart from the pointer, which now
      // names the version just restored instead of the one the working copy stood on beforehand.
      final versions = await service.listVersions(database: database);
      expect(versions.map((entry) => entry.id), unorderedEquals([first.id, second.id]));
      expect(await readCurrentVersionId(), first.id);
    });

    test("a restore whose base version has no stored digest adds one anyway", () async {
      await insertScene(id: "scene-1");
      final version = await createVersion();

      // A version written before schema v5 carries no digest: unknown reads as "modified" so a
      // restore doesn't wrongly assume it matches the untouched working copy.
      await (database.update(
        database.ocptProjectVersionsTable,
      )..where((table) => table.id.equals(version.id))).write(
        const OcptProjectVersionsTableCompanion(contentDigest: Value(null)),
      );

      await restore(version.id);

      final versions = await service.listVersions(database: database);
      expect(
        versions.map((entry) => entry.name),
        containsAll(["v1 — First read", "Before restoring"]),
      );
    });

    test("a restore that fails leaves the project exactly as it was", () async {
      await createDivergedProject();

      // A payload no project could ever hold: its shot belongs to a screenplay that doesn't exist,
      // so the transaction can only fail — at the commit, since the foreign keys are deferred.
      final payload = await readPayload(
        (await createVersion(name: "v2 — Sound")).id,
      );
      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-inconsistent",
              name: "v3 — Broken",
              createdAt: DateTime.utc(2026, 6, 2),
              appVersion: appVersion,
              payloadFormat: OcptProjectVersionCodec.currentPayloadFormat,
              payload: codec.encode(
                OcptProjectVersionPayload(
                  screenplays: payload.screenplays,
                  scenes: payload.scenes,
                  shots: [payload.shots.first.copyWith(screenplayId: "no-such-screenplay")],
                  shotCharacters: payload.shotCharacters,
                  shotCoverages: payload.shotCoverages,
                  people: payload.people,
                  personPositions: payload.personPositions,
                  personSkills: payload.personSkills,
                  personUnavailabilities: payload.personUnavailabilities,
                  roles: payload.roles,
                  roleEpisodes: payload.roleEpisodes,
                  locations: payload.locations,
                  locationAvailabilities: payload.locationAvailabilities,
                  sets: payload.sets,
                  sceneSets: payload.sceneSets,
                  elements: payload.elements,
                  sceneElements: payload.sceneElements,
                  roleElements: payload.roleElements,
                  roleCandidates: payload.roleCandidates,
                  assets: payload.assets,
                  breakdownTags: payload.breakdownTags,
                  sceneBreakdowns: payload.sceneBreakdowns,
                  shootingDays: payload.shootingDays,
                  shootingSlots: payload.shootingSlots,
                  shootingSlotCrew: payload.shootingSlotCrew,
                  shootingSlotCast: payload.shootingSlotCast,
                  shootingDayBlocks: payload.shootingDayBlocks,
                  shootingSlotGuests: payload.shootingSlotGuests,
                  shootingDayEvents: payload.shootingDayEvents,
                  projectDictionaryWords: payload.projectDictionaryWords,
                  budgetPostes: payload.budgetPostes,
                  budgetLines: payload.budgetLines,
                  budgetEntries: payload.budgetEntries,
                  budgetCommitments: payload.budgetCommitments,
                  budgetResources: payload.budgetResources,
                  budgetMileageRates: payload.budgetMileageRates,
                  budgetRevenues: payload.budgetRevenues,
                  budgetShares: payload.budgetShares,
                  budgetAllowances: payload.budgetAllowances,
                  rowFieldVersions: payload.rowFieldVersions,
                  pageSetup: payload.pageSetup,
                  settingsJson: payload.settingsJson,
                  currencyCode: payload.currencyCode,
                  minimumRestMinutes: payload.minimumRestMinutes,
                  screenplayLanguage: payload.screenplayLanguage,
                  shootingBlockCandidates: const [],
                  defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
                  mealPriceCents: payload.mealPriceCents,
                  snackPriceCents: payload.snackPriceCents,
                  isBudgetSimplified: payload.isBudgetSimplified,
                ),
              ),
              summaryJson: "{}",
              createdByDeviceId: deviceId,
            ),
          );

      final versionsBefore = await service.listVersions(database: database);

      final result = await restore("version-inconsistent");

      expect(result.status, OcptProjectRestoreStatus.writeFailed);
      expect(result.value, isNull);
      expect(await readScreenplayText(), rewrittenText);
      expect((await readShot("shot-1"))?.framing, "High angle");

      // The safety version is part of the same transaction, so a failed restore doesn't even leave
      // that behind.
      expect(
        (await service.listVersions(database: database)).map((entry) => entry.id),
        versionsBefore.map((entry) => entry.id),
      );
    });

    test("refuses a version the project doesn't have, and one from a later build", () async {
      await createDivergedProject();

      expect(
        (await restore("no-such-version")).status,
        OcptProjectRestoreStatus.versionNotFound,
      );

      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-from-the-future",
              name: "v9 — Written by a later build",
              createdAt: DateTime.utc(2026, 6, 2),
              appVersion: "99.0.0",
              payloadFormat: OcptProjectVersionCodec.currentPayloadFormat + 1,
              payload: '{"payloadFormat":${OcptProjectVersionCodec.currentPayloadFormat + 1}}',
              summaryJson: "{}",
              createdByDeviceId: deviceId,
            ),
          );

      expect(
        (await restore("version-from-the-future")).status,
        OcptProjectRestoreStatus.unsupportedFutureFormat,
      );
      expect(await readScreenplayText(), rewrittenText);
    });

    test("inserts, updates and tombstones resources rows, like any other table", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(id: "person-1", firstName: const Value("Clara")),
          );

      final version = await createVersion();

      // Diverge: the captured person is edited, and a second one is added since.
      await (database.update(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-1"))).write(
        const OcptPeopleTableCompanion(firstName: Value("Edited")),
      );
      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(id: "person-2", firstName: const Value("Later")),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      final restoredPerson1 = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-1"))).getSingle();
      expect(restoredPerson1.firstName, "Clara");

      // The person the version never held is tombstoned, not deleted, exactly like a shot.
      final restoredPerson2 = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-2"))).getSingle();
      expect(restoredPerson2.isDeleted, isTrue);
    });

    test("the cash journal comes back, and a movement recorded since is tombstoned", () async {
      await database
          .into(database.ocptBudgetPostesTable)
          .insert(OcptBudgetPostesTableCompanion.insert(id: "poste-1", label: "Personnel"));
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "entry-1",
              date: DateTime.utc(2026, 3, 12),
              label: "Gaffer tape",
              posteId: const Value("poste-1"),
              debitCents: const Value(1250),
              voucherNumber: const Value("J-001"),
            ),
          );
      await database
          .into(database.ocptBudgetCommitmentsTable)
          .insert(
            OcptBudgetCommitmentsTableCompanion.insert(
              id: "commitment-1",
              posteId: "poste-1",
              label: "Camera deposit",
              amountCents: const Value(45000),
            ),
          );

      final version = await createVersion();

      // Diverge: the captured entry is edited, and a second one is recorded since.
      await (database.update(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry-1"))).write(
        const OcptBudgetEntriesTableCompanion(debitCents: Value(9999)),
      );
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "entry-2",
              date: DateTime.utc(2026, 4),
              label: "Recorded later",
              voucherNumber: const Value("J-002"),
            ),
          );
      await (database.update(
        database.ocptBudgetCommitmentsTable,
      )..where((table) => table.id.equals("commitment-1"))).write(
        const OcptBudgetCommitmentsTableCompanion(amountCents: Value(1)),
      );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      // The amount comes back exactly as it was typed, to the cent.
      final restoredEntry = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry-1"))).getSingle();
      expect(restoredEntry.debitCents, 1250);
      expect(restoredEntry.voucherNumber, "J-001");

      final restoredCommitment = await (database.select(
        database.ocptBudgetCommitmentsTable,
      )..where((table) => table.id.equals("commitment-1"))).getSingle();
      expect(restoredCommitment.amountCents, 45000);

      // The movement the version never held is tombstoned, not deleted.
      final laterEntry = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry-2"))).getSingle();
      expect(laterEntry.isDeleted, isTrue);
    });

    test(
      "a financing resource, a mileage rate and a person's commute come back too",
      () async {
        await database
            .into(database.ocptBudgetMileageRatesTable)
            .insert(
              OcptBudgetMileageRatesTableCompanion.insert(
                id: "rate-1",
                label: "Voiture personnelle",
                ratePerKmMilliCents: const Value(52900),
              ),
            );
        await database
            .into(database.ocptBudgetResourcesTable)
            .insert(
              OcptBudgetResourcesTableCompanion.insert(
                id: "resource-1",
                label: "Région Île-de-France",
                amountCents: const Value(500000),
              ),
            );
        await database
            .into(database.ocptBudgetEntriesTable)
            .insert(
              OcptBudgetEntriesTableCompanion.insert(
                id: "entry-3",
                date: DateTime.utc(2026, 5, 4),
                label: "Acompte région",
                creditCents: const Value(200000),
                voucherNumber: const Value("J-003"),
                resourceId: const Value("resource-1"),
              ),
            );
        await database
            .into(database.ocptPeopleTable)
            .insert(
              OcptPeopleTableCompanion.insert(
                id: "person-3",
                firstName: const Value("Théo"),
                commuteKmMilli: const Value(1484000),
                mileageRateId: const Value("rate-1"),
              ),
            );

        final version = await createVersion();

        // Diverge: everything just captured is edited, and a fresh resource is recorded since.
        await (database.update(
          database.ocptBudgetMileageRatesTable,
        )..where((table) => table.id.equals("rate-1"))).write(
          const OcptBudgetMileageRatesTableCompanion(ratePerKmMilliCents: Value(1)),
        );
        await (database.update(
          database.ocptBudgetResourcesTable,
        )..where((table) => table.id.equals("resource-1"))).write(
          const OcptBudgetResourcesTableCompanion(amountCents: Value(1)),
        );
        await (database.update(
          database.ocptBudgetEntriesTable,
        )..where((table) => table.id.equals("entry-3"))).write(
          const OcptBudgetEntriesTableCompanion(resourceId: Value(null)),
        );
        await (database.update(
          database.ocptPeopleTable,
        )..where((table) => table.id.equals("person-3"))).write(
          const OcptPeopleTableCompanion(commuteKmMilli: Value(1), mileageRateId: Value(null)),
        );
        await database
            .into(database.ocptBudgetResourcesTable)
            .insert(
              OcptBudgetResourcesTableCompanion.insert(id: "resource-2", label: "Recorded later"),
            );

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);

        final restoredRate = await database.select(database.ocptBudgetMileageRatesTable).getSingle();
        expect(restoredRate.ratePerKmMilliCents, 52900);

        final restoredResource = await (database.select(
          database.ocptBudgetResourcesTable,
        )..where((table) => table.id.equals("resource-1"))).getSingle();
        expect(restoredResource.amountCents, 500000);

        final restoredEntry = await (database.select(
          database.ocptBudgetEntriesTable,
        )..where((table) => table.id.equals("entry-3"))).getSingle();
        expect(restoredEntry.resourceId, "resource-1");

        final restoredPerson = await (database.select(
          database.ocptPeopleTable,
        )..where((table) => table.id.equals("person-3"))).getSingle();
        expect(restoredPerson.commuteKmMilli, 1484000);
        expect(restoredPerson.mileageRateId, "rate-1");

        // The resource the version never held is tombstoned, not deleted.
        final laterResource = await (database.select(
          database.ocptBudgetResourcesTable,
        )..where((table) => table.id.equals("resource-2"))).getSingle();
        expect(laterResource.isDeleted, isTrue);
      },
    );

    test("the sharing comes back, and a taking recorded since is tombstoned", () async {
      await database
          .into(database.ocptBudgetRevenuesTable)
          .insert(
            OcptBudgetRevenuesTableCompanion.insert(
              id: "revenue-1",
              date: DateTime.utc(2026, 2, 2),
              label: "Clermont-Ferrand — audience award",
              amountCents: const Value(300000),
            ),
          );
      await database
          .into(database.ocptBudgetSharesTable)
          .insert(
            OcptBudgetSharesTableCompanion.insert(
              id: "share-1",
              label: "Director",
              sharePermille: const Value(400),
              reinvestPermille: const Value(1000),
            ),
          );
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "entry-1",
              date: DateTime.utc(2026, 2, 20),
              label: "Award paid in",
              creditCents: const Value(300000),
              voucherNumber: const Value("J-001"),
              revenueId: const Value("revenue-1"),
            ),
          );

      final version = await createVersion();

      // Diverge: the captured taking is edited, its share is renamed, and a second taking is
      // recorded since.
      await (database.update(
        database.ocptBudgetRevenuesTable,
      )..where((table) => table.id.equals("revenue-1"))).write(
        const OcptBudgetRevenuesTableCompanion(amountCents: Value(1)),
      );
      await (database.update(
        database.ocptBudgetSharesTable,
      )..where((table) => table.id.equals("share-1"))).write(
        const OcptBudgetSharesTableCompanion(sharePermille: Value(999)),
      );
      await database
          .into(database.ocptBudgetRevenuesTable)
          .insert(
            OcptBudgetRevenuesTableCompanion.insert(
              id: "revenue-2",
              date: DateTime.utc(2026, 5, 30),
              label: "Recorded later",
            ),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      // The amount comes back exactly as it was typed, to the cent.
      final restoredRevenue = await (database.select(
        database.ocptBudgetRevenuesTable,
      )..where((table) => table.id.equals("revenue-1"))).getSingle();
      expect(restoredRevenue.amountCents, 300000);

      final restoredShare = await (database.select(
        database.ocptBudgetSharesTable,
      )..where((table) => table.id.equals("share-1"))).getSingle();
      expect(restoredShare.sharePermille, 400);
      expect(restoredShare.reinvestPermille, 1000);

      // The link an entry carries onto a taking survives the round trip: without it the sharing
      // would read the takings as never having brought anything in.
      final restoredEntry = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry-1"))).getSingle();
      expect(restoredEntry.revenueId, "revenue-1");

      // The taking the version never held is tombstoned, not deleted.
      final laterRevenue = await (database.select(
        database.ocptBudgetRevenuesTable,
      )..where((table) => table.id.equals("revenue-2"))).getSingle();
      expect(laterRevenue.isDeleted, isTrue);
    });

    test("a role's things come back, and a link made since is tombstoned", () async {
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
          .into(database.ocptElementsTable)
          .insert(
            OcptElementsTableCompanion.insert(
              id: "element-1",
              name: "Manteau rouge",
              category: OcptElementCategory.costume,
              sourceKind: OcptElementSourceKind.owned,
            ),
          );
      await database
          .into(database.ocptRoleElementsTable)
          .insert(
            OcptRoleElementsTableCompanion.insert(
              id: "link-1",
              roleId: "role-1",
              elementId: "element-1",
              notes: const Value("Taché"),
            ),
          );

      final version = await createVersion();

      // Diverge: the captured link's note is edited, and a second link is made since.
      await (database.update(
        database.ocptRoleElementsTable,
      )..where((table) => table.id.equals("link-1"))).write(
        const OcptRoleElementsTableCompanion(notes: Value("Edited")),
      );
      await database
          .into(database.ocptRoleElementsTable)
          .insert(
            OcptRoleElementsTableCompanion.insert(
              id: "link-2",
              roleId: "role-1",
              elementId: "element-1",
            ),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      final restored = await (database.select(
        database.ocptRoleElementsTable,
      )..where((table) => table.id.equals("link-1"))).getSingle();
      expect(restored.notes, "Taché");
      expect(restored.isDeleted, isFalse);

      // The link the version never held is tombstoned, not deleted, like every other row.
      final later = await (database.select(
        database.ocptRoleElementsTable,
      )..where((table) => table.id.equals("link-2"))).getSingle();
      expect(later.isDeleted, isTrue);
    });

    test("a role's candidates come back, and one seen since is tombstoned", () async {
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
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(id: "person-1", firstName: const Value("Clara")),
          );
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-2", firstName: const Value("Sam")));
      await database
          .into(database.ocptRoleCandidatesTable)
          .insert(
            OcptRoleCandidatesTableCompanion.insert(
              id: "candidate-1",
              roleId: "role-1",
              personId: "person-1",
              notes: const Value("Very sure of the last scene"),
            ),
          );

      final version = await createVersion();

      // Diverge: the captured candidacy's note is edited, and somebody else is seen since.
      await (database.update(
        database.ocptRoleCandidatesTable,
      )..where((table) => table.id.equals("candidate-1"))).write(
        const OcptRoleCandidatesTableCompanion(notes: Value("Edited")),
      );
      await database
          .into(database.ocptRoleCandidatesTable)
          .insert(
            OcptRoleCandidatesTableCompanion.insert(
              id: "candidate-2",
              roleId: "role-1",
              personId: "person-2",
            ),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);

      final restored = await (database.select(
        database.ocptRoleCandidatesTable,
      )..where((table) => table.id.equals("candidate-1"))).getSingle();
      expect(restored.notes, "Very sure of the last scene");
      expect(restored.isDeleted, isFalse);

      // The candidate the version never held is tombstoned, not deleted, like every other row —
      // and the `people` row they are is untouched: a person outlives a candidacy.
      final later = await (database.select(
        database.ocptRoleCandidatesTable,
      )..where((table) => table.id.equals("candidate-2"))).getSingle();
      expect(later.isDeleted, isTrue);
      final person2 = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-2"))).getSingle();
      expect(person2.isDeleted, isFalse);
    });

    test(
      "a role's episode links come back, and one made since is tombstoned like any other row",
      () async {
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
            .into(database.ocptRoleEpisodesTable)
            .insert(
              OcptRoleEpisodesTableCompanion.insert(
                id: "link-1",
                roleId: "role-1",
                screenplayId: screenplayId,
              ),
            );

        final version = await createVersion();

        // Diverge: a second episode link is made since — as if the character had started
        // speaking in a second episode of the same production.
        await database
            .into(database.ocptScreenplaysTable)
            .insert(
              OcptScreenplaysTableCompanion.insert(
                id: "screenplay-2",
                title: "Episode 2",
                fountainText: const Value(""),
                updatedAt: DateTime.utc(2026, 1, 6),
              ),
            );
        await database
            .into(database.ocptRoleEpisodesTable)
            .insert(
              OcptRoleEpisodesTableCompanion.insert(
                id: "link-2",
                roleId: "role-1",
                screenplayId: "screenplay-2",
              ),
            );

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);

        final restored = await (database.select(
          database.ocptRoleEpisodesTable,
        )..where((table) => table.id.equals("link-1"))).getSingle();
        expect(restored.roleId, "role-1");
        expect(restored.screenplayId, screenplayId);
        expect(restored.isDeleted, isFalse);

        // The link the version never held is tombstoned, not deleted, exactly like every other
        // row a payload doesn't carry.
        final later = await (database.select(
          database.ocptRoleEpisodesTable,
        )..where((table) => table.id.equals("link-2"))).getSingle();
        expect(later.isDeleted, isTrue);
      },
    );

    test(
      "tombstones a word learned since the capture, and revives one removed since",
      () async {
        await database
            .into(database.ocptProjectDictionaryWordsTable)
            .insert(
              OcptProjectDictionaryWordsTableCompanion.insert(id: "word-1", word: "Clara"),
            );

        final version = await createVersion();

        // Diverge: the word is un-learned since — as if the writer had removed it after the
        // capture — and a fresh one is learned.
        await (database.update(
          database.ocptProjectDictionaryWordsTable,
        )..where((table) => table.id.equals("word-1"))).write(
          const OcptProjectDictionaryWordsTableCompanion(isDeleted: Value(true)),
        );
        await database
            .into(database.ocptProjectDictionaryWordsTable)
            .insert(
              OcptProjectDictionaryWordsTableCompanion.insert(id: "word-2", word: "Julien"),
            );

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);

        // "word-1" was live in the captured version: restoring revives it.
        final revived = await (database.select(
          database.ocptProjectDictionaryWordsTable,
        )..where((table) => table.id.equals("word-1"))).getSingle();
        expect(revived.word, "Clara");
        expect(revived.isDeleted, isFalse);

        // "word-2" was learned after the capture: the version never held it, so it is
        // tombstoned, not deleted, exactly like every other row a payload doesn't carry.
        final tombstoned = await (database.select(
          database.ocptProjectDictionaryWordsTable,
        )..where((table) => table.id.equals("word-2"))).getSingle();
        expect(tombstoned.isDeleted, isTrue);
      },
    );

    test("stamps a resources column it changed, above what it already held", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(id: "person-1", firstName: const Value("Clara")),
          );
      final version = await createVersion();

      await (database.update(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-1"))).write(
        const OcptPeopleTableCompanion(firstName: Value("Edited")),
      );

      // As if the edit had already been stamped by the changeset engine.
      await database
          .into(database.ocptRowFieldVersionsTable)
          .insert(
            OcptRowFieldVersionsTableCompanion.insert(
              targetTableName: "people",
              rowId: "person-1",
              columnName: "firstName",
              version: 4,
              deviceId: "device-0",
            ),
          );

      await restore(version.id);

      final stamps = await readStamps();
      expect(stamps["people/person-1/firstName"]?.version, 5);
      expect(stamps["people/person-1/firstName"]?.deviceId, deviceId);
    });

    test(
      "restores a schedule captured after M1 exactly, tombstones and sort keys included",
      () async {
        await insertShootingDay(id: "day-1", date: DateTime.utc(2026, 3, 10));
        await insertShootingSlot(id: "slot-1", shootingDayId: "day-1");
        await database
            .into(database.ocptPeopleTable)
            .insert(OcptPeopleTableCompanion.insert(id: "person-1", firstName: const Value("Clara")));
        await database
            .into(database.ocptShootingSlotCrewTable)
            .insert(
              OcptShootingSlotCrewTableCompanion.insert(
                id: "crew-1",
                slotId: "slot-1",
                personId: "person-1",
              ),
            );

        final version = await createVersion(name: "v1 — Day planned");

        // Diverge: the slot's anchored hour is edited, its position renamed by the shooting day it
        // belongs to, a second day is added, and the crew row is tombstoned.
        await (database.update(
          database.ocptShootingSlotsTable,
        )..where((table) => table.id.equals("slot-1"))).write(
          const OcptShootingSlotsTableCompanion(anchorMinute: Value(360)),
        );
        await insertShootingDay(id: "day-2", date: DateTime.utc(2026, 3, 11), sortKey: "k");
        await scheduleService.removeSlotCrewMember(database: database, crewMemberId: "crew-1");

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);

        final restoredSlot = await (database.select(
          database.ocptShootingSlotsTable,
        )..where((table) => table.id.equals("slot-1"))).getSingle();
        expect(restoredSlot.anchorMinute, 420);
        expect(restoredSlot.sortKey, "V");

        final restoredDay = await (database.select(
          database.ocptShootingDaysTable,
        )..where((table) => table.id.equals("day-1"))).getSingle();
        expect(restoredDay.isDeleted, isFalse);
        expect(restoredDay.sortKey, "V");

        // The day the version never held is tombstoned, not deleted, exactly like a shot.
        final droppedDay = await (database.select(
          database.ocptShootingDaysTable,
        )..where((table) => table.id.equals("day-2"))).getSingle();
        expect(droppedDay.isDeleted, isTrue);

        // The crew row is restored live again.
        final restoredCrew = await (database.select(
          database.ocptShootingSlotCrewTable,
        )..where((table) => table.id.equals("crew-1"))).getSingle();
        expect(restoredCrew.isDeleted, isFalse);
        expect(restoredCrew.personId, "person-1");
      },
    );

    test(
      "a guest and an event survive a capture and a restore, tombstones included",
      () async {
        await insertShootingDay(id: "day-1", date: DateTime.utc(2026, 3, 10));
        await insertShootingSlot(id: "slot-1", shootingDayId: "day-1");
        final guestId = await scheduleService.addSlotGuest(
          database: database,
          slotId: "slot-1",
          freeName: "Le maire",
          reason: "Prête la place",
        );
        final eventId = await scheduleService.createDayEvent(
          database: database,
          dayId: "day-1",
          minute: 1020,
          label: "Feu d'artifice du village",
        );

        final version = await createVersion(name: "v1 — Guest and event planned");

        // Diverge: the guest and the event are both removed in the working copy, and a second
        // guest is added on a new slot.
        await scheduleService.deleteSlotGuest(database: database, guestId: guestId!);
        await scheduleService.deleteDayEvent(database: database, eventId: eventId!);
        final secondSlotId = await scheduleService.createSlot(
          database: database,
          shootingDayId: "day-1",
          anchorMinute: 600,
        );
        await scheduleService.addSlotGuest(
          database: database,
          slotId: secondSlotId!,
          freeName: "Une journaliste",
        );

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);

        // The guest and the event the version held are revived — live again.
        final restoredGuest = await (database.select(
          database.ocptShootingSlotGuestsTable,
        )..where((table) => table.id.equals(guestId))).getSingle();
        expect(restoredGuest.isDeleted, isFalse);
        expect(restoredGuest.freeName, "Le maire");
        expect(restoredGuest.reason, "Prête la place");

        final restoredEvent = await (database.select(
          database.ocptShootingDayEventsTable,
        )..where((table) => table.id.equals(eventId))).getSingle();
        expect(restoredEvent.isDeleted, isFalse);
        expect(restoredEvent.minute, 1020);
        expect(restoredEvent.label, "Feu d'artifice du village");

        // The guest the version never held is tombstoned, not deleted, exactly like a shot.
        final droppedGuests = await database.select(database.ocptShootingSlotGuestsTable).get();
        expect(
          droppedGuests.where((row) => row.freeName == "Une journaliste").single.isDeleted,
          isTrue,
        );

        // And the schedule mode reads the guest and the event back exactly the way they were
        // written.
        final restoredSnapshot = await scheduleService.loadSchedule(database: database);
        expect(
          restoredSnapshot.slotsByDayId["day-1"]!.first.guests.single.freeName,
          "Le maire",
        );
        expect(restoredSnapshot.eventsByDayId["day-1"]!.single.label, "Feu d'artifice du village");
      },
    );


    test("stamps a schedule column it changed, above what it already held", () async {
      await insertShootingDay(id: "day-1");
      await insertShootingSlot(id: "slot-1", shootingDayId: "day-1");
      final version = await createVersion();

      await (database.update(
        database.ocptShootingSlotsTable,
      )..where((table) => table.id.equals("slot-1"))).write(
        const OcptShootingSlotsTableCompanion(anchorMinute: Value(360)),
      );

      // As if the edit had already been stamped by the changeset engine.
      await database
          .into(database.ocptRowFieldVersionsTable)
          .insert(
            OcptRowFieldVersionsTableCompanion.insert(
              targetTableName: "shooting_slots",
              rowId: "slot-1",
              columnName: "anchorMinute",
              version: 4,
              deviceId: "device-0",
            ),
          );

      await restore(version.id);

      final stamps = await readStamps();
      expect(stamps["shooting_slots/slot-1/anchorMinute"]?.version, 5);
      expect(stamps["shooting_slots/slot-1/anchorMinute"]?.deviceId, deviceId);
    });

    test("restores the currency the version was captured with", () async {
      final version = await createVersion();

      await database
          .update(database.ocptProjectInfoTable)
          .write(const OcptProjectInfoTableCompanion(currencyCode: Value("USD")));

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(info.currencyCode, "EUR");
    });

    test("restoring a payload with no currency leaves the project's own currency untouched", () async {
      // A live capture always states a real `currencyCode` ("restores the currency the version
      // was captured with" above): a null one is reachable only by hand-editing the stored payload,
      // which is exactly what this does — everything else about the capture stays genuine.
      final version = await createVersion();
      final storedRow = await (database.select(
        database.ocptProjectVersionsTable,
      )..where((table) => table.id.equals(version.id))).getSingle();
      final withNoCurrency = jsonDecode(storedRow.payload) as Map<String, dynamic>;
      (withNoCurrency["projectSettings"] as Map<String, dynamic>)["currencyCode"] = null;
      await (database.update(
        database.ocptProjectVersionsTable,
      )..where((table) => table.id.equals(version.id))).write(
        OcptProjectVersionsTableCompanion(payload: Value(jsonEncode(withNoCurrency))),
      );

      await database
          .update(database.ocptProjectInfoTable)
          .write(const OcptProjectInfoTableCompanion(currencyCode: Value("GBP")));

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(info.currencyCode, "GBP");
    });

    test("restores the minimum rest the version was captured with", () async {
      await database
          .update(database.ocptProjectInfoTable)
          .write(const OcptProjectInfoTableCompanion(minimumRestMinutes: Value(660)));
      final version = await createVersion();

      await database
          .update(database.ocptProjectInfoTable)
          .write(const OcptProjectInfoTableCompanion(minimumRestMinutes: Value(720)));

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(info.minimumRestMinutes, 660);
    });

    test(
      "restoring a payload with no minimum rest clears one recorded since — unlike the currency",
      () async {
        // Unlike currencyCode, which is never null on a live capture, minimumRestMinutes is null
        // right here because nobody has recorded one yet — a truthful value of its own, not a
        // format predating the column.
        final version = await createVersion();

        await database
            .update(database.ocptProjectInfoTable)
            .write(const OcptProjectInfoTableCompanion(minimumRestMinutes: Value(600)));

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);
        final info = await database.select(database.ocptProjectInfoTable).getSingle();
        expect(info.minimumRestMinutes, isNull);
      },
    );

    test("restores the screenplay language the version was captured with", () async {
      await database
          .update(database.ocptProjectInfoTable)
          .write(
            const OcptProjectInfoTableCompanion(
              screenplayLanguage: Value(OcptScreenplayLanguage.fr),
            ),
          );
      final version = await createVersion();

      await database
          .update(database.ocptProjectInfoTable)
          .write(
            const OcptProjectInfoTableCompanion(
              screenplayLanguage: Value(OcptScreenplayLanguage.enGb),
            ),
          );

      final result = await restore(version.id);

      expect(result.status, OcptProjectRestoreStatus.ok);
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(info.screenplayLanguage, OcptScreenplayLanguage.fr);
    });

    test(
      "restoring a payload with no screenplay language clears one recorded since — unlike the "
      "currency",
      () async {
        // Unlike currencyCode, which is never null on a live capture, screenplayLanguage is null
        // right here because nobody has recorded one yet — a truthful value of its own, exactly
        // the reading minimumRestMinutes' own null carries.
        final version = await createVersion();

        await database
            .update(database.ocptProjectInfoTable)
            .write(
              const OcptProjectInfoTableCompanion(
                screenplayLanguage: Value(OcptScreenplayLanguage.enGb),
              ),
            );

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);
        final info = await database.select(database.ocptProjectInfoTable).getSingle();
        expect(info.screenplayLanguage, isNull);
      },
    );

    test(
      "restoring a version captured before an erasure does not resurrect the erased person",
      () async {
        await database
            .into(database.ocptPeopleTable)
            .insert(
              OcptPeopleTableCompanion.insert(
                id: "person-1",
                firstName: const Value("Clara"),
                lastName: const Value("Martin"),
                email: const Value("clara@example.com"),
                phone: const Value("0102030405"),
                maxDailyPresenceMinutes: const Value(480),
              ),
            );
        await database
            .into(database.ocptPersonSkillsTable)
            .insert(
              OcptPersonSkillsTableCompanion.insert(
                id: "skill-1",
                personId: "person-1",
                label: const Value("Permis B"),
              ),
            );
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
            .into(database.ocptRoleCandidatesTable)
            .insert(
              OcptRoleCandidatesTableCompanion.insert(
                id: "candidate-1",
                roleId: "role-1",
                personId: "person-1",
                notes: const Value("Fragile, exactly right for the part"),
              ),
            );

        final version = await createVersion();

        // The erasure itself is other work (OcptPeopleService.deletePerson); this only checks that
        // a restore of a version captured before it can't undo it.
        await peopleService.deletePerson(database: database, personId: "person-1");

        final result = await restore(version.id);

        expect(result.status, OcptProjectRestoreStatus.ok);

        final person = await (database.select(
          database.ocptPeopleTable,
        )..where((table) => table.id.equals("person-1"))).getSingle();
        expect(person.isDeleted, isTrue);
        expect(person.firstName, isEmpty);
        expect(person.lastName, isEmpty);
        expect(person.email, isEmpty);
        expect(person.phone, isEmpty);
        expect(person.maxDailyPresenceMinutes, isNull);

        final skill = await (database.select(
          database.ocptPersonSkillsTable,
        )..where((table) => table.id.equals("skill-1"))).getSingle();
        expect(skill.isDeleted, isTrue);
        expect(skill.label, isEmpty);

        // A candidacy is the one link table holding something about a person: what was written
        // about them at an audition is scrubbed out of the payload on its way back too.
        final candidate = await (database.select(
          database.ocptRoleCandidatesTable,
        )..where((table) => table.id.equals("candidate-1"))).getSingle();
        expect(candidate.isDeleted, isTrue);
        expect(candidate.notes, isEmpty);

        // The erasure itself is never rewound: it is recorded outside any payload, on purpose.
        final erasures = await database.select(database.ocptLocalErasuresTable).get();
        expect(erasures.map((row) => row.personId), contains("person-1"));
      },
    );

    test("restoring a version does not put back an erased person's referenced files", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(
              id: "person-1",
              firstName: const Value("Clara"),
              lastName: const Value("Martin"),
            ),
          );
      final photoId = (await peopleService.setPersonPhoto(
        database: database,
        personId: "person-1",
        path: "/photos/clara-martin.jpg",
      ))!;

      final version = await createVersion();

      await peopleService.deletePerson(database: database, personId: "person-1");

      final result = await restore(version.id);
      expect(result.status, OcptProjectRestoreStatus.ok);

      // An asset's path is personal data in its own right — it names the person and says where a
      // photograph of them sits — so the payload's copy is scrubbed exactly as the person's own
      // row is, or a restore would write the leak straight back.
      final asset = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals(photoId))).getSingle();
      expect(asset.isDeleted, isTrue);
      expect(asset.path, isEmpty);
    });

    test("restoring keeps a location's own referenced files, which are nobody's data", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-1"));
      await database
          .into(database.ocptLocationsTable)
          .insert(
            OcptLocationsTableCompanion.insert(id: "location-1", name: "Le hangar"),
          );
      final photoId = (await locationsService.addLocationPhoto(
        database: database,
        locationId: "location-1",
        path: "/photos/repérage.jpg",
      ))!;

      final version = await createVersion();
      await peopleService.deletePerson(database: database, personId: "person-1");

      final result = await restore(version.id);
      expect(result.status, OcptProjectRestoreStatus.ok);

      final asset = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals(photoId))).getSingle();
      expect(asset.isDeleted, isFalse);
      expect(asset.path, "/photos/repérage.jpg");
    });

    test("previewing a version captured before an erasure shows nothing of the person", () async {
      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(
              id: "person-1",
              firstName: const Value("Clara"),
              lastName: const Value("Martin"),
              email: const Value("clara@example.com"),
              phone: const Value("0102030405"),
              allergies: const Value("Arachides"),
            ),
          );
      await database
          .into(database.ocptPersonSkillsTable)
          .insert(
            OcptPersonSkillsTableCompanion.insert(
              id: "skill-1",
              personId: "person-1",
              label: const Value("Permis B"),
            ),
          );

      final version = await createVersion();
      await peopleService.deletePerson(database: database, personId: "person-1");

      // A preview reads the very same payload a restore does, and hydrates it into the database
      // every mode draws its sheets from: scrubbing only the restore would put an erased person's
      // contact details and allergies back on screen, one click away, for as long as the version
      // lives.
      final payload = (await service.loadPayload(database: database, id: version.id)).value!;

      final previewDatabase = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(previewDatabase.close);
      await service.hydratePreview(
        database: previewDatabase,
        projectInfo: await database.select(database.ocptProjectInfoTable).getSingle(),
        payload: payload,
      );

      final person = await (previewDatabase.select(
        previewDatabase.ocptPeopleTable,
      )..where((table) => table.id.equals("person-1"))).getSingle();
      expect(person.isDeleted, isTrue);
      expect(person.firstName, isEmpty);
      expect(person.lastName, isEmpty);
      expect(person.email, isEmpty);
      expect(person.phone, isEmpty);
      expect(person.allergies, isEmpty);

      final skill = await (previewDatabase.select(
        previewDatabase.ocptPersonSkillsTable,
      )..where((table) => table.id.equals("skill-1"))).getSingle();
      expect(skill.isDeleted, isTrue);
      expect(skill.label, isEmpty);
    });

    test(
      "restores a breakdown captured before it, then one captured after, tags tombstoned rather "
      "than deleted and every reference still resolving",
      () async {
        // A real screenplay, reconciled into two real scenes — the breakdown restore's own
        // subtlety (§ the payload's doc comment) is about references staying valid, which only
        // means something against ids the reconciliation itself minted.
        final scenes = await saveScreenplayScenes(
          "INT. HOUSE - DAY\n\nA desk lamp glows. LÉA enters quietly.\n\n"
          "EXT. STREET - NIGHT\n\nRain falls on the porch.\n",
        );
        final scene1 = scenes[0];
        final scene2 = scenes[1];

        final elementId = (await elementsService.createElement(
          database: database,
          name: "Desk lamp",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        ))!;
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
        await (database.update(
          database.ocptElementsTable,
        )..where((table) => table.id.equals(elementId))).write(
          const OcptElementsTableCompanion(status: Value(OcptElementStatus.confirmed)),
        );

        final versionB = await createVersion(name: "v2 — Locked");

        // Restore A: the breakdown must read exactly as it did at that moment.
        final resultA = await restore(versionA.id);
        expect(resultA.status, OcptProjectRestoreStatus.ok);

        expect(
          (await readTag(roleTagId))?.isDeleted,
          isFalse,
          reason: "a tag deleted after A must be live again",
        );
        final tagAddedAfterA = await readTag(addedTagId);
        expect(
          tagAddedAfterA,
          isNotNull,
          reason: "the row must still be there, as a tombstone",
        );
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
          for (final row
              in await (database.select(
                database.ocptScenesTable,
              )..where((table) => table.isDeleted.equals(false))).get())
            row.id,
        };
        final liveElementIds = {
          for (final row
              in await (database.select(
                database.ocptElementsTable,
              )..where((table) => table.isDeleted.equals(false))).get())
            row.id,
        };
        final liveRoleIds = {
          for (final row
              in await (database.select(
                database.ocptRolesTable,
              )..where((table) => table.isDeleted.equals(false))).get())
            row.id,
        };
        final liveSetIds = {
          for (final row
              in await (database.select(
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
      },
    );
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
