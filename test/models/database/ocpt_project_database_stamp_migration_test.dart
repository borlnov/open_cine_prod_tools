// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// Run the tests of the schema v5 migration, which renames the `labelText` stamps of the storyboard
/// annotations to `text`.
void main() {
  late Directory tempDir;
  late String filePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v4_to_v5_test_');
    filePath = p.join(tempDir.path, 'movie.ocpt');
  });

  tearDown(() => tempDir.delete(recursive: true));

  /// Create a current-schema file, put [stamps] in it as `(table, row, column, version, device)`
  /// rows, and set its schema back to 4.
  Future<void> writeV4File(List<(String, String, String, int, String)> stamps) async {
    final created = OcptProjectDatabase(File(filePath));
    await created.customSelect('SELECT 1').get();
    await created.close();

    final raw = sqlite3.open(filePath);
    for (final (table, row, column, version, device) in stamps) {
      raw.execute(
        'INSERT INTO row_field_versions (table_name, row_id, column_name, version, device_id) '
        'VALUES (?, ?, ?, ?, ?)',
        [table, row, column, version, device],
      );
    }
    raw
      ..execute('PRAGMA user_version = 4')
      ..dispose();
  }

  /// Read the stamps of the annotations as `row/column/version/device`, sorted.
  Future<List<String>> readAnnotationStamps() async {
    final database = OcptProjectDatabase(File(filePath));
    addTearDown(database.close);

    final rows = await database
        .customSelect(
          "SELECT row_id, column_name, version, device_id FROM row_field_versions "
          "WHERE table_name = 'storyboard_annotations' ORDER BY row_id, column_name",
        )
        .get();

    return [
      for (final row in rows)
        '${row.data['row_id']}/${row.data['column_name']}/${row.data['version']}/'
            '${row.data['device_id']}',
    ];
  }

  test('a v4 file holding a labelText stamp opens with it renamed to text', () async {
    await writeV4File([
      ('storyboard_annotations', 'a1', 'labelText', 3, 'dev-1'),
      ('storyboard_annotations', 'a1', 'x1', 3, 'dev-1'),
      ('locations', 'l1', 'labelText', 2, 'dev-1'),
    ]);

    expect(await readAnnotationStamps(), ['a1/text/3/dev-1', 'a1/x1/3/dev-1']);

    final database = OcptProjectDatabase(File(filePath));
    addTearDown(database.close);
    final other = await database
        .customSelect("SELECT column_name FROM row_field_versions WHERE table_name = 'locations'")
        .getSingle();
    expect(other.data['column_name'], 'labelText');
    final userVersion = await database.customSelect('PRAGMA user_version').getSingle();
    expect(userVersion.data['user_version'], 5);
  });

  test('a text stamp already there is kept when it is the higher one', () async {
    await writeV4File([
      ('storyboard_annotations', 'a1', 'labelText', 3, 'dev-1'),
      ('storyboard_annotations', 'a1', 'text', 4, 'dev-1'),
      ('storyboard_annotations', 'a2', 'labelText', 5, 'dev-1'),
      ('storyboard_annotations', 'a2', 'text', 5, 'dev-2'),
    ]);

    expect(await readAnnotationStamps(), ['a1/text/4/dev-1', 'a2/text/5/dev-2']);
  });

  test('a labelText stamp replaces the text stamp it beats', () async {
    await writeV4File([
      ('storyboard_annotations', 'a1', 'labelText', 6, 'dev-1'),
      ('storyboard_annotations', 'a1', 'text', 4, 'dev-2'),
      ('storyboard_annotations', 'a2', 'labelText', 5, 'dev-2'),
      ('storyboard_annotations', 'a2', 'text', 5, 'dev-1'),
    ]);

    expect(await readAnnotationStamps(), ['a1/text/6/dev-1', 'a2/text/5/dev-2']);
  });
}
