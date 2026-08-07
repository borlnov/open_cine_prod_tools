// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over a screenplay's shooting schedule: its days, the convocation windows inside each day
/// (`shooting_slots`), who is convoked in each (`shooting_slot_crew`/`shooting_slot_cast`), and each
/// **slot's own** timetable (`shooting_day_blocks`) — placing a shot, reserving a `hold`, and the
/// milestones (preparation, hair/make-up, a meal, a travel move, the wrap) interleaved between them.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — these six tables have no `position` column at all,
/// schema v11 having been declared after `sortKey` already existed, so there is no legacy column
/// to leave alone.
///
/// **A day's printed number (`J3`) is a read-time rank, never a column.** [loadSchedule] counts it
/// off the same way `OcptShotListService` counts a shot's `OcptShot.position`: the 1-based index of
/// a live day among its screenplay's days, ordered by `sortKey`.
///
/// **A day is a set of parallel chains, one per slot, rather than one timetable.** A block belongs
/// to exactly one slot ([createBlock]/[placeShot] both take a required slot id and read the day off
/// it, so a block can never name a day its slot doesn't belong to) and chains from that slot's own
/// `startMinute` — see `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015, amended).
///
/// **A convocation is the slot you are linked to, and nothing about it is typed** — see
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0018). [addSlotCrewMember]/[addSlotCastRole] do
/// nothing more than create the link: a person's or a role's arrival, readiness band and departure
/// are read off every live slot they are linked to across the whole day, joined together, never
/// stored on the row itself and never typed beside it. A production that wants somebody there
/// earlier — a make-up call, a rigging call — creates the slot that says so, with its own label and
/// its own blocks, and links them to it; this service exposes no way to offset a convocation from
/// its slot instead.
///
/// **A shot may be placed as many times as the plan needs.** [placeShot] only ever creates: a shot
/// interrupted by the meal break and resumed after it is two blocks on the same day, not one, and a
/// shot picked up again on a later date is two blocks on two different days. A placement is *moved*
/// with [moveBlockToSlot] or the reorder, exactly like any other block, and *removed* with
/// [deleteBlock], exactly like any other block — there is no operation keyed by shot any more. This
/// costs the shot list's `Jour de tournage` read-out its single answer, which is why
/// [loadShotPlacements] returns a **list** per shot rather than one placement.
///
/// **Deleting a day cascades; deleting a slot moves what was scheduled inside it, or drops it with
/// the slot when there is nowhere left to move it to.** [deleteDay] tombstones everything hanging
/// off it — its slots, their crew and cast, and its blocks — in one transaction, the way
/// `OcptLocationsService.deleteLocation` tombstones a location's sets. [deleteSlot] is narrower: it
/// tombstones the slot's own crew and cast, then moves the slot's own live blocks, in their own
/// order, to the end of the day's first *other* live slot (lowest `sortKey`) — removing a
/// convocation window must not silently unplace whatever was scheduled inside it, so its blocks
/// simply join a different chain. When the slot being deleted is the day's **last** live one, there
/// is nowhere left for its blocks to go, and they are tombstoned along with it — a decision taken
/// deliberately: a block can
/// never be slotless (`shooting_day_blocks.slotId` is `NOT NULL` from schema v12), so a day with no
/// slot at all can hold no timetable either.
///
/// **Duplicating a day copies the shape of the crew, not the day's own work.** [duplicateDay] copies
/// the source day's slots, their crew and their cast — but copies **neither the placed shots nor the
/// crew note**, and (a decision this service makes on its own) starts the new day's
/// own `status`, `weatherNote` and `notes` at their column defaults too: a stable crew is entered
/// once for a whole shoot and reused day after day, while what got shot, what the weather did and
/// why a day was lost are all facts of the specific day being duplicated *away* from, not of the one
/// being planned.
///
/// **`shooting_presences` is out of scope here.** It is declared in schema v11 alongside these
/// tables (one migration for the whole mode, even though the presence grid it backs is milestone
/// M3's), but this service exposes nothing for it: there is nothing to override yet, since nothing
/// computes the grid it would override a cell of.
class OcptScheduleService {
  /// The minute a day's first slot is given by [createDay]: 08:00.
  static const _defaultStartMinute = 480;

  /// Class constructor
  const OcptScheduleService();

  /// Loads the whole shooting schedule of [screenplayId] in [database]: every live day, in
  /// `sortKey` order, joined with its live slots (each carrying its own live crew and cast) and its
  /// live blocks.
  ///
  /// Runs a bounded number of queries regardless of the schedule's size — one per table, each
  /// restricted to the days (or slots) already loaded — rather than one per day, exactly as
  /// `OcptLocationsService.loadLocations` joins locations with their sets in memory.
  Future<OcptScheduleSnapshot> loadSchedule({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final dayRows = await _liveDayRows(database: database, screenplayId: screenplayId);
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

    final blockRows = dayIds.isEmpty
        ? const <OcptShootingDayBlockRow>[]
        : await (database.select(database.ocptShootingDayBlocksTable)
                ..where((table) => table.shootingDayId.isIn(dayIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final crewBySlotId = <String, List<OcptShootingSlotCrewMember>>{};
    for (final row in crewRows) {
      crewBySlotId
          .putIfAbsent(row.slotId, () => [])
          .add(OcptShootingSlotCrewMember.fromRow(row));
    }

    final castBySlotId = <String, List<OcptShootingSlotCastMember>>{};
    for (final row in castRows) {
      castBySlotId
          .putIfAbsent(row.slotId, () => [])
          .add(OcptShootingSlotCastMember.fromRow(row));
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
            ),
          );
    }

    final blocksByDayId = <String, List<OcptShootingDayBlock>>{};
    for (final row in blockRows) {
      blocksByDayId
          .putIfAbsent(row.shootingDayId, () => [])
          .add(OcptShootingDayBlock.fromRow(row));
    }

    final days = [
      for (var i = 0; i < dayRows.length; i++)
        OcptShootingDay.fromRow(row: dayRows[i], dayNumber: i + 1),
    ];

    return OcptScheduleSnapshot.build(
      screenplayId: screenplayId,
      days: days,
      slotsByDayId: slotsByDayId,
      blocksByDayId: blocksByDayId,
    );
  }

  /// For every shot of [screenplayId] placed in the schedule, every block that places it — which
  /// day it sits on and that day's rank and date — keyed by shot id, each list ordered by
  /// `dayNumber` ascending, which is chronological order (days are ranked by date, then by
  /// `sortKey` between two sharing one), and, within a day, in the order the query itself returns,
  /// no secondary sort invented on top of it.
  ///
  /// A shot with no live block has **no entry** in the returned map, rather than an empty list: the
  /// shot list's `Jour de tournage` read-out reads absence as "not yet planned" rather than looking
  /// for a placement with null fields. A shot placed twice — on the same day either side of the meal
  /// break, or on two different days — carries two entries in its own list.
  Future<Map<String, List<OcptShotPlacement>>> loadShotPlacements({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final dayRows = await _liveDayRows(database: database, screenplayId: screenplayId);
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

  /// Creates a new shooting day of screenplay [screenplayId] dated [date], appended at the end, and
  /// returns its freshly generated id.
  ///
  /// **Mints one slot with it.** A day has at least one convocation window — see
  /// `OcptShootingSlotsTable`'s own doc comment — and a day with none could hold no crew, no cast
  /// and no chain start for its timetable. That first slot gets an empty [OcptShootingSlot.label]
  /// and the default start [_defaultStartMinute] (08:00).
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createDay({
    required OcptProjectDatabase database,
    required String screenplayId,
    required DateTime date,
  }) async {
    if (database.refusesUserWrite("createDay")) {
      return null;
    }

    return database.transaction(() async {
      final existing = await _liveDayRows(database: database, screenplayId: screenplayId);
      final dayId = const Uuid().v4();

      await database
          .into(database.ocptShootingDaysTable)
          .insert(
            OcptShootingDaysTableCompanion.insert(
              id: dayId,
              screenplayId: screenplayId,
              date: date,
              sortKey: Value(
                ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
              ),
            ),
          );

      await _insertDefaultSlot(database: database, dayId: dayId);

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
  Future<void> updateDay({
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

    await (database.update(
      database.ocptShootingDaysTable,
    )..where((table) => table.id.equals(dayId) & table.isDeleted.not())).write(
      OcptShootingDaysTableCompanion(
        date: date,
        status: status,
        crewNote: crewNote,
        weatherNote: weatherNote,
        notes: notes,
      ),
    );
  }

  /// Tombstones day [dayId] in [database], and along with it: its slots, their crew and cast rows,
  /// and its blocks — everything hanging off it, in one transaction, exactly as
  /// `OcptLocationsService.deleteLocation` tombstones a location's sets and their links.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteDay({required OcptProjectDatabase database, required String dayId}) async {
    if (database.refusesUserWrite("deleteDay")) {
      return;
    }

    await database.transaction(() async {
      final slotIds = (await _liveSlotRows(
        database: database,
        dayId: dayId,
      )).map((row) => row.id).toList(growable: false);

      if (slotIds.isNotEmpty) {
        await (database.update(
          database.ocptShootingSlotCrewTable,
        )..where((table) => table.slotId.isIn(slotIds))).write(
          const OcptShootingSlotCrewTableCompanion(isDeleted: Value(true)),
        );
        await (database.update(
          database.ocptShootingSlotCastTable,
        )..where((table) => table.slotId.isIn(slotIds))).write(
          const OcptShootingSlotCastTableCompanion(isDeleted: Value(true)),
        );
        await (database.update(
          database.ocptShootingSlotsTable,
        )..where((table) => table.shootingDayId.equals(dayId))).write(
          const OcptShootingSlotsTableCompanion(isDeleted: Value(true)),
        );
      }

      await (database.update(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.shootingDayId.equals(dayId))).write(
        const OcptShootingDayBlocksTableCompanion(isDeleted: Value(true)),
      );

      await (database.update(
        database.ocptShootingDaysTable,
      )..where((table) => table.id.equals(dayId))).write(
        const OcptShootingDaysTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// Creates a new day dated [date], appended at the end of [sourceDayId]'s screenplay, carrying
  /// copies of [sourceDayId]'s live slots, their live crew and their live cast — fresh ids, fresh
  /// `sortKey`s, everything else copied verbatim. Returns the new day's id.
  ///
  /// **Copies neither the placed shots nor the crew note** — see the class doc comment for why, and
  /// for the two further fields (`weatherNote`, `notes`) this service also leaves at their defaults
  /// on the new day, a decision the plan left unsaid. If [sourceDayId] currently holds no live slot
  /// at all (every one of them since deleted), the new day is given the same default slot
  /// [createDay] would give a brand new one, so the invariant "a day has at least one slot" still
  /// holds for a day built by this method too.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> duplicateDay({
    required OcptProjectDatabase database,
    required String sourceDayId,
    required DateTime date,
  }) async {
    if (database.refusesUserWrite("duplicateDay")) {
      return null;
    }

    return database.transaction(() async {
      final sourceDay = await _getDayRow(database: database, dayId: sourceDayId);
      final existingDays = await _liveDayRows(
        database: database,
        screenplayId: sourceDay.screenplayId,
      );
      final newDayId = const Uuid().v4();

      await database
          .into(database.ocptShootingDaysTable)
          .insert(
            OcptShootingDaysTableCompanion.insert(
              id: newDayId,
              screenplayId: sourceDay.screenplayId,
              date: date,
              sortKey: Value(
                ocptFractionalKeyBetween(
                  before: existingDays.isEmpty ? null : existingDays.last.sortKey,
                ),
              ),
            ),
          );

      final sourceSlots = await _liveSlotRows(database: database, dayId: sourceDayId);

      if (sourceSlots.isEmpty) {
        await _insertDefaultSlot(database: database, dayId: newDayId);
        return newDayId;
      }

      final newSlotIds = [for (var i = 0; i < sourceSlots.length; i++) const Uuid().v4()];
      final slotSortKeys = ocptFractionalKeySequence(sourceSlots.length);

      for (var i = 0; i < sourceSlots.length; i++) {
        final sourceSlot = sourceSlots[i];

        await database
            .into(database.ocptShootingSlotsTable)
            .insert(
              OcptShootingSlotsTableCompanion.insert(
                id: newSlotIds[i],
                shootingDayId: newDayId,
                sortKey: Value(slotSortKeys[i]),
                label: Value(sourceSlot.label),
                locationId: Value(sourceSlot.locationId),
                setId: Value(sourceSlot.setId),
                startMinute: sourceSlot.startMinute,
                notes: Value(sourceSlot.notes),
              ),
            );

        final sourceCrew = await _liveCrewRowsOfSlot(database: database, slotId: sourceSlot.id);
        final crewSortKeys = ocptFractionalKeySequence(sourceCrew.length);
        for (var j = 0; j < sourceCrew.length; j++) {
          final crewMember = sourceCrew[j];
          await database
              .into(database.ocptShootingSlotCrewTable)
              .insert(
                OcptShootingSlotCrewTableCompanion.insert(
                  id: const Uuid().v4(),
                  slotId: newSlotIds[i],
                  sortKey: Value(crewSortKeys[j]),
                  personId: crewMember.personId,
                  positionId: Value(crewMember.positionId),
                  customLabel: Value(crewMember.customLabel),
                  notes: Value(crewMember.notes),
                ),
              );
        }

        final sourceCast = await _liveCastRowsOfSlot(database: database, slotId: sourceSlot.id);
        final castSortKeys = ocptFractionalKeySequence(sourceCast.length);
        for (var j = 0; j < sourceCast.length; j++) {
          final castMember = sourceCast[j];
          await database
              .into(database.ocptShootingSlotCastTable)
              .insert(
                OcptShootingSlotCastTableCompanion.insert(
                  id: const Uuid().v4(),
                  slotId: newSlotIds[i],
                  roleId: castMember.roleId,
                  sortKey: Value(castSortKeys[j]),
                  notes: Value(castMember.notes),
                ),
              );
        }
      }

      return newDayId;
    });
  }

  /// Creates a new slot inside day [shootingDayId], appended at the end of its current slots, and
  /// returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createSlot({
    required OcptProjectDatabase database,
    required String shootingDayId,
    required int startMinute,
    String label = "",
    String? locationId,
    String? setId,
    String notes = "",
  }) async {
    if (database.refusesUserWrite("createSlot")) {
      return null;
    }

    final existing = await _liveSlotRows(database: database, dayId: shootingDayId);
    final id = const Uuid().v4();

    await database
        .into(database.ocptShootingSlotsTable)
        .insert(
          OcptShootingSlotsTableCompanion.insert(
            id: id,
            shootingDayId: shootingDayId,
            label: Value(label),
            locationId: Value(locationId),
            setId: Value(setId),
            startMinute: startMinute,
            notes: Value(notes),
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of slot [slotId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderSlot] and [deleteSlot].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateSlot({
    required OcptProjectDatabase database,
    required String slotId,
    Value<String> label = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
    Value<String?> setId = const Value.absent(),
    Value<int> startMinute = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSlot")) {
      return;
    }

    await (database.update(
      database.ocptShootingSlotsTable,
    )..where((table) => table.id.equals(slotId) & table.isDeleted.not())).write(
      OcptShootingSlotsTableCompanion(
        label: label,
        locationId: locationId,
        setId: setId,
        startMinute: startMinute,
        notes: notes,
      ),
    );
  }

  /// Moves slot [slotId] to [newPosition] (0-based) within its own day's slots, by giving it a
  /// `sortKey` sitting between the two slots it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderSlot({
    required OcptProjectDatabase database,
    required String slotId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderSlot")) {
      return;
    }

    await database.transaction(() async {
      final slot = await _getSlotRow(database: database, slotId: slotId);
      final others =
          (await _liveSlotRows(database: database, dayId: slot.shootingDayId))
            ..removeWhere((row) => row.id == slotId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptShootingSlotsTable,
      )..where((table) => table.id.equals(slotId))).write(
        OcptShootingSlotsTableCompanion(sortKey: Value(sortKey)),
      );
    });
  }

  /// Tombstones slot [slotId] in [database], and its crew and cast rows along with it.
  ///
  /// **The slot's own live blocks are moved, in their own order, to the end of the day's first
  /// other live slot** (lowest `sortKey`) — removing a convocation window must not silently unplace
  /// whatever was scheduled inside it, so its blocks simply join a different chain. **When [slotId]
  /// is the day's last live slot, there is nowhere left to move its blocks to, and they are
  /// tombstoned along with it**: a block can never be slotless (`shooting_day_blocks.slotId` is
  /// `NOT NULL` from schema v12), so a day with no slot at all can hold no timetable either — see
  /// the class doc comment.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteSlot({required OcptProjectDatabase database, required String slotId}) async {
    if (database.refusesUserWrite("deleteSlot")) {
      return;
    }

    await database.transaction(() async {
      final slot = await _getSlotRow(database: database, slotId: slotId);

      await (database.update(
        database.ocptShootingSlotCrewTable,
      )..where((table) => table.slotId.equals(slotId))).write(
        const OcptShootingSlotCrewTableCompanion(isDeleted: Value(true)),
      );
      await (database.update(
        database.ocptShootingSlotCastTable,
      )..where((table) => table.slotId.equals(slotId))).write(
        const OcptShootingSlotCastTableCompanion(isDeleted: Value(true)),
      );

      final otherSlots =
          (await _liveSlotRows(database: database, dayId: slot.shootingDayId))
            ..removeWhere((row) => row.id == slotId);
      final blocksToMove = await _liveBlockRowsOfSlot(database: database, slotId: slotId);

      if (otherSlots.isEmpty) {
        if (blocksToMove.isNotEmpty) {
          await (database.update(
            database.ocptShootingDayBlocksTable,
          )..where((table) => table.slotId.equals(slotId))).write(
            const OcptShootingDayBlocksTableCompanion(isDeleted: Value(true)),
          );
        }
      } else if (blocksToMove.isNotEmpty) {
        final destinationSlot = otherSlots.first;
        final destinationBlocks = await _liveBlockRowsOfSlot(
          database: database,
          slotId: destinationSlot.id,
        );
        final newSortKeys = ocptFractionalKeysBetween(
          count: blocksToMove.length,
          before: destinationBlocks.isEmpty ? null : destinationBlocks.last.sortKey,
        );

        for (var i = 0; i < blocksToMove.length; i++) {
          await (database.update(
            database.ocptShootingDayBlocksTable,
          )..where((table) => table.id.equals(blocksToMove[i].id))).write(
            OcptShootingDayBlocksTableCompanion(
              slotId: Value(destinationSlot.id),
              sortKey: Value(newSortKeys[i]),
            ),
          );
        }
      }

      await (database.update(
        database.ocptShootingSlotsTable,
      )..where((table) => table.id.equals(slotId))).write(
        const OcptShootingSlotsTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// Adds [personId] as holding [positionId] (or, when the catalogue has nothing that fits,
  /// [customLabel]) during slot [slotId], appended at the end of its current crew, and returns the
  /// freshly generated id of the assignment — no more than the link itself: this person's arrival,
  /// readiness band and departure are read off every slot they are linked to (ADR 0018), never
  /// seeded or typed here.
  ///
  /// A person holding two positions in one slot is two rows — see `OcptShootingSlotCrewTable`'s own
  /// doc comment — so, unlike [addSlotCastRole], this never refuses a duplicate `{slotId, personId}`
  /// pair.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addSlotCrewMember({
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

    final existing = await _liveCrewRowsOfSlot(database: database, slotId: slotId);
    final id = const Uuid().v4();

    await database
        .into(database.ocptShootingSlotCrewTable)
        .insert(
          OcptShootingSlotCrewTableCompanion.insert(
            id: id,
            slotId: slotId,
            personId: personId,
            positionId: Value(positionId),
            customLabel: Value(customLabel),
            notes: Value(notes),
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of crew assignment [crewMemberId] in [database] that are passed as
  /// something other than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change
  /// through slot reordering and [removeSlotCrewMember].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateSlotCrewMember({
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

    await (database.update(
      database.ocptShootingSlotCrewTable,
    )..where((table) => table.id.equals(crewMemberId) & table.isDeleted.not())).write(
      OcptShootingSlotCrewTableCompanion(
        personId: personId,
        positionId: positionId,
        customLabel: customLabel,
        notes: notes,
      ),
    );
  }

  /// Tombstones crew assignment [crewMemberId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeSlotCrewMember({
    required OcptProjectDatabase database,
    required String crewMemberId,
  }) async {
    if (database.refusesUserWrite("removeSlotCrewMember")) {
      return;
    }

    await (database.update(
      database.ocptShootingSlotCrewTable,
    )..where((table) => table.id.equals(crewMemberId))).write(
      const OcptShootingSlotCrewTableCompanion(isDeleted: Value(true)),
    );
  }

  /// Convokes role [roleId] during slot [slotId], appended at the end of its current cast, and
  /// returns the id of the convocation — no more than the link itself: this role's arrival,
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
  Future<String?> addSlotCastRole({
    required OcptProjectDatabase database,
    required String slotId,
    required String roleId,
    String notes = "",
  }) async {
    if (database.refusesUserWrite("addSlotCastRole")) {
      return null;
    }

    return database.transaction(() async {
      final existingRows =
          await (database.select(database.ocptShootingSlotCastTable)..where(
                (table) => table.slotId.equals(slotId) & table.roleId.equals(roleId),
              ))
              .get();

      OcptShootingSlotCastRow? tombstoned;
      for (final row in existingRows) {
        if (!row.isDeleted) {
          return row.id;
        }
        tombstoned ??= row;
      }

      if (tombstoned != null) {
        await (database.update(
          database.ocptShootingSlotCastTable,
        )..where((table) => table.id.equals(tombstoned!.id))).write(
          OcptShootingSlotCastTableCompanion(notes: Value(notes), isDeleted: const Value(false)),
        );
        return tombstoned.id;
      }

      final existing = await _liveCastRowsOfSlot(database: database, slotId: slotId);
      final id = const Uuid().v4();

      await database
          .into(database.ocptShootingSlotCastTable)
          .insert(
            OcptShootingSlotCastTableCompanion.insert(
              id: id,
              slotId: slotId,
              roleId: roleId,
              notes: Value(notes),
              sortKey: Value(
                ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
              ),
            ),
          );

      return id;
    });
  }

  /// Updates the fields of cast convocation [castRoleId] in [database] that are passed as something
  /// other than [Value.absent]. Never touches `sortKey`, `roleId` or `isDeleted`: those only change
  /// through slot reordering, [addSlotCastRole] and [removeSlotCastRole].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateSlotCastRole({
    required OcptProjectDatabase database,
    required String castRoleId,
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSlotCastRole")) {
      return;
    }

    await (database.update(
      database.ocptShootingSlotCastTable,
    )..where((table) => table.id.equals(castRoleId) & table.isDeleted.not())).write(
      OcptShootingSlotCastTableCompanion(notes: notes),
    );
  }

  /// Tombstones cast convocation [castRoleId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> removeSlotCastRole({
    required OcptProjectDatabase database,
    required String castRoleId,
  }) async {
    if (database.refusesUserWrite("removeSlotCastRole")) {
      return;
    }

    await (database.update(
      database.ocptShootingSlotCastTable,
    )..where((table) => table.id.equals(castRoleId))).write(
      const OcptShootingSlotCastTableCompanion(isDeleted: Value(true)),
    );
  }

  /// Places shot [shotId] inside slot [slotId], at [atPosition] within that slot's own timetable
  /// (or appended at the end when null), and returns the id of the freshly created block placing
  /// it. The day it lands on is read off [slotId]'s own row, so a block can never name a day its
  /// slot doesn't belong to.
  ///
  /// **Always creates a new block** — see the class doc comment: calling this on a shot already
  /// placed elsewhere adds a second placement rather than moving the first, exactly what a shot
  /// interrupted by the meal break needs. Moving an *existing* placement is [moveBlockToSlot] or the
  /// reorder, and removing one is [deleteBlock] — neither is this method's job.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> placeShot({
    required OcptProjectDatabase database,
    required String slotId,
    required String shotId,
    int? atPosition,
  }) async {
    if (database.refusesUserWrite("placeShot")) {
      return null;
    }

    return database.transaction(() async {
      final slot = await _getSlotRow(database: database, slotId: slotId);
      final dayId = slot.shootingDayId;

      final slotBlocks = await _liveBlockRowsOfSlot(database: database, slotId: slotId);

      final clampedPosition = atPosition == null
          ? slotBlocks.length
          : (atPosition < 0 ? 0 : (atPosition > slotBlocks.length ? slotBlocks.length : atPosition));

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? slotBlocks[clampedPosition - 1].sortKey : null,
        after: clampedPosition < slotBlocks.length ? slotBlocks[clampedPosition].sortKey : null,
      );

      final id = const Uuid().v4();
      await database
          .into(database.ocptShootingDayBlocksTable)
          .insert(
            OcptShootingDayBlocksTableCompanion.insert(
              id: id,
              shootingDayId: dayId,
              slotId: slotId,
              kind: const Value(OcptShootingBlockKind.shot),
              shotId: Value(shotId),
              sortKey: Value(sortKey),
            ),
          );
      return id;
    });
  }

  /// Tombstones block [blockId], whatever its [OcptShootingBlockKind] — a shot block, a milestone
  /// or a `hold`. Removing a shot's placement, now that a shot may carry several, means naming the
  /// block it sits in and calling this — there is no operation keyed by shot any more.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteBlock({
    required OcptProjectDatabase database,
    required String blockId,
  }) async {
    if (database.refusesUserWrite("deleteBlock")) {
      return;
    }

    await (database.update(
      database.ocptShootingDayBlocksTable,
    )..where((table) => table.id.equals(blockId))).write(
      const OcptShootingDayBlocksTableCompanion(isDeleted: Value(true)),
    );
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
  /// **[sceneId] belongs to a [OcptShootingBlockKind.hold] and to nothing else** — the sequence
  /// whose time is being reserved, which is what says who a hold convokes (ADR 0017). Passed with
  /// any other [kind] it is **ignored** rather than refused: the block itself is legitimate, only
  /// the scene link means nothing on it, and a caller that hands one over is choosing a kind, not
  /// making a claim about a sequence. It stays null on a hold whose sequence hasn't been settled
  /// yet, which is an ordinary state.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createBlock({
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

    final slot = await _getSlotRow(database: database, slotId: slotId);
    final slotBlocks = await _liveBlockRowsOfSlot(database: database, slotId: slotId);
    final clampedPosition = atPosition == null
        ? slotBlocks.length
        : (atPosition < 0 ? 0 : (atPosition > slotBlocks.length ? slotBlocks.length : atPosition));

    final sortKey = ocptFractionalKeyBetween(
      before: clampedPosition > 0 ? slotBlocks[clampedPosition - 1].sortKey : null,
      after: clampedPosition < slotBlocks.length ? slotBlocks[clampedPosition].sortKey : null,
    );

    final id = const Uuid().v4();
    await database
        .into(database.ocptShootingDayBlocksTable)
        .insert(
          OcptShootingDayBlocksTableCompanion.insert(
            id: id,
            shootingDayId: slot.shootingDayId,
            slotId: slotId,
            kind: Value(kind),
            sceneId: Value(kind == OcptShootingBlockKind.hold ? sceneId : null),
            label: Value(label),
            durationMinutes: Value(durationMinutes),
            anchorMinute: Value(anchorMinute),
            notes: Value(notes),
            sortKey: Value(sortKey),
          ),
        );

    return id;
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
  /// **`sceneId` only ever holds on a [OcptShootingBlockKind.hold]**, the same invariant
  /// [createBlock] enforces: a scene named on a block of any other kind is dropped to null, and a
  /// hold turned into another kind by this very call loses the sequence it was holding — it is no
  /// longer holding anything. A hold's scene is set to null the ordinary way, by passing
  /// `Value(null)`, which is how a production un-decides which sequence a reserved slot is for.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateBlock({
    required OcptProjectDatabase database,
    required String blockId,
    Value<OcptShootingBlockKind> kind = const Value.absent(),
    Value<String?> sceneId = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<int?> durationMinutes = const Value.absent(),
    Value<int?> anchorMinute = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateBlock")) {
      return;
    }

    if (kind.present && kind.value == OcptShootingBlockKind.shot) {
      return;
    }

    await database.transaction(() async {
      var sceneIdToWrite = sceneId;

      if (kind.present || sceneId.present) {
        final row =
            await (database.select(database.ocptShootingDayBlocksTable)..where(
                  (table) => table.id.equals(blockId) & table.isDeleted.not(),
                ))
                .getSingleOrNull();

        if (row == null || (kind.present && row.kind == OcptShootingBlockKind.shot)) {
          return;
        }

        final resultingKind = kind.present ? kind.value : row.kind;
        if (resultingKind != OcptShootingBlockKind.hold) {
          sceneIdToWrite = const Value(null);
        }
      }

      await (database.update(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.id.equals(blockId) & table.isDeleted.not())).write(
        OcptShootingDayBlocksTableCompanion(
          kind: kind,
          sceneId: sceneIdToWrite,
          label: label,
          durationMinutes: durationMinutes,
          anchorMinute: anchorMinute,
          notes: notes,
        ),
      );
    });
  }

  /// Moves block [blockId] to [newPosition] (0-based) within its own slot's timetable, by giving it
  /// a `sortKey` sitting between the two blocks it lands between there. Writes **exactly one row**.
  ///
  /// **`sortKey` stays day-wide** — these tables have no per-slot scope of their own, so a key
  /// allocated between two of one slot's blocks may well land, numerically, among another slot's.
  /// That is harmless: ordering is only ever read *within* a slot ([_liveBlockRowsOfSlot]), and two
  /// slots' chains are independent of one another (ADR 0015, amended).
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderBlock({
    required OcptProjectDatabase database,
    required String blockId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderBlock")) {
      return;
    }

    await database.transaction(() async {
      final block = await _getBlockRow(database: database, blockId: blockId);
      final others =
          (await _liveBlockRowsOfSlot(database: database, slotId: block.slotId))
            ..removeWhere((row) => row.id == blockId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.id.equals(blockId))).write(
        OcptShootingDayBlocksTableCompanion(sortKey: Value(sortKey)),
      );
    });
  }

  /// Moves block [blockId] to slot [targetSlotId], at [newPosition] (0-based) within that slot's
  /// own timetable, by giving it a `sortKey` sitting between the two blocks it lands between there.
  /// Writes **exactly one row**: both the block's `slotId` and its `shootingDayId` — read off
  /// [targetSlotId]'s own row, so a block can never end up pointing at a day its slot doesn't
  /// belong to — change in the same write as its `sortKey`. Replaces the old `moveBlockToDay`, whose
  /// "always nulls the slotId" rule disappears with it: a block belongs to exactly one slot from
  /// schema v12 on, so moving it across days now always means moving it into a slot of the
  /// destination day too, never leaving it slotless.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> moveBlockToSlot({
    required OcptProjectDatabase database,
    required String blockId,
    required String targetSlotId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("moveBlockToSlot")) {
      return;
    }

    await database.transaction(() async {
      final targetSlot = await _getSlotRow(database: database, slotId: targetSlotId);
      final others = await _liveBlockRowsOfSlot(database: database, slotId: targetSlotId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.id.equals(blockId))).write(
        OcptShootingDayBlocksTableCompanion(
          shootingDayId: Value(targetSlot.shootingDayId),
          slotId: Value(targetSlotId),
          sortKey: Value(sortKey),
        ),
      );
    });
  }

  /// Inserts the default first slot a brand new day is never without: an empty label and the
  /// default start [_defaultStartMinute]. Shared by [createDay] and [duplicateDay]'s empty-source
  /// fallback.
  Future<void> _insertDefaultSlot({
    required OcptProjectDatabase database,
    required String dayId,
  }) => database
      .into(database.ocptShootingSlotsTable)
      .insert(
        OcptShootingSlotsTableCompanion.insert(
          id: const Uuid().v4(),
          shootingDayId: dayId,
          startMinute: _defaultStartMinute,
          sortKey: Value(ocptFractionalKeyBetween()),
        ),
      );

  /// Reads back the day row [dayId], throwing if it doesn't exist or has been tombstoned.
  Future<OcptShootingDayRow> _getDayRow({
    required OcptProjectDatabase database,
    required String dayId,
  }) => (database.select(database.ocptShootingDaysTable)
        ..where((table) => table.id.equals(dayId) & table.isDeleted.not()))
      .getSingle();

  /// Reads back the slot row [slotId], throwing if it doesn't exist or has been tombstoned.
  Future<OcptShootingSlotRow> _getSlotRow({
    required OcptProjectDatabase database,
    required String slotId,
  }) => (database.select(database.ocptShootingSlotsTable)
        ..where((table) => table.id.equals(slotId) & table.isDeleted.not()))
      .getSingle();

  /// Reads back the block row [blockId], throwing if it doesn't exist or has been tombstoned.
  Future<OcptShootingDayBlockRow> _getBlockRow({
    required OcptProjectDatabase database,
    required String blockId,
  }) => (database.select(database.ocptShootingDayBlocksTable)
        ..where((table) => table.id.equals(blockId) & table.isDeleted.not()))
      .getSingle();

  /// Every live day row of screenplay [screenplayId], ordered by `date` ascending then `sortKey`
  /// ascending — chronologically, `sortKey` breaking the tie between two days sharing one date (a
  /// second unit), the order [OcptShootingDay.dayNumber] is a read-time rank over.
  Future<List<OcptShootingDayRow>> _liveDayRows({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => (database.select(database.ocptShootingDaysTable)
        ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
        ..orderBy([
          (table) => OrderingTerm.asc(table.date),
          (table) => OrderingTerm.asc(table.sortKey),
        ]))
      .get();

  /// Every live slot row of day [dayId], ordered by `sortKey`.
  Future<List<OcptShootingSlotRow>> _liveSlotRows({
    required OcptProjectDatabase database,
    required String dayId,
  }) => (database.select(database.ocptShootingSlotsTable)
        ..where((table) => table.shootingDayId.equals(dayId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// Every live crew row of slot [slotId], ordered by `sortKey`.
  Future<List<OcptShootingSlotCrewRow>> _liveCrewRowsOfSlot({
    required OcptProjectDatabase database,
    required String slotId,
  }) => (database.select(database.ocptShootingSlotCrewTable)
        ..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// Every live cast row of slot [slotId], ordered by `sortKey`.
  Future<List<OcptShootingSlotCastRow>> _liveCastRowsOfSlot({
    required OcptProjectDatabase database,
    required String slotId,
  }) => (database.select(database.ocptShootingSlotCastTable)
        ..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// Every live block row of slot [slotId], ordered by `sortKey` — that slot's own timetable order.
  Future<List<OcptShootingDayBlockRow>> _liveBlockRowsOfSlot({
    required OcptProjectDatabase database,
    required String slotId,
  }) => (database.select(database.ocptShootingDayBlocksTable)
        ..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();
}
