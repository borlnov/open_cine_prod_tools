// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of what [OcptSceneIndexService] answers when the database fails.
void main() {
  const service = OcptSceneIndexService(logger: SilentLogger());
  const screenplayId = "screenplay-1";

  /// The text the fixture is first reconciled against.
  const firstText = "INT. HOUSE - DAY\n\nAction.\n\nEXT. STREET - NIGHT\n\nAction.\n";

  /// A text that changes the scene index of [firstText]: one scene gone, one renamed, one new.
  const nextText =
      "INT. CABIN - DAY\n\nAction.\n\nINT. BARN - DAY\n\nAction.\n\nEXT. LAKE - DAY\n\nAction.\n";

  late OcptProjectDatabase database;

  FountainDocument parse(String source) => const FountainParser().parse(source);

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
    await service
        .reconcile(database: database, screenplayId: screenplayId, document: parse(firstText))
        .okOrFail;
  });

  tearDown(() async {
    await database.close();
  });

  /// Every row of the tables the service writes, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in ["scenes", "screenplays"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  /// Every call of the service, with an input that changes a row.
  final calls = <String, Future<MixinResultStatus> Function()>{
    "reconcile": () async => (await service.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: parse(nextText),
    )).status,
    "tombstoneScenesOfScreenplay": () async => (await service.tombstoneScenesOfScreenplay(
      database: database,
      screenplayId: screenplayId,
    )).status,
  };

  group("every write answers a database error when the database refuses it", () {
    for (final entry in calls.entries) {
      test("${entry.key} writes nothing", () async {
        final untouched = await snapshot();
        for (final verb in ["INSERT", "UPDATE"]) {
          await database.customStatement(
            "CREATE TRIGGER refuse_${verb.toLowerCase()}_scenes BEFORE $verb ON scenes "
            "BEGIN SELECT RAISE(ABORT, 'refused'); END",
          );
        }

        expect(await entry.value(), OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched, reason: "the failed call rolled back whole");

        for (final verb in ["insert", "update"]) {
          await database.customStatement("DROP TRIGGER refuse_${verb}_scenes");
        }

        expect(await entry.value(), OcptDatabaseStatus.ok, reason: "the same call goes through");
        expect(await snapshot(), isNot(untouched), reason: "the input changes a row");
      });
    }
  });

  group("every method answers a database error when its table is gone", () {
    for (final entry in calls.entries) {
      test("${entry.key} answers a database error", () async {
        await database.customStatement("ALTER TABLE scenes RENAME TO scenes_gone");

        expect(await entry.value(), OcptDatabaseStatus.databaseError);
      });
    }
  });

  group("reconcile hands the scenes it is about to tombstone to its hook", () {
    test("a hook that fails rolls back what the call and the hook wrote", () async {
      final untouched = await snapshot();

      final result = await service.reconcile(
        database: database,
        screenplayId: screenplayId,
        document: parse("INT. CABIN - DAY\n\nAction.\n"),
        onScenesDeleted: (scenes) async {
          await database.customStatement("UPDATE screenplays SET title = 'Written by the hook'");
          throw StateError("The hook failed.");
        },
      );

      expect(result.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "neither the hook's write nor the scenes stay");
    });

    test("a hook is not called when no scene is about to be tombstoned", () async {
      var called = false;

      await service
          .reconcile(
            database: database,
            screenplayId: screenplayId,
            document: parse(firstText),
            onScenesDeleted: (scenes) async => called = true,
          )
          .okOrFail;

      expect(called, isFalse);
    });
  });

  group("tombstoneScenesOfScreenplay", () {
    test("answers the ids of the live scenes it tombstoned", () async {
      final live = await database.select(database.ocptScenesTable).get();

      final ids = await service
          .tombstoneScenesOfScreenplay(database: database, screenplayId: screenplayId)
          .valueOrFail;

      expect(ids, unorderedEquals([for (final row in live) row.id]));
    });

    test("answers an empty list for a screenplay with no live scene", () async {
      expect(
        await service
            .tombstoneScenesOfScreenplay(database: database, screenplayId: "other")
            .valueOrFail,
        isEmpty,
      );
    });
  });
}
