// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
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
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_screenplay_merge_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// M3's acceptance test for `docs/plans/collaboration-and-sync.md` §3.4: a project-version
/// **restore** on one replica converges, through the changeset engine, against a replica that was
/// offline throughout — with the rows the restore tombstoned staying gone on the other side, and
/// the whole catch-up landing in one [OcptChangesetService.pullAndApply] call.
///
/// [OcptProjectVersionsService.restoreVersion] already tombstones-and-stamps through the very same
/// `OcptRowStampService` any ordinary edit uses (see its own `restoreIsAnEdit` doc), so this file
/// only has to prove that a restore's stamps actually reach `OcptChangesetService.pushLocalEdits`
/// the way any other local edit's would — it does, because `OcptProjectsManager.restoreProjectVersion`
/// already calls it against `OcptOpenProjectModel.fileDatabase`, the very handle the outbound side
/// reads from, exactly like every other write in the app.
///
/// The preview-safety property M3's own test list also names — an incoming changeset applying to
/// `fileDatabase` normally while a version preview is up — is already covered by
/// `ocpt_merge_service_test.dart`'s "an incoming changeset applies to fileDatabase normally even
/// while a version preview is up" test and is not duplicated here.
void main() {
  // Restoring a version, and a screenplay merge with no common base, both log through
  // appLogger(), which requires a global manager instance to be set; merely accessing it creates
  // the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const screenplayId = 'screenplay-1';
  const relayId = 'relay-1';
  const appVersion = '0.1.0';
  const margins = FountainPageMargins(
    leftInches: 1.5,
    rightInches: 1,
    topInches: 0.75,
    bottomInches: 1.25,
  );

  const originalText = 'INT. HOUSE - DAY\n\nAction one.\n\nEXT. STREET - NIGHT\n\nAction two.';
  const textAtV1 =
      'INT. HOUSE - DAY\n\nAction one, rewritten.\n\nEXT. STREET - NIGHT\n\nAction two.';
  const textAfterV1 =
      'INT. HOUSE - DAY\n\nAction one, rewritten again.\n\nEXT. STREET - NIGHT\n\nAction two.';

  /// A "device" bundle: a full `OcptScreenplayService` and `OcptLocationsService` (mirroring
  /// `ocpt_screenplay_merge_convergence_test.dart`'s own wiring), an `OcptProjectVersionsService`
  /// sharing the very same screenplay service — exactly as `OcptProjectsManager` wires the two —
  /// and the `OcptChangesetService` routing `fountainText` through a real
  /// `OcptScreenplayMergeService`. Everything stamps every write as [deviceId]'s own: what one real
  /// app instance, bound to one device id, would build for itself.
  ({
    OcptScreenplayService screenplayService,
    OcptLocationsService locationsService,
    OcptProjectVersionsService projectVersionsService,
    OcptChangesetService changesetService,
  })
  buildDevice(String deviceId) {
    Future<String> thisDeviceId() async => deviceId;

    final assetsService = OcptAssetsService(deviceId: thisDeviceId);
    final roleCandidatesService = OcptRoleCandidatesService(deviceId: thisDeviceId);
    final elementsService = OcptElementsService(assetsService: assetsService, deviceId: thisDeviceId);
    final locationsService = OcptLocationsService(assetsService: assetsService, deviceId: thisDeviceId);
    final roleIndexService = OcptRoleIndexService(
      elementsService: elementsService,
      roleCandidatesService: roleCandidatesService,
      deviceId: thisDeviceId,
    );
    final breakdownService = OcptBreakdownService(
      elementsService: elementsService,
      locationsService: locationsService,
      deviceId: thisDeviceId,
    );
    final screenplayService = OcptScreenplayService(
      sceneIndexService: const OcptSceneIndexService(),
      shotListService: OcptShotListService(deviceId: thisDeviceId),
      shotCoverageService: OcptShotCoverageService(deviceId: thisDeviceId),
      roleIndexService: roleIndexService,
      breakdownService: breakdownService,
      scheduleService: OcptScheduleService(deviceId: thisDeviceId),
      deviceId: thisDeviceId,
    );

    final changesetService = OcptChangesetService(
      mergeService: OcptMergeService(
        screenplayMergeService: OcptScreenplayMergeService(
          screenplayService: screenplayService,
          deviceId: thisDeviceId,
        ),
      ),
    );

    return (
      screenplayService: screenplayService,
      locationsService: locationsService,
      projectVersionsService: OcptProjectVersionsService(
        codec: const OcptProjectVersionCodec(),
        screenplayService: screenplayService,
      ),
      changesetService: changesetService,
    );
  }

  late Directory tempDir;
  late OcptFolderRemoteStorage storage;
  late OcptProjectDatabase replicaA;
  late OcptProjectDatabase replicaB;

  /// Seeds [database] with the project header every `OcptProjectVersionsService` call needs —
  /// `project_info` is local to a replica (never synchronised), so both replicas need their own.
  Future<void> insertProjectInfo(OcptProjectDatabase database) => database
      .into(database.ocptProjectInfoTable)
      .insert(
        OcptProjectInfoTableCompanion.insert(
          name: "My Movie",
          createdAt: DateTime.utc(2026, 1, 4),
          appVersionAtCreation: appVersion,
          pageFormat: OcptPageFormat.a4,
          settingsJson: const Value('{}'),
        ),
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_restore_convergence_test_');
    storage = OcptFolderRemoteStorage(tempDir);

    replicaA = OcptProjectDatabase.memory();
    replicaB = OcptProjectDatabase.memory();

    await insertProjectInfo(replicaA);
    await insertProjectInfo(replicaB);

    // The screenplay's very first row is created identically on both replicas rather than through
    // the engine, exactly as `ocpt_screenplay_merge_convergence_test.dart` does: `screenplays
    // .fountainText` is always routed through the merge service, even for a brand-new row, and a
    // merge needs a common-ancestor snapshot to diff against — a concern this test isn't about.
    for (final replica in [replicaA, replicaB]) {
      await replica
          .into(replica.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: screenplayId,
              title: 'Title',
              fountainText: const Value(originalText),
              updatedAt: DateTime.utc(2026),
            ),
          );
    }
  });

  tearDown(() async {
    await replicaA.close();
    await replicaB.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Every live (non-tombstoned) location's name in [database], in `sortKey` order.
  Future<List<String>> liveLocationNames(OcptProjectDatabase database) async {
    final rows = await (database.select(database.ocptLocationsTable)
          ..where((table) => table.isDeleted.equals(false))
          ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
        .get();
    return rows.map((row) => row.name).toList();
  }

  /// The location [id] as [database] currently holds it, tombstone included.
  Future<OcptLocationRow> locationRow(OcptProjectDatabase database, String id) =>
      (database.select(database.ocptLocationsTable)..where((table) => table.id.equals(id))).getSingle();

  /// Every live scene's heading of [screenplayId] in [database], in source order — `scenes` is
  /// derived and recomputed independently on each replica (never synchronised, ADR 0010), so this
  /// compares structure rather than row identity, exactly as
  /// `ocpt_screenplay_merge_convergence_test.dart`'s own `sceneHeadingsOf` does.
  Future<List<String>> sceneHeadingsOf(OcptProjectDatabase database) async {
    final scenes = await (database.select(database.ocptScenesTable)
          ..where((table) => table.isDeleted.equals(false))
          ..orderBy([(table) => OrderingTerm.asc(table.position)]))
        .get();
    return scenes.map((scene) => scene.heading).toList();
  }

  test(
    'a restore on one replica converges against a replica that was offline throughout, tombstones included',
    () async {
      final deviceA = buildDevice('device-a');
      final deviceB = buildDevice('device-b');

      // B "opens" the project once while still online, which is what stamps B's own base snapshot
      // of the shared starting text (`OcptScreenplayService.snapshotOnProjectOpen`, exactly what
      // the real app calls on every project open) — the common ancestor its own later merge, made
      // with no edit of its own, needs to diff against.
      await deviceB.screenplayService.snapshotOnProjectOpen(database: replicaB, screenplayId: screenplayId);

      // Seed one ordinary row on A only, then let it reach B through the real folder transport —
      // proving the two replicas start identical through the engine, not by construction.
      final office = (await deviceA.locationsService.createLocation(database: replicaA, name: 'Office'))!;

      await deviceA.changesetService.pushLocalEdits(
        database: replicaA,
        storage: storage,
        relayId: relayId,
        deviceId: 'device-a',
      );
      await deviceB.changesetService.pullAndApply(database: replicaB, storage: storage, relayId: relayId);

      expect(await liveLocationNames(replicaA), ['Office']);
      expect(await liveLocationNames(replicaB), ['Office']);

      // ---- B goes offline from here: no more sync call involving replicaB until the very end.

      // On A: edit the screenplay, add a location, and capture that as version V1 — "the earlier
      // version" this test restores back to.
      await deviceA.screenplayService.saveScreenplayText(
        database: replicaA,
        screenplayId: screenplayId,
        fountainText: textAtV1,
        snapshotReason: OcptSnapshotReason.manual,
      );
      final studio = (await deviceA.locationsService.createLocation(database: replicaA, name: 'Studio'))!;

      final v1 = await deviceA.projectVersionsService.createVersion(
        database: replicaA,
        name: 'v1',
        note: '',
        appVersion: appVersion,
        deviceId: 'device-a',
        pageMargins: margins,
      );

      // Diverge from V1 in every way a restore has to undo: change the screenplay text again,
      // rename a row V1 held, delete a row V1 held, and add a row V1 never held.
      await deviceA.screenplayService.saveScreenplayText(
        database: replicaA,
        screenplayId: screenplayId,
        fountainText: textAfterV1,
        snapshotReason: OcptSnapshotReason.manual,
      );
      await deviceA.locationsService.updateLocation(
        database: replicaA,
        locationId: office,
        name: const Value('Office HQ'),
      );
      await deviceA.locationsService.deleteLocation(database: replicaA, locationId: studio);
      final backlot = (await deviceA.locationsService.createLocation(database: replicaA, name: 'Backlot'))!;

      final restoreResult = await deviceA.projectVersionsService.restoreVersion(
        database: replicaA,
        id: v1.id,
        safetyVersionName: 'Before restoring',
        appVersion: appVersion,
        deviceId: 'device-a',
        pageMargins: margins,
      );
      expect(restoreResult.status, OcptProjectRestoreStatus.ok);

      // Sanity, on A itself, before anything is even pushed: the restore reverted the rename,
      // resurrected the deletion, tombstoned the addition, and put the screenplay text back.
      expect(
        await deviceA.screenplayService.loadScreenplayText(database: replicaA, screenplayId: screenplayId),
        textAtV1,
      );
      expect((await locationRow(replicaA, office)).name, 'Office');
      expect((await locationRow(replicaA, office)).isDeleted, isFalse);
      expect((await locationRow(replicaA, studio)).isDeleted, isFalse);
      expect((await locationRow(replicaA, backlot)).isDeleted, isTrue);
      expect(await liveLocationNames(replicaA), ['Office', 'Studio']);

      // One push carries every stamp the restore (and everything since the baseline sync) wrote.
      await deviceA.changesetService.pushLocalEdits(
        database: replicaA,
        storage: storage,
        relayId: relayId,
        deviceId: 'device-a',
      );

      // Bring B online: a single pullAndApply catches up on everything appended since the
      // baseline, in one call.
      final conflicts = await deviceB.changesetService.pullAndApply(
        database: replicaB,
        storage: storage,
        relayId: relayId,
      );
      expect(conflicts, isEmpty, reason: "B made no edit of its own, so this merges cleanly");

      // The screenplay text converges to A's restored text through the three-way merge — B's own
      // side of that merge is unchanged since the baseline, so this is the clean case.
      expect(
        await deviceB.screenplayService.loadScreenplayText(database: replicaB, screenplayId: screenplayId),
        textAtV1,
      );

      // Every row the restore touched converges byte-for-byte: the renamed row is back to its
      // earlier name, the deleted row is resurrected, and the row added after V1 stays a
      // tombstone — invisible to a normal, isDeleted-filtered read on B, exactly as on A.
      expect(await locationRow(replicaB, office), await locationRow(replicaA, office));
      expect(await locationRow(replicaB, studio), await locationRow(replicaA, studio));
      expect(await locationRow(replicaB, backlot), await locationRow(replicaA, backlot));
      expect((await locationRow(replicaB, backlot)).isDeleted, isTrue);
      expect(await liveLocationNames(replicaB), ['Office', 'Studio']);

      // scenes is derived and recomputed independently on each replica, never merged nor
      // synchronised — both must still show the very same live scene headings.
      const expectedHeadings = ['INT. HOUSE - DAY', 'EXT. STREET - NIGHT'];
      expect(await sceneHeadingsOf(replicaA), expectedHeadings);
      expect(await sceneHeadingsOf(replicaB), expectedHeadings);

      // And `scenes` is never named by any changeset this whole scenario appended — the restore's
      // own bulk rewrite of that table included (`OcptProjectVersionsService._applyPayload` stamps
      // every table it restores except `scenes`).
      final everyAppendedChangeset = await storage.readSince(OcptSequenceNumber.zero);
      expect(everyAppendedChangeset, hasLength(2), reason: "the baseline push, and the restore's own");
      for (final entry in everyAppendedChangeset) {
        final changeset = OcptChangeset.decode(entry.envelope.payload);
        for (final stamp in changeset.fieldStamps) {
          expect(stamp.tableName, isNot('scenes'));
        }
      }
    },
  );
}
