// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
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
/// [shotId] is non-null **iff** [kind] is [OcptShootingBlockKind.shot]. [durationMinutes] null on
/// a shot block means "use that shot's `estimatedDurationMs`"; [label] is what a non-shot block
/// says it is for, and for [OcptShootingBlockKind.hold] specifically, what sequence is being
/// reserved time for. [anchorMinute], when set, pins this block to start at exactly that minute
/// (an offset from the day's own midnight, which may exceed 1440 — see
/// `ocpt_shooting_slots_table.dart`) rather than wherever the chain before it lands.
///
/// **How a day's blocks chain into actual clock times is stated once and implemented once**, in
/// `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015) — nothing else may re-derive it.
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

  /// Which convocation window this block sits in, or null while it isn't tied to one.
  TextColumn get slotId => text().nullable().references(OcptShootingSlotsTable, #id)();

  /// What this block is for.
  // The stored literal below must match `OcptShootingBlockKind.shot.name` exactly, for the same
  // reason `shots.status`'s default does: an enum's `.name` getter isn't a compile-time constant
  // expression, so it can't be written as `Constant(OcptShootingBlockKind.shot)`.
  TextColumn get kind =>
      text().map(const OcptShootingBlockKindConverter()).withDefault(const Constant('shot'))();

  /// The shot this block places, non-null iff [kind] is [OcptShootingBlockKind.shot].
  TextColumn get shotId => text().nullable().references(OcptShotsTable, #id)();

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

  /// Free-form notes about this block.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
