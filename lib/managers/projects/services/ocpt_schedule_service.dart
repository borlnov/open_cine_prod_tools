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
/// (`shooting_slots`), who is convoked in each (`shooting_slot_crew`/`shooting_slot_cast`), and the
/// day's timetable (`shooting_day_blocks`) — placing a shot, reserving a `hold`, and the milestones
/// (preparation, hair/make-up, a meal, a travel move, the wrap) interleaved between them.
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
/// **A shot is placed at most once across the whole schedule.** [placeShot] looks for the shot's
/// existing live block (kind [OcptShootingBlockKind.shot]) across every day before creating one, so
/// calling it on an already-placed shot *moves* that block — to a new position, a new slot, or a new
/// day — rather than creating a second one. This is what makes the shot list's `Jour de tournage`
/// read-out ([loadShotPlacements]) well defined.
///
/// **Deleting a day cascades; deleting a slot does not unplace anything.** [deleteDay] tombstones
/// everything hanging off it — its slots, their crew and cast, and its blocks — in one transaction,
/// the way `OcptLocationsService.deleteLocation` tombstones a location's sets. [deleteSlot] is
/// narrower: it tombstones the slot's own crew and cast, but a block sitting in that slot only loses
/// its `slotId` (set to null) and **keeps its place in the day** — removing a convocation window
/// must not silently unplace whatever was scheduled inside it.
///
/// **Duplicating a day copies the shape of the crew, not the day's own work.** [duplicateDay] copies
/// the source day's slots, their crew, their cast and every one of their times, with fresh ids and
/// fresh `sortKey`s — but copies **neither the placed shots nor the crew note**, and (a decision this
/// service makes, the plan leaving it unsaid) starts the new day's own `status`, `weatherNote` and
/// `notes` at their column defaults too: a stable crew is entered once for a whole shoot and reused
/// day after day, while what got shot, what the weather did and why a day was lost are all facts of
/// the specific day being duplicated *away* from, not of the one being planned.
///
/// **`shooting_presences` is out of scope here.** It is declared in schema v11 alongside these six
/// tables (one migration for the whole mode, even though the presence grid it backs is milestone
/// M3's), but this service exposes nothing for it: there is nothing to override yet, since nothing
/// computes the grid it would override a cell of.
///
/// **How a day's blocks chain into clock times is not this service's business.** That rule is stated
/// once and implemented once, in `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015); this service
/// only ever reads and writes the columns that function takes as input.
class OcptScheduleService {
  /// The crew call minute a day's first slot is given by [createDay]: 08:00.
  static const _defaultCrewCallMinute = 480;

  /// The crew wrap minute a day's first slot is given by [createDay]: 18:00.
  static const _defaultCrewWrapMinute = 1080;

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

  /// For every shot of [screenplayId] placed in the schedule, which day it sits on and that day's
  /// rank and date, keyed by shot id.
  ///
  /// A shot with no live block has **no entry** in the returned map: the shot list's `Jour de
  /// tournage` read-out reads absence as "not yet planned" rather than looking for a placement with
  /// null fields.
  Future<Map<String, OcptShotPlacement>> loadShotPlacements({
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

    return {
      for (final row in blockRows)
        if (row.shotId != null)
          row.shotId!: OcptShotPlacement(
            shotId: row.shotId!,
            dayId: row.shootingDayId,
            dayNumber: dayNumberById[row.shootingDayId]!,
            date: dateById[row.shootingDayId]!,
          ),
    };
  }

  /// Creates a new shooting day of screenplay [screenplayId] dated [date], appended at the end, and
  /// returns its freshly generated id.
  ///
  /// **Mints one slot with it.** A day has at least one convocation window — see
  /// `OcptShootingSlotsTable`'s own doc comment — and a day with none could hold no crew, no cast
  /// and no chain start for its timetable. That first slot gets an empty [OcptShootingSlot.label]
  /// and the default crew band [_defaultCrewCallMinute]/[_defaultCrewWrapMinute] (08:00 → 18:00).
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
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderDay] and [deleteDay].
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

  /// Moves day [dayId] to [newPosition] (0-based) within its screenplay's days, by giving it a
  /// `sortKey` sitting between the two days it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderDay({
    required OcptProjectDatabase database,
    required String dayId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderDay")) {
      return;
    }

    await database.transaction(() async {
      final day = await _getDayRow(database: database, dayId: dayId);
      final others =
          (await _liveDayRows(database: database, screenplayId: day.screenplayId))
            ..removeWhere((row) => row.id == dayId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptShootingDaysTable,
      )..where((table) => table.id.equals(dayId))).write(
        OcptShootingDaysTableCompanion(sortKey: Value(sortKey)),
      );
    });
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
  /// copies of [sourceDayId]'s live slots, their live crew, their live cast and every one of their
  /// times — fresh ids, fresh `sortKey`s, everything else copied verbatim. Returns the new day's id.
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
                crewCallMinute: sourceSlot.crewCallMinute,
                crewWrapMinute: sourceSlot.crewWrapMinute,
                castCallMinute: Value(sourceSlot.castCallMinute),
                castWrapMinute: Value(sourceSlot.castWrapMinute),
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
                  callMinute: Value(crewMember.callMinute),
                  wrapMinute: Value(crewMember.wrapMinute),
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
                  arrivalMinute: Value(castMember.arrivalMinute),
                  castCallMinute: Value(castMember.castCallMinute),
                  castWrapMinute: Value(castMember.castWrapMinute),
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
    required int crewCallMinute,
    required int crewWrapMinute,
    String label = "",
    String? locationId,
    String? setId,
    int? castCallMinute,
    int? castWrapMinute,
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
            crewCallMinute: crewCallMinute,
            crewWrapMinute: crewWrapMinute,
            castCallMinute: Value(castCallMinute),
            castWrapMinute: Value(castWrapMinute),
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
    Value<int> crewCallMinute = const Value.absent(),
    Value<int> crewWrapMinute = const Value.absent(),
    Value<int?> castCallMinute = const Value.absent(),
    Value<int?> castWrapMinute = const Value.absent(),
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
        crewCallMinute: crewCallMinute,
        crewWrapMinute: crewWrapMinute,
        castCallMinute: castCallMinute,
        castWrapMinute: castWrapMinute,
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
  /// **A block sitting in this slot is not tombstoned.** It only loses its `slotId` (set to null)
  /// and keeps its place in the day's timetable: removing a convocation window must not silently
  /// unplace whatever was scheduled inside it — see the class doc comment.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteSlot({required OcptProjectDatabase database, required String slotId}) async {
    if (database.refusesUserWrite("deleteSlot")) {
      return;
    }

    await database.transaction(() async {
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
      await (database.update(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.slotId.equals(slotId))).write(
        const OcptShootingDayBlocksTableCompanion(slotId: Value(null)),
      );
      await (database.update(
        database.ocptShootingSlotsTable,
      )..where((table) => table.id.equals(slotId))).write(
        const OcptShootingSlotsTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// Adds [personId] as holding [positionId] (or, when the catalogue has nothing that fits,
  /// [customLabel]) during slot [slotId], appended at the end of its current crew, and returns the
  /// freshly generated id of the assignment.
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
    int? callMinute,
    int? wrapMinute,
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
            callMinute: Value(callMinute),
            wrapMinute: Value(wrapMinute),
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
    Value<int?> callMinute = const Value.absent(),
    Value<int?> wrapMinute = const Value.absent(),
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
        callMinute: callMinute,
        wrapMinute: wrapMinute,
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
  /// returns the id of the convocation.
  ///
  /// **The same role convoked twice in one slot is refused** — unlike crew, where two positions
  /// held by the same person are legitimate (see [addSlotCrewMember]): a role already convoked live
  /// in this slot has this call return that row's own id rather than create a second one. A role
  /// convoked here before and since removed has its tombstone lifted and its fields overwritten
  /// with this call's, exactly as `OcptLocationsService.assignSceneToSet` revives a dropped link
  /// rather than duplicating it.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addSlotCastRole({
    required OcptProjectDatabase database,
    required String slotId,
    required String roleId,
    int? arrivalMinute,
    int? castCallMinute,
    int? castWrapMinute,
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
          OcptShootingSlotCastTableCompanion(
            arrivalMinute: Value(arrivalMinute),
            castCallMinute: Value(castCallMinute),
            castWrapMinute: Value(castWrapMinute),
            notes: Value(notes),
            isDeleted: const Value(false),
          ),
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
              arrivalMinute: Value(arrivalMinute),
              castCallMinute: Value(castCallMinute),
              castWrapMinute: Value(castWrapMinute),
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
    Value<int?> arrivalMinute = const Value.absent(),
    Value<int?> castCallMinute = const Value.absent(),
    Value<int?> castWrapMinute = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSlotCastRole")) {
      return;
    }

    await (database.update(
      database.ocptShootingSlotCastTable,
    )..where((table) => table.id.equals(castRoleId) & table.isDeleted.not())).write(
      OcptShootingSlotCastTableCompanion(
        arrivalMinute: arrivalMinute,
        castCallMinute: castCallMinute,
        castWrapMinute: castWrapMinute,
        notes: notes,
      ),
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

  /// Places shot [shotId] in day [dayId], inside slot [slotId] (or with no slot when null), at
  /// [atPosition] within that day's timetable (or appended at the end when null), and returns the
  /// id of the block placing it.
  ///
  /// **A shot is placed at most once across the whole schedule** — see the class doc comment: if
  /// [shotId] already has a live block, this moves *that* block (to [dayId], [slotId] and
  /// [atPosition]) instead of creating a second one, whether or not it already sat on [dayId].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> placeShot({
    required OcptProjectDatabase database,
    required String dayId,
    required String shotId,
    String? slotId,
    int? atPosition,
  }) async {
    if (database.refusesUserWrite("placeShot")) {
      return null;
    }

    return database.transaction(() async {
      final existingBlock = await _liveShotBlockRow(database: database, shotId: shotId);

      final dayBlocks =
          (await _liveBlockRows(database: database, dayId: dayId))
            ..removeWhere((row) => row.id == existingBlock?.id);

      final clampedPosition = atPosition == null
          ? dayBlocks.length
          : (atPosition < 0 ? 0 : (atPosition > dayBlocks.length ? dayBlocks.length : atPosition));

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? dayBlocks[clampedPosition - 1].sortKey : null,
        after: clampedPosition < dayBlocks.length ? dayBlocks[clampedPosition].sortKey : null,
      );

      if (existingBlock != null) {
        await (database.update(
          database.ocptShootingDayBlocksTable,
        )..where((table) => table.id.equals(existingBlock.id))).write(
          OcptShootingDayBlocksTableCompanion(
            shootingDayId: Value(dayId),
            slotId: Value(slotId),
            sortKey: Value(sortKey),
          ),
        );
        return existingBlock.id;
      }

      final id = const Uuid().v4();
      await database
          .into(database.ocptShootingDayBlocksTable)
          .insert(
            OcptShootingDayBlocksTableCompanion.insert(
              id: id,
              shootingDayId: dayId,
              slotId: Value(slotId),
              kind: const Value(OcptShootingBlockKind.shot),
              shotId: Value(shotId),
              sortKey: Value(sortKey),
            ),
          );
      return id;
    });
  }

  /// Tombstones the block placing shot [shotId], if any. A no-op when the shot is not currently
  /// placed.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> unplaceShot({
    required OcptProjectDatabase database,
    required String shotId,
  }) async {
    if (database.refusesUserWrite("unplaceShot")) {
      return;
    }

    final block = await _liveShotBlockRow(database: database, shotId: shotId);
    if (block == null) {
      return;
    }

    await (database.update(
      database.ocptShootingDayBlocksTable,
    )..where((table) => table.id.equals(block.id))).write(
      const OcptShootingDayBlocksTableCompanion(isDeleted: Value(true)),
    );
  }

  /// Tombstones block [blockId], whatever its [OcptShootingBlockKind] — a shot block, a milestone
  /// or a `hold`. [unplaceShot] is the same operation keyed by shot instead of by block.
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

  /// Creates a new block of day [dayId], at [atPosition] within its timetable (or appended at the
  /// end when null), and returns its freshly generated id.
  ///
  /// **[kind] must not be [OcptShootingBlockKind.shot].** [placeShot] is the only writer of a shot
  /// block, since one also needs its `shotId` set in the very same write to keep `shotId` non-null
  /// **iff** `kind == shot`; passing [OcptShootingBlockKind.shot] here is refused (returns null,
  /// writes nothing) rather than creating a shot block with no shot.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createBlock({
    required OcptProjectDatabase database,
    required String dayId,
    required OcptShootingBlockKind kind,
    String? slotId,
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

    final dayBlocks = await _liveBlockRows(database: database, dayId: dayId);
    final clampedPosition = atPosition == null
        ? dayBlocks.length
        : (atPosition < 0 ? 0 : (atPosition > dayBlocks.length ? dayBlocks.length : atPosition));

    final sortKey = ocptFractionalKeyBetween(
      before: clampedPosition > 0 ? dayBlocks[clampedPosition - 1].sortKey : null,
      after: clampedPosition < dayBlocks.length ? dayBlocks[clampedPosition].sortKey : null,
    );

    final id = const Uuid().v4();
    await database
        .into(database.ocptShootingDayBlocksTable)
        .insert(
          OcptShootingDayBlocksTableCompanion.insert(
            id: id,
            shootingDayId: dayId,
            slotId: Value(slotId),
            kind: Value(kind),
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
  /// [placeShot]/[unplaceShot], block reordering/moving and [deleteBlock].
  ///
  /// **[kind] may never become [OcptShootingBlockKind.shot] here, and a block that already is one
  /// keeps it** — both refused as a no-op: setting it would either need a `shotId` this method
  /// doesn't take, or, for an existing shot block, would orphan the `shotId` it already carries,
  /// which this method does not touch. Turning a shot block into something else means unplacing the
  /// shot first ([unplaceShot]) and creating the other block afterwards ([createBlock]).
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateBlock({
    required OcptProjectDatabase database,
    required String blockId,
    Value<OcptShootingBlockKind> kind = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<int?> durationMinutes = const Value.absent(),
    Value<int?> anchorMinute = const Value.absent(),
    Value<String?> slotId = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateBlock")) {
      return;
    }

    if (kind.present && kind.value == OcptShootingBlockKind.shot) {
      return;
    }

    await database.transaction(() async {
      if (kind.present) {
        final row =
            await (database.select(database.ocptShootingDayBlocksTable)..where(
                  (table) => table.id.equals(blockId) & table.isDeleted.not(),
                ))
                .getSingleOrNull();

        if (row == null || row.kind == OcptShootingBlockKind.shot) {
          return;
        }
      }

      await (database.update(
        database.ocptShootingDayBlocksTable,
      )..where((table) => table.id.equals(blockId) & table.isDeleted.not())).write(
        OcptShootingDayBlocksTableCompanion(
          kind: kind,
          label: label,
          durationMinutes: durationMinutes,
          anchorMinute: anchorMinute,
          slotId: slotId,
          notes: notes,
        ),
      );
    });
  }

  /// Moves block [blockId] to [newPosition] (0-based) within day [dayId]'s timetable, by giving it
  /// a `sortKey` sitting between the two blocks it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderBlock({
    required OcptProjectDatabase database,
    required String dayId,
    required String blockId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderBlock")) {
      return;
    }

    await database.transaction(() async {
      final others =
          (await _liveBlockRows(database: database, dayId: dayId))
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

  /// Moves block [blockId] to day [targetDayId], at [newPosition] (0-based) within that day's
  /// timetable, by giving it a `sortKey` sitting between the two blocks it lands between there.
  /// Writes **exactly one row**.
  ///
  /// **Always nulls the block's `slotId`** (a decision this service makes, the plan leaving it
  /// unsaid): a slot belongs to one day, so a block carried across to another day cannot keep
  /// pointing at a convocation window that isn't on it — the destination day may not even have a
  /// slot with a matching call time. The block keeps everything else (its [OcptShootingBlockKind],
  /// its label, its duration, its anchor), and the caller re-slots it on the new day if needed.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> moveBlockToDay({
    required OcptProjectDatabase database,
    required String blockId,
    required String targetDayId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("moveBlockToDay")) {
      return;
    }

    await database.transaction(() async {
      final others = await _liveBlockRows(database: database, dayId: targetDayId);

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
          shootingDayId: Value(targetDayId),
          slotId: const Value(null),
          sortKey: Value(sortKey),
        ),
      );
    });
  }

  /// Inserts the default first slot a brand new day is never without: an empty label and the
  /// default crew band [_defaultCrewCallMinute]/[_defaultCrewWrapMinute]. Shared by [createDay] and
  /// [duplicateDay]'s empty-source fallback.
  Future<void> _insertDefaultSlot({
    required OcptProjectDatabase database,
    required String dayId,
  }) => database
      .into(database.ocptShootingSlotsTable)
      .insert(
        OcptShootingSlotsTableCompanion.insert(
          id: const Uuid().v4(),
          shootingDayId: dayId,
          crewCallMinute: _defaultCrewCallMinute,
          crewWrapMinute: _defaultCrewWrapMinute,
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

  /// Every live day row of screenplay [screenplayId], ordered by `sortKey`.
  Future<List<OcptShootingDayRow>> _liveDayRows({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => (database.select(database.ocptShootingDaysTable)
        ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
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

  /// Every live block row of day [dayId], ordered by `sortKey` — the day's timetable order.
  Future<List<OcptShootingDayBlockRow>> _liveBlockRows({
    required OcptProjectDatabase database,
    required String dayId,
  }) => (database.select(database.ocptShootingDayBlocksTable)
        ..where((table) => table.shootingDayId.equals(dayId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// The live block placing shot [shotId] (`kind == shot`), if any.
  Future<OcptShootingDayBlockRow?> _liveShotBlockRow({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.select(database.ocptShootingDayBlocksTable)..where(
        (table) =>
            table.shotId.equals(shotId) &
            table.kind.equalsValue(OcptShootingBlockKind.shot) &
            table.isDeleted.not(),
      ))
      .getSingleOrNull();
}
