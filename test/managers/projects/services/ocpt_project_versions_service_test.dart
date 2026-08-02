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
