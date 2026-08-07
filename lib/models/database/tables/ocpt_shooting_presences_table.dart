// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_days_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';

/// Converts a [OcptPresenceCode] to and from the text stored in the `shooting_presences.code`
/// column.
class OcptPresenceCodeConverter extends TypeConverter<OcptPresenceCode, String> {
  /// Class constructor
  const OcptPresenceCodeConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptPresenceCode fromSql(String fromDb) => OcptPresenceCode.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptPresenceCode value) => value.name;
}

/// A by-hand override of one cell of the presence grid (people × days).
///
/// A row exists **only** when the user overrides what the grid would otherwise compute from that
/// day's convocations and from `person_unavailabilities`: a row's *absence* means "the computed
/// value stands", never "unknown". Written by `OcptScheduleService.setPresenceOverride` alone, and
/// joined against the computed reading by `OcptSchedulePlanSnapshot.presenceCellOf` — the presence
/// grid (`OcptSchedulePresenceGrid`, `OcptScheduleCentreView.presence`) is the one place either is
/// read from.
///
/// **No `sortKey`**: nothing orders these rows, one cell of a grid having no rank of its own.
@DataClassName('OcptShootingPresenceRow')
class OcptShootingPresencesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingPresencesTable}
  @override
  String get tableName => 'shooting_presences';

  /// The stable, unique id of this override (a UUID).
  TextColumn get id => text()();

  /// The day this override is for.
  TextColumn get shootingDayId => text().references(OcptShootingDaysTable, #id)();

  /// The person this override is for.
  TextColumn get personId => text().references(OcptPeopleTable, #id)();

  /// The presence code the user overrode this cell with.
  TextColumn get code => text().map(const OcptPresenceCodeConverter())();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
