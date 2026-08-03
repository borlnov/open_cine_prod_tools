// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/types/ocpt_half_day.dart';
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
/// (`person_unavailabilities` carries no `sortKey`: it is an unordered set of dates, not a list a
/// user reorders — see `OcptPersonUnavailabilitiesTable`'s own doc comment).
///
/// **[deletePerson] is an erasure, not a plain tombstone** — decision 6 of the plan this service
/// ships under. See its own doc comment for exactly which columns are blanked.
class OcptPeopleService {
  /// Class constructor
  const OcptPeopleService();

  /// The write [deletePerson] uses to blank a person's personal columns.
  ///
  /// **Every column of `people` is blanked, except the four that are not personal data**: `id`
  /// (an opaque identifier, needed for the tombstone to mean anything), `sortKey` (list ordering,
  /// carries no information about the person), `isDeleted` (the tombstone itself, set to true
  /// rather than blanked) and `colorIndex` (an arbitrary palette index, not personal data). Every
  /// other column — name, contact details, address, birth date, transport/accommodation/travel
  /// notes, diet, allergies, sizes, HMC notes, image rights status/date/asset, free notes — held
  /// something about the person and is reset to its table default (empty string, `null`, or
  /// [OcptImageRightsStatus.notApplicable] for the one enum column) in this single write.
  static const _erasureCompanion = OcptPeopleTableCompanion(
    isDeleted: Value(true),
    firstName: Value(''),
    lastName: Value(''),
    email: Value(''),
    phone: Value(''),
    address: Value(''),
    city: Value(''),
    birthDate: Value(null),
    minorNotes: Value(''),
    isTransportAutonomous: Value(null),
    accommodationNotes: Value(''),
    travelNotes: Value(''),
    dietaryNotes: Value(''),
    allergies: Value(''),
    sizeTop: Value(''),
    sizeBottom: Value(''),
    sizeShoes: Value(''),
    hmcNotes: Value(''),
    imageRightsStatus: Value(OcptImageRightsStatus.notApplicable),
    imageRightsDate: Value(null),
    imageRightsAssetId: Value(null),
    photoAssetId: Value(null),
    notes: Value(''),
  );

  /// Loads every live person of [database], in `sortKey` order, each joined with its live
  /// [OcptPersonPosition]s, [OcptPersonSkill]s and [OcptPersonUnavailability]s.
  ///
  /// Runs four queries (one per table) regardless of how many people there are, the same trade-off
  /// `OcptShotListService.loadShotList` makes: an address book is dozens of rows, not millions, so
  /// joining them in memory here keeps each query trivial to read.
  Future<List<OcptPerson>> loadPeople({required OcptProjectDatabase database}) async {
    final personRows = await _liveRows(database);
    final personIds = personRows.map((row) => row.id).toList(growable: false);

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
                ..orderBy([(table) => OrderingTerm.asc(table.date)]))
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
    Value<String> address = const Value.absent(),
    Value<String> city = const Value.absent(),
    Value<int> colorIndex = const Value.absent(),
    Value<DateTime?> birthDate = const Value.absent(),
    Value<String> minorNotes = const Value.absent(),
    Value<bool?> isTransportAutonomous = const Value.absent(),
    Value<String> accommodationNotes = const Value.absent(),
    Value<String> travelNotes = const Value.absent(),
    Value<String> dietaryNotes = const Value.absent(),
    Value<String> allergies = const Value.absent(),
    Value<String> sizeTop = const Value.absent(),
    Value<String> sizeBottom = const Value.absent(),
    Value<String> sizeShoes = const Value.absent(),
    Value<String> hmcNotes = const Value.absent(),
    Value<OcptImageRightsStatus> imageRightsStatus = const Value.absent(),
    Value<DateTime?> imageRightsDate = const Value.absent(),
    Value<String?> imageRightsAssetId = const Value.absent(),
    Value<String?> photoAssetId = const Value.absent(),
    Value<String> notes = const Value.absent(),
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
        address: address,
        city: city,
        colorIndex: colorIndex,
        birthDate: birthDate,
        minorNotes: minorNotes,
        isTransportAutonomous: isTransportAutonomous,
        accommodationNotes: accommodationNotes,
        travelNotes: travelNotes,
        dietaryNotes: dietaryNotes,
        allergies: allergies,
        sizeTop: sizeTop,
        sizeBottom: sizeBottom,
        sizeShoes: sizeShoes,
        hmcNotes: hmcNotes,
        imageRightsStatus: imageRightsStatus,
        imageRightsDate: imageRightsDate,
        imageRightsAssetId: imageRightsAssetId,
        photoAssetId: photoAssetId,
        notes: notes,
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

      await database
          .into(database.ocptLocalErasuresTable)
          .insertOnConflictUpdate(
            OcptLocalErasuresTableCompanion.insert(personId: personId, erasedAt: DateTime.now()),
          );
    });
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
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addUnavailability({
    required OcptProjectDatabase database,
    required String personId,
    required DateTime date,
    required OcptHalfDay halfDay,
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
            date: date,
            halfDay: halfDay,
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
    Value<DateTime> date = const Value.absent(),
    Value<OcptHalfDay> halfDay = const Value.absent(),
    Value<String> reason = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateUnavailability")) {
      return;
    }

    await (database.update(
      database.ocptPersonUnavailabilitiesTable,
    )..where((table) => table.id.equals(id) & table.isDeleted.not())).write(
      OcptPersonUnavailabilitiesTableCompanion(date: date, halfDay: halfDay, reason: reason),
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
