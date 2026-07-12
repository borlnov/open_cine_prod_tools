// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
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

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
