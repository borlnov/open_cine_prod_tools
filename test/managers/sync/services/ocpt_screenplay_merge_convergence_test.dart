// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
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
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// Two replicas of the same project, converging over one shared [OcptFolderRemoteStorage], exactly
/// as `ocpt_changeset_service_test.dart` and `ocpt_merge_service_test.dart` already exercise for
/// every other synchronised column — this file is the same setup for `screenplays.fountainText`
/// specifically: the one column `docs/plans/collaboration-and-sync.md` (M3) reconciles by a
/// three-way line merge rather than last-writer-wins (`OcptScreenplayMergeService`).
void main() {
  // Refusing a write on a previewed version, and the screenplay merge service's own "no common
  // base" warning, both log through appLogger(), which requires a global manager instance to be
  // set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const screenplayId = 'screenplay-1';
  const relayId = 'relay-1';

  const originalText =
      'INT. HOUSE - DAY\n\nAction one.\n\nEXT. STREET - NIGHT\n\nAction two.';

  /// A "device" bundle: a full `OcptScreenplayService` (with its own five collaborator services,
  /// mirroring `ocpt_screenplay_service_test.dart`'s own wiring) plus the `OcptChangesetService`
  /// wired to route `fountainText` through a real `OcptScreenplayMergeService`, both stamping every
  /// write as [deviceId]'s own — exactly what one real app instance, bound to one device id, would
  /// build for itself (`OcptSyncManager`'s own constructor).
  ({OcptScreenplayService screenplayService, OcptChangesetService changesetService}) buildDevice(
    String deviceId,
  ) {
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

    return (screenplayService: screenplayService, changesetService: changesetService);
  }

  late Directory tempDir;
  late OcptFolderRemoteStorage storage;
  late OcptProjectDatabase replicaA;
  late OcptProjectDatabase replicaB;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_screenplay_merge_convergence_test_');
    storage = OcptFolderRemoteStorage(tempDir);

    replicaA = OcptProjectDatabase.memory();
    replicaB = OcptProjectDatabase.memory();

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

  Future<List<String>> sceneHeadingsOf(OcptProjectDatabase database) async {
    final scenes = await (database.select(
      database.ocptScenesTable,
    )..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
    return scenes.map((scene) => scene.heading).toList();
  }

  test(
    'non-overlapping edits on both replicas converge to the merged text, and scenes are recomputed on both',
    () async {
      final deviceA = buildDevice('device-a');
      final deviceB = buildDevice('device-b');

      await deviceA.screenplayService.saveScreenplayText(
        database: replicaA,
        screenplayId: screenplayId,
        fountainText: 'INT. HOUSE - DAY\n\nAction one, from A.\n\nEXT. STREET - NIGHT\n\nAction two.',
        snapshotReason: OcptSnapshotReason.manual,
      );
      await deviceB.screenplayService.saveScreenplayText(
        database: replicaB,
        screenplayId: screenplayId,
        fountainText: 'INT. HOUSE - DAY\n\nAction one.\n\nEXT. STREET - NIGHT\n\nAction two, from B.',
        snapshotReason: OcptSnapshotReason.manual,
      );

      // The usual round-robin: A pushes and pulls (nothing new to pull yet), B pushes and pulls
      // (picks up A's edit alongside its own, merging the two), and a second round for A picks up
      // what B pushed — including the merged text B's own merge just produced.
      final conflictsA1 = await deviceA.changesetService.syncOnce(
        database: replicaA,
        storage: storage,
        relayId: relayId,
        deviceId: 'device-a',
      );
      final conflictsB = await deviceB.changesetService.syncOnce(
        database: replicaB,
        storage: storage,
        relayId: relayId,
        deviceId: 'device-b',
      );
      final conflictsA2 = await deviceA.changesetService.syncOnce(
        database: replicaA,
        storage: storage,
        relayId: relayId,
        deviceId: 'device-a',
      );

      expect(conflictsA1, isEmpty);
      expect(conflictsB, isEmpty);
      expect(conflictsA2, isEmpty);

      const mergedText =
          'INT. HOUSE - DAY\n\nAction one, from A.\n\nEXT. STREET - NIGHT\n\nAction two, from B.';

      expect(
        await deviceA.screenplayService.loadScreenplayText(database: replicaA, screenplayId: screenplayId),
        mergedText,
      );
      expect(
        await deviceB.screenplayService.loadScreenplayText(database: replicaB, screenplayId: screenplayId),
        mergedText,
      );

      // scenes is derived and recomputed from the merged text, not merged itself — both replicas
      // must show the very same two scene headings.
      const expectedHeadings = ['INT. HOUSE - DAY', 'EXT. STREET - NIGHT'];
      expect(await sceneHeadingsOf(replicaA), expectedHeadings);
      expect(await sceneHeadingsOf(replicaB), expectedHeadings);
    },
  );

  test('scenes is never named by any changeset pushed while syncing a screenplay merge', () async {
    final deviceA = buildDevice('device-a');
    final deviceB = buildDevice('device-b');

    await deviceA.screenplayService.saveScreenplayText(
      database: replicaA,
      screenplayId: screenplayId,
      fountainText: 'INT. HOUSE - DAY\n\nAction one, from A.\n\nEXT. STREET - NIGHT\n\nAction two.',
      snapshotReason: OcptSnapshotReason.manual,
    );
    await deviceB.screenplayService.saveScreenplayText(
      database: replicaB,
      screenplayId: screenplayId,
      fountainText: 'INT. HOUSE - DAY\n\nAction one.\n\nEXT. STREET - NIGHT\n\nAction two, from B.',
      snapshotReason: OcptSnapshotReason.manual,
    );

    await deviceA.changesetService.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');
    await deviceB.changesetService.syncOnce(database: replicaB, storage: storage, relayId: relayId, deviceId: 'device-b');
    await deviceA.changesetService.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');

    final stored = await storage.readSince(OcptSequenceNumber.zero);
    expect(stored, isNotEmpty);

    for (final entry in stored) {
      final changeset = OcptChangeset.decode(entry.envelope.payload);
      for (final stamp in changeset.fieldStamps) {
        expect(stamp.tableName, isNot('scenes'));
      }
    }
  });

  test('the same lines edited differently on both replicas raise a recorded conflict, losing nothing', () async {
    final deviceA = buildDevice('device-a');
    final deviceB = buildDevice('device-b');

    const localTextOnA =
        'INT. HOUSE - DAY\n\nAction one, from A.\n\nEXT. STREET - NIGHT\n\nAction two.';
    const localTextOnB =
        'INT. HOUSE - DAY\n\nAction one, from B.\n\nEXT. STREET - NIGHT\n\nAction two.';

    await deviceA.screenplayService.saveScreenplayText(
      database: replicaA,
      screenplayId: screenplayId,
      fountainText: localTextOnA,
      snapshotReason: OcptSnapshotReason.manual,
    );
    await deviceB.screenplayService.saveScreenplayText(
      database: replicaB,
      screenplayId: screenplayId,
      fountainText: localTextOnB,
      snapshotReason: OcptSnapshotReason.manual,
    );

    await deviceA.changesetService.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');
    final conflictsB = await deviceB.changesetService.syncOnce(
      database: replicaB,
      storage: storage,
      relayId: relayId,
      deviceId: 'device-b',
    );

    expect(conflictsB, [
      const OcptScreenplayMergeConflict(
        screenplayId: screenplayId,
        baseText: originalText,
        localText: localTextOnB,
        incomingText: localTextOnA,
      ),
    ]);

    // Nothing was lost or silently overwritten: B's own text is exactly as it stood.
    expect(
      await deviceB.screenplayService.loadScreenplayText(database: replicaB, screenplayId: screenplayId),
      localTextOnB,
    );

    final conflictsA = await deviceA.changesetService.syncOnce(
      database: replicaA,
      storage: storage,
      relayId: relayId,
      deviceId: 'device-a',
    );

    expect(conflictsA, [
      const OcptScreenplayMergeConflict(
        screenplayId: screenplayId,
        baseText: originalText,
        localText: localTextOnA,
        incomingText: localTextOnB,
      ),
    ]);
    expect(
      await deviceA.screenplayService.loadScreenplayText(database: replicaA, screenplayId: screenplayId),
      localTextOnA,
    );
  });
}
