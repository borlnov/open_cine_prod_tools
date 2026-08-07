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
/// line.
///
/// **This row's arrival and PAT band are computed, never typed** — see
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0018): a person is convoked by being linked to
/// a slot, and every figure about them (arrival, PAT band, departure) is read off every live slot
/// of the day this row's own [slotId] is one of, joined with every other slot the same person is
/// linked to. Nothing here says "how long before" any more — a production that wants somebody
/// there earlier creates the slot that says so (a make-up call, a rigging call) and links them to
/// it, rather than typing a lead time beside an ordinary convocation.
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

  /// Free-form notes about this assignment.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
