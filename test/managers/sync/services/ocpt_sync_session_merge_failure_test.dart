// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_foundation/act_foundation.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_screenplay_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_sync_session.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_field_stamp.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_merge_failure.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_merge_status.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

/// A folder transport a test can ping, as the relay does when another replica pushed.
class _PingableStorage extends OcptFolderRemoteStorage {
  /// The controller behind [newWorkStream].
  final StreamController<void> _controller = StreamController<void>.broadcast();

  /// Emit the pings the test adds.
  @override
  Stream<void> get newWorkStream => _controller.stream;

  /// Class constructor
  _PingableStorage(super.directory);

  /// Announce another replica's push.
  void pingNewWork() => _controller.add(null);

  /// Close the controller behind [newWorkStream].
  Future<void> dispose() => _controller.close();
}

/// What a sync session does, end to end, when the merge of an incoming screenplay text fails on
/// the database: it goes offline on both of its paths, with the label of the path, and the
/// changeset is read again by the next run since its cursor did not advance.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  const screenplayId = 'screenplay-1';
  const deviceId = 'test-device';
  Future<String> testDeviceId() async => deviceId;

  final assetsService = OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId);
  final roleCandidatesService = OcptRoleCandidatesService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
  );
  final elementsService = OcptElementsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );
  final locationsService = OcptLocationsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    floorPlanService: OcptFloorPlanService(
      logger: const SilentLogger(),
      assetsService: assetsService,
      deviceId: testDeviceId,
    ),
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
  final scheduleService = OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId);
  const sceneIndexService = OcptSceneIndexService(logger: SilentLogger());
  final shotListService = OcptShotListService(
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
  );
  final shotCoverageService = OcptShotCoverageService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
  );
  final screenplayService = OcptScreenplayService(
    logger: const SilentLogger(),
    sceneIndexService: sceneIndexService,
    shotListService: shotListService,
    shotCoverageService: shotCoverageService,
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: scheduleService,
    deviceId: testDeviceId,
  );
  final mergeService = OcptScreenplayMergeService(
    logger: const SilentLogger(),
    screenplayService: screenplayService,
    deviceId: testDeviceId,
  );

  const projectId = 'project-1';
  const relayId = 'relay-1';

  late Directory tempDir;
  late _PingableStorage storage;
  late OcptProjectDatabase database;
  late OcptDiagnosticsManager diagnostics;
  late FakeLogger fakeLogger;
  late OcptSyncSession session;

  setUp(() async {
    diagnostics = OcptDiagnosticsManager();
    final managers = globalGetIt();
    if (managers.isRegistered<OcptDiagnosticsManager>()) {
      await managers.unregister<OcptDiagnosticsManager>();
    }
    managers.registerSingleton<OcptDiagnosticsManager>(diagnostics);

    tempDir = await Directory.systemTemp.createTemp('ocpt_sync_merge_failure_test_');
    storage = _PingableStorage(tempDir);
    database = OcptProjectDatabase.memory();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: 'Title',
            updatedAt: DateTime.utc(2026),
            fountainText: const Value('local text'),
          ),
        );
    fakeLogger = FakeLogger();
    session = OcptSyncSession(
      logger: fakeLogger,
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
      changesetService: OcptChangesetService(
        logger: const SilentLogger(),
        mergeService: OcptMergeService(
          logger: const SilentLogger(),
          screenplayMergeService: mergeService,
        ),
      ),
      pushInterval: const Duration(hours: 1),
    );
  });

  tearDown(() async {
    await session.stop();
    await storage.dispose();
    await database.close();
    final managers = globalGetIt();
    if (managers.isRegistered<OcptDiagnosticsManager>()) {
      await managers.unregister<OcptDiagnosticsManager>();
    }
    await diagnostics.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Append to the transport a changeset of another replica carrying a new text for the screenplay.
  Future<void> appendIncomingText() async {
    await storage.append(
      OcptChangesetEnvelope(
        changesetId: 'changeset-1',
        originDeviceId: 'device-2',
        lamport: 5,
        createdAt: DateTime.utc(2026, 2),
        payload: const OcptChangeset(
          fieldStamps: [
            OcptFieldStamp(
              tableName: 'screenplays',
              rowId: screenplayId,
              columnName: 'fountainText',
              value: 'incoming text',
              version: 5,
              deviceId: 'device-2',
            ),
          ],
        ).encode(),
      ),
    );
  }

  /// Make the local text of the screenplay unreadable.
  Future<void> breakTheText() =>
      database.customStatement('ALTER TABLE screenplays RENAME TO screenplays_gone');

  /// Get the diagnostics lines that say why the session went offline.
  List<String> causes() => [
    for (final entry in diagnostics.entries)
      if (entry.message.startsWith('offline cause')) entry.message,
  ];

  /// Get the position the pull cursor stands at, read straight from the database.
  Future<int> lastAppliedSequence() async {
    final rows = await database.select(database.ocptSyncRelayCursorsTable).get();

    return rows.isEmpty ? 0 : rows.single.lastAppliedSequence;
  }

  /// Let the text be read again, and tell the session to sync.
  Future<void> repairAndSyncAgain() async {
    await database.customStatement('ALTER TABLE screenplays_gone RENAME TO screenplays');
    await session.syncNow();
  }

  test('a failed text merge goes offline with the label of the push and pull run', () async {
    await appendIncomingText();
    await breakTheText();

    await session.start();

    expect(session.status, isA<OcptSyncStatusOffline>());
    expect(
      fakeLogger.recordsAtLevel(LogsLevel.warn).first.message.toString(),
      'Sync failed for project $projectId: SqliteException',
    );
    expect(causes(), ['offline cause: project=$projectId SqliteException']);
    expect(await lastAppliedSequence(), 0, reason: 'the cursor did not advance');

    await repairAndSyncAgain();

    expect(session.status, isA<OcptSyncStatusInSync>());
    expect(await lastAppliedSequence(), greaterThan(0));
  });

  test('a failed text merge goes offline with the label of the pull alone', () async {
    await session.start();
    expect(session.status, isA<OcptSyncStatusInSync>());
    await appendIncomingText();
    await breakTheText();

    storage.pingNewWork();
    for (var waited = 0; session.status is! OcptSyncStatusOffline; waited++) {
      expect(waited, lessThan(400), reason: 'the session never went offline');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(
      fakeLogger.recordsAtLevel(LogsLevel.warn).first.message.toString(),
      'Sync pull failed for project $projectId: SqliteException',
    );
    expect(causes(), ['offline cause: project=$projectId SqliteException']);
    expect(await lastAppliedSequence(), 0, reason: 'the cursor did not advance');

    await repairAndSyncAgain();

    expect(session.status, isA<OcptSyncStatusInSync>());
  });

  test('a failed text merge rolls back what the changeset had applied before it', () async {
    await database
        .into(database.ocptLocationsTable)
        .insert(OcptLocationsTableCompanion.insert(id: 'location-1', name: 'Untitled'));
    await breakTheText();

    final applied =
        await OcptMergeService(
          logger: const SilentLogger(),
          screenplayMergeService: mergeService,
        ).applyChangeset(
          fileDatabase: database,
          changeset: const OcptChangeset(
            fieldStamps: [
              OcptFieldStamp(
                tableName: 'locations',
                rowId: 'location-1',
                columnName: 'name',
                value: 'Exterior',
                version: 5,
                deviceId: 'device-2',
              ),
              OcptFieldStamp(
                tableName: 'screenplays',
                rowId: screenplayId,
                columnName: 'fountainText',
                value: 'incoming text',
                version: 5,
                deviceId: 'device-2',
              ),
            ],
          ),
        );

    expect(applied.status, OcptMergeStatus.databaseError);
    expect(applied.extraInfo, isA<OcptSyncMergeFailure>());
    expect((applied.extraInfo! as OcptSyncMergeFailure).error, SqliteException);
    expect((await database.select(database.ocptLocationsTable).getSingle()).name, 'Untitled');
    expect(await database.select(database.ocptRowFieldVersionsTable).get(), isEmpty);
  });
}
