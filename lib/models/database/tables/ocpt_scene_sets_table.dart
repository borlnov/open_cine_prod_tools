// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_sets_table.dart';

/// Which scene is shot in which set, many-to-many.
///
/// One scene most often means one set, but not always: a scene written as a single continuous
/// action is regularly covered in two sets — the kitchen and the courtyard it opens onto — and a
/// scene may also be shot in two candidate sets while the choice is still open. So a scene holds as
/// many links as the user gives it, and the set of them is what the schedule mode and a call sheet
/// will read.
///
/// The mode offers this link as a **suggestion** rather than filling it automatically: a scene
/// heading's location string (`INT. CUISINE - NUIT`) is normalised and matched against set and
/// location names, but `INT. CUISINE` in two different houses is two different sets, and only the
/// user knows which one a given scene means.
///
/// No `sortKey`: a scene's sets are an unordered set of answers rather than a list the user
/// reorders (a set's own scenes read back in the screenplay's order instead).
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
