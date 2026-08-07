// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:uuid/uuid.dart';

/// CRUD over `assets`, the rows referencing a binary file by path — a person's headshot, a
/// location's scouting photos, an element's photo, a signed release, a filming permit.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **No byte of a referenced file is ever read, copied or written here**, by this service or by
/// any of its callers: see `docs/adr/0013-binary-assets-referenced-by-path.md` and
/// `OcptAssetsTable`'s own doc comment. The app stores the path and nothing else, and a path that
/// resolves to nothing later is a normal state the UI reports rather than an error.
///
/// It exists because **four different owners reference files the same way** and only one of them
/// used to: the row is the same row whether a person, a location or an element owns it, and the
/// only thing that varies is which of the three nullable owner columns is filled. The services that
/// own those subjects (`OcptPeopleService`, `OcptLocationsService`, `OcptElementsService`) take one
/// of these and write their own `…AssetId` column beside the row it mints, since which asset is
/// *the* headshot is a fact about the person rather than about the file.
class OcptAssetsService {
  /// Class constructor
  const OcptAssetsService();

  /// Inserts one `assets` row of [kind] pointing at [path] and returns its freshly generated id.
  ///
  /// Exactly one of [personId], [locationId] and [elementId] names the subject; the caller is what
  /// knows which, and passing none would produce a row nothing can ever list.
  ///
  /// **Unguarded on purpose**: every caller is a service method that has already refused the write
  /// on a previewed database and is running inside its own transaction, so a second guard here
  /// would answer a question already answered — and answer it too late to roll the rest back.
  Future<String> insertAsset({
    required OcptProjectDatabase database,
    required OcptAssetKind kind,
    required String path,
    String label = "",
    String sortKey = "",
    String? personId,
    String? locationId,
    String? elementId,
  }) async {
    final id = const Uuid().v4();

    await database
        .into(database.ocptAssetsTable)
        .insert(
          OcptAssetsTableCompanion.insert(
            id: id,
            kind: kind,
            path: path,
            label: Value(label),
            addedAt: DateTime.now(),
            sortKey: Value(sortKey),
            personId: Value(personId),
            locationId: Value(locationId),
            elementId: Value(elementId),
          ),
        );

    return id;
  }

  /// Tombstones the `assets` row [assetId], if there is one.
  ///
  /// **Unguarded, for the reason [insertAsset] is**: this is the half of a replacement that runs
  /// inside a caller's transaction — a column pointing at one file has no history worth keeping,
  /// only an orphan to tombstone. [removeAsset] is the guarded entry point a user's own "remove
  /// this file" gesture goes through.
  Future<void> tombstoneAsset({
    required OcptProjectDatabase database,
    required String assetId,
  }) => (database.update(
    database.ocptAssetsTable,
  )..where((table) => table.id.equals(assetId))).write(
    const OcptAssetsTableCompanion(isDeleted: Value(true)),
  );

  /// Drops the reference [assetId] holds, on a user's own gesture.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeAsset({
    required OcptProjectDatabase database,
    required String assetId,
  }) async {
    if (database.refusesUserWrite("removeAsset")) {
      return;
    }

    await tombstoneAsset(database: database, assetId: assetId);
  }

  /// Tombstones every `assets` row belonging to person [personId] **and blanks its path and its
  /// label**, the erasure half of `OcptPeopleService.deletePerson`.
  ///
  /// A tombstone alone would not do here. An asset's `path` is personal data in its own right — an
  /// absolute path routinely names the person (`…/cession-droits-Jean-Dupont.pdf`) and always says
  /// where a photograph of them sits on this machine — so erasing somebody has to stop the file
  /// from holding it, exactly as `person_skills.label` and `person_unavailabilities.reason` are
  /// blanked rather than merely tombstoned. **The referenced file itself is not touched**: it is
  /// not the app's, it was never copied in, and deleting a user's own document off their disk is
  /// not what removing a person from a production means.
  ///
  /// **Unguarded, for the reason [insertAsset] is**: it runs inside `deletePerson`'s transaction.
  /// Its mirror on the version side is `OcptProjectVersionsService._scrubErasedPeople`, and the two
  /// must be kept in step by hand.
  Future<void> erasePersonAssets({
    required OcptProjectDatabase database,
    required String personId,
  }) => (database.update(
    database.ocptAssetsTable,
  )..where((table) => table.personId.equals(personId))).write(
    const OcptAssetsTableCompanion(isDeleted: Value(true), path: Value(''), label: Value('')),
  );
}
