// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_day_groups_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slots_table.dart';

/// Who holds which position during a slot.
///
/// A person holding two positions in one slot (director *and* production manager, which the
/// reference call sheets show) is **two rows**: the call sheet joins them back into one printed
/// line.
///
/// **This row's arrival and PAT band are computed, never typed** — see
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0017): the PAT band is the slot's own band, the
/// arrival is its start minus this person's resolved lead time, there being no after-offset
/// anywhere in this model (finishing later is stated as a `wrap` block). [leadMinutes]
/// is a lead time "minutes before the moment this person is needed" — hair, make-up, costume or
/// simply travel time; when null, this row inherits [groupId]'s own `shooting_day_groups.leadMinutes`
/// instead. **This row's own figure wins over its group's** when both are set.
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

  /// The `shooting_day_groups` row this assignment belongs to, or null while it belongs to none.
  /// See the class doc comment.
  TextColumn get groupId => text().nullable().references(OcptShootingDayGroupsTable, #id)();

  /// This assignment's own lead time, overriding [groupId]'s own figure, or null to use the
  /// group's — see the class doc comment.
  IntColumn get leadMinutes => integer().nullable()();

  /// Free-form notes about this assignment.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
