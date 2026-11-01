// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_file_compatibility_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:uuid/uuid.dart';

/// Creates a project file and opens an existing one, and decides whether a file's format lets it be
/// opened at all.
///
/// Stateless: the manager keeps the "busy" guard around each call and owns the open project, which
/// these methods report through `onCreated` / `onOpened` at the point the old behaviour set it.
abstract final class OcptProjectOpenOps {
  /// Creates a new project named [name] at [filePath], seeds it with a single empty screenplay —
  /// episode 1 (`number: 1`), given a real first `sortKey` rather than left at the column
  /// defaults, so a project made today looks exactly like one that came through the schema version
  /// 18 migration (`docs/adr/0019-one-project-several-episodes.md`) — registers it in the recent
  /// projects list, and makes it the `OcptProjectsManager.currentProject`.
  ///
  /// **Never overwrites an existing file.** If [filePath] is already taken, nothing is created,
  /// nothing is touched — not even the currently open project, which stays open — and this returns
  /// [OcptProjectStatus.fileAlreadyExists]. A caller normally avoids that outcome by resolving
  /// [filePath] through `freeNewProjectFilePath` first; the check stands here on its own so that no
  /// caller, present or future, can make this method destroy a file.
  ///
  /// If a project is already open and [filePath] is free, the open one is closed first. The
  /// project's page format defaults to [OcptPageFormat.a4] when the platform's locale is French,
  /// and to [OcptPageFormat.usLetter] otherwise. Its currency defaults to whatever `intl` names for
  /// the platform's current locale (`fr_FR` suggests EUR, `en_US` suggests USD…), falling back to
  /// [ocptDefaultCurrencyCode] when it can't. Its screenplay language is seeded from the **app's**
  /// own UI language instead ([_defaultScreenplayLanguageForAppLocale]), and left unset when no
  /// dictionary is bundled for it.
  static Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> createProject({
    required String name,
    required String filePath,
    required OcptOpenProjectModel? currentProject,
    required String appVersion,
    required String Function() appLanguageCode,
    required LogsHelper logger,
    required OcptPropertiesManager propertiesManager,
    required void Function(OcptOpenProjectModel project) onCreated,
    required Future<void> Function() closeCurrentProject,
    required Future<void> Function(String directoryPath) rememberProjectsDirectory,
  }) async {
    OcptProjectDatabase? database;
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        return const ResultWithStatus(status: OcptProjectStatus.fileAlreadyExists);
      }

      if (currentProject != null) {
        await closeCurrentProject();
      }

      await file.parent.create(recursive: true);

      database = OcptProjectDatabase(file);

      final now = DateTime.now();
      await database
          .into(database.ocptProjectInfoTable)
          .insert(
            OcptProjectInfoTableCompanion.insert(
              name: name,
              createdAt: now,
              appVersionAtCreation: appVersion,
              pageFormat: _defaultPageFormatForPlatformLocale(),
              currencyCode: Value(_defaultCurrencyCodeForPlatformLocale()),
              screenplayLanguage: Value(_defaultScreenplayLanguageForAppLocale(appLanguageCode)),
              migratedByAppVersion: Value(appVersion),
            ),
          );

      final screenplayId = const Uuid().v4();
      await database
          .into(database.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: screenplayId,
              title: name,
              updatedAt: now,
              number: const Value(1),
              sortKey: Value(ocptFractionalKeyBetween()),
            ),
          );

      final project = OcptOpenProjectModel(
        path: filePath,
        name: name,
        primaryScreenplayId: screenplayId,
        database: database,
      );
      onCreated(project);

      await propertiesManager.addRecentProject(
        // A fresh project holds exactly one episode — no need to read it back.
        OcptRecentProjectModel(path: filePath, name: name, lastOpenedAt: now, episodeCount: 1),
      );
      await rememberProjectsDirectory(p.dirname(filePath));

      logger.i("A project was created: $screenplayId");

      return ResultWithStatus(status: OcptProjectStatus.ok, value: project);
    } catch (error, stackTrace) {
      logger.e(
        "A problem occurred when tried to create a project: ${error.runtimeType}",
        null,
        stackTrace,
      );
      await database?.close();
      return const ResultWithStatus(status: OcptProjectStatus.ioError);
    }
  }

  /// Opens the project stored at [filePath], registers it in the recent projects list, and makes
  /// it the `OcptProjectsManager.currentProject`.
  ///
  /// If a project is already open, it's closed first — but only once the file's own format has been
  /// read and accepted, so a refusal never costs the user the project they already had open.
  ///
  /// **A file written by another build never opens silently.** It is probed first
  /// (`OcptProjectsManager.probeProjectFile`), and:
  /// - a **newer** format is refused with [OcptProjectStatus.newerFormat]: it isn't opened, isn't
  ///   touched and doesn't reach the recent projects list. Handing it to drift would stamp its
  ///   `user_version` back down to this build's number while leaving the newer build's tables in
  ///   place, which is not a failure the user could ever undo;
  /// - a file at this build's own schema, but last written by a **pre-release build that isn't
  ///   this exact build**, is refused the same way, with [OcptProjectStatus.foreignDevBuildFormat]:
  ///   its shape isn't guaranteed to match the frozen release
  ///   (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`);
  /// - an **older** format returns [OcptProjectStatus.migrationRequired] unless [allowMigration] is
  ///   true, which is the caller saying the user has been told what is about to happen. Only then
  ///   is the copy written — at the path the probe named, so the promise and the write cannot drift
  ///   apart — and the file handed to drift, whose `onUpgrade` migrates it as it always has;
  /// - anything else opens exactly as it did before this gate existed.
  static Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> openProject({
    required String filePath,
    required bool allowMigration,
    required OcptOpenProjectModel? currentProject,
    required String appVersion,
    required LogsHelper logger,
    required OcptPropertiesManager propertiesManager,
    required OcptProjectFileCompatibilityService projectFileCompatibilityService,
    required OcptScreenplayService screenplayService,
    required OcptProjectFileCompatibility Function({required String filePath}) probeProjectFile,
    required void Function(OcptOpenProjectModel project) onOpened,
    required Future<void> Function() closeCurrentProject,
  }) async {
    OcptProjectDatabase? database;
    try {
      if (!File(filePath).existsSync()) {
        return const ResultWithStatus(status: OcptProjectStatus.fileNotFound);
      }

      final formatGate = _gateOnFileFormat(
        filePath: filePath,
        allowMigration: allowMigration,
        logger: logger,
        probeProjectFile: probeProjectFile,
        projectFileCompatibilityService: projectFileCompatibilityService,
      );
      if (formatGate.status != null) {
        return ResultWithStatus(status: formatGate.status!);
      }

      if (currentProject != null) {
        await closeCurrentProject();
      }

      database = OcptProjectDatabase(File(filePath));

      final info = await database.select(database.ocptProjectInfoTable).getSingleOrNull();
      final screenplay = await (database.select(
        database.ocptScreenplaysTable,
      )..limit(1)).getSingleOrNull();

      if (info == null || screenplay == null) {
        logger.w(
          "A project file is missing its project info or its "
          "screenplay, it's considered corrupted",
        );
        await database.close();
        return const ResultWithStatus(status: OcptProjectStatus.corruptedFile);
      }

      // Stamp the writer identity only when a real migration just ran (the file was `older`, and
      // drift's `onUpgrade` has now brought it up to `currentSchemaVersion` through the query
      // above). A plain open of an already-current file must NOT touch this column: doing so would
      // lose the freeze guarantee ADR 0029 relies on — that a file at the build's own stable schema
      // still names the stable build that actually produced its shape, not whichever later build
      // happened to open it since.
      if (formatGate.isMigrating) {
        await database
            .update(database.ocptProjectInfoTable)
            .write(OcptProjectInfoTableCompanion(migratedByAppVersion: Value(appVersion)));
      }

      final project = OcptOpenProjectModel(
        path: filePath,
        name: info.name,
        primaryScreenplayId: screenplay.id,
        database: database,
      );
      onOpened(project);

      await screenplayService.snapshotOnProjectOpen(
        database: database,
        screenplayId: screenplay.id,
      );

      final episodeCount = (await screenplayService.loadEpisodes(database: database)).length;

      await propertiesManager.addRecentProject(
        OcptRecentProjectModel(
          path: filePath,
          name: info.name,
          lastOpenedAt: DateTime.now(),
          episodeCount: episodeCount,
        ),
      );

      logger.i("A project was opened: ${screenplay.id}, $episodeCount episode(s)");

      return ResultWithStatus(status: OcptProjectStatus.ok, value: project);
    } on SqliteException catch (error, stackTrace) {
      logger.e("A project file appears corrupted: ${error.runtimeType}", null, stackTrace);
      await database?.close();
      return const ResultWithStatus(status: OcptProjectStatus.corruptedFile);
    } catch (error, stackTrace) {
      logger.e(
        "A problem occurred when tried to open a project: ${error.runtimeType}",
        null,
        stackTrace,
      );
      await database?.close();
      return const ResultWithStatus(status: OcptProjectStatus.ioError);
    }
  }

  /// Answers whether the file at [filePath] may be handed to drift, and takes the backup when a
  /// migration is going ahead: `status` is null to go on, or the status to report back instead;
  /// `isMigrating` tells `OcptProjectsManager.openProject` whether drift is about to run a real
  /// `onUpgrade` on this file, which is what decides whether the writer identity gets stamped once
  /// it has.
  ///
  /// Split out of `OcptProjectsManager.openProject` because it is the one part of opening a project
  /// that must happen **before anything else does** — before the currently open project is closed,
  /// and before drift ever sees the file.
  static ({OcptProjectStatus? status, bool isMigrating}) _gateOnFileFormat({
    required String filePath,
    required bool allowMigration,
    required LogsHelper logger,
    required OcptProjectFileCompatibility Function({required String filePath}) probeProjectFile,
    required OcptProjectFileCompatibilityService projectFileCompatibilityService,
  }) {
    final compatibility = probeProjectFile(filePath: filePath);

    switch (compatibility.verdict) {
      case OcptProjectFileVerdict.newer:
        logger.w(
          "A project file is in format "
          "${compatibility.fileSchemaVersion}, which this build (format "
          "${compatibility.appSchemaVersion}) can't read: it's refused, not opened",
        );
        return (status: OcptProjectStatus.newerFormat, isMigrating: false);
      case OcptProjectFileVerdict.foreignDevBuild:
        logger.w(
          "A project file is at this build's own format "
          "(${compatibility.fileSchemaVersion}), but was last written by "
          "${compatibility.migratedByAppVersion}, a pre-release build that isn't this one: it's "
          "refused, not opened",
        );
        return (status: OcptProjectStatus.foreignDevBuildFormat, isMigrating: false);
      case OcptProjectFileVerdict.older:
        final backupPath = compatibility.suggestedBackupPath;
        if (!allowMigration || backupPath == null) {
          return (status: OcptProjectStatus.migrationRequired, isMigrating: false);
        }

        if (!projectFileCompatibilityService.writeBackup(
          filePath: filePath,
          backupPath: backupPath,
        )) {
          // The migration is irreversible, and it was allowed on the promise that a copy would be
          // kept: no copy, no migration.
          return (status: OcptProjectStatus.ioError, isMigrating: false);
        }

        logger.i(
          "A project file is being migrated from format "
          "${compatibility.fileSchemaVersion} to ${compatibility.appSchemaVersion}; a copy of "
          "it was kept",
        );
        return (status: null, isMigrating: true);
      case OcptProjectFileVerdict.current:
      case OcptProjectFileVerdict.unreadable:
        return (status: null, isMigrating: false);
    }
  }

  /// Returns the default [OcptPageFormat] for a newly created project, based on the platform's
  /// current locale: [OcptPageFormat.a4] for French, [OcptPageFormat.usLetter] otherwise.
  static OcptPageFormat _defaultPageFormatForPlatformLocale() {
    final languageCode = PlatformDispatcher.instance.locale.languageCode;
    return languageCode == "fr" ? OcptPageFormat.a4 : OcptPageFormat.usLetter;
  }

  /// Returns the default currency code for a newly created project, guessed from the platform's
  /// current locale (e.g. `fr_FR` suggests `EUR`, `en_US` suggests `USD`) through `intl`'s own
  /// locale-to-currency table, falling back to the schema's own default (`EUR`) when `intl` can't
  /// name one for the locale — a Dart platform locale that carries no region at all, say.
  static String _defaultCurrencyCodeForPlatformLocale() =>
      NumberFormat.simpleCurrency(
        locale: PlatformDispatcher.instance.locale.toString(),
      ).currencyName ??
      ocptDefaultCurrencyCode;

  /// Returns the default [OcptScreenplayLanguage] for a newly created project: the language the
  /// **app's own UI** is running in (`_appLanguageCode`), or **null** when no dictionary is bundled
  /// for it.
  ///
  /// The two other defaults a new project is seeded with read the *platform* locale
  /// ([_defaultPageFormatForPlatformLocale], [_defaultCurrencyCodeForPlatformLocale]) because a
  /// paper size and a currency belong to where the production is, whichever language its menus are
  /// in. A screenplay language is not that: it is the language the writer is about to type in, and
  /// the language they chose to read the app in is the far better guess — a French UI on an
  /// English system means a French writer.
  ///
  /// Returning null rather than falling back to any bundled dictionary is deliberate: with no
  /// dictionary for the app's language there is no honest guess left to make, and no dictionary
  /// selected means no spell-check underlines rather than every word underlined against a language
  /// the screenplay isn't written in. Whichever it is, it is a guess made once, at the only moment
  /// where getting it wrong costs nothing worse than a dropdown pick in the project settings page.
  static OcptScreenplayLanguage? _defaultScreenplayLanguageForAppLocale(
    String Function() appLanguageCode,
  ) {
    switch (appLanguageCode()) {
      case "fr":
        return OcptScreenplayLanguage.fr;
      case "en":
        return OcptScreenplayLanguage.enGb;
      default:
        return null;
    }
  }
}
