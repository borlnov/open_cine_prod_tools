// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the address book: `people`, and its `person_positions`/`person_skills`/
/// `person_unavailabilities` siblings.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — see `OcptShotListService`'s own doc comment, which
/// this service follows exactly, including for `person_positions` and `person_skills`
/// (`person_unavailabilities` carries no `sortKey`: it is an unordered set of constraints, not a
/// list a user reorders — see `OcptPersonUnavailabilitiesTable`'s own doc comment).
///
/// **[deletePerson] is an erasure, not a plain tombstone** — decision 6 of the plan this service
/// ships under. See its own doc comment for exactly which columns are blanked.
class OcptPeopleService {
  /// The service minting and tombstoning the `assets` rows a person owns — their photo and their
  /// signed image rights release. Held rather than reached for, exactly as
  /// `OcptLocationsService` holds its own.
  final OcptAssetsService assetsService;

  /// Class constructor
  const OcptPeopleService({this.assetsService = const OcptAssetsService()});

  /// The write [deletePerson] uses to blank a person's personal columns.
  ///
  /// **Every column of `people` is blanked, except the four that are not personal data**: `id`
  /// (an opaque identifier, needed for the tombstone to mean anything), `sortKey` (list ordering,
  /// carries no information about the person), `isDeleted` (the tombstone itself, set to true
  /// rather than blanked) and `colorIndex` (an arbitrary palette index, not personal data). Every
  /// other column — name, contact details, address, birth date, transport/accommodation/travel
  /// notes, diet, allergies, measurements, sizes, HMC notes, image rights status/date/asset, free
  /// notes — held
  /// something about the person and is reset to its table default (empty string, `null`, or
  /// [OcptImageRightsStatus.notApplicable] for the one enum column) in this single write.
  /// `maxDailyPresenceMinutes` is blanked with them: it is personal data of the same nature as
  /// `minorNotes`, the two constraints being thought about together on the sheet.
  /// `commuteKmMilli`/`mileageRateId` are blanked for the same reason: a one-way commute distance
  /// says roughly where somebody lives, which is exactly the kind of fact this erasure exists to
  /// take out of the file.
  static const _erasureCompanion = OcptPeopleTableCompanion(
    isDeleted: Value(true),
    firstName: Value(''),
    lastName: Value(''),
    email: Value(''),
    phone: Value(''),
    addressLine1: Value(''),
    addressLine2: Value(''),
    postalCode: Value(''),
    city: Value(''),
    region: Value(''),
    country: Value(''),
    birthDate: Value(null),
    minorNotes: Value(''),
    maxDailyPresenceMinutes: Value(null),
    isTransportAutonomous: Value(null),
    accommodationNotes: Value(''),
    travelNotes: Value(''),
    dietaryNotes: Value(''),
    allergies: Value(''),
    measurementHeight: Value(''),
    measurementChest: Value(''),
    measurementWaist: Value(''),
    measurementHips: Value(''),
    sizeTop: Value(''),
    sizeBottom: Value(''),
    sizeShoes: Value(''),
    hmcNotes: Value(''),
    imageRightsStatus: Value(OcptImageRightsStatus.notApplicable),
    imageRightsDate: Value(null),
    imageRightsAssetId: Value(null),
    photoAssetId: Value(null),
    notes: Value(''),
    commuteKmMilli: Value(null),
    mileageRateId: Value(null),
  );

  /// Loads every live person of [database], in `sortKey` order, each joined with its live
  /// [OcptPersonPosition]s, [OcptPersonSkill]s and [OcptPersonUnavailability]s, and with the two
  /// files it references — the photo and the signed image rights release.
  ///
  /// Runs five queries (one per table) regardless of how many people there are, the same trade-off
  /// `OcptShotListService.loadShotList` makes: an address book is dozens of rows, not millions, so
  /// joining them in memory here keeps each query trivial to read.
  ///
  /// A `photoAssetId` naming a tombstoned row resolves to null, the way a set's link onto a
  /// vanished scene is skipped: the reference is gone, and "no photo" is what that means. A path
  /// resolving to no file on disk is a different question entirely, and not this layer's — see
  /// `docs/adr/0013-binary-assets-referenced-by-path.md`.
  Future<List<OcptPerson>> loadPeople({required OcptProjectDatabase database}) async {
    final personRows = await _liveRows(database);
    final personIds = personRows.map((row) => row.id).toList(growable: false);

    final assetRows = personIds.isEmpty
        ? const <OcptAssetRow>[]
        : await (database.select(database.ocptAssetsTable)
                ..where((table) => table.personId.isIn(personIds) & table.isDeleted.not()))
              .get();

    final assetsById = {for (final row in assetRows) row.id: OcptAssetRef.fromRow(row)};

    final positionRows = personIds.isEmpty
        ? const <OcptPersonPositionRow>[]
        : await (database.select(database.ocptPersonPositionsTable)
                ..where((table) => table.personId.isIn(personIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final skillRows = personIds.isEmpty
        ? const <OcptPersonSkillRow>[]
        : await (database.select(database.ocptPersonSkillsTable)
                ..where((table) => table.personId.isIn(personIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final unavailabilityRows = personIds.isEmpty
        ? const <OcptPersonUnavailabilityRow>[]
        : await (database.select(database.ocptPersonUnavailabilitiesTable)
                ..where((table) => table.personId.isIn(personIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.startDate)]))
              .get();

    final positionsByPersonId = <String, List<OcptPersonPosition>>{};
    for (final row in positionRows) {
      positionsByPersonId.putIfAbsent(row.personId, () => []).add(OcptPersonPosition.fromRow(row));
    }

    final skillsByPersonId = <String, List<OcptPersonSkill>>{};
    for (final row in skillRows) {
      skillsByPersonId.putIfAbsent(row.personId, () => []).add(OcptPersonSkill.fromRow(row));
    }

    final unavailabilitiesByPersonId = <String, List<OcptPersonUnavailability>>{};
    for (final row in unavailabilityRows) {
      unavailabilitiesByPersonId
          .putIfAbsent(row.personId, () => [])
          .add(OcptPersonUnavailability.fromRow(row));
    }

    return [
      for (final row in personRows)
        OcptPerson.fromRow(
          row: row,
          positions: positionsByPersonId[row.id] ?? const [],
          skills: skillsByPersonId[row.id] ?? const [],
          unavailabilities: unavailabilitiesByPersonId[row.id] ?? const [],
          photo: assetsById[row.photoAssetId],
          imageRightsDocument: assetsById[row.imageRightsAssetId],
        ),
    ];
  }

  /// Creates a new, blank person in [database], appended at the end of the address book, and
  /// returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createPerson({required OcptProjectDatabase database}) async {
    if (database.refusesUserWrite("createPerson")) {
      return null;
    }

    final existing = await _liveRows(database);
    final id = const Uuid().v4();

    await database
        .into(database.ocptPeopleTable)
        .insert(
          OcptPeopleTableCompanion.insert(
            id: id,
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of person [personId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderPerson] and [deletePerson].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updatePerson({
    required OcptProjectDatabase database,
    required String personId,
    Value<String> firstName = const Value.absent(),
    Value<String> lastName = const Value.absent(),
    Value<String> email = const Value.absent(),
    Value<String> phone = const Value.absent(),
    Value<String> addressLine1 = const Value.absent(),
    Value<String> addressLine2 = const Value.absent(),
    Value<String> postalCode = const Value.absent(),
    Value<String> city = const Value.absent(),
    Value<String> region = const Value.absent(),
    Value<String> country = const Value.absent(),
    Value<int> colorIndex = const Value.absent(),
    Value<DateTime?> birthDate = const Value.absent(),
    Value<String> minorNotes = const Value.absent(),
    Value<int?> maxDailyPresenceMinutes = const Value.absent(),
    Value<bool?> isTransportAutonomous = const Value.absent(),
    Value<String> accommodationNotes = const Value.absent(),
    Value<String> travelNotes = const Value.absent(),
    Value<String> dietaryNotes = const Value.absent(),
    Value<String> allergies = const Value.absent(),
    Value<String> measurementHeight = const Value.absent(),
    Value<String> measurementChest = const Value.absent(),
    Value<String> measurementWaist = const Value.absent(),
    Value<String> measurementHips = const Value.absent(),
    Value<String> sizeTop = const Value.absent(),
    Value<String> sizeBottom = const Value.absent(),
    Value<String> sizeShoes = const Value.absent(),
    Value<String> hmcNotes = const Value.absent(),
    Value<OcptImageRightsStatus> imageRightsStatus = const Value.absent(),
    Value<DateTime?> imageRightsDate = const Value.absent(),
    Value<String?> imageRightsAssetId = const Value.absent(),
    Value<String?> photoAssetId = const Value.absent(),
    Value<String> notes = const Value.absent(),
    Value<int?> commuteKmMilli = const Value.absent(),
    Value<String?> mileageRateId = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updatePerson")) {
      return;
    }

    await (database.update(
      database.ocptPeopleTable,
    )..where((table) => table.id.equals(personId) & table.isDeleted.not())).write(
      OcptPeopleTableCompanion(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        postalCode: postalCode,
        city: city,
        region: region,
        country: country,
        colorIndex: colorIndex,
        birthDate: birthDate,
        minorNotes: minorNotes,
        maxDailyPresenceMinutes: maxDailyPresenceMinutes,
        isTransportAutonomous: isTransportAutonomous,
        accommodationNotes: accommodationNotes,
        travelNotes: travelNotes,
        dietaryNotes: dietaryNotes,
        allergies: allergies,
        measurementHeight: measurementHeight,
        measurementChest: measurementChest,
        measurementWaist: measurementWaist,
        measurementHips: measurementHips,
        sizeTop: sizeTop,
        sizeBottom: sizeBottom,
        sizeShoes: sizeShoes,
        hmcNotes: hmcNotes,
        imageRightsStatus: imageRightsStatus,
        imageRightsDate: imageRightsDate,
        imageRightsAssetId: imageRightsAssetId,
        photoAssetId: photoAssetId,
        notes: notes,
        commuteKmMilli: commuteKmMilli,
        mileageRateId: mileageRateId,
      ),
    );
  }

  /// Erases person [personId] from [database] (decision 6 of the plan this service ships under):
  /// tombstones the row and blanks its personal columns in the same write — see
  /// [_erasureCompanion] for exactly which ones — then records the erasure in `local_erasures`, the
  /// local, never-synchronised table that lets a later version restore refuse to resurrect this
  /// person (§4.9 of the plan; the restore side is other work, this only writes the row).
  ///
  /// Does nothing if [personId] doesn't exist or is already erased: an erasure only ever happens
  /// once, so a second call is a no-op rather than a second `local_erasures` row or a second write
  /// clobbering columns already blank.
  ///
  /// This person's `person_positions`/`person_skills`/`person_unavailabilities` rows are
  /// **tombstoned in the same transaction**, and the two that hold free text *about the person* are
  /// blanked with them: `person_skills.label` (driving licences, languages, what they can do) and
  /// `person_unavailabilities.reason` (why they were unavailable on a date, which is routinely
  /// something personal). An erasure is about what the project file stops holding, not about what
  /// the UI stops showing — leaving those rows readable in the `.ocpt` because no screen reaches
  /// them any more would make the erasure a lie the moment anybody opens the file with anything
  /// else.
  ///
  /// `person_positions` is tombstoned but **not** blanked: a crew position ("sound") describes the
  /// production rather than the person, and once the row it hangs off holds no name it identifies
  /// nobody.
  ///
  /// The `assets` rows this person owns — their photo, their signed release — are tombstoned **and
  /// their path and label blanked**, through `OcptAssetsService.erasePersonAssets`: a path names
  /// the person as readily as a field does, and says where a photograph of them sits. The
  /// referenced files themselves are not touched, being the user's own and never copied in.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deletePerson({
    required OcptProjectDatabase database,
    required String personId,
  }) async {
    if (database.refusesUserWrite("deletePerson")) {
      return;
    }

    await database.transaction(() async {
      final row = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals(personId))).getSingleOrNull();

      if (row == null || row.isDeleted) {
        return;
      }

      await (database.update(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals(personId))).write(_erasureCompanion);

      await (database.update(
        database.ocptPersonPositionsTable,
      )..where((table) => table.personId.equals(personId))).write(
        const OcptPersonPositionsTableCompanion(isDeleted: Value(true)),
      );

      await (database.update(
        database.ocptPersonSkillsTable,
      )..where((table) => table.personId.equals(personId))).write(
        const OcptPersonSkillsTableCompanion(isDeleted: Value(true), label: Value('')),
      );

      await (database.update(
        database.ocptPersonUnavailabilitiesTable,
      )..where((table) => table.personId.equals(personId))).write(
        const OcptPersonUnavailabilitiesTableCompanion(isDeleted: Value(true), reason: Value('')),
      );

      await assetsService.erasePersonAssets(database: database, personId: personId);

      await database
          .into(database.ocptLocalErasuresTable)
          .insertOnConflictUpdate(
            OcptLocalErasuresTableCompanion.insert(personId: personId, erasedAt: DateTime.now()),
          );
    });
  }

  /// References the file at [path] as person [personId]'s photo, replacing whichever file they
  /// referenced before, and returns the freshly generated id of the `assets` row.
  ///
  /// The replaced photo's row is tombstoned in the same transaction: a person has one photo, so a
  /// row nothing points at any more is not history worth keeping — it is an orphan. That is
  /// `OcptLocationsService.setPermitDocument`'s rule, and this is the same shape for the same
  /// reason. **No byte of the file is read, copied or written** — see
  /// `docs/adr/0013-binary-assets-referenced-by-path.md`.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> setPersonPhoto({
    required OcptProjectDatabase database,
    required String personId,
    required String path,
    String label = "",
  }) => _setPersonAsset(
    database: database,
    logContext: "setPersonPhoto",
    personId: personId,
    path: path,
    label: label,
    kind: OcptAssetKind.personPhoto,
    currentAssetIdOf: (row) => row.photoAssetId,
    companionOf: (assetId) => OcptPeopleTableCompanion(photoAssetId: Value(assetId)),
  );

  /// Drops person [personId]'s reference to their photo: the `assets` row is tombstoned and
  /// `photoAssetId` goes back to null. The file itself is never touched.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> clearPersonPhoto({
    required OcptProjectDatabase database,
    required String personId,
  }) => _clearPersonAsset(
    database: database,
    logContext: "clearPersonPhoto",
    personId: personId,
    currentAssetIdOf: (row) => row.photoAssetId,
    companionOf: (assetId) => OcptPeopleTableCompanion(photoAssetId: Value(assetId)),
  );

  /// References the file at [path] as person [personId]'s signed image rights release, replacing
  /// whichever document they referenced before, and returns the freshly generated id of the
  /// `assets` row.
  ///
  /// **This writes the reference alone and never `imageRightsStatus`.** Attaching a scan is not the
  /// same claim as saying the release is signed — a production routinely files a draft before it
  /// comes back signed — and deducing the status from the presence of a file would put a claim in
  /// the project nobody made. The status stays the sheet's own control.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> setImageRightsDocument({
    required OcptProjectDatabase database,
    required String personId,
    required String path,
    String label = "",
  }) => _setPersonAsset(
    database: database,
    logContext: "setImageRightsDocument",
    personId: personId,
    path: path,
    label: label,
    kind: OcptAssetKind.document,
    currentAssetIdOf: (row) => row.imageRightsAssetId,
    companionOf: (assetId) => OcptPeopleTableCompanion(imageRightsAssetId: Value(assetId)),
  );

  /// Drops person [personId]'s reference to their signed image rights release: the `assets` row is
  /// tombstoned and `imageRightsAssetId` goes back to null. The file itself is never touched, and
  /// neither is `imageRightsStatus` — see [setImageRightsDocument].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> clearImageRightsDocument({
    required OcptProjectDatabase database,
    required String personId,
  }) => _clearPersonAsset(
    database: database,
    logContext: "clearImageRightsDocument",
    personId: personId,
    currentAssetIdOf: (row) => row.imageRightsAssetId,
    companionOf: (assetId) => OcptPeopleTableCompanion(imageRightsAssetId: Value(assetId)),
  );

  /// The body [setPersonPhoto] and [setImageRightsDocument] share: tombstone whichever row the
  /// column named, mint a new one of [kind], and point the column at it, all in one transaction.
  ///
  /// [currentAssetIdOf] reads the column out of the person's row and [companionOf] writes it back;
  /// the pair is what makes the two columns one method rather than two copies that could drift on
  /// the ordering the paragraph above depends on.
  Future<String?> _setPersonAsset({
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
      await _tombstonePersonAsset(
        database: database,
        personId: personId,
        currentAssetIdOf: currentAssetIdOf,
      );

      final id = await assetsService.insertAsset(
        database: database,
        kind: kind,
        personId: personId,
        path: path,
        label: label,
      );

      await (database.update(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals(personId))).write(companionOf(id));

      return id;
    });
  }

  /// The body [clearPersonPhoto] and [clearImageRightsDocument] share. See [_setPersonAsset] for
  /// what [currentAssetIdOf] and [companionOf] are.
  Future<void> _clearPersonAsset({
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
      await _tombstonePersonAsset(
        database: database,
        personId: personId,
        currentAssetIdOf: currentAssetIdOf,
      );

      await (database.update(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals(personId))).write(companionOf(null));
    });
  }

  /// Tombstones whichever `assets` row [currentAssetIdOf] reads off person [personId], if any.
  /// Leaves the column alone: both callers write it themselves.
  Future<void> _tombstonePersonAsset({
    required OcptProjectDatabase database,
    required String personId,
    required String? Function(OcptPersonRow row) currentAssetIdOf,
  }) async {
    final row = await (database.select(
      database.ocptPeopleTable,
    )..where((table) => table.id.equals(personId))).getSingleOrNull();

    final assetId = row == null ? null : currentAssetIdOf(row);
    if (assetId == null) {
      return;
    }

    await assetsService.tombstoneAsset(database: database, assetId: assetId);
  }

  /// Moves person [personId] to [newPosition] (0-based) within the address book, by giving it a
  /// `sortKey` sitting between the two people it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderPerson({
    required OcptProjectDatabase database,
    required String personId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderPerson")) {
      return;
    }

    await database.transaction(() async {
      final others = (await _liveRows(database))..removeWhere((row) => row.id == personId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals(personId))).write(
        OcptPeopleTableCompanion(sortKey: Value(sortKey)),
      );
    });
  }

  /// Adds a crew position assignment to person [personId], appended after their current positions,
  /// and returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addPosition({
    required OcptProjectDatabase database,
    required String personId,
    required String positionId,
    required String customLabel,
  }) async {
    if (database.refusesUserWrite("addPosition")) {
      return null;
    }

    final existing = await _positionRowsOfPerson(database: database, personId: personId);
    final id = const Uuid().v4();

    await database
        .into(database.ocptPersonPositionsTable)
        .insert(
          OcptPersonPositionsTableCompanion.insert(
            id: id,
            personId: personId,
            positionId: Value(positionId),
            customLabel: Value(customLabel),
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of position assignment [id] in [database] that are passed as something
  /// other than [Value.absent].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updatePosition({
    required OcptProjectDatabase database,
    required String id,
    Value<String> positionId = const Value.absent(),
    Value<String> customLabel = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updatePosition")) {
      return;
    }

    await (database.update(
      database.ocptPersonPositionsTable,
    )..where((table) => table.id.equals(id) & table.isDeleted.not())).write(
      OcptPersonPositionsTableCompanion(positionId: positionId, customLabel: customLabel),
    );
  }

  /// Removes position assignment [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removePosition({required OcptProjectDatabase database, required String id}) async {
    if (database.refusesUserWrite("removePosition")) {
      return;
    }

    await (database.update(
      database.ocptPersonPositionsTable,
    )..where((table) => table.id.equals(id))).write(
      const OcptPersonPositionsTableCompanion(isDeleted: Value(true)),
    );
  }

  /// Reorders person [personId]'s positions to [orderedIds], which must be a permutation of their
  /// currently attached positions' ids. Only the ones that actually have to move are written.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderPositions({
    required OcptProjectDatabase database,
    required String personId,
    required List<String> orderedIds,
  }) async {
    if (database.refusesUserWrite("reorderPositions")) {
      return;
    }

    await database.transaction(() async {
      final rows = await _positionRowsOfPerson(database: database, personId: personId);
      final sortKeyById = {for (final row in rows) row.id: row.sortKey};
      final ids = orderedIds.where(sortKeyById.containsKey).toList(growable: false);

      final plan = ocptFractionalKeyRekeyPlan([for (final id in ids) sortKeyById[id]!]);

      for (final entry in plan.entries) {
        await (database.update(
          database.ocptPersonPositionsTable,
        )..where((table) => table.id.equals(ids[entry.key]))).write(
          OcptPersonPositionsTableCompanion(sortKey: Value(entry.value)),
        );
      }
    });
  }

  /// Adds a skill to person [personId], appended after their current skills, and returns its
  /// freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addSkill({
    required OcptProjectDatabase database,
    required String personId,
    required String label,
  }) async {
    if (database.refusesUserWrite("addSkill")) {
      return null;
    }

    final existing = await _skillRowsOfPerson(database: database, personId: personId);
    final id = const Uuid().v4();

    await database
        .into(database.ocptPersonSkillsTable)
        .insert(
          OcptPersonSkillsTableCompanion.insert(
            id: id,
            personId: personId,
            label: Value(label),
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates skill [id]'s label.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateSkill({
    required OcptProjectDatabase database,
    required String id,
    required String label,
  }) async {
    if (database.refusesUserWrite("updateSkill")) {
      return;
    }

    await (database.update(
      database.ocptPersonSkillsTable,
    )..where((table) => table.id.equals(id) & table.isDeleted.not())).write(
      OcptPersonSkillsTableCompanion(label: Value(label)),
    );
  }

  /// Removes skill [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeSkill({required OcptProjectDatabase database, required String id}) async {
    if (database.refusesUserWrite("removeSkill")) {
      return;
    }

    await (database.update(
      database.ocptPersonSkillsTable,
    )..where((table) => table.id.equals(id))).write(
      const OcptPersonSkillsTableCompanion(isDeleted: Value(true)),
    );
  }

  /// Reorders person [personId]'s skills to [orderedIds], which must be a permutation of their
  /// currently attached skills' ids. Only the ones that actually have to move are written.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderSkills({
    required OcptProjectDatabase database,
    required String personId,
    required List<String> orderedIds,
  }) async {
    if (database.refusesUserWrite("reorderSkills")) {
      return;
    }

    await database.transaction(() async {
      final rows = await _skillRowsOfPerson(database: database, personId: personId);
      final sortKeyById = {for (final row in rows) row.id: row.sortKey};
      final ids = orderedIds.where(sortKeyById.containsKey).toList(growable: false);

      final plan = ocptFractionalKeyRekeyPlan([for (final id in ids) sortKeyById[id]!]);

      for (final entry in plan.entries) {
        await (database.update(
          database.ocptPersonSkillsTable,
        )..where((table) => table.id.equals(ids[entry.key]))).write(
          OcptPersonSkillsTableCompanion(sortKey: Value(entry.value)),
        );
      }
    });
  }

  /// Adds an unavailability to person [personId], and returns its freshly generated id.
  ///
  /// [endDate] is clamped up to [startDate] rather than refused: a range that ends before it
  /// starts is a slip of a date picker, and the caller has nothing useful to do with an error.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addUnavailability({
    required OcptProjectDatabase database,
    required String personId,
    required DateTime startDate,
    required DateTime endDate,
    required OcptDayPartSlot slot,
    int? startMinute,
    int? endMinute,
    required String reason,
  }) async {
    if (database.refusesUserWrite("addUnavailability")) {
      return null;
    }

    final id = const Uuid().v4();

    await database
        .into(database.ocptPersonUnavailabilitiesTable)
        .insert(
          OcptPersonUnavailabilitiesTableCompanion.insert(
            id: id,
            personId: personId,
            startDate: startDate,
            endDate: endDate.isBefore(startDate) ? startDate : endDate,
            slot: Value(slot),
            startMinute: Value(startMinute),
            endMinute: Value(endMinute),
            reason: Value(reason),
          ),
        );

    return id;
  }

  /// Updates the fields of unavailability [id] that are passed as something other than
  /// [Value.absent].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateUnavailability({
    required OcptProjectDatabase database,
    required String id,
    Value<DateTime> startDate = const Value.absent(),
    Value<DateTime> endDate = const Value.absent(),
    Value<OcptDayPartSlot> slot = const Value.absent(),
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<String> reason = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateUnavailability")) {
      return;
    }

    await (database.update(
      database.ocptPersonUnavailabilitiesTable,
    )..where((table) => table.id.equals(id) & table.isDeleted.not())).write(
      OcptPersonUnavailabilitiesTableCompanion(
        startDate: startDate,
        endDate: endDate,
        slot: slot,
        startMinute: startMinute,
        endMinute: endMinute,
        reason: reason,
      ),
    );
  }

  /// Removes unavailability [id].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeUnavailability({
    required OcptProjectDatabase database,
    required String id,
  }) async {
    if (database.refusesUserWrite("removeUnavailability")) {
      return;
    }

    await (database.update(
      database.ocptPersonUnavailabilitiesTable,
    )..where((table) => table.id.equals(id))).write(
      const OcptPersonUnavailabilitiesTableCompanion(isDeleted: Value(true)),
    );
  }

  /// Every live person row of [database], ordered by `sortKey`.
  Future<List<OcptPersonRow>> _liveRows(OcptProjectDatabase database) =>
      (database.select(database.ocptPeopleTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Every live position row of person [personId], ordered by `sortKey`.
  Future<List<OcptPersonPositionRow>> _positionRowsOfPerson({
    required OcptProjectDatabase database,
    required String personId,
  }) => (database.select(database.ocptPersonPositionsTable)
        ..where((table) => table.personId.equals(personId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// Every live skill row of person [personId], ordered by `sortKey`.
  Future<List<OcptPersonSkillRow>> _skillRowsOfPerson({
    required OcptProjectDatabase database,
    required String personId,
  }) => (database.select(database.ocptPersonSkillsTable)
        ..where((table) => table.personId.equals(personId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();
}
