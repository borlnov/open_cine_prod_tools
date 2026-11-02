// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_snapshot_loader.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'budget_bloc_test_doubles.dart';

/// What the budget does when the schedule it counts the meals from cannot be read, with a real
/// SQLite failure (the table of the shooting days is gone): the loader answers the failure and the
/// mode shows nothing it did not read, whatever asked for the read.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptBudgetBloc bloc;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_schedule_failure_test_");
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
    await bloc.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Build the mode bloc on the test project.
  OcptBudgetBloc buildBloc() => OcptBudgetBloc(
    seed: smallSeed,
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Make the schedule unreadable.
  Future<void> loseTheSchedule() => projectsManager.currentProject!.database.customStatement(
    "ALTER TABLE shooting_days RENAME TO shooting_days_gone",
  );

  /// Give the mode time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  test("the loader answers the failure of the schedule instead of a budget", () async {
    bloc = buildBloc();
    await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    await loseTheSchedule();
    final loader = OcptBudgetSnapshotLoader(projectsManager: projectsManager, seed: smallSeed);

    final read = await loader.load(projectsManager.currentProject!);

    expect(read.status, OcptDatabaseStatus.databaseError);
    expect(read.value, isNull);
  });

  test("a mode whose schedule cannot be read stays loading", () async {
    await loseTheSchedule();

    bloc = buildBloc();
    await settle();

    expect(bloc.state.isLoading, isTrue);
  });

  test("reading the budget again answers false and leaves the state as it was", () async {
    bloc = buildBloc();
    await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    final state = bloc.state;
    await loseTheSchedule();

    expect(await bloc.reload({OcptBudgetReloadScope.snapshot}), isFalse);

    expect(bloc.state, same(state));
    expect(bloc.state.reloadEpoch, state.reloadEpoch);
  });

  test("a change of the project's settings reads nothing the mode does not already hold", () async {
    bloc = buildBloc();
    await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    final state = bloc.state;
    await loseTheSchedule();

    bloc.add(const OcptBudgetProjectSettingsChangedEvent());
    await settle();

    expect(bloc.state, same(state));
  });
}
