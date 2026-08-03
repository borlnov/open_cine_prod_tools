// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the `elements` catalogue and the `scene_elements` links (the *dépouillement*) between
/// a scene and the elements it needs.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — see `OcptShotListService`'s own doc comment. The
/// elements board groups the loaded list by [OcptElement.category] for display, but that grouping
/// is read-time UI work over a single flat `sortKey` order, exactly as the shot list table groups
/// its own flat order by sequence: there is one order to maintain, not one per category.
///
/// `scene_elements` carries no `sortKey`: a scene's elements are a set the user adds to and removes
/// from, not a list they reorder (see `OcptSceneElementsTable`'s own doc comment).
class OcptElementsService {
  /// Class constructor
  const OcptElementsService();

  /// Loads every live element of [database], in `sortKey` order, each joined with the live
  /// `scene_elements` links pointing at it, themselves in the screenplay's own scene order.
  ///
  /// A link's `sceneId` names a **live scene only**: a row whose scene was tombstoned by the last
  /// reconciliation is skipped rather than shown as a scene that no longer exists, and comes back
  /// on its own if the scene does — `OcptSceneIndexService` reuses a scene's id for as long as it
  /// can match it. That is `OcptLocationsService.loadLocations`' own rule for a set's scenes, and
  /// the two must not disagree about what a link onto a vanished scene means.
  Future<List<OcptElement>> loadElements({required OcptProjectDatabase database}) async {
    final rows = await _liveElementRows(database);
    final linksByElementId = await _liveSceneLinksByElementId(
      database: database,
      elementIds: rows.map((row) => row.id).toList(growable: false),
    );

    return [
      for (final row in rows)
        OcptElement.fromRow(row: row, sceneLinks: linksByElementId[row.id] ?? const []),
    ];
  }

  /// Creates a new element named [name], of [category] and [sourceKind], in [database], appended
  /// at the end of the catalogue, and returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createElement({
    required OcptProjectDatabase database,
    required String name,
    required OcptElementCategory category,
    required OcptElementSourceKind sourceKind,
  }) async {
    if (database.refusesUserWrite("createElement")) {
      return null;
    }

    final existing = await _liveElementRows(database);
    final id = const Uuid().v4();

    await database
        .into(database.ocptElementsTable)
        .insert(
          OcptElementsTableCompanion.insert(
            id: id,
            name: name,
            category: category,
            sourceKind: sourceKind,
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of element [elementId] in [database] that are passed as something other
  /// than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderElement] and [deleteElement].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateElement({
    required OcptProjectDatabase database,
    required String elementId,
    Value<OcptElementCategory> category = const Value.absent(),
    Value<String> subCategory = const Value.absent(),
    Value<String> name = const Value.absent(),
    Value<String> code = const Value.absent(),
    Value<String> quantity = const Value.absent(),
    Value<OcptElementSourceKind> sourceKind = const Value.absent(),
    Value<String?> ownerPersonId = const Value.absent(),
    Value<String> ownerNotes = const Value.absent(),
    Value<String?> broughtByPersonId = const Value.absent(),
    Value<String> storageNotes = const Value.absent(),
    Value<bool> isSecured = const Value.absent(),
    Value<bool> isReadyForShoot = const Value.absent(),
    Value<bool> isReturned = const Value.absent(),
    Value<int?> cost = const Value.absent(),
    Value<String> purposeNotes = const Value.absent(),
    Value<String> notes = const Value.absent(),
    Value<String?> photoAssetId = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateElement")) {
      return;
    }

    await (database.update(
      database.ocptElementsTable,
    )..where((table) => table.id.equals(elementId) & table.isDeleted.not())).write(
      OcptElementsTableCompanion(
        category: category,
        subCategory: subCategory,
        name: name,
        code: code,
        quantity: quantity,
        sourceKind: sourceKind,
        ownerPersonId: ownerPersonId,
        ownerNotes: ownerNotes,
        broughtByPersonId: broughtByPersonId,
        storageNotes: storageNotes,
        isSecured: isSecured,
        isReadyForShoot: isReadyForShoot,
        isReturned: isReturned,
        cost: cost,
        purposeNotes: purposeNotes,
        notes: notes,
        photoAssetId: photoAssetId,
      ),
    );
  }

  /// Tombstones element [elementId] in [database] and its `scene_elements` links along with it.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteElement({
    required OcptProjectDatabase database,
    required String elementId,
  }) async {
    if (database.refusesUserWrite("deleteElement")) {
      return;
    }

    await database.transaction(() async {
      await (database.update(
        database.ocptSceneElementsTable,
      )..where((table) => table.elementId.equals(elementId))).write(
        const OcptSceneElementsTableCompanion(isDeleted: Value(true)),
      );
      await (database.update(
        database.ocptElementsTable,
      )..where((table) => table.id.equals(elementId))).write(
        const OcptElementsTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// Moves element [elementId] to [newPosition] (0-based) within the catalogue's flat `sortKey`
  /// order, by giving it a `sortKey` sitting between the two elements it lands between. Writes
  /// **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderElement({
    required OcptProjectDatabase database,
    required String elementId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderElement")) {
      return;
    }

    await database.transaction(() async {
      final others = (await _liveElementRows(database))..removeWhere((row) => row.id == elementId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptElementsTable,
      )..where((table) => table.id.equals(elementId))).write(
        OcptElementsTableCompanion(sortKey: Value(sortKey)),
      );
    });
  }

  /// Links scene [sceneId] to element [elementId], with an optional per-scene [quantity] override
  /// and [notes], and returns the id of the link — the one that already said so when there was one,
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
  Future<String?> addSceneElement({
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
      final existingLinks =
          await (database.select(database.ocptSceneElementsTable)..where(
                (table) => table.sceneId.equals(sceneId) & table.elementId.equals(elementId),
              ))
              .get();

      OcptSceneElementRow? droppedLink;
      for (final link in existingLinks) {
        if (!link.isDeleted) {
          return link.id;
        }

        droppedLink ??= link;
      }

      if (droppedLink != null) {
        await (database.update(
          database.ocptSceneElementsTable,
        )..where((table) => table.id.equals(droppedLink!.id))).write(
          const OcptSceneElementsTableCompanion(isDeleted: Value(false)),
        );

        return droppedLink.id;
      }

      final id = const Uuid().v4();
      await database
          .into(database.ocptSceneElementsTable)
          .insert(
            OcptSceneElementsTableCompanion.insert(
              id: id,
              sceneId: sceneId,
              elementId: elementId,
              quantity: Value(quantity),
              notes: Value(notes),
            ),
          );

      return id;
    });
  }

  /// Updates the fields of scene ↔ element link [id] in [database] that are passed as something
  /// other than [Value.absent].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateSceneElement({
    required OcptProjectDatabase database,
    required String id,
    Value<String> quantity = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSceneElement")) {
      return;
    }

    await (database.update(
      database.ocptSceneElementsTable,
    )..where((table) => table.id.equals(id) & table.isDeleted.not())).write(
      OcptSceneElementsTableCompanion(quantity: quantity, notes: notes),
    );
  }

  /// Removes the scene ↔ element link [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeSceneElement({
    required OcptProjectDatabase database,
    required String id,
  }) async {
    if (database.refusesUserWrite("removeSceneElement")) {
      return;
    }

    await (database.update(
      database.ocptSceneElementsTable,
    )..where((table) => table.id.equals(id))).write(
      const OcptSceneElementsTableCompanion(isDeleted: Value(true)),
    );
  }

  /// Every live `scene_elements` row of scene [sceneId].
  Future<List<OcptSceneElementRow>> sceneElementsOfScene({
    required OcptProjectDatabase database,
    required String sceneId,
  }) => (database.select(database.ocptSceneElementsTable)..where(
        (table) => table.sceneId.equals(sceneId) & table.isDeleted.not(),
      ))
      .get();

  /// The live `scene_elements` links of every element of [elementIds], keyed by element id and
  /// ordered by the screenplay's own scene order.
  ///
  /// Ordered by the scene rather than by anything the link carries: `scene_elements` has no
  /// `sortKey` (see its own doc comment), and the only order a reader expects of "the scenes this
  /// prop appears in" is the one they are read in. See [loadElements] for why a link onto a
  /// tombstoned scene is left out rather than reported.
  Future<Map<String, List<OcptSceneElementLink>>> _liveSceneLinksByElementId({
    required OcptProjectDatabase database,
    required List<String> elementIds,
  }) async {
    if (elementIds.isEmpty) {
      return const {};
    }

    final linkRows =
        await (database.select(database.ocptSceneElementsTable)..where(
              (table) => table.elementId.isIn(elementIds) & table.isDeleted.not(),
            ))
            .get();
    if (linkRows.isEmpty) {
      return const {};
    }

    final sceneRows =
        await (database.select(database.ocptScenesTable)..where(
              (table) =>
                  table.id.isIn(linkRows.map((row) => row.sceneId).toList(growable: false)) &
                  table.isDeleted.not(),
            ))
            .get();

    final positionBySceneId = {for (final row in sceneRows) row.id: row.position};

    final linksByElementId = <String, List<OcptSceneElementLink>>{};
    for (final link in linkRows) {
      if (positionBySceneId.containsKey(link.sceneId)) {
        linksByElementId
            .putIfAbsent(link.elementId, () => [])
            .add(OcptSceneElementLink.fromRow(link));
      }
    }

    for (final links in linksByElementId.values) {
      links.sort(
        (a, b) => positionBySceneId[a.sceneId]!.compareTo(positionBySceneId[b.sceneId]!),
      );
    }

    return linksByElementId;
  }

  /// Every live element row of [database], ordered by `sortKey`.
  Future<List<OcptElementRow>> _liveElementRows(OcptProjectDatabase database) =>
      (database.select(database.ocptElementsTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();
}
