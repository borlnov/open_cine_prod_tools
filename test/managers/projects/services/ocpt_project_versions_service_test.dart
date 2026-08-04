// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

void main() {
  // Reading a version's stored summary logs through appLogger(), which requires a global manager
  // instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec();
  const peopleService = OcptPeopleService();
  const service = OcptProjectVersionsService(
    codec: codec,
    screenplayService: OcptScreenplayService(
      sceneIndexService: OcptSceneIndexService(),
      shotListService: OcptShotListService(),
      shotCoverageService: OcptShotCoverageService(),
      roleIndexService: OcptRoleIndexService(),
    ),
  );
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
                  locations: payload.locations,
                  locationAvailabilities: payload.locationAvailabilities,
                  sets: payload.sets,
                  sceneSets: payload.sceneSets,
                  elements: payload.elements,
                  sceneElements: payload.sceneElements,
                  assets: payload.assets,
                  rowFieldVersions: payload.rowFieldVersions,
                  pageSetup: payload.pageSetup,
                  settingsJson: payload.settingsJson,
                  currencyCode: payload.currencyCode,
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

    test("restoring a format-1 payload tombstones the resources the working copy has", () async {
      // A literal fixture of a version captured before the resources mode existed: none of the
      // eleven resources keys are present at all, matching exactly what a real payload written in
      // that format looked like on disk.
      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-format1",
              name: "v0 — Before resources",
              createdAt: DateTime.utc(2026),
              appVersion: "0.1.0",
              payloadFormat: 1,
              payload:
                  '{"payloadFormat":1,"screenplays":[{"id":"$screenplayId","title":"Draft",'
                  '"fountainText":"${capturedText.replaceAll('\n', r'\n')}",'
                  '"updatedAt":"2026-01-05T00:00:00.000Z",'
                  '"isDeleted":false}],"scenes":[],"shots":[],"shotCharacters":[],'
                  '"shotCoverages":[],"rowFieldVersions":[],'
                  '"projectSettings":{"pageFormat":"a4","settingsJson":null},'
                  '"pageMargins":{"leftInches":1.5,"rightInches":1,"topInches":0.75,'
                  '"bottomInches":1.25}}',
              summaryJson: "{}",
              createdByDeviceId: deviceId,
            ),
          );

      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(id: "person-1", firstName: const Value("Clara")),
          );

      final result = await restore("version-format1");

      expect(result.status, OcptProjectRestoreStatus.ok);

      // The format-1 payload says "this project had no resources" — a truthful statement about
      // that moment — so the restore tombstones what the working copy has, rather than leaving it.
      final person = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person-1"))).getSingle();
      expect(person.isDeleted, isTrue);
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
      // A literal fixture of a version captured before currencies existed (payload format 3):
      // `projectSettings` carries no `currencyCode` key at all.
      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-format3",
              name: "v0 — Before currencies",
              createdAt: DateTime.utc(2026),
              appVersion: "0.1.0",
              payloadFormat: 3,
              payload:
                  '{"payloadFormat":3,"screenplays":[],"scenes":[],"shots":[],'
                  '"shotCharacters":[],"shotCoverages":[],"people":[],"personPositions":[],'
                  '"personSkills":[],"personUnavailabilities":[],"roles":[],"locations":[],'
                  '"locationAvailabilities":[],"sets":[],"sceneSets":[],"elements":[],'
                  '"sceneElements":[],"assets":[],"rowFieldVersions":[],'
                  '"projectSettings":{"pageFormat":"a4","settingsJson":null},'
                  '"pageMargins":{"leftInches":1.5,"rightInches":1,"topInches":0.75,'
                  '"bottomInches":1.25}}',
              summaryJson: "{}",
              createdByDeviceId: deviceId,
            ),
          );

      await database
          .update(database.ocptProjectInfoTable)
          .write(const OcptProjectInfoTableCompanion(currencyCode: Value("GBP")));

      final result = await restore("version-format3");

      expect(result.status, OcptProjectRestoreStatus.ok);
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(info.currencyCode, "GBP");
    });

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

        final skill = await (database.select(
          database.ocptPersonSkillsTable,
        )..where((table) => table.id.equals("skill-1"))).getSingle();
        expect(skill.isDeleted, isTrue);
        expect(skill.label, isEmpty);

        // The erasure itself is never rewound: it is recorded outside any payload, on purpose.
        final erasures = await database.select(database.ocptLocalErasuresTable).get();
        expect(erasures.map((row) => row.personId), contains("person-1"));
      },
    );

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
