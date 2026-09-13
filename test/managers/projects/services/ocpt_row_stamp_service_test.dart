// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

void main() {
  const deviceId = "device-1";

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>`.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp
        in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

  /// Inserts and returns a bare person row, [id] apart every column at its schema default.
  Future<OcptPersonRow> insertPerson(String id) async {
    await database
        .into(database.ocptPeopleTable)
        .insert(OcptPeopleTableCompanion.insert(id: id));
    return (database.select(
      database.ocptPeopleTable,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  /// Inserts and returns a bare location row, [id] apart every column at its schema default.
  Future<OcptLocationRow> insertLocation(String id) async {
    await database
        .into(database.ocptLocationsTable)
        .insert(OcptLocationsTableCompanion.insert(id: id, name: "Untitled"));
    return (database.select(
      database.ocptLocationsTable,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  test(
    "a device's stamps strictly increase transaction over transaction, whatever row, "
    "column or table the next one touches",
    () async {
      final person = await insertPerson("person-1");
      final location = await insertLocation("location-1");

      final firstTransaction = await OcptRowStampService.seed(
        database: database,
        deviceId: deviceId,
      );
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPeopleTable,
        rowId: person.id,
        current: person,
        next: person.copyWith(firstName: "Clara"),
        stamps: firstTransaction,
      );
      await firstTransaction.flush(database);

      final secondTransaction = await OcptRowStampService.seed(
        database: database,
        deviceId: deviceId,
      );
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptLocationsTable,
        rowId: location.id,
        current: location,
        next: location.copyWith(name: "Exterior"),
        stamps: secondTransaction,
      );
      await secondTransaction.flush(database);

      final stamps = await readStamps();
      final firstVersion = stamps["people/person-1/firstName"]!.version;
      final secondVersion = stamps["locations/location-1/name"]!.version;

      expect(secondVersion, greaterThan(firstVersion));
    },
  );

  test(
    "a single transaction stamps every column it touches with one shared version, "
    "strictly above each column's own prior version",
    () async {
      final person = await insertPerson("person-1");
      final location = await insertLocation("location-1");

      // As if these two columns had already been stamped, at different versions, by an earlier
      // transaction or a merged-in edit.
      await database
          .into(database.ocptRowFieldVersionsTable)
          .insert(
            OcptRowFieldVersionsTableCompanion.insert(
              targetTableName: "people",
              rowId: person.id,
              columnName: "firstName",
              version: 3,
              deviceId: "device-0",
            ),
          );
      await database
          .into(database.ocptRowFieldVersionsTable)
          .insert(
            OcptRowFieldVersionsTableCompanion.insert(
              targetTableName: "locations",
              rowId: location.id,
              columnName: "name",
              version: 5,
              deviceId: "device-0",
            ),
          );

      final transaction = await OcptRowStampService.seed(
        database: database,
        deviceId: deviceId,
      );
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPeopleTable,
        rowId: person.id,
        current: person,
        next: person.copyWith(firstName: "Clara"),
        stamps: transaction,
      );
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptLocationsTable,
        rowId: location.id,
        current: location,
        next: location.copyWith(name: "Exterior"),
        stamps: transaction,
      );
      await transaction.flush(database);

      final stamps = await readStamps();
      final personVersion = stamps["people/person-1/firstName"]!.version;
      final locationVersion = stamps["locations/location-1/name"]!.version;

      expect(personVersion, locationVersion);
      expect(personVersion, greaterThan(3));
      expect(locationVersion, greaterThan(5));
    },
  );
}
