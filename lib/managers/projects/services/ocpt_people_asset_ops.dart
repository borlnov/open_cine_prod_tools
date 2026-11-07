// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';

/// The files a person references: their photo and their image-rights document, each minted or
/// tombstoned as an `assets` row through `OcptAssetsService` in the transaction that points the
/// person at it.
///
/// What `OcptPeopleService` forwards to; that service documents the address book whole.
abstract final class OcptPeopleAssetOps {
  /// Reference the file at [path] as person [personId]'s photo, replacing whichever file they
  /// referenced before, and return the freshly generated id of the `assets` row.
  ///
  /// The replaced photo's row is tombstoned in the same transaction: a person has one photo, so a
  /// row nothing points at any more is not history worth keeping — it is an orphan. That is
  /// `OcptLocationsService.setPermitDocument`'s rule, and this is the same shape for the same
  /// reason. **No byte of the file is read, copied or written** — see
  /// `docs/adr/0013-binary-assets-referenced-by-path.md`.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> setPersonPhoto({
    required OcptDeviceIdGetter deviceId,
    required OcptAssetsService assetsService,
    required OcptProjectDatabase database,
    required String personId,
    required String path,
    String label = "",
  }) => _setPersonAsset(
    deviceId: deviceId,
    assetsService: assetsService,
    database: database,
    logContext: "setPersonPhoto",
    personId: personId,
    path: path,
    label: label,
    kind: OcptAssetKind.personPhoto,
    currentAssetIdOf: (row) => row.photoAssetId,
    companionOf: (assetId) => OcptPeopleTableCompanion(photoAssetId: Value(assetId)),
  );

  /// Drop person [personId]'s reference to their photo: the `assets` row is tombstoned and
  /// `photoAssetId` goes back to null. The file itself is never touched.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> clearPersonPhoto({
    required OcptDeviceIdGetter deviceId,
    required OcptAssetsService assetsService,
    required OcptProjectDatabase database,
    required String personId,
  }) => _clearPersonAsset(
    deviceId: deviceId,
    assetsService: assetsService,
    database: database,
    logContext: "clearPersonPhoto",
    personId: personId,
    currentAssetIdOf: (row) => row.photoAssetId,
    companionOf: (assetId) => OcptPeopleTableCompanion(photoAssetId: Value(assetId)),
  );

  /// Reference the file at [path] as person [personId]'s signed image rights release, replacing
  /// whichever document they referenced before, and return the freshly generated id of the
  /// `assets` row.
  ///
  /// **This writes the reference alone and never `imageRightsStatus`.** Attaching a scan is not the
  /// same claim as saying the release is signed — a production routinely files a draft before it
  /// comes back signed — and deducing the status from the presence of a file would put a claim in
  /// the project nobody made. The status stays the sheet's own control.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> setImageRightsDocument({
    required OcptDeviceIdGetter deviceId,
    required OcptAssetsService assetsService,
    required OcptProjectDatabase database,
    required String personId,
    required String path,
    String label = "",
  }) => _setPersonAsset(
    deviceId: deviceId,
    assetsService: assetsService,
    database: database,
    logContext: "setImageRightsDocument",
    personId: personId,
    path: path,
    label: label,
    kind: OcptAssetKind.document,
    currentAssetIdOf: (row) => row.imageRightsAssetId,
    companionOf: (assetId) => OcptPeopleTableCompanion(imageRightsAssetId: Value(assetId)),
  );

  /// Drop person [personId]'s reference to their signed image rights release: the `assets` row is
  /// tombstoned and `imageRightsAssetId` goes back to null. The file itself is never touched, and
  /// neither is `imageRightsStatus` — see [setImageRightsDocument].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> clearImageRightsDocument({
    required OcptDeviceIdGetter deviceId,
    required OcptAssetsService assetsService,
    required OcptProjectDatabase database,
    required String personId,
  }) => _clearPersonAsset(
    deviceId: deviceId,
    assetsService: assetsService,
    database: database,
    logContext: "clearImageRightsDocument",
    personId: personId,
    currentAssetIdOf: (row) => row.imageRightsAssetId,
    companionOf: (assetId) => OcptPeopleTableCompanion(imageRightsAssetId: Value(assetId)),
  );

  /// Run the body [setPersonPhoto] and [setImageRightsDocument] share: tombstone whichever row the
  /// column named, mint a new one of [kind], and point the column at it, all in one transaction.
  ///
  /// [currentAssetIdOf] reads the column out of the person's row and [companionOf] writes it back;
  /// the pair is what makes the two columns one method rather than two copies that could drift on
  /// the ordering the paragraph above depends on.
  static Future<String?> _setPersonAsset({
    required OcptDeviceIdGetter deviceId,
    required OcptAssetsService assetsService,
    required OcptProjectDatabase database,
    required String logContext,
    required String personId,
    required String path,
    required String label,
    required OcptAssetKind kind,
    required String? Function(OcptPersonRow row) currentAssetIdOf,
    required OcptPeopleTableCompanion Function(String? assetId) companionOf,
  }) async {
    if (database.refusesUserWrite(logContext)) {
      return null;
    }

    return database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await _tombstonePersonAsset(
        assetsService: assetsService,
        database: database,
        personId: personId,
        currentAssetIdOf: currentAssetIdOf,
        stamps: stamps,
      );

      final id = await assetsService.insertAsset(
        database: database,
        kind: kind,
        personId: personId,
        path: path,
        label: label,
        stamps: stamps,
      );

      final current = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals(personId))).getSingleOrNull();

      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptPeopleTable,
          rowId: personId,
          current: current,
          next: current.copyWithCompanion(companionOf(id)),
          stamps: stamps,
        );
      }

      await stamps.flush(database);

      return id;
    });
  }

  /// Run the body [clearPersonPhoto] and [clearImageRightsDocument] share. See [_setPersonAsset]
  /// for
  /// what [currentAssetIdOf] and [companionOf] are.
  static Future<void> _clearPersonAsset({
    required OcptDeviceIdGetter deviceId,
    required OcptAssetsService assetsService,
    required OcptProjectDatabase database,
    required String logContext,
    required String personId,
    required String? Function(OcptPersonRow row) currentAssetIdOf,
    required OcptPeopleTableCompanion Function(String? assetId) companionOf,
  }) async {
    if (database.refusesUserWrite(logContext)) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await _tombstonePersonAsset(
        assetsService: assetsService,
        database: database,
        personId: personId,
        currentAssetIdOf: currentAssetIdOf,
        stamps: stamps,
      );

      final current = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals(personId))).getSingleOrNull();

      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptPeopleTable,
          rowId: personId,
          current: current,
          next: current.copyWithCompanion(companionOf(null)),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Tombstone whichever `assets` row [currentAssetIdOf] reads off person [personId], if any.
  /// Leaves the column alone: both callers write it themselves. Stamps through [stamps] — the
  /// caller's own instance.
  static Future<void> _tombstonePersonAsset({
    required OcptAssetsService assetsService,
    required OcptProjectDatabase database,
    required String personId,
    required String? Function(OcptPersonRow row) currentAssetIdOf,
    required OcptRowStampService? stamps,
  }) async {
    final row = await (database.select(
      database.ocptPeopleTable,
    )..where((table) => table.id.equals(personId))).getSingleOrNull();

    final assetId = row == null ? null : currentAssetIdOf(row);
    if (assetId == null) {
      return;
    }

    await assetsService.tombstoneAsset(database: database, assetId: assetId, stamps: stamps);
  }
}
