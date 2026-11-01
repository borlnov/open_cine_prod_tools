// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// Read and write the settings the open project keeps in its `project_info` row: the page format,
/// the currency, the minimum rest, the screenplay language, the default VAT rate and the two
/// catering prices.
///
/// Stateless, so every call takes the project it works on; a null project is the "nothing is open"
/// case each method answers on its own.
abstract final class OcptProjectSettingsOps {
  /// Load the page format stored in the `currentProject`'s `project_info` table, or null if no
  /// project is currently open.
  ///
  /// This lives here (rather than in the editor's UI layer) so reading the project database stays
  /// confined to the managers/services layer.
  static Future<OcptPageFormat?> loadCurrentProjectPageFormat({
    required OcptOpenProjectModel? project,
  }) async {
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.pageFormat;
  }

  /// Update the page format stored in the `currentProject`'s `project_info` table. Does nothing if
  /// no project is currently open.
  ///
  /// This is the first write to `project_info` after the project is created: `createProject` seeds
  /// it once, and this is the only path that ever changes it afterwards.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> saveCurrentProjectPageFormat({
    required OcptOpenProjectModel? project,
    required OcptPageFormat format,
  }) async {
    if (project == null || project.database.refusesUserWrite("saveCurrentProjectPageFormat")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(pageFormat: Value(format)));
  }

  /// Load the ISO 4217 currency code stored in the `currentProject`'s `project_info` table, or
  /// null if no project is currently open.
  ///
  /// Modelled on [loadCurrentProjectPageFormat]: reading the project database stays confined to
  /// the managers/services layer.
  static Future<String?> loadCurrentProjectCurrencyCode({
    required OcptOpenProjectModel? project,
  }) async {
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.currencyCode;
  }

  /// Update the currency code stored in the `currentProject`'s `project_info` table. Does nothing
  /// if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectPageFormat]: [code] is a property of the project, not of the
  /// app, so it is written the very same way.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> saveCurrentProjectCurrencyCode({
    required OcptOpenProjectModel? project,
    required String code,
  }) async {
    if (project == null || project.database.refusesUserWrite("saveCurrentProjectCurrencyCode")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(currencyCode: Value(code)));
  }

  /// Load the minimum rest, in minutes, stored in the `currentProject`'s `project_info` table, or
  /// null.
  ///
  /// The two reasons for a null answer are indistinguishable here, exactly as
  /// [loadCurrentProjectCurrencyCode]'s would be if that column were nullable: no project is open,
  /// or one is and nobody has recorded a minimum for it — the column's own truthful "nobody has
  /// said" (`OcptProjectInfoTable.minimumRestMinutes`).
  static Future<int?> loadCurrentProjectMinimumRestMinutes({
    required OcptOpenProjectModel? project,
  }) async {
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.minimumRestMinutes;
  }

  /// Update the minimum rest, in minutes, stored in the `currentProject`'s `project_info` table, or
  /// clear it when [minutes] is null — a production that decides it no longer wants to record
  /// one is as real a gesture as setting it. Does nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectCurrencyCode], with one difference the column's own nullability
  /// forces: [minutes] is written whichever it is, including null, rather than only ever holding a
  /// value the way a page format or a currency always does.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> saveCurrentProjectMinimumRestMinutes({
    required OcptOpenProjectModel? project,
    required int? minutes,
  }) async {
    if (project == null ||
        project.database.refusesUserWrite("saveCurrentProjectMinimumRestMinutes")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(minimumRestMinutes: Value(minutes)));
  }

  /// Load the screenplay language stored in the `currentProject`'s `project_info` table, or null.
  ///
  /// The two reasons for a null answer are indistinguishable here, exactly as
  /// [loadCurrentProjectMinimumRestMinutes]'s are: no project is open, or one is and nobody has
  /// recorded a language for it — the column's own truthful "nobody has said"
  /// (`OcptProjectInfoTable.screenplayLanguage`).
  static Future<OcptScreenplayLanguage?> loadCurrentProjectScreenplayLanguage({
    required OcptOpenProjectModel? project,
  }) async {
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.screenplayLanguage;
  }

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
  static Future<void> saveCurrentProjectScreenplayLanguage({
    required OcptOpenProjectModel? project,
    required OcptScreenplayLanguage? language,
  }) async {
    if (project == null ||
        project.database.refusesUserWrite("saveCurrentProjectScreenplayLanguage")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(screenplayLanguage: Value(language)));
  }

  /// Load the default VAT rate, in basis points, stored in the `currentProject`'s `project_info`
  /// table, or null.
  ///
  /// The two reasons for a null answer are indistinguishable here, exactly as
  /// [loadCurrentProjectMinimumRestMinutes]'s are: no project is open, or one is and nobody has
  /// recorded a rate for it — the column's own truthful "nobody has said"
  /// (`OcptProjectInfoTable.defaultVatRateBasisPoints`).
  static Future<int?> loadCurrentProjectDefaultVatRateBasisPoints({
    required OcptOpenProjectModel? project,
  }) async {
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.defaultVatRateBasisPoints;
  }

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
  static Future<void> saveCurrentProjectDefaultVatRateBasisPoints({
    required OcptOpenProjectModel? project,
    required int? basisPoints,
  }) async {
    if (project == null ||
        project.database.refusesUserWrite("saveCurrentProjectDefaultVatRateBasisPoints")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(defaultVatRateBasisPoints: Value(basisPoints)));
  }

  /// Load the price of one meal, in cents, stored in the `currentProject`'s `project_info` table,
  /// or null — the same "nobody has said" reading [loadCurrentProjectDefaultVatRateBasisPoints]
  /// gets.
  static Future<int?> loadCurrentProjectMealPriceCents({
    required OcptOpenProjectModel? project,
  }) async {
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.mealPriceCents;
  }

  /// Update the price of one meal, in cents, stored in the `currentProject`'s `project_info` table,
  /// or clear it when [cents] is null. Does nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectDefaultVatRateBasisPoints]: [cents] is written whichever it is,
  /// including null.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> saveCurrentProjectMealPriceCents({
    required OcptOpenProjectModel? project,
    required int? cents,
  }) async {
    if (project == null || project.database.refusesUserWrite("saveCurrentProjectMealPriceCents")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(mealPriceCents: Value(cents)));
  }

  /// Load the price of the buffet, in cents, stored in the `currentProject`'s `project_info`
  /// table, or null — [loadCurrentProjectMealPriceCents]'s sibling, read the same way. **Named
  /// after the column it reads, `project_info.snackPriceCents`, kept for the schema (ADR 0007's
  /// schema-number rule); the UI names this figure the buffet, or craft services, never a snack.**
  static Future<int?> loadCurrentProjectSnackPriceCents({
    required OcptOpenProjectModel? project,
  }) async {
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.snackPriceCents;
  }

  /// Update the price of the buffet, in cents, stored in the `currentProject`'s `project_info`
  /// table, or clear it when [cents] is null — [saveCurrentProjectMealPriceCents]'s sibling. See
  /// [loadCurrentProjectSnackPriceCents]'s own doc comment for why this keeps the column's name.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> saveCurrentProjectSnackPriceCents({
    required OcptOpenProjectModel? project,
    required int? cents,
  }) async {
    if (project == null || project.database.refusesUserWrite("saveCurrentProjectSnackPriceCents")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(snackPriceCents: Value(cents)));
  }
}
