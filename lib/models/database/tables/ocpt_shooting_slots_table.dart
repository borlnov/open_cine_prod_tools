// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_locations_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_sets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_days_table.dart';

/// A convocation window inside a day — the *créneau* the reference call sheets print. A day has at
/// least one; the second reference call sheet has two, with different crews, different locations
/// and different call times.
///
/// [locationId] and [setId] are both nullable and independent of any other slot of the same day:
/// nothing here forces every slot of a day to share a location.
///
/// **[crewCallMinute]/[crewWrapMinute]/[castCallMinute]/[castWrapMinute] may exceed 1440.** A
/// night slot running 19:00 → 03:00 stores `1140` → `1620`: the value is an offset from the day's
/// own midnight, nothing is ever taken modulo anything, and every formatter and comparison reads
/// it that way — see `lib/utils/ocpt_day_minute.dart`, the single place that renders one. This is
/// written down because getting it wrong only shows up on the one night shoot of a production.
///
/// The reference call sheets' "HORAIRES ÉQUIPE IMAGE 16:45 / HORAIRES ÉQUIPE TECHNIQUE 18:30" is
/// **not** a second pair of columns here: it is two people called earlier than the slot's own
/// [crewCallMinute], which `shooting_slot_crew`'s per-person overrides express without this schema
/// ever having to decide in advance which departments a production splits.
@DataClassName('OcptShootingSlotRow')
class OcptShootingSlotsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingSlotsTable}
  @override
  String get tableName => 'shooting_slots';

  /// The stable, unique id of this slot (a UUID).
  TextColumn get id => text()();

  /// The day this slot belongs to.
  TextColumn get shootingDayId => text().references(OcptShootingDaysTable, #id)();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// This slot's own label ("Matin", "Nuit"), free text — printed on the call sheet as the name of
  /// the convocation window.
  TextColumn get label => text().withDefault(const Constant(''))();

  /// The location this slot is shot at, or null while none is chosen.
  TextColumn get locationId => text().nullable().references(OcptLocationsTable, #id)();

  /// The set (décor) this slot is shot at, or null while none is chosen. Its own
  /// `sets.locationId` must be [locationId].
  TextColumn get setId => text().nullable().references(OcptSetsTable, #id)();

  /// The minute, from the day's own midnight, at which the crew is called for this slot. May
  /// exceed 1440 — see the class doc comment.
  IntColumn get crewCallMinute => integer()();

  /// The minute, from the day's own midnight, at which the crew wraps for this slot. May exceed
  /// 1440 — see the class doc comment.
  IntColumn get crewWrapMinute => integer()();

  /// The default start of this slot's cast *PAT* (ready-to-shoot) band, or null while none is set.
  /// Any `shooting_slot_cast` row may override it for its own role.
  IntColumn get castCallMinute => integer().nullable()();

  /// The default end of this slot's cast *PAT* band, or null while none is set. Any
  /// `shooting_slot_cast` row may override it for its own role.
  IntColumn get castWrapMinute => integer().nullable()();

  /// Free-form notes about this slot.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
