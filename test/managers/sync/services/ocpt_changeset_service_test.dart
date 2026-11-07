// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_field_stamp.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_merge_failure.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import '../../../ocpt_result_expectations.dart';

/// Answer with the fixed device id the storyboard service stamps its writes with.
Future<String> _testDeviceId() async => 'device-1';

/// Run the tests of [OcptChangesetService].
void main() {
  const deviceId = 'device-1';
  const relayId = 'relay-1';
  const service = OcptChangesetService(
    logger: SilentLogger(),
    mergeService: OcptMergeService(logger: SilentLogger()),
  );

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
    final stored = (await storage.readSince(OcptSequenceNumber.zero)).value;

    return [
      for (final entry in stored!) ...OcptChangeset.decode(entry.envelope.payload).fieldStamps,
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

  /// Stamp [columnName] of [tableName]'s row [rowId] as written by this device at a new version.
  Future<void> insertStamp({
    required String tableName,
    required String rowId,
    required String columnName,
  }) => database
      .into(database.ocptRowFieldVersionsTable)
      .insert(
        OcptRowFieldVersionsTableCompanion.insert(
          targetTableName: tableName,
          rowId: rowId,
          columnName: columnName,
          version: 1,
          deviceId: deviceId,
        ),
      );

  /// Expect a push to refuse with [message], appending nothing and leaving the cursors alone.
  Future<void> expectRefused(String message) async {
    final pushed = await service.pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );

    expect(pushed.status, OcptRemoteStorageStatus.unreachable);
    final detail = pushed.extraInfo;
    expect(detail, isA<OcptSyncMergeFailure>());
    expect((detail! as OcptSyncMergeFailure).error, isA<StateError>());
    expect(detail.toString(), contains(message));
    expect((await storage.readSince(OcptSequenceNumber.zero)).value, isEmpty);
    expect(await database.select(database.ocptSyncRelayCursorsTable).get(), isEmpty);
  }

  group('a push whose stamps and tables drifted apart is refused', () {
    test('a stamp naming a table that is not synchronised', () async {
      await insertStamp(tableName: 'not_a_table', rowId: 'row-1', columnName: 'name');

      await expectRefused("row_field_versions names table 'not_a_table'");
    });

    test('a stamp naming a column its table does not have', () async {
      final location = await insertLocation('location-1');
      await insertStamp(tableName: 'locations', rowId: location.id, columnName: 'noSuchColumn');

      await expectRefused("stamps column 'noSuchColumn' of 'locations'");
    });

    test('a stamp naming a row its table does not hold', () async {
      await insertStamp(tableName: 'locations', rowId: 'ghost', columnName: 'name');

      await expectRefused("No row 'ghost' found in 'locations'");
    });

    test('and is pushed once the stamps are mended', () async {
      final location = await insertLocation('location-1');
      await insertStamp(tableName: 'locations', rowId: location.id, columnName: 'noSuchColumn');
      await database.customStatement("UPDATE row_field_versions SET column_name = 'name'");

      await service
          .pushLocalEdits(
            database: database,
            storage: storage,
            relayId: relayId,
            deviceId: deviceId,
          )
          .okOrFail;

      expect(await readAppendedFieldStamps(), hasLength(1));
    });
  });

  test('a freshly created storyboard annotation is pushed with its text column stamped', () async {
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database.customStatement(
      "INSERT INTO storyboard_panels (id, shot_id) VALUES ('panel-1', 'shot-1')",
    );
    const storyboardService = OcptStoryboardService(
      logger: SilentLogger(),
      assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
      deviceId: _testDeviceId,
    );

    final annotationId = await storyboardService
        .addAnnotation(
          database: database,
          panelId: 'panel-1',
          kind: OcptStoryboardAnnotationKind.label,
          x1: 0.1,
          y1: 0.2,
          text: 'dolly in',
        )
        .valueOrFail;

    await service
        .pushLocalEdits(database: database, storage: storage, relayId: relayId, deviceId: deviceId)
        .okOrFail;

    final textStamps = (await readAppendedFieldStamps()).where(
      (stamp) => stamp.tableName == 'storyboard_annotations' && stamp.rowId == annotationId,
    );
    expect(textStamps.map((stamp) => stamp.columnName), contains('text'));
    expect(textStamps.map((stamp) => stamp.columnName), isNot(contains('labelText')));
  });

  test('nothing to push appends nothing and touches no cursor', () async {
    await service
        .pushLocalEdits(database: database, storage: storage, relayId: relayId, deviceId: deviceId)
        .okOrFail;

    expect((await storage.readSince(OcptSequenceNumber.zero)).value, isEmpty);
    expect(await database.select(database.ocptSyncRelayCursorsTable).get(), isEmpty);
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

      await service
          .pushLocalEdits(
            database: database,
            storage: storage,
            relayId: relayId,
            deviceId: deviceId,
          )
          .okOrFail;

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

  test("the generic row id for a shot_characters row equals ocptCompositeRowStampKey "
      "([shotId, roleId])", () async {
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
    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(id: 'role-1', name: 'JOHN', kind: OcptRoleKind.speaking),
        );

    const shotCharacter = OcptShotCharacterRow(
      shotId: 'shot-1',
      roleId: 'role-1',
      position: 0,
      sortKey: '',
      isDeleted: false,
    );
    final expectedRowId = ocptCompositeRowStampKey([shotCharacter.shotId, shotCharacter.roleId]);

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

    await service
        .pushLocalEdits(database: database, storage: storage, relayId: relayId, deviceId: deviceId)
        .okOrFail;

    final fieldStamps = await readAppendedFieldStamps();

    expect(fieldStamps, isNotEmpty);
    for (final stamp in fieldStamps) {
      expect(stamp.tableName, 'shot_characters');
      expect(stamp.rowId, expectedRowId);
    }
  });

  test(
    'a second generate with no new edits appends nothing once the water mark has advanced',
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

      final stampedVersion =
          (await database.select(database.ocptRowFieldVersionsTable).getSingle()).version;

      await service
          .pushLocalEdits(
            database: database,
            storage: storage,
            relayId: relayId,
            deviceId: deviceId,
          )
          .okOrFail;
      expect((await storage.readSince(OcptSequenceNumber.zero)).value, hasLength(1));

      final cursor = await (database.select(
        database.ocptSyncRelayCursorsTable,
      )..where((table) => table.relayId.equals(relayId))).getSingle();
      expect(cursor.outboxHighWaterMark, stampedVersion);

      // Calling it again with no new edits must append nothing more.
      await service
          .pushLocalEdits(
            database: database,
            storage: storage,
            relayId: relayId,
            deviceId: deviceId,
          )
          .okOrFail;
      expect((await storage.readSince(OcptSequenceNumber.zero)).value, hasLength(1));
    },
  );

  test(
    "a stamp bearing a different device id is never pushed as this replica's own edit",
    () async {
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

      await service
          .pushLocalEdits(
            database: database,
            storage: storage,
            relayId: relayId,
            deviceId: deviceId,
          )
          .okOrFail;

      expect((await storage.readSince(OcptSequenceNumber.zero)).value, isEmpty);
    },
  );

  group('countUnpushedEdits', () {
    test('is zero when nothing has ever been stamped', () async {
      expect(
        await service.countUnpushedEdits(database: database, relayId: relayId, deviceId: deviceId),
        0,
      );
    });

    test('counts exactly the stamps a push would send, and none it already sent', () async {
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

      expect(
        await service.countUnpushedEdits(database: database, relayId: relayId, deviceId: deviceId),
        1,
      );

      await service
          .pushLocalEdits(
            database: database,
            storage: storage,
            relayId: relayId,
            deviceId: deviceId,
          )
          .okOrFail;

      expect(
        await service.countUnpushedEdits(database: database, relayId: relayId, deviceId: deviceId),
        0,
      );
    });

    test("never counts another device's own stamp", () async {
      final location = await insertLocation('location-1');
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

      expect(
        await service.countUnpushedEdits(database: database, relayId: relayId, deviceId: deviceId),
        0,
      );
    });
  });

  group('highestAppendedSequence', () {
    test('is zero when this replica has never pushed anything to this relay', () async {
      expect(
        await service.highestAppendedSequence(database: database, relayId: relayId),
        OcptSequenceNumber.zero,
      );
    });

    test('reflects the outbox water mark a push just advanced', () async {
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
      final stampedVersion =
          (await database.select(database.ocptRowFieldVersionsTable).getSingle()).version;

      await service
          .pushLocalEdits(
            database: database,
            storage: storage,
            relayId: relayId,
            deviceId: deviceId,
          )
          .okOrFail;

      expect(
        await service.highestAppendedSequence(database: database, relayId: relayId),
        OcptSequenceNumber(stampedVersion),
      );
    });

    test('never advances for a relay nothing has been pushed to', () async {
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

      await service
          .pushLocalEdits(
            database: database,
            storage: storage,
            relayId: relayId,
            deviceId: deviceId,
          )
          .okOrFail;

      expect(
        await service.highestAppendedSequence(database: database, relayId: 'another-relay'),
        OcptSequenceNumber.zero,
      );
    });
  });
}
