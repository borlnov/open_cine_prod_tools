// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_rows.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:uuid/uuid.dart';

/// The convocation windows of a shooting day: a slot's creation, its edit, its anchor, its order and
/// its deletion, which moves or drops the blocks scheduled inside it.
///
/// What `OcptScheduleService` forwards to; see `OcptScheduleDaysOps`.
abstract final class OcptScheduleSlotsOps {
  /// Create a new slot inside day [shootingDayId], appended at the end of its current slots,
  /// anchored **by its start** at [anchorMinute], and return its freshly generated id.
  ///
  /// A new slot is always start-anchored at a typed hour, which is the only anchor a slot could
  /// have before schema version 14 and the only one that needs nothing else to already exist:
  /// pinning it by its end, or reading its hour off a sibling, is [setSlotAnchor]'s job, once there
  /// is a slot to talk about.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> createSlot({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String shootingDayId,
    required int anchorMinute,
    String label = "",
    String? locationId,
    String? setId,
    String notes = "",
  }) async {
    if (database.refusesUserWrite("createSlot")) {
      return null;
    }

    return database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      final existing = await OcptScheduleRows.liveSlotRows(
        database: database,
        dayId: shootingDayId,
      );
      final id = const Uuid().v4();

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotsTable,
        rowId: id,
        current: null,
        next: OcptShootingSlotRow(
          id: id,
          shootingDayId: shootingDayId,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          label: label,
          locationId: locationId,
          setId: setId,
          anchorEdge: OcptShootingSlotAnchorEdge.start,
          anchorMinute: anchorMinute,
          notes: notes,
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);

      return id;
    });
  }

  /// Update the fields of slot [slotId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderSlot] and [deleteSlot], nor the anchor trio, which is [setSlotAnchor]'s alone — the
  /// three columns are one fact between them, and a method that let a caller write any one of them
  /// on its own would let it write a slot anchored by nothing.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateSlot({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String slotId,
    Value<String> label = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
    Value<String?> setId = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSlot")) {
      return;
    }

    final companion = OcptShootingSlotsTableCompanion(
      label: label,
      locationId: locationId,
      setId: setId,
      notes: notes,
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingSlotsTable,
      )..where((table) => table.id.equals(slotId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotsTable,
        rowId: slotId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Pin slot [slotId]'s [edge] to a typed [minute], or to the **opposite** edge of [sourceSlotId],
  /// and return whether anything was written.
  ///
  /// **Exactly one of [minute]/[sourceSlotId] must be given**: they are the two halves of one
  /// discriminator (see `OcptShootingSlotsTable`), and a call passing both, or neither, writes
  /// nothing rather than picking one. A link is refused — again writing nothing — when
  /// [sourceSlotId] is [slotId] itself, is not a **live slot of the same day**, or would close a
  /// circle of anchors (`ocptSlotAnchorWouldCycle`): the picker greys those entries out, and this
  /// is the guarantee behind that, so `ocptComputeShootingDayTimelines`' own cycle rule never has
  /// to fire on a project this app wrote.
  ///
  /// **Unlinking freezes nothing on its own.** Passing a [minute] simply writes it; the *hour that
  /// was being read* is the caller's to pass, because only the caller knows which moment the user
  /// was looking at when they picked the entry. [deleteSlot] is the one place this service works
  /// that hour out itself, having taken the slot away from under its dependents.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<bool> setSlotAnchor({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String slotId,
    required OcptShootingSlotAnchorEdge edge,
    int? minute,
    String? sourceSlotId,
  }) async {
    if (database.refusesUserWrite("setSlotAnchor")) {
      return false;
    }

    if ((minute == null) == (sourceSlotId == null)) {
      return false;
    }

    return database.transaction(() async {
      final slot = await OcptScheduleRows.getSlotRow(database: database, slotId: slotId);

      if (sourceSlotId != null) {
        if (sourceSlotId == slotId) {
          return false;
        }

        final daySlots = await OcptScheduleRows.liveSlotRows(
          database: database,
          dayId: slot.shootingDayId,
        );
        if (!daySlots.any((row) => row.id == sourceSlotId)) {
          return false;
        }

        final wouldCycle = ocptSlotAnchorWouldCycle(
          anchorSourceBySlotId: {for (final row in daySlots) row.id: row.anchorSlotId},
          slotId: slotId,
          sourceSlotId: sourceSlotId,
        );
        if (wouldCycle) {
          return false;
        }
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotsTable,
        rowId: slotId,
        current: slot,
        next: slot.copyWith(
          anchorEdge: edge,
          anchorMinute: Value(minute),
          anchorSlotId: Value(sourceSlotId),
        ),
        stamps: stamps,
      );
      await stamps.flush(database);

      return true;
    });
  }

  /// Move slot [slotId] to [newPosition] (0-based) within its own day's slots, by giving it a
  /// `sortKey` sitting between the two slots it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> reorderSlot({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String slotId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderSlot")) {
      return;
    }

    await database.transaction(() async {
      final slot = await OcptScheduleRows.getSlotRow(database: database, slotId: slotId);
      final others = (await OcptScheduleRows.liveSlotRows(
        database: database,
        dayId: slot.shootingDayId,
      ))..removeWhere((row) => row.id == slotId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      final current = await (database.select(
        database.ocptShootingSlotsTable,
      )..where((table) => table.id.equals(slotId))).getSingleOrNull();
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotsTable,
        rowId: slotId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstone slot [slotId] in [database], and its crew, cast, guest and candidate rows along
  /// with it — a guest, and a candidate seen for a part, is convoked by the slot exactly as a crew
  /// member or a role is, so they go with them.
  ///
  /// **The slot's own live blocks are moved, in their own order, to the end of the day's first
  /// other live slot** (lowest `sortKey`) — removing a convocation window must not silently unplace
  /// whatever was scheduled inside it, so its blocks simply join a different chain. **When [slotId]
  /// is the day's last live slot, there is nowhere left to move its blocks to, and they are
  /// tombstoned along with it**: a block can never be slotless (`shooting_day_blocks.slotId` is
  /// `NOT NULL` from schema v12), so a day with no slot at all can hold no timetable either — see
  /// the class doc comment.
  ///
  /// **Every slot reading this one's edge freezes the hour it was reading**, as a typed anchor on
  /// its own edge — the same rule unlinking by hand follows, so a deletion never silently moves a
  /// day. The hour is worked out here, from the day's own timelines *before* anything is
  /// tombstoned: a dependent pinned by its start was reading this slot's **end**, one pinned by its
  /// end was reading its **start**, and an empty slot's end is its own start (ADR 0015's rule 5).
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> deleteSlot({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String slotId,
  }) async {
    if (database.refusesUserWrite("deleteSlot")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final slot = await OcptScheduleRows.getSlotRow(database: database, slotId: slotId);

      await _freezeDependentsOf(database: database, slot: slot, stamps: stamps);

      final crewRows = await (database.select(
        database.ocptShootingSlotCrewTable,
      )..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())).get();
      for (final row in crewRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingSlotCrewTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final castRows = await (database.select(
        database.ocptShootingSlotCastTable,
      )..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())).get();
      for (final row in castRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingSlotCastTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final guestRows = await (database.select(
        database.ocptShootingSlotGuestsTable,
      )..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())).get();
      for (final row in guestRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingSlotGuestsTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final otherSlots = (await OcptScheduleRows.liveSlotRows(
        database: database,
        dayId: slot.shootingDayId,
      ))..removeWhere((row) => row.id == slotId);
      final blocksToMove = await OcptScheduleRows.liveBlockRowsOfSlot(
        database: database,
        slotId: slotId,
      );

      if (otherSlots.isEmpty) {
        if (blocksToMove.isNotEmpty) {
          await OcptScheduleRows.tombstoneCandidaciesOfBlocks(
            database: database,
            blockIds: blocksToMove.map((row) => row.id).toList(growable: false),
            stamps: stamps,
          );
          for (final row in blocksToMove) {
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
      } else if (blocksToMove.isNotEmpty) {
        final destinationSlot = otherSlots.first;
        final destinationBlocks = await OcptScheduleRows.liveBlockRowsOfSlot(
          database: database,
          slotId: destinationSlot.id,
        );
        final newSortKeys = ocptFractionalKeysBetween(
          count: blocksToMove.length,
          before: destinationBlocks.isEmpty ? null : destinationBlocks.last.sortKey,
        );

        for (var i = 0; i < blocksToMove.length; i++) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShootingDayBlocksTable,
            rowId: blocksToMove[i].id,
            current: blocksToMove[i],
            next: blocksToMove[i].copyWith(slotId: destinationSlot.id, sortKey: newSortKeys[i]),
            stamps: stamps,
          );
        }
      }

      final currentSlot = await (database.select(
        database.ocptShootingSlotsTable,
      )..where((table) => table.id.equals(slotId))).getSingleOrNull();
      if (currentSlot != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingSlotsTable,
          rowId: slotId,
          current: currentSlot,
          next: currentSlot.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Turn every live slot of [slot]'s own day that reads [slot]'s edge into one anchored by a
  /// **typed** hour: the very hour it was reading at the moment of the call. Called by [deleteSlot]
  /// before anything is tombstoned — see its own doc comment.
  static Future<void> _freezeDependentsOf({
    required OcptProjectDatabase database,
    required OcptShootingSlotRow slot,
    required OcptRowStampService? stamps,
  }) async {
    final daySlots = await OcptScheduleRows.liveSlotRows(
      database: database,
      dayId: slot.shootingDayId,
    );
    final dependents = [
      for (final row in daySlots)
        if (row.anchorSlotId == slot.id) row,
    ];
    if (dependents.isEmpty) {
      return;
    }

    final timelines = await OcptScheduleRows.timelinesOfDay(
      database: database,
      dayId: slot.shootingDayId,
      slots: daySlots,
    );
    final deletedTimeline = timelines.bySlotId[slot.id];
    final startMinute = deletedTimeline?.startMinute ?? 0;
    final endMinute = deletedTimeline?.endMinute ?? startMinute;

    for (final dependent in dependents) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingSlotsTable,
        rowId: dependent.id,
        current: dependent,
        next: dependent.copyWith(
          anchorMinute: Value(
            dependent.anchorEdge == OcptShootingSlotAnchorEdge.start ? endMinute : startMinute,
          ),
          anchorSlotId: const Value(null),
        ),
        stamps: stamps,
      );
    }
  }
}
