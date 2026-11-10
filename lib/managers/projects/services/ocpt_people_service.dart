// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_asset_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_detail_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_skill.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_unavailability.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
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
/// **[deletePerson] is an erasure, not a plain tombstone**. See its own doc comment for exactly
/// which columns are blanked.
class OcptPeopleService extends AbsOcptService {
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

  /// The service minting and tombstoning the `assets` rows a person owns — their photo and their
  /// signed image rights release. Held rather than reached for, exactly as
  /// `OcptLocationsService` holds its own.
  final OcptAssetsService assetsService;

  /// The service owning the `role_candidates` rows, held so [deletePerson] can carry this person's
  /// candidacies — and what was written about them at an audition — off with them.
  ///
  /// Held for the same reason [assetsService] is, and the edge runs the same way: that service
  /// never reads `people`, so nothing here closes a circle.
  final OcptRoleCandidatesService roleCandidatesService;

  /// {@macro open_cine_prod_tools.serviceDeviceIdGetter}
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptPeopleService({
    required super.logger,
    required this.deviceId,
    required this.assetsService,
    required this.roleCandidatesService,
  });

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Initialises the services this one owns, in the order they are listed in its constructor.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    await assetsService.initLifeCycle();
    await roleCandidatesService.initLifeCycle();
  }

  /// Load every live person of [database], in `sortKey` order, each joined with its live
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
  @useResult
  Future<OcptDatabaseResult<List<OcptPerson>>> loadPeople({
    required OcptProjectDatabase database,
  }) => guardResult("loadPeople", () async {
    final personRows = await _liveRows(database);
    final personIds = personRows.map((row) => row.id).toList(growable: false);

    final assetRows = personIds.isEmpty
        ? const <OcptAssetRow>[]
        : await (database.select(
            database.ocptAssetsTable,
          )..where((table) => table.personId.isIn(personIds) & table.isDeleted.not())).get();

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
  });

  /// Create a new, blank person in [database], appended at the end of the address book, and return
  /// its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseResult<String>> createPerson({required OcptProjectDatabase database}) =>
      guardResult("createPerson", () async {
        if (database.refusesUserWrite("createPerson")) {
          return null;
        }

        final existing = await _liveRows(database);
        final id = const Uuid().v4();

        await database.transaction(() async {
          final stamps = await OcptRowStampService.seed(
            database: database,
            deviceId: await deviceId(),
          );
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptPeopleTable,
            rowId: id,
            current: null,
            next: OcptPersonRow(
              id: id,
              sortKey: ocptFractionalKeyBetween(
                before: existing.isEmpty ? null : existing.last.sortKey,
              ),
              isDeleted: false,
              firstName: '',
              lastName: '',
              email: '',
              phone: '',
              addressLine1: '',
              addressLine2: '',
              postalCode: '',
              city: '',
              region: '',
              country: '',
              colorIndex: 0,
              minorNotes: '',
              accommodationNotes: '',
              travelNotes: '',
              dietaryNotes: '',
              allergies: '',
              measurementHeight: '',
              measurementChest: '',
              measurementWaist: '',
              measurementHips: '',
              sizeTop: '',
              sizeBottom: '',
              sizeShoes: '',
              hmcNotes: '',
              imageRightsStatus: OcptImageRightsStatus.notApplicable,
              notes: '',
            ),
            stamps: stamps,
          );
          await stamps.flush(database);
        });

        return id;
      });

  /// Update the fields of person [personId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderPerson] and [deletePerson].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> updatePerson({
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
  }) => guardOutcome("updatePerson", () async {
    if (database.refusesUserWrite("updatePerson")) {
      return;
    }

    final companion = OcptPeopleTableCompanion(
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
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals(personId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPeopleTable,
        rowId: personId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Erase person [personId] from [database]:
  /// tombstones the row and blanks its personal columns in the same write — see
  /// [_erasureCompanion] for exactly which ones — then records the erasure in `local_erasures`, the
  /// local, never-synchronised table that lets a later version restore refuse to resurrect this
  /// person (the restore side is `OcptProjectVersionsService`'s; this only writes the row).
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
  /// The `role_candidates` rows naming them — the parts they were seen for — go the same way,
  /// through `OcptRoleCandidatesService.eraseCandidaciesOfPerson`: tombstoned, with the `notes`
  /// somebody wrote about them at an audition blanked. **The `roles` they are cast in are uncast**:
  /// `roles.personId` is cleared (stamped) on each live one, so a part never counts as cast for
  /// somebody who no longer exists, in the casting progress, the schedule or the exports. Every
  /// other reference to an erased person (budget, elements, locations, a slot's crew) still points
  /// at the blanked row, which keeps resolving, since the schema hard-deletes nothing.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> deletePerson({
    required OcptProjectDatabase database,
    required String personId,
  }) => guardOutcome("deletePerson", () async {
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

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptPeopleTable,
        rowId: personId,
        current: row,
        next: row.copyWithCompanion(_erasureCompanion),
        stamps: stamps,
      );

      final positionRows = await (database.select(
        database.ocptPersonPositionsTable,
      )..where((table) => table.personId.equals(personId) & table.isDeleted.not())).get();
      for (final positionRow in positionRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptPersonPositionsTable,
          rowId: positionRow.id,
          current: positionRow,
          next: positionRow.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final skillRows = await (database.select(
        database.ocptPersonSkillsTable,
      )..where((table) => table.personId.equals(personId) & table.isDeleted.not())).get();
      for (final skillRow in skillRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptPersonSkillsTable,
          rowId: skillRow.id,
          current: skillRow,
          next: skillRow.copyWith(isDeleted: true, label: ''),
          stamps: stamps,
        );
      }

      final unavailabilityRows = await (database.select(
        database.ocptPersonUnavailabilitiesTable,
      )..where((table) => table.personId.equals(personId) & table.isDeleted.not())).get();
      for (final unavailabilityRow in unavailabilityRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptPersonUnavailabilitiesTable,
          rowId: unavailabilityRow.id,
          current: unavailabilityRow,
          next: unavailabilityRow.copyWith(isDeleted: true, reason: ''),
          stamps: stamps,
        );
      }

      final castRoleRows = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.personId.equals(personId) & table.isDeleted.not())).get();
      for (final roleRow in castRoleRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRolesTable,
          rowId: roleRow.id,
          current: roleRow,
          next: roleRow.copyWith(personId: const Value(null)),
          stamps: stamps,
        );
      }

      await assetsService.erasePersonAssets(database: database, personId: personId, stamps: stamps);

      await roleCandidatesService.eraseCandidaciesOfPerson(
        database: database,
        personId: personId,
        stamps: stamps,
      );

      await database
          .into(database.ocptLocalErasuresTable)
          .insertOnConflictUpdate(
            OcptLocalErasuresTableCompanion.insert(personId: personId, erasedAt: DateTime.now()),
          );

      await stamps.flush(database);
    });
  });

  /// Forward to [OcptPeopleAssetOps.setPersonPhoto].
  @useResult
  Future<OcptDatabaseResult<String>> setPersonPhoto({
    required OcptProjectDatabase database,
    required String personId,
    required String path,
    String label = "",
  }) => guardResult(
    "setPersonPhoto",
    () => OcptPeopleAssetOps.setPersonPhoto(
      database: database,
      personId: personId,
      path: path,
      label: label,
      deviceId: deviceId,
      assetsService: assetsService,
    ),
  );

  /// Forward to [OcptPeopleAssetOps.clearPersonPhoto].
  @useResult
  Future<OcptDatabaseOutcome> clearPersonPhoto({
    required OcptProjectDatabase database,
    required String personId,
  }) => guardOutcome(
    "clearPersonPhoto",
    () => OcptPeopleAssetOps.clearPersonPhoto(
      database: database,
      personId: personId,
      deviceId: deviceId,
      assetsService: assetsService,
    ),
  );

  /// Forward to [OcptPeopleAssetOps.setImageRightsDocument].
  @useResult
  Future<OcptDatabaseResult<String>> setImageRightsDocument({
    required OcptProjectDatabase database,
    required String personId,
    required String path,
    String label = "",
  }) => guardResult(
    "setImageRightsDocument",
    () => OcptPeopleAssetOps.setImageRightsDocument(
      database: database,
      personId: personId,
      path: path,
      label: label,
      deviceId: deviceId,
      assetsService: assetsService,
    ),
  );

  /// Forward to [OcptPeopleAssetOps.clearImageRightsDocument].
  @useResult
  Future<OcptDatabaseOutcome> clearImageRightsDocument({
    required OcptProjectDatabase database,
    required String personId,
  }) => guardOutcome(
    "clearImageRightsDocument",
    () => OcptPeopleAssetOps.clearImageRightsDocument(
      database: database,
      personId: personId,
      deviceId: deviceId,
      assetsService: assetsService,
    ),
  );

  /// Move person [personId] to [newPosition] (0-based) within the address book, by giving it a
  /// `sortKey` sitting between the two people it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> reorderPerson({
    required OcptProjectDatabase database,
    required String personId,
    required int newPosition,
  }) => guardOutcome("reorderPerson", () async {
    if (database.refusesUserWrite("reorderPerson")) {
      return;
    }

    await database.transaction(() async {
      final rows = await _liveRows(database);
      final current = rows.where((row) => row.id == personId).firstOrNull;
      if (current == null) {
        return;
      }

      final others = rows.where((row) => row.id != personId).toList(growable: false);

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
        table: database.ocptPeopleTable,
        rowId: personId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Forward to [OcptPeopleDetailOps.addPosition].
  @useResult
  Future<OcptDatabaseResult<String>> addPosition({
    required OcptProjectDatabase database,
    required String personId,
    required String positionId,
    required String customLabel,
  }) => guardResult(
    "addPosition",
    () => OcptPeopleDetailOps.addPosition(
      database: database,
      personId: personId,
      positionId: positionId,
      customLabel: customLabel,
      deviceId: deviceId,
    ),
  );

  /// Forward to [OcptPeopleDetailOps.updatePosition].
  @useResult
  Future<OcptDatabaseOutcome> updatePosition({
    required OcptProjectDatabase database,
    required String id,
    Value<String> positionId = const Value.absent(),
    Value<String> customLabel = const Value.absent(),
  }) => guardOutcome(
    "updatePosition",
    () => OcptPeopleDetailOps.updatePosition(
      database: database,
      id: id,
      positionId: positionId,
      customLabel: customLabel,
      deviceId: deviceId,
    ),
  );

  /// Forward to [OcptPeopleDetailOps.removePosition].
  @useResult
  Future<OcptDatabaseOutcome> removePosition({
    required OcptProjectDatabase database,
    required String id,
  }) => guardOutcome(
    "removePosition",
    () => OcptPeopleDetailOps.removePosition(database: database, id: id, deviceId: deviceId),
  );

  /// Forward to [OcptPeopleDetailOps.reorderPositions].
  @useResult
  Future<OcptDatabaseOutcome> reorderPositions({
    required OcptProjectDatabase database,
    required String personId,
    required List<String> orderedIds,
  }) => guardOutcome(
    "reorderPositions",
    () => OcptPeopleDetailOps.reorderPositions(
      database: database,
      personId: personId,
      orderedIds: orderedIds,
      deviceId: deviceId,
    ),
  );

  /// Forward to [OcptPeopleDetailOps.addSkill].
  @useResult
  Future<OcptDatabaseResult<String>> addSkill({
    required OcptProjectDatabase database,
    required String personId,
    required String label,
  }) => guardResult(
    "addSkill",
    () => OcptPeopleDetailOps.addSkill(
      database: database,
      personId: personId,
      label: label,
      deviceId: deviceId,
    ),
  );

  /// Forward to [OcptPeopleDetailOps.updateSkill].
  @useResult
  Future<OcptDatabaseOutcome> updateSkill({
    required OcptProjectDatabase database,
    required String id,
    required String label,
  }) => guardOutcome(
    "updateSkill",
    () => OcptPeopleDetailOps.updateSkill(
      database: database,
      id: id,
      label: label,
      deviceId: deviceId,
    ),
  );

  /// Forward to [OcptPeopleDetailOps.removeSkill].
  @useResult
  Future<OcptDatabaseOutcome> removeSkill({
    required OcptProjectDatabase database,
    required String id,
  }) => guardOutcome(
    "removeSkill",
    () => OcptPeopleDetailOps.removeSkill(database: database, id: id, deviceId: deviceId),
  );

  /// Forward to [OcptPeopleDetailOps.reorderSkills].
  @useResult
  Future<OcptDatabaseOutcome> reorderSkills({
    required OcptProjectDatabase database,
    required String personId,
    required List<String> orderedIds,
  }) => guardOutcome(
    "reorderSkills",
    () => OcptPeopleDetailOps.reorderSkills(
      database: database,
      personId: personId,
      orderedIds: orderedIds,
      deviceId: deviceId,
    ),
  );

  /// Forward to [OcptPeopleDetailOps.addUnavailability].
  @useResult
  Future<OcptDatabaseResult<String>> addUnavailability({
    required OcptProjectDatabase database,
    required String personId,
    required DateTime startDate,
    required DateTime endDate,
    required OcptDayPartSlot slot,
    int? startMinute,
    int? endMinute,
    required String reason,
  }) => guardResult(
    "addUnavailability",
    () => OcptPeopleDetailOps.addUnavailability(
      database: database,
      personId: personId,
      startDate: startDate,
      endDate: endDate,
      slot: slot,
      startMinute: startMinute,
      endMinute: endMinute,
      reason: reason,
      deviceId: deviceId,
    ),
  );

  /// Forward to [OcptPeopleDetailOps.updateUnavailability].
  @useResult
  Future<OcptDatabaseOutcome> updateUnavailability({
    required OcptProjectDatabase database,
    required String id,
    Value<DateTime> startDate = const Value.absent(),
    Value<DateTime> endDate = const Value.absent(),
    Value<OcptDayPartSlot> slot = const Value.absent(),
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<String> reason = const Value.absent(),
  }) => guardOutcome(
    "updateUnavailability",
    () => OcptPeopleDetailOps.updateUnavailability(
      database: database,
      id: id,
      startDate: startDate,
      endDate: endDate,
      slot: slot,
      startMinute: startMinute,
      endMinute: endMinute,
      reason: reason,
      deviceId: deviceId,
    ),
  );

  /// Forward to [OcptPeopleDetailOps.removeUnavailability].
  @useResult
  Future<OcptDatabaseOutcome> removeUnavailability({
    required OcptProjectDatabase database,
    required String id,
  }) => guardOutcome(
    "removeUnavailability",
    () => OcptPeopleDetailOps.removeUnavailability(database: database, id: id, deviceId: deviceId),
  );

  /// Get every live person row of [database], ordered by `sortKey`.
  Future<List<OcptPersonRow>> _liveRows(OcptProjectDatabase database) =>
      (database.select(database.ocptPeopleTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Disposes the services this one owns, in the reverse order they were initialised.
  @override
  Future<void> disposeLifeCycle() async {
    await roleCandidatesService.disposeLifeCycle();
    await assetsService.disposeLifeCycle();

    return super.disposeLifeCycle();
  }
}
