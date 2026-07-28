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
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
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
/// index or its shot list is delegated to [screenplayService], [sceneIndexService],
/// [shotListService] and [shotCoverageService], the four services this manager owns and wires
/// together (RFL18): this manager itself is only responsible for the lifecycle of the project file
/// (create/open/close) and for keeping the properties manager's recent-projects list in sync.
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

  /// Whether a create/open/close operation is currently in progress.
  bool _isBusy = false;

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
  Future<void> saveCurrentProjectPageFormat(OcptPageFormat format) async {
    final project = currentProject;
    if (project == null) {
      return;
    }

    await project.database
        .update(project.database.ocptProjectInfoTable)
        .write(OcptProjectInfoTableCompanion(pageFormat: Value(format)));
  }

  /// Closes the [currentProject], disposing its database handle. Does nothing if no project is
  /// open.
  Future<void> closeCurrentProject() async {
    final project = currentProject;
    if (project == null) {
      return;
    }

    await project.database.close();
    _currentProject.value = null;
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
