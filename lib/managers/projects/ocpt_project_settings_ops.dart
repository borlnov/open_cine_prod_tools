// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:meta/meta.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// Read and write the settings the open project keeps in its `project_info` row: the page format,
/// the currency, the minimum rest, the screenplay language, the default VAT rate and the two
/// catering prices.
///
/// Stateless, so every call takes the project it works on; a null project is the "nothing is open"
/// case each method answers on its own.
///
/// Each method answers a result: `ok` when the call ran, with no value when no project is open or
/// the setting is not recorded, and `databaseError` when the project file failed it, logged once
/// through the `logger` it is handed. A write the read-only preview refuses answers `ok` and writes
/// nothing.
abstract final class OcptProjectSettingsOps {
  /// Load the page format stored in the `currentProject`'s `project_info` table, or null if no
  /// project is currently open.
  ///
  /// This lives here (rather than in the editor's UI layer) so reading the project database stays
  /// confined to the managers/services layer.
  @useResult
  static Future<OcptDatabaseResult<OcptPageFormat>> loadCurrentProjectPageFormat({
    required OcptOpenProjectModel? project,
    required LogsHelper logger,
  }) => _load(
    "loadCurrentProjectPageFormat",
    project: project,
    logger: logger,
    pick: (info) => info?.pageFormat,
  );

  /// Update the page format stored in the `currentProject`'s `project_info` table. Does nothing if
  /// no project is currently open.
  ///
  /// This is the first write to `project_info` after the project is created: `createProject` seeds
  /// it once, and this is the only path that ever changes it afterwards.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  static Future<OcptDatabaseOutcome> saveCurrentProjectPageFormat({
    required OcptOpenProjectModel? project,
    required OcptPageFormat format,
    required LogsHelper logger,
  }) => _save(
    "saveCurrentProjectPageFormat",
    project: project,
    logger: logger,
    companion: OcptProjectInfoTableCompanion(pageFormat: Value(format)),
  );

  /// Load the ISO 4217 currency code stored in the `currentProject`'s `project_info` table, or
  /// null if no project is currently open.
  ///
  /// Modelled on [loadCurrentProjectPageFormat]: reading the project database stays confined to
  /// the managers/services layer.
  @useResult
  static Future<OcptDatabaseResult<String>> loadCurrentProjectCurrencyCode({
    required OcptOpenProjectModel? project,
    required LogsHelper logger,
  }) => _load(
    "loadCurrentProjectCurrencyCode",
    project: project,
    logger: logger,
    pick: (info) => info?.currencyCode,
  );

  /// Update the currency code stored in the `currentProject`'s `project_info` table. Does nothing
  /// if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectPageFormat]: [code] is a property of the project, not of the
  /// app, so it is written the very same way.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  static Future<OcptDatabaseOutcome> saveCurrentProjectCurrencyCode({
    required OcptOpenProjectModel? project,
    required String code,
    required LogsHelper logger,
  }) => _save(
    "saveCurrentProjectCurrencyCode",
    project: project,
    logger: logger,
    companion: OcptProjectInfoTableCompanion(currencyCode: Value(code)),
  );

  /// Load the minimum rest, in minutes, stored in the `currentProject`'s `project_info` table, or
  /// null.
  ///
  /// The two reasons for a null answer are indistinguishable here, exactly as
  /// [loadCurrentProjectCurrencyCode]'s would be if that column were nullable: no project is open,
  /// or one is and nobody has recorded a minimum for it — the column's own truthful "nobody has
  /// said" (`OcptProjectInfoTable.minimumRestMinutes`).
  @useResult
  static Future<OcptDatabaseResult<int>> loadCurrentProjectMinimumRestMinutes({
    required OcptOpenProjectModel? project,
    required LogsHelper logger,
  }) => _load(
    "loadCurrentProjectMinimumRestMinutes",
    project: project,
    logger: logger,
    pick: (info) => info?.minimumRestMinutes,
  );

  /// Update the minimum rest, in minutes, stored in the `currentProject`'s `project_info` table, or
  /// clear it when [minutes] is null — a production that decides it no longer wants to record
  /// one is as real a gesture as setting it. Does nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectCurrencyCode], with one difference the column's own nullability
  /// forces: [minutes] is written whichever it is, including null, rather than only ever holding a
  /// value the way a page format or a currency always does.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  static Future<OcptDatabaseOutcome> saveCurrentProjectMinimumRestMinutes({
    required OcptOpenProjectModel? project,
    required int? minutes,
    required LogsHelper logger,
  }) => _save(
    "saveCurrentProjectMinimumRestMinutes",
    project: project,
    logger: logger,
    companion: OcptProjectInfoTableCompanion(minimumRestMinutes: Value(minutes)),
  );

  /// Load the screenplay language stored in the `currentProject`'s `project_info` table, or null.
  ///
  /// The two reasons for a null answer are indistinguishable here, exactly as
  /// [loadCurrentProjectMinimumRestMinutes]'s are: no project is open, or one is and nobody has
  /// recorded a language for it — the column's own truthful "nobody has said"
  /// (`OcptProjectInfoTable.screenplayLanguage`).
  @useResult
  static Future<OcptDatabaseResult<OcptScreenplayLanguage>> loadCurrentProjectScreenplayLanguage({
    required OcptOpenProjectModel? project,
    required LogsHelper logger,
  }) => _load(
    "loadCurrentProjectScreenplayLanguage",
    project: project,
    logger: logger,
    pick: (info) => info?.screenplayLanguage,
  );

  /// Update the screenplay language stored in the `currentProject`'s `project_info` table, or clear
  /// it when [language] is null — a writer who decides the checker should stay off this
  /// screenplay is making as real a choice as picking one of the two bundled languages. Does
  /// nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectMinimumRestMinutes]: [language] is written whichever it is,
  /// including null, rather than only ever holding a value the way a page format or a currency
  /// always does.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  static Future<OcptDatabaseOutcome> saveCurrentProjectScreenplayLanguage({
    required OcptOpenProjectModel? project,
    required OcptScreenplayLanguage? language,
    required LogsHelper logger,
  }) => _save(
    "saveCurrentProjectScreenplayLanguage",
    project: project,
    logger: logger,
    companion: OcptProjectInfoTableCompanion(screenplayLanguage: Value(language)),
  );

  /// Load the default VAT rate, in basis points, stored in the `currentProject`'s `project_info`
  /// table, or null.
  ///
  /// The two reasons for a null answer are indistinguishable here, exactly as
  /// [loadCurrentProjectMinimumRestMinutes]'s are: no project is open, or one is and nobody has
  /// recorded a rate for it — the column's own truthful "nobody has said"
  /// (`OcptProjectInfoTable.defaultVatRateBasisPoints`).
  @useResult
  static Future<OcptDatabaseResult<int>> loadCurrentProjectDefaultVatRateBasisPoints({
    required OcptOpenProjectModel? project,
    required LogsHelper logger,
  }) => _load(
    "loadCurrentProjectDefaultVatRateBasisPoints",
    project: project,
    logger: logger,
    pick: (info) => info?.defaultVatRateBasisPoints,
  );

  /// Update the default VAT rate, in basis points, stored in the `currentProject`'s `project_info`
  /// table, or clear it when [basisPoints] is null — a production putting the rate back to "not
  /// recorded" is as real a gesture as setting it (`OcptProjectSettingsBudgetSection`'s `No rate`
  /// button). Does nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectMinimumRestMinutes]: [basisPoints] is written whichever it is,
  /// including null, rather than only ever holding a value the way a page format or a currency
  /// always does.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  static Future<OcptDatabaseOutcome> saveCurrentProjectDefaultVatRateBasisPoints({
    required OcptOpenProjectModel? project,
    required int? basisPoints,
    required LogsHelper logger,
  }) => _save(
    "saveCurrentProjectDefaultVatRateBasisPoints",
    project: project,
    logger: logger,
    companion: OcptProjectInfoTableCompanion(defaultVatRateBasisPoints: Value(basisPoints)),
  );

  /// Load the price of one meal, in cents, stored in the `currentProject`'s `project_info` table,
  /// or null — the same "nobody has said" reading [loadCurrentProjectDefaultVatRateBasisPoints]
  /// gets.
  @useResult
  static Future<OcptDatabaseResult<int>> loadCurrentProjectMealPriceCents({
    required OcptOpenProjectModel? project,
    required LogsHelper logger,
  }) => _load(
    "loadCurrentProjectMealPriceCents",
    project: project,
    logger: logger,
    pick: (info) => info?.mealPriceCents,
  );

  /// Update the price of one meal, in cents, stored in the `currentProject`'s `project_info` table,
  /// or clear it when [cents] is null. Does nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectDefaultVatRateBasisPoints]: [cents] is written whichever it is,
  /// including null.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  static Future<OcptDatabaseOutcome> saveCurrentProjectMealPriceCents({
    required OcptOpenProjectModel? project,
    required int? cents,
    required LogsHelper logger,
  }) => _save(
    "saveCurrentProjectMealPriceCents",
    project: project,
    logger: logger,
    companion: OcptProjectInfoTableCompanion(mealPriceCents: Value(cents)),
  );

  /// Load the price of the buffet, in cents, stored in the `currentProject`'s `project_info`
  /// table, or null — [loadCurrentProjectMealPriceCents]'s sibling, read the same way. **Named
  /// after the column it reads, `project_info.snackPriceCents`, kept for the schema (ADR 0007's
  /// schema-number rule); the UI names this figure the buffet, or craft services, never a snack.**
  @useResult
  static Future<OcptDatabaseResult<int>> loadCurrentProjectSnackPriceCents({
    required OcptOpenProjectModel? project,
    required LogsHelper logger,
  }) => _load(
    "loadCurrentProjectSnackPriceCents",
    project: project,
    logger: logger,
    pick: (info) => info?.snackPriceCents,
  );

  /// Update the price of the buffet, in cents, stored in the `currentProject`'s `project_info`
  /// table, or clear it when [cents] is null — [saveCurrentProjectMealPriceCents]'s sibling. See
  /// [loadCurrentProjectSnackPriceCents]'s own doc comment for why this keeps the column's name.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  static Future<OcptDatabaseOutcome> saveCurrentProjectSnackPriceCents({
    required OcptOpenProjectModel? project,
    required int? cents,
    required LogsHelper logger,
  }) => _save(
    "saveCurrentProjectSnackPriceCents",
    project: project,
    logger: logger,
    companion: OcptProjectInfoTableCompanion(snackPriceCents: Value(cents)),
  );

  /// Read the `project_info` row of [project] and answer what [pick] takes from it, or an `ok`
  /// answer without a value when no project is open, no row exists or [pick] finds nothing.
  ///
  /// A failure of the database is answered as `databaseError`, see [_guard].
  static Future<OcptDatabaseResult<T>> _load<T>(
    String operation, {
    required OcptOpenProjectModel? project,
    required LogsHelper logger,
    required T? Function(OcptProjectInfoRow? info) pick,
  }) => _guard<T>(operation, logger, () async {
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return pick(info);
  });

  /// Write [companion] to the `project_info` row of [project], unless no project is open or the
  /// read-only preview refuses a user write, both of which answer `ok` with nothing written.
  ///
  /// A failure of the database is answered as `databaseError`, see [_guard].
  static Future<OcptDatabaseOutcome> _save(
    String operation, {
    required OcptOpenProjectModel? project,
    required LogsHelper logger,
    required OcptProjectInfoTableCompanion companion,
  }) async {
    final written = await _guard<void>(operation, logger, () async {
      if (project == null || project.database.refusesUserWrite(operation)) {
        return;
      }

      await project.database.update(project.database.ocptProjectInfoTable).write(companion);
    });

    return OcptDatabaseOutcome(status: written.status, extraInfo: written.extraInfo);
  }

  /// Run [body], a read or a write called [operation], and answer what it produced, or
  /// `databaseError` when the database failed it, with the type of what failed as its
  /// `extraInfo`. The failure is logged once, here, by type.
  ///
  /// Only an [AssertionError], a mistake of the programmer, goes through.
  static Future<OcptDatabaseResult<T>> _guard<T>(
    String operation,
    LogsHelper logger,
    Future<T?> Function() body,
  ) async {
    OcptDatabaseResult<T> result;
    try {
      result = OcptDatabaseResult<T>(status: OcptDatabaseStatus.ok, value: await body());
    } catch (error, stackTrace) {
      if (error is AssertionError) {
        rethrow;
      }

      logger.e("The database failed '$operation': ${error.runtimeType}", null, stackTrace);
      result = OcptDatabaseResult<T>(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: error.runtimeType,
      );
    }

    return result;
  }
}
