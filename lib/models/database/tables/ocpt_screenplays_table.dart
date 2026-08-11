// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// A row of this table **is an episode** (`docs/adr/0019-one-project-several-episodes.md`): a
/// series, a mini-series and a feature shot in two parts are one production seen from the same
/// angle — one crew, one address book, one schedule, several screenplays — and a screenplay is
/// where that "several" lives. A project created today holds a single one, numbered 1, which is
/// what a feature is; nothing in the schema stops more from being added later.
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

  /// This episode's printed number — an ordinary integer, shown beside the page wherever the
  /// episode is named, and carrying **no uniqueness constraint**. Two episodes numbered 4 is a
  /// state the user can reach by hand (mid-renumbering, or simply a mistake) and repair by hand; a
  /// constraint would refuse that intermediate state rather than help, exactly the reasoning that
  /// keeps `shots.position` unenforced after `sortKey` took over ordering. [sortKey], not this
  /// column, is what actually orders the episodes — the same split `shooting_days` already makes
  /// between its date-ranked position and its own `sortKey` tiebreaker.
  IntColumn get number => integer().withDefault(const Constant(1))();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

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
