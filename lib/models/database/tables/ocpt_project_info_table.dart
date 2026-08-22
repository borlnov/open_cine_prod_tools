// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_versions_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

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

/// Converts a [OcptScreenplayLanguage] to and from the text stored in the
/// `project_info.screenplayLanguage` column.
class OcptScreenplayLanguageConverter extends TypeConverter<OcptScreenplayLanguage, String> {
  /// Class constructor
  const OcptScreenplayLanguageConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptScreenplayLanguage fromSql(String fromDb) => OcptScreenplayLanguage.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptScreenplayLanguage value) => value.name;
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

  /// The minimum rest, in minutes, this production says it owes between two shooting days, or
  /// null.
  ///
  /// **Nullable, and deliberately not defaulted to 660** (the eleven hours French law sets): this
  /// app ships in more than one country, and a default would be it advancing a legal figure nobody
  /// here validated — the whole reason the column exists at all rather than a constant the rest
  /// alert compares every gap against. Null means "nobody has recorded a minimum", never "any rest
  /// is enough", and the alert that reads it (a coming milestone) stays silent when it is null,
  /// exactly as `people.maxDailyPresenceMinutes` and a location declaring no availability window
  /// already do.
  IntColumn get minimumRestMinutes => integer().nullable()();

  /// The language this project's screenplays are **written** in ([OcptScreenplayLanguage]), or
  /// null.
  ///
  /// A property of the **project**, not of the app — the same reasoning [currencyCode] carries: a
  /// screenplay written in French stays French on a colleague's machine running the app in
  /// English, so the fact has to travel inside the `.ocpt` file itself rather than live in
  /// `OcptPropertiesManager` next to a rendering preference with nothing to do with any one
  /// project.
  ///
  /// **Nullable on purpose.** Null means "nobody has said", exactly the reading
  /// [minimumRestMinutes]'s own doc comment gives its own null: it is what a project created before
  /// this column existed reads as, and it is also the honest answer for a screenplay written in a
  /// language this app carries no dictionary for — there is no guess worth making on its behalf,
  /// only an off switch worth offering. Nothing is spell-checked while this is null.
  TextColumn get screenplayLanguage =>
      text().nullable().map(const OcptScreenplayLanguageConverter())();

  /// The default VAT rate the budget mode applies to a line that doesn't override it, in basis
  /// points (550 for 5.5 %), or null.
  ///
  /// **Nullable, and deliberately not defaulted to any rate**: this app ships in more than one
  /// country, so no single figure could be a rate anybody here validated — the same reasoning
  /// [minimumRestMinutes] already carries. Null means "nobody has recorded a rate", never "no VAT
  /// applies" — that second fact is an explicit **0** a project or a line can state just as well
  /// (`OcptBudgetLinesTable.vatRateBasisPoints`'s own doc comment), and the two are different facts
  /// with different totals. A new project is born with this null, and the excluding-tax and VAT
  /// figures the budget mode shows are then simply empty, exactly as `minimumRestMinutes`'s own
  /// rest alert stays silent when it is null.
  IntColumn get defaultVatRateBasisPoints => integer().nullable()();

  /// The price of one meal, in cents, the budget mode's catering view charges per head, or null.
  ///
  /// Nullable for the reason [defaultVatRateBasisPoints] is: no figure here would be one this app
  /// could validate on the production's behalf, so null means "nobody has recorded a price" and the
  /// catering view (a coming milestone) stays silent for a day it cannot cost, rather than
  /// advancing a price nobody typed.
  IntColumn get mealPriceCents => integer().nullable()();

  /// The price of one snack, in cents, the budget mode's catering view charges per head, or null —
  /// [mealPriceCents]'s sibling, read the same way and for the same reason.
  IntColumn get snackPriceCents => integer().nullable()();

  /// Whether the budget mode's header currently shows the simplified view rather than the
  /// detailed one, or null.
  ///
  /// **Nullable, and deliberately not defaulted to either reading**: the toggle used to live in
  /// memory alone, so every close of the project lost the choice, and a fresh default of `false`
  /// here would silently reintroduce that same loss the moment a project is opened for the first
  /// time under this column, printing detailed while claiming somebody chose it. Null means
  /// "nobody has ever chosen", exactly the reading [minimumRestMinutes] already carries, and the
  /// budget mode opens **detailed** for it — precisely what it already does today, before this
  /// column existed at all.
  BoolColumn get isBudgetSimplified => boolean().nullable()();

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
