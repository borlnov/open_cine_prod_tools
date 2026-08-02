// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Builds a project with the given [path], for tests that only care about ordering/deduplication.
OcptRecentProjectModel _projectAt(String path, {DateTime? lastOpenedAt}) => OcptRecentProjectModel(
  path: path,
  name: path,
  lastOpenedAt: lastOpenedAt ?? DateTime.utc(2026),
);

void main() {
  // [OcptPropertiesManager] wraps `PropertiesSingleton`, which is a process-wide singleton bound
  // to whichever `SharedPreferencesAsyncPlatform` was set when it was first created. We therefore
  // create it once, backed by an in-memory store, and clear that store between tests instead of
  // recreating the manager.
  late OcptPropertiesManager manager;

  setUpAll(() async {
    // OcptRecentProjectModel logs through appLogger(), which requires a global manager instance
    // to be set; merely accessing it creates the (otherwise unused) singleton.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    manager = OcptPropertiesManager();
    await manager.initLifeCycle();
  });

  setUp(() async {
    await manager.deleteAll();
  });

  group('OcptPropertiesManager.recentProjects', () {
    test('is empty by default', () async {
      expect(await manager.recentProjects.load(), isNull);
    });

    test('addRecentProject inserts the most recently opened project first', () async {
      await manager.addRecentProject(_projectAt("/a"));
      await manager.addRecentProject(_projectAt("/b"));
      await manager.addRecentProject(_projectAt("/c"));

      final stored = await manager.recentProjects.load();

      expect(stored?.map((project) => project.path).toList(), ["/c", "/b", "/a"]);
    });

    test('addRecentProject moves an already known path to the front instead of duplicating it', () async {
      await manager.addRecentProject(_projectAt("/a"));
      await manager.addRecentProject(_projectAt("/b"));
      await manager.addRecentProject(_projectAt("/a", lastOpenedAt: DateTime.utc(2026, 2)));

      final stored = await manager.recentProjects.load();

      expect(stored?.map((project) => project.path).toList(), ["/a", "/b"]);
      expect(stored?.first.lastOpenedAt, DateTime.utc(2026, 2));
    });

    test('addRecentProject caps the list at 10 entries, dropping the oldest ones', () async {
      for (var i = 0; i < 12; i++) {
        await manager.addRecentProject(_projectAt("/project-$i"));
      }

      final stored = await manager.recentProjects.load();

      expect(stored, hasLength(10));
      expect(stored?.map((project) => project.path).toList(), [
        for (var i = 11; i >= 2; i--) "/project-$i",
      ]);
    });

    test('removeRecentProject only removes the matching path', () async {
      await manager.addRecentProject(_projectAt("/a"));
      await manager.addRecentProject(_projectAt("/b"));

      await manager.removeRecentProject("/a");

      final stored = await manager.recentProjects.load();

      expect(stored?.map((project) => project.path).toList(), ["/b"]);
    });

    test('removeRecentProject on an unknown path is a no-op', () async {
      await manager.addRecentProject(_projectAt("/a"));

      await manager.removeRecentProject("/unknown");

      final stored = await manager.recentProjects.load();

      expect(stored?.map((project) => project.path).toList(), ["/a"]);
    });
  });

  group('OcptPropertiesManager.editorMode', () {
    test('is null by default, which means OcptEditorMode.styled applies', () async {
      expect(await manager.editorMode.load(), isNull);
    });

    test('round trips through the local storage', () async {
      await manager.editorMode.store(OcptEditorMode.raw);

      expect(await manager.editorMode.load(), OcptEditorMode.raw);
    });
  });

  group('OcptPropertiesManager.workspaceMode', () {
    test('is null by default, which means OcptWorkspaceMode.screenplay applies', () async {
      expect(await manager.workspaceMode.load(), isNull);
    });

    test('round trips through the local storage', () async {
      await manager.workspaceMode.store(OcptWorkspaceMode.budget);

      expect(await manager.workspaceMode.load(), OcptWorkspaceMode.budget);
    });
  });

  group('OcptPropertiesManager.pageMargins', () {
    test('is null by default, which means FountainPageMargins.standard() applies', () async {
      expect(await manager.pageMargins.load(), isNull);
    });

    test('round trips through the local storage', () async {
      const margins = FountainPageMargins(
        leftInches: 2,
        rightInches: 1.25,
        topInches: 0.75,
        bottomInches: 1.5,
      );

      await manager.pageMargins.store(margins);

      expect(await manager.pageMargins.load(), margins);
    });

    test('round trips the standard margins', () async {
      const margins = FountainPageMargins.standard();

      await manager.pageMargins.store(margins);

      expect(await manager.pageMargins.load(), margins);
    });
  });

  group('OcptPropertiesManager.deviceId', () {
    test('is nothing until something asks for it', () async {
      expect(await manager.deviceId.load(), isNull);
    });

    test('loadOrCreateDeviceId mints one, stores it, and returns the same one afterwards', () async {
      final minted = await manager.loadOrCreateDeviceId();

      expect(minted, isNotEmpty);
      expect(await manager.deviceId.load(), minted);
      expect(await manager.loadOrCreateDeviceId(), minted);
    });

    test('loadOrCreateDeviceId keeps an id already stored rather than minting a new one', () async {
      await manager.deviceId.store("an-existing-device-id");

      expect(await manager.loadOrCreateDeviceId(), "an-existing-device-id");
    });
  });
}
