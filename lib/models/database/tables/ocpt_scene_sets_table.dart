// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_sets_table.dart';

/// Which scene is shot in which set, many-to-one.
///
/// The mode offers this link as a **suggestion** rather than filling it automatically: a scene
/// heading's location string (`INT. CUISINE - NUIT`) is normalised and matched against set and
/// location names, but `INT. CUISINE` in two different houses is two different sets, and only the
/// user knows which one a given scene means.
///
/// No `sortKey`: a scene's sets (in practice, at most one) are not a list the user reorders.
@DataClassName('OcptSceneSetRow')
class OcptSceneSetsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptSceneSetsTable}
  @override
  String get tableName => 'scene_sets';

  /// The stable, unique id of this link (a UUID).
  TextColumn get id => text()();

  /// The scene this link is for.
  TextColumn get sceneId => text().references(OcptScenesTable, #id)();

  /// The set this scene is shot in.
  TextColumn get setId => text().references(OcptSetsTable, #id)();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
