// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_rows.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_set_code.dart';
import 'package:uuid/uuid.dart';

/// The sets of a location and the links between a scene and the sets it is shot in: creating,
/// editing, moving, duplicating, ordering and deleting a set, and assigning a scene to one.
///
/// What `OcptLocationsService` forwards to; that service documents the locations model whole.
abstract final class OcptLocationsSetOps {
  /// Create a new set named [name] inside location [locationId], appended at the end of that
  /// location's sets, and return its freshly generated id.
  ///
  /// The set's code is generated here and nowhere else (`ocptSetCodeOf`, the first letters no live
  /// set of the **project** already carries), exactly as `OcptElementsService.createElement`
  /// generates an element's: it is the app's own identifier for the set rather than something the
  /// user is asked for, so no sheet offers to type it and a caller minting a set as a side effect
  /// of something else — the breakdown naming a décor while reading — cannot end up with one
  /// without a code.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> createSet({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String locationId,
    required String name,
  }) async {
    if (database.refusesUserWrite("createSet")) {
      return null;
    }

    final existing = await OcptLocationsRows.liveSetRowsOfLocation(
      database: database,
      locationId: locationId,
    );
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSetsTable,
        rowId: id,
        current: null,
        next: OcptSetRow(
          id: id,
          locationId: locationId,
          code: ocptSetCodeOf(existingCodes: await OcptLocationsRows.liveSetCodes(database)),
          name: name,
          notes: '',
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Update the fields of set [setId] in [database] that are passed as something other than
  /// [Value.absent].
  ///
  /// `code` is not among them, and neither is `locationId`, for the same kind of reason: a set's
  /// code is the app's own ([createSet] mints it, nothing ever rewrites it), and its location is
  /// what it belongs to ([moveSetToLocation] hands it over). Neither is a field of the sheet.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateSet({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String setId,
    Value<String> name = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSet")) {
      return;
    }

    final companion = OcptSetsTableCompanion(name: name, notes: notes);

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptSetsTable,
      )..where((table) => table.id.equals(setId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Move set [setId] to location [locationId], appended at the end of that location's sets.
  ///
  /// The one column [updateSet] deliberately does not write: a set's location is what it *is*, not
  /// one of its fields, and a set moves as a whole — it leaves the sheet it was being edited on.
  /// Its scenes, its notes and its code come along untouched, which is the whole point: a set filed
  /// under the wrong house is repaired rather than deleted and typed again, `deleteSet` tombstoning
  /// its `scene_sets` links along with it.
  ///
  /// A fresh `sortKey` is allocated in the destination: the one it held ranked it among its former
  /// siblings, and means nothing among its new ones.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> moveSetToLocation({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String setId,
    required String locationId,
  }) async {
    if (database.refusesUserWrite("moveSetToLocation")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptSetsTable,
      )..where((table) => table.id.equals(setId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final existing = await OcptLocationsRows.liveSetRowsOfLocation(
        database: database,
        locationId: locationId,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWith(
          locationId: locationId,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstone set [setId] in [database], the `scene_sets` links onto it and its floor plan
  /// (`floorPlanService.tombstoneFloorPlanRowsOfSet` — its own plan row, symbols and arrows) along
  /// with it.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> deleteSet({
    required OcptDeviceIdGetter deviceId,
    required OcptFloorPlanService floorPlanService,
    required OcptProjectDatabase database,
    required String setId,
  }) async {
    if (database.refusesUserWrite("deleteSet")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final sceneSetRows = await (database.select(
        database.ocptSceneSetsTable,
      )..where((table) => table.setId.equals(setId) & table.isDeleted.not())).get();
      for (final row in sceneSetRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptSceneSetsTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await floorPlanService.tombstoneFloorPlanRowsOfSet(
        database: database,
        setId: setId,
        stamps: stamps,
      );

      final current = await (database.select(
        database.ocptSetsTable,
      )..where((table) => table.id.equals(setId))).getSingleOrNull();
      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptSetsTable,
          rowId: setId,
          current: current,
          next: current.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Create a new set named [name], in the same location as [sourceSetId], and return its freshly
  /// generated id — the "mint a Resources set" half of "duplicate this set", which
  /// `OcptShotListBloc` puts together with
  /// `OcptFloorPlanService.duplicateSet` (copying the plan) and [assignSceneToSet] (linking it to
  /// the calling scene): see `OcptFloorPlanService.duplicateSet`'s own doc comment for why the
  /// three steps live on three different calls rather than one. Returns null, doing nothing, if
  /// [sourceSetId] doesn't name a live set.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> createSiblingSet({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String sourceSetId,
    required String name,
  }) async {
    if (database.refusesUserWrite("createSiblingSet")) {
      return null;
    }

    final source = await (database.select(
      database.ocptSetsTable,
    )..where((table) => table.id.equals(sourceSetId) & table.isDeleted.not())).getSingleOrNull();
    if (source == null) {
      return null;
    }

    return createSet(
      deviceId: deviceId,
      database: database,
      locationId: source.locationId,
      name: name,
    );
  }

  /// Duplicate set [sourceSetId] into a fresh Resources set named [name] — in the same location,
  /// its plan's own set-scope symbols copied, linked to scene [sceneId] — as **one atomic
  /// operation**, run inside a single transaction: the three
  /// steps [createSiblingSet]/`floorPlanService.duplicateSet`/[assignSceneToSet]
  /// `OcptShotListBloc._onSetDuplicationRequested` used to call one by one now happen here, so a
  /// failure at any step (an exception thrown by any of the three) rolls back every one of them —
  /// no orphan set left minted with nothing copied onto it or linked to nothing.
  ///
  /// Drift nests a `transaction()` opened while another is already active as its own **savepoint**:
  /// an exception aborts and rolls back that inner savepoint alone before propagating outward, so a
  /// failure inside [createSiblingSet], `floorPlanService.duplicateSet` or [assignSceneToSet] —
  /// none of which is caught here — keeps unwinding until it reaches *this* method's own outermost
  /// `transaction()` call below, which is what actually discards the whole thing.
  ///
  /// Returns null, having written nothing durable, when [sourceSetId] doesn't name a live set
  /// ([createSiblingSet] itself returning null) or when [assignSceneToSet] somehow refuses the link
  /// (defensive only — `refusesUserWrite` was already checked above, before either sibling call
  /// ever ran, so this can only trip if the connection turned read-only mid-transaction).
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> duplicateSetForScene({
    required OcptDeviceIdGetter deviceId,
    required OcptFloorPlanService floorPlanService,
    required OcptProjectDatabase database,
    required String sourceSetId,
    required String name,
    required String sceneId,
  }) async {
    if (database.refusesUserWrite("duplicateSetForScene")) {
      return null;
    }

    return database.transaction(() async {
      final newSetId = await createSiblingSet(
        deviceId: deviceId,
        database: database,
        sourceSetId: sourceSetId,
        name: name,
      );
      if (newSetId == null) {
        return null;
      }

      await floorPlanService.duplicateSet(
        database: database,
        sourceSetId: sourceSetId,
        destinationSetId: newSetId,
      );

      final linkId = await assignSceneToSet(
        deviceId: deviceId,
        database: database,
        sceneId: sceneId,
        setId: newSetId,
      );
      if (linkId == null) {
        // Defensive: nothing observed in tests reaches this path (see this method's own doc
        // comment), but leaving a freshly minted, freshly copied set with no link at all would be
        // exactly the orphan this method exists to rule out — throwing is what rolls the whole
        // transaction back rather than returning a set id the caller would have to clean up itself.
        throw StateError(
          "Could not link duplicated set $newSetId (from $sourceSetId) to scene $sceneId",
        );
      }

      return newSetId;
    });
  }

  /// Move set [setId] to [newPosition] (0-based) within location [locationId]'s sets, by giving
  /// it a `sortKey` sitting between the two sets it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> reorderSet({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String locationId,
    required String setId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderSet")) {
      return;
    }

    await database.transaction(() async {
      final rows = await OcptLocationsRows.liveSetRowsOfLocation(
        database: database,
        locationId: locationId,
      );
      final current = rows.where((row) => row.id == setId).firstOrNull;
      if (current == null) {
        return;
      }

      final others = rows.where((row) => row.id != setId).toList(growable: false);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Say scene [sceneId] is also shot in set [setId], and return the id of the link.
  ///
  /// A scene may be shot in **several** sets (see `OcptSceneSetsTable`), so this adds a link beside
  /// the ones the scene already carries rather than moving it: dropping a set is
  /// [removeSceneFromSet]'s job, and saying "also here" must never silently answer "no longer
  /// there".
  ///
  /// Saying the same thing twice writes nothing new — the live link's id comes back — and a link
  /// the user had dropped is revived rather than duplicated, so a scene never ends up holding two
  /// rows that say the same thing.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> assignSceneToSet({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String sceneId,
    required String setId,
  }) async {
    if (database.refusesUserWrite("assignSceneToSet")) {
      return null;
    }

    return database.transaction(() async {
      final existingLinks = await (database.select(
        database.ocptSceneSetsTable,
      )..where((table) => table.sceneId.equals(sceneId) & table.setId.equals(setId))).get();

      OcptSceneSetRow? droppedLink;
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
          table: database.ocptSceneSetsTable,
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
        table: database.ocptSceneSetsTable,
        rowId: id,
        current: null,
        next: OcptSceneSetRow(id: id, sceneId: sceneId, setId: setId, isDeleted: false),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// Remove the link saying scene [sceneId] is shot in set [setId], leaving whatever other sets
  /// that scene is shot in alone. A no-op when there is no such live link.
  ///
  /// Takes the two ids the caller has rather than the link's own: the set sheet lists a scene, and
  /// "this scene is not shot here" is what the user answers — the row carrying it is an
  /// implementation detail of that answer.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> removeSceneFromSet({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String sceneId,
    required String setId,
  }) async {
    if (database.refusesUserWrite("removeSceneFromSet")) {
      return;
    }

    await database.transaction(() async {
      final current =
          await (database.select(database.ocptSceneSetsTable)..where(
                (table) =>
                    table.sceneId.equals(sceneId) &
                    table.setId.equals(setId) &
                    table.isDeleted.not(),
              ))
              .getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSceneSetsTable,
        rowId: current.id,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Get the id of set [setId]'s own **first** live linked scene, in screenplay order — episode
  /// order
  /// first (`screenplays.sortKey`), then that episode's own scene order (`scenes.position`) — and
  /// the id of the episode (screenplay) it belongs to, or null while [setId] carries no live link
  /// at all. What the Resources location sheet's own `Open in shot list`
  /// (`OcptShotListRevealRequest`) reveals.
  ///
  /// Reads `screenplays`/`scenes` directly rather than through `OcptScreenplayService`
  /// (dependencies never reference their dependents: that service already depends on this one, for
  /// `loadScenes`'s own `episodeNumber` parameter) — the ordering this needs is a plain `sortKey`/
  /// `position` sort, nothing an episode's own richer model would add.
  static Future<({String sceneId, String screenplayId})?> firstLinkedSceneOf({
    required OcptProjectDatabase database,
    required String setId,
  }) async {
    final linkRows = await (database.select(
      database.ocptSceneSetsTable,
    )..where((table) => table.setId.equals(setId) & table.isDeleted.not())).get();
    if (linkRows.isEmpty) {
      return null;
    }

    final sceneIds = linkRows.map((row) => row.sceneId).toSet();
    final sceneRows = await (database.select(
      database.ocptScenesTable,
    )..where((table) => table.id.isIn(sceneIds) & table.isDeleted.not())).get();
    if (sceneRows.isEmpty) {
      return null;
    }

    final screenplayIds = sceneRows.map((row) => row.screenplayId).toSet();
    final screenplayRows = await (database.select(
      database.ocptScreenplaysTable,
    )..where((table) => table.id.isIn(screenplayIds) & table.isDeleted.not())).get();
    final sortKeyByScreenplayId = {for (final row in screenplayRows) row.id: row.sortKey};

    final sorted = sceneRows.toList()
      ..sort((a, b) {
        final byEpisode = (sortKeyByScreenplayId[a.screenplayId] ?? "").compareTo(
          sortKeyByScreenplayId[b.screenplayId] ?? "",
        );
        return byEpisode != 0 ? byEpisode : a.position.compareTo(b.position);
      });

    final first = sorted.first;
    return (sceneId: first.id, screenplayId: first.screenplayId);
  }

  /// Tombstone every live `scene_sets` row naming any of [sceneIds]: `scene_sets` is this
  /// service's table, not `OcptBreakdownService`'s, so its own cascade
  /// (`OcptBreakdownService.tombstoneBreakdownOfScenes`) reaches for this narrow helper rather than
  /// writing the table itself — the set these links point at is, of course, untouched.
  ///
  /// **Unguarded**, exactly as `OcptElementsService.tombstoneRoleLinksOfRole` is: its only caller
  /// has already refused the write on a preview connection and is already inside the transaction
  /// removing the episode, so a second guard here would only be able to disagree with the first.
  /// Stamps through [stamps] — that caller's own instance — rather than resolving a device id of
  /// its own.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  static Future<void> tombstoneSceneSetsOfScenes({
    required OcptProjectDatabase database,
    required List<String> sceneIds,
    required OcptRowStampService? stamps,
  }) async {
    if (sceneIds.isEmpty) {
      return;
    }

    final rows = await (database.select(
      database.ocptSceneSetsTable,
    )..where((table) => table.sceneId.isIn(sceneIds) & table.isDeleted.not())).get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSceneSetsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }
}
