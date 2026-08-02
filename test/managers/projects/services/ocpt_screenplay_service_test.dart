// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const screenplayId = "screenplay-1";
  const service = OcptScreenplayService(
    sceneIndexService: OcptSceneIndexService(),
    shotListService: OcptShotListService(),
    shotCoverageService: OcptShotCoverageService(),
  );

  late OcptProjectDatabase database;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<List<OcptScreenplaySnapshotRow>> readSnapshots() =>
      (database.select(database.ocptScreenplaySnapshotsTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

  /// Reads back every snapshot row, tombstones included, oldest first.
  Future<List<OcptScreenplaySnapshotRow>> readSnapshotsIncludingTombstones() => (database.select(
    database.ocptScreenplaySnapshotsTable,
  )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();

  test('loadScreenplayText returns the empty text of a freshly created screenplay', () async {
    final text = await service.loadScreenplayText(database: database, screenplayId: screenplayId);
    expect(text, "");
  });

  test('saveScreenplayText updates the stored text and reconciles the scene index', () async {
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: "INT. HOUSE - DAY\n\nAction.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );

    final text = await service.loadScreenplayText(database: database, screenplayId: screenplayId);
    expect(text, "INT. HOUSE - DAY\n\nAction.\n");

    final scenes = await database.select(database.ocptScenesTable).get();
    expect(scenes, hasLength(1));
    expect(scenes.single.heading, "INT. HOUSE - DAY");
  });

  test('saveScreenplayText snapshots the text as it was before the overwrite', () async {
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: "first version",
      snapshotReason: OcptSnapshotReason.manual,
    );
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: "second version",
      snapshotReason: OcptSnapshotReason.timer,
    );

    final snapshots = await readSnapshots();

    // The first save snapshots the initial empty text; the second save snapshots "first version".
    expect(snapshots, hasLength(2));
    expect(snapshots[0].fountainText, "");
    expect(snapshots[0].reason, OcptSnapshotReason.manual);
    expect(snapshots[1].fountainText, "first version");
    expect(snapshots[1].reason, OcptSnapshotReason.timer);
  });

  test('snapshotOnProjectOpen takes a snapshot of the current text, tagged "open"', () async {
    await service.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: "current text",
      snapshotReason: OcptSnapshotReason.manual,
    );

    await service.snapshotOnProjectOpen(database: database, screenplayId: screenplayId);

    final snapshots = await readSnapshots();
    expect(snapshots.last.fountainText, "current text");
    expect(snapshots.last.reason, OcptSnapshotReason.open);
  });

  test('snapshots beyond the 30 most recent are pruned after every save', () async {
    for (var i = 0; i < 35; i++) {
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: "version $i",
        snapshotReason: OcptSnapshotReason.timer,
      );
    }

    final snapshots = await readSnapshots();

    expect(snapshots, hasLength(OcptScreenplayService.maxSnapshotsPerScreenplay));
    // The 35 saves snapshot the *previous* text each time: "version 0".."version 33" (34 values,
    // since the very first save snapshots the initial empty text). Only the 30 most recent survive.
    expect(snapshots.first.fountainText, "version 4");
    expect(snapshots.last.fountainText, "version 33");
  });

  test('a pruned snapshot is a tombstone with its text dropped, not a deleted row', () async {
    for (var i = 0; i < 35; i++) {
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: "version $i",
        snapshotReason: OcptSnapshotReason.timer,
      );
    }

    final everyRow = await readSnapshotsIncludingTombstones();
    final pruned = everyRow.where((row) => row.isDeleted).toList(growable: false);

    // 35 saves wrote 35 snapshot rows; the 30 most recent stayed live.
    expect(everyRow, hasLength(35));
    expect(pruned, hasLength(35 - OcptScreenplayService.maxSnapshotsPerScreenplay));
    // Pruning exists to bound the file's size, so a pruned row keeps nothing but its marker.
    expect(pruned.every((row) => row.fountainText.isEmpty), isTrue);
  });

  test('a write handed the read-only database of a previewed version is refused', () async {
    final preview = OcptProjectDatabase.memory(isPreview: true);
    addTearDown(preview.close);

    await preview
        .into(preview.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            fountainText: const Value("INT. HOUSE - DAY"),
            updatedAt: DateTime.now(),
          ),
        );

    await service.saveScreenplayText(
      database: preview,
      screenplayId: screenplayId,
      fountainText: "EXT. STREET - NIGHT",
      snapshotReason: OcptSnapshotReason.manual,
    );
    await service.snapshotOnProjectOpen(database: preview, screenplayId: screenplayId);

    // The user may not edit a version they are only reading, and the UI having hidden the
    // affordance isn't what makes that true: the service refuses the write itself.
    expect(
      await service.loadScreenplayText(database: preview, screenplayId: screenplayId),
      "INT. HOUSE - DAY",
    );
    expect(await preview.select(preview.ocptScreenplaySnapshotsTable).get(), isEmpty);
  });
}
