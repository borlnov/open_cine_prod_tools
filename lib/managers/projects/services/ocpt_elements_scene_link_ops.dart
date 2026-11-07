// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_prop_summary.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:uuid/uuid.dart';

/// The links between a scene and the elements it needs: adding, editing and removing one, the
/// links tombstoned along with scenes, and the reads of a scene's elements and props.
///
/// What `OcptElementsService` forwards to; that service documents the elements catalogue whole.
abstract final class OcptElementsSceneLinkOps {
  /// Link scene [sceneId] to element [elementId], with an optional per-scene [quantity] override
  /// and [notes], and return the id of the link — the one that already said so when there was one,
  /// a freshly generated one otherwise.
  ///
  /// Adding a scene the element already carries is a no-op rather than a second row, and a link
  /// that was removed earlier is **revived** rather than duplicated, exactly as
  /// `OcptLocationsService.assignSceneToSet` revives a dropped `scene_sets` row: a tombstone is how
  /// this app deletes, so the pair `(scene, element)` may well have a row already, saying it is
  /// gone. A revived link keeps the quantity and the notes it held — the answer the user gave the
  /// first time is the one they get back — so [quantity] and [notes] only ever seed a row that is
  /// genuinely being inserted.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addSceneElement({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String sceneId,
    required String elementId,
    String quantity = "",
    String notes = "",
  }) async {
    if (database.refusesUserWrite("addSceneElement")) {
      return null;
    }

    return database.transaction(() async {
      final existingLinks = await (database.select(
        database.ocptSceneElementsTable,
      )..where((table) => table.sceneId.equals(sceneId) & table.elementId.equals(elementId))).get();

      OcptSceneElementRow? droppedLink;
      for (final link in existingLinks) {
        if (!link.isDeleted) {
          return link.id;
        }

        droppedLink ??= link;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      if (droppedLink != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptSceneElementsTable,
          rowId: droppedLink.id,
          current: droppedLink,
          next: droppedLink.copyWith(isDeleted: false),
          stamps: stamps,
        );
        await stamps.flush(database);

        return droppedLink.id;
      }

      final id = const Uuid().v4();
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSceneElementsTable,
        rowId: id,
        current: null,
        next: OcptSceneElementRow(
          id: id,
          sceneId: sceneId,
          elementId: elementId,
          quantity: quantity,
          notes: notes,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// Update the fields of scene ↔ element link [id] in [database] that are passed as something
  /// other than [Value.absent].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateSceneElement({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
    Value<String> quantity = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSceneElement")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptSceneElementsTable,
      )..where((table) => table.id.equals(id) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSceneElementsTable,
        rowId: id,
        current: current,
        next: current.copyWithCompanion(
          OcptSceneElementsTableCompanion(quantity: quantity, notes: notes),
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Remove the scene ↔ element link [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> removeSceneElement({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String id,
  }) async {
    if (database.refusesUserWrite("removeSceneElement")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptSceneElementsTable,
      )..where((table) => table.id.equals(id))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSceneElementsTable,
        rowId: id,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstone every live `scene_elements` row naming any of [sceneIds]: `scene_elements` is this
  /// service's table, not `OcptBreakdownService`'s, so its own cascade
  /// (`OcptBreakdownService.tombstoneBreakdownOfScenes`) reaches for this narrow helper rather than
  /// writing the table itself — the element these links point at is, of course, untouched.
  ///
  /// **Unguarded**, exactly as `tombstoneRoleLinksOfRole` is: its only caller has already refused
  /// the write on a preview connection and is already inside the transaction removing the episode,
  /// so a second guard here would only be able to disagree with the first. Stamps through [stamps]
  /// — that caller's own instance — rather than resolving a device id of its own.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  static Future<void> tombstoneSceneElementsOfScenes({
    required OcptProjectDatabase database,
    required List<String> sceneIds,
    required OcptRowStampService? stamps,
  }) async {
    if (sceneIds.isEmpty) {
      return;
    }

    final rows = await (database.select(
      database.ocptSceneElementsTable,
    )..where((table) => table.sceneId.isIn(sceneIds) & table.isDeleted.not())).get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSceneElementsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }

  /// Get every live `scene_elements` row of scene [sceneId].
  static Future<List<OcptSceneElementRow>> sceneElementsOfScene({
    required OcptProjectDatabase database,
    required String sceneId,
  }) => (database.select(
    database.ocptSceneElementsTable,
  )..where((table) => table.sceneId.equals(sceneId) & table.isDeleted.not())).get();

  /// Get scene [sceneId]'s own breakdown props (category [OcptElementCategory.prop] alone), each
  /// carrying its own effective quantity — the floor plans palette's own `Sequence` group chips. In
  /// the catalogue's own `sortKey` order.
  static Future<List<OcptScenePropSummary>> propsOfScene({
    required OcptProjectDatabase database,
    required String sceneId,
  }) async {
    final query =
        database.select(database.ocptSceneElementsTable).join([
            innerJoin(
              database.ocptElementsTable,
              database.ocptElementsTable.id.equalsExp(database.ocptSceneElementsTable.elementId),
            ),
          ])
          ..where(
            database.ocptSceneElementsTable.sceneId.equals(sceneId) &
                database.ocptSceneElementsTable.isDeleted.not() &
                database.ocptElementsTable.isDeleted.not() &
                database.ocptElementsTable.category.equalsValue(OcptElementCategory.prop),
          )
          ..orderBy([OrderingTerm.asc(database.ocptElementsTable.sortKey)]);

    final rows = await query.get();
    return [
      for (final row in rows)
        _scenePropSummaryOf(
          sceneElementRow: row.readTable(database.ocptSceneElementsTable),
          elementRow: row.readTable(database.ocptElementsTable),
        ),
    ];
  }

  /// Get one [OcptScenePropSummary], resolving its own effective quantity: [sceneElementRow]'s own
  /// override when it isn't empty, [elementRow]'s own catalogue quantity otherwise.
  static OcptScenePropSummary _scenePropSummaryOf({
    required OcptSceneElementRow sceneElementRow,
    required OcptElementRow elementRow,
  }) => OcptScenePropSummary(
    elementId: elementRow.id,
    name: elementRow.name,
    quantity: sceneElementRow.quantity.isNotEmpty ? sceneElementRow.quantity : elementRow.quantity,
  );
}
