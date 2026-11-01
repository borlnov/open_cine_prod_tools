// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timelines.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_block.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// The reads every schedule operation shares: a row fetched by id or a live collection under its
/// parent, in the order the schedule reads it, and the two derived reads two of them need (a day's
/// computed timelines, a block's candidacies tombstoned with it).
///
/// Stateless, so a call takes the database it reads from, the same shape every service's own
/// private query helpers have.
abstract final class OcptScheduleRows {
  /// Read back the day row [dayId], throwing if it doesn't exist or have been tombstoned.
  static Future<OcptShootingDayRow> getDayRow({
    required OcptProjectDatabase database,
    required String dayId,
  }) => (database.select(
    database.ocptShootingDaysTable,
  )..where((table) => table.id.equals(dayId) & table.isDeleted.not())).getSingle();

  /// Read back the slot row [slotId], throwing if it doesn't exist or have been tombstoned.
  static Future<OcptShootingSlotRow> getSlotRow({
    required OcptProjectDatabase database,
    required String slotId,
  }) => (database.select(
    database.ocptShootingSlotsTable,
  )..where((table) => table.id.equals(slotId) & table.isDeleted.not())).getSingle();

  /// Read back the block row [blockId], throwing if it doesn't exist or have been tombstoned.
  static Future<OcptShootingDayBlockRow> getBlockRow({
    required OcptProjectDatabase database,
    required String blockId,
  }) => (database.select(
    database.ocptShootingDayBlocksTable,
  )..where((table) => table.id.equals(blockId) & table.isDeleted.not())).getSingle();

  /// Get every live day row of the **project** — a shooting day belongs to no one episode
  /// (`docs/adr/0019-one-project-several-episodes.md`), the schedule being shared across every
  /// screenplay it holds — ordered by `date` ascending then `sortKey` ascending: chronologically,
  /// `sortKey` breaking the tie between two days sharing one date (a second unit), the order
  /// [OcptShootingDay.dayNumber] is a read-time rank over.
  static Future<List<OcptShootingDayRow>> liveDayRows({required OcptProjectDatabase database}) =>
      (database.select(database.ocptShootingDaysTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([
              (table) => OrderingTerm.asc(table.date),
              (table) => OrderingTerm.asc(table.sortKey),
            ]))
          .get();

  /// Get every live slot row of day [dayId], ordered by `sortKey`.
  static Future<List<OcptShootingSlotRow>> liveSlotRows({
    required OcptProjectDatabase database,
    required String dayId,
  }) =>
      (database.select(database.ocptShootingSlotsTable)
            ..where((table) => table.shootingDayId.equals(dayId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live `person_positions` row of [personId], ordered by `sortKey` — what
  /// `addSlotCrewMember` reads to pre-fill a fresh crew row's position, written exactly as
  /// `OcptPeopleService._positionRowsOfPerson` is.
  static Future<List<OcptPersonPositionRow>> livePositionRowsOfPerson({
    required OcptProjectDatabase database,
    required String personId,
  }) =>
      (database.select(database.ocptPersonPositionsTable)
            ..where((table) => table.personId.equals(personId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live crew row of slot [slotId], ordered by `sortKey`.
  static Future<List<OcptShootingSlotCrewRow>> liveCrewRowsOfSlot({
    required OcptProjectDatabase database,
    required String slotId,
  }) =>
      (database.select(database.ocptShootingSlotCrewTable)
            ..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live cast row of slot [slotId], ordered by `sortKey`.
  static Future<List<OcptShootingSlotCastRow>> liveCastRowsOfSlot({
    required OcptProjectDatabase database,
    required String slotId,
  }) =>
      (database.select(database.ocptShootingSlotCastTable)
            ..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live block row of slot [slotId], ordered by `sortKey` — that slot's own timetable
  /// order.
  static Future<List<OcptShootingDayBlockRow>> liveBlockRowsOfSlot({
    required OcptProjectDatabase database,
    required String slotId,
  }) =>
      (database.select(database.ocptShootingDayBlocksTable)
            ..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live guest row of slot [slotId], ordered by `sortKey`.
  static Future<List<OcptShootingSlotGuestRow>> liveGuestRowsOfSlot({
    required OcptProjectDatabase database,
    required String slotId,
  }) =>
      (database.select(database.ocptShootingSlotGuestsTable)
            ..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live candidate row of block [blockId], ordered by `sortKey`.
  static Future<List<OcptShootingBlockCandidateRow>> liveCandidateRowsOfBlock({
    required OcptProjectDatabase database,
    required String blockId,
  }) =>
      (database.select(database.ocptShootingBlockCandidatesTable)
            ..where((table) => table.blockId.equals(blockId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live block row of day [dayId], ordered by `sortKey` — the whole day's timetable,
  /// across
  /// its slots, which is what a day-wide cascade has to reach.
  static Future<List<OcptShootingDayBlockRow>> liveBlockRowsOfDay({
    required OcptProjectDatabase database,
    required String dayId,
  }) =>
      (database.select(database.ocptShootingDayBlocksTable)
            ..where((table) => table.shootingDayId.equals(dayId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live event row of day [dayId], ordered by `sortKey` — the tiebreak `loadSchedule`
  /// falls
  /// back on once two events share a `minute`.
  static Future<List<OcptShootingDayEventRow>> liveEventRowsOfDay({
    required OcptProjectDatabase database,
    required String dayId,
  }) =>
      (database.select(database.ocptShootingDayEventsTable)
            ..where((table) => table.shootingDayId.equals(dayId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get day [dayId]'s own computed timelines, one chain per live slot (ADR 0015, amended twice),
  /// read
  /// straight out of [database].
  ///
  /// This service computes them for one reason only: `deleteSlot` has to know the hour a dependent
  /// was reading before it takes that hour's slot away. Nothing else here reads a clock — the mode
  /// computes its own from the snapshot it already holds — so this stays private, and it uses the
  /// same `ocptDefaultBlockDurationMinutes` every other reader does, that constant living beside
  /// the rule rather than on one caller.
  static Future<OcptShootingDayTimelines> timelinesOfDay({
    required OcptProjectDatabase database,
    required String dayId,
    List<OcptShootingSlotRow>? slots,
  }) async {
    final slotRows = slots ?? await OcptScheduleRows.liveSlotRows(database: database, dayId: dayId);
    final blockRows =
        await (database.select(database.ocptShootingDayBlocksTable)
              ..where((table) => table.shootingDayId.equals(dayId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();

    final shotIds = {
      for (final row in blockRows)
        if (row.kind == OcptShootingBlockKind.shot && row.shotId != null) row.shotId!,
    };
    final shotRows = shotIds.isEmpty
        ? const <OcptShotRow>[]
        : await (database.select(
            database.ocptShotsTable,
          )..where((table) => table.id.isIn(shotIds))).get();
    final estimateByShotId = {
      for (final row in shotRows)
        if (row.estimatedDurationMs != null) row.id: (row.estimatedDurationMs! / 60000).round(),
    };

    final blocksBySlotId = <String, List<OcptShootingDayBlockRow>>{};
    for (final row in blockRows) {
      blocksBySlotId.putIfAbsent(row.slotId, () => []).add(row);
    }

    return ocptComputeShootingDayTimelines(
      slots: [
        for (final row in slotRows)
          OcptShootingTimelineSlot(
            id: row.id,
            anchorEdge: row.anchorEdge,
            anchorMinute: row.anchorMinute,
            anchorSlotId: row.anchorSlotId,
            blocks: [
              for (final block in blocksBySlotId[row.id] ?? const <OcptShootingDayBlockRow>[])
                OcptShootingTimelineBlock(
                  id: block.id,
                  durationMinutes: block.durationMinutes,
                  fallbackDurationMinutes: block.shotId == null
                      ? null
                      : estimateByShotId[block.shotId],
                  anchorMinute: block.anchorMinute,
                ),
            ],
          ),
      ],
      defaultDurationMinutes: ocptDefaultBlockDurationMinutes,
    );
  }

  /// Tombstone every `shooting_block_candidates` row hanging off [blockIds], and do nothing at
  /// all when that list is empty.
  ///
  /// The cascade a block's own deletion owes its candidacies, written once because three callers
  /// need it — `deleteBlock`, `deleteSlot` (when the slot it empties is the day's last) and
  /// `deleteDay`. A convocation whose audition is gone convokes nobody, and leaving the rows live
  /// would let a candidate keep an hour on a day whose timetable no longer holds it.
  static Future<void> tombstoneCandidaciesOfBlocks({
    required OcptProjectDatabase database,
    required List<String> blockIds,
    required OcptRowStampService? stamps,
  }) async {
    if (blockIds.isEmpty) {
      return;
    }

    final rows = await (database.select(
      database.ocptShootingBlockCandidatesTable,
    )..where((table) => table.blockId.isIn(blockIds) & table.isDeleted.not())).get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingBlockCandidatesTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }
}
