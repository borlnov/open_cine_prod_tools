// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  // OcptPropertiesManager wraps a process-wide singleton (see the properties manager test), so we
  // create it once, backed by an in-memory store, and clear it between tests.
  late OcptPropertiesManager propertiesManager;
  late Directory tempDir;
  late OcptProjectsManager manager;

  setUpAll(() async {
    // OcptRecentProjectModel and this manager both log through appLogger(), which requires a
    // global manager instance to be set; merely accessing it creates the (otherwise unused)
    // singleton.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_projects_manager_test_");
    manager = OcptProjectsManager(propertiesManager: propertiesManager);
    await manager.initLifeCycle();
  });

  tearDown(() async {
    await manager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  test('createProject creates the project file, seeds it, and makes it current', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");

    final result = await manager.createProject(name: "My Movie", filePath: filePath);

    expect(result.status, OcptProjectStatus.ok);
    expect(result.value?.name, "My Movie");
    expect(File(filePath).existsSync(), isTrue);
    expect(manager.currentProject?.path, filePath);
    expect(manager.currentProject?.name, "My Movie");

    final screenplayText = await manager.screenplayService.loadScreenplayText(
      database: manager.currentProject!.database,
      screenplayId: manager.currentProject!.primaryScreenplayId,
    );
    expect(screenplayText, "");

    final recents = await propertiesManager.recentProjects.load();
    expect(recents?.first.path, filePath);
    expect(recents?.first.name, "My Movie");
  });

  test('createProject while a project is already open closes the previous one first', () async {
    await manager.createProject(name: "First", filePath: p.join(tempDir.path, "first.ocpt"));

    final result = await manager.createProject(
      name: "Second",
      filePath: p.join(tempDir.path, "second.ocpt"),
    );

    expect(result.status, OcptProjectStatus.ok);
    expect(manager.currentProject?.name, "Second");
  });

  test('openProject opens a previously created project and makes it current', () async {
    final filePath = p.join(tempDir.path, "movie.ocpt");
    await manager.createProject(name: "My Movie", filePath: filePath);
    await manager.closeCurrentProject();

    final result = await manager.openProject(filePath: filePath);

    expect(result.status, OcptProjectStatus.ok);
    expect(manager.currentProject?.name, "My Movie");
    expect(manager.currentProject?.path, filePath);

    final recents = await propertiesManager.recentProjects.load();
    expect(recents?.first.path, filePath);
  });

  test('closeCurrentProject clears the current project and is a no-op when none is open', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));

    await manager.closeCurrentProject();
    expect(manager.currentProject, isNull);

    // Closing again must not throw.
    await manager.closeCurrentProject();
    expect(manager.currentProject, isNull);
  });

  test('currentProjectStream emits every time the current project changes', () async {
    // expectLater/emitsInOrder subscribes right away and awaits each expected event in turn,
    // which avoids racing the stream's (deferred) event delivery against the actions below.
    final expectation = expectLater(
      manager.currentProjectStream.map((project) => project?.name),
      emitsInOrder(<Object?>["My Movie", null]),
    );

    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    await manager.closeCurrentProject();

    await expectation;
  });

  test('openProject returns fileNotFound when the file does not exist', () async {
    final result = await manager.openProject(filePath: p.join(tempDir.path, "missing.ocpt"));

    expect(result.status, OcptProjectStatus.fileNotFound);
    expect(result.value, isNull);
    expect(manager.currentProject, isNull);
  });

  test('openProject returns corruptedFile when the file is not a valid project database', () async {
    final filePath = p.join(tempDir.path, "garbage.ocpt");
    await File(filePath).writeAsBytes(List<int>.generate(32, (i) => i));

    final result = await manager.openProject(filePath: filePath);

    expect(result.status, OcptProjectStatus.corruptedFile);
    expect(manager.currentProject, isNull);
  });

  test(
    'saveCurrentProjectPageFormat writes the format, loadCurrentProjectPageFormat reads it back',
    () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await manager.createProject(name: "My Movie", filePath: filePath);

      final initialFormat = await manager.loadCurrentProjectPageFormat();
      final otherFormat = initialFormat == OcptPageFormat.usLetter
          ? OcptPageFormat.a4
          : OcptPageFormat.usLetter;

      await manager.saveCurrentProjectPageFormat(otherFormat);

      expect(await manager.loadCurrentProjectPageFormat(), otherFormat);
    },
  );

  test('saveCurrentProjectPageFormat is a no-op when no project is open', () async {
    await expectLater(
      manager.saveCurrentProjectPageFormat(OcptPageFormat.a4),
      completes,
    );
    expect(manager.currentProject, isNull);
  });

  test('createProjectVersion captures the open project, listProjectVersions reads it back', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));

    final created = await manager.createProjectVersion(
      name: "v1 — First read",
      note: "Before the rewrite",
    );

    expect(created?.name, "v1 — First read");
    expect(created?.isCurrent, isTrue);

    final versions = await manager.listProjectVersions();
    expect(versions.map((version) => version.id), [created?.id]);
    expect(versions.single.note, "Before the rewrite");

    // The manager is what fills in the facts a version records but the service can't know: the
    // replica's device id is minted through the properties manager on the way.
    expect(await propertiesManager.deviceId.load(), isNotEmpty);
  });

  test('deleteProjectVersion removes the version from the open project', () async {
    await manager.createProject(name: "My Movie", filePath: p.join(tempDir.path, "movie.ocpt"));
    final created = await manager.createProjectVersion(name: "v1", note: "");

    await manager.deleteProjectVersion(created!.id);

    expect(await manager.listProjectVersions(), isEmpty);
  });

  test('the version operations are no-ops when no project is open', () async {
    expect(await manager.listProjectVersions(), isEmpty);
    expect(await manager.createProjectVersion(name: "v1", note: ""), isNull);
    await expectLater(manager.deleteProjectVersion("no-such-version"), completes);
  });
}
