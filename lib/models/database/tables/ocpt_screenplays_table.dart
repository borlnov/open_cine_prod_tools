// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// The screenplays of a project, each holding its full Fountain source text.
///
/// A project is created with a single screenplay (whose title matches the project's name), but
/// the schema doesn't prevent more from being added later.
@DataClassName('OcptScreenplayRow')
class OcptScreenplaysTable extends Table {
  /// {@macro open_cine_prod_tools.OcptScreenplaysTable}
  @override
  String get tableName => 'screenplays';

  /// The unique, stable id of this screenplay (a UUID).
  TextColumn get id => text()();

  /// The display title of the screenplay.
  TextColumn get title => text()();

  /// The full Fountain source text of the screenplay.
  TextColumn get fountainText => text().withDefault(const Constant(''))();

  /// The date and time at which [fountainText] was last saved.
  DateTimeColumn get updatedAt => dateTime()();

  /// {@template open_cine_prod_tools.isDeleted}
  /// Whether this row has been deleted: a tombstone rather than a removal.
  ///
  /// Every synchronised table carries this
  /// (`docs/adr/0010-sync-ready-data-model-prerequisites.md`): a replica that was offline when a
  /// row was deleted has no way to learn it happened if the row simply vanished, and re-inserts it
  /// on the next merge. Every read path therefore filters tombstones out rather than relying on
  /// them being gone, and only a purge — once every replica has provably seen the tombstone — ever
  /// removes the row for real.
  /// {@endtemplate}
  ///
  /// No code path deletes a screenplay today; the column is here because this table is
  /// synchronised, so the day one does, it is already a tombstone.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
