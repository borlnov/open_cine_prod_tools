// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

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

    test("createSet codes a set across the whole project, not within its location", () async {
      final firstLocationId = (await locationsService.createLocation(
        database: database,
        name: "Maison",
      ))!;
      final secondLocationId = (await locationsService.createLocation(
        database: database,
        name: "Hangar",
      ))!;

      await locationsService.createSet(
        database: database,
        locationId: firstLocationId,
        name: "Cuisine",
      );
      await locationsService.createSet(
        database: database,
        locationId: firstLocationId,
        name: "Jardin",
      );
      await locationsService.createSet(
        database: database,
        locationId: secondLocationId,
        name: "Atelier",
      );

      final locations = await locationsService.loadLocations(database: database);
      expect(locations.first.sets.map((set) => set.code), ["A", "B"]);
      expect(locations.last.sets.single.code, "C");
    });

    test("updateSet only touches the fields it's given a Value for", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final setId = (await locationsService.createSet(
        database: database,
        locationId: locationId,
        name: "Hangar",
      ))!;

      await locationsService.updateSet(
        database: database,
        setId: setId,
        notes: const Value("Nord"),
      );

      final locations = await locationsService.loadLocations(database: database);
      final set = locations.single.sets.single;
      expect(set.notes, "Nord");
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

    test("createSetLinkedToScene mints a location of its own when given none", () async {
      final setId = await locationsService.createSetLinkedToScene(
        database: database,
        sceneId: "scene-1",
        name: "CUISINE",
      );

      final locations = await locationsService.loadLocations(database: database);
      expect(locations, hasLength(1));
      expect(locations.single.name, "CUISINE");
      expect(locations.single.sets.single.id, setId);
      expect(locations.single.sets.single.name, "CUISINE");
      expect(locations.single.sets.single.sceneIds, ["scene-1"]);
    });

    test("createSetLinkedToScene files the set under the location it's given", () async {
      final locationId = (await locationsService.createLocation(
        database: database,
        name: "Maison",
      ))!;

      await locationsService.createSetLinkedToScene(
        database: database,
        sceneId: "scene-1",
        name: "Cuisine",
        locationId: locationId,
      );

      final locations = await locationsService.loadLocations(database: database);
      expect(locations, hasLength(1));
      expect(locations.single.sets.single.sceneIds, ["scene-1"]);
    });

    test("moveSetToLocation hands a set over with its scenes, appended at the end", () async {
      final fromId = (await locationsService.createLocation(database: database, name: "A"))!;
      final toId = (await locationsService.createLocation(database: database, name: "B"))!;
      await locationsService.createSet(database: database, locationId: toId, name: "Salon");
      final setId = (await locationsService.createSet(
        database: database,
        locationId: fromId,
        name: "Cuisine",
      ))!;
      await locationsService.assignSceneToSet(database: database, sceneId: "scene-1", setId: setId);

      await locationsService.moveSetToLocation(database: database, setId: setId, locationId: toId);

      final locations = await locationsService.loadLocations(database: database);
      expect(locations.first.sets, isEmpty);
      // Appended rather than slotted in: the sortKey it held ranked it among its former siblings.
      expect(locations.last.sets.map((set) => set.name), ["Salon", "Cuisine"]);
      expect(locations.last.sets.last.sceneIds, ["scene-1"]);
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

    test("a scene may be shot in several sets at once", () async {
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

      // Assigning adds; it never answers "no longer there" on the user's behalf.
      expect(await sceneIdsOfSet(firstSetId), ["scene-1"]);
      expect(await sceneIdsOfSet(secondSetId), ["scene-1"]);
    });

    test("dropping one of a scene's sets leaves the others alone", () async {
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

      await locationsService.removeSceneFromSet(
        database: database,
        sceneId: "scene-1",
        setId: firstSetId,
      );

      expect(await sceneIdsOfSet(firstSetId), isEmpty);
      expect(await sceneIdsOfSet(secondSetId), ["scene-1"]);
    });

    test("re-assigning a dropped link revives it rather than adding a second one", () async {
      final setId = await createSetInNewLocation("Cuisine");
      final firstLinkId = await locationsService.assignSceneToSet(
        database: database,
        sceneId: "scene-1",
        setId: setId,
      );
      await locationsService.removeSceneFromSet(
        database: database,
        sceneId: "scene-1",
        setId: setId,
      );

      final revivedLinkId = await locationsService.assignSceneToSet(
        database: database,
        sceneId: "scene-1",
        setId: setId,
      );

      expect(revivedLinkId, firstLinkId);
      expect(await sceneIdsOfSet(setId), ["scene-1"]);
      final links = await database.select(database.ocptSceneSetsTable).get();
      expect(links.length, 1);
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

  group("availability windows", () {
    test("addAvailability appends a window and loadLocations reads it back", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;

      await locationsService.addAvailability(
        database: database,
        locationId: locationId,
        startDate: DateTime.utc(2026, 3, 2),
        endDate: DateTime.utc(2026, 3, 20),
        weekdays: ocptWeekdayMaskToggled(ocptEveryWeekdayMask, DateTime.sunday),
        slot: OcptDayPartSlot.custom,
        startMinute: 8 * 60,
        endMinute: 19 * 60,
        kind: OcptLocationAvailabilityKind.conditional,
        note: "No noise after 22:00",
      );

      final availability = (await locationsService.loadLocations(
        database: database,
      )).single.availabilities.single;
      expect(availability.startDate, DateTime.utc(2026, 3, 2));
      expect(availability.endDate, DateTime.utc(2026, 3, 20));
      expect(ocptWeekdayMaskContains(availability.weekdays, DateTime.sunday), isFalse);
      expect(ocptWeekdayMaskContains(availability.weekdays, DateTime.monday), isTrue);
      expect(availability.slot, OcptDayPartSlot.custom);
      expect(availability.startMinute, 8 * 60);
      expect(availability.kind, OcptLocationAvailabilityKind.conditional);
      expect(availability.note, "No noise after 22:00");
    });

    test("a window is read in start-date order, whatever order it was entered in", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      await locationsService.addAvailability(
        database: database,
        locationId: locationId,
        startDate: DateTime.utc(2026, 5),
        endDate: DateTime.utc(2026, 5),
      );
      await locationsService.addAvailability(
        database: database,
        locationId: locationId,
        startDate: DateTime.utc(2026, 3),
        endDate: DateTime.utc(2026, 3),
      );

      final availabilities = (await locationsService.loadLocations(
        database: database,
      )).single.availabilities;
      expect(availabilities.map((availability) => availability.startDate), [
        DateTime.utc(2026, 3),
        DateTime.utc(2026, 5),
      ]);
    });

    test("a range ending before it starts is clamped rather than refused", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;

      await locationsService.addAvailability(
        database: database,
        locationId: locationId,
        startDate: DateTime.utc(2026, 3, 20),
        endDate: DateTime.utc(2026, 3, 2),
      );

      final availability = (await locationsService.loadLocations(
        database: database,
      )).single.availabilities.single;
      expect(availability.endDate, DateTime.utc(2026, 3, 20));
    });

    test("a window covering no weekday at all falls back to every day", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;

      await locationsService.addAvailability(
        database: database,
        locationId: locationId,
        startDate: DateTime.utc(2026, 3, 2),
        endDate: DateTime.utc(2026, 3, 2),
        weekdays: 0,
      );

      final availability = (await locationsService.loadLocations(
        database: database,
      )).single.availabilities.single;
      expect(availability.weekdays, ocptEveryWeekdayMask);
    });

    test("updateAvailability writes only what it was passed", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final id = (await locationsService.addAvailability(
        database: database,
        locationId: locationId,
        startDate: DateTime.utc(2026, 3, 2),
        endDate: DateTime.utc(2026, 3, 2),
        note: "Ask for Camille",
      ))!;

      await locationsService.updateAvailability(
        database: database,
        id: id,
        kind: const Value(OcptLocationAvailabilityKind.conditional),
      );

      final availability = (await locationsService.loadLocations(
        database: database,
      )).single.availabilities.single;
      expect(availability.kind, OcptLocationAvailabilityKind.conditional);
      expect(availability.note, "Ask for Camille");
    });

    test("removeAvailability tombstones the row", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final id = (await locationsService.addAvailability(
        database: database,
        locationId: locationId,
        startDate: DateTime.utc(2026, 3, 2),
        endDate: DateTime.utc(2026, 3, 2),
      ))!;

      await locationsService.removeAvailability(database: database, id: id);

      expect(
        (await locationsService.loadLocations(database: database)).single.availabilities,
        isEmpty,
      );
      final row = await (database.select(
        database.ocptLocationAvailabilitiesTable,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(row.isDeleted, isTrue);
    });

    test("deleting a location tombstones its windows too", () async {
      final locationId = (await locationsService.createLocation(database: database, name: "A"))!;
      final id = (await locationsService.addAvailability(
        database: database,
        locationId: locationId,
        startDate: DateTime.utc(2026, 3, 2),
        endDate: DateTime.utc(2026, 3, 2),
      ))!;

      await locationsService.deleteLocation(database: database, locationId: locationId);

      final row = await (database.select(
        database.ocptLocationAvailabilitiesTable,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(row.isDeleted, isTrue);
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
