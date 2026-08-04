// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';

/// Converts a [OcptBreakdownSceneStatus] to and from the text stored in the
/// `scene_breakdowns.status` column.
class OcptBreakdownSceneStatusConverter extends TypeConverter<OcptBreakdownSceneStatus, String> {
  /// Class constructor
  const OcptBreakdownSceneStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBreakdownSceneStatus fromSql(String fromDb) => OcptBreakdownSceneStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBreakdownSceneStatus value) => value.name;
}

/// How far the breakdown pass has got on one scene: its status, held by hand, and its notes.
///
/// One live row per scene, enforced by the service rather than by a unique index: a scene with no
/// row reads as [OcptBreakdownSceneStatus.toDo], and the row is created on the first write, never
/// eagerly for every scene the screenplay holds.
///
/// A UUID primary key with [sceneId] beside it, rather than [sceneId] itself as the key, because
/// the sync model stamps rows by primary key (`row_field_versions`), and every other synchronised
/// table in the schema follows that shape.
@DataClassName('OcptSceneBreakdownRow')
class OcptSceneBreakdownsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptSceneBreakdownsTable}
  @override
  String get tableName => 'scene_breakdowns';

  /// The stable, unique id of this row (a UUID).
  TextColumn get id => text()();

  /// The scene this breakdown status is about.
  TextColumn get sceneId => text().references(OcptScenesTable, #id)();

  /// How far the breakdown pass has got on this scene.
  // The stored literal below must match `OcptBreakdownSceneStatus.toDo.name` exactly, for the
  // reason `person_unavailabilities.slot`'s default spells out.
  TextColumn get status =>
      text().map(const OcptBreakdownSceneStatusConverter()).withDefault(const Constant('toDo'))();

  /// Free-form breakdown notes for this scene.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
