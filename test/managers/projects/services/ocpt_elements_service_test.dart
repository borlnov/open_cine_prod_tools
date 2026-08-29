// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final assetsService = OcptAssetsService(deviceId: testDeviceId);
  final elementsService = OcptElementsService(assetsService: assetsService, deviceId: testDeviceId);

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

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>` — the same
  /// shape `OcptShotListService`'s own stamping tests read `row_field_versions` back through.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

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

    test("updateElement renumbers the code when the category actually changes", () async {
      await createElement("Valise");
      final movedId = await createElement("Renault 4L");
      expect((await readElement(movedId)).code, "PRP-2");

      await elementsService.updateElement(
        database: database,
        elementId: movedId,
        category: const Value(OcptElementCategory.vehicle),
      );

      expect((await readElement(movedId)).code, "VEH-1");
    });

    test("updateElement leaves the code alone when the category doesn't change", () async {
      await createElement("Valise");
      final elementId = await createElement("Lampe torche");

      await elementsService.updateElement(
        database: database,
        elementId: elementId,
        category: const Value(OcptElementCategory.prop),
        name: const Value("Lampe frontale"),
      );

      expect((await readElement(elementId)).code, "PRP-2");
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

    test("updateElement writes a new status", () async {
      final id = await createElement("Valise");
      expect((await readElement(id)).status, OcptElementStatus.toFind);

      await elementsService.updateElement(
        database: database,
        elementId: id,
        status: const Value(OcptElementStatus.confirmed),
      );

      expect((await readElement(id)).status, OcptElementStatus.confirmed);
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

  group("referenced photo", () {
    test("setElementPhoto references the file and points the element at it", () async {
      final id = (await elementsService.createElement(
        database: database,
        name: "Vélo rouge",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.toBuy,
      ))!;

      await elementsService.setElementPhoto(
        database: database,
        elementId: id,
        path: "/photos/velo.jpg",
      );

      final elements = await elementsService.loadElements(database: database);
      expect(elements.single.photo?.path, "/photos/velo.jpg");
      expect(elements.single.photo?.kind, OcptAssetKind.elementPhoto);
    });

    test("clearElementPhoto tombstones the row and nulls the column", () async {
      final id = (await elementsService.createElement(
        database: database,
        name: "Vélo rouge",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.toBuy,
      ))!;
      await elementsService.setElementPhoto(
        database: database,
        elementId: id,
        path: "/photos/velo.jpg",
      );

      await elementsService.clearElementPhoto(database: database, elementId: id);

      final elements = await elementsService.loadElements(database: database);
      expect(elements.single.photo, isNull);
    });

    test("deleting an element carries its photo away with it", () async {
      final id = (await elementsService.createElement(
        database: database,
        name: "Vélo rouge",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.toBuy,
      ))!;
      final assetId = (await elementsService.setElementPhoto(
        database: database,
        elementId: id,
        path: "/photos/velo.jpg",
      ))!;

      await elementsService.deleteElement(database: database, elementId: id);

      // Nothing can reach that row any more, which is what makes it an orphan rather than history.
      final asset = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals(assetId))).getSingle();
      expect(asset.isDeleted, isTrue);
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

  group("role ↔ element links", () {
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
          .into(database.ocptRolesTable)
          .insert(
            OcptRolesTableCompanion.insert(
              id: "role-1",
              name: "CLARA",
              kind: OcptRoleKind.speaking,
              sortKey: const Value("a"),
            ),
          );
      await database
          .into(database.ocptRolesTable)
          .insert(
            OcptRolesTableCompanion.insert(
              id: "role-2",
              name: "LE CLIENT",
              kind: OcptRoleKind.speaking,
              sortKey: const Value("b"),
            ),
          );
    });

    test("addRoleElement links a role to an element, read back off the element", () async {
      final elementId = await createElement("Manteau rouge");

      await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
        notes: "Taché à partir de la séquence 12",
      );

      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.roleLinks, hasLength(1));
      expect(element.roleLinks.single.roleId, "role-1");
      expect(element.roleLinks.single.notes, "Taché à partir de la séquence 12");
    });

    test("the links come back in the cast's own sortKey order", () async {
      final elementId = await createElement("Manteau rouge");

      // Linked in the reverse of the cast's order, so the read cannot be passing by accident.
      await elementsService.addRoleElement(
        database: database,
        roleId: "role-2",
        elementId: elementId,
      );
      await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
      );

      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.roleLinks.map((link) => link.roleId), ["role-1", "role-2"]);
    });

    test("addRoleElement returns the existing link rather than a second one", () async {
      final elementId = await createElement("Manteau rouge");
      final linkId = (await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
        notes: "Taché",
      ))!;

      final again = await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
      );

      expect(again, linkId);
      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.roleLinks, hasLength(1));
      expect(element.roleLinks.single.notes, "Taché");
    });

    test("addRoleElement revives a removed link, note included", () async {
      final elementId = await createElement("Manteau rouge");
      final linkId = (await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
        notes: "Taché",
      ))!;
      await elementsService.removeRoleElement(database: database, id: linkId);

      final revivedId = await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
      );

      expect(revivedId, linkId);
      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.roleLinks.single.notes, "Taché");
    });

    test("updateRoleElement writes the note, and removeRoleElement tombstones", () async {
      final elementId = await createElement("Manteau rouge");
      final linkId = (await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
      ))!;

      await elementsService.updateRoleElement(
        database: database,
        id: linkId,
        notes: "Doublure changée",
      );
      var element = (await elementsService.loadElements(database: database)).single;
      expect(element.roleLinks.single.notes, "Doublure changée");

      await elementsService.removeRoleElement(database: database, id: linkId);
      element = (await elementsService.loadElements(database: database)).single;
      expect(element.roleLinks, isEmpty);

      // Tombstoned rather than deleted: the row is still there, flagged.
      final rows = await database.select(database.ocptRoleElementsTable).get();
      expect(rows.single.isDeleted, isTrue);
    });

    test("a link onto a tombstoned role is left out of the read", () async {
      final elementId = await createElement("Manteau rouge");
      await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
      );

      await (database.update(
        database.ocptRolesTable,
      )..where((row) => row.id.equals("role-1"))).write(
        const OcptRolesTableCompanion(isDeleted: Value(true)),
      );

      final element = (await elementsService.loadElements(database: database)).single;
      expect(element.roleLinks, isEmpty);
    });

    test("deleteElement carries its role links off with it", () async {
      final elementId = await createElement("Manteau rouge");
      await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
      );

      await elementsService.deleteElement(database: database, elementId: elementId);

      final rows = await database.select(database.ocptRoleElementsTable).get();
      expect(rows.single.isDeleted, isTrue);
    });

    test("tombstoneRoleLinksOfRole takes every link of one role and no other", () async {
      final wornId = await createElement("Manteau rouge");
      final otherId = await createElement("Valise");
      await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: wornId,
      );
      await elementsService.addRoleElement(
        database: database,
        roleId: "role-2",
        elementId: otherId,
      );

      await elementsService.tombstoneRoleLinksOfRole(
        database: database,
        roleId: "role-1",
        stamps: null,
      );

      final elements = await elementsService.loadElements(database: database);
      final byId = {for (final element in elements) element.id: element};
      expect(byId[wornId]!.roleLinks, isEmpty);
      expect(byId[otherId]!.roleLinks.single.roleId, "role-2");

      // And the element itself is untouched: a coat outlives the character who wore it.
      expect(byId[wornId]!.name, "Manteau rouge");
    });

    test("addRoleElement is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final linkId = await elementsService.addRoleElement(
        database: preview,
        roleId: "role-1",
        elementId: "element-1",
      );

      expect(linkId, isNull);
      expect(await preview.select(preview.ocptRoleElementsTable).get(), isEmpty);

      await preview.close();
    });
  });

  group("row-field-version stamps", () {
    /// Inserts the role [id] named "CLARA" directly, for the tests below that link an element to
    /// one — `role_elements.roleId` is a foreign key, and this group's own database starts with no
    /// role at all.
    Future<void> insertRole(String id) => database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(
            id: id,
            name: "CLARA",
            kind: OcptRoleKind.speaking,
            sortKey: const Value("a"),
          ),
        );

    test("createElement stamps every column of the new row", () async {
      final elementId = await createElement("Manteau rouge");

      final stamps = await readStamps();
      final element = await readElement(elementId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("elements/$elementId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(element.toJson().length));
      for (final column in element.toJson().keys) {
        final stamp = ownStamps["elements/$elementId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("updateElement stamps only the columns that actually changed", () async {
      final elementId = await createElement("Manteau rouge");
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await elementsService.updateElement(
        database: database,
        elementId: elementId,
        name: const Value("Manteau bleu"),
        notes: const Value("Taché à la séquence 12"),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("elements/$elementId/")).toSet();
      expect(ownKeys, {"elements/$elementId/name", "elements/$elementId/notes"});

      // Writing the same values again touches nothing: there is nothing left to stamp.
      await elementsService.updateElement(
        database: database,
        elementId: elementId,
        name: const Value("Manteau bleu"),
      );
      expect(await readStamps(), stamps);
    });

    test("deleteElement stamps isDeleted on the element and its role_elements links", () async {
      final elementId = await createElement("Manteau rouge");
      await insertRole("role-1");
      final linkId = (await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await elementsService.deleteElement(database: database, elementId: elementId);

      final stamps = await readStamps();
      expect(stamps["elements/$elementId/isDeleted"]!.version, 1);
      expect(stamps["role_elements/$linkId/isDeleted"]!.version, 1);
    });

    test("addRoleElement stamps every column of the new link", () async {
      final elementId = await createElement("Manteau rouge");
      await insertRole("role-1");
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final linkId = (await elementsService.addRoleElement(
        database: database,
        roleId: "role-1",
        elementId: elementId,
      ))!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptRoleElementsTable,
      )..where((table) => table.id.equals(linkId))).getSingle();

      for (final column in row.toJson().keys) {
        expect(
          stamps["role_elements/$linkId/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });
  });
}
