// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_rows.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:uuid/uuid.dart';

/// A slot's own timetable: placing a shot, reserving a hold, the milestones between them, and
/// moving a block within its slot or to another.
///
/// What `OcptScheduleService` forwards to; see `OcptScheduleDaysOps`.
abstract final class OcptScheduleBlocksOps {
  /// Places shot [shotId] inside slot [slotId], at [atPosition] within that slot's own timetable
  /// (or appended at the end when null), and returns the id of the freshly created block placing
  /// it. The day it lands on is read off [slotId]'s own row, so a block can never name a day its
  /// slot doesn't belong to.
  ///
  /// **Always creates a new block** — see the class doc comment: calling this on a shot already
  /// placed elsewhere adds a second placement rather than moving the first, exactly what a shot
  /// interrupted by the meal break needs. Moving an *existing* placement is [moveBlockToSlot] or
  /// the reorder, and removing one is [deleteBlock] — neither is this method's job.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> placeShot({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String slotId,
    required String shotId,
    int? atPosition,
  }) async {
    if (database.refusesUserWrite("placeShot")) {
      return null;
    }

    return database.transaction(() async {
      final slot = await OcptScheduleRows.getSlotRow(database: database, slotId: slotId);
      final dayId = slot.shootingDayId;

      final slotBlocks = await OcptScheduleRows.liveBlockRowsOfSlot(
        database: database,
        slotId: slotId,
      );

      final clampedPosition = atPosition == null
          ? slotBlocks.length
          : (atPosition < 0
                ? 0
                : (atPosition > slotBlocks.length ? slotBlocks.length : atPosition));

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? slotBlocks[clampedPosition - 1].sortKey : null,
        after: clampedPosition < slotBlocks.length ? slotBlocks[clampedPosition].sortKey : null,
      );

      final id = const Uuid().v4();
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDayBlocksTable,
        rowId: id,
        current: null,
        next: OcptShootingDayBlockRow(
          id: id,
          shootingDayId: dayId,
          sortKey: sortKey,
          slotId: slotId,
          kind: OcptShootingBlockKind.shot,
          shotId: shotId,
          label: '',
          notes: '',
          crewNote: '',
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
      return id;
    });
  }

  /// Tombstones block [blockId], whatever its [OcptShootingBlockKind] — a shot block, a milestone,
  /// a `hold` or an `audition` — **and the candidacies an audition names along with it**. Removing
  /// a shot's placement, now that a shot may carry several, means naming the block it sits in and
  /// calling this — there is no operation keyed by shot any more.
  ///
  /// The cascade is the counterpart of what a candidate's convocation *is* (ADR 0024): the block is
  /// the hour they are expected at, so an audition that is gone convokes nobody, and a link left
  /// live would keep somebody on a day whose timetable no longer holds it. The `role_candidates`
  /// row itself is untouched: a candidacy outlives an audition exactly as a person outlives a
  /// candidacy.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> deleteBlock({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String blockId,
  }) async {
    if (database.refusesUserWrite("deleteBlock")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await OcptScheduleRows.tombstoneCandidaciesOfBlocks(
        database: database,
        blockIds: [blockId],
        stamps: stamps,
      );

      final current = await (database.select(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.id.equals(blockId))).getSingleOrNull();
      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingDayBlocksTable,
          rowId: blockId,
          current: current,
          next: current.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Creates a new block inside slot [slotId], at [atPosition] within that slot's own timetable (or
  /// appended at the end when null), and returns its freshly generated id. The day it belongs to is
  /// read off [slotId]'s own row.
  ///
  /// **[kind] must not be [OcptShootingBlockKind.shot].** [placeShot] is the only writer of a shot
  /// block, since one also needs its `shotId` set in the very same write to keep `shotId` non-null
  /// **iff** `kind == shot`; passing [OcptShootingBlockKind.shot] here is refused (returns null,
  /// writes nothing) rather than creating a shot block with no shot.
  ///
  /// **[sceneId] belongs to a [OcptShootingBlockKind.hold] and a [OcptShootingBlockKind.rehearsal]
  /// and to nothing else** — the sequence whose time is being reserved, or which is being worked,
  /// which is what says who either convokes (ADR 0017). Passed with any other [kind] it is
  /// **ignored** rather than refused: the block itself is legitimate, only the scene link means
  /// nothing on it, and a caller that hands one over is choosing a kind, not making a claim about a
  /// sequence. It stays null on a hold or a rehearsal whose sequence hasn't been settled yet, which
  /// is an ordinary state.
  ///
  /// **An [OcptShootingBlockKind.audition] takes no link at all here**: who it sees, and for which
  /// part, is `shooting_block_candidates`, added afterwards through `addBlockCandidate` — a block
  /// that names nobody yet is an ordinary state, exactly as a hold with no sequence is, and one
  /// block regularly names several (ADR 0024).
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> createBlock({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String slotId,
    required OcptShootingBlockKind kind,
    String? sceneId,
    String label = "",
    int? durationMinutes,
    int? anchorMinute,
    String notes = "",
    int? atPosition,
  }) async {
    if (database.refusesUserWrite("createBlock")) {
      return null;
    }

    if (kind == OcptShootingBlockKind.shot) {
      return null;
    }

    return database.transaction(() async {
      final slot = await OcptScheduleRows.getSlotRow(database: database, slotId: slotId);
      final slotBlocks = await OcptScheduleRows.liveBlockRowsOfSlot(
        database: database,
        slotId: slotId,
      );
      final clampedPosition = atPosition == null
          ? slotBlocks.length
          : (atPosition < 0
                ? 0
                : (atPosition > slotBlocks.length ? slotBlocks.length : atPosition));

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? slotBlocks[clampedPosition - 1].sortKey : null,
        after: clampedPosition < slotBlocks.length ? slotBlocks[clampedPosition].sortKey : null,
      );

      final id = const Uuid().v4();
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDayBlocksTable,
        rowId: id,
        current: null,
        next: OcptShootingDayBlockRow(
          id: id,
          shootingDayId: slot.shootingDayId,
          sortKey: sortKey,
          slotId: slotId,
          kind: kind,
          sceneId: _namesASequence(kind) ? sceneId : null,
          label: label,
          durationMinutes: durationMinutes,
          anchorMinute: anchorMinute,
          notes: notes,
          crewNote: '',
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// Updates the fields of block [blockId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `shotId`, `sortKey` or `isDeleted`: those only change through
  /// [placeShot], block reordering/moving and [deleteBlock].
  ///
  /// **[kind] may never become [OcptShootingBlockKind.shot] here, and a block that already is one
  /// keeps it** — both refused as a no-op: setting it would either need a `shotId` this method
  /// doesn't take, or, for an existing shot block, would orphan the `shotId` it already carries,
  /// which this method does not touch. Turning a shot block into something else means deleting it
  /// first ([deleteBlock]) and creating the other block afterwards ([createBlock]).
  ///
  /// **`sceneId` only ever holds on a [OcptShootingBlockKind.hold] or a
  /// [OcptShootingBlockKind.rehearsal]**, the same invariant [createBlock] enforces: a scene named
  /// on a block of any other kind is dropped to null, and a hold turned into a meal by this very
  /// call loses the sequence it was holding — it is no longer holding anything. A hold turned into
  /// a rehearsal **keeps** it: the same sequence, now being worked rather than merely reserved. A
  /// scene is set to null the ordinary way, by passing `Value(null)`, which is how a production
  /// un-decides which sequence a reserved slot is for.
  ///
  /// **An audition turned into anything else loses the candidacies it named**, tombstoned in this
  /// very transaction — the same rule `sceneId` follows one column across, and for the same reason:
  /// a meal break sees nobody, so a link saying somebody is read during it convokes them at an hour
  /// nothing auditions at. The `role_candidates` rows themselves are untouched, a candidacy
  /// outliving the audition that was going to see it.
  ///
  /// **[notes] and [crewNote] are not the same field wearing two names**: [notes] never prints,
  /// [crewNote] does — see `OcptShootingDayBlocksTable`'s own doc comment on each.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateBlock({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String blockId,
    Value<OcptShootingBlockKind> kind = const Value.absent(),
    Value<String?> sceneId = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<int?> durationMinutes = const Value.absent(),
    Value<int?> anchorMinute = const Value.absent(),
    Value<String> notes = const Value.absent(),
    Value<String> crewNote = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateBlock")) {
      return;
    }

    if (kind.present && kind.value == OcptShootingBlockKind.shot) {
      return;
    }

    await database.transaction(() async {
      var sceneIdToWrite = sceneId;

      final row = await (database.select(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.id.equals(blockId) & table.isDeleted.not())).getSingleOrNull();

      if (row == null) {
        return;
      }

      var resultingKind = row.kind;
      if (kind.present || sceneId.present) {
        if (kind.present && row.kind == OcptShootingBlockKind.shot) {
          return;
        }

        resultingKind = kind.present ? kind.value : row.kind;
        if (!_namesASequence(resultingKind)) {
          sceneIdToWrite = const Value(null);
        }
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      if (row.kind == OcptShootingBlockKind.audition &&
          resultingKind != OcptShootingBlockKind.audition) {
        await OcptScheduleRows.tombstoneCandidaciesOfBlocks(
          database: database,
          blockIds: [blockId],
          stamps: stamps,
        );
      }

      final companion = OcptShootingDayBlocksTableCompanion(
        kind: kind,
        sceneId: sceneIdToWrite,
        label: label,
        durationMinutes: durationMinutes,
        anchorMinute: anchorMinute,
        notes: notes,
        crewNote: crewNote,
      );

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDayBlocksTable,
        rowId: blockId,
        current: row,
        next: row.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves block [blockId] to [newPosition] (0-based) within its own slot's timetable, by giving it
  /// a `sortKey` sitting between the two blocks it lands between there. Writes **exactly one row**.
  ///
  /// **`sortKey` stays day-wide** — these tables have no per-slot scope of their own, so a key
  /// allocated between two of one slot's blocks may well land, numerically, among another slot's.
  /// That is harmless: ordering is only ever read *within* a slot ([OcptScheduleRows.liveBlockRowsOfSlot]), and two
  /// slots' chains are independent of one another (ADR 0015, amended).
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> reorderBlock({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String blockId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderBlock")) {
      return;
    }

    await database.transaction(() async {
      final block = await OcptScheduleRows.getBlockRow(database: database, blockId: blockId);
      final others = (await OcptScheduleRows.liveBlockRowsOfSlot(
        database: database,
        slotId: block.slotId,
      ))..removeWhere((row) => row.id == blockId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      final current = await (database.select(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.id.equals(blockId))).getSingleOrNull();
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDayBlocksTable,
        rowId: blockId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves block [blockId] to slot [targetSlotId], at [newPosition] (0-based) within that slot's
  /// own timetable, by giving it a `sortKey` sitting between the two blocks it lands between there.
  /// Writes **exactly one row**: both the block's `slotId` and its `shootingDayId` — read off
  /// [targetSlotId]'s own row, so a block can never end up pointing at a day its slot doesn't
  /// belong to — change in the same write as its `sortKey`. Replaces the old `moveBlockToDay`,
  /// whose "always nulls the slotId" rule disappears with it: a block belongs to exactly one slot
  /// from schema v12 on, so moving it across days now always means moving it into a slot of the
  /// destination day too, never leaving it slotless.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> moveBlockToSlot({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String blockId,
    required String targetSlotId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("moveBlockToSlot")) {
      return;
    }

    await database.transaction(() async {
      final targetSlot = await OcptScheduleRows.getSlotRow(
        database: database,
        slotId: targetSlotId,
      );
      final others = await OcptScheduleRows.liveBlockRowsOfSlot(
        database: database,
        slotId: targetSlotId,
      );

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      final current = await (database.select(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.id.equals(blockId))).getSingleOrNull();
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDayBlocksTable,
        rowId: blockId,
        current: current,
        next: current.copyWith(
          shootingDayId: targetSlot.shootingDayId,
          slotId: targetSlotId,
          sortKey: sortKey,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones every live `shooting_day_blocks` row placing any of [shotIds]:
  /// `OcptScreenplayService`'s episode-delete cascade, once its own shot list service has handed it
  /// the ids of the shots going with the episode. **The day, its slots, its convocations and its
  /// every other block are untouched** — the schedule is the production's, not any one episode's
  /// (`docs/adr/0019-one-project-several-episodes.md`), and a block placing one of the episode's
  /// shots is the one fact about it this service ever has to give up: the day it sat on was never
  /// that episode's to begin with.
  ///
  /// **Unguarded**, exactly as `OcptElementsService.tombstoneRoleLinksOfRole` is: its only caller
  /// has already refused the write on a preview connection and is already inside the transaction
  /// removing the episode, so a second guard here would only be able to disagree with the first —
  /// and stamps through [stamps], that caller's own instance, rather than resolving a device id of
  /// its own.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  static Future<void> tombstoneShotBlocks({
    required OcptProjectDatabase database,
    required List<String> shotIds,
    required OcptRowStampService? stamps,
  }) async {
    if (shotIds.isEmpty) {
      return;
    }

    final rows = await (database.select(
      database.ocptShootingDayBlocksTable,
    )..where((table) => table.shotId.isIn(shotIds) & table.isDeleted.not())).get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDayBlocksTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }

  /// Whether a block of [kind] names a sequence through `shooting_day_blocks.sceneId`: a
  /// [OcptShootingBlockKind.hold] reserves one's time, a [OcptShootingBlockKind.rehearsal] works
  /// it, and no other kind has anything to say about a sequence.
  ///
  /// Written once and read by [createBlock] and [updateBlock] alike, so the two cannot come to
  /// disagree about which kinds keep the column.
  static bool _namesASequence(OcptShootingBlockKind kind) =>
      kind == OcptShootingBlockKind.hold || kind == OcptShootingBlockKind.rehearsal;
}
