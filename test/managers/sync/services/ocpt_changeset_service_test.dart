// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_field_stamp.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';

void main() {
  const deviceId = 'device-1';
  const relayId = 'relay-1';
  const service = OcptChangesetService();

  late Directory tempDir;
  late OcptFolderRemoteStorage storage;
  late OcptProjectDatabase database;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_changeset_service_test_');
    storage = OcptFolderRemoteStorage(tempDir);
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Every field stamp appended to [storage] so far, across however many changesets it holds,
  /// decoding each one's own opaque payload.
  Future<List<OcptFieldStamp>> readAppendedFieldStamps() async {
    final stored = await storage.readSince(OcptSequenceNumber.zero);

    return [
      for (final entry in stored) ...OcptChangeset.decode(entry.envelope.payload).fieldStamps,
    ];
  }

  /// Inserts and returns a bare location row, [id] apart every column at its schema default —
  /// mirrors `ocpt_row_stamp_service_test.dart`'s own helper.
  Future<OcptLocationRow> insertLocation(String id) async {
    await database
        .into(database.ocptLocationsTable)
        .insert(OcptLocationsTableCompanion.insert(id: id, name: "Untitled"));
    return (database.select(
      database.ocptLocationsTable,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  test('nothing to push appends nothing and touches no cursor', () async {
    await service.pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );

    expect(await storage.readSince(OcptSequenceNumber.zero), isEmpty);
    expect(
      await database.select(database.ocptSyncRelayCursorsTable).get(),
      isEmpty,
    );
  });

  test(
    'a local write to an arbitrary synchronised table produces exactly its changed columns',
    () async {
      final location = await insertLocation('location-1');

      final stamps = await OcptRowStampService.seed(database: database, deviceId: deviceId);
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptLocationsTable,
        rowId: location.id,
        current: location,
        next: location.copyWith(name: 'Exterior'),
        stamps: stamps,
      );
      await stamps.flush(database);

      final rawStamp = await database.select(database.ocptRowFieldVersionsTable).getSingle();

      await service.pushLocalEdits(
        database: database,
        storage: storage,
        relayId: relayId,
        deviceId: deviceId,
      );

      final fieldStamps = await readAppendedFieldStamps();

      expect(fieldStamps, [
        OcptFieldStamp(
          tableName: 'locations',
          rowId: location.id,
          columnName: 'name',
          value: 'Exterior',
          version: rawStamp.version,
          deviceId: deviceId,
        ),
      ]);
    },
  );

  test(
    "the generic row id for a shot_characters row equals ocptCompositeRowStampKey "
    "([shotId, characterName])",
    () async {
      await database
          .into(database.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: 'screenplay-1',
              title: 'Title',
              updatedAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.ocptShotsTable)
          .insert(
            OcptShotsTableCompanion.insert(id: 'shot-1', screenplayId: 'screenplay-1', position: 0),
          );

      const shotCharacter = OcptShotCharacterRow(
        shotId: 'shot-1',
        characterName: 'JOHN',
        position: 0,
        sortKey: '',
        isDeleted: false,
      );
      final expectedRowId = ocptCompositeRowStampKey([shotCharacter.shotId, shotCharacter.characterName]);

      final stamps = await OcptRowStampService.seed(database: database, deviceId: deviceId);
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShotCharactersTable,
        rowId: expectedRowId,
        current: null,
        next: shotCharacter,
        stamps: stamps,
      );
      await stamps.flush(database);

      await service.pushLocalEdits(
        database: database,
        storage: storage,
        relayId: relayId,
        deviceId: deviceId,
      );

      final fieldStamps = await readAppendedFieldStamps();

      expect(fieldStamps, isNotEmpty);
      for (final stamp in fieldStamps) {
        expect(stamp.tableName, 'shot_characters');
        expect(stamp.rowId, expectedRowId);
      }
    },
  );

  test('a second generate with no new edits appends nothing once the water mark has advanced', () async {
    final location = await insertLocation('location-1');
    final stamps = await OcptRowStampService.seed(database: database, deviceId: deviceId);
    await OcptRowStampService.writeAndStamp(
      database: database,
      table: database.ocptLocationsTable,
      rowId: location.id,
      current: location,
      next: location.copyWith(name: 'Exterior'),
      stamps: stamps,
    );
    await stamps.flush(database);

    final stampedVersion = (await database.select(database.ocptRowFieldVersionsTable).getSingle()).version;

    await service.pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );
    expect(await storage.readSince(OcptSequenceNumber.zero), hasLength(1));

    final cursor = await (database.select(
      database.ocptSyncRelayCursorsTable,
    )..where((table) => table.relayId.equals(relayId))).getSingle();
    expect(cursor.outboxHighWaterMark, stampedVersion);

    // Calling it again with no new edits must append nothing more.
    await service.pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );
    expect(await storage.readSince(OcptSequenceNumber.zero), hasLength(1));
  });

  test("a stamp bearing a different device id is never pushed as this replica's own edit", () async {
    final location = await insertLocation('location-1');

    // As if this column had been merged in from another device rather than edited locally.
    await database
        .into(database.ocptRowFieldVersionsTable)
        .insert(
          OcptRowFieldVersionsTableCompanion.insert(
            targetTableName: 'locations',
            rowId: location.id,
            columnName: 'name',
            version: 1,
            deviceId: 'other-device',
          ),
        );

    await service.pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );

    expect(await storage.readSince(OcptSequenceNumber.zero), isEmpty);
  });
}
