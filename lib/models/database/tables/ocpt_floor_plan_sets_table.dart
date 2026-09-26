// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_sets_table.dart';

/// The floor plan **of a Resources set** (`sets`, `docs/plans/storyboard.md`, §10): one row per
/// set, created lazily on its first write (`OcptFloorPlanService.ensurePlan`) rather than eagerly
/// for every set the resources mode holds.
///
/// [id] **is `sets.id`**, not a fresh id of its own — a deliberate departure from every other
/// table's own stable UUID. The plan is created lazily, so two replicas that each place the first
/// symbol on the very same set while offline would otherwise mint two `floor_plan_sets` rows for
/// one set; making the id deterministic (the set's own) means the sync merge converges them onto
/// **one** row instead, exactly as any other row two replicas happen to write the same way. The
/// set's own name and tab order are read off `sets` itself: a sequence's floor-plan tabs are its
/// live `scene_sets` links, nothing stored here.
@DataClassName('OcptFloorPlanSetRow')
class OcptFloorPlanSetsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptFloorPlanSetsTable}
  @override
  String get tableName => 'floor_plan_sets';

  /// The Resources set this is the plan of — see this class's own doc comment for why this, and
  /// not a fresh id, is the primary key.
  TextColumn get id => text().references(OcptSetsTable, #id)();

  /// The imported photo or plan drawn under this set's symbols, an `assets` row of kind
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
