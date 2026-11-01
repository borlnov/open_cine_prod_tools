// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_rows.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_block_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timelines.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:uuid/uuid.dart';

/// The shooting days of a project's schedule: the read of the whole schedule, the days themselves
/// (create, update, delete with its cascade, duplicate) and each day's events.
///
/// What `OcptScheduleService` forwards to: that service documents the schedule's model whole and
/// owns the device id each write is stamped with, which is why each write here takes it.
abstract final class OcptScheduleDaysOps {
  /// The minute a day's first slot is given by [createDay]: 08:00.
  static const _defaultStartMinute = 480;

  /// Loads the whole shooting schedule of the project in [database]: every live day, in `sortKey`
  /// order, joined with its live slots (each carrying its own live crew, cast and guests), its live
  /// blocks (each carrying the live candidacies it sees) and its live events.
  ///
  /// Runs a bounded number of queries regardless of the schedule's size — one per table, each
  /// restricted to the days (or slots) already loaded — rather than one per day, exactly as
  /// `OcptLocationsService.loadLocations` joins locations with their sets in memory.
  static Future<OcptScheduleSnapshot> loadSchedule({required OcptProjectDatabase database}) async {
    final dayRows = await OcptScheduleRows.liveDayRows(database: database);
    final dayIds = dayRows.map((row) => row.id).toList(growable: false);

    final slotRows = dayIds.isEmpty
        ? const <OcptShootingSlotRow>[]
        : await (database.select(database.ocptShootingSlotsTable)
                ..where((table) => table.shootingDayId.isIn(dayIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();
    final slotIds = slotRows.map((row) => row.id).toList(growable: false);

    final crewRows = slotIds.isEmpty
        ? const <OcptShootingSlotCrewRow>[]
        : await (database.select(database.ocptShootingSlotCrewTable)
                ..where((table) => table.slotId.isIn(slotIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final castRows = slotIds.isEmpty
        ? const <OcptShootingSlotCastRow>[]
        : await (database.select(database.ocptShootingSlotCastTable)
                ..where((table) => table.slotId.isIn(slotIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final guestRows = slotIds.isEmpty
        ? const <OcptShootingSlotGuestRow>[]
        : await (database.select(database.ocptShootingSlotGuestsTable)
                ..where((table) => table.slotId.isIn(slotIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final blockRows = dayIds.isEmpty
        ? const <OcptShootingDayBlockRow>[]
        : await (database.select(database.ocptShootingDayBlocksTable)
                ..where((table) => table.shootingDayId.isIn(dayIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();
    final blockIds = blockRows.map((row) => row.id).toList(growable: false);

    final candidateRows = blockIds.isEmpty
        ? const <OcptShootingBlockCandidateRow>[]
        : await (database.select(database.ocptShootingBlockCandidatesTable)
                ..where((table) => table.blockId.isIn(blockIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final eventRows = dayIds.isEmpty
        ? const <OcptShootingDayEventRow>[]
        : await (database.select(database.ocptShootingDayEventsTable)
                ..where((table) => table.shootingDayId.isIn(dayIds) & table.isDeleted.not())
                ..orderBy([
                  (table) => OrderingTerm.asc(table.minute),
                  (table) => OrderingTerm.asc(table.sortKey),
                ]))
              .get();

    final crewBySlotId = <String, List<OcptShootingSlotCrewMember>>{};
    for (final row in crewRows) {
      crewBySlotId.putIfAbsent(row.slotId, () => []).add(OcptShootingSlotCrewMember.fromRow(row));
    }

    final castBySlotId = <String, List<OcptShootingSlotCastMember>>{};
    for (final row in castRows) {
      castBySlotId.putIfAbsent(row.slotId, () => []).add(OcptShootingSlotCastMember.fromRow(row));
    }

    final guestsBySlotId = <String, List<OcptShootingSlotGuest>>{};
    for (final row in guestRows) {
      guestsBySlotId.putIfAbsent(row.slotId, () => []).add(OcptShootingSlotGuest.fromRow(row));
    }

    final candidatesByBlockId = <String, List<OcptShootingBlockCandidate>>{};
    for (final row in candidateRows) {
      candidatesByBlockId
          .putIfAbsent(row.blockId, () => [])
          .add(OcptShootingBlockCandidate.fromRow(row));
    }

    final slotsByDayId = <String, List<OcptShootingSlot>>{};
    for (final row in slotRows) {
      slotsByDayId
          .putIfAbsent(row.shootingDayId, () => [])
          .add(
            OcptShootingSlot.fromRow(
              row: row,
              crew: crewBySlotId[row.id] ?? const [],
              cast: castBySlotId[row.id] ?? const [],
              guests: guestsBySlotId[row.id] ?? const [],
            ),
          );
    }

    final blocksByDayId = <String, List<OcptShootingDayBlock>>{};
    for (final row in blockRows) {
      blocksByDayId
          .putIfAbsent(row.shootingDayId, () => [])
          .add(
            OcptShootingDayBlock.fromRow(
              row: row,
              candidates: candidatesByBlockId[row.id] ?? const [],
            ),
          );
    }

    final eventsByDayId = <String, List<OcptShootingDayEvent>>{};
    for (final row in eventRows) {
      eventsByDayId.putIfAbsent(row.shootingDayId, () => []).add(OcptShootingDayEvent.fromRow(row));
    }

    final days = [
      for (var i = 0; i < dayRows.length; i++)
        OcptShootingDay.fromRow(row: dayRows[i], dayNumber: i + 1),
    ];

    return OcptScheduleSnapshot.build(
      days: days,
      slotsByDayId: slotsByDayId,
      blocksByDayId: blocksByDayId,
      eventsByDayId: eventsByDayId,
    );
  }

  /// For every shot of the project placed in the schedule, every block that places it — which
  /// day it sits on and that day's rank and date — keyed by shot id, each list ordered by
  /// `dayNumber` ascending, which is chronological order (days are ranked by date, then by
  /// `sortKey` between two sharing one), and, within a day, in the order the query itself returns,
  /// no secondary sort invented on top of it.
  ///
  /// A shot with no live block has **no entry** in the returned map, rather than an empty list: the
  /// shot list's `Jour de tournage` read-out reads absence as "not yet planned" rather than looking
  /// for a placement with null fields. A shot placed twice — on the same day either side of the
  /// meal break, or on two different days — carries two entries in its own list.
  static Future<Map<String, List<OcptShotPlacement>>> loadShotPlacements({
    required OcptProjectDatabase database,
  }) async {
    final dayRows = await OcptScheduleRows.liveDayRows(database: database);
    if (dayRows.isEmpty) {
      return const {};
    }

    final dayNumberById = <String, int>{};
    final dateById = <String, DateTime>{};
    for (var i = 0; i < dayRows.length; i++) {
      dayNumberById[dayRows[i].id] = i + 1;
      dateById[dayRows[i].id] = dayRows[i].date;
    }

    final dayIds = dayRows.map((row) => row.id).toList(growable: false);
    final blockRows =
        await (database.select(database.ocptShootingDayBlocksTable)..where(
              (table) =>
                  table.shootingDayId.isIn(dayIds) &
                  table.kind.equalsValue(OcptShootingBlockKind.shot) &
                  table.isDeleted.not(),
            ))
            .get();

    // Grouped by walking the days in their own ascending order and, for each, the blocks the query
    // returned for it in the order it returned them — a day-by-day partition rather than a sort, so
    // stability within a day is never in question.
    final blocksByDayId = <String, List<OcptShootingDayBlockRow>>{};
    for (final row in blockRows) {
      blocksByDayId.putIfAbsent(row.shootingDayId, () => []).add(row);
    }

    final placementsByShotId = <String, List<OcptShotPlacement>>{};
    for (final day in dayRows) {
      for (final row in blocksByDayId[day.id] ?? const <OcptShootingDayBlockRow>[]) {
        final shotId = row.shotId;
        if (shotId == null) {
          continue;
        }

        placementsByShotId
            .putIfAbsent(shotId, () => [])
            .add(
              OcptShotPlacement(
                shotId: shotId,
                dayId: row.shootingDayId,
                dayNumber: dayNumberById[row.shootingDayId]!,
                date: dateById[row.shootingDayId]!,
              ),
            );
      }
    }

    return placementsByShotId;
  }

  /// Creates a new shooting day of the project dated [date], appended at the end, and returns its
  /// freshly generated id.
  ///
  /// **Mints one slot with it.** A day has at least one convocation window — see
  /// `OcptShootingSlotsTable`'s own doc comment — and a day with none could hold no crew, no cast
  /// and no chain start for its timetable. That first slot gets an empty [OcptShootingSlot.label]
  /// and the default start [_defaultStartMinute] (08:00).
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> createDay({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required DateTime date,
  }) async {
    if (database.refusesUserWrite("createDay")) {
      return null;
    }

    return database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final existing = await OcptScheduleRows.liveDayRows(database: database);
      final dayId = const Uuid().v4();

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDaysTable,
        rowId: dayId,
        current: null,
        next: OcptShootingDayRow(
          id: dayId,
          date: date,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          status: OcptShootingDayStatus.planned,
          crewNote: '',
          weatherNote: '',
          notes: '',
          isDeleted: false,
        ),
        stamps: stamps,
      );

      await _insertDefaultSlot(database: database, dayId: dayId, stamps: stamps);

      await stamps.flush(database);

      return dayId;
    });
  }

  /// Updates the fields of day [dayId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: `sortKey` is only allocated once, at
  /// insertion (breaking a tie between two days sharing one [date] — the order of the days
  /// themselves is [date]'s own, not a stored fact anybody can move), and `isDeleted` only through
  /// [deleteDay].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateDay({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String dayId,
    Value<DateTime> date = const Value.absent(),
    Value<OcptShootingDayStatus> status = const Value.absent(),
    Value<String> crewNote = const Value.absent(),
    Value<String> weatherNote = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateDay")) {
      return;
    }

    final companion = OcptShootingDaysTableCompanion(
      date: date,
      status: status,
      crewNote: crewNote,
      weatherNote: weatherNote,
      notes: notes,
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingDaysTable,
      )..where((table) => table.id.equals(dayId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDaysTable,
        rowId: dayId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones day [dayId] in [database], and along with it: its slots, their crew, cast, guest
  /// and candidate rows, its blocks, and its own events — everything hanging off it, in one
  /// transaction, exactly as `OcptLocationsService.deleteLocation` tombstones a location's sets and
  /// their links.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> deleteDay({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String dayId,
  }) async {
    if (database.refusesUserWrite("deleteDay")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final slotRows = await OcptScheduleRows.liveSlotRows(database: database, dayId: dayId);
      final slotIds = slotRows.map((row) => row.id).toList(growable: false);

      if (slotIds.isNotEmpty) {
        final crewRows = await (database.select(
          database.ocptShootingSlotCrewTable,
        )..where((table) => table.slotId.isIn(slotIds) & table.isDeleted.not())).get();
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
        )..where((table) => table.slotId.isIn(slotIds) & table.isDeleted.not())).get();
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
        )..where((table) => table.slotId.isIn(slotIds) & table.isDeleted.not())).get();
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

        for (final row in slotRows) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShootingSlotsTable,
            rowId: row.id,
            current: row,
            next: row.copyWith(isDeleted: true),
            stamps: stamps,
          );
        }
      }

      final blockRows = await OcptScheduleRows.liveBlockRowsOfDay(database: database, dayId: dayId);
      await OcptScheduleRows.tombstoneCandidaciesOfBlocks(
        database: database,
        blockIds: blockRows.map((row) => row.id).toList(growable: false),
        stamps: stamps,
      );

      for (final row in blockRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingDayBlocksTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final eventRows = await OcptScheduleRows.liveEventRowsOfDay(database: database, dayId: dayId);
      for (final row in eventRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingDayEventsTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final currentDay = await (database.select(
        database.ocptShootingDaysTable,
      )..where((table) => table.id.equals(dayId))).getSingleOrNull();
      if (currentDay != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingDaysTable,
          rowId: dayId,
          current: currentDay,
          next: currentDay.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Creates a new day dated [date], appended at the end of the project's days, carrying copies of
  /// [sourceDayId]'s live slots, their live crew, their live cast and their live guests — fresh
  /// ids, fresh `sortKey`s, everything else copied verbatim. Returns the new day's id.
  ///
  /// **Copies neither the timetable, the crew note, nor the source day's events** — which is also
  /// why it copies no audition and no candidate: somebody seen for a part is linked to the
  /// **block** that sees them (ADR 0024), and a day duplicated without its blocks has no hour to
  /// convoke them at. See the class doc comment for why, and
  /// for the two further fields (`weatherNote`, `notes`) this service also leaves at their defaults
  /// on the new day, a choice made here. If [sourceDayId] currently holds no live slot
  /// at all (every one of them since deleted), the new day is given the same default slot
  /// [createDay] would give a brand new one, so the invariant "a day has at least one slot" still
  /// holds for a day built by this method too.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> duplicateDay({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String sourceDayId,
    required DateTime date,
  }) async {
    if (database.refusesUserWrite("duplicateDay")) {
      return null;
    }

    return database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      // Read back for validation alone from here on — throws if `sourceDayId` doesn't exist or has
      // been tombstoned — since a day no longer names a screenplay for this method to carry over.
      await OcptScheduleRows.getDayRow(database: database, dayId: sourceDayId);
      final existingDays = await OcptScheduleRows.liveDayRows(database: database);
      final newDayId = const Uuid().v4();

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDaysTable,
        rowId: newDayId,
        current: null,
        next: OcptShootingDayRow(
          id: newDayId,
          date: date,
          sortKey: ocptFractionalKeyBetween(
            before: existingDays.isEmpty ? null : existingDays.last.sortKey,
          ),
          status: OcptShootingDayStatus.planned,
          crewNote: '',
          weatherNote: '',
          notes: '',
          isDeleted: false,
        ),
        stamps: stamps,
      );

      final sourceSlots = await OcptScheduleRows.liveSlotRows(
        database: database,
        dayId: sourceDayId,
      );

      if (sourceSlots.isEmpty) {
        await _insertDefaultSlot(database: database, dayId: newDayId, stamps: stamps);
        await stamps.flush(database);
        return newDayId;
      }

      final newSlotIds = [for (var i = 0; i < sourceSlots.length; i++) const Uuid().v4()];
      final slotSortKeys = ocptFractionalKeySequence(sourceSlots.length);
      final newSlotIdBySourceId = {
        for (var i = 0; i < sourceSlots.length; i++) sourceSlots[i].id: newSlotIds[i],
      };

      // Read once, and only when some source anchor names a slot that isn't being copied — see
      // [_frozenAnchorMinuteOf] for why that branch exists at all.
      OcptShootingDayTimelines? sourceTimelines;

      for (var i = 0; i < sourceSlots.length; i++) {
        final sourceSlot = sourceSlots[i];

        // The copy links to the copy: a slot pointing back at the original day's would be a
        // cross-day link, which nothing in this app allows.
        final copiedAnchorSlotId = sourceSlot.anchorSlotId == null
            ? null
            : newSlotIdBySourceId[sourceSlot.anchorSlotId];
        var anchorMinute = sourceSlot.anchorMinute;
        if (sourceSlot.anchorSlotId != null && copiedAnchorSlotId == null) {
          sourceTimelines ??= await OcptScheduleRows.timelinesOfDay(
            database: database,
            dayId: sourceDayId,
            slots: sourceSlots,
          );
          anchorMinute = _frozenAnchorMinuteOf(sourceSlot, sourceTimelines);
        }

        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingSlotsTable,
          rowId: newSlotIds[i],
          current: null,
          next: OcptShootingSlotRow(
            id: newSlotIds[i],
            shootingDayId: newDayId,
            sortKey: slotSortKeys[i],
            label: sourceSlot.label,
            locationId: sourceSlot.locationId,
            setId: sourceSlot.setId,
            anchorEdge: sourceSlot.anchorEdge,
            anchorMinute: anchorMinute,
            anchorSlotId: copiedAnchorSlotId,
            notes: sourceSlot.notes,
            isDeleted: false,
          ),
          stamps: stamps,
        );

        final sourceCrew = await OcptScheduleRows.liveCrewRowsOfSlot(
          database: database,
          slotId: sourceSlot.id,
        );
        final crewSortKeys = ocptFractionalKeySequence(sourceCrew.length);
        for (var j = 0; j < sourceCrew.length; j++) {
          final crewMember = sourceCrew[j];
          final newCrewId = const Uuid().v4();
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShootingSlotCrewTable,
            rowId: newCrewId,
            current: null,
            next: OcptShootingSlotCrewRow(
              id: newCrewId,
              slotId: newSlotIds[i],
              sortKey: crewSortKeys[j],
              personId: crewMember.personId,
              positionId: crewMember.positionId,
              customLabel: crewMember.customLabel,
              notes: crewMember.notes,
              isDeleted: false,
            ),
            stamps: stamps,
          );
        }

        final sourceCast = await OcptScheduleRows.liveCastRowsOfSlot(
          database: database,
          slotId: sourceSlot.id,
        );
        final castSortKeys = ocptFractionalKeySequence(sourceCast.length);
        for (var j = 0; j < sourceCast.length; j++) {
          final castMember = sourceCast[j];
          final newCastId = const Uuid().v4();
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShootingSlotCastTable,
            rowId: newCastId,
            current: null,
            next: OcptShootingSlotCastRow(
              id: newCastId,
              slotId: newSlotIds[i],
              roleId: castMember.roleId,
              sortKey: castSortKeys[j],
              notes: castMember.notes,
              isDeleted: false,
            ),
            stamps: stamps,
          );
        }

        final sourceGuests = await OcptScheduleRows.liveGuestRowsOfSlot(
          database: database,
          slotId: sourceSlot.id,
        );
        final guestSortKeys = ocptFractionalKeySequence(sourceGuests.length);
        for (var j = 0; j < sourceGuests.length; j++) {
          final guest = sourceGuests[j];
          final newGuestId = const Uuid().v4();
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShootingSlotGuestsTable,
            rowId: newGuestId,
            current: null,
            next: OcptShootingSlotGuestRow(
              id: newGuestId,
              slotId: newSlotIds[i],
              personId: guest.personId,
              freeName: guest.freeName,
              reason: guest.reason,
              notes: guest.notes,
              sortKey: guestSortKeys[j],
              isDeleted: false,
            ),
            stamps: stamps,
          );
        }
      }

      await stamps.flush(database);

      return newDayId;
    });
  }

  /// Creates a new event on day [dayId], appended at the end of its current events, and returns its
  /// freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> createDayEvent({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String dayId,
    required int minute,
    String label = "",
    String notes = "",
  }) async {
    if (database.refusesUserWrite("createDayEvent")) {
      return null;
    }

    return database.transaction(() async {
      final existing = await OcptScheduleRows.liveEventRowsOfDay(database: database, dayId: dayId);
      final id = const Uuid().v4();

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDayEventsTable,
        rowId: id,
        current: null,
        next: OcptShootingDayEventRow(
          id: id,
          shootingDayId: dayId,
          minute: minute,
          label: label,
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

  /// Updates the fields of event [eventId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [deleteDayEvent] — there is no reorder method, an event's order being its own [minute].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateDayEvent({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String eventId,
    Value<int> minute = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateDayEvent")) {
      return;
    }

    final companion = OcptShootingDayEventsTableCompanion(
      minute: minute,
      label: label,
      notes: notes,
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingDayEventsTable,
      )..where((table) => table.id.equals(eventId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDayEventsTable,
        rowId: eventId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones event [eventId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> deleteDayEvent({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String eventId,
  }) async {
    if (database.refusesUserWrite("deleteDayEvent")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptShootingDayEventsTable,
      )..where((table) => table.id.equals(eventId))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptShootingDayEventsTable,
        rowId: eventId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Inserts the default first slot a brand new day is never without: an empty label, anchored by
  /// its start at [_defaultStartMinute]. Shared by [createDay] and [duplicateDay]'s empty-source
  /// fallback.
  static Future<void> _insertDefaultSlot({
    required OcptProjectDatabase database,
    required String dayId,
    required OcptRowStampService? stamps,
  }) {
    final id = const Uuid().v4();
    return OcptRowStampService.writeAndStamp(
      database: database,
      table: database.ocptShootingSlotsTable,
      rowId: id,
      current: null,
      next: OcptShootingSlotRow(
        id: id,
        shootingDayId: dayId,
        sortKey: ocptFractionalKeyBetween(),
        label: '',
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorMinute: _defaultStartMinute,
        notes: '',
        isDeleted: false,
      ),
      stamps: stamps,
    );
  }

  /// The hour [slot]'s own anchored edge was reading in [timelines] — what a link that cannot be
  /// carried across freezes into a typed anchor, so the copy still says the same thing about time
  /// as the slot it was copied from.
  ///
  /// Reached only from [duplicateDay], and only for a source slot whose `anchorSlotId` names no
  /// live slot of its own day. Nothing this app writes leaves one like that — `deleteSlot` freezes
  /// the dependents of the slot it takes away — but a restored payload or a hand-edited file can,
  /// and the alternative would be a copy anchored by neither a slot nor an hour.
  static int _frozenAnchorMinuteOf(OcptShootingSlotRow slot, OcptShootingDayTimelines timelines) {
    final timeline = timelines.bySlotId[slot.id];
    return slot.anchorEdge == OcptShootingSlotAnchorEdge.start
        ? (timeline?.startMinute ?? 0)
        : (timeline?.endMinute ?? timeline?.startMinute ?? 0);
  }
}
