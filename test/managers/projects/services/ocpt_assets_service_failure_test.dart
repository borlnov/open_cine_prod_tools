// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of what [OcptAssetsService] answers when the database fails or refuses.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId);

  late OcptProjectDatabase database;
  late String assetId;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    assetId = await service.insertAsset(
      database: database,
      kind: OcptAssetKind.document,
      path: "/permits/granted.pdf",
      stamps: null,
    );
  });

  tearDown(() async {
    await database.close();
  });

  /// Every write of the service, with an input that changes the row.
  final writes = <String, Future<MixinResultStatus> Function(OcptProjectDatabase, String)>{
    "removeAsset": (db, id) async => (await service.removeAsset(database: db, assetId: id)).status,
    "updateAssetValidity": (db, id) async => (await service.updateAssetValidity(
      database: db,
      assetId: id,
      validFrom: Value(DateTime.utc(2026, 3, 10)),
    )).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot(OcptProjectDatabase db) async {
    final buffer = StringBuffer();
    for (final table in ["assets", "row_field_versions"]) {
      final result = await db.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  group("every write answers a database error when the database refuses it", () {
    for (final entry in writes.entries) {
      test("${entry.key} writes nothing", () async {
        // The call must change something when nothing is wrong, or the refusal proves nothing.
        final before = await snapshot(database);
        expect(await entry.value(database, assetId), OcptDatabaseStatus.ok);
        expect(await snapshot(database), isNot(before), reason: "the input changes no row");
        await database.close();
        database = OcptProjectDatabase.memory();
        assetId = await service.insertAsset(
          database: database,
          kind: OcptAssetKind.document,
          path: "/permits/granted.pdf",
          stamps: null,
        );

        final untouched = await snapshot(database);
        await database.customStatement(
          "CREATE TRIGGER refuse_update_assets BEFORE UPDATE ON assets "
          "BEGIN SELECT RAISE(ABORT, 'refused'); END",
        );

        final status = await entry.value(database, assetId);

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(database), untouched, reason: "the failed call rolled back whole");
      });
    }
  });

  group("every write answers a database error when its table is gone", () {
    for (final entry in writes.entries) {
      test("${entry.key} answers a database error", () async {
        await database.customStatement("ALTER TABLE assets RENAME TO assets_gone");

        expect(await entry.value(database, assetId), OcptDatabaseStatus.databaseError);
      });
    }
  });

  group("on the database of a version being previewed", () {
    test("every write is refused as a call that went well, and writes nothing", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      for (final entry in writes.entries) {
        expect(await entry.value(preview, "missing"), OcptDatabaseStatus.ok, reason: entry.key);
      }

      expect(await preview.customSelect("SELECT * FROM assets").get(), isEmpty);
    });
  });

  group("a row that is not there", () {
    test("removeAsset and updateAssetValidity write nothing and answer ok", () async {
      final before = await snapshot(database);

      await service.removeAsset(database: database, assetId: "missing").okOrFail;
      await service
          .updateAssetValidity(
            database: database,
            assetId: "missing",
            validFrom: Value(DateTime.utc(2026, 3, 10)),
          )
          .okOrFail;

      expect(await snapshot(database), before);
    });
  });
}
