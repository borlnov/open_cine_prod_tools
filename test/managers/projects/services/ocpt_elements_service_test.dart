// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const elementsService = OcptElementsService();

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every live element row, in `sortKey` order.
  Future<List<OcptElementRow>> readElements() =>
      (database.select(database.ocptElementsTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// The element row [id], tombstoned or not.
  Future<OcptElementRow> readElement(String id) => (database.select(
    database.ocptElementsTable,
  )..where((row) => row.id.equals(id))).getSingle();

  Future<String> createElement(String name) => elementsService
      .createElement(
        database: database,
        name: name,
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      )
      .then((id) => id!);

  group("elements CRUD and ordering", () {
    test("createElement appends at the end and loadElements reads it back", () async {
      final firstId = await createElement("Valise");
      final secondId = await createElement("Lampe torche");

      final elements = await elementsService.loadElements(database: database);
      expect(elements.map((element) => element.id), [firstId, secondId]);
      expect(elements.map((element) => element.category), [
        OcptElementCategory.prop,
        OcptElementCategory.prop,
      ]);
    });

    test("createElement numbers a code within the element's own category", () async {
      final firstPropId = await createElement("Valise");
      final secondPropId = await createElement("Lampe torche");
      final vehicleId = await elementsService
          .createElement(
            database: database,
            name: "Renault 4L",
            category: OcptElementCategory.vehicle,
            sourceKind: OcptElementSourceKind.borrowed,
          )
          .then((id) => id!);

      expect((await readElement(firstPropId)).code, "PRP-1");
      expect((await readElement(secondPropId)).code, "PRP-2");
      expect((await readElement(vehicleId)).code, "VEH-1");
    });

    test("createElement leaves a hand-written code out of its numbering", () async {
      final firstId = await createElement("Valise");
      await elementsService.updateElement(
        database: database,
        elementId: firstId,
        code: const Value("malle noire"),
      );

      final secondId = await createElement("Lampe torche");

      expect((await readElement(secondId)).code, "PRP-1");
    });

    test("createElement in the middle keeps sortKey ordering", () async {
      final firstId = await createElement("A");
      final secondId = await createElement("B");

      await elementsService.reorderElement(
        database: database,
        elementId: secondId,
        newPosition: 0,
      );
      final thirdId = await createElement("C");
      await elementsService.reorderElement(database: database, elementId: thirdId, newPosition: 1);

      final rows = await readElements();
      expect(rows.map((row) => row.id), [secondId, thirdId, firstId]);
    });

    test("updateElement only touches the fields it's given a Value for", () async {
      final id = await createElement("Valise");

      await elementsService.updateElement(
        database: database,
        elementId: id,
        quantity: const Value("1"),
        isSecured: const Value(true),
      );

      final row = await readElement(id);
      expect(row.quantity, "1");
      expect(row.isSecured, isTrue);
      expect(row.isReadyForShoot, isFalse); // untouched, still its column default
      expect(row.name, "Valise"); // untouched
    });

    test("reorderElement moves an element by writing exactly one row", () async {
      final firstId = await createElement("A");
      final secondId = await createElement("B");
      final thirdId = await createElement("C");

      final keysBefore = {for (final row in await readElements()) row.id: row.sortKey};
      await elementsService.reorderElement(database: database, elementId: firstId, newPosition: 2);
      final keysAfter = {for (final row in await readElements()) row.id: row.sortKey};

      expect((await readElements()).map((row) => row.id), [secondId, thirdId, firstId]);
      expect(keysAfter.keys.where((id) => keysAfter[id] != keysBefore[id]), [firstId]);
    });

    test("deleteElement writes a tombstone and the row disappears from every read", () async {
      final firstId = await createElement("A");
      final secondId = await createElement("B");

      await elementsService.deleteElement(database: database, elementId: firstId);

      final elements = await elementsService.loadElements(database: database);
      expect(elements.map((element) => element.id), [secondId]);

      final tombstoned = await readElement(firstId);
      expect(tombstoned.isDeleted, isTrue);
    });
  });

  group("scene ↔ element links", () {
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
      await database
          .into(database.ocptScenesTable)
          .insert(
            OcptScenesTableCompanion.insert(
              id: "scene-2",
              screenplayId: "screenplay-1",
              position: 1,
              heading: "EXT. RUE - NIGHT",
              charStart: 11,
              charEnd: 20,
            ),
          );
    });

    test("addSceneElement links a scene to an element", () async {
      final elementId = await createElement("Valise");

      await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
        quantity: "2",
      );

      final links = await elementsService.sceneElementsOfScene(
        database: database,
        sceneId: "scene-1",
      );
      expect(links, hasLength(1));
      expect(links.single.elementId, elementId);
      expect(links.single.quantity, "2");
    });

    test("updateSceneElement only touches the fields it's given a Value for", () async {
      final elementId = await createElement("Valise");
      final linkId = (await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
        quantity: "1",
      ))!;

      await elementsService.updateSceneElement(
        database: database,
        id: linkId,
        notes: const Value("Sur la table"),
      );

      final links = await elementsService.sceneElementsOfScene(
        database: database,
        sceneId: "scene-1",
      );
      expect(links.single.quantity, "1"); // untouched
      expect(links.single.notes, "Sur la table");
    });

    test("deleteElement tombstones its scene_elements links along with it", () async {
      final elementId = await createElement("Valise");
      await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
      );

      await elementsService.deleteElement(database: database, elementId: elementId);

      final links = await elementsService.sceneElementsOfScene(
        database: database,
        sceneId: "scene-1",
      );
      expect(links, isEmpty);
    });

    test("removeSceneElement tombstones the link", () async {
      final elementId = await createElement("Valise");
      final linkId = (await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
      ))!;

      await elementsService.removeSceneElement(database: database, id: linkId);

      final links = await elementsService.sceneElementsOfScene(
        database: database,
        sceneId: "scene-1",
      );
      expect(links, isEmpty);
    });
    test("loadElements joins the links in the screenplay's own scene order", () async {
      final elementId = await createElement("Valise");
      await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-2",
        elementId: elementId,
        quantity: "1",
      );
      await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
        quantity: "2",
        notes: "Sur la table",
      );

      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.sceneLinks.map((link) => link.sceneId), ["scene-1", "scene-2"]);
      expect(element.sceneLinks.first.quantity, "2");
      expect(element.sceneLinks.first.notes, "Sur la table");
    });

    test("a link onto a tombstoned scene is left out of the element it points at", () async {
      final elementId = await createElement("Valise");
      await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
      );
      await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-2",
        elementId: elementId,
      );

      await (database.update(
        database.ocptScenesTable,
      )..where((row) => row.id.equals("scene-1"))).write(
        const OcptScenesTableCompanion(isDeleted: Value(true)),
      );

      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.sceneLinks.map((link) => link.sceneId), ["scene-2"]);
    });

    test("addSceneElement on a scene already linked returns the link it already has", () async {
      final elementId = await createElement("Valise");
      final firstId = await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
        quantity: "2",
      );

      final secondId = await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
      );

      expect(secondId, firstId);
      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.sceneLinks, hasLength(1));
      expect(element.sceneLinks.single.quantity, "2");
    });

    test("addSceneElement revives a removed link rather than duplicating it", () async {
      final elementId = await createElement("Valise");
      final linkId = (await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
        quantity: "2",
        notes: "Sur la table",
      ))!;
      await elementsService.removeSceneElement(database: database, id: linkId);

      final revivedId = await elementsService.addSceneElement(
        database: database,
        sceneId: "scene-1",
        elementId: elementId,
      );

      expect(revivedId, linkId);
      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.sceneLinks, hasLength(1));
      expect(element.sceneLinks.single.quantity, "2");
      expect(element.sceneLinks.single.notes, "Sur la table");
    });
  });
}
