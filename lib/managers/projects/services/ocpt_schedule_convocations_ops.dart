// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_rows.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_crew_position_ref.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_crew_position_prefill.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:uuid/uuid.dart';

/// Who is convoked: the crew, the cast roles and the guests linked to a slot, and the candidates
/// linked to the audition block that sees them.
///
/// What `OcptScheduleService` forwards to; see `OcptScheduleDaysOps`.
abstract final class OcptScheduleConvocationsOps {
  /// Add [personId] as holding [positionId] (or, when the catalogue has nothing that fits,
  /// [customLabel]) during slot [slotId], appended at the end of its current crew, and return the
  /// freshly generated id of the assignment — no more than the link itself: this person's arrival,
  /// readiness band and departure are read off every slot they are linked to (ADR 0018), never
  /// seeded or typed here.
  ///
  /// A person holding two positions in one slot is two rows — see `OcptShootingSlotCrewTable`'s own
  /// doc comment — so, unlike [addSlotCastRole], this never refuses a duplicate
  /// `{slotId, personId}` pair.
  ///
  /// **When the caller passes neither [positionId] nor [customLabel], the position is pre-filled**
  /// through `ocptCrewPositionPrefillOf`: [personId]'s live `person_positions` rows, in their
  /// declared order, joined against what they already hold live on this same slot, land the new row
  /// on their first declared position not already taken there — nothing declared, or everything
  /// already taken, leaves the row with no position, exactly as before this join existed. A caller
  /// passing either explicitly keeps it untouched; the pre-fill only ever fills a blank.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addSlotCrewMember({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String slotId,
    required String personId,
    String positionId = "",
    String customLabel = "",
    String notes = "",
  }) async {
    if (database.refusesUserWrite("addSlotCrewMember")) {
      return null;
    }

    final existing = await OcptScheduleRows.liveCrewRowsOfSlot(database: database, slotId: slotId);

    var resolvedPositionId = positionId;
    var resolvedCustomLabel = customLabel;
    if (resolvedPositionId.isEmpty && resolvedCustomLabel.isEmpty) {
      final declaredPositions = await OcptScheduleRows.livePositionRowsOfPerson(
        database: database,
        personId: personId,
      );
      final prefill = ocptCrewPositionPrefillOf(
        declaredPositions: [
          for (final row in declaredPositions)
            OcptCrewPositionRef(positionId: row.positionId, customLabel: row.customLabel),
        ],
        heldOnSlot: [
          for (final row in existing)
            if (row.personId == personId)
              OcptCrewPositionRef(positionId: row.positionId, customLabel: row.customLabel),
        ],
      ).prefill;
      resolvedPositionId = prefill?.positionId ?? "";
      resolvedCustomLabel = prefill?.customLabel ?? "";
    }

    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotCrewTable,
        rowId: id,
        current: null,
        next: OcptShootingSlotCrewRow(
          id: id,
          slotId: slotId,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          personId: personId,
          positionId: resolvedPositionId,
          customLabel: resolvedCustomLabel,
          notes: notes,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Update the fields of crew assignment [crewMemberId] in [database] that are passed as
  /// something other than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change
  /// through slot reordering and [removeSlotCrewMember].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateSlotCrewMember({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String crewMemberId,
    Value<String> personId = const Value.absent(),
    Value<String> positionId = const Value.absent(),
    Value<String> customLabel = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSlotCrewMember")) {
      return;
    }

    final companion = OcptShootingSlotCrewTableCompanion(
      personId: personId,
      positionId: positionId,
      customLabel: customLabel,
      notes: notes,
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingSlotCrewTable,
      )..where((table) => table.id.equals(crewMemberId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotCrewTable,
        rowId: crewMemberId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstone crew assignment [crewMemberId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> removeSlotCrewMember({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String crewMemberId,
  }) async {
    if (database.refusesUserWrite("removeSlotCrewMember")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingSlotCrewTable,
      )..where((table) => table.id.equals(crewMemberId))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotCrewTable,
        rowId: crewMemberId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Convoke role [roleId] during slot [slotId], appended at the end of its current cast, and
  /// return the id of the convocation — no more than the link itself: this role's arrival,
  /// readiness band and departure are read off every slot it is linked to (ADR 0018), never seeded
  /// or typed here.
  ///
  /// **The same role convoked twice in one slot is refused** — unlike crew, where two positions
  /// held by the same person are legitimate (see [addSlotCrewMember]): a role already convoked live
  /// in this slot has this call return that row's own id rather than create a second one. A role
  /// convoked here before and since removed has its tombstone lifted rather than a second row being
  /// created, exactly as `OcptLocationsService.assignSceneToSet` revives a dropped link rather than
  /// duplicating it.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addSlotCastRole({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String slotId,
    required String roleId,
    String notes = "",
  }) async {
    if (database.refusesUserWrite("addSlotCastRole")) {
      return null;
    }

    return database.transaction(() async {
      final existingRows = await (database.select(
        database.ocptShootingSlotCastTable,
      )..where((table) => table.slotId.equals(slotId) & table.roleId.equals(roleId))).get();

      OcptShootingSlotCastRow? tombstoned;
      for (final row in existingRows) {
        if (!row.isDeleted) {
          return row.id;
        }
        tombstoned ??= row;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      if (tombstoned != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingSlotCastTable,
          rowId: tombstoned.id,
          current: tombstoned,
          next: tombstoned.copyWith(notes: notes, isDeleted: false),
          stamps: stamps,
        );
        await stamps.flush(database);
        return tombstoned.id;
      }

      final existing = await OcptScheduleRows.liveCastRowsOfSlot(
        database: database,
        slotId: slotId,
      );
      final id = const Uuid().v4();

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotCastTable,
        rowId: id,
        current: null,
        next: OcptShootingSlotCastRow(
          id: id,
          slotId: slotId,
          roleId: roleId,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          notes: notes,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// Update the fields of cast convocation [castRoleId] in [database] that are passed as something
  /// other than [Value.absent]. Never touches `sortKey`, `roleId` or `isDeleted`: those only change
  /// through slot reordering, [addSlotCastRole] and [removeSlotCastRole].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateSlotCastRole({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String castRoleId,
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSlotCastRole")) {
      return;
    }

    final companion = OcptShootingSlotCastTableCompanion(notes: notes);

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingSlotCastTable,
      )..where((table) => table.id.equals(castRoleId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotCastTable,
        rowId: castRoleId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstone cast convocation [castRoleId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> removeSlotCastRole({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String castRoleId,
  }) async {
    if (database.refusesUserWrite("removeSlotCastRole")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingSlotCastTable,
      )..where((table) => table.id.equals(castRoleId))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotCastTable,
        rowId: castRoleId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Add a guest to slot [slotId], appended at the end of its current guests, and return the
  /// freshly generated id of the attendance — no more than the link itself: this guest's arrival
  /// and departure are read off every slot they are linked to (ADR 0018), never seeded or typed
  /// here.
  ///
  /// **Exactly one of [personId]/[freeName] must be given**: they are the two halves of one
  /// discriminator (see `OcptShootingSlotGuestsTable`), and a call passing both, or neither, writes
  /// nothing rather than picking one.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addSlotGuest({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String slotId,
    String? personId,
    String? freeName,
    String reason = "",
    String notes = "",
  }) async {
    if (database.refusesUserWrite("addSlotGuest")) {
      return null;
    }

    final resolvedFreeName = freeName ?? "";
    if ((personId == null) == resolvedFreeName.isEmpty) {
      return null;
    }

    return database.transaction(() async {
      final existing = await OcptScheduleRows.liveGuestRowsOfSlot(
        database: database,
        slotId: slotId,
      );
      final id = const Uuid().v4();

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotGuestsTable,
        rowId: id,
        current: null,
        next: OcptShootingSlotGuestRow(
          id: id,
          slotId: slotId,
          personId: personId,
          freeName: resolvedFreeName,
          reason: reason,
          notes: notes,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// Update the fields of guest attendance [guestId] in [database] that are passed as something
  /// other than [Value.absent]. Never touches `sortKey` or `isDeleted`: the first is allocated
  /// once, at insertion — nothing reorders a slot's guests, there being no order worth arguing
  /// about between two people watching the same afternoon — and the second only changes through
  /// [deleteSlotGuest].
  ///
  /// **May move a guest between the two halves of the discriminator**, but refuses a write that
  /// would leave [personId]/[freeName] both set or both empty — exactly the guarantee
  /// [addSlotGuest] gives a fresh row, kept over an edit to an existing one. A caller changing only
  /// one of the pair must therefore also clear the other in the same call.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateSlotGuest({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String guestId,
    Value<String?> personId = const Value.absent(),
    Value<String> freeName = const Value.absent(),
    Value<String> reason = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSlotGuest")) {
      return;
    }

    final companion = OcptShootingSlotGuestsTableCompanion(
      personId: personId,
      freeName: freeName,
      reason: reason,
      notes: notes,
    );

    await database.transaction(() async {
      final row = await (database.select(
        database.ocptShootingSlotGuestsTable,
      )..where((table) => table.id.equals(guestId) & table.isDeleted.not())).getSingleOrNull();
      if (row == null) {
        return;
      }

      if (personId.present || freeName.present) {
        final resultingPersonId = personId.present ? personId.value : row.personId;
        final resultingFreeName = freeName.present ? freeName.value : row.freeName;
        if ((resultingPersonId == null) == resultingFreeName.isEmpty) {
          return;
        }
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotGuestsTable,
        rowId: guestId,
        current: row,
        next: row.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstone guest attendance [guestId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> deleteSlotGuest({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String guestId,
  }) async {
    if (database.refusesUserWrite("deleteSlotGuest")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingSlotGuestsTable,
      )..where((table) => table.id.equals(guestId))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotGuestsTable,
        rowId: guestId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Name candidacy [roleCandidateId] on audition block [blockId], appended at the end of that
  /// block's own candidacies, and return the id of the convocation — the one that already said so
  /// when there was one, a freshly generated one otherwise. No more than the link itself: this
  /// candidate's arrival, PAT band and departure are read off every audition block naming them
  /// (ADR 0018 as ADR 0024 applies it), never seeded or typed here.
  ///
  /// **Refuses a block that is not an [OcptShootingBlockKind.audition]** (returns null, writes
  /// nothing): a candidacy on a meal break or a shot would say somebody was being seen at an hour
  /// nothing in the day sees anybody at, and the timeline, the convocations and the call sheet all
  /// read this link as an audition's own.
  ///
  /// Follows [addSlotCastRole] rule for rule otherwise, and for the same reason: a `{blockId,
  /// roleCandidateId}` pair the block already carries is a **no-op** rather than a second row —
  /// naming somebody twice at one hour says nothing the first row didn't — and a convocation
  /// removed earlier is **revived** rather than duplicated.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addBlockCandidate({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String blockId,
    required String roleCandidateId,
    String notes = "",
  }) async {
    if (database.refusesUserWrite("addBlockCandidate")) {
      return null;
    }

    return database.transaction(() async {
      final block = await OcptScheduleRows.getBlockRow(database: database, blockId: blockId);
      if (block.kind != OcptShootingBlockKind.audition) {
        return null;
      }

      final existingRows =
          await (database.select(database.ocptShootingBlockCandidatesTable)..where(
                (table) =>
                    table.blockId.equals(blockId) & table.roleCandidateId.equals(roleCandidateId),
              ))
              .get();

      OcptShootingBlockCandidateRow? tombstoned;
      for (final row in existingRows) {
        if (!row.isDeleted) {
          return row.id;
        }
        tombstoned ??= row;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      if (tombstoned != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingBlockCandidatesTable,
          rowId: tombstoned.id,
          current: tombstoned,
          next: tombstoned.copyWith(notes: notes, isDeleted: false),
          stamps: stamps,
        );
        await stamps.flush(database);
        return tombstoned.id;
      }

      final existing = await OcptScheduleRows.liveCandidateRowsOfBlock(
        database: database,
        blockId: blockId,
      );
      final id = const Uuid().v4();

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingBlockCandidatesTable,
        rowId: id,
        current: null,
        next: OcptShootingBlockCandidateRow(
          id: id,
          blockId: blockId,
          roleCandidateId: roleCandidateId,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          notes: notes,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// Update the fields of candidate convocation [blockCandidateId] in [database] that are passed
  /// as something other than [Value.absent]. Never touches `sortKey`, `roleCandidateId` or
  /// `isDeleted`: those only change through `addBlockCandidate`, [reorderBlockCandidate] and
  /// [removeBlockCandidate].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateBlockCandidate({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String blockCandidateId,
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateBlockCandidate")) {
      return;
    }

    final companion = OcptShootingBlockCandidatesTableCompanion(notes: notes);

    await database.transaction(() async {
      final current =
          await (database.select(database.ocptShootingBlockCandidatesTable)
                ..where((table) => table.id.equals(blockCandidateId) & table.isDeleted.not()))
              .getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingBlockCandidatesTable,
        rowId: blockCandidateId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Move candidate convocation [blockCandidateId] to [newPosition] (0-based) among its own
  /// block's candidacies, by giving it a `sortKey` sitting between the two it lands between there.
  /// Writes **exactly one row**, exactly as `reorderBlock` does.
  ///
  /// The order matters where two actors are read together: it is the order the block's own chips
  /// draw them in, and the order the call sheet's audition table prints them under a shared hour.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> reorderBlockCandidate({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String blockCandidateId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderBlockCandidate")) {
      return;
    }

    await database.transaction(() async {
      final row =
          await (database.select(database.ocptShootingBlockCandidatesTable)
                ..where((table) => table.id.equals(blockCandidateId) & table.isDeleted.not()))
              .getSingleOrNull();
      if (row == null) {
        return;
      }

      final others = (await OcptScheduleRows.liveCandidateRowsOfBlock(
        database: database,
        blockId: row.blockId,
      ))..removeWhere((other) => other.id == blockCandidateId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      final current = await (database.select(
        database.ocptShootingBlockCandidatesTable,
      )..where((table) => table.id.equals(blockCandidateId))).getSingleOrNull();
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingBlockCandidatesTable,
        rowId: blockCandidateId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstone candidate convocation [blockCandidateId].
  ///
  /// **Touches neither the block nor the candidacy**: the audition stays exactly where it is and
  /// says what the day still plans to do at that hour, and the `role_candidates` row outlives the
  /// convocation exactly as a person outlives a candidacy. Taking somebody out of an audition and
  /// taking that audition out of the running order are two gestures, and folding them would delete
  /// a row the user never pointed at.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> removeBlockCandidate({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String blockCandidateId,
  }) async {
    if (database.refusesUserWrite("removeBlockCandidate")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingBlockCandidatesTable,
      )..where((table) => table.id.equals(blockCandidateId))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingBlockCandidatesTable,
        rowId: blockCandidateId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }
}
