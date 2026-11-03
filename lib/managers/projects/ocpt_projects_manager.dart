// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_dart_value_keeper/act_dart_value_keeper.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_project_file.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_episode_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_move_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_open_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_preview_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_settings_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_services.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_allowances_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_dictionary_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_file_compatibility_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_package_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_export_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_import_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_free_file_path.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_move_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Return the language code of the locale the app's own UI is running in (`fr`, `en`…). The
/// type of [OcptProjectsManager]'s injectable seam over [LocalesManager] — see that class's
/// constructor for why a test wants to be able to replace it.
typedef OcptAppLanguageCodeGetter = String Function();

/// Build the [OcptProjectsManager] instance registered by the global manager.
class OcptProjectsManagerBuilder extends AbsLifeCycleFactory<OcptProjectsManager> {
  /// Class constructor
  const OcptProjectsManagerBuilder() : super(OcptProjectsManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, OcptPropertiesManager, LocalesManager];
}

/// Own the project the user currently has open, and every operation that creates, opens or
/// closes one.
///
/// Every Open Cine Prod Tools project is a single `.ocpt` SQLite file (an [OcptProjectDatabase]);
/// only one such file can be open at a time, exposed through [currentProject] and
/// [currentProjectStream]. Everything specific to reading/writing a screenplay's text, its scene
/// index, its shot list, its named versions, its resources catalogue (the address book, the cast,
/// locations and elements), the breakdown pass tagging that catalogue against the screenplay, the
/// shooting schedule, or the project's own spell-check lexicon is delegated to
/// [screenplayService], [sceneIndexService], [shotListService], [shotCoverageService],
/// [projectVersionsService], [peopleService], [roleIndexService], [roleCandidatesService],
/// [locationsService],
/// [elementsService], [breakdownService], [scheduleService], [assetsService],
/// [storyboardService], [floorPlanService],
/// [projectDictionaryService], [projectPackageService], [projectFileCompatibilityService],
/// [budgetQuoteService], [budgetJournalService], [budgetFinancingService],
/// [budgetAllowancesService] and [budgetSharingService], the twenty-three services this manager
/// owns and wires together:
/// this manager itself is only
/// responsible for the lifecycle of the project file (create/open/move/close), for keeping the
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
  /// The extension used by project files, without the leading dot.
  ///
  /// The one definition lives in [ocptProjectFileExtension], which the package service reads too:
  /// a service may not import this manager, and the extension restated on the way down is one that
  /// could drift from the file this manager actually writes.
  static const projectFileExtension = ocptProjectFileExtension;

  /// The logger category linked to this manager.
  static const _loggerCategory = "projects";

  /// The name of the folder created inside the platform's documents directory to hold projects
  /// created/saved without the user picking a different location.
  static const _defaultProjectsDirectoryName = "OpenCineProdTools";

  /// The app version stamped into newly created and migrated projects' `project_info` (see
  /// [createProject] and `_gateOnFileFormat`).
  ///
  /// Read from a `--dart-define=APP_VERSION=...` the CI passes at build time
  /// (`.github/workflows/build.yml`'s `get-version` job, itself derived from `git describe` on the
  /// git tag), so a build off a stable tag carries a bare semver and every other build carries a
  /// pre-release suffix, per `docs/adr/0029-schema-versions-frozen-at-stable-releases.md`. The
  /// default is the local/dev fallback used whenever no such define is passed — `flutter test`
  /// included — and must be kept in sync with the `version` entry of `pubspec.yaml`. It stays a
  /// compile-time const (rather than read from the platform, e.g. via a package-info plugin) so
  /// this manager stays fully testable with `flutter test`, without a platform channel.
  // This is precisely the one legitimate use the lint's own rationale carves out: a build-time
  // value the CI passes deliberately (`--dart-define=APP_VERSION=...`), with a documented,
  // version-controlled default for every build that doesn't pass one.
  // ignore: do_not_use_environment
  static const _appVersion = String.fromEnvironment("APP_VERSION", defaultValue: "0.3.0");

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

  /// The service used for CRUD over a screenplay's storyboard: its shots' panels and their
  /// annotation layer.
  final OcptStoryboardService storyboardService;

  /// The service used for CRUD over a screenplay's floor plans: each Resources set's symbols and
  /// arrows.
  final OcptFloorPlanService floorPlanService;

  /// The service used for CRUD over the people seen for a part, and for the one rule saying which
  /// of them the part is cast with.
  final OcptRoleCandidatesService roleCandidatesService;

  /// The service used for CRUD over locations and their sets.
  final OcptLocationsService locationsService;

  /// The service used for CRUD over the physical elements catalogue.
  final OcptElementsService elementsService;

  /// The service used for CRUD over the budget mode's quote: the `budget_postes` catalogue and the
  /// `budget_lines` inside each one.
  final OcptBudgetQuoteService budgetQuoteService;

  /// The service used for CRUD over the budget mode's cash journal: the `budget_entries` movements
  /// and the `budget_commitments` still owed against an account.
  final OcptBudgetJournalService budgetJournalService;

  /// The service used for CRUD over the budget mode's financing plan: the `budget_resources`
  /// catalogue and the `budget_mileage_rates` a production names for itself.
  final OcptBudgetFinancingService budgetFinancingService;

  /// The service used for CRUD over the budget mode's defrayals: the `budget_allowances` a
  /// production types for itself, which nothing deduces from the schedule.
  final OcptBudgetAllowancesService budgetAllowancesService;

  /// The service used for CRUD over the budget mode's revenue sharing: the `budget_revenues`
  /// takings and the `budget_shares` splitting what they bring in.
  final OcptBudgetSharingService budgetSharingService;

  /// The service used to tag a screenplay passage against an element, a role or a set, and to
  /// track a scene's own breakdown status.
  final OcptBreakdownService breakdownService;

  /// The service used for CRUD over the shooting schedule: its days, their convocation windows and
  /// convocations, and each day's timetable.
  final OcptScheduleService scheduleService;

  /// The service used to mint and tombstone the `assets` rows referencing a file — a headshot, a
  /// scouting photo, an element's photo, a signed release.
  final OcptAssetsService assetsService;

  /// The service used to learn, unlearn and read back the words this project's writer has taught
  /// the spell checker.
  final OcptProjectDictionaryService projectDictionaryService;

  /// The service used to write the project out as a portable package, and to read one back.
  final OcptProjectPackageService projectPackageService;

  /// The service reading a project file's own format before anything opens it, and keeping the
  /// copy a migration is answered with.
  final OcptProjectFileCompatibilityService projectFileCompatibilityService;

  /// The logger this manager writes to, and the parent of every service's own.
  final LogsHelper _logger;

  /// The properties manager used to persist the recently opened projects list.
  final OcptPropertiesManager _propertiesManager;

  /// The seam `_defaultScreenplayLanguageForAppLocale` reads the app's UI language through.
  final OcptAppLanguageCodeGetter _appLanguageCode;

  /// The manager [newProjectsDirectory] branches on to tell a desktop platform from a mobile one.
  final PlatformManager _platformManager;

  /// Whether a create/open/close operation is currently in progress.
  bool _isBusy;

  /// The callbacks the modes register to answer, at any moment, whether they hold changes that
  /// haven't reached the database yet.
  ///
  /// See [registerUnsavedChangesReporter] for why this manager has to ask at all.
  final List<bool Function()> _unsavedChangesReporters;

  /// The project currently open, if any, with a stream to react to it changing.
  ///
  /// This uses [ValueKeeperWithStream] (rather than `ValueKeeperWithStreamAndNullInit`, whose
  /// setter only accepts a non-null value once past its initial state) because a project needs to
  /// be freely settable back to null whenever it's closed.
  late final ValueKeeperWithStream<OcptOpenProjectModel?> _currentProject;

  /// Get the running build's own app version — see [_appVersion]'s own doc comment for where it
  /// comes
  /// from and why it defaults the way it does.
  ///
  /// Exposed alongside it rather than duplicated: the Partager screen's own pairing call
  /// (`docs/architecture/sync.md`) stamps a freshly published snapshot with this same
  /// version, through `OcptSyncManager.pairProjectToRelay`, and reading it here is what keeps that
  /// one string from drifting out of step with what [createProject] and `_gateOnFileFormat` already
  /// stamp into a project file.
  String get appVersion => _appVersion;

  /// Get the project currently open, or null if none is.
  OcptOpenProjectModel? get currentProject => _currentProject.value;

  /// Emit the project currently open (or null) every time it changes.
  Stream<OcptOpenProjectModel?> get currentProjectStream => _currentProject.valueStream;

  /// Tell whether any mode currently reports changes that haven't reached the database yet.
  bool get hasUnsavedChanges => _unsavedChangesReporters.any((reporter) => reporter());

  /// Class constructor
  ///
  /// [appLanguageCode] is the injectable seam over reading the app's own UI language, defaulting
  /// to [LocalesManager]'s `currentLocale`, and read only when a project is created
  /// (`_defaultScreenplayLanguageForAppLocale`) — never when this manager is built, so a test only
  /// needs to hand one in when it creates a project.
  ///
  /// [platformManager] is not resolved through [globalGetIt] like the managers above:
  /// [PlatformManager]'s own constructor is a synchronous, side-effect-free read of the real
  /// platform, so building one directly here is exactly as correct as the registered singleton
  /// would be, and it keeps this manager's own tests from having to register it —
  /// `OcptExportManager`'s own constructor follows the same reasoning.
  OcptProjectsManager({
    OcptPropertiesManager? propertiesManager,
    OcptAppLanguageCodeGetter? appLanguageCode,
    PlatformManager? platformManager,
  }) : this._(
         logger: buildOcptLogsHelper(_loggerCategory),
         propertiesManager: propertiesManager,
         appLanguageCode: appLanguageCode,
         platformManager: platformManager,
       );

  /// Class constructor, taking the one logger the services built here are given sub-loggers of.
  ///
  /// A constructor initializer list cannot see `this`, so the logger is built once by the public
  /// constructor and handed down as a parameter.
  OcptProjectsManager._({
    required LogsHelper logger,
    required OcptPropertiesManager? propertiesManager,
    required OcptAppLanguageCodeGetter? appLanguageCode,
    required PlatformManager? platformManager,
  }) : this._withServices(
         logger: logger,
         services: OcptProjectsServices(logger: logger, propertiesManager: propertiesManager),
         propertiesManager: propertiesManager,
         appLanguageCode: appLanguageCode,
         platformManager: platformManager,
       );

  /// Class constructor, taking the services already built for this manager.
  OcptProjectsManager._withServices({
    required LogsHelper logger,
    required OcptProjectsServices services,
    required OcptPropertiesManager? propertiesManager,
    required OcptAppLanguageCodeGetter? appLanguageCode,
    required PlatformManager? platformManager,
  }) : _isBusy = false,
       _unsavedChangesReporters = <bool Function()>[],
       _logger = logger,
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _appLanguageCode = appLanguageCode ?? _localesManagerLanguageCode,
       _platformManager = platformManager ?? PlatformManager(),
       sceneIndexService = services.sceneIndexService,
       shotListService = services.shotListService,
       shotCoverageService = services.shotCoverageService,
       projectVersionsService = services.projectVersionsService,
       screenplayService = services.screenplayService,
       peopleService = services.peopleService,
       roleIndexService = services.roleIndexService,
       roleCandidatesService = services.roleCandidatesService,
       locationsService = services.locationsService,
       elementsService = services.elementsService,
       budgetQuoteService = services.budgetQuoteService,
       budgetJournalService = services.budgetJournalService,
       budgetFinancingService = services.budgetFinancingService,
       budgetAllowancesService = services.budgetAllowancesService,
       budgetSharingService = services.budgetSharingService,
       assetsService = services.assetsService,
       storyboardService = services.storyboardService,
       floorPlanService = services.floorPlanService,
       projectDictionaryService = services.projectDictionaryService,
       projectPackageService = services.projectPackageService,
       projectFileCompatibilityService = services.projectFileCompatibilityService,
       breakdownService = services.breakdownService,
       scheduleService = services.scheduleService;

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    _currentProject = ValueKeeperWithStream<OcptOpenProjectModel?>(value: null);
    await sceneIndexService.initLifeCycle();
    await shotListService.initLifeCycle();
    await shotCoverageService.initLifeCycle();
    await projectVersionsService.initLifeCycle();
    await screenplayService.initLifeCycle();
    await peopleService.initLifeCycle();
    await roleIndexService.initLifeCycle();
    await roleCandidatesService.initLifeCycle();
    await locationsService.initLifeCycle();
    await elementsService.initLifeCycle();
    await budgetQuoteService.initLifeCycle();
    await budgetJournalService.initLifeCycle();
    await budgetFinancingService.initLifeCycle();
    await budgetAllowancesService.initLifeCycle();
    await budgetSharingService.initLifeCycle();
    await assetsService.initLifeCycle();
    await storyboardService.initLifeCycle();
    await floorPlanService.initLifeCycle();
    await projectDictionaryService.initLifeCycle();
    await projectPackageService.initLifeCycle();
    await projectFileCompatibilityService.initLifeCycle();
    await breakdownService.initLifeCycle();
    await scheduleService.initLifeCycle();

    _logger.i("The projects manager started");
  }

  /// Get the app's own projects folder, Documents/OpenCineProdTools, creating it if it doesn't
  /// already
  /// exist: what [suggestedProjectsDirectory] proposes until a dialog has landed a project
  /// elsewhere, and where [newProjectsDirectory] puts one on desktop.
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

  /// Tell where a new project's `.ocpt` lands when no dialog lets the user choose —
  /// [createProject]'s
  /// callers turn it into an actual file path through [freeNewProjectFilePath], which never names
  /// a file already there.
  ///
  /// That is Android/iOS, where `file_selector` has no save-file or folder dialog: the app's own
  /// documents directory. Desktop always shows a dialog instead; it gets
  /// [getDefaultProjectsDirectory] here only so this never answers with nothing.
  Future<Directory> newProjectsDirectory() async {
    if (_platformManager.isMobile) {
      return getApplicationDocumentsDirectory();
    }

    return getDefaultProjectsDirectory();
  }

  /// Get the first free `.ocpt` path for a project named [name] inside [newProjectsDirectory] — see
  /// [ocptFreeFilePath] for the numbering a name already taken there is given.
  Future<String> freeNewProjectFilePath(String name) async {
    final directory = await newProjectsDirectory();

    return ocptFreeFilePath(
      directoryPath: directory.path,
      baseName: name,
      extension: projectFileExtension,
      exists: (path) => File(path).existsSync(),
    );
  }

  /// Get the folder a native save-file or folder-picker dialog opens in when creating, importing,
  /// joining or moving a project on desktop: [OcptPropertiesManager.lastProjectsDirectory]'s own
  /// folder, when it is still there, or [getDefaultProjectsDirectory] the very first time, or again
  /// once a remembered folder has since been deleted from under the app.
  Future<String> suggestedProjectsDirectory() async {
    final remembered = await _propertiesManager.lastProjectsDirectory.load();
    if (remembered != null && Directory(remembered).existsSync()) {
      return remembered;
    }

    return (await getDefaultProjectsDirectory()).path;
  }

  /// Remember [directoryPath] as the folder [suggestedProjectsDirectory] proposes next time —
  /// called after every create, import, join and move that actually lands a project there.
  Future<void> rememberProjectsDirectory(String directoryPath) =>
      _propertiesManager.lastProjectsDirectory.store(directoryPath);

  /// Create a new project named [name] at [filePath], seed it with a single empty screenplay —
  /// episode 1 (`number: 1`), given a real first `sortKey` rather than left at the column
  /// defaults, so a project made today looks exactly like one that came through the schema version
  /// 18 migration (`docs/adr/0019-one-project-several-episodes.md`) — registers it in the recent
  /// projects list, and makes it the [currentProject].
  Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> createProject({
    required String name,
    required String filePath,
  }) async {
    if (_isBusy) {
      return const ResultWithStatus(status: OcptProjectStatus.alreadyOpen);
    }
    _isBusy = true;

    try {
      return await OcptProjectOpenOps.createProject(
        name: name,
        filePath: filePath,
        currentProject: currentProject,
        appVersion: _appVersion,
        appLanguageCode: _appLanguageCode,
        logger: _logger,
        propertiesManager: _propertiesManager,
        onCreated: (project) => _currentProject.value = project,
        closeCurrentProject: closeCurrentProject,
        rememberProjectsDirectory: rememberProjectsDirectory,
      );
    } finally {
      _isBusy = false;
    }
  }

  /// Read which format the project file at [filePath] is in, and what that means for this build,
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
        appVersion: _appVersion,
      );

  /// Open the project stored at [filePath], register it in the recent projects list, and makes
  /// it the [currentProject].
  Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> openProject({
    required String filePath,
    bool allowMigration = false,
  }) async {
    if (_isBusy) {
      return const ResultWithStatus(status: OcptProjectStatus.alreadyOpen);
    }
    _isBusy = true;

    try {
      return await OcptProjectOpenOps.openProject(
        filePath: filePath,
        allowMigration: allowMigration,
        currentProject: currentProject,
        appVersion: _appVersion,
        logger: _logger,
        propertiesManager: _propertiesManager,
        projectFileCompatibilityService: projectFileCompatibilityService,
        screenplayService: screenplayService,
        probeProjectFile: probeProjectFile,
        onOpened: (project) => _currentProject.value = project,
        closeCurrentProject: closeCurrentProject,
      );
    } finally {
      _isBusy = false;
    }
  }

  /// Load the page format stored in the [currentProject]'s `project_info` table, or null if no
  /// project is currently open.
  Future<OcptPageFormat?> loadCurrentProjectPageFormat() =>
      OcptProjectSettingsOps.loadCurrentProjectPageFormat(project: currentProject);

  /// Update the page format stored in the [currentProject]'s `project_info` table. Does nothing if
  /// no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectPageFormat(OcptPageFormat format) =>
      OcptProjectSettingsOps.saveCurrentProjectPageFormat(project: currentProject, format: format);

  /// Load the ISO 4217 currency code stored in the [currentProject]'s `project_info` table, or
  /// null if no project is currently open.
  Future<String?> loadCurrentProjectCurrencyCode() =>
      OcptProjectSettingsOps.loadCurrentProjectCurrencyCode(project: currentProject);

  /// Update the currency code stored in the [currentProject]'s `project_info` table. Does nothing
  /// if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectCurrencyCode(String code) =>
      OcptProjectSettingsOps.saveCurrentProjectCurrencyCode(project: currentProject, code: code);

  /// Load the minimum rest, in minutes, stored in the [currentProject]'s `project_info` table, or
  /// null.
  Future<int?> loadCurrentProjectMinimumRestMinutes() =>
      OcptProjectSettingsOps.loadCurrentProjectMinimumRestMinutes(project: currentProject);

  /// Update the minimum rest, in minutes, stored in the [currentProject]'s `project_info` table, or
  /// clear it when [minutes] is null — a production that decides it no longer wants to record
  /// one is as real a gesture as setting it. Does nothing if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectMinimumRestMinutes(int? minutes) =>
      OcptProjectSettingsOps.saveCurrentProjectMinimumRestMinutes(
        project: currentProject,
        minutes: minutes,
      );

  /// Load the screenplay language stored in the [currentProject]'s `project_info` table, or null.
  Future<OcptScreenplayLanguage?> loadCurrentProjectScreenplayLanguage() =>
      OcptProjectSettingsOps.loadCurrentProjectScreenplayLanguage(project: currentProject);

  /// Update the screenplay language stored in the [currentProject]'s `project_info` table, or clear
  /// it when [language] is null — a writer who decides the checker should stay off this
  /// screenplay is making as real a choice as picking one of the two bundled languages. Does
  /// nothing if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage? language) =>
      OcptProjectSettingsOps.saveCurrentProjectScreenplayLanguage(
        project: currentProject,
        language: language,
      );

  /// Load the default VAT rate, in basis points, stored in the [currentProject]'s `project_info`
  /// table, or null.
  Future<int?> loadCurrentProjectDefaultVatRateBasisPoints() =>
      OcptProjectSettingsOps.loadCurrentProjectDefaultVatRateBasisPoints(project: currentProject);

  /// Update the default VAT rate, in basis points, stored in the [currentProject]'s `project_info`
  /// table, or clear it when [basisPoints] is null — a production putting the rate back to "not
  /// recorded" is as real a gesture as setting it (`OcptProjectSettingsBudgetSection`'s `No rate`
  /// button). Does nothing if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectDefaultVatRateBasisPoints(int? basisPoints) =>
      OcptProjectSettingsOps.saveCurrentProjectDefaultVatRateBasisPoints(
        project: currentProject,
        basisPoints: basisPoints,
      );

  /// Load the price of one meal, in cents, stored in the [currentProject]'s `project_info` table,
  /// or null — the same "nobody has said" reading [loadCurrentProjectDefaultVatRateBasisPoints]
  /// gets.
  Future<int?> loadCurrentProjectMealPriceCents() =>
      OcptProjectSettingsOps.loadCurrentProjectMealPriceCents(project: currentProject);

  /// Update the price of one meal, in cents, stored in the [currentProject]'s `project_info` table,
  /// or clear it when [cents] is null. Does nothing if no project is currently open.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectMealPriceCents(int? cents) =>
      OcptProjectSettingsOps.saveCurrentProjectMealPriceCents(
        project: currentProject,
        cents: cents,
      );

  /// Load the price of the buffet, in cents, stored in the [currentProject]'s `project_info`
  /// table, or null — [loadCurrentProjectMealPriceCents]'s sibling, read the same way. **Named
  /// after the column it reads, `project_info.snackPriceCents`, kept for the schema (ADR 0007's
  /// schema-number rule); the UI names this figure the buffet, or craft services, never a snack.**
  Future<int?> loadCurrentProjectSnackPriceCents() =>
      OcptProjectSettingsOps.loadCurrentProjectSnackPriceCents(project: currentProject);

  /// Update the price of the buffet, in cents, stored in the [currentProject]'s `project_info`
  /// table, or clear it when [cents] is null — [saveCurrentProjectMealPriceCents]'s sibling. See
  /// [loadCurrentProjectSnackPriceCents]'s own doc comment for why this keeps the column's name.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveCurrentProjectSnackPriceCents(int? cents) =>
      OcptProjectSettingsOps.saveCurrentProjectSnackPriceCents(
        project: currentProject,
        cents: cents,
      );

  /// List the [currentProject]'s versions, newest first, or an empty list if no project is open.
  ///
  /// {@template open_cine_prod_tools.OcptProjectsManager.versionOperations}
  /// The version operations live here rather than being called on [projectVersionsService]
  /// directly, because the service is handed facts only this manager holds: the open project's
  /// database, the app version, this replica's device id and the app-wide page margins.
  ///
  /// They are also the only operations of the app that go through
  /// [OcptOpenProjectModel.fileDatabase] rather than [OcptOpenProjectModel.database]: the version
  /// list belongs to the project file, and stays readable and editable while a preview is on
  /// screen — deleting a version you happen not to be previewing is perfectly legitimate then. A
  /// failure of the file raises a [StateError], until this manager answers a result of its own.
  /// {@endtemplate}
  Future<List<OcptProjectVersion>> listProjectVersions() async {
    final project = currentProject;
    if (project == null) {
      return const [];
    }

    final listed = await projectVersionsService.listVersions(database: project.fileDatabase);
    if (listed.isError) {
      throw StateError("The project versions could not be listed");
    }

    return listed.value!;
  }

  /// Capture the [currentProject] as a new version named [name], with the user's [note], and return
  /// it. Returns null if no project is open.
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

    final created = await projectVersionsService.createVersion(
      database: project.fileDatabase,
      name: name,
      note: note,
      appVersion: _appVersion,
      deviceId: await _propertiesManager.loadOrCreateDeviceId(),
      pageMargins: await _loadPageMargins(),
    );
    if (created.isError) {
      throw StateError("The project version could not be created");
    }

    return created.value;
  }

  /// Rename the version [versionId] of the [currentProject] to [name], replacing its [note]. Does
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

    final renamed = await projectVersionsService.renameVersion(
      database: project.fileDatabase,
      id: versionId,
      name: name,
      note: note,
    );
    if (renamed.isError) {
      throw StateError("The project version could not be renamed");
    }
  }

  /// Measure the [currentProject]'s working copy exactly as
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

    final captured = await projectVersionsService.captureWorkingCopyState(
      database: project.fileDatabase,
      pageMargins: await _loadPageMargins(),
    );
    if (captured.isError) {
      throw StateError("The working copy could not be measured");
    }

    return captured.value;
  }

  /// Delete the version [versionId] of the [currentProject]. Does nothing if no project is open,
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
      _logger.w(
        "The project version $versionId can't be deleted while it's the one being previewed: "
        "leave the preview first",
      );
      return;
    }

    final deleted = await projectVersionsService.deleteVersion(
      database: project.fileDatabase,
      id: versionId,
    );
    if (deleted.isError) {
      throw StateError("The project version could not be deleted");
    }
  }

  /// Put the [currentProject] back into the state the version [versionId] captured, keeping the
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

  /// Register [reporter], which answers whether the caller holds changes that haven't reached the
  /// database yet, and return the callback that unregisters it.
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

  /// Enter the read-only preview of the version [versionId] of the [currentProject]: the version's
  /// payload is hydrated into an in-memory database, and *that* is what [currentProject] hands the
  /// modes from now on.
  Future<ResultWithStatus<OcptProjectPreviewStatus, OcptOpenProjectModel>> previewVersion(
    String versionId,
  ) => OcptProjectPreviewOps.previewVersion(
    project: currentProject,
    versionId: versionId,
    hasUnsavedChanges: hasUnsavedChanges,
    projectVersionsService: projectVersionsService,
    logger: _logger,
    onPreviewed: (previewedProject) => _currentProject.value = previewedProject,
  );

  /// Leave the read-only preview, putting the working copy back on screen. Does nothing if no
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

    _logger.i("Left the preview of a project version");
  }

  /// Stat every file the project stored at [projectFilePath] references, without writing
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

  /// Write the project stored at [projectFilePath] out as a portable package at [packageFilePath],
  /// and report what travelled.
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

  /// Unpack the package at [packageFilePath] into a new folder inside [parentDirectoryPath], and
  /// report what landed.
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

  /// Close the [currentProject], disposing its database handle. Does nothing if no project is
  /// open.
  Future<void> closeCurrentProject() => OcptProjectEpisodeOps.closeProject(
    project: currentProject,
    screenplayService: screenplayService,
    propertiesManager: _propertiesManager,
    logger: _logger,
    onClosed: () => _currentProject.value = null,
  );

  /// Update the recent-projects entry for the [currentProject] so it carries the episode count
  /// the project holds right now. Does nothing when no project is open.
  Future<void> recordCurrentProjectEpisodeCount() =>
      OcptProjectEpisodeOps.recordOpenProjectEpisodeCount(
        project: currentProject,
        screenplayService: screenplayService,
        propertiesManager: _propertiesManager,
      );

  /// Move the [currentProject]'s file to [newFilePath] — the project settings page's own `Move…`
  /// action — and keep it the [currentProject] there.
  Future<ResultWithStatus<OcptProjectMoveStatus, OcptOpenProjectModel>> moveCurrentProject({
    required String newFilePath,
  }) => OcptProjectMoveOps.moveProject(
    project: currentProject,
    newFilePath: newFilePath,
    logger: _logger,
    propertiesManager: _propertiesManager,
    onSwapped: (movedProject) => _currentProject.value = movedProject,
    rememberProjectsDirectory: rememberProjectsDirectory,
  );

  /// Get the app-wide page margins a version is measured and restored against, falling back to the
  /// standard ones while the user has never set any.
  Future<FountainPageMargins> _loadPageMargins() async =>
      await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard();

  /// Get the default [OcptAppLanguageCodeGetter]: the language of the app's own UI locale, as
  /// [LocalesManager] holds it.
  ///
  /// Resolved through [globalGetIt] at call time rather than when this manager is built, so
  /// nothing needs that manager registered until a project is actually created.
  static String _localesManagerLanguageCode() =>
      globalGetIt().get<LocalesManager>().currentLocale.languageCode;

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    _logger.i("The projects manager is being disposed");
    await closeCurrentProject();
    await _currentProject.disposeLifeCycle();
    await scheduleService.disposeLifeCycle();
    await breakdownService.disposeLifeCycle();
    await projectFileCompatibilityService.disposeLifeCycle();
    await projectPackageService.disposeLifeCycle();
    await projectDictionaryService.disposeLifeCycle();
    await floorPlanService.disposeLifeCycle();
    await storyboardService.disposeLifeCycle();
    await assetsService.disposeLifeCycle();
    await budgetSharingService.disposeLifeCycle();
    await budgetAllowancesService.disposeLifeCycle();
    await budgetFinancingService.disposeLifeCycle();
    await budgetJournalService.disposeLifeCycle();
    await budgetQuoteService.disposeLifeCycle();
    await elementsService.disposeLifeCycle();
    await locationsService.disposeLifeCycle();
    await roleCandidatesService.disposeLifeCycle();
    await roleIndexService.disposeLifeCycle();
    await peopleService.disposeLifeCycle();
    await screenplayService.disposeLifeCycle();
    await projectVersionsService.disposeLifeCycle();
    await shotCoverageService.disposeLifeCycle();
    await shotListService.disposeLifeCycle();
    await sceneIndexService.disposeLifeCycle();
    return super.disposeLifeCycle();
  }
}
