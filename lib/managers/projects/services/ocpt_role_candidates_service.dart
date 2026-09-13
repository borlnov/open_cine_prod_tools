// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over `role_candidates`: the people seen for a part, what was thought of each of them, and
/// which one was retained.
///
/// `OcptRoleIndexService`'s companion on the casting side, owned by `OcptProjectsManager` beside
/// it. It exists as a service of its own, rather than as more methods on that one, for the reason
/// this whole table exists: **the retained rule is about two tables agreeing**, and it has to
/// answer the same way whoever asks. [retainCandidate] marks this candidate, turns every other
/// candidate still in the running down to [OcptRoleCandidateStatus.notRetained] and writes
/// `roles.personId`, all in one transaction; [setStatus] is the single door every status change
/// comes through, so no caller can move a candidate off [OcptRoleCandidateStatus.retained] and
/// leave the cast column pointing at them.
///
/// **The role header's own cast picker stays editable beside all of this**, and writes
/// `roles.personId` alone (`OcptRoleIndexService.updateRole`): a production that ran no auditions
/// casts directly and touches no row here. The reverse is not true — nothing here ever writes a
/// `people` row, and deleting a candidacy never touches the person it named: a person outlives a
/// candidacy exactly as a coat outlives the character who wore it.
///
/// {@macro open_cine_prod_tools.tombstones}
class OcptRoleCandidatesService {
  /// The statuses that leave a candidacy in the running — the rows retaining somebody turns down.
  ///
  /// Resolved off `OcptRoleCandidateStatus.isStillALead` rather than listed here, so the one place
  /// that reading is written stays the one place: a ninth status joins this set, or stays out of
  /// it, by answering that getter and nothing else.
  static final _leadStatuses = OcptRoleCandidateStatus.values
      .where((status) => status.isStillALead)
      .toList(growable: false);

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [tombstoneCandidatesOfRole] and [eraseCandidaciesOfPerson] never call
  /// it: they write inside a caller's own transaction, and take that caller's own
  /// [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptRoleCandidatesService({required this.deviceId});

  /// Loads every live candidacy of the project, grouped by `roleId`, each group in its own
  /// `sortKey` order — the casting director's own ranking of the people they have seen.
  ///
  /// Each row is joined with the person it names, taken from [people] rather than read again: the
  /// address book is already loaded by whoever asks for this (the resources mode reads both into
  /// one snapshot), and a second query for the same rows could only end up disagreeing with the
  /// first. A candidacy whose person is not in [people] — erased, or tombstoned — is **left out**
  /// rather than shown, exactly as a set's link onto a vanished scene is: the reference is gone,
  /// and "nobody" is what that means.
  ///
  /// The retained candidate is **not** pulled to the front here: that is a reading the card does
  /// when it draws the list, and this order is the one the user actually chose.
  Future<Map<String, List<OcptRoleCandidate>>> loadCandidatesByRoleId({
    required OcptProjectDatabase database,
    required List<OcptPerson> people,
  }) async {
    final rows = await _liveCandidateRows(database: database);
    final peopleById = {for (final person in people) person.id: person};

    final candidatesByRoleId = <String, List<OcptRoleCandidate>>{};
    for (final row in rows) {
      final person = peopleById[row.personId];
      if (person == null) {
        continue;
      }

      candidatesByRoleId
          .putIfAbsent(row.roleId, () => [])
          .add(OcptRoleCandidate.fromRow(row: row, person: person));
    }

    return candidatesByRoleId;
  }

  /// Records that [personId] is seen for role [roleId], appended after that role's other
  /// candidates, and returns the id of the candidacy — the one that already said so when there was
  /// one, a freshly generated one otherwise.
  ///
  /// Follows `OcptElementsService.addRoleElement`'s rules to the letter: a pair the role already
  /// carries is a no-op rather than a second row, and a candidacy removed earlier is **revived**
  /// rather than duplicated, keeping the status, the date and the notes it held — somebody seen
  /// again is the same person seen again, and what was written about them the first time is exactly
  /// what a casting director wants back.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addCandidate({
    required OcptProjectDatabase database,
    required String roleId,
    required String personId,
  }) async {
    if (database.refusesUserWrite("addCandidate")) {
      return null;
    }

    return database.transaction(() async {
      final existingCandidacies = await (database.select(
        database.ocptRoleCandidatesTable,
      )..where((table) => table.roleId.equals(roleId) & table.personId.equals(personId))).get();

      OcptRoleCandidateRow? droppedCandidacy;
      for (final candidacy in existingCandidacies) {
        if (!candidacy.isDeleted) {
          return candidacy.id;
        }

        droppedCandidacy ??= candidacy;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      if (droppedCandidacy != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRoleCandidatesTable,
          rowId: droppedCandidacy.id,
          current: droppedCandidacy,
          next: droppedCandidacy.copyWith(isDeleted: false),
          stamps: stamps,
        );
        await stamps.flush(database);

        return droppedCandidacy.id;
      }

      final existing = await _liveCandidateRows(database: database, roleId: roleId);
      final id = const Uuid().v4();
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleCandidatesTable,
        rowId: id,
        current: null,
        next: OcptRoleCandidateRow(
          id: id,
          roleId: roleId,
          personId: personId,
          status: OcptRoleCandidateStatus.seen,
          notes: '',
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// Updates the fields of candidacy [candidateId] that are passed as something other than
  /// [Value.absent].
  ///
  /// Never touches `status`, `sortKey` or the tombstone: those only change through [setStatus],
  /// [reorderCandidate] and [removeCandidate], the three writes that mean something beyond this
  /// row.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateCandidate({
    required OcptProjectDatabase database,
    required String candidateId,
    Value<DateTime?> auditionedOn = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateCandidate")) {
      return;
    }

    final companion = OcptRoleCandidatesTableCompanion(auditionedOn: auditionedOn, notes: notes);

    await database.transaction(() async {
      final current = await (database.select(database.ocptRoleCandidatesTable)
            ..where((table) => table.id.equals(candidateId) & table.isDeleted.not()))
          .getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleCandidatesTable,
        rowId: candidateId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves candidacy [candidateId] to [newPosition] (0-based) within role [roleId]'s own list, by
  /// giving it a `sortKey` sitting between the two candidacies it lands between. Writes **exactly
  /// one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderCandidate({
    required OcptProjectDatabase database,
    required String roleId,
    required String candidateId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderCandidate")) {
      return;
    }

    await database.transaction(() async {
      final rows = await _liveCandidateRows(database: database, roleId: roleId);
      final current = rows.where((row) => row.id == candidateId).firstOrNull;
      if (current == null) {
        return;
      }

      final others = rows.where((row) => row.id != candidateId).toList(growable: false);

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
        table: database.ocptRoleCandidatesTable,
        rowId: candidateId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Sets candidacy [candidateId]'s status to [status], keeping `roles.personId` in step with it.
  ///
  /// **The one door every status change comes through**, [retainCandidate] and [unretainCandidate]
  /// included, so the two tables cannot end up disagreeing whichever gesture the user made:
  ///
  /// - to [OcptRoleCandidateStatus.retained]: every **other** candidacy of the role still in the
  ///   running is turned down to [OcptRoleCandidateStatus.notRetained] — the part is cast, and they
  ///   did not get it — and `roles.personId` becomes this candidacy's own person. The ones already
  ///   closed keep the status that says how they closed, and a second retained row, if a file
  ///   somehow holds one, is turned down with the rest: see [_turnDownOtherLeadsOfRole], which owns
  ///   both halves of that;
  /// - **away** from [OcptRoleCandidateStatus.retained]: `roles.personId` goes back to null, the
  ///   cast column having been written by exactly the status now being taken away;
  /// - between two other statuses: nothing but this row is touched. A role cast **by hand** through
  ///   the sheet's own picker is in that case: its `personId` was never written by a candidacy, so
  ///   nothing here takes it away, and its candidates can be noted, ranked and turned down without
  ///   the casting ever moving.
  ///
  /// Does nothing when [candidateId] names no live candidacy.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> setStatus({
    required OcptProjectDatabase database,
    required String candidateId,
    required OcptRoleCandidateStatus status,
  }) async {
    if (database.refusesUserWrite("setStatus")) {
      return;
    }

    await database.transaction(() async {
      final candidacy = await (database.select(
        database.ocptRoleCandidatesTable,
      )..where((table) => table.id.equals(candidateId) & table.isDeleted.not())).getSingleOrNull();

      if (candidacy == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      if (status == OcptRoleCandidateStatus.retained) {
        await _turnDownOtherLeadsOfRole(
          database: database,
          roleId: candidacy.roleId,
          exceptCandidateId: candidateId,
          stamps: stamps,
        );
      }

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleCandidatesTable,
        rowId: candidateId,
        current: candidacy,
        next: candidacy.copyWith(status: status),
        stamps: stamps,
      );

      if (status == OcptRoleCandidateStatus.retained) {
        await _writeRoleCasting(
          database: database,
          roleId: candidacy.roleId,
          personId: candidacy.personId,
          stamps: stamps,
        );
      } else if (candidacy.status == OcptRoleCandidateStatus.retained) {
        await _writeRoleCasting(
          database: database,
          roleId: candidacy.roleId,
          personId: null,
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Retains candidacy [candidateId]: this person is the one cast in the part, and every other
  /// candidate still in the running is turned down with the same gesture. [setStatus]'s retaining
  /// half, named for the decision the card's own status list makes.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> retainCandidate({
    required OcptProjectDatabase database,
    required String candidateId,
  }) => setStatus(
    database: database,
    candidateId: candidateId,
    status: OcptRoleCandidateStatus.retained,
  );

  /// Drops candidacy [candidateId] back to [OcptRoleCandidateStatus.seen] and clears the part's
  /// casting with it. [retainCandidate]'s mirror on the cast column, and only there.
  ///
  /// The candidacy itself stays exactly where it was in the list, with its date and its notes: the
  /// person was still seen, and the record of it is the whole point of this table.
  ///
  /// **The other candidates are not brought back.** Retaining turned down everybody still in the
  /// running; un-retaining leaves them turned down, because what each of them held beforehand is
  /// recorded nowhere and guessing it is what this codebase refuses everywhere else. Changing one's
  /// mind about a casting therefore means saying so, row by row — which is the honest cost of the
  /// gesture, and the reason the card's status list is the only place a status ever moves.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> unretainCandidate({
    required OcptProjectDatabase database,
    required String candidateId,
  }) =>
      setStatus(database: database, candidateId: candidateId, status: OcptRoleCandidateStatus.seen);

  /// Removes candidacy [candidateId]: this person is no longer among the people seen for the part.
  ///
  /// **The `people` row is never touched** — a person outlives a candidacy — and neither is any
  /// other candidacy of the role. `roles.personId` is cleared when the candidacy being removed was
  /// the retained one, for the reason [setStatus] clears it when the status is taken away: the cast
  /// column was written by this very row, and a part cast by a candidacy that no longer exists is
  /// exactly the disagreement between two tables this service exists to prevent.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeCandidate({
    required OcptProjectDatabase database,
    required String candidateId,
  }) async {
    if (database.refusesUserWrite("removeCandidate")) {
      return;
    }

    await database.transaction(() async {
      final candidacy = await (database.select(
        database.ocptRoleCandidatesTable,
      )..where((table) => table.id.equals(candidateId) & table.isDeleted.not())).getSingleOrNull();

      if (candidacy == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleCandidatesTable,
        rowId: candidateId,
        current: candidacy,
        next: candidacy.copyWith(isDeleted: true),
        stamps: stamps,
      );

      if (candidacy.status == OcptRoleCandidateStatus.retained) {
        await _writeRoleCasting(
          database: database,
          roleId: candidacy.roleId,
          personId: null,
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Tombstones every `role_candidates` row naming role [roleId], the cascade
  /// `OcptRoleIndexService.deleteRole` reaches for once it has decided the role goes.
  ///
  /// The **people** these rows named are of course untouched, exactly as the elements a role's
  /// links pointed at are: an address book outlives a part being cut. `roles.personId` is not
  /// cleared either — the role itself is being tombstoned in the same transaction, so there is no
  /// disagreement left for anybody to read.
  ///
  /// **Unguarded**, exactly as `OcptElementsService.tombstoneRoleLinksOfRole` is: its only caller
  /// has already refused the write on a preview connection and is already inside the transaction
  /// removing the role, so a second guard here would only be able to disagree with the first.
  /// Stamps through [stamps] — that caller's own instance — rather than resolving a device id of
  /// its own.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneCandidatesOfRole({
    required OcptProjectDatabase database,
    required String roleId,
    required OcptRowStampService? stamps,
  }) async {
    final rows =
        await (database.select(
              database.ocptRoleCandidatesTable,
            )..where((table) => table.roleId.equals(roleId) & table.isDeleted.not()))
            .get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleCandidatesTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }

  /// Tombstones every `role_candidates` row naming person [personId] **and blanks its notes**: the
  /// cascade `OcptPeopleService.deletePerson` reaches for, this table being the one link table that
  /// holds something about a person rather than only ids.
  ///
  /// `notes` is what somebody wrote about this person at an audition, and an erasure is about what
  /// the project file stops holding, not about what a screen stops showing — the same reasoning
  /// that blanks `person_skills.label` and `person_unavailabilities.reason` beside it. The status,
  /// the date and the row itself stay, tombstoned, for the reason nothing in this schema is ever
  /// hard-deleted; `roles.personId` is left pointing at the blanked `people` row exactly as every
  /// other reference to an erased person is (see `OcptPeopleService.deletePerson`).
  ///
  /// **Unguarded**, for the reason [tombstoneCandidatesOfRole] is: its only caller has already
  /// refused the write on a preview connection and is already inside the transaction erasing the
  /// person. Stamps through [stamps], for the same reason.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> eraseCandidaciesOfPerson({
    required OcptProjectDatabase database,
    required String personId,
    required OcptRowStampService? stamps,
  }) async {
    final rows =
        await (database.select(
              database.ocptRoleCandidatesTable,
            )..where((table) => table.personId.equals(personId)))
            .get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleCandidatesTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true, notes: ''),
        stamps: stamps,
      );
    }
  }

  /// Turns down every live candidacy of role [roleId] other than [exceptCandidateId] that was still
  /// a lead — the "the part is cast, and the others did not get it" half of [setStatus].
  ///
  /// **The closed ones are left exactly as they are.** Somebody who declined, or who was
  /// unavailable, or who had already been turned down, keeps the status that says so: they did not
  /// lose the part to this casting, they were out of it before. Overwriting them with
  /// [OcptRoleCandidateStatus.notRetained] would be the app inventing a decision nobody made, and
  /// would lose the one distinction the three closed statuses exist for.
  ///
  /// **It subsumes the "one retained candidate at a time" rule** rather than sitting beside it: a
  /// second retained row is a lead like any other and is turned down here too. Written as a query
  /// over every matching row rather than as a read of "the" retained one, for that reason —
  /// nothing in the schema refuses a second, so a file that somehow holds two (a merge, a
  /// hand-edited database) is repaired by the next retaining rather than left to disagree with the
  /// cast column for ever.
  ///
  /// **Nothing undoes this.** Un-retaining ([unretainCandidate]) clears the cast column and leaves
  /// the turned-down rows turned down: what each of them held before is not recorded anywhere, and
  /// reconstructing it is exactly the guess this codebase refuses everywhere else.
  Future<void> _turnDownOtherLeadsOfRole({
    required OcptProjectDatabase database,
    required String roleId,
    required String exceptCandidateId,
    required OcptRowStampService? stamps,
  }) async {
    final rows =
        await (database.select(database.ocptRoleCandidatesTable)..where(
              (table) =>
                  table.roleId.equals(roleId) &
                  table.id.equals(exceptCandidateId).not() &
                  table.isDeleted.not() &
                  table.status.isInValues(_leadStatuses),
            ))
            .get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleCandidatesTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(status: OcptRoleCandidateStatus.notRetained),
        stamps: stamps,
      );
    }
  }

  /// Writes [personId] — a person, or null to leave the part uncast — into role [roleId]'s own
  /// `personId` column.
  ///
  /// The one place this service touches `roles`, and it goes straight to the table rather than
  /// through `OcptRoleIndexService.updateRole`: this always runs inside one of the transactions
  /// above, and the guard that method carries has already been answered by whichever public method
  /// opened it. Stamps through [stamps] — that caller's own instance.
  Future<void> _writeRoleCasting({
    required OcptProjectDatabase database,
    required String roleId,
    required String? personId,
    required OcptRowStampService? stamps,
  }) async {
    final current = await (database.select(
      database.ocptRolesTable,
    )..where((table) => table.id.equals(roleId) & table.isDeleted.not())).getSingleOrNull();

    if (current == null) {
      return;
    }

    await OcptRowStampService.writeAndStamp(
      database: database,
      table: database.ocptRolesTable,
      rowId: roleId,
      current: current,
      next: current.copyWith(personId: Value(personId)),
      stamps: stamps,
    );
  }

  /// Every live `role_candidates` row of the project — or of role [roleId] alone when one is given
  /// — ordered by `sortKey`.
  Future<List<OcptRoleCandidateRow>> _liveCandidateRows({
    required OcptProjectDatabase database,
    String? roleId,
  }) {
    final query = database.select(database.ocptRoleCandidatesTable)
      ..where(
        (table) => roleId == null
            ? table.isDeleted.not()
            : table.roleId.equals(roleId) & table.isDeleted.not(),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]);

    return query.get();
  }
}
