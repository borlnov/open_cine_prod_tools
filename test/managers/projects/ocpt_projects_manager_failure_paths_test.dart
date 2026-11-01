// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_preview_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_move_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
  /// Class constructor
  _ThrowingHydrationService({required super.screenplayService})
    : super(
        logger: const SilentLogger(),
        codec: const OcptProjectVersionCodec(logger: SilentLogger()),
      );

  /// Fail as a payload that cannot be applied does.
  @override
  Future<void> hydratePreview({
    required OcptProjectDatabase database,
    required OcptProjectInfoRow projectInfo,
    required OcptProjectVersionPayload payload,
  }) async => throw StateError("hydration failed");
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
    await manager.closeCurrentProject();

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
    final version = (await manager.createProjectVersion(name: "v1", note: ""))!;

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
}
