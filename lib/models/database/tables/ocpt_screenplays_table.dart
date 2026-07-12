// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
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

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
