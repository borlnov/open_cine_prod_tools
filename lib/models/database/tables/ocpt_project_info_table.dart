// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_versions_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The currency a project counts in until somebody says otherwise: the column's own SQL default,
/// what an existing project is migrated to, and the fallback `OcptProjectsManager` seeds a new one
/// with when the device locale gives `intl` no better guess.
///
/// A top-level constant rather than a static of [OcptProjectInfoTable]: drift copies a column's
/// `defaultValue` verbatim into the generated table class, and a static inherited from the table it
/// generates against cannot be named unqualified there.
const String ocptDefaultCurrencyCode = 'EUR';

/// Converts a [OcptPageFormat] to and from the text stored in the `project_info.pageFormat`
/// column.
class OcptPageFormatConverter extends TypeConverter<OcptPageFormat, String> {
  /// Class constructor
  const OcptPageFormatConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptPageFormat fromSql(String fromDb) => OcptPageFormat.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptPageFormat value) => value.name;
}

/// The single-row table holding the project-wide metadata of an Open Cine Prod Tools project.
///
/// There is always exactly one row in this table, with [id] always equal to 1: it isn't a
/// per-entity table like the others, it's a key/value-ish header for the whole `.ocpt` file.
@DataClassName('OcptProjectInfoRow')
class OcptProjectInfoTable extends Table {
  /// {@macro open_cine_prod_tools.OcptProjectInfoTable}
  @override
  String get tableName => 'project_info';

  /// The row id, always 1: this table only ever holds a single row.
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// The display name of the project.
  TextColumn get name => text()();

  /// The date and time at which the project was created.
  DateTimeColumn get createdAt => dateTime()();

  /// The version of Open Cine Prod Tools that created this project file.
  TextColumn get appVersionAtCreation => text()();

  /// The physical page format used to paginate this project's screenplays.
  TextColumn get pageFormat => text().map(const OcptPageFormatConverter())();

  /// The ISO 4217 code of the currency this project counts its costs in (e.g. `EUR`, `USD`).
  ///
  /// A property of the **project**, not of the app: a production shot in France and one shot in
  /// the US count their costs in different currencies, and that fact has to travel inside the
  /// `.ocpt` file itself so a colleague opening it on another machine sees the same figures read
  /// the same way. This is the same reasoning that keeps [pageFormat] here rather than in
  /// `OcptPropertiesManager` — unlike the page **margins**, an app-wide rendering preference with
  /// nothing to do with any one project.
  TextColumn get currencyCode => text().withDefault(const Constant(ocptDefaultCurrencyCode))();

  /// Free-form project settings, stored as a JSON object, or null if there are none yet.
  TextColumn get settingsJson => text().nullable()();

  /// The project version the working copy descends from, or null in a project which never had one.
  ///
  /// This is what tells the `Versions` panel which of its cards is the current one: it is set when
  /// a version is created and when one is restored, and cleared when the version it points at is
  /// deleted. Like [OcptProjectVersionsTable] itself, it is **local and never synchronised** — a
  /// restore performed on one machine must not silently move another machine's pointer.
  TextColumn get currentVersionId =>
      text().nullable().references(OcptProjectVersionsTable, #id)();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
