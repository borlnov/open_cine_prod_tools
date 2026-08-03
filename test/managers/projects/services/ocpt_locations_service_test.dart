// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const locationsService = OcptLocationsService();

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every live location row, in `sortKey` order.
  Future<List<OcptLocationRow>> readLocations() =>
      (database.select(database.ocptLocationsTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// The location row [id], tombstoned or not.
  Future<OcptLocationRow> readLocation(String id) => (database.select(
    database.ocptLocationsTable,
  )..where((row) => row.id.equals(id))).getSingle();

  group("locations CRUD and ordering", () {
    test("createLocation appends at the end and loadLocations reads it back", () async {
      final firstId = (await locationsService.createLocation(
        database: database,
        name: "La maison des Pains",
      ))!;
      final secondId = (await locationsService.createLocation(
        database: database,
        name: "Le hangar",
      ))!;

      final locations = await locationsService.loadLocations(database: database);
      expect(locations.map((location) => location.id), [firstId, secondId]);
      expect(locations.map((location) => location.name), ["La maison des Pains", "Le hangar"]);
    });

    test("createLocation in the middle keeps sortKey ordering", () async {
      final firstId = (await locationsService.createLocation(database: database, name: "A"))!;
      final secondId = (await locationsService.createLocation(database: database, name: "B"))!;

      await locationsService.reorderLocation(
        database: database,
        locationId: secondId,
        newPosition: 0,
      );
      final thirdId = (await locationsService.createLocation(database: database, name: "C"))!;
      await locationsService.reorderLocation(
        database: database,
        locationId: thirdId,
        newPosition: 1,
      );

      final rows = await readLocations();
      expect(rows.map((row) => row.id), [secondId, thirdId, firstId]);
    });

    test("updateLocation only touches the fields it's given a Value for", () async {
      final id = (await locationsService.createLocation(database: database, name: "A"))!;

      await locationsService.updateLocation(
        database: database,
        locationId: id,
        city: const Value("Lyon"),
        permitStatus: const Value(OcptPermitStatus.requested),
      );

      final row = await readLocation(id);
      expect(row.city, "Lyon");
      expect(row.permitStatus, OcptPermitStatus.requested);
      expect(row.addressLine1, ""); // untouched, still its column default
    });

    test("reorderLocation moves a location by writing exactly one row", () async {
      final firstId = (await locationsService.createLocation(database: database, name: "A"))!;
      final secondId = (await locationsService.createLocation(database: database, name: "B"))!;
      final thirdId = (await locationsService.createLocation(database: database, name: "C"))!;

      final keysBefore = {for (final row in await readLocations()) row.id: row.sortKey};
      await locationsService.reorderLocation(
        database: database,
        locationId: firstId,
        newPosition: 2,
      );
      final keysAfter = {for (final row in await readLocations()) row.id: row.sortKey};

      expect((await readLocations()).map((row) => row.id), [secondId, thirdId, firstId]);
      expect(keysAfter.keys.where((id) => keysAfter[id] != keysBefore[id]), [firstId]);
    });

    test("deleteLocation writes a tombstone and the row disappears from every read", () async {
      final firstId = (await locationsService.createLocation(database: database, name: "A"))!;
      final secondId = (await locationsService.createLocation(database: database, name: "B"))!;

      await locationsService.deleteLocation(database: database, locationId: firstId);

      final locations = await locationsService.loadLocations(database: database);
      expect(locations.map((location) => location.id), [secondId]);

      final tombstoned = await readLocation(firstId);
      expect(tombstoned.isDeleted, isTrue);
    });

    test("deleteLocation tombstones its sets and the scene_sets links onto them", () async {
      final locationId = (await locationsService.createLocation(
        database: database,
        name: "La maison des Pains",
      ))!;
      final setId = (await locationsService.createSet(
        database: database,
        locationId: locationId,
        name: "Cuisine",
      ))!;
      await database
          .into(database.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: "screenplay-1",
              title: "Draft",
              updatedAt: DateTime.now(),
            ),
          );
      await database
          .into(database.ocptScenesTable)
          .insert(
            OcptScenesTableCompanion.insert(
              id: "scene-1",
              screenplayId: "screenplay-1",
              position: 0,
              heading: "INT. CUISINE - DAY",
              charStart: 0,
              charEnd: 10,
            ),
          );
      final linkId = (await locationsService.addSceneSet(
        database: database,
        sceneId: "scene-1",
        setId: setId,
      ))!;

      await locationsService.deleteLocation(database: database, locationId: locationId);

      final setRow = await (database.select(
        database.ocptSetsTable,
      )..where((row) => row.id.equals(setId))).getSingle();
      expect(setRow.isDeleted, isTrue);

      final linkRow = await (database.select(
        database.ocptSceneSetsTable,
      )..where((row) => row.id.equals(linkId))).getSingle();
      expect(linkRow.isDeleted, isTrue);
    });
  });

  group("sets", () {
    test("createSet appends within its location and loadLocations reads them back in order", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;

      await locationsService.createSet(database: database, locationId: locationId, name: "Hangar");
      await locationsService.createSet(database: database, locationId: locationId, name: "Jardin");

      final locations = await locationsService.loadLocations(database: database);
      expect(locations.single.sets.map((set) => set.name), ["Hangar", "Jardin"]);
    });

    test("updateSet only touches the fields it's given a Value for", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final setId = (await locationsService.createSet(
        database: database,
        locationId: locationId,
        name: "Hangar",
      ))!;

      await locationsService.updateSet(database: database, setId: setId, code: const Value("A"));

      final locations = await locationsService.loadLocations(database: database);
      final set = locations.single.sets.single;
      expect(set.code, "A");
      expect(set.name, "Hangar");
    });

    test("deleteSet tombstones it and it disappears from loadLocations", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final firstSetId = (await locationsService.createSet(
        database: database,
        locationId: locationId,
        name: "Hangar",
      ))!;
      final secondSetId = (await locationsService.createSet(
        database: database,
        locationId: locationId,
        name: "Jardin",
      ))!;

      await locationsService.deleteSet(database: database, setId: firstSetId);

      final locations = await locationsService.loadLocations(database: database);
      expect(locations.single.sets.map((set) => set.id), [secondSetId]);
    });

    test("reorderSet moves a set by writing exactly one row", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final ids = [
        for (var i = 0; i < 3; i++)
          (await locationsService.createSet(
            database: database,
            locationId: locationId,
            name: "Set $i",
          ))!,
      ];

      await locationsService.reorderSet(
        database: database,
        locationId: locationId,
        setId: ids[0],
        newPosition: 2,
      );

      final locations = await locationsService.loadLocations(database: database);
      expect(locations.single.sets.map((set) => set.id), [ids[1], ids[2], ids[0]]);
    });
  });

  group("scene ↔ set links", () {
    setUp(() async {
      await database
          .into(database.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: "screenplay-1",
              title: "Draft",
              updatedAt: DateTime.now(),
            ),
          );
      await database
          .into(database.ocptScenesTable)
          .insert(
            OcptScenesTableCompanion.insert(
              id: "scene-1",
              screenplayId: "screenplay-1",
              position: 0,
              heading: "INT. CUISINE - DAY",
              charStart: 0,
              charEnd: 10,
            ),
          );
    });

    test("addSceneSet links a scene to a set and setIdsOfScene reads it back", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final setId = (await locationsService.createSet(
        database: database,
        locationId: locationId,
        name: "Cuisine",
      ))!;

      await locationsService.addSceneSet(database: database, sceneId: "scene-1", setId: setId);

      final setIds = await locationsService.setIdsOfScene(database: database, sceneId: "scene-1");
      expect(setIds, [setId]);
    });

    test("removeSceneSet tombstones the link", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final setId = (await locationsService.createSet(
        database: database,
        locationId: locationId,
        name: "Cuisine",
      ))!;
      final linkId = (await locationsService.addSceneSet(
        database: database,
        sceneId: "scene-1",
        setId: setId,
      ))!;

      await locationsService.removeSceneSet(database: database, id: linkId);

      final setIds = await locationsService.setIdsOfScene(database: database, sceneId: "scene-1");
      expect(setIds, isEmpty);
    });
  });
}
