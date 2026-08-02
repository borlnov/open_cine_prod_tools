// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

void main() {
  // Reading a version's stored summary logs through appLogger(), which requires a global manager
  // instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec();
  const service = OcptProjectVersionsService(codec: codec);
  const screenplayId = "screenplay-1";
  const deviceId = "device-1";
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
      expect(version.isCurrent, isTrue);
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
      expect(versions.map((version) => version.isCurrent), [false, true, false]);
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
      expect(version?.isCurrent, isTrue);
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
      expect(versions.single.isCurrent, isTrue);
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
