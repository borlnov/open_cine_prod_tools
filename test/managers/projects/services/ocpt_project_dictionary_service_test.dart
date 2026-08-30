// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_dictionary_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptProjectDictionaryService(deviceId: testDeviceId);

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every `project_dictionary_words` row the project currently holds, tombstones included.
  Future<List<OcptProjectDictionaryWordRow>> readAllRows() =>
      database.select(database.ocptProjectDictionaryWordsTable).get();

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>` — the same
  /// shape `OcptShotListService`'s own stamping tests read `row_field_versions` back through.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

  group("learnWord", () {
    test("inserts one live row", () async {
      await service.learnWord(database: database, word: "Séquence");

      final rows = await readAllRows();
      expect(rows, hasLength(1));
      expect(rows.single.word, "Séquence");
      expect(rows.single.isDeleted, isFalse);
    });

    test("learning the same word again, whatever the case, inserts nothing", () async {
      await service.learnWord(database: database, word: "Marie");
      await service.learnWord(database: database, word: "marie");
      await service.learnWord(database: database, word: "MARIE");

      final rows = await readAllRows();
      expect(rows, hasLength(1));
      expect(rows.single.word, "Marie");
    });

    test("a blank or whitespace-only word is refused", () async {
      await service.learnWord(database: database, word: "");
      await service.learnWord(database: database, word: "   ");

      expect(await readAllRows(), isEmpty);
    });

    test("trims the word before storing it", () async {
      await service.learnWord(database: database, word: "  Clara  ");

      final rows = await readAllRows();
      expect(rows.single.word, "Clara");
    });

    test("re-learning a tombstoned word revives that very row, spelled as freshly typed", () async {
      await service.learnWord(database: database, word: "marc");
      final firstId = (await readAllRows()).single.id;
      await service.unlearnWord(database: database, word: "marc");

      await service.learnWord(database: database, word: "Marc");

      final rows = await readAllRows();
      expect(rows, hasLength(1), reason: "no second row for the same word");
      expect(rows.single.id, firstId, reason: "the very same row, not a fresh one");
      expect(rows.single.word, "Marc");
      expect(rows.single.isDeleted, isFalse);
    });

    test("is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      await service.learnWord(database: preview, word: "Clara");

      expect(await preview.select(preview.ocptProjectDictionaryWordsTable).get(), isEmpty);

      await preview.close();
    });
  });

  group("unlearnWord", () {
    test("tombstones the row rather than deleting it", () async {
      await service.learnWord(database: database, word: "Julien");

      await service.unlearnWord(database: database, word: "Julien");

      final rows = await readAllRows();
      expect(rows, hasLength(1), reason: "the row is still physically there");
      expect(rows.single.isDeleted, isTrue);
    });

    test("matches case-insensitively", () async {
      await service.learnWord(database: database, word: "Julien");

      await service.unlearnWord(database: database, word: "JULIEN");

      expect((await readAllRows()).single.isDeleted, isTrue);
    });

    test("loadWords filters a tombstoned word back out", () async {
      await service.learnWord(database: database, word: "Julien");
      await service.learnWord(database: database, word: "Clara");

      await service.unlearnWord(database: database, word: "Julien");

      expect(await service.loadWords(database: database), ["Clara"]);
    });

    test("is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      await preview.into(preview.ocptProjectDictionaryWordsTable).insert(
        OcptProjectDictionaryWordsTableCompanion.insert(id: "word-1", word: "Clara"),
      );

      await service.unlearnWord(database: preview, word: "Clara");

      final row = await (preview.select(
        preview.ocptProjectDictionaryWordsTable,
      )..where((table) => table.id.equals("word-1"))).getSingle();
      expect(row.isDeleted, isFalse);

      await preview.close();
    });
  });

  group("loadWords", () {
    test("returns the live words, sorted case-insensitively", () async {
      await service.learnWord(database: database, word: "zorro");
      await service.learnWord(database: database, word: "Alice");
      await service.learnWord(database: database, word: "bob");

      expect(await service.loadWords(database: database), ["Alice", "bob", "zorro"]);
    });

    test("returns an empty list for a project that has taught nothing yet", () async {
      expect(await service.loadWords(database: database), isEmpty);
    });
  });

  group("stamping", () {
    test("learnWord stamps every column of a freshly inserted word", () async {
      await service.learnWord(database: database, word: "Séquence");
      final id = (await readAllRows()).single.id;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptProjectDictionaryWordsTable,
      )..where((table) => table.id.equals(id))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("project_dictionary_words/$id/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        final stamp = ownStamps["project_dictionary_words/$id/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("re-learning a tombstoned word stamps only the columns that actually changed", () async {
      await service.learnWord(database: database, word: "marc");
      final id = (await readAllRows()).single.id;
      await service.unlearnWord(database: database, word: "marc");
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.learnWord(database: database, word: "Marc");

      final stamps = await readStamps();
      final ownKeys = stamps.keys
          .where((key) => key.startsWith("project_dictionary_words/$id/"))
          .toSet();
      expect(ownKeys, {
        "project_dictionary_words/$id/word",
        "project_dictionary_words/$id/isDeleted",
      });
    });

    test("unlearnWord stamps isDeleted on the tombstoned word", () async {
      await service.learnWord(database: database, word: "Julien");
      final id = (await readAllRows()).single.id;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.unlearnWord(database: database, word: "Julien");

      final stamps = await readStamps();
      final ownKeys = stamps.keys
          .where((key) => key.startsWith("project_dictionary_words/$id/"))
          .toSet();
      expect(ownKeys, {"project_dictionary_words/$id/isDeleted"});
    });
  });
}
