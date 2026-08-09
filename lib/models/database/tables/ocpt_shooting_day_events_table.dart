// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_days_table.dart';

/// Something the day does not control, happening at an absolute hour — the village fireworks at
/// 17:00, a road closing for a parade, the tide.
///
/// [minute] is an offset from the day's own midnight and **may exceed 1440**, like every other
/// minute in this mode: see `lib/utils/ocpt_day_minute.dart`.
///
/// **This is deliberately not a `shooting_day_blocks` row, and takes no part in any slot's chain.**
/// A block belongs to one slot and pushes what follows it when it runs long
/// (`lib/utils/ocpt_shooting_day_timeline.dart`, ADR 0015); an event belongs to the day as a whole
/// and never moves anybody's schedule — the fireworks do not push a shot back, and giving this a
/// `OcptShootingBlockKind` of its own would be exactly that mistake, dressed up as a feature.
@DataClassName('OcptShootingDayEventRow')
class OcptShootingDayEventsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingDayEventsTable}
  @override
  String get tableName => 'shooting_day_events';

  /// The stable, unique id of this event (a UUID).
  TextColumn get id => text()();

  /// The day this event happens on.
  TextColumn get shootingDayId => text().references(OcptShootingDaysTable, #id)();

  /// The hour this event happens at, as an offset from the day's own midnight. May exceed 1440.
  IntColumn get minute => integer()();

  /// This event's own label ("Feu d'artifice du village", "Passage du cortège").
  TextColumn get label => text().withDefault(const Constant(''))();

  /// Free-form notes about this event.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
