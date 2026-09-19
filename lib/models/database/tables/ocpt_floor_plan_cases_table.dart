// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';

/// One décor of a sequence's floor plan — the top-down symbol-placing editor a shot list's Floor
/// plans view opens onto (`docs/plans/storyboard.md`, §1). A sequence may hold several cases, shown
/// as tabs.
///
/// A case follows its scene and nothing else: `scenes` rows are tombstoned, never dropped, and their
/// ids are stable, so a case whose scene vanished from the screenplay is simply unreachable from the
/// tree until the scene index matches it again — no orphan handling, no cascade of its own
/// (`docs/plans/storyboard.md`, §2, §8).
@DataClassName('OcptFloorPlanCaseRow')
class OcptFloorPlanCasesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptFloorPlanCasesTable}
  @override
  String get tableName => 'floor_plan_cases';

  /// The stable, unique id of this case (a UUID).
  TextColumn get id => text()();

  /// The sequence this case belongs to — a case is per sequence, so per episode for free
  /// (`docs/adr/0019-one-project-several-episodes.md`).
  TextColumn get sceneId => text().references(OcptScenesTable, #id)();

  /// The case's own name, e.g. `Kitchen`, `Hallway` — free text, prefilled from the scene heading's
  /// place but editable in the tab.
  TextColumn get name => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.sortKey}
  ///
  /// The order the case's tab takes among the sequence's other cases.
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// The imported photo or plan drawn under this case's symbols, an `assets` row of kind
  /// `floorPlanUnderlay` — null until one is imported.
  TextColumn get underlayAssetId => text().nullable().references(OcptAssetsTable, #id)();

  /// The underlay's centre X, in **metres** — null until the underlay is placed.
  RealColumn get underlayXM => real().nullable()();

  /// The underlay's centre Y, in metres. See [underlayXM].
  RealColumn get underlayYM => real().nullable()();

  /// The underlay's width, in metres. See [underlayXM].
  RealColumn get underlayWidthM => real().nullable()();

  /// The underlay's height, in metres. See [underlayXM].
  RealColumn get underlayHeightM => real().nullable()();

  /// The underlay's rotation, in degrees. See [underlayXM].
  RealColumn get underlayRotationDeg => real().nullable()();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
