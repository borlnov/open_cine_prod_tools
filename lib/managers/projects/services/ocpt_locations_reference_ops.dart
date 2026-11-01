// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_weekday_mask.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:uuid/uuid.dart';

/// What a location references or declares beyond its name: the windows it may be shot in, its
/// scouting photos and its permit document.
///
/// What `OcptLocationsService` forwards to; see `OcptLocationsSetOps`.
abstract final class OcptLocationsReferenceOps {
  /// Adds an availability window to location [locationId], and returns its freshly generated id.
  ///
  /// [endDate] is clamped up to [startDate] rather than refused, and [weekdays] falls back to
  /// [ocptEveryWeekdayMask] when it covers no day at all: both are slips of a control, and the
  /// caller has nothing useful to do with an error — the sheet shows what was written, which is
  /// how the user sees it.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addAvailability({
    required OcptDeviceIdGetter deviceId,
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
  static Future<void> updateAvailability({
    required OcptDeviceIdGetter deviceId,
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
  static Future<void> removeAvailability({
    required OcptDeviceIdGetter deviceId,
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
  static Future<String?> addLocationPhoto({
    required OcptDeviceIdGetter deviceId,
    required OcptAssetsService assetsService,
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
  static Future<String?> setPermitDocument({
    required OcptDeviceIdGetter deviceId,
    required OcptAssetsService assetsService,
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

      await _tombstonePermitDocument(
        assetsService: assetsService,
        database: database,
        locationId: locationId,
        stamps: stamps,
      );

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
  static Future<void> clearPermitDocument({
    required OcptDeviceIdGetter deviceId,
    required OcptAssetsService assetsService,
    required OcptProjectDatabase database,
    required String locationId,
  }) async {
    if (database.refusesUserWrite("clearPermitDocument")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await _tombstonePermitDocument(
        assetsService: assetsService,
        database: database,
        locationId: locationId,
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
  static Future<void> _tombstonePermitDocument({
    required OcptAssetsService assetsService,
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
}
