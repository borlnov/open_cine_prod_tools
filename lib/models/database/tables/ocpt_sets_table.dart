// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_locations_table.dart';

/// A set ("décor") inside a location: a location scouted once (a house) commonly holds several
/// sets a screenplay's scenes are shot in ("Hangar", "Jardin", "Escalier", "Cuisine" of the same
/// house), which is the structure the reference sheets already keep.
@DataClassName('OcptSetRow')
class OcptSetsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptSetsTable}
  @override
  String get tableName => 'sets';

  /// The stable, unique id of this set (a UUID).
  TextColumn get id => text()();

  /// The location this set belongs to.
  TextColumn get locationId => text().references(OcptLocationsTable, #id)();

  /// The short code a breakdown margin has room for (e.g. `A`, `B`), free text, empty until
  /// assigned.
  TextColumn get code => text().withDefault(const Constant(''))();

  /// The set's display name (e.g. "Cuisine").
  TextColumn get name => text()();

  /// Free-form notes about this set.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
