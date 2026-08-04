// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';

/// The *dépouillement* link: which element a scene needs, and how many.
///
/// This is what turns the elements catalogue into a per-day requirements list once the schedule
/// mode exists (§6 of the plan this table ships under); the per-scene breakdown *view* itself is
/// out of scope for this step, only the link ships.
///
/// No `sortKey`: a scene's elements are a set the user adds to and removes from, not a list they
/// reorder.
@DataClassName('OcptSceneElementRow')
class OcptSceneElementsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptSceneElementsTable}
  @override
  String get tableName => 'scene_elements';

  /// The stable, unique id of this link (a UUID).
  TextColumn get id => text()();

  /// The scene this element is needed in.
  TextColumn get sceneId => text().references(OcptScenesTable, #id)();

  /// The element needed.
  TextColumn get elementId => text().references(OcptElementsTable, #id)();

  /// How many of the element this scene needs, overriding `elements.quantity` for this scene alone.
  /// A decimal number stored as text, for the same reason `elements.quantity` is.
  TextColumn get quantity => text().withDefault(const Constant(''))();

  /// Free-form notes about this scene's need for the element.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
