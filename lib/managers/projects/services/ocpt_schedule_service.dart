// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_group.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over a screenplay's shooting schedule: its days, the named lead times each day carries
/// (`shooting_day_groups`), the convocation windows inside each day (`shooting_slots`), who is
/// convoked in each (`shooting_slot_crew`/`shooting_slot_cast`), and each **slot's own** timetable
/// (`shooting_day_blocks`) — placing a shot, reserving a `hold`, and the milestones (preparation,
/// hair/make-up, a meal, a travel move, the wrap) interleaved between them.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — these seven tables have no `position` column at all,
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
/// `startMinute` — see `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015, amended). **Every
/// convocation time is computed, never stored**: a crew member's call and wrap, an actor's PAT band
/// and arrival, are all read off a slot's chain and a lead time through
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0017) — this service only ever reads and writes
/// the columns those two functions take as input (a slot's `startMinute`, a block's duration and
/// anchor, and a crew/cast row's own `leadMinutes`/`groupId`), and never a clock time itself.
///
/// **A shot is placed at most once across the whole schedule.** [placeShot] looks for the shot's
/// existing live block (kind [OcptShootingBlockKind.shot]) across every day before creating one, so
/// calling it on an already-placed shot *moves* that block — to a new position or a new slot —
/// rather than creating a second one. This is what makes the shot list's `Jour de tournage`
/// read-out ([loadShotPlacements]) well defined.
///
/// **Deleting a day cascades; deleting a slot moves what was scheduled inside it, or drops it with
/// the slot when there is nowhere left to move it to.** [deleteDay] tombstones everything hanging
/// off it — its groups, its slots, their crew and cast, and its blocks — in one transaction, the way
/// `OcptLocationsService.deleteLocation` tombstones a location's sets. [deleteSlot] is narrower: it
/// tombstones the slot's own crew and cast, then moves the slot's own live blocks, in their own
/// order, to the end of the day's first *other* live slot (lowest `sortKey`) — removing a
/// convocation window must not silently unplace whatever was scheduled inside it, so its blocks
/// simply join a different chain. When the slot being deleted is the day's **last** live one, there
/// is nowhere left for its blocks to go, and they are tombstoned along with it — a decision taken
/// deliberately (`docs/plans/schedule-slots-and-computed-convocations.md` §4, M1'): a block can
/// never be slotless (`shooting_day_blocks.slotId` is `NOT NULL` from schema v12), so a day with no
/// slot at all can hold no timetable either.
///
/// **A group is a named lead time a day carries**, that any convocation of that day — crew and cast
/// alike — may point at (`OcptShootingDayGroupsTable`'s own doc comment, ADR 0017). [createDay]
/// copies the *previous* day's groups — the last live day of the screenplay in `sortKey` order, the
/// one it is appended after — labels and figures alike, with fresh ids and fresh `sortKey`s; nothing
/// else is inherited, copying the crew and the cast themselves being [duplicateDay]'s job. [deleteGroup]
/// tombstones the group **and** nulls the `groupId` of every crew and cast row of that day pointing
/// at it, in one transaction: deleting a group leaves its members with no group rather than removing
/// them from the day.
///
/// **[addSlotCrewMember]/[addSlotCastRole] seed a new convocation's own lead time and group from
/// that person's or role's most recent convocation** — the screenplay's live day with the greatest
/// `sortKey` other than the target's own, i.e. the plan's own order, not the calendar date. A crew
/// row matches on the same person **and** the same position (`positionId` when set, else
/// `customLabel`); a cast row matches on the same role. The source row's own `leadMinutes` is
/// copied **verbatim, null included** — a row that inherited its group's figure keeps inheriting
/// rather than having that figure frozen onto it — and its group is matched **by label** on the
/// target day's own groups (group ids being per day), staying null when the target day has no group
/// with that label. Without this, "ANNA needs 90 minutes of prosthetics" would have to be retyped on
/// every one of her days.
///
/// **Duplicating a day copies the shape of the crew, not the day's own work.** [duplicateDay] copies
/// the source day's groups (fresh ids, fresh `sortKey`s), its slots, their crew, their cast and
/// every one of their times, **remapping** each copied crew/cast row's `groupId` onto the new day's
/// group carrying the same label (group ids being per day) — but copies **neither the placed shots
/// nor the crew note**, and (a decision this service makes, the plan leaving it unsaid) starts the
/// new day's own `status`, `weatherNote` and `notes` at their column defaults too: a stable crew is
/// entered once for a whole shoot and reused day after day, while what got shot, what the weather
/// did and why a day was lost are all facts of the specific day being duplicated *away* from, not of
/// the one being planned.
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
  /// `sortKey` order, joined with its live groups, its live slots (each carrying its own live crew
  /// and cast) and its live blocks.
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

    final groupRows = dayIds.isEmpty
        ? const <OcptShootingDayGroupRow>[]
        : await (database.select(database.ocptShootingDayGroupsTable)
                ..where((table) => table.shootingDayId.isIn(dayIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

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

    final groupsByDayId = <String, List<OcptShootingDayGroup>>{};
    for (final row in groupRows) {
      groupsByDayId
          .putIfAbsent(row.shootingDayId, () => [])
          .add(OcptShootingDayGroup.fromRow(row));
    }

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
      groupsByDayId: groupsByDayId,
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
  /// and the default start [_defaultStartMinute] (08:00).
  ///
  /// **Copies the previous day's groups** — the screenplay's last live day in `sortKey` order, the
  /// one this new day is appended after — labels and figures alike, with fresh ids and fresh
  /// `sortKey`s; nothing else is inherited (see the class doc comment). A day created with no
  /// previous day to copy from simply starts with none.
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

      if (existing.isNotEmpty) {
        await _copyGroups(database: database, sourceDayId: existing.last.id, targetDayId: dayId);
      }

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

  /// Tombstones day [dayId] in [database], and along with it: its groups, its slots, their crew and
  /// cast rows, and its blocks — everything hanging off it, in one transaction, exactly as
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
        database.ocptShootingDayGroupsTable,
      )..where((table) => table.shootingDayId.equals(dayId))).write(
        const OcptShootingDayGroupsTableCompanion(isDeleted: Value(true)),
      );

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
  /// copies of [sourceDayId]'s live groups, its live slots, their live crew, their live cast and
  /// every one of their times — fresh ids, fresh `sortKey`s, everything else copied verbatim, each
  /// copied crew/cast row's `groupId` **remapped** onto the new day's own copy of the group it
  /// pointed at (matched by label, group ids being per day). Returns the new day's id.
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

      final newGroupIdByLabel = await _copyGroups(
        database: database,
        sourceDayId: sourceDayId,
        targetDayId: newDayId,
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
                  groupId: Value(
                    crewMember.groupId == null ? null : newGroupIdByLabel[crewMember.groupId],
                  ),
                  leadMinutes: Value(crewMember.leadMinutes),
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
                  groupId: Value(
                    castMember.groupId == null ? null : newGroupIdByLabel[castMember.groupId],
                  ),
                  leadMinutes: Value(castMember.leadMinutes),
                  notes: Value(castMember.notes),
                ),
              );
        }
      }

      return newDayId;
    });
  }

  /// Creates a new group on day [shootingDayId], appended at the end of its current groups, and
  /// returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createGroup({
    required OcptProjectDatabase database,
    required String shootingDayId,
    String label = "",
    int leadMinutes = 0,
  }) async {
    if (database.refusesUserWrite("createGroup")) {
      return null;
    }

    final existing = await _liveGroupRows(database: database, dayId: shootingDayId);
    final id = const Uuid().v4();

    await database
        .into(database.ocptShootingDayGroupsTable)
        .insert(
          OcptShootingDayGroupsTableCompanion.insert(
            id: id,
            shootingDayId: shootingDayId,
            label: Value(label),
            leadMinutes: Value(leadMinutes),
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of group [groupId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [deleteGroup] — there is no `reorderGroup`, nothing ordering a group by hand yet.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateGroup({
    required OcptProjectDatabase database,
    required String groupId,
    Value<String> label = const Value.absent(),
    Value<int> leadMinutes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateGroup")) {
      return;
    }

    await (database.update(
      database.ocptShootingDayGroupsTable,
    )..where((table) => table.id.equals(groupId) & table.isDeleted.not())).write(
      OcptShootingDayGroupsTableCompanion(label: label, leadMinutes: leadMinutes),
    );
  }

  /// Tombstones group [groupId], and **nulls the `groupId` of every crew and cast row pointing at
  /// it**, in one transaction: deleting a group leaves its members with no group rather than
  /// removing them from the day.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteGroup({required OcptProjectDatabase database, required String groupId}) async {
    if (database.refusesUserWrite("deleteGroup")) {
      return;
    }

    await database.transaction(() async {
      await (database.update(
        database.ocptShootingSlotCrewTable,
      )..where((table) => table.groupId.equals(groupId))).write(
        const OcptShootingSlotCrewTableCompanion(groupId: Value(null)),
      );
      await (database.update(
        database.ocptShootingSlotCastTable,
      )..where((table) => table.groupId.equals(groupId))).write(
        const OcptShootingSlotCastTableCompanion(groupId: Value(null)),
      );
      await (database.update(
        database.ocptShootingDayGroupsTable,
      )..where((table) => table.id.equals(groupId))).write(
        const OcptShootingDayGroupsTableCompanion(isDeleted: Value(true)),
      );
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
  /// freshly generated id of the assignment.
  ///
  /// **Seeds the new row's own lead time and group from that person's and position's most recent
  /// convocation** — see the class doc comment.
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

    return database.transaction(() async {
      final slot = await _getSlotRow(database: database, slotId: slotId);
      final day = await _getDayRow(database: database, dayId: slot.shootingDayId);

      final seed = await _seedCrewConvocation(
        database: database,
        targetDayId: slot.shootingDayId,
        screenplayId: day.screenplayId,
        personId: personId,
        positionId: positionId,
        customLabel: customLabel,
      );

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
              groupId: Value(seed.groupId),
              leadMinutes: Value(seed.leadMinutes),
              notes: Value(notes),
              sortKey: Value(
                ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
              ),
            ),
          );

      return id;
    });
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
    Value<String?> groupId = const Value.absent(),
    Value<int?> leadMinutes = const Value.absent(),
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
        groupId: groupId,
        leadMinutes: leadMinutes,
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
  /// **Seeds the new row's own lead time and group from that role's most recent convocation** —
  /// see the class doc comment.
  ///
  /// **The same role convoked twice in one slot is refused** — unlike crew, where two positions
  /// held by the same person are legitimate (see [addSlotCrewMember]): a role already convoked live
  /// in this slot has this call return that row's own id rather than create a second one. A role
  /// convoked here before and since removed has its tombstone lifted and its fields overwritten
  /// with the freshly seeded ones, exactly as `OcptLocationsService.assignSceneToSet` revives a
  /// dropped link rather than duplicating it.
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

      final slot = await _getSlotRow(database: database, slotId: slotId);
      final day = await _getDayRow(database: database, dayId: slot.shootingDayId);
      final seed = await _seedCastConvocation(
        database: database,
        targetDayId: slot.shootingDayId,
        screenplayId: day.screenplayId,
        roleId: roleId,
      );

      if (tombstoned != null) {
        await (database.update(
          database.ocptShootingSlotCastTable,
        )..where((table) => table.id.equals(tombstoned!.id))).write(
          OcptShootingSlotCastTableCompanion(
            groupId: Value(seed.groupId),
            leadMinutes: Value(seed.leadMinutes),
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
              groupId: Value(seed.groupId),
              leadMinutes: Value(seed.leadMinutes),
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
    Value<String?> groupId = const Value.absent(),
    Value<int?> leadMinutes = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSlotCastRole")) {
      return;
    }

    await (database.update(
      database.ocptShootingSlotCastTable,
    )..where((table) => table.id.equals(castRoleId) & table.isDeleted.not())).write(
      OcptShootingSlotCastTableCompanion(groupId: groupId, leadMinutes: leadMinutes, notes: notes),
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
  /// (or appended at the end when null), and returns the id of the block placing it. The day it
  /// lands on is read off [slotId]'s own row, so a block can never name a day its slot doesn't
  /// belong to.
  ///
  /// **A shot is placed at most once across the whole schedule** — see the class doc comment: if
  /// [shotId] already has a live block, this moves *that* block (to [slotId] and [atPosition])
  /// instead of creating a second one, whether or not it already sat in [slotId].
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

      final existingBlock = await _liveShotBlockRow(database: database, shotId: shotId);

      final slotBlocks =
          (await _liveBlockRowsOfSlot(database: database, slotId: slotId))
            ..removeWhere((row) => row.id == existingBlock?.id);

      final clampedPosition = atPosition == null
          ? slotBlocks.length
          : (atPosition < 0 ? 0 : (atPosition > slotBlocks.length ? slotBlocks.length : atPosition));

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? slotBlocks[clampedPosition - 1].sortKey : null,
        after: clampedPosition < slotBlocks.length ? slotBlocks[clampedPosition].sortKey : null,
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
              slotId: slotId,
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
  /// [placeShot]/[unplaceShot], block reordering/moving and [deleteBlock].
  ///
  /// **[kind] may never become [OcptShootingBlockKind.shot] here, and a block that already is one
  /// keeps it** — both refused as a no-op: setting it would either need a `shotId` this method
  /// doesn't take, or, for an existing shot block, would orphan the `shotId` it already carries,
  /// which this method does not touch. Turning a shot block into something else means unplacing the
  /// shot first ([unplaceShot]) and creating the other block afterwards ([createBlock]).
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

  /// Copies [sourceDayId]'s live groups onto [targetDayId], fresh ids and fresh `sortKey`s, labels
  /// and lead times copied verbatim — shared by [createDay] (copying the previous day's groups) and
  /// [duplicateDay] (copying the source day's own). Returns the old group id → new group id map
  /// [duplicateDay] needs to remap a copied crew/cast row's `groupId`.
  Future<Map<String, String>> _copyGroups({
    required OcptProjectDatabase database,
    required String sourceDayId,
    required String targetDayId,
  }) async {
    final sourceGroups = await _liveGroupRows(database: database, dayId: sourceDayId);
    if (sourceGroups.isEmpty) {
      return const {};
    }

    final newGroupIds = [for (var i = 0; i < sourceGroups.length; i++) const Uuid().v4()];
    final sortKeys = ocptFractionalKeySequence(sourceGroups.length);
    final newGroupIdBySourceId = <String, String>{};

    for (var i = 0; i < sourceGroups.length; i++) {
      final sourceGroup = sourceGroups[i];
      newGroupIdBySourceId[sourceGroup.id] = newGroupIds[i];

      await database
          .into(database.ocptShootingDayGroupsTable)
          .insert(
            OcptShootingDayGroupsTableCompanion.insert(
              id: newGroupIds[i],
              shootingDayId: targetDayId,
              sortKey: Value(sortKeys[i]),
              label: Value(sourceGroup.label),
              leadMinutes: Value(sourceGroup.leadMinutes),
            ),
          );
    }

    return newGroupIdBySourceId;
  }

  /// The seeded lead time and group [addSlotCrewMember] gives a fresh row for [personId] holding
  /// [positionId] (or [customLabel]) — see the class doc comment.
  Future<({String? groupId, int? leadMinutes})> _seedCrewConvocation({
    required OcptProjectDatabase database,
    required String targetDayId,
    required String screenplayId,
    required String personId,
    required String positionId,
    required String customLabel,
  }) async {
    final sourceDayIds = await _otherDayIdsMostRecentFirst(
      database: database,
      screenplayId: screenplayId,
      excludingDayId: targetDayId,
    );

    for (final sourceDayId in sourceDayIds) {
      final sourceSlotIds = (await _liveSlotRows(
        database: database,
        dayId: sourceDayId,
      )).map((row) => row.id).toList(growable: false);
      if (sourceSlotIds.isEmpty) {
        continue;
      }

      final matches =
          await (database.select(database.ocptShootingSlotCrewTable)
                ..where(
                  (table) =>
                      table.slotId.isIn(sourceSlotIds) &
                      table.isDeleted.not() &
                      table.personId.equals(personId) &
                      (positionId.isNotEmpty
                          ? table.positionId.equals(positionId)
                          : table.customLabel.equals(customLabel)),
                )
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();
      if (matches.isEmpty) {
        continue;
      }

      final source = matches.first;
      final groupId = await _matchGroupByLabel(
        database: database,
        sourceGroupId: source.groupId,
        targetDayId: targetDayId,
      );

      return (groupId: groupId, leadMinutes: source.leadMinutes);
    }

    return (groupId: null, leadMinutes: null);
  }

  /// The seeded lead time and group [addSlotCastRole] gives a fresh row for [roleId] — the cast
  /// sibling of [_seedCrewConvocation].
  Future<({String? groupId, int? leadMinutes})> _seedCastConvocation({
    required OcptProjectDatabase database,
    required String targetDayId,
    required String screenplayId,
    required String roleId,
  }) async {
    final sourceDayIds = await _otherDayIdsMostRecentFirst(
      database: database,
      screenplayId: screenplayId,
      excludingDayId: targetDayId,
    );

    for (final sourceDayId in sourceDayIds) {
      final sourceSlotIds = (await _liveSlotRows(
        database: database,
        dayId: sourceDayId,
      )).map((row) => row.id).toList(growable: false);
      if (sourceSlotIds.isEmpty) {
        continue;
      }

      final matches =
          await (database.select(database.ocptShootingSlotCastTable)
                ..where(
                  (table) =>
                      table.slotId.isIn(sourceSlotIds) &
                      table.isDeleted.not() &
                      table.roleId.equals(roleId),
                )
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();
      if (matches.isEmpty) {
        continue;
      }

      final source = matches.first;
      final groupId = await _matchGroupByLabel(
        database: database,
        sourceGroupId: source.groupId,
        targetDayId: targetDayId,
      );

      return (groupId: groupId, leadMinutes: source.leadMinutes);
    }

    return (groupId: null, leadMinutes: null);
  }

  /// The id of [targetDayId]'s own live group carrying the same label as [sourceGroupId], or null
  /// when [sourceGroupId] is itself null, no longer live, or the target day has no group with that
  /// label — see the class doc comment on [addSlotCrewMember]/[addSlotCastRole].
  Future<String?> _matchGroupByLabel({
    required OcptProjectDatabase database,
    required String? sourceGroupId,
    required String targetDayId,
  }) async {
    if (sourceGroupId == null) {
      return null;
    }

    final sourceGroup =
        await (database.select(database.ocptShootingDayGroupsTable)
              ..where((table) => table.id.equals(sourceGroupId) & table.isDeleted.not()))
            .getSingleOrNull();
    if (sourceGroup == null) {
      return null;
    }

    final targetGroups = await _liveGroupRows(database: database, dayId: targetDayId);
    for (final group in targetGroups) {
      if (group.label == sourceGroup.label) {
        return group.id;
      }
    }

    return null;
  }

  /// Every live day of [screenplayId] other than [excludingDayId], the greatest `sortKey` first —
  /// "most recent" in the plan's own order, not the calendar date.
  ///
  /// The whole list rather than only its head: the day a convocation is seeded from is the most
  /// recent one that **convoked that person or that role**, which is rarely the most recent day of
  /// the plan — an actor shooting on days 2 and 7 is convoked on neither 5 nor 6, and giving up at
  /// the first day that doesn't name them would make the seeding fire almost never.
  Future<List<String>> _otherDayIdsMostRecentFirst({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String excludingDayId,
  }) async {
    final days =
        (await _liveDayRows(database: database, screenplayId: screenplayId))
          ..removeWhere((row) => row.id == excludingDayId);

    return [for (final day in days.reversed) day.id];
  }

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

  /// Every live day row of screenplay [screenplayId], ordered by `sortKey`.
  Future<List<OcptShootingDayRow>> _liveDayRows({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => (database.select(database.ocptShootingDaysTable)
        ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// Every live group row of day [dayId], ordered by `sortKey`.
  Future<List<OcptShootingDayGroupRow>> _liveGroupRows({
    required OcptProjectDatabase database,
    required String dayId,
  }) => (database.select(database.ocptShootingDayGroupsTable)
        ..where((table) => table.shootingDayId.equals(dayId) & table.isDeleted.not())
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

  /// Every live block row of slot [slotId], ordered by `sortKey` — that slot's own timetable order.
  Future<List<OcptShootingDayBlockRow>> _liveBlockRowsOfSlot({
    required OcptProjectDatabase database,
    required String slotId,
  }) => (database.select(database.ocptShootingDayBlocksTable)
        ..where((table) => table.slotId.equals(slotId) & table.isDeleted.not())
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
