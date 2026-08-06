// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slots_table.dart';

/// Who holds which position during a slot.
///
/// A person holding two positions in one slot (director *and* production manager, which the
/// reference call sheets show) is **two rows**: the call sheet joins them back into one printed
/// line. [callMinute]/[wrapMinute] are nullable **overrides** of the slot's own
/// `crewCallMinute`/`crewWrapMinute` — the reference sheets' "HORAIRES ÉQUIPE IMAGE 16:45 /
/// ÉQUIPE TECHNIQUE 18:30" is exactly this, one row called earlier than the rest of the slot,
/// rather than a second pair of slot-level columns the schema would have to decide in advance
/// which departments need.
@DataClassName('OcptShootingSlotCrewRow')
class OcptShootingSlotCrewTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingSlotCrewTable}
  @override
  String get tableName => 'shooting_slot_crew';

  /// The stable, unique id of this assignment (a UUID).
  TextColumn get id => text()();

  /// The slot this assignment is for.
  TextColumn get slotId => text().references(OcptShootingSlotsTable, #id)();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// The person holding this position during the slot.
  TextColumn get personId => text().references(OcptPeopleTable, #id)();

  /// The stable code of the position, from `ocptCrewPositions` (`lib/constants/`), or the empty
  /// string when this assignment is a free label ([customLabel]) instead of a catalogue entry.
  /// Mirrors `person_positions.positionId`.
  TextColumn get positionId => text().withDefault(const Constant(''))();

  /// A free-text position label, used instead of [positionId] when the catalogue has nothing that
  /// fits. Empty when [positionId] is set.
  TextColumn get customLabel => text().withDefault(const Constant(''))();

  /// This person's own call time for this slot, overriding `shooting_slots.crewCallMinute`, or
  /// null to use the slot's own. May exceed 1440 — see `ocpt_shooting_slots_table.dart`.
  IntColumn get callMinute => integer().nullable()();

  /// This person's own wrap time for this slot, overriding `shooting_slots.crewWrapMinute`, or
  /// null to use the slot's own. May exceed 1440 — see `ocpt_shooting_slots_table.dart`.
  IntColumn get wrapMinute => integer().nullable()();

  /// Free-form notes about this assignment.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
