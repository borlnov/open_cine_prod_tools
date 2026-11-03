// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_episode_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_move_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_move_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../ocpt_result_expectations.dart';

/// A project file database that refuses to close.
class _UncloseableFileDatabase extends OcptProjectDatabase {
  /// Class constructor
  _UncloseableFileDatabase(super.file);

  /// Refuse as a connection in a bad state does.
  @override
  Future<void> close() async => throw StateError("close refused");
}

/// A properties manager whose device id cannot be read.
class _NoDeviceIdPropertiesManager extends OcptPropertiesManager {
  /// Whether the device id cannot be read.
  bool refuse = false;

  /// Fail as a preferences store that cannot be read does, when told to.
  @override
  Future<String> loadOrCreateDeviceId() async {
    if (refuse) {
      throw StateError("preferences unavailable");
    }

    return super.loadOrCreateDeviceId();
  }
}

/// Where the projects manager stops when the episodes of the open project cannot be counted: the
/// restore that has already committed, the creation that has to close the project first, and the
/// disposal.
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_projects_stops_");
    manager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await manager.initLifeCycle();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Open a project at [name] holding a second episode whose number the database cannot read back.
  Future<String> openProjectWithUnreadableEpisodes(String name) async {
    final path = p.join(tempDir.path, name);
    await manager.createProject(name: "My Movie", filePath: path);
    final secondId = await manager.screenplayService
        .createEpisode(database: manager.currentProject!.database, title: "Two")
        .valueOrFail;
    await manager.currentProject!.database.customStatement(
      "UPDATE screenplays SET number = 'unreadable' WHERE id = '$secondId'",
    );

    return path;
  }

  test("a restore that committed but cannot count the episodes answers databaseError", () async {
    final path = p.join(tempDir.path, "movie.ocpt");
    final project = (await manager.createProject(name: "My Movie", filePath: path)).value!;
    await manager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: "INT. HOUSE - DAY\n\nCLARA enters.",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    final version = await manager.createProjectVersion(name: "v1", note: "").valueOrFail;
    await manager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: "EXT. STREET - NIGHT\n\nThe rewrite.",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    // The restore itself goes through, then leaves a number the episode count cannot read.
    await project.fileDatabase.customStatement(
      "CREATE TRIGGER unreadable_after_restore AFTER UPDATE ON screenplays "
      "BEGIN UPDATE screenplays SET number = 'unreadable' WHERE id = NEW.id; END",
    );

    final status = await manager.restoreProjectVersion(
      versionId: version.id,
      safetyVersionName: "Before",
    );

    expect(status, OcptProjectRestoreStatus.databaseError);
    final text = await project.fileDatabase
        .customSelect("SELECT fountain_text FROM screenplays")
        .getSingle();
    expect(
      text.read<String>("fountain_text"),
      "INT. HOUSE - DAY\n\nCLARA enters.",
      reason: "the restore had committed",
    );
  });

  test("creating a project while the open one cannot be closed creates nothing", () async {
    final oldPath = await openProjectWithUnreadableEpisodes("old.ocpt");
    final opened = manager.currentProject!;
    final newPath = p.join(tempDir.path, "new.ocpt");

    final result = await manager.createProject(name: "Other", filePath: newPath);

    expect(result.status, OcptProjectStatus.ioError);
    expect(File(newPath).existsSync(), isFalse);
    expect(manager.currentProject, same(opened));
    expect(manager.currentProject!.path, oldPath);
    final stillOpen = await opened.fileDatabase.customSelect("SELECT id FROM screenplays").get();
    expect(stillOpen, hasLength(2), reason: "the old database was not closed or changed");
  });

  test("disposing the manager stops when the open project cannot be closed", () async {
    await openProjectWithUnreadableEpisodes("movie.ocpt");
    var streamClosed = false;
    final subscription = manager.currentProjectStream.listen(
      (_) {},
      onDone: () {
        streamClosed = true;
      },
    );
    addTearDown(subscription.cancel);

    await manager.disposeLifeCycle();
    await pumpEventQueue();

    expect(streamClosed, isFalse, reason: "nothing after the failed close ran");
    expect(manager.currentProject, isNotNull);
  });

  group("a version creation whose device id cannot be read", () {
    setUp(() async {
      await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    });

    test("creating a version answers the failure of the device id", () async {
      final properties = _NoDeviceIdPropertiesManager();
      final failing = OcptProjectsManager(
        propertiesManager: properties,
        appLanguageCode: () => "en",
      );
      await failing.initLifeCycle();
      await failing.createProject(name: "Other", filePath: p.join(tempDir.path, "other.ocpt"));
      properties.refuse = true;

      final created = await failing.createProjectVersion(name: "v1", note: "");

      expect(created.status, OcptDatabaseStatus.databaseError);
      expect(created.extraInfo, StateError);
      properties.refuse = false;
      expect(await failing.listProjectVersions().valueOrFail, isEmpty, reason: "nothing written");
    });
  });

  group("a project file database that cannot be closed", () {
    late String path;
    late OcptOpenProjectModel project;

    setUp(() async {
      path = p.join(tempDir.path, "movie.ocpt");
      final created = (await manager.createProject(name: "My Movie", filePath: path)).value!;
      final primaryScreenplayId = created.primaryScreenplayId;
      await manager.closeCurrentProject().okOrFail;
      project = OcptOpenProjectModel(
        path: path,
        name: "My Movie",
        primaryScreenplayId: primaryScreenplayId,
        database: _UncloseableFileDatabase(File(path)),
      );
    });

    test("closing the project answers the failure, after reporting it closed", () async {
      var reportedClosed = false;

      final closed = await OcptProjectEpisodeOps.closeProject(
        project: project,
        screenplayService: manager.screenplayService,
        propertiesManager: propertiesManager,
        logger: buildOcptLogsHelper("test"),
        onClosed: () => reportedClosed = true,
      );

      expect(closed.status, OcptDatabaseStatus.databaseError);
      expect(closed.extraInfo, StateError);
      expect(reportedClosed, isTrue, reason: "the project is cleared before its databases close");
    });

    test("closing it records no episode count", () async {
      await propertiesManager.recentProjects.store([
        OcptRecentProjectModel(
          path: path,
          name: "My Movie",
          lastOpenedAt: DateTime.utc(2026),
          episodeCount: 7,
        ),
      ]);

      final closed = await OcptProjectEpisodeOps.closeProject(
        project: project,
        screenplayService: manager.screenplayService,
        propertiesManager: propertiesManager,
        logger: buildOcptLogsHelper("test"),
        onClosed: () {},
      );

      expect(closed.isError, isTrue);
      expect((await propertiesManager.recentProjects.load())!.single.episodeCount, 7);
    });

    test("moving the project answers ioError once it has swapped, and cleans nothing up", () async {
      final newPath = p.join(tempDir.path, "moved", "movie.ocpt");
      OcptOpenProjectModel? swapped;
      var rememberedDirectory = false;

      final result = await OcptProjectMoveOps.moveProject(
        project: project,
        newFilePath: newPath,
        logger: buildOcptLogsHelper("test"),
        propertiesManager: propertiesManager,
        onSwapped: (moved) => swapped = moved,
        rememberProjectsDirectory: (_) async => rememberedDirectory = true,
      );

      expect(result.status, OcptProjectMoveStatus.ioError);
      expect(swapped?.path, newPath, reason: "the project had been swapped when the close failed");
      expect(File(path).existsSync(), isTrue, reason: "the old file is left as it was");
      expect(rememberedDirectory, isFalse);
      await swapped?.fileDatabase.close();
    });
  });
}
