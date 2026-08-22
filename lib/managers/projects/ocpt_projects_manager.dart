// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_dart_value_keeper/act_dart_value_keeper.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fountain_kit/fountain_kit.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_project_file.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_dictionary_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_file_compatibility_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_package_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:uuid/uuid.dart';

/// Returns the language code of the locale the app's own UI is running in (`fr`, `en`…). The
/// type of [OcptProjectsManager]'s injectable seam over [LocalesManager] — see that class's
/// constructor for why a test wants to be able to replace it.
typedef OcptAppLanguageCodeGetter = String Function();

/// Builds the [OcptProjectsManager] instance registered by the global manager.
class OcptProjectsManagerBuilder extends AbsLifeCycleFactory<OcptProjectsManager> {
  /// Class constructor
  const OcptProjectsManagerBuilder() : super(OcptProjectsManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, OcptPropertiesManager, LocalesManager];
}

/// Owns the project the user currently has open, and every operation that creates, opens or
/// closes one.
///
/// Every Open Cine Prod Tools project is a single `.ocpt` SQLite file (an [OcptProjectDatabase]);
/// only one such file can be open at a time, exposed through [currentProject] and
/// [currentProjectStream]. Everything specific to reading/writing a screenplay's text, its scene
/// index, its shot list, its named versions, its resources catalogue (the address book, the cast,
/// locations and elements), the breakdown pass tagging that catalogue against the screenplay, the
/// shooting schedule, or the project's own spell-check lexicon is delegated to
/// [screenplayService], [sceneIndexService], [shotListService], [shotCoverageService],
/// [projectVersionsService], [peopleService], [roleIndexService], [locationsService],
/// [elementsService], [breakdownService], [scheduleService], [assetsService],
/// [projectDictionaryService], [projectPackageService], [projectFileCompatibilityService],
/// [budgetQuoteService], [budgetJournalService] and [budgetFinancingService], the eighteen services
/// this manager owns and wires together (RFL18): this manager itself is only
/// responsible for the lifecycle of the project file (create/open/close), for keeping the
/// properties manager's recent-projects list in sync, and for handing those services the facts
/// only it holds — the open project's database, the app version, this replica's device id and the
/// app-wide page margins.
///
/// **No project file reaches drift before [probeProjectFile] has read it.** A file written by
/// another build never opens as it comes: an older one is migrated in place only once the user has
/// answered for it and a copy has been kept ([openProject]'s `allowMigration`), and a newer one is
/// refused outright — see [OcptProjectFileCompatibilityService] for what drift does with a file
/// from the future, which is worse than failing.
///
/// It also owns the read-only **preview** of a version ([previewVersion] / [exitPreview]), which is
/// a state of the open project rather than of the database and so belongs here rather than in
/// [projectVersionsService]: previewing swaps the database the modes read through for an in-memory
/// one hydrated from the version's payload, and re-emits the project on [currentProjectStream].
class OcptProjectsManager extends AbsWithLifeCycle {
  /// The name of the folder created inside the platform's documents directory to hold projects
  /// created/saved without the user picking a different location.
  static const _defaultProjectsDirectoryName = "OpenCineProdTools";

  /// The extension used by project files, without the leading dot.
  ///
  /// The one definition lives in [ocptProjectFileExtension], which the package service reads too:
  /// a service may not import this manager, and the extension restated on the way down is one that
  /// could drift from the file this manager actually writes.
  static const projectFileExtension = ocptProjectFileExtension;

  /// The app version stored in newly created projects' `project_info.appVersionAtCreation`.
  ///
  /// This is a literal instead of being read from the platform (e.g. via a package-info plugin)
  /// so this manager stays fully testable with `flutter test`, without a platform channel: keep
  /// it in sync with the `version` entry of `pubspec.yaml`.
  static const _appVersion = "0.1.0";

  /// The properties manager used to persist the recently opened projects list.
  final OcptPropertiesManager _propertiesManager;

  /// The seam [_defaultScreenplayLanguageForAppLocale] reads the app's UI language through.
  final OcptAppLanguageCodeGetter _appLanguageCode;

  /// The service used to load/save a screenplay's text and manage its snapshots.
  final OcptScreenplayService screenplayService;

  /// The service used to reconcile a screenplay's scene index.
  final OcptSceneIndexService sceneIndexService;

  /// The service used for CRUD over a screenplay's shot list.
  final OcptShotListService shotListService;

  /// The service used to add/remove/check a shot's scenario coverage ranges.
  final OcptShotCoverageService shotCoverageService;

  /// The service used to create, list and delete the project's named versions.
  final OcptProjectVersionsService projectVersionsService;

  /// The service used for CRUD over the address book.
  final OcptPeopleService peopleService;

  /// The service used to reconcile the cast against the screenplay's speaking characters.
  final OcptRoleIndexService roleIndexService;

  /// The service used for CRUD over locations and their sets.
  final OcptLocationsService locationsService;

  /// The service used for CRUD over the physical elements catalogue.
  final OcptElementsService elementsService;

  /// The service used for CRUD over the budget mode's quote: the `budget_postes` catalogue and the
  /// `budget_lines` inside each one.
  final OcptBudgetQuoteService budgetQuoteService;

  /// The service used for CRUD over the budget mode's cash journal: the `budget_entries` movements
  /// and the `budget_commitments` still owed against a poste.
  final OcptBudgetJournalService budgetJournalService;

  /// The service used for CRUD over the budget mode's financing plan: the `budget_resources`
  /// catalogue and the `budget_mileage_rates` a production names for itself.
  final OcptBudgetFinancingService budgetFinancingService;

  /// The service used to tag a screenplay passage against an element, a role or a set, and to
  /// track a scene's own breakdown status.
  final OcptBreakdownService breakdownService;

  /// The service used for CRUD over the shooting schedule: its days, their convocation windows and
  /// convocations, and each day's timetable.
  final OcptScheduleService scheduleService;

  /// The service used to mint and tombstone the `assets` rows referencing a file — a headshot, a
  /// scouting photo, an element's photo, a signed release.
  ///
  /// Held here as well as inside the three services that compose it, because the resources mode
  /// drops a reference without caring what owns it: the row is the same row whoever it belongs to,
  /// so "remove this file" has one answer rather than three.
  final OcptAssetsService assetsService;

  /// The service used to learn, unlearn and read back the words this project's writer has taught
  /// the spell checker.
  final OcptProjectDictionaryService projectDictionaryService;

  /// The service used to write the project out as a portable package, and to read one back.
  ///
  /// Unlike every other service here it takes **paths** rather than an open database: a package is
  /// written from a project file, which is how the same code serves a project open in the workspace
  /// and a project card on the home page, and why exporting never migrates what it copies.
  final OcptProjectPackageService projectPackageService;

  /// The service reading a project file's own format before anything opens it, and keeping the
  /// copy a migration is answered with.
  ///
  /// Like [projectPackageService] it takes **paths** rather than an open database, and for a
  /// sharper reason: what it exists to prevent is precisely a project file being opened before its
  /// format is known.
  final OcptProjectFileCompatibilityService projectFileCompatibilityService;

  /// Whether a create/open/close operation is currently in progress.
  bool _isBusy = false;

  /// The callbacks the modes register to answer, at any moment, whether they hold changes that
  /// haven't reached the database yet.
  ///
  /// See [registerUnsavedChangesReporter] for why this manager has to ask at all.
  final _unsavedChangesReporters = <bool Function()>[];

  /// The project currently open, if any, with a stream to react to it changing.
  ///
  /// This uses [ValueKeeperWithStream] (rather than `ValueKeeperWithStreamAndNullInit`, whose
  /// setter only accepts a non-null value once past its initial state) because a project needs to
  /// be freely settable back to null whenever it's closed.
  late final ValueKeeperWithStream<OcptOpenProjectModel?> _currentProject;

  /// Class constructor
  ///
  /// [appLanguageCode] is the injectable seam over reading the app's own UI language, defaulting
  /// to [LocalesManager]'s `currentLocale`, and read only when a project is created
  /// ([_defaultScreenplayLanguageForAppLocale]) — never when this manager is built, so a test only
  /// needs to hand one in when it creates a project.
  OcptProjectsManager({
    OcptPropertiesManager? propertiesManager,
    OcptAppLanguageCodeGetter? appLanguageCode,
  }) : _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _appLanguageCode = appLanguageCode ?? _localesManagerLanguageCode,
       sceneIndexService = const OcptSceneIndexService(),
       shotListService = const OcptShotListService(),
       shotCoverageService = const OcptShotCoverageService(),
       projectVersionsService = const OcptProjectVersionsService(
         codec: OcptProjectVersionCodec(),
         screenplayService: OcptScreenplayService(
           sceneIndexService: OcptSceneIndexService(),
           shotListService: OcptShotListService(),
           shotCoverageService: OcptShotCoverageService(),
           roleIndexService: OcptRoleIndexService(),
           breakdownService: OcptBreakdownService(
             elementsService: OcptElementsService(),
             locationsService: OcptLocationsService(),
           ),
           scheduleService: OcptScheduleService(),
         ),
       ),
       screenplayService = const OcptScreenplayService(
         sceneIndexService: OcptSceneIndexService(),
         shotListService: OcptShotListService(),
         shotCoverageService: OcptShotCoverageService(),
         roleIndexService: OcptRoleIndexService(),
         breakdownService: OcptBreakdownService(
           elementsService: OcptElementsService(),
           locationsService: OcptLocationsService(),
         ),
         scheduleService: OcptScheduleService(),
       ),
       peopleService = const OcptPeopleService(),
       roleIndexService = const OcptRoleIndexService(),
       locationsService = const OcptLocationsService(),
       elementsService = const OcptElementsService(),
       budgetQuoteService = const OcptBudgetQuoteService(),
       budgetJournalService = const OcptBudgetJournalService(),
       budgetFinancingService = const OcptBudgetFinancingService(),
       assetsService = const OcptAssetsService(),
       projectDictionaryService = const OcptProjectDictionaryService(),
       projectPackageService = const OcptProjectPackageService(),
       projectFileCompatibilityService = const OcptProjectFileCompatibilityService(),
       breakdownService = const OcptBreakdownService(
         elementsService: OcptElementsService(),
         locationsService: OcptLocationsService(),
       ),
       scheduleService = const OcptScheduleService();

  /// The project currently open, or null if none is.
  OcptOpenProjectModel? get currentProject => _currentProject.value;

  /// Emits the project currently open (or null) every time it changes.
  Stream<OcptOpenProjectModel?> get currentProjectStream => _currentProject.valueStream;

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    _currentProject = ValueKeeperWithStream<OcptOpenProjectModel?>(value: null);
  }

  /// Returns the default directory suggested to the user when creating or opening a project,
  /// creating it if it doesn't already exist.
  Future<Directory> getDefaultProjectsDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final projectsDirectory = Directory(
      p.join(documentsDirectory.path, _defaultProjectsDirectoryName),
    );

    if (!projectsDirectory.existsSync()) {
      await projectsDirectory.create(recursive: true);
    }

    return projectsDirectory;
  }

  /// Creates a new project named [name] at [filePath], seeds it with a single empty screenplay —
  /// episode 1 (`number: 1`), given a real first `sortKey` rather than left at the column
  /// defaults, so a project made today looks exactly like one that came through the schema version
  /// 18 migration (`docs/adr/0019-one-project-several-episodes.md`) — registers it in the recent
  /// projects list, and makes it the [currentProject].
  ///
  /// If a project is already open, it's closed first. The project's page format defaults to
  /// [OcptPageFormat.a4] when the platform's locale is French, and to [OcptPageFormat.usLetter]
  /// otherwise. Its currency defaults to whatever `intl` names for the platform's current locale
  /// (`fr_FR` suggests EUR, `en_US` suggests USD…), falling back to
  /// [ocptDefaultCurrencyCode] when it can't. Its screenplay language is seeded from the **app's**
  /// own UI language instead ([_defaultScreenplayLanguageForAppLocale]), and left unset when no
  /// dictionary is bundled for it.
  Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> createProject({
    required String name,
    required String filePath,
  }) async {
    if (_isBusy) {
      return const ResultWithStatus(status: OcptProjectStatus.alreadyOpen);
    }
    _isBusy = true;

    OcptProjectDatabase? database;
    try {
      if (currentProject != null) {
        await closeCurrentProject();
      }

      final file = File(filePath);
      await file.parent.create(recursive: true);
      if (file.existsSync()) {
        await file.delete();
      }

      database = OcptProjectDatabase(file);

      final now = DateTime.now();
      await database
          .into(database.ocptProjectInfoTable)
          .insert(
            OcptProjectInfoTableCompanion.insert(
              name: name,
              createdAt: now,
              appVersionAtCreation: _appVersion,
              pageFormat: _defaultPageFormatForPlatformLocale(),
              currencyCode: Value(_defaultCurrencyCodeForPlatformLocale()),
              screenplayLanguage: Value(_defaultScreenplayLanguageForAppLocale()),
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
      _currentProject.value = project;

      await _propertiesManager.addRecentProject(
        // A fresh project holds exactly one episode — no need to read it back.
        OcptRecentProjectModel(path: filePath, name: name, lastOpenedAt: now, episodeCount: 1),
      );

      return ResultWithStatus(status: OcptProjectStatus.ok, value: project);
    } catch (error) {
      appLogger().e(
        "A problem occurred when tried to create the project '$name' at $filePath: "
        "$error",
      );
      await database?.close();
      return const ResultWithStatus(status: OcptProjectStatus.ioError);
    } finally {
      _isBusy = false;
    }
  }

  /// Reads which format the project file at [filePath] is in, and what that means for this build,
  /// without opening it as a project.
  ///
  /// What every door into a project file asks before it goes through: the home page's `Open…`, a
  /// recent project card, and the import of a package built by another build. It writes nothing and
  /// migrates nothing, which is the whole point — the answer is what the user is shown *before*
  /// their file is touched, and [OcptProjectFileCompatibility.suggestedBackupPath] is the very path
  /// [openProject] then writes the copy to.
  OcptProjectFileCompatibility probeProjectFile({required String filePath}) =>
      projectFileCompatibilityService.probe(
        filePath: filePath,
        appSchemaVersion: OcptProjectDatabase.currentSchemaVersion,
      );

  /// Opens the project stored at [filePath], registers it in the recent projects list, and makes
  /// it the [currentProject].
  ///
  /// If a project is already open, it's closed first — but only once the file's own format has been
  /// read and accepted, so a refusal never costs the user the project they already had open.
  ///
  /// **A file written by another build never opens silently.** It is probed first
  /// ([probeProjectFile]), and:
  /// - a **newer** format is refused with [OcptProjectStatus.newerFormat]: it isn't opened, isn't
  ///   touched and doesn't reach the recent projects list. Handing it to drift would stamp its
  ///   `user_version` back down to this build's number while leaving the newer build's tables in
  ///   place, which is not a failure the user could ever undo;
  /// - an **older** format returns [OcptProjectStatus.migrationRequired] unless [allowMigration] is
  ///   true, which is the caller saying the user has been told what is about to happen. Only then is
  ///   the copy written — at the path the probe named, so the promise and the write cannot drift
  ///   apart — and the file handed to drift, whose `onUpgrade` migrates it as it always has;
  /// - anything else opens exactly as it did before this gate existed.
  Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> openProject({
    required String filePath,
    bool allowMigration = false,
  }) async {
    if (_isBusy) {
      return const ResultWithStatus(status: OcptProjectStatus.alreadyOpen);
    }
    _isBusy = true;

    OcptProjectDatabase? database;
    try {
      if (!File(filePath).existsSync()) {
        return const ResultWithStatus(status: OcptProjectStatus.fileNotFound);
      }

      final formatGate = _gateOnFileFormat(filePath: filePath, allowMigration: allowMigration);
      if (formatGate != null) {
        return ResultWithStatus(status: formatGate);
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
        appLogger().w(
          "The project file at $filePath is missing its project info or its "
          "screenplay, it's considered corrupted",
        );
        await database.close();
        return const ResultWithStatus(status: OcptProjectStatus.corruptedFile);
      }

      final project = OcptOpenProjectModel(
        path: filePath,
        name: info.name,
        primaryScreenplayId: screenplay.id,
        database: database,
      );
      _currentProject.value = project;

      await screenplayService.snapshotOnProjectOpen(
        database: database,
        screenplayId: screenplay.id,
      );

      final episodeCount = (await screenplayService.loadEpisodes(database: database)).length;

      await _propertiesManager.addRecentProject(
        OcptRecentProjectModel(
          path: filePath,
          name: info.name,
          lastOpenedAt: DateTime.now(),
          episodeCount: episodeCount,
        ),
      );

      return ResultWithStatus(status: OcptProjectStatus.ok, value: project);
    } on SqliteException catch (error) {
      appLogger().e("The project file at $filePath appears corrupted: $error");
      await database?.close();
      return const ResultWithStatus(status: OcptProjectStatus.corruptedFile);
    } catch (error) {
      appLogger().e("A problem occurred when tried to open the project at $filePath: $error");
      await database?.close();
      return const ResultWithStatus(status: OcptProjectStatus.ioError);
    } finally {
      _isBusy = false;
    }
  }

  /// Answers whether the file at [filePath] may be handed to drift, and takes the backup when a
  /// migration is going ahead: null to go on, or the status to report back instead.
  ///
  /// Split out of [openProject] because it is the one part of opening a project that must happen
  /// **before anything else does** — before the currently open project is closed, and before drift
  /// ever sees the file.
  OcptProjectStatus? _gateOnFileFormat({required String filePath, required bool allowMigration}) {
    final compatibility = probeProjectFile(filePath: filePath);

    switch (compatibility.verdict) {
      case OcptProjectFileVerdict.newer:
        appLogger().w(
          "The project file at $filePath is in format ${compatibility.fileSchemaVersion}, which "
          "this build (format ${compatibility.appSchemaVersion}) can't read: it's refused, not "
          "opened",
        );
        return OcptProjectStatus.newerFormat;
      case OcptProjectFileVerdict.older:
        final backupPath = compatibility.suggestedBackupPath;
        if (!allowMigration || backupPath == null) {
          return OcptProjectStatus.migrationRequired;
        }

        if (!projectFileCompatibilityService.writeBackup(
          filePath: filePath,
          backupPath: backupPath,
        )) {
          // The migration is irreversible, and it was allowed on the promise that a copy would be
          // kept: no copy, no migration.
          return OcptProjectStatus.ioError;
        }

        appLogger().i(
          "The project file at $filePath is being migrated from format "
          "${compatibility.fileSchemaVersion} to ${compatibility.appSchemaVersion}; a copy of it "
          "was kept at $backupPath",
        );
        return null;
      case OcptProjectFileVerdict.current:
      case OcptProjectFileVerdict.unreadable:
        return null;
    }
  }

  /// Loads the page format stored in the [currentProject]'s `project_info` table, or null if no
  /// project is currently open.
  ///
  /// This lives here (rather than in the editor's UI layer) so reading the project database stays
  /// confined to the managers/services layer.
  Future<OcptPageFormat?> loadCurrentProjectPageFormat() async {
    final project = currentProject;
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.pageFormat;
  }

  /// Updates the page format stored in the [currentProject]'s `project_info` table. Does nothing if
  /// no project is currently open.
  ///
  /// This is the first write to `project_info` after the project is created: [createProject] seeds
  /// it once, and this is the only path that ever changes it afterwards.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectPageFormat(OcptPageFormat format) async {
    final project = currentProject;
    if (project == null || project.database.refusesUserWrite("saveCurrentProjectPageFormat")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(pageFormat: Value(format)));
  }

  /// Loads the ISO 4217 currency code stored in the [currentProject]'s `project_info` table, or
  /// null if no project is currently open.
  ///
  /// Modelled on [loadCurrentProjectPageFormat]: reading the project database stays confined to
  /// the managers/services layer.
  Future<String?> loadCurrentProjectCurrencyCode() async {
    final project = currentProject;
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.currencyCode;
  }

  /// Updates the currency code stored in the [currentProject]'s `project_info` table. Does nothing
  /// if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectPageFormat]: [code] is a property of the project, not of the
  /// app, so it is written the very same way.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectCurrencyCode(String code) async {
    final project = currentProject;
    if (project == null || project.database.refusesUserWrite("saveCurrentProjectCurrencyCode")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(currencyCode: Value(code)));
  }

  /// Loads the minimum rest, in minutes, stored in the [currentProject]'s `project_info` table, or
  /// null.
  ///
  /// The two reasons for a null answer are indistinguishable here, exactly as
  /// [loadCurrentProjectCurrencyCode]'s would be if that column were nullable: no project is open,
  /// or one is and nobody has recorded a minimum for it — the column's own truthful "nobody has
  /// said" (`OcptProjectInfoTable.minimumRestMinutes`).
  Future<int?> loadCurrentProjectMinimumRestMinutes() async {
    final project = currentProject;
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.minimumRestMinutes;
  }

  /// Updates the minimum rest, in minutes, stored in the [currentProject]'s `project_info` table,
  /// or clears it when [minutes] is null — a production that decides it no longer wants to record
  /// one is as real a gesture as setting it. Does nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectCurrencyCode], with one difference the column's own nullability
  /// forces: [minutes] is written whichever it is, including null, rather than only ever holding a
  /// value the way a page format or a currency always does.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectMinimumRestMinutes(int? minutes) async {
    final project = currentProject;
    if (project == null ||
        project.database.refusesUserWrite("saveCurrentProjectMinimumRestMinutes")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(minimumRestMinutes: Value(minutes)));
  }

  /// Loads the screenplay language stored in the [currentProject]'s `project_info` table, or null.
  ///
  /// The two reasons for a null answer are indistinguishable here, exactly as
  /// [loadCurrentProjectMinimumRestMinutes]'s are: no project is open, or one is and nobody has
  /// recorded a language for it — the column's own truthful "nobody has said"
  /// (`OcptProjectInfoTable.screenplayLanguage`).
  Future<OcptScreenplayLanguage?> loadCurrentProjectScreenplayLanguage() async {
    final project = currentProject;
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.screenplayLanguage;
  }

  /// Updates the screenplay language stored in the [currentProject]'s `project_info` table, or
  /// clears it when [language] is null — a writer who decides the checker should stay off this
  /// screenplay is making as real a choice as picking one of the two bundled languages. Does
  /// nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectMinimumRestMinutes]: [language] is written whichever it is,
  /// including null, rather than only ever holding a value the way a page format or a currency
  /// always does.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage? language) async {
    final project = currentProject;
    if (project == null ||
        project.database.refusesUserWrite("saveCurrentProjectScreenplayLanguage")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(screenplayLanguage: Value(language)));
  }

  /// Loads the default VAT rate, in basis points, stored in the [currentProject]'s `project_info`
  /// table, or null.
  ///
  /// The two reasons for a null answer are indistinguishable here, exactly as
  /// [loadCurrentProjectMinimumRestMinutes]'s are: no project is open, or one is and nobody has
  /// recorded a rate for it — the column's own truthful "nobody has said"
  /// (`OcptProjectInfoTable.defaultVatRateBasisPoints`).
  Future<int?> loadCurrentProjectDefaultVatRateBasisPoints() async {
    final project = currentProject;
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.defaultVatRateBasisPoints;
  }

  /// Updates the default VAT rate, in basis points, stored in the [currentProject]'s `project_info`
  /// table, or clears it when [basisPoints] is null — a production putting the rate back to "not
  /// recorded" is as real a gesture as setting it (`OcptProjectSettingsBudgetSection`'s `No rate`
  /// button). Does nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectMinimumRestMinutes]: [basisPoints] is written whichever it is,
  /// including null, rather than only ever holding a value the way a page format or a currency
  /// always does.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectDefaultVatRateBasisPoints(int? basisPoints) async {
    final project = currentProject;
    if (project == null ||
        project.database.refusesUserWrite("saveCurrentProjectDefaultVatRateBasisPoints")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(defaultVatRateBasisPoints: Value(basisPoints)));
  }

  /// Loads the price of one meal, in cents, stored in the [currentProject]'s `project_info` table,
  /// or null — the same "nobody has said" reading [loadCurrentProjectDefaultVatRateBasisPoints]
  /// gets.
  Future<int?> loadCurrentProjectMealPriceCents() async {
    final project = currentProject;
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.mealPriceCents;
  }

  /// Updates the price of one meal, in cents, stored in the [currentProject]'s `project_info`
  /// table, or clears it when [cents] is null. Does nothing if no project is currently open.
  ///
  /// Modelled on [saveCurrentProjectDefaultVatRateBasisPoints]: [cents] is written whichever it is,
  /// including null.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectMealPriceCents(int? cents) async {
    final project = currentProject;
    if (project == null || project.database.refusesUserWrite("saveCurrentProjectMealPriceCents")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(mealPriceCents: Value(cents)));
  }

  /// Loads the price of one snack, in cents, stored in the [currentProject]'s `project_info` table,
  /// or null — [loadCurrentProjectMealPriceCents]'s sibling, read the same way.
  Future<int?> loadCurrentProjectSnackPriceCents() async {
    final project = currentProject;
    if (project == null) {
      return null;
    }

    final info = await project.database
        .select(project.database.ocptProjectInfoTable)
        .getSingleOrNull();
    return info?.snackPriceCents;
  }

  /// Updates the price of one snack, in cents, stored in the [currentProject]'s `project_info`
  /// table, or clears it when [cents] is null — [saveCurrentProjectMealPriceCents]'s sibling.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectSnackPriceCents(int? cents) async {
    final project = currentProject;
    if (project == null ||
        project.database.refusesUserWrite("saveCurrentProjectSnackPriceCents")) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(snackPriceCents: Value(cents)));
  }

  /// Lists the [currentProject]'s versions, newest first, or an empty list if no project is open.
  ///
  /// {@template open_cine_prod_tools.OcptProjectsManager.versionOperations}
  /// The version operations live here rather than being called on [projectVersionsService]
  /// directly, because the service is handed facts only this manager holds: the open project's
  /// database, the app version, this replica's device id and the app-wide page margins.
  ///
  /// They are also the only operations of the app that go through
  /// [OcptOpenProjectModel.fileDatabase] rather than [OcptOpenProjectModel.database]: the version
  /// list belongs to the project file, and stays readable and editable while a preview is on
  /// screen — deleting a version you happen not to be previewing is perfectly legitimate then.
  /// {@endtemplate}
  Future<List<OcptProjectVersion>> listProjectVersions() async {
    final project = currentProject;
    if (project == null) {
      return const [];
    }

    return projectVersionsService.listVersions(database: project.fileDatabase);
  }

  /// Captures the [currentProject] as a new version named [name], with the user's [note], and
  /// returns it. Returns null if no project is open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectsManager.versionOperations}
  Future<OcptProjectVersion?> createProjectVersion({
    required String name,
    required String note,
  }) async {
    final project = currentProject;
    if (project == null) {
      return null;
    }

    return projectVersionsService.createVersion(
      database: project.fileDatabase,
      name: name,
      note: note,
      appVersion: _appVersion,
      deviceId: await _propertiesManager.loadOrCreateDeviceId(),
      pageMargins: await _loadPageMargins(),
    );
  }

  /// Renames the version [versionId] of the [currentProject] to [name], replacing its [note]. Does
  /// nothing if no project is open.
  ///
  /// Unlike every other version operation, this one is left available while a version is being
  /// previewed: `OcptProjectVersionsService.renameVersion` only ever writes the version's own row,
  /// never reads the project's data, so there is nothing here a preview could make stale.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectsManager.versionOperations}
  Future<void> renameProjectVersion({
    required String versionId,
    required String name,
    required String note,
  }) async {
    final project = currentProject;
    if (project == null) {
      return;
    }

    await projectVersionsService.renameVersion(
      database: project.fileDatabase,
      id: versionId,
      name: name,
      note: note,
    );
  }

  /// Measures the [currentProject]'s working copy exactly as
  /// [OcptProjectVersionsService.captureWorkingCopyState] does, or null if no project is open.
  ///
  /// Also null while a version is being previewed, for the same reason [createProjectVersion] is
  /// refused by the bloc that calls it then: this reads [OcptOpenProjectModel.fileDatabase], the
  /// project file underneath whatever the user is actually looking at, so a working-copy card built
  /// from it during a preview would describe a state that isn't on screen.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectsManager.versionOperations}
  Future<OcptProjectWorkingCopyState?> captureWorkingCopyState() async {
    final project = currentProject;
    if (project == null || project.isReadOnly) {
      return null;
    }

    return projectVersionsService.captureWorkingCopyState(
      database: project.fileDatabase,
      pageMargins: await _loadPageMargins(),
    );
  }

  /// Deletes the version [versionId] of the [currentProject]. Does nothing if no project is open,
  /// or if [versionId] is the version currently being previewed.
  ///
  /// Refusing to delete the previewed version is a matter of the open project's state rather than
  /// of the database, which is why it lives here rather than in [projectVersionsService]: the
  /// preview on screen reads from a database hydrated out of that very row, and pulling it from
  /// under the user would leave them reading something the project no longer has.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectsManager.versionOperations}
  Future<void> deleteProjectVersion(String versionId) async {
    final project = currentProject;
    if (project == null) {
      return;
    }

    if (project.previewedVersion?.id == versionId) {
      appLogger().w(
        "The project version $versionId can't be deleted while it's the one being "
        "previewed: leave the preview first",
      );
      return;
    }

    await projectVersionsService.deleteVersion(database: project.fileDatabase, id: versionId);
  }

  /// Puts the [currentProject] back into the state the version [versionId] captured, keeping the
  /// state it leaves behind as a version of its own named [safetyVersionName] — unless that state
  /// already matches the version the working copy currently descends from, in which case
  /// [OcptProjectVersionsService.restoreVersion] skips it rather than mint a duplicate of a card
  /// already in the list.
  ///
  /// A preview is left first, whichever version it was showing: the working copy is about to become
  /// something else, and a preview outliving that would go on describing a project that no longer
  /// exists. The project model is re-emitted once the restore has committed, so every mode reloads
  /// what it shows from the restored database.
  ///
  /// The page setup travels with the version (see
  /// [OcptProjectVersionsService.restoreVersion]): the format is written by the restore's own
  /// transaction, and the **margins are written here, after it has committed**, because they are an
  /// app-wide preference rather than project data and cannot be rolled back with the transaction
  /// that would have written them.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectsManager.versionOperations}
  Future<OcptProjectRestoreStatus> restoreProjectVersion({
    required String versionId,
    required String safetyVersionName,
  }) async {
    if (currentProject == null) {
      return OcptProjectRestoreStatus.noProjectOpen;
    }

    await exitPreview();

    final project = currentProject!;
    final result = await projectVersionsService.restoreVersion(
      database: project.fileDatabase,
      id: versionId,
      safetyVersionName: safetyVersionName,
      appVersion: _appVersion,
      deviceId: await _propertiesManager.loadOrCreateDeviceId(),
      pageMargins: await _loadPageMargins(),
    );

    final restoredPageSetup = result.value;
    if (restoredPageSetup == null) {
      return result.status;
    }

    await _propertiesManager.pageMargins.store(restoredPageSetup.margins);

    _currentProject.value = project.workingCopy;

    // A restored version may hold a different number of episodes than the working copy did.
    await recordCurrentProjectEpisodeCount();

    return result.status;
  }

  /// The app-wide page margins a version is measured and restored against, falling back to the
  /// standard ones while the user has never set any.
  Future<FountainPageMargins> _loadPageMargins() async =>
      await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard();

  /// Registers [reporter], which answers whether the caller holds changes that haven't reached the
  /// database yet, and returns the callback that unregisters it.
  ///
  /// A mode's bloc registers itself when it mounts and calls the returned callback when it closes.
  /// This exists for [previewVersion] alone: entering a preview swaps the database every edit is
  /// written through, so a save still sitting in an autosave debounce would land in the previewed
  /// version's in-memory database and be lost with it. Rather than let the manager reach into a
  /// bloc's state, each mode answers for itself.
  void Function() registerUnsavedChangesReporter(bool Function() reporter) {
    _unsavedChangesReporters.add(reporter);
    return () => _unsavedChangesReporters.remove(reporter);
  }

  /// Whether any mode currently reports changes that haven't reached the database yet.
  bool get hasUnsavedChanges => _unsavedChangesReporters.any((reporter) => reporter());

  /// Enters the read-only preview of the version [versionId] of the [currentProject]: the version's
  /// payload is hydrated into an in-memory database, and *that* is what [currentProject] hands the
  /// modes from now on.
  ///
  /// **The project file is never opened for writing by a preview.** It stays open as
  /// [OcptOpenProjectModel.fileDatabase] — same connection, still writable by everything that
  /// isn't a user edit — and a crash mid-preview leaves it exactly as it was. Nothing of the
  /// version is written anywhere either: the page setup it was typeset with travels on
  /// [OcptOpenProjectModel.previewedPageSetup] and is rendered with, never stored, since the
  /// margins half of it is an app-wide preference that has nothing to do with this project.
  ///
  /// Every mode's bloc already rebuilds on [currentProjectStream], so none of them learns anything
  /// about versions to display one — that stream emission is the whole of the propagation. It
  /// works because the emitted model doesn't compare equal to the previous one (see
  /// [OcptOpenProjectModel.props]).
  ///
  /// Refused with [OcptProjectPreviewStatus.unsavedChanges] while any mode reports itself dirty:
  /// the caller saves first and retries. Refused as a whole on any failure — a preview that can't
  /// be entered leaves the working copy on screen, untouched.
  Future<ResultWithStatus<OcptProjectPreviewStatus, OcptOpenProjectModel>> previewVersion(
    String versionId,
  ) async {
    final project = currentProject;
    if (project == null) {
      return const ResultWithStatus(status: OcptProjectPreviewStatus.noProjectOpen);
    }

    if (hasUnsavedChanges) {
      appLogger().w(
        "The project version $versionId can't be previewed while a mode still holds "
        "unsaved changes: they must be saved first, or they would be written into the preview",
      );
      return const ResultWithStatus(status: OcptProjectPreviewStatus.unsavedChanges);
    }

    final version = await projectVersionsService.loadVersion(
      database: project.fileDatabase,
      id: versionId,
    );

    if (version == null) {
      appLogger().w(
        "The project version $versionId can't be previewed: no such version in this "
        "project",
      );
      return const ResultWithStatus(status: OcptProjectPreviewStatus.versionNotFound);
    }

    final payloadResult = await projectVersionsService.loadPayload(
      database: project.fileDatabase,
      id: versionId,
    );

    final payload = payloadResult.value;
    if (payload == null) {
      return ResultWithStatus(
        status: switch (payloadResult.status) {
          OcptProjectVersionPayloadStatus.unsupportedFutureFormat =>
            OcptProjectPreviewStatus.unsupportedFutureFormat,
          _ => OcptProjectPreviewStatus.malformedPayload,
        },
      );
    }

    final previewDatabase = OcptProjectDatabase.memory(isPreview: true);
    try {
      await projectVersionsService.hydratePreview(
        database: previewDatabase,
        projectInfo: await project.fileDatabase
            .select(project.fileDatabase.ocptProjectInfoTable)
            .getSingle(),
        payload: payload,
      );
    } catch (error) {
      appLogger().e(
        "A problem occurred when tried to hydrate the preview of the project version "
        "$versionId: $error",
      );
      await previewDatabase.close();
      return const ResultWithStatus(status: OcptProjectPreviewStatus.hydrationFailed);
    }

    // Only now that the new preview is ready does the previous one go: a preview that failed to
    // load must leave what was on screen alone.
    final previousPreviewDatabase = project.isReadOnly ? project.database : null;

    final previewedProject = project.previewing(
      previewDatabase: previewDatabase,
      version: version,
      pageSetup: payload.pageSetup,
    );
    _currentProject.value = previewedProject;

    await previousPreviewDatabase?.close();

    return ResultWithStatus(status: OcptProjectPreviewStatus.ok, value: previewedProject);
  }

  /// Leaves the read-only preview, putting the working copy back on screen. Does nothing if no
  /// project is open or if none is being previewed.
  ///
  /// The model is re-emitted *before* the preview database is closed, so every mode has already
  /// been told to read from the project file again by the time that connection goes.
  Future<void> exitPreview() async {
    final project = currentProject;
    if (project == null || !project.isReadOnly) {
      return;
    }

    final previewDatabase = project.database;
    _currentProject.value = project.workingCopy;

    await previewDatabase.close();
  }

  /// Stats every file the project stored at [projectFilePath] references, without writing
  /// anything.
  ///
  /// The question a package export asks before it writes: a referenced file that is gone does not
  /// block the export, but it is never skipped silently. Returns null when that file cannot be read
  /// as a project at all.
  ///
  /// Takes a path rather than reading [currentProject] because both doors into this share it: a
  /// project open in the workspace passes its own path, a project card on the home page passes the
  /// path it lists, and neither needs the project to be open.
  OcptProjectPackagePreflight? scanProjectPackageAssets({required String projectFilePath}) =>
      projectPackageService.scanAssets(projectFilePath: projectFilePath);

  /// Writes the project stored at [projectFilePath] out as a portable package at
  /// [packageFilePath], and reports what travelled.
  ///
  /// [projectName] is the display name the package carries, resolved by the caller — from
  /// [currentProject] for an open project, from the recent entry for a card on the home page.
  ///
  /// **The project file is only ever read**, and it is never migrated on the way out: a package
  /// carries the database at whatever schema version it is in, and it is the importing build's own
  /// gate that states a migration. Nothing here needs a project to be open, and nothing here
  /// touches the one that is.
  Future<ResultWithStatus<OcptProjectPackageStatus, OcptProjectPackageExportReport>>
  exportProjectPackage({
    required String projectFilePath,
    required String projectName,
    required String packageFilePath,
  }) => projectPackageService.writePackage(
    projectFilePath: projectFilePath,
    packageFilePath: packageFilePath,
    projectName: projectName,
    appVersion: _appVersion,
    exportedAt: DateTime.now(),
  );

  /// Unpacks the package at [packageFilePath] into a new folder inside [parentDirectoryPath], and
  /// reports what landed.
  ///
  /// **It does not open the project it just unpacked.** The `.ocpt` this writes may be at any
  /// schema version — a package carries the database exactly as it was exported, unmigrated (see
  /// [exportProjectPackage]) — so the caller goes through the same gate every other door into a
  /// project file does: [probeProjectFile] then [openProject], which is what states a migration
  /// for a package built by an older build rather than one silently happening as a side effect of
  /// importing it.
  Future<ResultWithStatus<OcptProjectPackageStatus, OcptProjectPackageImportReport>>
  importProjectPackage({required String packageFilePath, required String parentDirectoryPath}) =>
      projectPackageService.readPackage(
        packageFilePath: packageFilePath,
        parentDirectoryPath: parentDirectoryPath,
      );

  /// Closes the [currentProject], disposing its database handle. Does nothing if no project is
  /// open.
  ///
  /// A project closed while a version is being previewed disposes both of its connections: the
  /// in-memory one holding the version, then the project file itself. Before either goes, the
  /// recent-projects entry for this project is updated with its live episode count, read through
  /// [screenplayService]'s own [OcptScreenplayService.loadEpisodes] over
  /// [OcptOpenProjectModel.fileDatabase] — the working copy, **never**
  /// [OcptOpenProjectModel.database], which would be the in-memory preview database while a
  /// version is being previewed — so a session that added or deleted episodes leaves a truthful
  /// count behind rather than the one it opened with, and previewing a version never overwrites it
  /// with a count that isn't the project's own.
  Future<void> closeCurrentProject() async {
    final project = currentProject;
    if (project == null) {
      return;
    }

    final episodeCount = (await screenplayService.loadEpisodes(
      database: project.fileDatabase,
    )).length;

    _currentProject.value = null;

    if (project.isReadOnly) {
      await project.database.close();
    }

    await project.fileDatabase.close();

    await _recordEpisodeCount(path: project.path, episodeCount: episodeCount);
  }

  /// Updates the recent-projects entry for the [currentProject] so it carries the episode count
  /// the project holds right now. Does nothing when no project is open.
  ///
  /// [closeCurrentProject] records that count on the way out too, but only a session that *leaves*
  /// the project ever reaches it: an app closed while the project is still open never runs it, and
  /// the home card would then go on showing the count the project was opened with until the next
  /// time it is opened. Whoever adds or removes an episode calls this the moment it happens, so
  /// that count survives a window closed on the spot.
  ///
  /// The live count is read over [OcptOpenProjectModel.fileDatabase] — the working copy, **never**
  /// [OcptOpenProjectModel.database], which would be the in-memory preview database while a
  /// version is being previewed.
  Future<void> recordCurrentProjectEpisodeCount() async {
    final project = currentProject;
    if (project == null) {
      return;
    }

    final episodeCount = (await screenplayService.loadEpisodes(
      database: project.fileDatabase,
    )).length;

    await _recordEpisodeCount(path: project.path, episodeCount: episodeCount);
  }

  /// Updates the recent-projects entry for [path], if it is still in the list, so it carries
  /// [episodeCount] rather than whichever count was recorded when the project was opened.
  ///
  /// Left untouched, rather than created, when [path] isn't in the list at all — e.g. it was
  /// removed from the recent projects list while the project stayed open.
  Future<void> _recordEpisodeCount({required String path, required int episodeCount}) async {
    final recents = await _propertiesManager.recentProjects.load() ?? const [];
    final index = recents.indexWhere((entry) => entry.path == path);
    if (index == -1) {
      return;
    }

    final updated = [...recents];
    updated[index] = updated[index].copyWith(episodeCount: episodeCount);
    await _propertiesManager.recentProjects.store(updated);
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
  /// **app's own UI** is running in ([_appLanguageCode]), or **null** when no dictionary is bundled for
  /// it.
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
  OcptScreenplayLanguage? _defaultScreenplayLanguageForAppLocale() {
    switch (_appLanguageCode()) {
      case "fr":
        return OcptScreenplayLanguage.fr;
      case "en":
        return OcptScreenplayLanguage.enGb;
      default:
        return null;
    }
  }

  /// The default [OcptAppLanguageCodeGetter]: the language of the app's own UI locale, as
  /// [LocalesManager] holds it.
  ///
  /// Resolved through [globalGetIt] at call time rather than when this manager is built, so
  /// nothing needs that manager registered until a project is actually created.
  static String _localesManagerLanguageCode() =>
      globalGetIt().get<LocalesManager>().currentLocale.languageCode;

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    await closeCurrentProject();
    await _currentProject.disposeLifeCycle();
    return super.disposeLifeCycle();
  }
}
