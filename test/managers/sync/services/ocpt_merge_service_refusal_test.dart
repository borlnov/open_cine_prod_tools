// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_field_stamp.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_merge_failure.dart';
import 'package:open_cine_prod_tools/types/ocpt_merge_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';

/// What `OcptMergeService` does with a changeset that names a table or a column this replica does
/// not know: refuse it whole, as a value, and leave the file as it was.
void main() {
  const mergeService = OcptMergeService(logger: SilentLogger());
  const relayId = 'relay-1';

  const knownStamp = OcptFieldStamp(
    tableName: 'locations',
    rowId: 'location-1',
    columnName: 'name',
    value: 'Merged',
    version: 1,
    deviceId: 'device-remote',
  );

  late OcptProjectDatabase database;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    addTearDown(database.close);
    await database
        .into(database.ocptLocationsTable)
        .insert(OcptLocationsTableCompanion.insert(id: 'location-1', name: 'Untitled'));
  });

  Future<String> locationName() async => (await (database.select(
    database.ocptLocationsTable,
  )..where((table) => table.id.equals('location-1'))).getSingle()).name;

  Future<int> stampCount() async =>
      (await database.select(database.ocptRowFieldVersionsTable).get()).length;

  test(
    'a changeset naming an unknown table is refused and rolls back what came before it',
    () async {
      final result = await mergeService.applyChangeset(
        fileDatabase: database,
        changeset: const OcptChangeset(
          fieldStamps: [
            knownStamp,
            OcptFieldStamp(
              tableName: 'no_such_table',
              rowId: 'row-1',
              columnName: 'name',
              value: 'x',
              version: 1,
              deviceId: 'device-remote',
            ),
          ],
        ),
      );

      expect(result.status, OcptMergeStatus.unknownTable);
      expect(result.value, isNull);
      final failure = result.extraInfo! as OcptSyncMergeFailure;
      expect(failure.toString(), contains('no_such_table'));
      expect(await locationName(), 'Untitled');
      expect(await stampCount(), 0);
    },
  );

  test(
    'a changeset naming an unknown column is refused and rolls back what came before it',
    () async {
      final result = await mergeService.applyChangeset(
        fileDatabase: database,
        changeset: const OcptChangeset(
          fieldStamps: [
            knownStamp,
            OcptFieldStamp(
              tableName: 'locations',
              rowId: 'location-2',
              columnName: 'noSuchColumn',
              value: 'x',
              version: 1,
              deviceId: 'device-remote',
            ),
          ],
        ),
      );

      expect(result.status, OcptMergeStatus.unknownColumn);
      expect(result.extraInfo, isA<OcptSyncMergeFailure>());
      expect(await locationName(), 'Untitled');
      expect(await stampCount(), 0);
    },
  );

  test('a changeset that is known applies and answers ok with its conflicts', () async {
    final result = await mergeService.applyChangeset(
      fileDatabase: database,
      changeset: const OcptChangeset(fieldStamps: [knownStamp]),
    );

    expect(result.status, OcptMergeStatus.ok);
    expect(result.value, isEmpty);
    expect(await locationName(), 'Merged');
  });

  test('a pull whose changeset is refused stops before the cursor moves, and tells why', () async {
    final tempDir = await Directory.systemTemp.createTemp('ocpt_merge_refusal_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final storage = OcptFolderRemoteStorage(tempDir);
    final appended = await storage.append(
      OcptChangesetEnvelope(
        changesetId: 'changeset-1',
        originDeviceId: 'device-remote',
        lamport: 1,
        createdAt: DateTime.utc(2026),
        payload: const OcptChangeset(
          fieldStamps: [
            OcptFieldStamp(
              tableName: 'no_such_table',
              rowId: 'row-1',
              columnName: 'name',
              value: 'x',
              version: 1,
              deviceId: 'device-remote',
            ),
          ],
        ).encode(),
      ),
    );
    expect(appended.isSuccess, isTrue);

    const changesetService = OcptChangesetService(
      logger: SilentLogger(),
      mergeService: mergeService,
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      final pulled = await changesetService.pullAndApply(
        database: database,
        storage: storage,
        relayId: relayId,
      );

      expect(pulled.status, OcptRemoteStorageStatus.unreachable);
      expect(pulled.extraInfo, isA<OcptSyncMergeFailure>());
      expect(await database.select(database.ocptSyncRelayCursorsTable).get(), isEmpty);
    }
  });
}
