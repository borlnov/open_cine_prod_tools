// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_element_code.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the `elements` catalogue and the two kinds of link onto it: the `scene_elements` ones
/// (the *dépouillement*) between a scene and the elements it needs, and the `role_elements` ones
/// between a role and what it wears, carries and is made up with.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — see `OcptShotListService`'s own doc comment. The
/// elements board groups the loaded list by [OcptElement.category] for display, but that grouping
/// is read-time UI work over a single flat `sortKey` order, exactly as the shot list table groups
/// its own flat order by sequence: there is one order to maintain, not one per category.
///
/// **`role_elements` is written from here rather than from `OcptRoleIndexService`** even though the
/// role sheet is where the user adds to it: the row is a link onto an element, it is loaded with
/// the element it names, and one service owning both halves is what keeps the role sheet's card
/// and the element sheet's reverse read-out from ever disagreeing. The role side of it is a read —
/// the card scans the loaded catalogue for the links naming its role — with the single exception of
/// [tombstoneRoleLinksOfRole], the cascade `OcptRoleIndexService.deleteRole` reaches for.
///
/// Neither link table carries a `sortKey`: a scene's elements, like a role's things, are a set the
/// user adds to and removes from rather than a list they reorder (see `OcptSceneElementsTable`'s
/// own doc comment).
class OcptElementsService {
  /// The service minting and tombstoning the `assets` row an element's photo is. Held rather than
  /// reached for, exactly as `OcptPeopleService` and `OcptLocationsService` hold their own.
  final OcptAssetsService assetsService;

  /// Class constructor
  const OcptElementsService({this.assetsService = const OcptAssetsService()});

  /// Loads every live element of [database], in `sortKey` order, each joined with the live
  /// `scene_elements` links pointing at it (themselves in the screenplay's own scene order), the
  /// live `role_elements` ones (in the cast's own `sortKey` order) and with the photo it
  /// references.
  ///
  /// A link's `sceneId` names a **live scene only**: a row whose scene was tombstoned by the last
  /// reconciliation is skipped rather than shown as a scene that no longer exists, and comes back
  /// on its own if the scene does — `OcptSceneIndexService` reuses a scene's id for as long as it
  /// can match it. That is `OcptLocationsService.loadLocations`' own rule for a set's scenes, and
  /// the two must not disagree about what a link onto a vanished scene means.
  Future<List<OcptElement>> loadElements({required OcptProjectDatabase database}) async {
    final rows = await _liveElementRows(database);
    final elementIds = rows.map((row) => row.id).toList(growable: false);

    final linksByElementId = await _liveSceneLinksByElementId(
      database: database,
      elementIds: elementIds,
    );

    final roleLinksByElementId = await _liveRoleLinksByElementId(
      database: database,
      elementIds: elementIds,
    );

    final assetRows = elementIds.isEmpty
        ? const <OcptAssetRow>[]
        : await (database.select(database.ocptAssetsTable)
                ..where((table) => table.elementId.isIn(elementIds) & table.isDeleted.not()))
              .get();

    final assetsById = {for (final row in assetRows) row.id: OcptAssetRef.fromRow(row)};

    return [
      for (final row in rows)
        OcptElement.fromRow(
          row: row,
          sceneLinks: linksByElementId[row.id] ?? const [],
          roleLinks: roleLinksByElementId[row.id] ?? const [],
          photo: assetsById[row.photoAssetId],
        ),
    ];
  }

  /// Creates a new element named [name], of [category] and [sourceKind], in [database], appended
  /// at the end of the catalogue, and returns its freshly generated id.
  ///
  /// The element's code is generated here rather than left empty (`ocptElementCodeOf`, numbered
  /// within [category] from the codes the catalogue already carries): every element gets one
  /// without anybody typing it, and a caller that creates an element as a side effect of something
  /// else — the breakdown adding an item from a scene — cannot forget to. It is a default, not a
  /// decision: the sheet's own field overwrites it.
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
            code: Value(
              ocptElementCodeOf(
                category: category,
                existingCodes: existing.map((row) => row.code),
              ),
            ),
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
  /// `code` is not among the arguments: it is the app's own, minted by [createElement] and rewritten
  /// **here and nowhere else**, whenever [category] genuinely changes (see
  /// [_codeAfterCategoryChangeOf]). A code says which department an item comes from, and nobody can
  /// type one, so an element that moves from props to vehicles and keeps `PRP-4` would be lying
  /// about itself with no way for the user to correct it. Owning that rule here rather than in a
  /// bloc is what makes it true of every mode: the breakdown's own category chips get it without
  /// knowing it exists.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateElement({
    required OcptProjectDatabase database,
    required String elementId,
    Value<OcptElementCategory> category = const Value.absent(),
    Value<String> subCategory = const Value.absent(),
    Value<String> name = const Value.absent(),
    Value<String> quantity = const Value.absent(),
    Value<OcptElementSourceKind> sourceKind = const Value.absent(),
    Value<OcptElementStatus> status = const Value.absent(),
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

    final code = await _codeAfterCategoryChangeOf(
      database: database,
      elementId: elementId,
      category: category,
    );

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
        status: status,
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

  /// The code element [elementId] is given as [category] is written onto it: a freshly generated
  /// one (`ocptElementCodeOf`, numbered within the category it is joining), or [Value.absent] when
  /// there is nothing to rewrite.
  ///
  /// Nothing is rewritten when [category] is absent (the caller is changing something else
  /// entirely), when the element has disappeared underneath (a stale write), or when the category
  /// written is the one the element already had — the last of the three being the one that matters:
  /// [ocptElementCodeOf] answers "the first free number", so regenerating `PRP-2` inside props would
  /// hand it `PRP-4` for no reason at all.
  Future<Value<String>> _codeAfterCategoryChangeOf({
    required OcptProjectDatabase database,
    required String elementId,
    required Value<OcptElementCategory> category,
  }) async {
    if (!category.present) {
      return const Value.absent();
    }

    final rows = await _liveElementRows(database);
    final current = rows.where((row) => row.id == elementId).firstOrNull;
    if (current == null || current.category == category.value) {
      return const Value.absent();
    }

    return Value(
      ocptElementCodeOf(
        category: category.value,
        // The element's own code is left out: it is about to stop belonging to the category it is
        // numbered in, so it must not reserve a number there — and it can never collide with the
        // numbers of the category it is joining.
        existingCodes: [
          for (final row in rows)
            if (row.id != elementId) row.code,
        ],
      ),
    );
  }

  /// Tombstones element [elementId] in [database] and both kinds of link onto it — the
  /// `scene_elements` ones and the `role_elements` ones — along with it.
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
        database.ocptRoleElementsTable,
      )..where((table) => table.elementId.equals(elementId))).write(
        const OcptRoleElementsTableCompanion(isDeleted: Value(true)),
      );
      // The photo goes with the element: nothing can reach that row any more, which is what makes
      // it an orphan rather than history. Its `photoAssetId` is left pointing at the tombstone,
      // exactly as every other tombstoned link keeps its ids.
      await _tombstoneElementPhoto(database: database, elementId: elementId);
      await (database.update(
        database.ocptElementsTable,
      )..where((table) => table.id.equals(elementId))).write(
        const OcptElementsTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// References the file at [path] as element [elementId]'s photo, replacing whichever file it
  /// referenced before, and returns the freshly generated id of the `assets` row.
  ///
  /// The replaced photo's row is tombstoned in the same transaction, for the reason
  /// `OcptPeopleService.setPersonPhoto` gives: an element has one photo, so a row nothing points at
  /// any more is an orphan rather than history. **No byte of the file is read, copied or written**
  /// — see `docs/adr/0013-binary-assets-referenced-by-path.md`.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> setElementPhoto({
    required OcptProjectDatabase database,
    required String elementId,
    required String path,
    String label = "",
  }) async {
    if (database.refusesUserWrite("setElementPhoto")) {
      return null;
    }

    return database.transaction(() async {
      await _tombstoneElementPhoto(database: database, elementId: elementId);

      final id = await assetsService.insertAsset(
        database: database,
        kind: OcptAssetKind.elementPhoto,
        elementId: elementId,
        path: path,
        label: label,
      );

      await (database.update(
        database.ocptElementsTable,
      )..where((table) => table.id.equals(elementId))).write(
        OcptElementsTableCompanion(photoAssetId: Value(id)),
      );

      return id;
    });
  }

  /// Drops element [elementId]'s reference to its photo: the `assets` row is tombstoned and
  /// `photoAssetId` goes back to null. The file itself is never touched.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> clearElementPhoto({
    required OcptProjectDatabase database,
    required String elementId,
  }) async {
    if (database.refusesUserWrite("clearElementPhoto")) {
      return;
    }

    await database.transaction(() async {
      await _tombstoneElementPhoto(database: database, elementId: elementId);

      await (database.update(
        database.ocptElementsTable,
      )..where((table) => table.id.equals(elementId))).write(
        const OcptElementsTableCompanion(photoAssetId: Value(null)),
      );
    });
  }

  /// Tombstones whichever `assets` row element [elementId] currently names as its photo, if any.
  /// Leaves `photoAssetId` alone: both callers write it themselves.
  Future<void> _tombstoneElementPhoto({
    required OcptProjectDatabase database,
    required String elementId,
  }) async {
    final row = await (database.select(
      database.ocptElementsTable,
    )..where((table) => table.id.equals(elementId))).getSingleOrNull();

    final photoAssetId = row?.photoAssetId;
    if (photoAssetId == null) {
      return;
    }

    await assetsService.tombstoneAsset(database: database, assetId: photoAssetId);
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

  /// Links role [roleId] to element [elementId], with optional [notes], and returns the id of the
  /// link — the one that already said so when there was one, a freshly generated one otherwise.
  ///
  /// [addSceneElement]'s sibling and follows exactly its rules: a pair the role already carries is
  /// a no-op rather than a second row, a link removed earlier is **revived** rather than
  /// duplicated, and a revived link keeps the note it held — so [notes] only ever seeds a row that
  /// is genuinely being inserted.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addRoleElement({
    required OcptProjectDatabase database,
    required String roleId,
    required String elementId,
    String notes = "",
  }) async {
    if (database.refusesUserWrite("addRoleElement")) {
      return null;
    }

    return database.transaction(() async {
      final existingLinks =
          await (database.select(database.ocptRoleElementsTable)..where(
                (table) => table.roleId.equals(roleId) & table.elementId.equals(elementId),
              ))
              .get();

      OcptRoleElementRow? droppedLink;
      for (final link in existingLinks) {
        if (!link.isDeleted) {
          return link.id;
        }

        droppedLink ??= link;
      }

      if (droppedLink != null) {
        await (database.update(
          database.ocptRoleElementsTable,
        )..where((table) => table.id.equals(droppedLink!.id))).write(
          const OcptRoleElementsTableCompanion(isDeleted: Value(false)),
        );

        return droppedLink.id;
      }

      final id = const Uuid().v4();
      await database
          .into(database.ocptRoleElementsTable)
          .insert(
            OcptRoleElementsTableCompanion.insert(
              id: id,
              roleId: roleId,
              elementId: elementId,
              notes: Value(notes),
            ),
          );

      return id;
    });
  }

  /// Updates the notes of role ↔ element link [id] in [database].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateRoleElement({
    required OcptProjectDatabase database,
    required String id,
    required String notes,
  }) async {
    if (database.refusesUserWrite("updateRoleElement")) {
      return;
    }

    await (database.update(
      database.ocptRoleElementsTable,
    )..where((table) => table.id.equals(id) & table.isDeleted.not())).write(
      OcptRoleElementsTableCompanion(notes: Value(notes)),
    );
  }

  /// Removes the role ↔ element link [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeRoleElement({
    required OcptProjectDatabase database,
    required String id,
  }) async {
    if (database.refusesUserWrite("removeRoleElement")) {
      return;
    }

    await (database.update(
      database.ocptRoleElementsTable,
    )..where((table) => table.id.equals(id))).write(
      const OcptRoleElementsTableCompanion(isDeleted: Value(true)),
    );
  }

  /// Tombstones every `role_elements` row naming role [roleId], the cascade
  /// `OcptRoleIndexService.deleteRole` reaches for once it has decided the role goes.
  ///
  /// **Unguarded**, exactly as `OcptAssetsService`'s own cascades are: its only caller has already
  /// refused the write on a preview connection and is already inside the transaction removing the
  /// role, so a second guard here would only be able to disagree with the first.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneRoleLinksOfRole({
    required OcptProjectDatabase database,
    required String roleId,
  }) => (database.update(
    database.ocptRoleElementsTable,
  )..where((table) => table.roleId.equals(roleId))).write(
    const OcptRoleElementsTableCompanion(isDeleted: Value(true)),
  );

  /// Tombstones every live `scene_elements` row naming any of [sceneIds]: `scene_elements` is this
  /// service's table, not `OcptBreakdownService`'s, so its own cascade
  /// (`OcptBreakdownService.tombstoneBreakdownOfScenes`) reaches for this narrow helper rather than
  /// writing the table itself — the element these links point at is, of course, untouched.
  ///
  /// **Unguarded**, exactly as [tombstoneRoleLinksOfRole] is: its only caller has already refused
  /// the write on a preview connection and is already inside the transaction removing the episode,
  /// so a second guard here would only be able to disagree with the first.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneSceneElementsOfScenes({
    required OcptProjectDatabase database,
    required List<String> sceneIds,
  }) async {
    if (sceneIds.isEmpty) {
      return;
    }

    await (database.update(
      database.ocptSceneElementsTable,
    )..where((table) => table.sceneId.isIn(sceneIds))).write(
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

  /// The live `role_elements` links of every element of [elementIds], keyed by element id and
  /// ordered by the cast's own `sortKey` order.
  ///
  /// Ordered by the role rather than by anything the link carries, for the reason
  /// [_liveSceneLinksByElementId] is ordered by the scene: `role_elements` has no `sortKey`, and
  /// the only order a reader expects of "the roles wearing this coat" is the one the cast list
  /// reads in. A link onto a **tombstoned role** is left out rather than reported, exactly as a
  /// link onto a vanished scene is: a deleted role is gone from every list the mode shows, and a
  /// chip naming it would be the only place it survived.
  Future<Map<String, List<OcptRoleElementLink>>> _liveRoleLinksByElementId({
    required OcptProjectDatabase database,
    required List<String> elementIds,
  }) async {
    if (elementIds.isEmpty) {
      return const {};
    }

    final linkRows =
        await (database.select(database.ocptRoleElementsTable)..where(
              (table) => table.elementId.isIn(elementIds) & table.isDeleted.not(),
            ))
            .get();
    if (linkRows.isEmpty) {
      return const {};
    }

    final roleRows =
        await (database.select(database.ocptRolesTable)..where(
              (table) =>
                  table.id.isIn(linkRows.map((row) => row.roleId).toList(growable: false)) &
                  table.isDeleted.not(),
            ))
            .get();

    final sortKeyByRoleId = {for (final row in roleRows) row.id: row.sortKey};

    final linksByElementId = <String, List<OcptRoleElementLink>>{};
    for (final link in linkRows) {
      if (sortKeyByRoleId.containsKey(link.roleId)) {
        linksByElementId
            .putIfAbsent(link.elementId, () => [])
            .add(OcptRoleElementLink.fromRow(link));
      }
    }

    for (final links in linksByElementId.values) {
      links.sort((a, b) => sortKeyByRoleId[a.roleId]!.compareTo(sortKeyByRoleId[b.roleId]!));
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
