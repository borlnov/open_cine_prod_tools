// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_set_code.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';
import 'package:uuid/uuid.dart';

/// CRUD over `locations`, their `sets`, the `scene_sets` links between a scene and the sets it is
/// shot in, the `location_availabilities` windows a location may be shot in, and which files a
/// location references (its scouting photos and its permit document).
///
/// The `assets` rows behind those references are [OcptAssetsService]'s: this service decides
/// *that* a location has a permit document and which one, and that service is what mints and
/// tombstones the row. The two halves are written in one transaction here, since a location
/// pointing at a row that does not exist yet is not a state a reader may see.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`**, for `locations`, `sets` and a location's photos — see
/// `OcptShotListService`'s own doc comment. `scene_sets` carries no `sortKey` at all: a scene's
/// sets are an unordered set of answers rather than a list the user reorders (see
/// [assignSceneToSet] and `OcptSceneSetsTable`'s own doc comment), and the scenes read back for a
/// set are ordered by the screenplay's own scene order instead.
///
/// This service does not decide *which* set a scene's heading suggests — §4.5 of the plan this
/// service ships under is explicit that the suggestion is never applied automatically, only
/// offered: `ocptSceneSetSuggestionOf` computes it and the resources mode offers it, while
/// [assignSceneToSet]/[removeSceneFromSet] are the plain link writes the mode calls once the user
/// has picked (or confirmed) one.
class OcptLocationsService {
  /// The service minting and tombstoning the `assets` rows a location owns. Held rather than
  /// reached for so a test can hand in its own, exactly as `OcptBreakdownService` holds the two
  /// services it composes.
  final OcptAssetsService assetsService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter].
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptLocationsService({required this.assetsService, required this.deviceId});

  /// Loads every live location of [database], in `sortKey` order, each joined with its live
  /// [OcptSet]s and scouting photos (both in `sortKey` order), with its availability windows (in
  /// start-date order, the order they are read in rather than one the user chose) and with the
  /// document its `permitAssetId` resolves to.
  ///
  /// A set's `sceneIds` name **live scenes only**: a `scene_sets` row whose scene was tombstoned by
  /// the last reconciliation is skipped rather than shown as a scene that no longer exists, and
  /// comes back on its own if the scene does — `OcptSceneIndexService` reuses a scene's id for as
  /// long as it can match it.
  Future<List<OcptLocation>> loadLocations({required OcptProjectDatabase database}) async {
    final locationRows = await _liveLocationRows(database);
    final locationIds = locationRows.map((row) => row.id).toList(growable: false);

    final setRows = locationIds.isEmpty
        ? const <OcptSetRow>[]
        : await (database.select(database.ocptSetsTable)
                ..where((table) => table.locationId.isIn(locationIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final sceneIdsBySetId = await _liveSceneIdsBySetId(
      database: database,
      setIds: setRows.map((row) => row.id).toList(growable: false),
    );

    final assetRows = locationIds.isEmpty
        ? const <OcptAssetRow>[]
        : await (database.select(database.ocptAssetsTable)
                ..where((table) => table.locationId.isIn(locationIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final setsByLocationId = <String, List<OcptSet>>{};
    for (final row in setRows) {
      setsByLocationId
          .putIfAbsent(row.locationId, () => [])
          .add(OcptSet.fromRow(row: row, sceneIds: sceneIdsBySetId[row.id] ?? const []));
    }

    final availabilityRows = locationIds.isEmpty
        ? const <OcptLocationAvailabilityRow>[]
        : await (database.select(database.ocptLocationAvailabilitiesTable)
                ..where((table) => table.locationId.isIn(locationIds) & table.isDeleted.not())
                ..orderBy([
                  (table) => OrderingTerm.asc(table.startDate),
                  (table) => OrderingTerm.asc(table.endDate),
                ]))
              .get();

    final availabilitiesByLocationId = <String, List<OcptLocationAvailability>>{};
    for (final row in availabilityRows) {
      availabilitiesByLocationId
          .putIfAbsent(row.locationId, () => [])
          .add(OcptLocationAvailability.fromRow(row));
    }

    final photosByLocationId = <String, List<OcptAssetRef>>{};
    final assetsById = <String, OcptAssetRef>{};
    for (final row in assetRows) {
      final asset = OcptAssetRef.fromRow(row);
      assetsById[asset.id] = asset;
      if (row.kind == OcptAssetKind.locationPhoto) {
        photosByLocationId.putIfAbsent(row.locationId!, () => []).add(asset);
      }
    }

    return [
      for (final row in locationRows)
        OcptLocation.fromRow(
          row: row,
          sets: setsByLocationId[row.id] ?? const [],
          photos: photosByLocationId[row.id] ?? const [],
          permitDocument: row.permitAssetId == null ? null : assetsById[row.permitAssetId],
          availabilities: availabilitiesByLocationId[row.id] ?? const [],
        ),
    ];
  }

  /// Loads every live scene of screenplay [screenplayId] in [database], in source order.
  ///
  /// The resources mode reads these to offer them for a set (see [assignSceneToSet]) and to name
  /// the ones a set already holds. This service is where the read lives because `scene_sets` is
  /// its table; the scenes themselves are `OcptSceneIndexService`'s to write, and nothing here
  /// ever does.
  ///
  /// [episodeNumber] is [screenplayId]'s own episode number, or null when the project holds a
  /// single episode; it is only carried onto each [OcptSceneRef] for `displayNumber` to read, never
  /// resolved here — this service has no reason to depend on `OcptScreenplayService`, which already
  /// depends on it (dependencies never reference their dependents).
  Future<List<OcptSceneRef>> loadScenes({
    required OcptProjectDatabase database,
    required String screenplayId,
    required int? episodeNumber,
  }) async {
    final rows =
        await (database.select(database.ocptScenesTable)
              ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();

    return [
      for (final row in rows) OcptSceneRef.fromRow(row: row, episodeNumber: episodeNumber),
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

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptLocationsTable,
        rowId: id,
        current: null,
        next: OcptLocationRow(
          id: id,
          name: name,
          colorIndex: 0,
          addressLine1: '',
          addressLine2: '',
          postalCode: '',
          city: '',
          region: '',
          country: '',
          contactNotes: '',
          permitStatus: OcptPermitStatus.toRequest,
          permitLabel: '',
          parkingNotes: '',
          powerNotes: '',
          facilitiesNotes: '',
          constraintsNotes: '',
          notes: '',
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

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

    final companion = OcptLocationsTableCompanion(
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
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptLocationsTable,
      )..where((table) => table.id.equals(locationId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptLocationsTable,
        rowId: locationId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones location [locationId] in [database], its sets, the `scene_sets` links onto those
  /// sets, its availability windows, and the `assets` rows it owns (its scouting photos and its
  /// permit document) along with it.
  ///
  /// The photo files themselves are never touched: this app only ever holds their paths (see
  /// [addLocationPhoto]), so deleting a location drops its references and nothing else.
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
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

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

        for (final setRow in setRows) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptSetsTable,
            rowId: setRow.id,
            current: setRow,
            next: setRow.copyWith(isDeleted: true),
            stamps: stamps,
          );
        }
      }

      final availabilityRows =
          await (database.select(database.ocptLocationAvailabilitiesTable)..where(
                (table) => table.locationId.equals(locationId) & table.isDeleted.not(),
              ))
              .get();
      for (final availabilityRow in availabilityRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptLocationAvailabilitiesTable,
          rowId: availabilityRow.id,
          current: availabilityRow,
          next: availabilityRow.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final assetRows =
          await (database.select(
                database.ocptAssetsTable,
              )..where((table) => table.locationId.equals(locationId) & table.isDeleted.not()))
              .get();
      for (final assetRow in assetRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptAssetsTable,
          rowId: assetRow.id,
          current: assetRow,
          next: assetRow.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final current = await (database.select(
        database.ocptLocationsTable,
      )..where((table) => table.id.equals(locationId))).getSingleOrNull();
      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptLocationsTable,
          rowId: locationId,
          current: current,
          next: current.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
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
      final rows = await _liveLocationRows(database);
      final current = rows.where((row) => row.id == locationId).firstOrNull;
      if (current == null) {
        return;
      }

      final others = rows.where((row) => row.id != locationId).toList(growable: false);

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
        table: database.ocptLocationsTable,
        rowId: locationId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Creates a new set named [name] inside location [locationId], appended at the end of that
  /// location's sets, and returns its freshly generated id.
  ///
  /// The set's code is generated here and nowhere else (`ocptSetCodeOf`, the first letters no live
  /// set of the **project** already carries), exactly as `OcptElementsService.createElement`
  /// generates an element's: it is the app's own identifier for the set rather than something the
  /// user is asked for, so no sheet offers to type it and a caller minting a set as a side effect
  /// of something else — the breakdown naming a décor while reading — cannot end up with one
  /// without a code.
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
          code: ocptSetCodeOf(existingCodes: await _liveSetCodes(database)),
          name: name,
          notes: '',
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Creates a new set named [name] and says scene [sceneId] is shot in it, in one transaction.
  ///
  /// [locationId] names the place holding it. Passing null creates **a location of its own**, named
  /// [name] too, for the reason `OcptBreakdownService.createSetAndTag` gives from the other side: a
  /// set has no existence outside a location, and somebody reading a scene and meeting a place the
  /// project has never heard of should not have to leave for another tab to invent one first. The
  /// two are renamed apart afterwards, `Cuisine` in `Cuisine` being an honest first guess rather
  /// than a claim.
  ///
  /// Writes **no tag**: this is the plain `scene_sets` link, the fact that a scene is shot
  /// somewhere, which the breakdown mode's scene sheet and the resources mode's own set row both
  /// state without a passage of the script being involved.
  ///
  /// Returns null, and rolls every write back, when any of them refuses.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createSetLinkedToScene({
    required OcptProjectDatabase database,
    required String sceneId,
    required String name,
    String? locationId,
  }) async {
    if (database.refusesUserWrite("createSetLinkedToScene")) {
      return null;
    }

    return database.transaction(() async {
      final holdingLocationId =
          locationId ?? await createLocation(database: database, name: name);
      if (holdingLocationId == null) {
        return null;
      }

      final setId = await createSet(
        database: database,
        locationId: holdingLocationId,
        name: name,
      );
      if (setId == null) {
        return null;
      }

      return await assignSceneToSet(database: database, sceneId: sceneId, setId: setId) == null
          ? null
          : setId;
    });
  }

  /// Updates the fields of set [setId] in [database] that are passed as something other than
  /// [Value.absent].
  ///
  /// `code` is not among them, and neither is `locationId`, for the same kind of reason: a set's
  /// code is the app's own ([createSet] mints it, nothing ever rewrites it), and its location is
  /// what it belongs to ([moveSetToLocation] hands it over). Neither is a field of the sheet.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateSet({
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

  /// Moves set [setId] to location [locationId], appended at the end of that location's sets.
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
  Future<void> moveSetToLocation({
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

      final existing = await _liveSetRowsOfLocation(database: database, locationId: locationId);

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWith(
          locationId: locationId,
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
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

      final current = await (database.select(
        database.ocptSetsTable,
      )..where((table) => table.id.equals(setId))).getSingleOrNull();
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
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
      final rows = await _liveSetRowsOfLocation(database: database, locationId: locationId);
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

  /// Says scene [sceneId] is also shot in set [setId], and returns the id of the link.
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
  Future<String?> assignSceneToSet({
    required OcptProjectDatabase database,
    required String sceneId,
    required String setId,
  }) async {
    if (database.refusesUserWrite("assignSceneToSet")) {
      return null;
    }

    return database.transaction(() async {
      final existingLinks =
          await (database.select(database.ocptSceneSetsTable)..where(
                (table) => table.sceneId.equals(sceneId) & table.setId.equals(setId),
              ))
              .get();

      OcptSceneSetRow? droppedLink;
      for (final link in existingLinks) {
        if (!link.isDeleted) {
          return link.id;
        }

        droppedLink ??= link;
      }

      if (droppedLink != null) {
        await (database.update(
          database.ocptSceneSetsTable,
        )..where((table) => table.id.equals(droppedLink!.id))).write(
          const OcptSceneSetsTableCompanion(isDeleted: Value(false)),
        );

        return droppedLink.id;
      }

      final id = const Uuid().v4();
      await database
          .into(database.ocptSceneSetsTable)
          .insert(
            OcptSceneSetsTableCompanion.insert(id: id, sceneId: sceneId, setId: setId),
          );

      return id;
    });
  }

  /// Removes the link saying scene [sceneId] is shot in set [setId], leaving whatever other sets
  /// that scene is shot in alone. A no-op when there is no such live link.
  ///
  /// Takes the two ids the caller has rather than the link's own: the set sheet lists a scene, and
  /// "this scene is not shot here" is what the user answers — the row carrying it is an
  /// implementation detail of that answer.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeSceneFromSet({
    required OcptProjectDatabase database,
    required String sceneId,
    required String setId,
  }) async {
    if (database.refusesUserWrite("removeSceneFromSet")) {
      return;
    }

    await (database.update(database.ocptSceneSetsTable)..where(
          (table) => table.sceneId.equals(sceneId) & table.setId.equals(setId),
        ))
        .write(const OcptSceneSetsTableCompanion(isDeleted: Value(true)));
  }

  /// Adds an availability window to location [locationId], and returns its freshly generated id.
  ///
  /// [endDate] is clamped up to [startDate] rather than refused, and [weekdays] falls back to
  /// [ocptEveryWeekdayMask] when it covers no day at all: both are slips of a control, and the
  /// caller has nothing useful to do with an error — the sheet shows what was written, which is
  /// how the user sees it.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addAvailability({
    required OcptProjectDatabase database,
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
    int weekdays = ocptEveryWeekdayMask,
    OcptDayPartSlot slot = OcptDayPartSlot.fullDay,
    int? startMinute,
    int? endMinute,
    OcptLocationAvailabilityKind kind = OcptLocationAvailabilityKind.available,
    String note = "",
  }) async {
    if (database.refusesUserWrite("addAvailability")) {
      return null;
    }

    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptLocationAvailabilitiesTable,
        rowId: id,
        current: null,
        next: OcptLocationAvailabilityRow(
          id: id,
          locationId: locationId,
          startDate: startDate,
          endDate: endDate.isBefore(startDate) ? startDate : endDate,
          weekdays: weekdays & ocptEveryWeekdayMask == 0 ? ocptEveryWeekdayMask : weekdays,
          slot: slot,
          startMinute: startMinute,
          endMinute: endMinute,
          kind: kind,
          note: note,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of availability window [id] that are passed as something other than
  /// [Value.absent].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateAvailability({
    required OcptProjectDatabase database,
    required String id,
    Value<DateTime> startDate = const Value.absent(),
    Value<DateTime> endDate = const Value.absent(),
    Value<int> weekdays = const Value.absent(),
    Value<OcptDayPartSlot> slot = const Value.absent(),
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<OcptLocationAvailabilityKind> kind = const Value.absent(),
    Value<String> note = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateAvailability")) {
      return;
    }

    final companion = OcptLocationAvailabilitiesTableCompanion(
      startDate: startDate,
      endDate: endDate,
      weekdays: weekdays,
      slot: slot,
      startMinute: startMinute,
      endMinute: endMinute,
      kind: kind,
      note: note,
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptLocationAvailabilitiesTable,
      )..where((table) => table.id.equals(id) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptLocationAvailabilitiesTable,
        rowId: id,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Removes availability window [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeAvailability({
    required OcptProjectDatabase database,
    required String id,
  }) async {
    if (database.refusesUserWrite("removeAvailability")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptLocationAvailabilitiesTable,
      )..where((table) => table.id.equals(id))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptLocationAvailabilitiesTable,
        rowId: id,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// References the file at [path] as a scouting photo of location [locationId], appended at the
  /// end of its photos, and returns the freshly generated id of the `assets` row.
  ///
  /// **No byte of the file is read, copied or written here** — see
  /// `docs/adr/0013-binary-assets-referenced-by-path.md` and `OcptAssetsTable`'s own doc comment:
  /// the app stores the path and nothing else, and a path that resolves to nothing later is a
  /// normal state the UI reports rather than an error.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addLocationPhoto({
    required OcptProjectDatabase database,
    required String locationId,
    required String path,
    String label = "",
  }) async {
    if (database.refusesUserWrite("addLocationPhoto")) {
      return null;
    }

    final existing =
        await (database.select(database.ocptAssetsTable)
              ..where(
                (table) =>
                    table.locationId.equals(locationId) &
                    table.kind.equalsValue(OcptAssetKind.locationPhoto) &
                    table.isDeleted.not(),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();

    return database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      final id = await assetsService.insertAsset(
        database: database,
        kind: OcptAssetKind.locationPhoto,
        locationId: locationId,
        path: path,
        label: label,
        sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// References the file at [path] as location [locationId]'s filming permit document, replacing
  /// whichever document it referenced before, and returns the freshly generated id of the `assets`
  /// row.
  ///
  /// The replaced document's row is tombstoned in the same transaction: a location has one permit
  /// document, so a row nothing points at any more is not history worth keeping — it is an orphan.
  /// See [addLocationPhoto] for why no byte of the file is touched.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> setPermitDocument({
    required OcptProjectDatabase database,
    required String locationId,
    required String path,
    String label = "",
  }) async {
    if (database.refusesUserWrite("setPermitDocument")) {
      return null;
    }

    return database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await _tombstonePermitDocument(database: database, locationId: locationId, stamps: stamps);

      final id = await assetsService.insertAsset(
        database: database,
        kind: OcptAssetKind.document,
        locationId: locationId,
        path: path,
        label: label,
        stamps: stamps,
      );

      final current = await (database.select(
        database.ocptLocationsTable,
      )..where((table) => table.id.equals(locationId))).getSingleOrNull();
      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptLocationsTable,
          rowId: locationId,
          current: current,
          next: current.copyWith(permitAssetId: Value(id)),
          stamps: stamps,
        );
      }

      await stamps.flush(database);

      return id;
    });
  }

  /// Drops location [locationId]'s reference to its filming permit document: the `assets` row is
  /// tombstoned and `permitAssetId` goes back to null. The file itself is never touched.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> clearPermitDocument({
    required OcptProjectDatabase database,
    required String locationId,
  }) async {
    if (database.refusesUserWrite("clearPermitDocument")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await _tombstonePermitDocument(database: database, locationId: locationId, stamps: stamps);

      final current = await (database.select(
        database.ocptLocationsTable,
      )..where((table) => table.id.equals(locationId))).getSingleOrNull();
      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptLocationsTable,
          rowId: locationId,
          current: current,
          next: current.copyWith(permitAssetId: const Value(null)),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Tombstones whichever `assets` row location [locationId] currently names as its permit
  /// document, if any. Leaves `permitAssetId` alone: both callers write it themselves. Stamps
  /// through [stamps] — the caller's own instance.
  Future<void> _tombstonePermitDocument({
    required OcptProjectDatabase database,
    required String locationId,
    required OcptRowStampService? stamps,
  }) async {
    final row = await (database.select(
      database.ocptLocationsTable,
    )..where((table) => table.id.equals(locationId))).getSingleOrNull();

    final permitAssetId = row?.permitAssetId;
    if (permitAssetId == null) {
      return;
    }

    await assetsService.tombstoneAsset(database: database, assetId: permitAssetId, stamps: stamps);
  }

  /// Tombstones every live `scene_sets` row naming any of [sceneIds]: `scene_sets` is this service's
  /// table, not `OcptBreakdownService`'s, so its own cascade
  /// (`OcptBreakdownService.tombstoneBreakdownOfScenes`) reaches for this narrow helper rather than
  /// writing the table itself — the set these links point at is, of course, untouched.
  ///
  /// **Unguarded**, exactly as `OcptElementsService.tombstoneRoleLinksOfRole` is: its only caller has
  /// already refused the write on a preview connection and is already inside the transaction
  /// removing the episode, so a second guard here would only be able to disagree with the first.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneSceneSetsOfScenes({
    required OcptProjectDatabase database,
    required List<String> sceneIds,
  }) async {
    if (sceneIds.isEmpty) {
      return;
    }

    await (database.update(
      database.ocptSceneSetsTable,
    )..where((table) => table.sceneId.isIn(sceneIds))).write(
      const OcptSceneSetsTableCompanion(isDeleted: Value(true)),
    );
  }

  /// The ids of the live scenes linked to each of [setIds], keyed by set id and ordered by the
  /// screenplay's own scene order. See [loadLocations] for why a link onto a tombstoned scene is
  /// left out rather than reported.
  Future<Map<String, List<String>>> _liveSceneIdsBySetId({
    required OcptProjectDatabase database,
    required List<String> setIds,
  }) async {
    if (setIds.isEmpty) {
      return const {};
    }

    final linkRows =
        await (database.select(database.ocptSceneSetsTable)..where(
              (table) => table.setId.isIn(setIds) & table.isDeleted.not(),
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

    final sceneIdsBySetId = <String, List<String>>{};
    for (final link in linkRows) {
      if (positionBySceneId.containsKey(link.sceneId)) {
        sceneIdsBySetId.putIfAbsent(link.setId, () => []).add(link.sceneId);
      }
    }

    for (final sceneIds in sceneIdsBySetId.values) {
      sceneIds.sort((a, b) => positionBySceneId[a]!.compareTo(positionBySceneId[b]!));
    }

    return sceneIdsBySetId;
  }

  /// Every live location row of [database], ordered by `sortKey`.
  Future<List<OcptLocationRow>> _liveLocationRows(OcptProjectDatabase database) =>
      (database.select(database.ocptLocationsTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// The code of every live set of [database], whichever location it belongs to — what
  /// [createSet] numbers a new code from, a set's code being unique across the whole project rather
  /// than within its location (`ocptSetCodeOf`).
  Future<List<String>> _liveSetCodes(OcptProjectDatabase database) async {
    final query = database.selectOnly(database.ocptSetsTable)
      ..addColumns([database.ocptSetsTable.code])
      ..where(database.ocptSetsTable.isDeleted.not());

    final rows = await query.get();

    return [for (final row in rows) row.read(database.ocptSetsTable.code) ?? ""];
  }

  /// Every live set row of location [locationId], ordered by `sortKey`.
  Future<List<OcptSetRow>> _liveSetRowsOfLocation({
    required OcptProjectDatabase database,
    required String locationId,
  }) => (database.select(database.ocptSetsTable)
        ..where((table) => table.locationId.equals(locationId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();
}
