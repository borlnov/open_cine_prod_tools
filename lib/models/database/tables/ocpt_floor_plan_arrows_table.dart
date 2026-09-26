// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_floor_plan_sets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_floor_plan_symbols_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';

/// Converts a [OcptFloorPlanArrowKind] to and from the text stored in the
/// `floor_plan_arrows.kind` column.
class OcptFloorPlanArrowKindConverter extends TypeConverter<OcptFloorPlanArrowKind, String> {
  /// Class constructor
  const OcptFloorPlanArrowKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptFloorPlanArrowKind fromSql(String fromDb) => OcptFloorPlanArrowKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptFloorPlanArrowKind value) => value.name;
}

/// A movement or camera-move arrow drawn between two symbols of the same floor plan set.
///
/// [shotId] is **always set**, unlike `floor_plan_symbols.shotId`: an arrow is a movement, and a
/// movement belongs to a shot even when either end it connects — [fromSymbolId] or [toSymbolId] —
/// is a set-scope or scene-scope symbol (an actor walking to a door, `docs/plans/storyboard.md`,
/// §10). Removing a symbol tombstones every arrow touching it, in the same transaction.
@DataClassName('OcptFloorPlanArrowRow')
class OcptFloorPlanArrowsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptFloorPlanArrowsTable}
  @override
  String get tableName => 'floor_plan_arrows';

  /// The stable, unique id of this arrow (a UUID).
  TextColumn get id => text()();

  /// The set this arrow is drawn on.
  TextColumn get setId => text().references(OcptFloorPlanSetsTable, #id)();

  /// The shot this movement belongs to. Always set — see the class doc comment.
  TextColumn get shotId => text().references(OcptShotsTable, #id)();

  /// Whether this arrow is a movement between two symbols or a camera move.
  TextColumn get kind => text().map(const OcptFloorPlanArrowKindConverter())();

  /// The symbol this arrow starts from.
  TextColumn get fromSymbolId => text().references(OcptFloorPlanSymbolsTable, #id)();

  /// The symbol this arrow points to.
  TextColumn get toSymbolId => text().references(OcptFloorPlanSymbolsTable, #id)();

  /// The arrow's own text label, free text.
  TextColumn get label => text().withDefault(const Constant(''))();

  /// A curved arrow's bezier control point X, in **metres** — **null meaning a straight arrow**.
  /// Set alongside [ctrlYM] by bending an otherwise straight movement or camera-move arrow.
  RealColumn get ctrlXM => real().nullable()();

  /// A curved arrow's bezier control point Y, in metres. See [ctrlXM].
  RealColumn get ctrlYM => real().nullable()();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
