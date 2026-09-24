// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_floor_plan_sets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';

/// Converts a [OcptFloorPlanLayer] to and from the text stored in the `floor_plan_symbols.layer`
/// column.
class OcptFloorPlanLayerConverter extends TypeConverter<OcptFloorPlanLayer, String> {
  /// Class constructor
  const OcptFloorPlanLayerConverter();

  /// One-cycle back-compat map from the pre-merge layer names (`decor`, `furniture`, `fixedProps`,
  /// `handProps`) a dev `.ocpt` file written before schema v4's layer merge may still hold, onto
  /// their replacement in [OcptFloorPlanLayer] — schema version 4 is still an open development
  /// cycle (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`), so the merge happens in
  /// place with no migration step of its own, and this is what lets such a file still open. Safe to
  /// drop once schema v4 ships stable, since a stable release never wrote the old names.
  static const _legacyLayerNames = {
    'decor': OcptFloorPlanLayer.set,
    'furniture': OcptFloorPlanLayer.set,
    'fixedProps': OcptFloorPlanLayer.set,
    'handProps': OcptFloorPlanLayer.props,
  };

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptFloorPlanLayer fromSql(String fromDb) =>
      _legacyLayerNames[fromDb] ?? OcptFloorPlanLayer.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptFloorPlanLayer value) => value.name;
}

/// Converts a [OcptFloorPlanSetElementShape] to and from the text stored in the
/// `floor_plan_symbols.setElementShape` column.
class OcptFloorPlanSetElementShapeConverter
    extends TypeConverter<OcptFloorPlanSetElementShape, String> {
  /// Class constructor
  const OcptFloorPlanSetElementShapeConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptFloorPlanSetElementShape fromSql(String fromDb) =>
      OcptFloorPlanSetElementShape.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptFloorPlanSetElementShape value) => value.name;
}

/// A camera, a character, a light, a set element or any other placed symbol of a floor plan set.
///
/// One table for both of the floor plan's scopes: [layer] decides the scope, and [shotId] is null
/// **exactly when** [layer] is sequence-scoped (`OcptFloorPlanLayer.isSequenceScoped`) — the
/// invariant `OcptFloorPlanService` enforces at every write (`docs/plans/storyboard.md`, §2).
///
/// A camera symbol's letter (`3A`, `3B`) and a shot layer's shot number are **never stored**: both
/// are derived at read time, the letter from this row's rank among the same shot's live cameras on
/// the same set in [sortKey] order, the number from the shot's own rank in its sequence — the house
/// rule the shot code already follows.
@DataClassName('OcptFloorPlanSymbolRow')
class OcptFloorPlanSymbolsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptFloorPlanSymbolsTable}
  @override
  String get tableName => 'floor_plan_symbols';

  /// The stable, unique id of this symbol (a UUID).
  TextColumn get id => text()();

  /// The set this symbol is placed on.
  TextColumn get setId => text().references(OcptFloorPlanSetsTable, #id)();

  /// The shot this symbol belongs to — null on a sequence layer, set on a shot layer. See the class
  /// doc comment.
  TextColumn get shotId => text().nullable().references(OcptShotsTable, #id)();

  /// Which layer this symbol is drawn on, and so which scope it belongs to.
  TextColumn get layer => text().map(const OcptFloorPlanLayerConverter())();

  /// {@macro open_cine_prod_tools.sortKey}
  ///
  /// The draw order, and — for a `OcptFloorPlanLayer.cameras` symbol — the rank its letter is
  /// derived from.
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// The symbol's centre X, in **metres**.
  RealColumn get xM => real()();

  /// The symbol's centre Y, in metres.
  RealColumn get yM => real()();

  /// The symbol's rotation, in degrees — a camera's heading, a wall's angle.
  RealColumn get rotationDeg => real().withDefault(const Constant(0))();

  /// A set element's footprint width, in metres — null on every other layer in v1. The v2
  /// per-symbol size override reuses this column with no migration (`docs/plans/storyboard.md`,
  /// §2).
  RealColumn get widthM => real().nullable()();

  /// A set element's footprint height, in metres. See [widthM].
  RealColumn get heightM => real().nullable()();

  /// A camera's field-of-view wedge, in degrees — null meaning the drawing's own default.
  RealColumn get fovDeg => real().nullable()();

  /// How far, in metres, a camera's own field-of-view wedge reaches from its lens — null meaning
  /// the drawing's own default (`ocptFloorPlanCameraFovWedgeLengthM`, 2 m). Null for every other
  /// symbol, which doesn't draw a wedge.
  RealColumn get fovReachM => real().nullable()();

  /// The text label this symbol carries, e.g. `key · 1.2k`, `SAM · stand-in`,
  /// `85mm · reverse on Sam`. A character symbol's [label] is a free text pre-filled from the
  /// shot's characters field as a convenience only — it carries no link back to a role
  /// (`docs/plans/storyboard.md`, §2).
  TextColumn get label => text().withDefault(const Constant(''))();

  /// The visual primitive a set-element (sequence-layer) symbol is drawn as — a wall, a door, a
  /// piece of furniture, or a free-hand shape. **Null for every camera, character and light
  /// symbol**, which don't use it: only a symbol on [OcptFloorPlanLayer.set] carries one.
  TextColumn get setElementShape =>
      text().nullable().map(const OcptFloorPlanSetElementShapeConverter())();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
