// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';

/// A range of a scene's text that a shot covers: the scenario coverage a shot list ties back to
/// the screenplay it films.
///
/// [startOffset] and [endOffset] are character offsets **relative to the scene's `charStart`**,
/// not to the whole document: a scene that moves because a scene above it grew keeps every range
/// it had, with no rewriting at all, since only edits *inside* the scene can disturb offsets that
/// are local to it. [coveredTextDigest] is a digest of the exact substring the range covered when
/// it was recorded, so a later reconciliation can detect whether that substring changed (or the
/// range no longer fits inside the scene at all) without keeping the substring itself around.
@DataClassName('OcptShotCoverageRow')
class OcptShotCoveragesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShotCoveragesTable}
  @override
  String get tableName => 'shot_coverages';

  /// The stable, unique id of this coverage range (a UUID).
  TextColumn get id => text()();

  /// The shot this range is covered by.
  TextColumn get shotId => text().references(OcptShotsTable, #id)();

  /// The scene this range belongs to. [startOffset]/[endOffset] are relative to this scene's
  /// `charStart`.
  TextColumn get sceneId => text().references(OcptScenesTable, #id)();

  /// The character offset, relative to the scene's `charStart`, at which this range starts.
  IntColumn get startOffset => integer()();

  /// The character offset, relative to the scene's `charStart`, one past the last character of
  /// this range.
  IntColumn get endOffset => integer()();

  /// A digest of the exact substring this range covered when it was last recorded or confirmed,
  /// used to detect staleness without storing the substring itself.
  TextColumn get coveredTextDigest => text()();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
