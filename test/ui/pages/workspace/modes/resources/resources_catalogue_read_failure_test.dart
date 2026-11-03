// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// What the resources mode does when it cannot read the locations or the scenes
/// it is loaded with, with a real SQLite failure (the table is gone): it stops before it emits
/// anything, answers false when it reads again, and loads once they can be read.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_catalogue_read_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Build a mode bloc on the test project.
  OcptResourcesBloc buildMode() => OcptResourcesBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _SilentRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Make the [table] unreadable.
  Future<void> lose(String table) => projectsManager.currentProject!.database.customStatement(
    "ALTER TABLE $table RENAME TO ${table}_gone",
  );

  for (final (name, table) in [("locations", "locations"), ("scenes", "scenes")]) {
    group("when the $name cannot be read", () {
      test("the mode stays loading", () async {
        await lose(table);

        final mode = buildMode();
        addTearDown(mode.close);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(mode.state.isLoading, isTrue);
      });

      test("reading the catalogue again answers false and shows the write error", () async {
        final mode = buildMode();
        addTearDown(mode.close);
        await mode.stream
            .firstWhere((state) => !state.isLoading)
            .timeout(const Duration(seconds: 5));
        final held = mode.state;
        await lose(table);

        expect(await mode.reload({OcptResourcesReloadScope.snapshot}), isFalse);

        expect(mode.state.hasWriteError, isTrue);
        expect(mode.state.reloadEpoch, held.reloadEpoch);
        expect(mode.state.people, same(held.people));
        expect(mode.state.locations, same(held.locations));
      });
    });
  }

  test("the mode loads once they can be read", () async {
    final mode = buildMode();
    addTearDown(mode.close);

    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
  });
}
