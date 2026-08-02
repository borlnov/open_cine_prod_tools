// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplays_table.dart';

/// The scene index of a screenplay, one row per scene heading found by the last reconciliation.
///
/// {@template open_cine_prod_tools.OcptSceneIndexService.stability}
/// A scene's [id] is a stable UUID: `OcptSceneIndexService` reuses it across reconciliations for
/// as long as it can match the scene to one already known (see `OcptSceneIndexService.reconcile`
/// for the exact matching rules), so other tables/features can safely reference a scene by id
/// even as the screenplay is edited, reordered or renumbered.
/// {@endtemplate}
@DataClassName('OcptSceneRow')
class OcptScenesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptScenesTable}
  @override
  String get tableName => 'scenes';

  /// The stable, unique id of this scene (a UUID). {@macro open_cine_prod_tools.OcptSceneIndexService.stability}
  TextColumn get id => text()();

  /// The screenplay this scene belongs to.
  TextColumn get screenplayId => text().references(OcptScreenplaysTable, #id)();

  /// The 0-based position of this scene among the screenplay's scenes, in source order.
  IntColumn get position => integer()();

  /// The normalized scene heading text (e.g. `INT. KITCHEN - DAY`).
  TextColumn get heading => text()();

  /// The explicit scene number written in the source (e.g. `4A`), or null if none.
  TextColumn get sceneNumber => text().nullable()();

  /// The character offset, in the screenplay's Fountain text, at which this scene starts.
  IntColumn get charStart => integer()();

  /// The character offset, in the screenplay's Fountain text, one past the last character of this
  /// scene.
  IntColumn get charEnd => integer()();

  /// {@macro open_cine_prod_tools.isDeleted}
  ///
  /// This table is the one exception to that template's reasoning: `scenes` is derived from the
  /// screenplay text and is never synchronised at all (ADR 0010) — it is recomputed locally.
  /// Its rows are tombstoned all the same, because `shots.sceneId` and `shot_coverages.sceneId`
  /// reference them and those two tables *are* synchronised: a coverage row kept as a tombstone
  /// still points at its scene, so hard-deleting the scene under it would break a foreign key the
  /// schema declares and `PRAGMA foreign_keys` enforces.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
