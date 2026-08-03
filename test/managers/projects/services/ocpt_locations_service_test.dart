// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
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

  /// Inserts one scene of `screenplay-1`, the screenplay the scene ↔ set group sets up.
  Future<void> insertScene({
    required String id,
    required int position,
    required String heading,
  }) => database
      .into(database.ocptScenesTable)
      .insert(
        OcptScenesTableCompanion.insert(
          id: id,
          screenplayId: "screenplay-1",
          position: position,
          heading: heading,
          charStart: position * 100,
          charEnd: position * 100 + 50,
        ),
      );

  /// Creates a location holding one set named [name], and returns that set's id.
  Future<String> createSetInNewLocation(String name) async {
    final locationId = (await locationsService.createLocation(database: database, name: name))!;
    return (await locationsService.createSet(
      database: database,
      locationId: locationId,
      name: name,
    ))!;
  }

  /// The ids of the scenes set [setId] holds, read back through [OcptLocationsService.loadLocations]
  /// — the one way the app itself ever reads a `scene_sets` row.
  Future<List<String>> sceneIdsOfSet(String setId) async {
    final locations = await locationsService.loadLocations(database: database);
    for (final location in locations) {
      for (final set in location.sets) {
        if (set.id == setId) {
          return set.sceneIds;
        }
      }
    }
    return const [];
  }

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
      final linkId = (await locationsService.assignSceneToSet(
        database: database,
        sceneId: "scene-1",
        setId: setId,
      ))!;
      final photoId = (await locationsService.addLocationPhoto(
        database: database,
        locationId: locationId,
        path: "/tmp/repérage.jpg",
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

      final photoRow = await (database.select(
        database.ocptAssetsTable,
      )..where((row) => row.id.equals(photoId))).getSingle();
      expect(photoRow.isDeleted, isTrue);
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
      await insertScene(id: "scene-1", position: 0, heading: "INT. CUISINE - JOUR");
      await insertScene(id: "scene-2", position: 1, heading: "EXT. JARDIN - NUIT");
    });

    test("assignSceneToSet links a scene to a set and loadLocations reads it back", () async {
      final setId = await createSetInNewLocation("Cuisine");

      await locationsService.assignSceneToSet(database: database, sceneId: "scene-1", setId: setId);

      expect(await sceneIdsOfSet(setId), ["scene-1"]);
    });

    test("a set's scenes come back in the screenplay's own order", () async {
      final setId = await createSetInNewLocation("Cuisine");

      await locationsService.assignSceneToSet(database: database, sceneId: "scene-2", setId: setId);
      await locationsService.assignSceneToSet(database: database, sceneId: "scene-1", setId: setId);

      expect(await sceneIdsOfSet(setId), ["scene-1", "scene-2"]);
    });

    test("assigning a scene to another set moves it rather than linking it twice", () async {
      final firstSetId = await createSetInNewLocation("Cuisine");
      final secondSetId = await createSetInNewLocation("Hangar");

      await locationsService.assignSceneToSet(
        database: database,
        sceneId: "scene-1",
        setId: firstSetId,
      );
      await locationsService.assignSceneToSet(
        database: database,
        sceneId: "scene-1",
        setId: secondSetId,
      );

      expect(await sceneIdsOfSet(firstSetId), isEmpty);
      expect(await sceneIdsOfSet(secondSetId), ["scene-1"]);
    });

    test("assigning a scene to the set it already sits in keeps the same link", () async {
      final setId = await createSetInNewLocation("Cuisine");

      final firstLinkId = await locationsService.assignSceneToSet(
        database: database,
        sceneId: "scene-1",
        setId: setId,
      );
      final secondLinkId = await locationsService.assignSceneToSet(
        database: database,
        sceneId: "scene-1",
        setId: setId,
      );

      expect(secondLinkId, firstLinkId);
      expect(await sceneIdsOfSet(setId), ["scene-1"]);
    });

    test("removeSceneFromSet tombstones the link", () async {
      final setId = await createSetInNewLocation("Cuisine");
      await locationsService.assignSceneToSet(database: database, sceneId: "scene-1", setId: setId);

      await locationsService.removeSceneFromSet(
        database: database,
        sceneId: "scene-1",
        setId: setId,
      );

      expect(await sceneIdsOfSet(setId), isEmpty);
    });

    test("a link onto a tombstoned scene is left out of the set that holds it", () async {
      final setId = await createSetInNewLocation("Cuisine");
      await locationsService.assignSceneToSet(database: database, sceneId: "scene-1", setId: setId);

      await (database.update(
        database.ocptScenesTable,
      )..where((row) => row.id.equals("scene-1"))).write(
        const OcptScenesTableCompanion(isDeleted: Value(true)),
      );

      expect(await sceneIdsOfSet(setId), isEmpty);
    });

    test("loadScenes reads the screenplay's live scenes in source order", () async {
      final scenes = await locationsService.loadScenes(
        database: database,
        screenplayId: "screenplay-1",
      );

      expect(scenes.map((scene) => scene.id), ["scene-1", "scene-2"]);
      expect(scenes.map((scene) => scene.displayNumber), ["1", "2"]);
    });
  });

  group("assets", () {
    test("addLocationPhoto appends a reference and loadLocations reads it back", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;

      await locationsService.addLocationPhoto(
        database: database,
        locationId: locationId,
        path: "/photos/first.jpg",
      );
      await locationsService.addLocationPhoto(
        database: database,
        locationId: locationId,
        path: "/photos/second.jpg",
      );

      final locations = await locationsService.loadLocations(database: database);
      expect(locations.single.photos.map((photo) => photo.path), [
        "/photos/first.jpg",
        "/photos/second.jpg",
      ]);
      expect(locations.single.photos.map((photo) => photo.kind), [
        OcptAssetKind.locationPhoto,
        OcptAssetKind.locationPhoto,
      ]);
    });

    test("removeAsset drops a photo from the location that held it", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final photoId = (await locationsService.addLocationPhoto(
        database: database,
        locationId: locationId,
        path: "/photos/first.jpg",
      ))!;

      await locationsService.removeAsset(database: database, assetId: photoId);

      final locations = await locationsService.loadLocations(database: database);
      expect(locations.single.photos, isEmpty);
    });

    test("setPermitDocument points the location at the document it references", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;

      await locationsService.setPermitDocument(
        database: database,
        locationId: locationId,
        path: "/permits/granted.pdf",
      );

      final location = (await locationsService.loadLocations(database: database)).single;
      expect(location.permitDocument?.path, "/permits/granted.pdf");
      expect(location.permitDocument?.kind, OcptAssetKind.document);
      expect(location.permitAssetId, location.permitDocument?.id);
      // The permit document is not one of the scouting photos, however the two are stored.
      expect(location.photos, isEmpty);
    });

    test("setPermitDocument tombstones the document it replaces", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final firstId = (await locationsService.setPermitDocument(
        database: database,
        locationId: locationId,
        path: "/permits/draft.pdf",
      ))!;

      await locationsService.setPermitDocument(
        database: database,
        locationId: locationId,
        path: "/permits/granted.pdf",
      );

      final replaced = await (database.select(
        database.ocptAssetsTable,
      )..where((row) => row.id.equals(firstId))).getSingle();
      expect(replaced.isDeleted, isTrue);

      final location = (await locationsService.loadLocations(database: database)).single;
      expect(location.permitDocument?.path, "/permits/granted.pdf");
    });

    test("clearPermitDocument drops both the reference and the row", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final documentId = (await locationsService.setPermitDocument(
        database: database,
        locationId: locationId,
        path: "/permits/granted.pdf",
      ))!;

      await locationsService.clearPermitDocument(database: database, locationId: locationId);

      final location = (await locationsService.loadLocations(database: database)).single;
      expect(location.permitAssetId, isNull);
      expect(location.permitDocument, isNull);

      final row = await (database.select(
        database.ocptAssetsTable,
      )..where((row) => row.id.equals(documentId))).getSingle();
      expect(row.isDeleted, isTrue);
    });
  });
}
