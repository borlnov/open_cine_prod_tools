// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_open_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_preview_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_move_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../ocpt_result_expectations.dart';

/// A properties manager that cannot record a recent project, which is the last step of creating
/// or opening a project.
class _ThrowingPropertiesManager extends OcptPropertiesManager {
  /// Fail as a store that cannot be written does.
  @override
  Future<void> addRecentProject(OcptRecentProjectModel project) async =>
      throw const FileSystemException("recent projects unavailable");
}

/// A versions service whose preview hydration always fails.
class _ThrowingHydrationService extends OcptProjectVersionsService {
  /// The database each hydration was asked to fill.
  final hydrated = <OcptProjectDatabase>[];

  /// Class constructor
  _ThrowingHydrationService({required super.screenplayService})
    : super(
        logger: const SilentLogger(),
        codec: const OcptProjectVersionCodec(logger: SilentLogger()),
      );

  /// Fail as a payload that cannot be applied does.
  @override
  Future<OcptDatabaseOutcome> hydratePreview({
    required OcptProjectDatabase database,
    required OcptProjectInfoRow projectInfo,
    required OcptProjectVersionPayload payload,
  }) async {
    hydrated.add(database);
    // A database nobody has used yet is not open, so closing it would prove nothing.
    await database.select(database.ocptScreenplaysTable).get();

    return const OcptDatabaseOutcome(
      status: OcptDatabaseStatus.databaseError,
      extraInfo: "hydration failed",
    );
  }
}

/// A versions service whose payload read always fails.
class _FailingPayloadService extends OcptProjectVersionsService {
  /// Class constructor
  _FailingPayloadService({required super.screenplayService})
    : super(
        logger: const SilentLogger(),
        codec: const OcptProjectVersionCodec(logger: SilentLogger()),
      );

  /// Fail as a payload that cannot be read does.
  @override
  Future<
    OcptDatabaseResult<ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload>>
  >
  loadPayload({required OcptProjectDatabase database, required String id}) async =>
      const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "payload unreadable",
      );
}

/// A screenplay service whose project-open snapshot and episodes read fail with the type of
/// failure each is given, `null` leaving the step to the real service.
class _RefusingScreenplayService extends OcptScreenplayService {
  /// The type of what the snapshot fails with, or null for no failure.
  Type? snapshotFailure;

  /// The type of what the episodes read fails with, or null for no failure.
  Type? episodesFailure;

  /// Class constructor
  _RefusingScreenplayService(OcptProjectsManager manager)
    : super(
        logger: const SilentLogger(),
        sceneIndexService: manager.sceneIndexService,
        shotListService: manager.shotListService,
        shotCoverageService: manager.shotCoverageService,
        roleIndexService: manager.roleIndexService,
        breakdownService: manager.breakdownService,
        scheduleService: manager.scheduleService,
        deviceId: manager.screenplayService.deviceId,
      );

  /// Fail as told, otherwise take the snapshot as the real service does.
  @override
  Future<OcptDatabaseOutcome> snapshotOnProjectOpen({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final failure = snapshotFailure;
    if (failure != null) {
      return OcptDatabaseOutcome(status: OcptDatabaseStatus.databaseError, extraInfo: failure);
    }

    return super.snapshotOnProjectOpen(database: database, screenplayId: screenplayId);
  }

  /// Fail as told, otherwise read the episodes as the real service does.
  @override
  Future<OcptDatabaseResult<List<OcptEpisode>>> loadEpisodes({
    required OcptProjectDatabase database,
  }) async {
    final failure = episodesFailure;
    if (failure != null) {
      return OcptDatabaseResult(status: OcptDatabaseStatus.databaseError, extraInfo: failure);
    }

    return super.loadEpisodes(database: database);
  }
}

/// The soft failures of the projects manager: each is logged and answered as a status.
void main() {
  late OcptPropertiesManager propertiesManager;
  late Directory tempDir;
  late OcptProjectsManager manager;

  setUpAll(() async {
    OcptGlobalManager.instance;
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_projects_failures_");
    manager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await manager.initLifeCycle();
  });

  tearDown(() async {
    await manager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// A path under a regular file, which no folder can be created at.
  String pathUnderAFile(String name) {
    final blocker = File(p.join(tempDir.path, "blocker"))..writeAsStringSync("x");
    return p.join(blocker.path, name);
  }

  test("createProject answers ioError when the folder cannot be created", () async {
    final result = await manager.createProject(
      name: "My Movie",
      filePath: pathUnderAFile("movie.ocpt"),
    );

    expect(result.status, OcptProjectStatus.ioError);
    expect(manager.currentProject, isNull);
  });

  test("openProject answers ioError when a step after the file is read fails", () async {
    final path = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: path);
    await manager.closeCurrentProject().okOrFail;

    final failing = OcptProjectsManager(
      propertiesManager: _ThrowingPropertiesManager(),
      appLanguageCode: () => "en",
    );
    await failing.initLifeCycle();
    final result = await failing.openProject(filePath: path);

    expect(result.status, OcptProjectStatus.ioError);
  });

  test("moveCurrentProject answers ioError when the target folder cannot be created", () async {
    final oldPath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: oldPath);

    final result = await manager.moveCurrentProject(newFilePath: pathUnderAFile("movie.ocpt"));

    expect(result.status, OcptProjectMoveStatus.ioError);
    expect(manager.currentProject?.path, oldPath);
    expect(File(oldPath).existsSync(), isTrue);
  });

  test("previewVersion answers hydrationFailed when the preview cannot be hydrated", () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final version = await manager.createProjectVersion(name: "v1", note: "").valueOrFail;

    final result = await OcptProjectPreviewOps.previewVersion(
      project: manager.currentProject,
      versionId: version.id,
      hasUnsavedChanges: false,
      projectVersionsService: _ThrowingHydrationService(
        screenplayService: manager.screenplayService,
      ),
      logger: buildOcptLogsHelper("test"),
      onPreviewed: (_) {},
    );

    expect(result.status, OcptProjectPreviewStatus.hydrationFailed);
  });

  test("a preview that cannot be hydrated is closed, and the working copy stays", () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final version = await manager.createProjectVersion(name: "v1", note: "").valueOrFail;
    final service = _ThrowingHydrationService(screenplayService: manager.screenplayService);
    final before = manager.currentProject;

    await OcptProjectPreviewOps.previewVersion(
      project: manager.currentProject,
      versionId: version.id,
      hasUnsavedChanges: false,
      projectVersionsService: service,
      logger: buildOcptLogsHelper("test"),
      onPreviewed: (_) {},
    );

    expect(service.hydrated, hasLength(1));
    final preview = service.hydrated.single;
    await expectLater(preview.select(preview.ocptScreenplaysTable).get(), throwsA(anything));
    expect(manager.currentProject, same(before));
  });

  test("a preview whose payload cannot be read answers databaseError, project untouched", () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final version = await manager.createProjectVersion(name: "v1", note: "").valueOrFail;
    final before = manager.currentProject;
    var previewed = false;

    final result = await OcptProjectPreviewOps.previewVersion(
      project: manager.currentProject,
      versionId: version.id,
      hasUnsavedChanges: false,
      projectVersionsService: _FailingPayloadService(screenplayService: manager.screenplayService),
      logger: buildOcptLogsHelper("test"),
      onPreviewed: (_) => previewed = true,
    );

    expect(result.status, OcptProjectPreviewStatus.databaseError);
    expect(previewed, isFalse);
    expect(manager.currentProject, same(before));
  });

  group("a project whose episodes cannot be read", () {
    late String secondId;

    setUp(() async {
      await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
      secondId = await manager.screenplayService
          .createEpisode(database: manager.currentProject!.database, title: "Two")
          .valueOrFail;
      await manager.currentProject!.database.customStatement(
        "UPDATE screenplays SET number = 'unreadable' WHERE id = '$secondId'",
      );
    });

    tearDown(() async {
      await manager.currentProject?.database.customStatement(
        "UPDATE screenplays SET number = 2 WHERE id = '$secondId'",
      );
    });

    test("is not closed, and closing it answers the failure of the read", () async {
      final closed = await manager.closeCurrentProject();

      expect(closed.status, OcptDatabaseStatus.databaseError);
      expect(closed.extraInfo, FormatException);
      expect(manager.currentProject, isNotNull);
    });

    test("records no episode count, and recording it answers the failure", () async {
      final recorded = await manager.recordCurrentProjectEpisodeCount();

      expect(recorded.status, OcptDatabaseStatus.databaseError);
      expect(recorded.extraInfo, FormatException);
    });
  });

  group("a version operation answers a failure when the project file cannot answer it", () {
    late String versionId;

    setUp(() async {
      await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
      versionId = (await manager.createProjectVersion(name: "v1", note: "").valueOrFail).id;
      await manager.currentProject!.fileDatabase.customStatement(
        "ALTER TABLE project_versions RENAME TO project_versions_gone",
      );
    });

    final operations = <String, Future<StatusWithExtraInfo<MixinResultStatus>> Function()>{};
    operations["listProjectVersions"] = () => manager.listProjectVersions();
    operations["createProjectVersion"] = () => manager.createProjectVersion(name: "v2", note: "");
    operations["renameProjectVersion"] = () =>
        manager.renameProjectVersion(versionId: versionId, name: "v1 bis", note: "");
    operations["deleteProjectVersion"] = () => manager.deleteProjectVersion(versionId);
    operations["captureWorkingCopyState"] = () => manager.captureWorkingCopyState();

    for (final entry in operations.entries) {
      test(entry.key, () async {
        final answer = await entry.value();

        expect(answer.status, OcptDatabaseStatus.databaseError);
        expect(answer.extraInfo, SqliteException);
      });
    }

    test("previewVersion", () async {
      final answer = await manager.previewVersion(versionId);

      expect(answer.status, OcptProjectPreviewStatus.databaseError);
      expect(answer.extraInfo, SqliteException);
    });

    test("a failed preview read leaves the working copy on screen", () async {
      final before = manager.currentProject;

      final answer = await manager.previewVersion(versionId);

      expect(answer.status, OcptProjectPreviewStatus.databaseError);
      expect(manager.currentProject, same(before));
      expect(manager.currentProject!.isReadOnly, isFalse);
    });
  });

  group("opening a project whose screenplay the database refuses", () {
    OcptProjectsManager? opened;

    /// Create a project at [path] holding a second episode, run [statement] in it, and close it.
    Future<String> prepare(String statement) async {
      final path = p.join(tempDir.path, "movie.ocpt");
      await manager.createProject(name: "My Movie", filePath: path);
      await manager.screenplayService
          .createEpisode(database: manager.currentProject!.database, title: "Two")
          .okOrFail;
      await manager.closeCurrentProject().okOrFail;
      sqlite3.open(path)
        ..execute(statement)
        ..dispose();

      return path;
    }

    /// Expect the database of the project the failed opening left behind to be closed.
    Future<void> expectDatabaseClosed() async {
      final database = opened!.currentProject!.database;

      await expectLater(database.select(database.ocptScreenplaysTable).get(), throwsA(anything));
    }

    /// Open [path] on a manager of its own: a project whose opening failed stays the current one,
    /// and closing it would read the episodes the opening could not.
    Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> openOnAFreshManager(
      String path,
    ) async {
      final opener = OcptProjectsManager(
        propertiesManager: propertiesManager,
        appLanguageCode: () => "en",
      );
      await opener.initLifeCycle();
      opened = opener;

      return opener.openProject(filePath: path);
    }

    test("the project-open snapshot that sqlite refuses answers corruptedFile", () async {
      final path = await prepare(
        "CREATE TRIGGER refuse_snapshots BEFORE INSERT ON screenplay_snapshots "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      final result = await openOnAFreshManager(path);

      expect(result.status, OcptProjectStatus.corruptedFile);
      await expectDatabaseClosed();
    });

    test("episodes that cannot be read at opening answer ioError", () async {
      final path = await prepare(
        "UPDATE screenplays SET number = 'unreadable' WHERE title = 'Two'",
      );

      final result = await openOnAFreshManager(path);

      expect(result.status, OcptProjectStatus.ioError);
      await expectDatabaseClosed();
    });
  });

  group("the verdict of an opening follows the type of the failure that stopped it", () {
    late String path;

    setUp(() async {
      path = p.join(tempDir.path, "movie.ocpt");
      await manager.createProject(name: "My Movie", filePath: path);
      await manager.closeCurrentProject().okOrFail;
    });

    /// Open [path] with [service] standing for the screenplay service, nothing else open.
    Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> openWith(
      OcptScreenplayService service,
    ) => OcptProjectOpenOps.openProject(
      filePath: path,
      allowMigration: false,
      currentProject: null,
      appVersion: manager.appVersion,
      logger: buildOcptLogsHelper("test"),
      propertiesManager: propertiesManager,
      projectFileCompatibilityService: manager.projectFileCompatibilityService,
      screenplayService: service,
      probeProjectFile: manager.probeProjectFile,
      onOpened: (_) {},
      closeCurrentProject: () async => const OcptDatabaseOutcome(status: OcptDatabaseStatus.ok),
    );

    test("a snapshot failing with a sqlite error answers corruptedFile", () async {
      final service = _RefusingScreenplayService(manager)..snapshotFailure = SqliteException;

      expect((await openWith(service)).status, OcptProjectStatus.corruptedFile);
    });

    test("a snapshot failing with another error answers ioError", () async {
      final service = _RefusingScreenplayService(manager)..snapshotFailure = StateError;

      expect((await openWith(service)).status, OcptProjectStatus.ioError);
    });

    test("an episodes read failing with a sqlite error answers corruptedFile", () async {
      final service = _RefusingScreenplayService(manager)..episodesFailure = SqliteException;

      expect((await openWith(service)).status, OcptProjectStatus.corruptedFile);
    });

    test("an episodes read failing with another error answers ioError", () async {
      final service = _RefusingScreenplayService(manager)..episodesFailure = StateError;

      expect((await openWith(service)).status, OcptProjectStatus.ioError);
    });

    group("closing the project that is open", () {
      late String otherPath;

      setUp(() async {
        otherPath = p.join(tempDir.path, "other.ocpt");
        await manager.createProject(name: "Other", filePath: otherPath);
        await manager.closeCurrentProject().okOrFail;
        await manager.openProject(filePath: path);
        await manager.screenplayService
            .createEpisode(database: manager.currentProject!.database, title: "Two")
            .okOrFail;
      });

      test("a sqlite error while counting the episodes answers corruptedFile", () async {
        await manager.currentProject!.fileDatabase.customStatement(
          "ALTER TABLE screenplays RENAME TO screenplays_gone",
        );

        final result = await manager.openProject(filePath: otherPath);

        expect(result.status, OcptProjectStatus.corruptedFile);
        expect(manager.currentProject!.path, path, reason: "the open project stays open");
      });

      test("another error while counting the episodes answers ioError", () async {
        await manager.currentProject!.fileDatabase.customStatement(
          "UPDATE screenplays SET number = 'unreadable' WHERE title = 'Two'",
        );

        final result = await manager.openProject(filePath: otherPath);

        expect(result.status, OcptProjectStatus.ioError);
        expect(manager.currentProject!.path, path);
      });
    });
  });
}
