// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';

/// One imported frame of a shot's storyboard, ordered among the shot's other panels.
///
/// A shot holds **0..N** of these — a deliberate divergence from "one frame per shot"
/// (`docs/plans/storyboard.md`, §1, §8/ADR 0031): a shot's action rarely fits one drawing, and a
/// pan, a push-in or an actor crossing the frame each need a key frame of their own.
///
/// [imageAssetId] is nullable so a panel **outlives its image**: replacing it tombstones the old
/// `assets` row, mints a new one and re-points this column, while the panel's own [id] — what its
/// `storyboard_annotations` and a version payload refer to — never changes. The panel's rank (`1/2`,
/// `2/2` on the board) is a read-time count off [sortKey], exactly as a shot's own code is.
@DataClassName('OcptStoryboardPanelRow')
class OcptStoryboardPanelsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptStoryboardPanelsTable}
  @override
  String get tableName => 'storyboard_panels';

  /// The stable, unique id of this panel (a UUID).
  TextColumn get id => text()();

  /// The shot this panel belongs to.
  TextColumn get shotId => text().references(OcptShotsTable, #id)();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// The panel's frame, an `assets` row of kind `storyboardPanelImage` — null while no image has
  /// been imported yet, or after one was removed without a replacement.
  TextColumn get imageAssetId => text().nullable().references(OcptAssetsTable, #id)();

  /// The free comment shown under the frame. No start/end captions — a single comment per panel
  /// (`docs/plans/storyboard.md`, §1).
  TextColumn get comment => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
