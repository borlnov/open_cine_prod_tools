// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over `locations`, their `sets` and the `scene_sets` links between a scene and the set it is
/// shot in.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`**, for both `locations` and `sets` — see
/// `OcptShotListService`'s own doc comment. `scene_sets` carries no `sortKey` at all: a scene's sets
/// are, in practice, a set of at most one the user picks, not a list they reorder (see
/// `OcptSceneSetsTable`'s own doc comment).
///
/// This service does not decide *which* set a scene's heading suggests — §4.5 of the plan this
/// service ships under is explicit that the suggestion is never applied automatically, only
/// offered, which makes it the mode's job once it exists: [addSceneSet]/[removeSceneSet] are the
/// plain link CRUD the mode calls once the user has picked (or confirmed) one.
class OcptLocationsService {
  /// Class constructor
  const OcptLocationsService();

  /// Loads every live location of [database], in `sortKey` order, each joined with its live
  /// [OcptSet]s, also in `sortKey` order.
  Future<List<OcptLocation>> loadLocations({required OcptProjectDatabase database}) async {
    final locationRows = await _liveLocationRows(database);
    final locationIds = locationRows.map((row) => row.id).toList(growable: false);

    final setRows = locationIds.isEmpty
        ? const <OcptSetRow>[]
        : await (database.select(database.ocptSetsTable)
                ..where((table) => table.locationId.isIn(locationIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final setsByLocationId = <String, List<OcptSet>>{};
    for (final row in setRows) {
      setsByLocationId.putIfAbsent(row.locationId, () => []).add(OcptSet.fromRow(row));
    }

    return [
      for (final row in locationRows)
        OcptLocation.fromRow(row: row, sets: setsByLocationId[row.id] ?? const []),
    ];
  }

  /// Creates a new location named [name] in [database], appended at the end, and returns its
  /// freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createLocation({
    required OcptProjectDatabase database,
    required String name,
  }) async {
    if (database.refusesUserWrite("createLocation")) {
      return null;
    }

    final existing = await _liveLocationRows(database);
    final id = const Uuid().v4();

    await database
        .into(database.ocptLocationsTable)
        .insert(
          OcptLocationsTableCompanion.insert(
            id: id,
            name: name,
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of location [locationId] in [database] that are passed as something other
  /// than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderLocation] and [deleteLocation].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateLocation({
    required OcptProjectDatabase database,
    required String locationId,
    Value<String> name = const Value.absent(),
    Value<int> colorIndex = const Value.absent(),
    Value<String> addressLine1 = const Value.absent(),
    Value<String> addressLine2 = const Value.absent(),
    Value<String> postalCode = const Value.absent(),
    Value<String> city = const Value.absent(),
    Value<String> region = const Value.absent(),
    Value<String> country = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<String?> contactPersonId = const Value.absent(),
    Value<String> contactNotes = const Value.absent(),
    Value<OcptPermitStatus> permitStatus = const Value.absent(),
    Value<String> permitLabel = const Value.absent(),
    Value<DateTime?> permitDate = const Value.absent(),
    Value<String?> permitAssetId = const Value.absent(),
    Value<String> parkingNotes = const Value.absent(),
    Value<String> powerNotes = const Value.absent(),
    Value<String> facilitiesNotes = const Value.absent(),
    Value<String> constraintsNotes = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateLocation")) {
      return;
    }

    await (database.update(
      database.ocptLocationsTable,
    )..where((table) => table.id.equals(locationId) & table.isDeleted.not())).write(
      OcptLocationsTableCompanion(
        name: name,
        colorIndex: colorIndex,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        postalCode: postalCode,
        city: city,
        region: region,
        country: country,
        latitude: latitude,
        longitude: longitude,
        contactPersonId: contactPersonId,
        contactNotes: contactNotes,
        permitStatus: permitStatus,
        permitLabel: permitLabel,
        permitDate: permitDate,
        permitAssetId: permitAssetId,
        parkingNotes: parkingNotes,
        powerNotes: powerNotes,
        facilitiesNotes: facilitiesNotes,
        constraintsNotes: constraintsNotes,
        notes: notes,
      ),
    );
  }

  /// Tombstones location [locationId] in [database], its sets and the `scene_sets` links onto
  /// those sets along with it.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteLocation({
    required OcptProjectDatabase database,
    required String locationId,
  }) async {
    if (database.refusesUserWrite("deleteLocation")) {
      return;
    }

    await database.transaction(() async {
      final setRows =
          await (database.select(database.ocptSetsTable)..where(
                (table) => table.locationId.equals(locationId) & table.isDeleted.not(),
              ))
              .get();
      final setIds = setRows.map((row) => row.id).toList(growable: false);

      if (setIds.isNotEmpty) {
        await (database.update(
          database.ocptSceneSetsTable,
        )..where((table) => table.setId.isIn(setIds))).write(
          const OcptSceneSetsTableCompanion(isDeleted: Value(true)),
        );
        await (database.update(
          database.ocptSetsTable,
        )..where((table) => table.locationId.equals(locationId))).write(
          const OcptSetsTableCompanion(isDeleted: Value(true)),
        );
      }

      await (database.update(
        database.ocptLocationsTable,
      )..where((table) => table.id.equals(locationId))).write(
        const OcptLocationsTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// Moves location [locationId] to [newPosition] (0-based), by giving it a `sortKey` sitting
  /// between the two locations it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderLocation({
    required OcptProjectDatabase database,
    required String locationId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderLocation")) {
      return;
    }

    await database.transaction(() async {
      final others = (await _liveLocationRows(database))
        ..removeWhere((row) => row.id == locationId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptLocationsTable,
      )..where((table) => table.id.equals(locationId))).write(
        OcptLocationsTableCompanion(sortKey: Value(sortKey)),
      );
    });
  }

  /// Creates a new set named [name] inside location [locationId], appended at the end of that
  /// location's sets, and returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createSet({
    required OcptProjectDatabase database,
    required String locationId,
    required String name,
  }) async {
    if (database.refusesUserWrite("createSet")) {
      return null;
    }

    final existing = await _liveSetRowsOfLocation(database: database, locationId: locationId);
    final id = const Uuid().v4();

    await database
        .into(database.ocptSetsTable)
        .insert(
          OcptSetsTableCompanion.insert(
            id: id,
            locationId: locationId,
            name: name,
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of set [setId] in [database] that are passed as something other than
  /// [Value.absent].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateSet({
    required OcptProjectDatabase database,
    required String setId,
    Value<String> code = const Value.absent(),
    Value<String> name = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSet")) {
      return;
    }

    await (database.update(
      database.ocptSetsTable,
    )..where((table) => table.id.equals(setId) & table.isDeleted.not())).write(
      OcptSetsTableCompanion(code: code, name: name, notes: notes),
    );
  }

  /// Tombstones set [setId] in [database] and the `scene_sets` links onto it along with it.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteSet({required OcptProjectDatabase database, required String setId}) async {
    if (database.refusesUserWrite("deleteSet")) {
      return;
    }

    await database.transaction(() async {
      await (database.update(
        database.ocptSceneSetsTable,
      )..where((table) => table.setId.equals(setId))).write(
        const OcptSceneSetsTableCompanion(isDeleted: Value(true)),
      );
      await (database.update(
        database.ocptSetsTable,
      )..where((table) => table.id.equals(setId))).write(
        const OcptSetsTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// Moves set [setId] to [newPosition] (0-based) within location [locationId]'s sets, by giving
  /// it a `sortKey` sitting between the two sets it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderSet({
    required OcptProjectDatabase database,
    required String locationId,
    required String setId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderSet")) {
      return;
    }

    await database.transaction(() async {
      final others =
          (await _liveSetRowsOfLocation(database: database, locationId: locationId))
            ..removeWhere((row) => row.id == setId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptSetsTable,
      )..where((table) => table.id.equals(setId))).write(
        OcptSetsTableCompanion(sortKey: Value(sortKey)),
      );
    });
  }

  /// Links scene [sceneId] to set [setId], and returns the freshly generated id of the link. Does
  /// nothing (returns null) if that exact link already exists and is live.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addSceneSet({
    required OcptProjectDatabase database,
    required String sceneId,
    required String setId,
  }) async {
    if (database.refusesUserWrite("addSceneSet")) {
      return null;
    }

    final existing =
        await (database.select(database.ocptSceneSetsTable)..where(
              (table) =>
                  table.sceneId.equals(sceneId) &
                  table.setId.equals(setId) &
                  table.isDeleted.not(),
            ))
            .getSingleOrNull();
    if (existing != null) {
      return null;
    }

    final id = const Uuid().v4();
    await database
        .into(database.ocptSceneSetsTable)
        .insert(
          OcptSceneSetsTableCompanion.insert(id: id, sceneId: sceneId, setId: setId),
        );

    return id;
  }

  /// Removes the scene ↔ set link [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeSceneSet({required OcptProjectDatabase database, required String id}) async {
    if (database.refusesUserWrite("removeSceneSet")) {
      return;
    }

    await (database.update(
      database.ocptSceneSetsTable,
    )..where((table) => table.id.equals(id))).write(
      const OcptSceneSetsTableCompanion(isDeleted: Value(true)),
    );
  }

  /// The ids of every set scene [sceneId] is currently linked to, in no particular order (see the
  /// class doc comment: `scene_sets` carries no `sortKey`).
  Future<List<String>> setIdsOfScene({
    required OcptProjectDatabase database,
    required String sceneId,
  }) async {
    final rows =
        await (database.select(database.ocptSceneSetsTable)..where(
              (table) => table.sceneId.equals(sceneId) & table.isDeleted.not(),
            ))
            .get();
    return rows.map((row) => row.setId).toList(growable: false);
  }

  /// Every live location row of [database], ordered by `sortKey`.
  Future<List<OcptLocationRow>> _liveLocationRows(OcptProjectDatabase database) =>
      (database.select(database.ocptLocationsTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Every live set row of location [locationId], ordered by `sortKey`.
  Future<List<OcptSetRow>> _liveSetRowsOfLocation({
    required OcptProjectDatabase database,
    required String locationId,
  }) => (database.select(database.ocptSetsTable)
        ..where((table) => table.locationId.equals(locationId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();
}
