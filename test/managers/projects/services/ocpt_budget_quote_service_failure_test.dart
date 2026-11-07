// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account_seed.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_provision_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import '../../../ocpt_result_expectations.dart';

/// A quote service that answers a failure for one kind of line write without touching the
/// database, so that what a provisioning does with the failure of a call it makes is proven alone:
/// a real refusal also ends the transaction by itself.
class _RefusingLineService extends OcptBudgetQuoteService {
  /// Whether [createLine] answers a failure.
  final bool failsCreation;

  /// Whether [updateLine] answers a failure.
  final bool failsUpdate;

  /// Class constructor
  _RefusingLineService({required this.failsCreation, required this.failsUpdate})
    : super(logger: const SilentLogger(), deviceId: () async => "test-device");

  /// Answer a failure when told to, otherwise mint the line as the real service does.
  @override
  Future<OcptDatabaseResult<String>> createLine({
    required OcptProjectDatabase database,
    required String accountId,
    required String label,
    Value<String?> elementId = const Value.absent(),
    Value<int> quantityMilli = const Value.absent(),
    Value<String> unit = const Value.absent(),
    Value<int> unitAmountCents = const Value.absent(),
    Value<bool> isTaxInclusive = const Value.absent(),
    Value<int?> vatRateBasisPoints = const Value.absent(),
    Value<String?> provisionKey = const Value.absent(),
    Value<String?> provisionDigest = const Value.absent(),
    Value<String?> inKindResourceId = const Value.absent(),
  }) async {
    if (failsCreation) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "line creation intentionally failed for the test",
      );
    }

    return super.createLine(
      database: database,
      accountId: accountId,
      label: label,
      elementId: elementId,
      quantityMilli: quantityMilli,
      unit: unit,
      unitAmountCents: unitAmountCents,
      isTaxInclusive: isTaxInclusive,
      vatRateBasisPoints: vatRateBasisPoints,
      provisionKey: provisionKey,
      provisionDigest: provisionDigest,
      inKindResourceId: inKindResourceId,
    );
  }

  /// Answer a failure when told to, otherwise rewrite the line as the real service does.
  @override
  Future<OcptDatabaseOutcome> updateLine({
    required OcptProjectDatabase database,
    required String lineId,
    Value<String> label = const Value.absent(),
    Value<int> quantityMilli = const Value.absent(),
    Value<String> unit = const Value.absent(),
    Value<int> unitAmountCents = const Value.absent(),
    Value<bool> isTaxInclusive = const Value.absent(),
    Value<int?> vatRateBasisPoints = const Value.absent(),
    Value<String?> elementId = const Value.absent(),
    Value<String?> provisionKey = const Value.absent(),
    Value<String?> provisionDigest = const Value.absent(),
    Value<String> notes = const Value.absent(),
    Value<String?> inKindResourceId = const Value.absent(),
  }) async {
    if (failsUpdate) {
      return const OcptDatabaseOutcome(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "line update intentionally failed for the test",
      );
    }

    return super.updateLine(
      database: database,
      lineId: lineId,
      label: label,
      quantityMilli: quantityMilli,
      unit: unit,
      unitAmountCents: unitAmountCents,
      isTaxInclusive: isTaxInclusive,
      vatRateBasisPoints: vatRateBasisPoints,
      elementId: elementId,
      provisionKey: provisionKey,
      provisionDigest: provisionDigest,
      notes: notes,
      inKindResourceId: inKindResourceId,
    );
  }
}

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String firstAccount,
  String secondAccount,
  String firstLine,
  String secondLine,
});

/// Run the tests of what [OcptBudgetQuoteService] answers when the database fails or refuses.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptBudgetQuoteService(logger: const SilentLogger(), deviceId: testDeviceId);

  const tables = ["budget_postes", "budget_lines"];

  late OcptProjectDatabase database;
  late _Fixture rows;

  /// Insert two accounts and two lines of the first one through the service.
  Future<_Fixture> seed() async {
    final first = await service.createAccount(database: database, label: "Cast").valueOrFail;
    final second = await service.createAccount(database: database, label: "Crew").valueOrFail;
    return (
      firstAccount: first,
      secondAccount: second,
      firstLine: await service
          .createLine(database: database, accountId: first, label: "Lead")
          .valueOrFail,
      secondLine: await service
          .createLine(database: database, accountId: first, label: "Extras")
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

  /// A provisioning that mints one line and rewrites another.
  List<OcptBudgetProvisionEntry> provision(_Fixture r) => [
    const OcptBudgetProvisionEntry(
      kind: OcptBudgetProvisionKind.meal,
      lineId: null,
      label: "Meals",
      quantityMilli: 4000,
      unitAmountCents: 1200,
      outcome: OcptBudgetProvisionOutcome.created,
    ),
    OcptBudgetProvisionEntry(
      kind: OcptBudgetProvisionKind.snack,
      lineId: r.firstLine,
      label: "Buffet",
      quantityMilli: 2000,
      unitAmountCents: 500,
      outcome: OcptBudgetProvisionOutcome.updated,
    ),
  ];

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "createAccount": (r) async =>
        (await service.createAccount(database: database, label: "Art")).status,
    "updateAccount": (r) async => (await service.updateAccount(
      database: database,
      accountId: r.firstAccount,
      label: const Value("Changed"),
    )).status,
    "reorderAccount": (r) async => (await service.reorderAccount(
      database: database,
      accountId: r.secondAccount,
      newPosition: 0,
    )).status,
    "deleteAccount": (r) async =>
        (await service.deleteAccount(database: database, accountId: r.secondAccount)).status,
    "createLine": (r) async => (await service.createLine(
      database: database,
      accountId: r.firstAccount,
      label: "Stunts",
    )).status,
    "updateLine": (r) async => (await service.updateLine(
      database: database,
      lineId: r.firstLine,
      label: const Value("Changed"),
    )).status,
    "reorderLine": (r) async => (await service.reorderLine(
      database: database,
      lineId: r.secondLine,
      newPosition: 0,
    )).status,
    "deleteLine": (r) async =>
        (await service.deleteLine(database: database, lineId: r.firstLine)).status,
    "applyProvision": (r) async => (await service.applyProvision(
      database: database,
      accountId: r.firstAccount,
      entries: provision(r),
    )).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadAccounts": (r) async =>
        (await service.loadAccounts(database: database, seed: const [])).status,
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
          for (final verb in ["INSERT", "UPDATE"]) {
            await database.customStatement(
              "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
              "BEGIN SELECT RAISE(ABORT, 'refused'); END",
            );
          }
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
      final account = await service.createAccount(database: preview, label: "Art").maybeValueOrFail;
      final line = await service
          .createLine(database: preview, accountId: rows.firstAccount, label: "Stunts")
          .maybeValueOrFail;

      expect(account, isNull);
      expect(line, isNull);
    });

    test("a read is not refused", () async {
      expect(await service.loadAccounts(database: preview, seed: const []).valueOrFail, isEmpty);
    });

    test("a read seeds nothing", () async {
      final seeded = await service
          .loadAccounts(
            database: preview,
            seed: const [OcptBudgetAccountSeed(id: "s", code: "1", label: "One", simpleLabel: "1")],
          )
          .valueOrFail;

      expect(seeded, isEmpty);
    });
  });

  group("a provisioning is one transaction", () {
    test("a line that cannot be minted undoes the line rewritten before it", () async {
      final untouched = await snapshot();
      await database.customStatement(
        "CREATE TRIGGER refuse_insert_lines BEFORE INSERT ON budget_lines "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      final applied = await service.applyProvision(
        database: database,
        accountId: rows.firstAccount,
        entries: provision(rows).reversed.toList(),
      );

      expect(applied.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the rewritten line stayed rewritten");
    });

    test("a line that cannot be rewritten undoes the line minted before it", () async {
      final untouched = await snapshot();
      await database.customStatement(
        "CREATE TRIGGER refuse_update_lines BEFORE UPDATE ON budget_lines "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      final applied = await service.applyProvision(
        database: database,
        accountId: rows.firstAccount,
        entries: provision(rows),
      );

      expect(applied.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the minted line stayed minted");
    });

    test("a creation that answers a failure undoes the line rewritten before it", () async {
      final refusing = _RefusingLineService(failsCreation: true, failsUpdate: false);
      final untouched = await snapshot();

      final applied = await refusing.applyProvision(
        database: database,
        accountId: rows.firstAccount,
        entries: provision(rows).reversed.toList(),
      );

      expect(applied.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the rewritten line stayed rewritten");
    });

    test("an update that answers a failure undoes the line minted before it", () async {
      final refusing = _RefusingLineService(failsCreation: false, failsUpdate: true);
      final untouched = await snapshot();

      final applied = await refusing.applyProvision(
        database: database,
        accountId: rows.firstAccount,
        entries: provision(rows),
      );

      expect(applied.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the minted line stayed minted");
    });
  });
}
