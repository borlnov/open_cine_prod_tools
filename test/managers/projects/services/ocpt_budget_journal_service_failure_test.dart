// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import '../../../ocpt_result_expectations.dart';

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String firstEntry,
  String secondEntry,
  String firstCommitment,
  String secondCommitment,
});

/// Run the tests of what [OcptBudgetJournalService] answers when the database fails or refuses.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptBudgetJournalService(
    logger: const SilentLogger(),
    assetsService: OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId),
    deviceId: testDeviceId,
  );

  final quoteService = OcptBudgetQuoteService(logger: const SilentLogger(), deviceId: testDeviceId);

  const tables = ["budget_entries", "budget_commitments", "assets"];

  late OcptProjectDatabase database;
  late _Fixture rows;
  late String accountId;

  /// Insert two entries, the first with a voucher, and two commitments through the service.
  Future<_Fixture> seed() async {
    accountId = await quoteService.createAccount(database: database, label: "Crew").valueOrFail;
    final first = await service
        .createEntry(database: database, date: DateTime(2026), label: "Rent")
        .valueOrFail;
    final second = await service
        .createEntry(database: database, date: DateTime(2026, 2), label: "Fuel")
        .valueOrFail;
    await service
        .setEntryReceipt(database: database, entryId: first, path: "/receipts/rent.pdf")
        .valueOrFail;
    return (
      firstEntry: first,
      secondEntry: second,
      firstCommitment: await service
          .createCommitment(database: database, accountId: accountId, label: "Van")
          .valueOrFail,
      secondCommitment: await service
          .createCommitment(database: database, accountId: accountId, label: "Lights")
          .valueOrFail,
    );
  }

  setUp(() async {
    database = OcptProjectDatabase.memory();
    rows = await seed();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "createEntry": (r) async => (await service.createEntry(
      database: database,
      date: DateTime(2026, 3),
      label: "Food",
    )).status,
    "updateEntry": (r) async => (await service.updateEntry(
      database: database,
      entryId: r.firstEntry,
      label: const Value("Changed"),
    )).status,
    "reorderEntry": (r) async => (await service.reorderEntry(
      database: database,
      entryId: r.secondEntry,
      newPosition: 0,
    )).status,
    "deleteEntry": (r) async =>
        (await service.deleteEntry(database: database, entryId: r.firstEntry)).status,
    "setEntryReceipt": (r) async => (await service.setEntryReceipt(
      database: database,
      entryId: r.secondEntry,
      path: "/receipts/fuel.pdf",
    )).status,
    "clearEntryReceipt": (r) async =>
        (await service.clearEntryReceipt(database: database, entryId: r.firstEntry)).status,
    "createCommitment": (r) async => (await service.createCommitment(
      database: database,
      accountId: accountId,
      label: "Props",
    )).status,
    "updateCommitment": (r) async => (await service.updateCommitment(
      database: database,
      commitmentId: r.firstCommitment,
      label: const Value("Changed"),
    )).status,
    "reorderCommitment": (r) async => (await service.reorderCommitment(
      database: database,
      commitmentId: r.secondCommitment,
      newPosition: 0,
    )).status,
    "deleteCommitment": (r) async => (await service.deleteCommitment(
      database: database,
      commitmentId: r.firstCommitment,
    )).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadEntries": (r) async => (await service.loadEntries(database: database)).status,
    "loadCommitments": (r) async => (await service.loadCommitments(database: database)).status,
    "loadReceipts": (r) async => (await service.loadReceipts(database: database)).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in [...tables, "row_field_versions"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  /// Refuse the [verbs] on [table].
  Future<void> refuse(String table, List<String> verbs) async {
    for (final verb in verbs) {
      await database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );
    }
  }

  group("every write answers a database error when the database refuses it", () {
    for (final entry in writes.entries) {
      test("${entry.key} writes nothing", () async {
        // The call must change something when nothing is wrong, or the refusal proves nothing.
        final before = await snapshot();
        expect(await entry.value(rows), OcptDatabaseStatus.ok);
        expect(await snapshot(), isNot(before), reason: "the input changes no row");
        await database.close();
        database = OcptProjectDatabase.memory();
        rows = await seed();

        final untouched = await snapshot();
        for (final table in tables) {
          await refuse(table, ["INSERT", "UPDATE"]);
        }

        final status = await entry.value(rows);

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched, reason: "the failed call rolled back whole");
      });
    }
  });

  group("every method answers a database error when its tables are gone", () {
    for (final entry in {...writes, ...reads}.entries) {
      test("${entry.key} answers a database error", () async {
        for (final table in tables) {
          await database.customStatement("ALTER TABLE $table RENAME TO ${table}_gone");
        }

        expect(await entry.value(rows), OcptDatabaseStatus.databaseError);
      });
    }
  });

  group("on the database of a version being previewed", () {
    late OcptProjectDatabase preview;

    setUp(() => preview = OcptProjectDatabase.memory(isPreview: true));

    tearDown(() => preview.close());

    test("every write is refused as a call that went well, and writes nothing", () async {
      final previous = database;
      database = preview;
      final untouched = await snapshot();

      for (final entry in writes.entries) {
        expect(await entry.value(rows), OcptDatabaseStatus.ok, reason: entry.key);
      }

      expect(await snapshot(), untouched);
      database = previous;
    });

    test("a write that answers an id answers none", () async {
      final entry = await service
          .createEntry(database: preview, date: DateTime(2026), label: "Food")
          .maybeValueOrFail;
      final commitment = await service
          .createCommitment(database: preview, accountId: accountId, label: "Props")
          .maybeValueOrFail;
      final receipt = await service
          .setEntryReceipt(database: preview, entryId: rows.firstEntry, path: "/a.pdf")
          .maybeValueOrFail;

      expect(entry, isNull);
      expect(commitment, isNull);
      expect(receipt, isNull);
    });

    test("a read is not refused", () async {
      expect(await service.loadEntries(database: preview).valueOrFail, isEmpty);
      expect(await service.loadCommitments(database: preview).valueOrFail, isEmpty);
      expect(await service.loadReceipts(database: preview).valueOrFail, isEmpty);
    });
  });

  group("a write that touches two tables is one transaction", () {
    test("an entry whose voucher cannot be tombstoned stays live", () async {
      final untouched = await snapshot();
      await refuse("assets", ["UPDATE"]);

      final deleted = await service.deleteEntry(database: database, entryId: rows.firstEntry);

      expect(deleted.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    });

    test("a voucher stays live when the entry cannot be tombstoned", () async {
      final untouched = await snapshot();
      await refuse("budget_entries", ["UPDATE"]);

      final deleted = await service.deleteEntry(database: database, entryId: rows.firstEntry);

      expect(deleted.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the voucher stayed tombstoned");
    });

    test("a voucher that cannot be minted leaves the former one referenced", () async {
      final untouched = await snapshot();
      await refuse("assets", ["INSERT"]);

      final set = await service.setEntryReceipt(
        database: database,
        entryId: rows.firstEntry,
        path: "/receipts/other.pdf",
      );

      expect(set.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the former voucher stayed tombstoned");
    });
  });
}
