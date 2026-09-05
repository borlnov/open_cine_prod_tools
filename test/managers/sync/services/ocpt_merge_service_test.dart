// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_field_stamp.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';

/// Two replicas of the same project, both reading and writing through one shared
/// [OcptFolderRemoteStorage] — exactly the setup `docs/plans/collaboration-and-sync.md`'s M3 tests
/// ask for, exercised here through [OcptChangesetService]'s outbound and inbound halves together.
void main() {
  // The preview test below calls `refusesUserWrite`, which logs through `appLogger()`; that
  // requires a global manager instance to be set, and merely accessing it creates the (otherwise
  // unused) singleton — the same idiom `ocpt_elements_service_test.dart` uses.
  setUpAll(() => OcptGlobalManager.instance);

  const service = OcptChangesetService();
  const relayId = 'relay-1';

  late Directory tempDir;
  late OcptFolderRemoteStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_merge_service_test_');
    storage = OcptFolderRemoteStorage(tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Seeds [database] with a screenplay and one shot of it, both directly — bypassing
  /// `OcptRowStampService` entirely, so this baseline is never pushed as anybody's own edit — with
  /// exactly the same values every caller passes, which is what lets two replicas start out
  /// identical without ever exchanging a changeset for it.
  Future<void> seedScreenplayAndShot(OcptProjectDatabase database, {required String shotId}) async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: 'screenplay-1', title: 'Title', updatedAt: DateTime.utc(2026)),
        );
    await database
        .into(database.ocptShotsTable)
        .insert(OcptShotsTableCompanion.insert(id: shotId, screenplayId: 'screenplay-1', position: 0));
  }

  /// Stamps and writes [next] over [current] on [database], as [deviceId]'s own edit, then flushes
  /// the stamp — the shape every test below uses to make "a replica edits a row" concrete.
  /// [current] is null for a brand-new row, exactly like `OcptRowStampService.writeAndStamp` itself.
  Future<void> writeAndStamp<D extends DataClass>({
    required OcptProjectDatabase database,
    required String deviceId,
    required TableInfo<Table, D> table,
    required String rowId,
    required D? current,
    required D next,
  }) async {
    final stamps = await OcptRowStampService.seed(database: database, deviceId: deviceId);
    await OcptRowStampService.writeAndStamp(
      database: database,
      table: table,
      rowId: rowId,
      current: current,
      next: next,
      stamps: stamps,
    );
    await stamps.flush(database);
  }

  Future<OcptShotRow> readShot(OcptProjectDatabase database, String shotId) =>
      (database.select(database.ocptShotsTable)..where((table) => table.id.equals(shotId))).getSingle();

  test('two replicas editing different columns of the same shot row both survive on both', () async {
    final replicaA = OcptProjectDatabase.memory();
    final replicaB = OcptProjectDatabase.memory();
    addTearDown(replicaA.close);
    addTearDown(replicaB.close);

    const shotId = 'shot-1';
    await seedScreenplayAndShot(replicaA, shotId: shotId);
    await seedScreenplayAndShot(replicaB, shotId: shotId);

    final baseline = await readShot(replicaA, shotId);
    await writeAndStamp(
      database: replicaA,
      deviceId: 'device-a',
      table: replicaA.ocptShotsTable,
      rowId: shotId,
      current: baseline,
      next: baseline.copyWith(framing: 'Close-up'),
    );
    await writeAndStamp(
      database: replicaB,
      deviceId: 'device-b',
      table: replicaB.ocptShotsTable,
      rowId: shotId,
      current: baseline,
      next: baseline.copyWith(shootingDay: const Value('2026-09-01')),
    );

    // A round-robin of syncOnce, exactly what a test drives to converge two replicas: A pushes and
    // pulls first (nothing to pull yet but its own edit), B pushes and pulls next (picks up A's
    // edit alongside its own), and a second round for A picks up what B pushed after A's own pull.
    await service.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');
    await service.syncOnce(database: replicaB, storage: storage, relayId: relayId, deviceId: 'device-b');
    await service.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');

    final onA = await readShot(replicaA, shotId);
    final onB = await readShot(replicaB, shotId);

    expect(onA.framing, 'Close-up');
    expect(onA.shootingDay, '2026-09-01');
    expect(onB.framing, 'Close-up');
    expect(onB.shootingDay, '2026-09-01');
  });

  test(
    'an edited TypeConverter-backed enum column (shots.status) converges to the same value',
    () async {
      // This is also this schema's only kind of `TypeConverter` column: every `TypeConverter` this
      // app declares (`git grep 'extends TypeConverter<'`) converts an enum to text, so there is no
      // separate non-enum `TypeConverter` case to exercise. Before the raw-value fix, this column's
      // stamped value was an `OcptShotStatus` enum instance straight out of `toJson()`, which
      // `jsonEncode` cannot serialise — pushing this edit used to throw.
      final replicaA = OcptProjectDatabase.memory();
      final replicaB = OcptProjectDatabase.memory();
      addTearDown(replicaA.close);
      addTearDown(replicaB.close);

      const shotId = 'shot-1';
      await seedScreenplayAndShot(replicaA, shotId: shotId);
      await seedScreenplayAndShot(replicaB, shotId: shotId);

      final baseline = await readShot(replicaA, shotId);
      await writeAndStamp(
        database: replicaA,
        deviceId: 'device-a',
        table: replicaA.ocptShotsTable,
        rowId: shotId,
        current: baseline,
        next: baseline.copyWith(status: OcptShotStatus.retake),
      );

      await service.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');
      await service.syncOnce(database: replicaB, storage: storage, relayId: relayId, deviceId: 'device-b');

      final onA = await readShot(replicaA, shotId);
      final onB = await readShot(replicaB, shotId);

      expect(onA.status, OcptShotStatus.retake);
      expect(onB.status, OcptShotStatus.retake);
    },
  );

  test('an edited DateTime column (screenplays.updatedAt) converges to the same value', () async {
    final replicaA = OcptProjectDatabase.memory();
    final replicaB = OcptProjectDatabase.memory();
    addTearDown(replicaA.close);
    addTearDown(replicaB.close);

    const shotId = 'shot-1';
    await seedScreenplayAndShot(replicaA, shotId: shotId);
    await seedScreenplayAndShot(replicaB, shotId: shotId);

    Future<OcptScreenplayRow> readScreenplay(OcptProjectDatabase database) =>
        (database.select(
          database.ocptScreenplaysTable,
        )..where((table) => table.id.equals('screenplay-1'))).getSingle();

    final baseline = await readScreenplay(replicaA);
    // Stored as ISO-8601 text (`storeDateTimeAsText`), not a Unix timestamp — a good check that the
    // raw value carried on the wire is the exact text SQLite holds, not a re-derived millisecond
    // count.
    final editedAt = DateTime.utc(2026, 3, 15, 9, 30);
    await writeAndStamp(
      database: replicaA,
      deviceId: 'device-a',
      table: replicaA.ocptScreenplaysTable,
      rowId: 'screenplay-1',
      current: baseline,
      next: baseline.copyWith(updatedAt: editedAt),
    );

    await service.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');
    await service.syncOnce(database: replicaB, storage: storage, relayId: relayId, deviceId: 'device-b');

    final onA = await readScreenplay(replicaA);
    final onB = await readScreenplay(replicaB);

    expect(onA.updatedAt, editedAt);
    expect(onB.updatedAt, editedAt);
  });

  test('a tombstone on one side and an edit on the other resolve consistently on both', () async {
    final replicaA = OcptProjectDatabase.memory();
    final replicaB = OcptProjectDatabase.memory();
    addTearDown(replicaA.close);
    addTearDown(replicaB.close);

    const shotId = 'shot-1';
    await seedScreenplayAndShot(replicaA, shotId: shotId);
    await seedScreenplayAndShot(replicaB, shotId: shotId);

    final baseline = await readShot(replicaA, shotId);
    await writeAndStamp(
      database: replicaB,
      deviceId: 'device-b',
      table: replicaB.ocptShotsTable,
      rowId: shotId,
      current: baseline,
      next: baseline.copyWith(framing: 'Wide shot'),
    );
    // Written second, so device A's tombstone carries the higher version and wins the isDeleted
    // column outright, whatever the two device ids compare as.
    await writeAndStamp(
      database: replicaA,
      deviceId: 'device-a',
      table: replicaA.ocptShotsTable,
      rowId: shotId,
      current: baseline,
      next: baseline.copyWith(isDeleted: true),
    );

    await service.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');
    await service.syncOnce(database: replicaB, storage: storage, relayId: relayId, deviceId: 'device-b');
    await service.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');

    final onA = await readShot(replicaA, shotId);
    final onB = await readShot(replicaB, shotId);

    expect(onA.isDeleted, isTrue);
    expect(onB.isDeleted, isTrue);
    expect(onA.framing, onB.framing);
    expect(onA.framing, 'Wide shot');
  });

  test('a replica offline across several changesets catches up in one pullAndApply', () async {
    final online = OcptProjectDatabase.memory();
    final offline = OcptProjectDatabase.memory();
    addTearDown(online.close);
    addTearDown(offline.close);

    const locationId = 'location-1';
    Future<void> seedLocation(OcptProjectDatabase database) => database
        .into(database.ocptLocationsTable)
        .insert(OcptLocationsTableCompanion.insert(id: locationId, name: 'Untitled'));
    await seedLocation(online);
    await seedLocation(offline);

    Future<OcptLocationRow> readLocation(OcptProjectDatabase database) =>
        (database.select(database.ocptLocationsTable)..where((table) => table.id.equals(locationId))).getSingle();

    // Three separate edits, three separate changesets, all appended to the relay while `offline`
    // never once reads it.
    for (final name in ['Exterior', 'Exterior — night', 'Exterior — night, rain']) {
      final current = await readLocation(online);
      await writeAndStamp(
        database: online,
        deviceId: 'device-online',
        table: online.ocptLocationsTable,
        rowId: locationId,
        current: current,
        next: current.copyWith(name: name),
      );
      await service.pushLocalEdits(database: online, storage: storage, relayId: relayId, deviceId: 'device-online');
    }

    expect(await storage.readSince(OcptSequenceNumber.zero), hasLength(3));

    await service.pullAndApply(database: offline, storage: storage, relayId: relayId);

    expect((await readLocation(offline)).name, 'Exterior — night, rain');
  });

  test('concurrent insertions at the same index coexist on both replicas', () async {
    final replicaA = OcptProjectDatabase.memory();
    final replicaB = OcptProjectDatabase.memory();
    addTearDown(replicaA.close);
    addTearDown(replicaB.close);

    const shotId = 'shot-1';
    await seedScreenplayAndShot(replicaA, shotId: shotId);
    await seedScreenplayAndShot(replicaB, shotId: shotId);

    Future<void> insertCharacter({
      required OcptProjectDatabase database,
      required String deviceId,
      required String characterName,
      required String sortKey,
    }) async {
      final character = OcptShotCharacterRow(
        shotId: shotId,
        characterName: characterName,
        position: 0,
        sortKey: sortKey,
        isDeleted: false,
      );
      await writeAndStamp(
        database: database,
        deviceId: deviceId,
        table: database.ocptShotCharactersTable,
        rowId: ocptCompositeRowStampKey([shotId, characterName]),
        current: null,
        next: character,
      );
    }

    // Both replicas insert a new character at the head of the same (empty) list, concurrently,
    // each with its own fractional key.
    await insertCharacter(database: replicaA, deviceId: 'device-a', characterName: 'JOHN', sortKey: 'a0');
    await insertCharacter(database: replicaB, deviceId: 'device-b', characterName: 'JANE', sortKey: 'a1');

    await service.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');
    await service.syncOnce(database: replicaB, storage: storage, relayId: relayId, deviceId: 'device-b');
    await service.syncOnce(database: replicaA, storage: storage, relayId: relayId, deviceId: 'device-a');

    Future<List<String>> characterNamesOn(OcptProjectDatabase database) async {
      final rows = await (database.select(
        database.ocptShotCharactersTable,
      )..where((table) => table.shotId.equals(shotId))).get();
      return rows.map((row) => row.characterName).toList()..sort();
    }

    expect(await characterNamesOn(replicaA), ['JANE', 'JOHN']);
    expect(await characterNamesOn(replicaB), ['JANE', 'JOHN']);

    final sortKeysOnA = await (replicaA.select(
      replicaA.ocptShotCharactersTable,
    )..where((table) => table.shotId.equals(shotId))).get();
    expect(sortKeysOnA.map((row) => row.sortKey).toSet(), {'a0', 'a1'});
  });

  test('an incoming changeset applies to fileDatabase normally even while a version preview is up', () async {
    final fileDatabase = OcptProjectDatabase.memory();
    addTearDown(fileDatabase.close);

    const locationId = 'location-1';
    await fileDatabase
        .into(fileDatabase.ocptLocationsTable)
        .insert(OcptLocationsTableCompanion.insert(id: locationId, name: 'Untitled'));

    final previewDatabase = OcptProjectDatabase.memory(isPreview: true);
    addTearDown(previewDatabase.close);
    await previewDatabase
        .into(previewDatabase.ocptLocationsTable)
        .insert(OcptLocationsTableCompanion.insert(id: locationId, name: 'Untitled (as of the preview)'));

    final model = OcptOpenProjectModel(
      path: '/tmp/project.ocpt',
      name: 'Project',
      primaryScreenplayId: 'screenplay-1',
      database: fileDatabase,
    ).previewing(
      previewDatabase: previewDatabase,
      version: OcptProjectVersion(
        id: 'version-1',
        name: 'Version 1',
        note: '',
        createdAt: DateTime.utc(2026),
        summary: OcptProjectVersionSummary.empty,
        isBase: false,
      ),
      pageSetup: const OcptPageSetup.standard(),
    );

    expect(model.isReadOnly, isTrue);
    expect(model.database.refusesUserWrite('probe'), isTrue);

    final changeset = const OcptChangeset(
      fieldStamps: [
        OcptFieldStamp(
          tableName: 'locations',
          rowId: locationId,
          columnName: 'name',
          value: 'Updated via merge',
          version: 1,
          deviceId: 'device-remote',
        ),
      ],
    );

    await const OcptMergeService().applyChangeset(fileDatabase: model.fileDatabase, changeset: changeset);

    Future<String> nameOn(OcptProjectDatabase database) async =>
        (await (database.select(database.ocptLocationsTable)..where((table) => table.id.equals(locationId))).getSingle()).name;

    expect(await nameOn(model.fileDatabase), 'Updated via merge');
    expect(await nameOn(model.database), 'Untitled (as of the preview)');
  });
}
