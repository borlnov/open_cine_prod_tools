// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_dart_value_keeper/act_dart_value_keeper.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:uuid/uuid.dart';

/// Builds the [OcptProjectsManager] instance registered by the global manager.
class OcptProjectsManagerBuilder extends AbsLifeCycleFactory<OcptProjectsManager> {
  /// Class constructor
  const OcptProjectsManagerBuilder() : super(OcptProjectsManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, OcptPropertiesManager];
}

/// Owns the project the user currently has open, and every operation that creates, opens or
/// closes one.
///
/// Every Open Cine Prod Tools project is a single `.ocpt` SQLite file (an [OcptProjectDatabase]);
/// only one such file can be open at a time, exposed through [currentProject] and
/// [currentProjectStream]. Everything specific to reading/writing a screenplay's text, its scene
/// index, its shot list or its named versions is delegated to [screenplayService],
/// [sceneIndexService], [shotListService], [shotCoverageService] and [projectVersionsService], the
/// five services this manager owns and wires together (RFL18): this manager itself is only
/// responsible for the lifecycle of the project file (create/open/close), for keeping the
/// properties manager's recent-projects list in sync, and for handing those services the facts only
/// it holds — the open project's database, the app version, this replica's device id and the
/// app-wide page margins.
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
  static const projectFileExtension = "ocpt";

  /// The app version stored in newly created projects' `project_info.appVersionAtCreation`.
  ///
  /// This is a literal instead of being read from the platform (e.g. via a package-info plugin)
  /// so this manager stays fully testable with `flutter test`, without a platform channel: keep
  /// it in sync with the `version` entry of `pubspec.yaml`.
  static const _appVersion = "0.1.0";

  /// The properties manager used to persist the recently opened projects list.
  final OcptPropertiesManager _propertiesManager;

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
  OcptProjectsManager({OcptPropertiesManager? propertiesManager})
    : _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
      sceneIndexService = const OcptSceneIndexService(),
      shotListService = const OcptShotListService(),
      shotCoverageService = const OcptShotCoverageService(),
      projectVersionsService = const OcptProjectVersionsService(
        codec: OcptProjectVersionCodec(),
        screenplayService: OcptScreenplayService(
          sceneIndexService: OcptSceneIndexService(),
          shotListService: OcptShotListService(),
          shotCoverageService: OcptShotCoverageService(),
        ),
      ),
      screenplayService = const OcptScreenplayService(
        sceneIndexService: OcptSceneIndexService(),
        shotListService: OcptShotListService(),
        shotCoverageService: OcptShotCoverageService(),
      );

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

  /// Creates a new project named [name] at [filePath], seeds it with a single empty screenplay,
  /// registers it in the recent projects list, and makes it the [currentProject].
  ///
  /// If a project is already open, it's closed first. The project's page format defaults to
  /// [OcptPageFormat.a4] when the platform's locale is French, and to [OcptPageFormat.usLetter]
  /// otherwise.
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
            ),
          );

      final screenplayId = const Uuid().v4();
      await database
          .into(database.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(id: screenplayId, title: name, updatedAt: now),
          );

      final project = OcptOpenProjectModel(
        path: filePath,
        name: name,
        primaryScreenplayId: screenplayId,
        database: database,
      );
      _currentProject.value = project;

      await _propertiesManager.addRecentProject(
        OcptRecentProjectModel(path: filePath, name: name, lastOpenedAt: now),
      );

      return ResultWithStatus(status: OcptProjectStatus.ok, value: project);
    } catch (error) {
      appLogger().e("A problem occurred when tried to create the project '$name' at $filePath: "
          "$error");
      await database?.close();
      return const ResultWithStatus(status: OcptProjectStatus.ioError);
    } finally {
      _isBusy = false;
    }
  }

  /// Opens the project stored at [filePath], registers it in the recent projects list, and makes
  /// it the [currentProject].
  ///
  /// If a project is already open, it's closed first.
  Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> openProject({
    required String filePath,
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

      if (currentProject != null) {
        await closeCurrentProject();
      }

      database = OcptProjectDatabase(File(filePath));

      final info = await database.select(database.ocptProjectInfoTable).getSingleOrNull();
      final screenplay = await (database.select(
        database.ocptScreenplaysTable,
      )..limit(1)).getSingleOrNull();

      if (info == null || screenplay == null) {
        appLogger().w("The project file at $filePath is missing its project info or its "
            "screenplay, it's considered corrupted");
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

      await _propertiesManager.addRecentProject(
        OcptRecentProjectModel(path: filePath, name: info.name, lastOpenedAt: DateTime.now()),
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
      pageMargins:
          await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
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
      appLogger().w("The project version $versionId can't be deleted while it's the one being "
          "previewed: leave the preview first");
      return;
    }

    await projectVersionsService.deleteVersion(database: project.fileDatabase, id: versionId);
  }

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
      appLogger().w("The project version $versionId can't be previewed while a mode still holds "
          "unsaved changes: they must be saved first, or they would be written into the preview");
      return const ResultWithStatus(status: OcptProjectPreviewStatus.unsavedChanges);
    }

    final version = await projectVersionsService.loadVersion(
      database: project.fileDatabase,
      id: versionId,
    );

    if (version == null) {
      appLogger().w("The project version $versionId can't be previewed: no such version in this "
          "project");
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
      appLogger().e("A problem occurred when tried to hydrate the preview of the project version "
          "$versionId: $error");
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

  /// Closes the [currentProject], disposing its database handle. Does nothing if no project is
  /// open.
  ///
  /// A project closed while a version is being previewed disposes both of its connections: the
  /// in-memory one holding the version, then the project file itself.
  Future<void> closeCurrentProject() async {
    final project = currentProject;
    if (project == null) {
      return;
    }

    _currentProject.value = null;

    if (project.isReadOnly) {
      await project.database.close();
    }

    await project.fileDatabase.close();
  }

  /// Returns the default [OcptPageFormat] for a newly created project, based on the platform's
  /// current locale: [OcptPageFormat.a4] for French, [OcptPageFormat.usLetter] otherwise.
  static OcptPageFormat _defaultPageFormatForPlatformLocale() {
    final languageCode = PlatformDispatcher.instance.locale.languageCode;
    return languageCode == "fr" ? OcptPageFormat.a4 : OcptPageFormat.usLetter;
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    await closeCurrentProject();
    await _currentProject.disposeLifeCycle();
    return super.disposeLifeCycle();
  }
}
