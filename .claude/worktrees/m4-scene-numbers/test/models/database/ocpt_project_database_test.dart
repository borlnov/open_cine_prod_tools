// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

void main() {
  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  test('project_info: a row can be inserted and read back, with its default id', () async {
    final now = DateTime.now();

    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: "My Movie",
            createdAt: now,
            appVersionAtCreation: "0.1.0",
            pageFormat: OcptPageFormat.a4,
          ),
        );

    final row = await database.select(database.ocptProjectInfoTable).getSingle();

    expect(row.id, 1);
    expect(row.name, "My Movie");
    expect(row.appVersionAtCreation, "0.1.0");
    expect(row.pageFormat, OcptPageFormat.a4);
    expect(row.settingsJson, isNull);
  });

  test('screenplays: a row can be inserted and read back, with its default text', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );

    final row = await database.select(database.ocptScreenplaysTable).getSingle();

    expect(row.id, "s1");
    expect(row.title, "Draft");
    expect(row.fountainText, "");
  });

  test('screenplay_snapshots: a row can be inserted and read back', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );

    await database
        .into(database.ocptScreenplaySnapshotsTable)
        .insert(
          OcptScreenplaySnapshotsTableCompanion.insert(
            id: "snap1",
            screenplayId: "s1",
            createdAt: DateTime.now(),
            reason: OcptSnapshotReason.manual,
            fountainText: "INT. HOUSE - DAY",
          ),
        );

    final row = await database.select(database.ocptScreenplaySnapshotsTable).getSingle();

    expect(row.screenplayId, "s1");
    expect(row.reason, OcptSnapshotReason.manual);
    expect(row.fountainText, "INT. HOUSE - DAY");
  });

  test('scenes: a row can be inserted and read back, with a null scene number', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );

    await database
        .into(database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene1",
            screenplayId: "s1",
            position: 0,
            heading: "INT. HOUSE - DAY",
            charStart: 0,
            charEnd: 20,
          ),
        );

    final row = await database.select(database.ocptScenesTable).getSingle();

    expect(row.heading, "INT. HOUSE - DAY");
    expect(row.sceneNumber, isNull);
    expect(row.charStart, 0);
    expect(row.charEnd, 20);
  });
}
