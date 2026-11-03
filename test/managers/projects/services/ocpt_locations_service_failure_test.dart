// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import '../../../ocpt_result_expectations.dart';

/// The fixed device id every stamp this file's writes carry.
const _deviceId = "device-1";

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String locationA,
  String locationB,
  String setA1,
  String setA2,
  String availability,
});

/// Answer with the fixed device id.
Future<String> _testDeviceId() async => _deviceId;

/// Run the tests of what [OcptLocationsService] answers when the database fails or refuses.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const assetsService = OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId);
  const floorPlanService = OcptFloorPlanService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: _testDeviceId,
  );
  const locationsService = OcptLocationsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    floorPlanService: floorPlanService,
    deviceId: _testDeviceId,
  );

  late OcptProjectDatabase database;
  late _Fixture rows;

  const tables = [
    "locations",
    "sets",
    "scene_sets",
    "location_availabilities",
    "assets",
    "floor_plan_sets",
    "floor_plan_symbols",
    "floor_plan_arrows",
  ];

  /// Insert the screenplay and the two scenes the links name.
  Future<void> seedScenes() async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: "screenplay-1",
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
    for (final (index, id) in ["scene-1", "scene-2"].indexed) {
      await database
          .into(database.ocptScenesTable)
          .insert(
            OcptScenesTableCompanion.insert(
              id: id,
              screenplayId: "screenplay-1",
              position: index,
              heading: "INT. CUISINE - JOUR",
              charStart: index * 100,
              charEnd: index * 100 + 50,
            ),
          );
    }
  }

  /// Two locations, two sets in the first one, one of them linked to `scene-1` and carrying a
  /// symbol of its plan, a photo and a permit document on the first location and one availability
  /// window.
  Future<_Fixture> seed() async {
    await seedScenes();
    final a = await locationsService.createLocation(database: database, name: "House").valueOrFail;
    final b = await locationsService.createLocation(database: database, name: "Barn").valueOrFail;
    final setA1 = await locationsService
        .createSet(database: database, locationId: a, name: "Kitchen")
        .valueOrFail;
    final setA2 = await locationsService
        .createSet(database: database, locationId: a, name: "Hall")
        .valueOrFail;
    await locationsService
        .assignSceneToSet(database: database, sceneId: "scene-1", setId: setA1)
        .valueOrFail;
    await floorPlanService
        .placeSymbol(
          database: database,
          setId: setA1,
          sceneId: null,
          shotId: null,
          layer: OcptFloorPlanLayer.set,
          xM: 1,
          yM: 2,
        )
        .maybeValueOrFail;
    await locationsService
        .addLocationPhoto(database: database, locationId: a, path: "/photos/a.jpg")
        .valueOrFail;
    await locationsService
        .setPermitDocument(database: database, locationId: a, path: "/docs/permit.pdf")
        .valueOrFail;
    final availability = await locationsService
        .addAvailability(
          database: database,
          locationId: a,
          startDate: DateTime(2026, 5),
          endDate: DateTime(2026, 5, 3),
        )
        .valueOrFail;

    return (locationA: a, locationB: b, setA1: setA1, setA2: setA2, availability: availability);
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
    "createLocation": (r) async =>
        (await locationsService.createLocation(database: database, name: "Shed")).status,
    "updateLocation": (r) async => (await locationsService.updateLocation(
      database: database,
      locationId: r.locationA,
      name: const Value("Manor"),
    )).status,
    "deleteLocation": (r) async =>
        (await locationsService.deleteLocation(database: database, locationId: r.locationA)).status,
    "reorderLocation": (r) async => (await locationsService.reorderLocation(
      database: database,
      locationId: r.locationB,
      newPosition: 0,
    )).status,
    "createSet": (r) async => (await locationsService.createSet(
      database: database,
      locationId: r.locationB,
      name: "Loft",
    )).status,
    "createSetLinkedToScene": (r) async => (await locationsService.createSetLinkedToScene(
      database: database,
      sceneId: "scene-2",
      name: "Garden",
    )).status,
    "updateSet": (r) async => (await locationsService.updateSet(
      database: database,
      setId: r.setA1,
      name: const Value("Scullery"),
    )).status,
    "moveSetToLocation": (r) async => (await locationsService.moveSetToLocation(
      database: database,
      setId: r.setA2,
      locationId: r.locationB,
    )).status,
    "deleteSet": (r) async =>
        (await locationsService.deleteSet(database: database, setId: r.setA1)).status,
    "createSiblingSet": (r) async => (await locationsService.createSiblingSet(
      database: database,
      sourceSetId: r.setA1,
      name: "Pantry",
    )).status,
    "duplicateSetForScene": (r) async => (await locationsService.duplicateSetForScene(
      database: database,
      sourceSetId: r.setA1,
      name: "Kitchen copy",
      sceneId: "scene-2",
    )).status,
    "reorderSet": (r) async => (await locationsService.reorderSet(
      database: database,
      locationId: r.locationA,
      setId: r.setA2,
      newPosition: 0,
    )).status,
    "assignSceneToSet": (r) async => (await locationsService.assignSceneToSet(
      database: database,
      sceneId: "scene-2",
      setId: r.setA2,
    )).status,
    "removeSceneFromSet": (r) async => (await locationsService.removeSceneFromSet(
      database: database,
      sceneId: "scene-1",
      setId: r.setA1,
    )).status,
    "addAvailability": (r) async => (await locationsService.addAvailability(
      database: database,
      locationId: r.locationB,
      startDate: DateTime(2026, 6),
      endDate: DateTime(2026, 6, 2),
    )).status,
    "updateAvailability": (r) async => (await locationsService.updateAvailability(
      database: database,
      id: r.availability,
      note: const Value("Noisy"),
    )).status,
    "removeAvailability": (r) async =>
        (await locationsService.removeAvailability(database: database, id: r.availability)).status,
    "addLocationPhoto": (r) async => (await locationsService.addLocationPhoto(
      database: database,
      locationId: r.locationB,
      path: "/photos/b.jpg",
    )).status,
    "setPermitDocument": (r) async => (await locationsService.setPermitDocument(
      database: database,
      locationId: r.locationA,
      path: "/docs/other.pdf",
    )).status,
    "clearPermitDocument": (r) async => (await locationsService.clearPermitDocument(
      database: database,
      locationId: r.locationA,
    )).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadLocations": (r) async => (await locationsService.loadLocations(database: database)).status,
    "loadScenes": (r) async => (await locationsService.loadScenes(
      database: database,
      screenplayId: "screenplay-1",
      episodeNumber: null,
    )).status,
    "firstLinkedSceneOf": (r) async =>
        (await locationsService.firstLinkedSceneOf(database: database, setId: r.setA1)).status,
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

  /// Refuse the [verbs] on [table], on the rows [when] selects when it is given.
  Future<void> refuse(String table, List<String> verbs, {String? when}) async {
    for (final verb in verbs) {
      await database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "${when == null ? '' : 'WHEN $when '}BEGIN SELECT RAISE(ABORT, 'refused'); END",
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
        for (final table in [...tables, "scenes"]) {
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
      final created = <String?>[
        await locationsService.createLocation(database: preview, name: "Shed").maybeValueOrFail,
        await locationsService
            .createSet(database: preview, locationId: rows.locationA, name: "Loft")
            .maybeValueOrFail,
        await locationsService
            .createSetLinkedToScene(database: preview, sceneId: "scene-2", name: "Garden")
            .maybeValueOrFail,
        await locationsService
            .createSiblingSet(database: preview, sourceSetId: rows.setA1, name: "Pantry")
            .maybeValueOrFail,
        await locationsService
            .duplicateSetForScene(
              database: preview,
              sourceSetId: rows.setA1,
              name: "Copy",
              sceneId: "scene-2",
            )
            .maybeValueOrFail,
        await locationsService
            .assignSceneToSet(database: preview, sceneId: "scene-2", setId: rows.setA2)
            .maybeValueOrFail,
        await locationsService
            .addAvailability(
              database: preview,
              locationId: rows.locationA,
              startDate: DateTime(2026, 6),
              endDate: DateTime(2026, 6, 2),
            )
            .maybeValueOrFail,
        await locationsService
            .addLocationPhoto(database: preview, locationId: rows.locationA, path: "/p.jpg")
            .maybeValueOrFail,
        await locationsService
            .setPermitDocument(database: preview, locationId: rows.locationA, path: "/p.pdf")
            .maybeValueOrFail,
      ];

      expect(created, everyElement(isNull));
    });

    test("a read is not refused", () async {
      expect(await locationsService.loadLocations(database: preview).valueOrFail, isEmpty);
      expect(
        await locationsService
            .loadScenes(database: preview, screenplayId: "screenplay-1", episodeNumber: null)
            .valueOrFail,
        isEmpty,
      );
      expect(
        await locationsService.firstLinkedSceneOf(database: preview, setId: "x").maybeValueOrFail,
        isNull,
      );
    });
  });

  group("a write that touches several rows is one transaction", () {
    /// Create a set linked to a scene, in the location the fixture names.
    Future<OcptDatabaseResult<String>> createSetInBarn() => locationsService.createSetLinkedToScene(
      database: database,
      sceneId: "scene-2",
      name: "Garden",
      locationId: rows.locationB,
    );

    /// Refuse the [verbs] on [table], then expect [call] to answer a database error with every
    /// table as it was.
    Future<void> expectNothingKept(
      String table,
      List<String> verbs,
      Future<MixinResultStatus> Function() call, {
      String? when,
    }) async {
      final untouched = await snapshot();
      await refuse(table, verbs, when: when);

      final status = await call();

      expect(status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    }

    test("a set made along with its location is not kept when the location cannot be", () async {
      await expectNothingKept("locations", [
        "INSERT",
      ], () => writes["createSetLinkedToScene"]!(rows));
    });

    test("a location made for a set is not kept when the set cannot be written", () async {
      await expectNothingKept("sets", ["INSERT"], () => writes["createSetLinkedToScene"]!(rows));
    });

    test("a location and a set are not kept when the scene link cannot be written", () async {
      await expectNothingKept("scene_sets", [
        "INSERT",
      ], () => writes["createSetLinkedToScene"]!(rows));
    });

    test("a set created in a location the caller names is not kept without its link", () async {
      await expectNothingKept("scene_sets", [
        "INSERT",
      ], () async => (await createSetInBarn()).status);
    });

    test("a duplicated set keeps nothing when its scene link cannot be written", () async {
      await expectNothingKept("scene_sets", [
        "INSERT",
      ], () => writes["duplicateSetForScene"]!(rows));
    });

    test("a duplicated set keeps nothing when its sibling cannot be written", () async {
      await expectNothingKept("sets", ["INSERT"], () => writes["duplicateSetForScene"]!(rows));
    });

    test("a refusal of the plan copy leaves no new set and no link behind", () async {
      await expectNothingKept("floor_plan_symbols", [
        "INSERT",
      ], () => writes["duplicateSetForScene"]!(rows));
    });

    test("a location keeps its sets when the plan of one of them cannot be tombstoned", () async {
      await expectNothingKept("floor_plan_symbols", [
        "UPDATE",
      ], () => writes["deleteLocation"]!(rows));
    });

    test("a location keeps every set when the second one cannot be tombstoned", () async {
      await expectNothingKept(
        "sets",
        ["UPDATE"],
        () => writes["deleteLocation"]!(rows),
        when: "NEW.id = '${rows.setA2}'",
      );
    });

    test("a location keeps its assets when its own row cannot be tombstoned", () async {
      await expectNothingKept("locations", ["UPDATE"], () => writes["deleteLocation"]!(rows));
    });

    test("a set keeps its plan when its row cannot be tombstoned", () async {
      await expectNothingKept("sets", ["UPDATE"], () => writes["deleteSet"]!(rows));
    });

    test("a set keeps its scene links when its plan cannot be tombstoned", () async {
      await expectNothingKept("floor_plan_symbols", ["UPDATE"], () => writes["deleteSet"]!(rows));
    });

    test("a new permit document keeps the old one when the location cannot point at it", () async {
      await expectNothingKept("locations", ["UPDATE"], () => writes["setPermitDocument"]!(rows));
    });

    test("a new permit document is not kept when the old one cannot be dropped", () async {
      await expectNothingKept("assets", ["UPDATE"], () => writes["setPermitDocument"]!(rows));
    });

    test("a cleared permit document keeps its asset when the location cannot be written", () async {
      await expectNothingKept("locations", ["UPDATE"], () => writes["clearPermitDocument"]!(rows));
    });
  });
}
