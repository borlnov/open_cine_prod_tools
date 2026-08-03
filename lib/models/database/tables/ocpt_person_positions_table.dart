// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';

/// The crew positions a person holds on the film, assigned at **project level** rather than per
/// time slot.
///
/// The mock-up assigns positions inside the planning's per-day time slots, but the schedule mode
/// this plan defers to (§6) doesn't exist yet, so a row here instead carries [scopeNotes] — free
/// text such as "whole shoot" or "mornings only" — which the schedule mode later refines into real
/// per-slot assignments without this table changing shape.
@DataClassName('OcptPersonPositionRow')
class OcptPersonPositionsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptPersonPositionsTable}
  @override
  String get tableName => 'person_positions';

  /// The stable, unique id of this assignment (a UUID).
  ///
  /// A row isn't uniquely identified by [personId] and [positionId] alone: [positionId] is empty
  /// whenever [customLabel] is used instead, so two custom-labelled assignments for the same person
  /// would otherwise collide.
  TextColumn get id => text()();

  /// The person holding this position.
  TextColumn get personId => text().references(OcptPeopleTable, #id)();

  /// The stable code of the position, from `ocptCrewPositions` (`lib/constants/`), or the empty
  /// string when this assignment is a free label ([customLabel]) instead of a catalogue entry.
  TextColumn get positionId => text().withDefault(const Constant(''))();

  /// A free-text position label, used instead of [positionId] when the catalogue has nothing that
  /// fits. Empty when [positionId] is set.
  TextColumn get customLabel => text().withDefault(const Constant(''))();

  /// Free text describing when this assignment applies (e.g. "whole shoot", "mornings only"). Not
  /// decoration: a reference call sheet has one person on sound in the morning and another in the
  /// afternoon, and a model with no scope cannot say that until the schedule mode exists.
  TextColumn get scopeNotes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
