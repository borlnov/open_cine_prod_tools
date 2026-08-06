// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_days_table.dart';

/// A named lead time a shooting day carries, that any convocation of that day — crew and cast
/// alike — may point at.
///
/// A group is deliberately **not** the crew department: a department says which trade someone
/// practises, a group says who walks in at the same time, and the two only coincide by accident —
/// "figurants" is a bag of `extra` roles, "équipe technique" a bag of people, and both are the same
/// idea here (`docs/plans/schedule-slots-and-computed-convocations.md` §2.3).
///
/// A group lives on the **day**, because [leadMinutes] does: the same crew called at 06:00 on a
/// January exterior is called at 09:00 in a studio. `OcptScheduleService.createDay` copies the
/// previous day's groups (labels and figures alike) onto every new day it appends, and
/// `OcptScheduleService.deleteGroup` leaves a group's members with no group rather than removing
/// them from the day — see `docs/adr/0017-convocations-computed-from-the-slot-chain.md`.
@DataClassName('OcptShootingDayGroupRow')
class OcptShootingDayGroupsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingDayGroupsTable}
  @override
  String get tableName => 'shooting_day_groups';

  /// The stable, unique id of this group (a UUID).
  TextColumn get id => text()();

  /// The day this group belongs to.
  TextColumn get shootingDayId => text().references(OcptShootingDaysTable, #id)();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// This group's own label ("Figuration", "Équipe technique"), free text.
  TextColumn get label => text().withDefault(const Constant(''))();

  /// How many minutes before the moment a member of this group is needed they have to be there —
  /// the fact a `shooting_slot_crew`/`shooting_slot_cast` row inherits unless its own
  /// `leadMinutes` overrides it.
  IntColumn get leadMinutes => integer().withDefault(const Constant(0))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
