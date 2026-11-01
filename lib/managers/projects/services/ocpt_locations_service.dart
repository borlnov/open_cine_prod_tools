// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_reference_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_rows.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_set_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_location_availability.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_weekday_mask.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
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
/// This service does not decide *which* set a scene's heading suggests: the suggestion is never
/// applied automatically, only offered: `ocptSceneSetSuggestionOf` computes it and the resources
/// mode offers it, while [assignSceneToSet]/[removeSceneFromSet] are the plain link writes the mode
/// calls once the user has picked (or confirmed) one.
class OcptLocationsService extends AbsOcptService {
  /// The service minting and tombstoning the `assets` rows a location owns. Held rather than
  /// reached for so a test can hand in its own, exactly as `OcptBreakdownService` holds the two
  /// services it composes.
  final OcptAssetsService assetsService;

  /// The service tombstoning a set's floor plan along with it ([deleteSet], [deleteLocation]).
  /// This service depends on it — never the other way round (dependencies never reference their
  /// dependents) — since `OcptFloorPlanService.duplicateSet` needs a Resources set already minted
  /// by [createSiblingSet] to copy into, and a service that itself depended on this one could not
  /// be depended on here without a cycle.
  final OcptFloorPlanService floorPlanService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter].
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptLocationsService({
    required super.logger,
    required this.assetsService,
    required this.floorPlanService,
    required this.deviceId,
  });

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Initialises the services this one owns, in the order they are listed in its constructor.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    await assetsService.initLifeCycle();
    await floorPlanService.initLifeCycle();
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Disposes the services this one owns, in the reverse order they were initialised.
  @override
  Future<void> disposeLifeCycle() async {
    await floorPlanService.disposeLifeCycle();
    await assetsService.disposeLifeCycle();

    return super.disposeLifeCycle();
  }

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
    final locationRows = await OcptLocationsRows.liveLocationRows(database);
    final locationIds = locationRows.map((row) => row.id).toList(growable: false);

    final setRows = locationIds.isEmpty
        ? const <OcptSetRow>[]
        : await (database.select(database.ocptSetsTable)
                ..where((table) => table.locationId.isIn(locationIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final sceneIdsBySetId = await OcptLocationsRows.liveSceneIdsBySetId(
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

    return [for (final row in rows) OcptSceneRef.fromRow(row: row, episodeNumber: episodeNumber)];
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

    final existing = await OcptLocationsRows.liveLocationRows(database);
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
  /// sets, each set's own floor plan (`floorPlanService.tombstoneFloorPlanRowsOfSet`), its
  /// availability windows, and the `assets` rows it owns (its scouting photos and its permit
  /// document) along with it.
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

      final setRows = await (database.select(
        database.ocptSetsTable,
      )..where((table) => table.locationId.equals(locationId) & table.isDeleted.not())).get();
      final setIds = setRows.map((row) => row.id).toList(growable: false);

      if (setIds.isNotEmpty) {
        final sceneSetRows = await (database.select(
          database.ocptSceneSetsTable,
        )..where((table) => table.setId.isIn(setIds) & table.isDeleted.not())).get();
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

        for (final setRow in setRows) {
          await floorPlanService.tombstoneFloorPlanRowsOfSet(
            database: database,
            setId: setRow.id,
            stamps: stamps,
          );

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

      final availabilityRows = await (database.select(
        database.ocptLocationAvailabilitiesTable,
      )..where((table) => table.locationId.equals(locationId) & table.isDeleted.not())).get();
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

      final assetRows = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.locationId.equals(locationId) & table.isDeleted.not())).get();
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
      final rows = await OcptLocationsRows.liveLocationRows(database);
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

  /// Forwards to [OcptLocationsSetOps.createSet].
  Future<String?> createSet({
    required OcptProjectDatabase database,
    required String locationId,
    required String name,
  }) => OcptLocationsSetOps.createSet(
    database: database,
    locationId: locationId,
    name: name,
    deviceId: deviceId,
  );

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
      final holdingLocationId = locationId ?? await createLocation(database: database, name: name);
      if (holdingLocationId == null) {
        return null;
      }

      final setId = await createSet(database: database, locationId: holdingLocationId, name: name);
      if (setId == null) {
        return null;
      }

      return await assignSceneToSet(database: database, sceneId: sceneId, setId: setId) == null
          ? null
          : setId;
    });
  }

  /// Forwards to [OcptLocationsSetOps.updateSet].
  Future<void> updateSet({
    required OcptProjectDatabase database,
    required String setId,
    Value<String> name = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) => OcptLocationsSetOps.updateSet(
    database: database,
    setId: setId,
    name: name,
    notes: notes,
    deviceId: deviceId,
  );

  /// Forwards to [OcptLocationsSetOps.moveSetToLocation].
  Future<void> moveSetToLocation({
    required OcptProjectDatabase database,
    required String setId,
    required String locationId,
  }) => OcptLocationsSetOps.moveSetToLocation(
    database: database,
    setId: setId,
    locationId: locationId,
    deviceId: deviceId,
  );

  /// Forwards to [OcptLocationsSetOps.deleteSet].
  Future<void> deleteSet({required OcptProjectDatabase database, required String setId}) =>
      OcptLocationsSetOps.deleteSet(
        database: database,
        setId: setId,
        deviceId: deviceId,
        floorPlanService: floorPlanService,
      );

  /// Forwards to [OcptLocationsSetOps.createSiblingSet].
  Future<String?> createSiblingSet({
    required OcptProjectDatabase database,
    required String sourceSetId,
    required String name,
  }) => OcptLocationsSetOps.createSiblingSet(
    database: database,
    sourceSetId: sourceSetId,
    name: name,
    deviceId: deviceId,
  );

  /// Forwards to [OcptLocationsSetOps.duplicateSetForScene].
  Future<String?> duplicateSetForScene({
    required OcptProjectDatabase database,
    required String sourceSetId,
    required String name,
    required String sceneId,
  }) => OcptLocationsSetOps.duplicateSetForScene(
    database: database,
    sourceSetId: sourceSetId,
    name: name,
    sceneId: sceneId,
    deviceId: deviceId,
    floorPlanService: floorPlanService,
  );

  /// Forwards to [OcptLocationsSetOps.reorderSet].
  Future<void> reorderSet({
    required OcptProjectDatabase database,
    required String locationId,
    required String setId,
    required int newPosition,
  }) => OcptLocationsSetOps.reorderSet(
    database: database,
    locationId: locationId,
    setId: setId,
    newPosition: newPosition,
    deviceId: deviceId,
  );

  /// Forwards to [OcptLocationsSetOps.assignSceneToSet].
  Future<String?> assignSceneToSet({
    required OcptProjectDatabase database,
    required String sceneId,
    required String setId,
  }) => OcptLocationsSetOps.assignSceneToSet(
    database: database,
    sceneId: sceneId,
    setId: setId,
    deviceId: deviceId,
  );

  /// Forwards to [OcptLocationsSetOps.removeSceneFromSet].
  Future<void> removeSceneFromSet({
    required OcptProjectDatabase database,
    required String sceneId,
    required String setId,
  }) => OcptLocationsSetOps.removeSceneFromSet(
    database: database,
    sceneId: sceneId,
    setId: setId,
    deviceId: deviceId,
  );

  /// Forwards to [OcptLocationsSetOps.firstLinkedSceneOf].
  Future<({String sceneId, String screenplayId})?> firstLinkedSceneOf({
    required OcptProjectDatabase database,
    required String setId,
  }) => OcptLocationsSetOps.firstLinkedSceneOf(database: database, setId: setId);

  /// Forwards to [OcptLocationsReferenceOps.addAvailability].
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
  }) => OcptLocationsReferenceOps.addAvailability(
    database: database,
    locationId: locationId,
    startDate: startDate,
    endDate: endDate,
    weekdays: weekdays,
    slot: slot,
    startMinute: startMinute,
    endMinute: endMinute,
    kind: kind,
    note: note,
    deviceId: deviceId,
  );

  /// Forwards to [OcptLocationsReferenceOps.updateAvailability].
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
  }) => OcptLocationsReferenceOps.updateAvailability(
    database: database,
    id: id,
    startDate: startDate,
    endDate: endDate,
    weekdays: weekdays,
    slot: slot,
    startMinute: startMinute,
    endMinute: endMinute,
    kind: kind,
    note: note,
    deviceId: deviceId,
  );

  /// Forwards to [OcptLocationsReferenceOps.removeAvailability].
  Future<void> removeAvailability({required OcptProjectDatabase database, required String id}) =>
      OcptLocationsReferenceOps.removeAvailability(database: database, id: id, deviceId: deviceId);

  /// Forwards to [OcptLocationsReferenceOps.addLocationPhoto].
  Future<String?> addLocationPhoto({
    required OcptProjectDatabase database,
    required String locationId,
    required String path,
    String label = "",
  }) => OcptLocationsReferenceOps.addLocationPhoto(
    database: database,
    locationId: locationId,
    path: path,
    label: label,
    deviceId: deviceId,
    assetsService: assetsService,
  );

  /// Forwards to [OcptLocationsReferenceOps.setPermitDocument].
  Future<String?> setPermitDocument({
    required OcptProjectDatabase database,
    required String locationId,
    required String path,
    String label = "",
  }) => OcptLocationsReferenceOps.setPermitDocument(
    database: database,
    locationId: locationId,
    path: path,
    label: label,
    deviceId: deviceId,
    assetsService: assetsService,
  );

  /// Forwards to [OcptLocationsReferenceOps.clearPermitDocument].
  Future<void> clearPermitDocument({
    required OcptProjectDatabase database,
    required String locationId,
  }) => OcptLocationsReferenceOps.clearPermitDocument(
    database: database,
    locationId: locationId,
    deviceId: deviceId,
    assetsService: assetsService,
  );

  /// Forwards to [OcptLocationsSetOps.tombstoneSceneSetsOfScenes].
  Future<void> tombstoneSceneSetsOfScenes({
    required OcptProjectDatabase database,
    required List<String> sceneIds,
    required OcptRowStampService? stamps,
  }) => OcptLocationsSetOps.tombstoneSceneSetsOfScenes(
    database: database,
    sceneIds: sceneIds,
    stamps: stamps,
  );
}
