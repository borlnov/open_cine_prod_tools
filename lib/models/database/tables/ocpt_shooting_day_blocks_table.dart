// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_role_candidates_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_days_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slots_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// Converts a [OcptShootingBlockKind] to and from the text stored in the
/// `shooting_day_blocks.kind` column.
class OcptShootingBlockKindConverter extends TypeConverter<OcptShootingBlockKind, String> {
  /// Class constructor
  const OcptShootingBlockKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShootingBlockKind fromSql(String fromDb) => OcptShootingBlockKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShootingBlockKind value) => value.name;
}

/// One block of a shooting day's timetable, in [sortKey] order. **This is the heart of the
/// schedule mode.**
///
/// [shotId] is non-null **iff** [kind] is [OcptShootingBlockKind.shot]; [sceneId] is null on every
/// kind but [OcptShootingBlockKind.hold] and [OcptShootingBlockKind.rehearsal], where it names the
/// scene whose time is being reserved or worked; and [roleId]/[roleCandidateId] are non-null
/// **iff** [kind] is [OcptShootingBlockKind.audition] — the same discriminator idiom, three times
/// over. [durationMinutes] null on a shot block means "use that shot's `estimatedDurationMs`";
/// [label] is what a non-shot block says it is for. [anchorMinute], when set, pins this block to
/// start at exactly that minute (an offset from the day's own midnight, which may exceed 1440 — see
/// `ocpt_shooting_slots_table.dart`) rather than wherever the chain before it lands.
///
/// **A `hold` names its scene, not only its wording.** [label] has always been free text saying
/// which sequence is being held, and free text answers nobody: a convocation needs to know *which
/// roles* a held sequence calls for (ADR 0017), and only a real link can say. [sceneId] is that
/// link, and it is nullable because a production regularly blocks out time before it has settled
/// which sequence goes there — a hold with no scene names no role, exactly as it did before this
/// column existed.
///
/// **An audition names a candidate, and a rehearsal names a sequence.** [roleCandidateId] says
/// *who, for which part* — a candidacy rather than a person, two candidacies of one person being
/// two different things to see them about — and [roleId] says the part beside it, so a block reads
/// on its own without a second query. A rehearsal reuses [sceneId] rather than growing a column:
/// what is rehearsed is a sequence, which is exactly what a [OcptShootingBlockKind.hold] already
/// names. Both links are **read defensively**: a candidacy since removed, or a role since deleted,
/// leaves the block where it is and reads as nothing at all, exactly as `shooting_slot_cast` does
/// for a role deleted under it — the schedule has never held a cascade for that, and a plan that
/// silently dropped rows would be worse than one naming somebody it can no longer resolve.
///
/// **A block belongs to exactly one slot** ([slotId], non-null from schema v12 on): a day is a set
/// of parallel chains, one per slot, and a block's own chain is its slot's own, starting from that
/// slot's own `startMinute` — there is no day-wide chain any more. **How a slot's blocks chain into
/// actual clock times is stated once and implemented once**, in
/// `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015, amended) — nothing else may re-derive it.
@DataClassName('OcptShootingDayBlockRow')
class OcptShootingDayBlocksTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingDayBlocksTable}
  @override
  String get tableName => 'shooting_day_blocks';

  /// The stable, unique id of this block (a UUID).
  TextColumn get id => text()();

  /// The day this block belongs to.
  TextColumn get shootingDayId => text().references(OcptShootingDaysTable, #id)();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// Which convocation window this block sits in. Non-null from schema v12 on — see the class doc
  /// comment.
  TextColumn get slotId => text().references(OcptShootingSlotsTable, #id)();

  /// What this block is for.
  // The stored literal below must match `OcptShootingBlockKind.shot.name` exactly, for the same
  // reason `shots.status`'s default does: an enum's `.name` getter isn't a compile-time constant
  // expression, so it can't be written as `Constant(OcptShootingBlockKind.shot)`.
  TextColumn get kind =>
      text().map(const OcptShootingBlockKindConverter()).withDefault(const Constant('shot'))();

  /// The shot this block places, non-null iff [kind] is [OcptShootingBlockKind.shot].
  TextColumn get shotId => text().nullable().references(OcptShotsTable, #id)();

  /// The scene a [OcptShootingBlockKind.hold] block reserves time for, or a
  /// [OcptShootingBlockKind.rehearsal] block works, or null — either because this block is of
  /// another kind, or because the sequence hasn't been settled yet. See the class doc comment.
  TextColumn get sceneId => text().nullable().references(OcptScenesTable, #id)();

  /// The part an [OcptShootingBlockKind.audition] block sees somebody for, or null on every other
  /// kind. Non-null exactly with [roleCandidateId], both halves of one link — see the class doc
  /// comment.
  TextColumn get roleId => text().nullable().references(OcptRolesTable, #id)();

  /// The candidacy an [OcptShootingBlockKind.audition] block is about — *who, for which part* —, or
  /// null on every other kind. See the class doc comment.
  TextColumn get roleCandidateId => text().nullable().references(OcptRoleCandidatesTable, #id)();

  /// The wording of a non-shot block; for [OcptShootingBlockKind.hold], what sequence is being
  /// reserved time for. Free text, empty for a shot block.
  TextColumn get label => text().withDefault(const Constant(''))();

  /// This block's own duration in minutes, or null. For a shot block, null means "use that shot's
  /// `estimatedDurationMs`"; for any other kind, null falls back to the mode's own default.
  IntColumn get durationMinutes => integer().nullable()();

  /// The minute, from the day's own midnight, this block is pinned to start at exactly, or null
  /// while it simply follows the block before it. May exceed 1440 — see
  /// `ocpt_shooting_slots_table.dart`.
  IntColumn get anchorMinute => integer().nullable()();

  /// Free-form notes about this block. **Private, and never printed** — the call sheet and the
  /// shooting plan say nothing about it. See [crewNote] for the sibling that does.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// What this block's own row says to the crew when it prints: the sibling of
  /// `shooting_days.crewNote`, one block narrower — that one is the whole day's note, this one
  /// belongs to a single block ("the neighbours have asked for silence before 9:00", "the
  /// generator arrives during this move"). **Printed**, under the block's own row on the call
  /// sheet and in the shooting plan's day agenda, which is the whole reason it exists apart from
  /// [notes]: a field nobody had ever said would or wouldn't print was really two fields wearing
  /// one name.
  TextColumn get crewNote => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
