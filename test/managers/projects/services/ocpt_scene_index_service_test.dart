// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// Parses [source] with the real Fountain parser, so reconciliation is tested against realistic
/// documents rather than hand-built ones.
FountainDocument _parse(String source) => const FountainParser().parse(source);

void main() {
  const service = OcptSceneIndexService();
  const screenplayId = "screenplay-1";

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

  /// Reads back every live scene of [screenplayId], ordered by position: tombstoned rows are
  /// filtered out, exactly as every reader of the index does.
  Future<List<OcptSceneRow>> readScenes() =>
      (database.select(database.ocptScenesTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.position)]))
          .get();

  /// Reads back every scene row of [screenplayId], tombstones included.
  Future<List<OcptSceneRow>> readScenesIncludingTombstones() => (database.select(
    database.ocptScenesTable,
  )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();

  test('reconciling an empty index inserts one row per scene heading, in order', () async {
    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
'''),
    );

    final scenes = await readScenes();

    expect(scenes, hasLength(2));
    expect(scenes[0].heading, "INT. HOUSE - DAY");
    expect(scenes[0].position, 0);
    expect(scenes[1].heading, "EXT. STREET - NIGHT");
    expect(scenes[1].position, 1);
    expect(scenes[0].id, isNot(scenes[1].id));
  });

  test("inserting a scene above existing ones keeps the existing scenes' ids stable", () async {
    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
'''),
    );

    final before = await readScenes();
    final houseId = before.firstWhere((row) => row.heading == "INT. HOUSE - DAY").id;
    final streetId = before.firstWhere((row) => row.heading == "EXT. STREET - NIGHT").id;

    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. GARAGE - DAY

Action.

INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
'''),
    );

    final after = await readScenes();

    expect(after, hasLength(3));
    expect(after[0].heading, "INT. GARAGE - DAY");
    expect(after[0].id, isNot(houseId));
    expect(after[0].id, isNot(streetId));
    expect(after[1].heading, "INT. HOUSE - DAY");
    expect(after[1].id, houseId);
    expect(after[2].heading, "EXT. STREET - NIGHT");
    expect(after[2].id, streetId);
  });

  test('renaming a scene heading that carries an explicit number: the id follows the number', () async {
    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - DAY #1#

Action.

EXT. STREET - NIGHT #2#

Action.
'''),
    );

    final before = await readScenes();
    final houseId = before.firstWhere((row) => row.sceneNumber == "1").id;

    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - MORNING #1#

Action.

EXT. STREET - NIGHT #2#

Action.
'''),
    );

    final after = await readScenes();
    final renamed = after.firstWhere((row) => row.sceneNumber == "1");

    expect(renamed.id, houseId);
    expect(renamed.heading, "INT. HOUSE - MORNING");
  });

  test('renumbering a scene whose heading text is unchanged: the id follows the heading text', () async {
    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - DAY #1#

Action.

EXT. STREET - NIGHT #2#

Action.
'''),
    );

    final before = await readScenes();
    final houseId = before.firstWhere((row) => row.heading == "INT. HOUSE - DAY").id;

    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - DAY #1A#

Action.

EXT. STREET - NIGHT #2#

Action.
'''),
    );

    final after = await readScenes();
    final renumbered = after.firstWhere((row) => row.heading == "INT. HOUSE - DAY");

    expect(renumbered.id, houseId);
    expect(renumbered.sceneNumber, "1A");
  });

  test("reordering scenes keeps every scene's id, only their position changes", () async {
    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
'''),
    );

    final before = await readScenes();
    final houseId = before.firstWhere((row) => row.heading == "INT. HOUSE - DAY").id;
    final streetId = before.firstWhere((row) => row.heading == "EXT. STREET - NIGHT").id;

    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
EXT. STREET - NIGHT

Action.

INT. HOUSE - DAY

Action.
'''),
    );

    final after = await readScenes();

    expect(after, hasLength(2));
    expect(after[0].id, streetId);
    expect(after[0].position, 0);
    expect(after[1].id, houseId);
    expect(after[1].position, 1);
  });

  test('deleting a scene removes only its row', () async {
    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
'''),
    );

    final before = await readScenes();
    final houseId = before.firstWhere((row) => row.heading == "INT. HOUSE - DAY").id;

    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - DAY

Action.
'''),
    );

    final after = await readScenes();

    expect(after, hasLength(1));
    expect(after.single.id, houseId);
    expect(after.single.heading, "INT. HOUSE - DAY");

    // The deleted scene is a tombstone, not a removal: its row is still there, flagged, so a
    // replica that never saw the deletion can still learn about it.
    final everyRow = await readScenesIncludingTombstones();
    expect(everyRow, hasLength(2));
    expect(
      everyRow.where((row) => row.isDeleted).map((row) => row.heading),
      ["EXT. STREET - NIGHT"],
    );
  });

  test('a plain rename (no scene number) at the same position keeps the id, by relative order', () async {
    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
'''),
    );

    final before = await readScenes();
    final houseId = before.firstWhere((row) => row.heading == "INT. HOUSE - DAY").id;
    final streetId = before.firstWhere((row) => row.heading == "EXT. STREET - NIGHT").id;

    await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse('''
INT. CABIN - DAY

Action.

EXT. STREET - NIGHT

Action.
'''),
    );

    final after = await readScenes();

    expect(after, hasLength(2));
    expect(after[0].heading, "INT. CABIN - DAY");
    expect(after[0].id, houseId);
    expect(after[1].heading, "EXT. STREET - NIGHT");
    expect(after[1].id, streetId);
  });

  test('charStart/charEnd span from a scene heading to the next one, or the document end', () async {
    const source = '''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
''';
    final document = _parse(source);

    await service.reconcile(database: database, screenplayId: screenplayId, document: document);

    final scenes = await readScenes();
    final headings = document.scenes;

    expect(scenes[0].charStart, headings[0].sourceRange.startOffset);
    expect(scenes[0].charEnd, headings[1].sourceRange.startOffset);
    expect(scenes[1].charStart, headings[1].sourceRange.startOffset);
    expect(scenes[1].charEnd, document.sourceText.length);
  });
}
