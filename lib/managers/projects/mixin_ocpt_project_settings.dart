// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:meta/meta.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_settings_ops.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// The settings the open project keeps in its `project_info` row, read and written through the
/// project the manager has open.
///
/// Each read answers `ok` with no value when no project is open or nobody has recorded the
/// setting, and each write answers `ok` having written nothing when no project is open or the
/// read-only preview refuses it. A failure of the project file is answered as `databaseError`,
/// with the type of what failed as its `extraInfo`, and logged once by the step that met it.
mixin MixinOcptProjectSettings {
  /// Get the project the settings belong to, null when none is open.
  OcptOpenProjectModel? get currentProject;

  /// Get the logger the failures of the settings are written to.
  LogsHelper get settingsLogger;

  /// Load the page format stored in the [currentProject]'s `project_info` table, or null if no
  /// project is currently open.
  @useResult
  Future<OcptDatabaseResult<OcptPageFormat>> loadCurrentProjectPageFormat() =>
      OcptProjectSettingsOps.loadCurrentProjectPageFormat(
        project: currentProject,
        logger: settingsLogger,
      );

  /// Update the page format stored in the [currentProject]'s `project_info` table. Does nothing if
  /// no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> saveCurrentProjectPageFormat(OcptPageFormat format) =>
      OcptProjectSettingsOps.saveCurrentProjectPageFormat(
        project: currentProject,
        format: format,
        logger: settingsLogger,
      );

  /// Load the ISO 4217 currency code stored in the [currentProject]'s `project_info` table, or
  /// null if no project is currently open.
  @useResult
  Future<OcptDatabaseResult<String>> loadCurrentProjectCurrencyCode() =>
      OcptProjectSettingsOps.loadCurrentProjectCurrencyCode(
        project: currentProject,
        logger: settingsLogger,
      );

  /// Update the currency code stored in the [currentProject]'s `project_info` table. Does nothing
  /// if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> saveCurrentProjectCurrencyCode(String code) =>
      OcptProjectSettingsOps.saveCurrentProjectCurrencyCode(
        project: currentProject,
        code: code,
        logger: settingsLogger,
      );

  /// Load the minimum rest, in minutes, stored in the [currentProject]'s `project_info` table, or
  /// null.
  @useResult
  Future<OcptDatabaseResult<int>> loadCurrentProjectMinimumRestMinutes() =>
      OcptProjectSettingsOps.loadCurrentProjectMinimumRestMinutes(
        project: currentProject,
        logger: settingsLogger,
      );

  /// Update the minimum rest, in minutes, stored in the [currentProject]'s `project_info` table, or
  /// clear it when [minutes] is null — a production that decides it no longer wants to record
  /// one is as real a gesture as setting it. Does nothing if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> saveCurrentProjectMinimumRestMinutes(int? minutes) =>
      OcptProjectSettingsOps.saveCurrentProjectMinimumRestMinutes(
        project: currentProject,
        minutes: minutes,
        logger: settingsLogger,
      );

  /// Load the screenplay language stored in the [currentProject]'s `project_info` table, or null.
  @useResult
  Future<OcptDatabaseResult<OcptScreenplayLanguage>> loadCurrentProjectScreenplayLanguage() =>
      OcptProjectSettingsOps.loadCurrentProjectScreenplayLanguage(
        project: currentProject,
        logger: settingsLogger,
      );

  /// Update the screenplay language stored in the [currentProject]'s `project_info` table, or clear
  /// it when [language] is null — a writer who decides the checker should stay off this
  /// screenplay is making as real a choice as picking one of the two bundled languages. Does
  /// nothing if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> saveCurrentProjectScreenplayLanguage(
    OcptScreenplayLanguage? language,
  ) => OcptProjectSettingsOps.saveCurrentProjectScreenplayLanguage(
    project: currentProject,
    language: language,
    logger: settingsLogger,
  );

  /// Load the default VAT rate, in basis points, stored in the [currentProject]'s `project_info`
  /// table, or null.
  @useResult
  Future<OcptDatabaseResult<int>> loadCurrentProjectDefaultVatRateBasisPoints() =>
      OcptProjectSettingsOps.loadCurrentProjectDefaultVatRateBasisPoints(
        project: currentProject,
        logger: settingsLogger,
      );

  /// Update the default VAT rate, in basis points, stored in the [currentProject]'s `project_info`
  /// table, or clear it when [basisPoints] is null — a production putting the rate back to "not
  /// recorded" is as real a gesture as setting it (`OcptProjectSettingsBudgetSection`'s `No rate`
  /// button). Does nothing if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> saveCurrentProjectDefaultVatRateBasisPoints(int? basisPoints) =>
      OcptProjectSettingsOps.saveCurrentProjectDefaultVatRateBasisPoints(
        project: currentProject,
        basisPoints: basisPoints,
        logger: settingsLogger,
      );

  /// Load the price of one meal, in cents, stored in the [currentProject]'s `project_info` table,
  /// or null — the same "nobody has said" reading [loadCurrentProjectDefaultVatRateBasisPoints]
  /// gets.
  @useResult
  Future<OcptDatabaseResult<int>> loadCurrentProjectMealPriceCents() =>
      OcptProjectSettingsOps.loadCurrentProjectMealPriceCents(
        project: currentProject,
        logger: settingsLogger,
      );

  /// Update the price of one meal, in cents, stored in the [currentProject]'s `project_info` table,
  /// or clear it when [cents] is null. Does nothing if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> saveCurrentProjectMealPriceCents(int? cents) =>
      OcptProjectSettingsOps.saveCurrentProjectMealPriceCents(
        project: currentProject,
        cents: cents,
        logger: settingsLogger,
      );

  /// Load the price of the buffet, in cents, stored in the [currentProject]'s `project_info`
  /// table, or null — [loadCurrentProjectMealPriceCents]'s sibling, read the same way. **Named
  /// after the column it reads, `project_info.snackPriceCents`, kept for the schema (ADR 0007's
  /// schema-number rule); the UI names this figure the buffet, or craft services, never a snack.**
  @useResult
  Future<OcptDatabaseResult<int>> loadCurrentProjectSnackPriceCents() =>
      OcptProjectSettingsOps.loadCurrentProjectSnackPriceCents(
        project: currentProject,
        logger: settingsLogger,
      );

  /// Update the price of the buffet, in cents, stored in the [currentProject]'s `project_info`
  /// table, or clear it when [cents] is null — [saveCurrentProjectMealPriceCents]'s sibling. See
  /// [loadCurrentProjectSnackPriceCents]'s own doc comment for why this keeps the column's name.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> saveCurrentProjectSnackPriceCents(int? cents) =>
      OcptProjectSettingsOps.saveCurrentProjectSnackPriceCents(
        project: currentProject,
        cents: cents,
        logger: settingsLogger,
      );
}
