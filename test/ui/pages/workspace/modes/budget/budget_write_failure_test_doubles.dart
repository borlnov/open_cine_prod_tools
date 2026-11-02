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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'budget_bloc_test_doubles.dart';

/// A project on disk and the budget mode bloc over it, with the means to make the database refuse
/// a write and to lift the refusal, so that a test can watch a handler stop on a real failure.
class BudgetFailureHarness {
  /// The manager the project is created through.
  late OcptProjectsManager projectsManager;

  /// The properties the mode bloc reads and writes its dock state through.
  late OcptPropertiesManager propertiesManager;

  /// The folder holding the project file.
  late Directory tempDir;

  /// The mode bloc built by [buildBloc], if any.
  OcptBudgetBloc? modeBloc;

  /// Get the state the mode bloc holds.
  OcptBudgetState get state => modeBloc!.state;

  /// Prepare the managers the project is created through, once for the file.
  Future<void> setUpAll() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  }

  /// Create a project in a fresh folder.
  Future<void> setUp() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_write_failure_test_");
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
  }

  /// Close the bloc and delete the project.
  Future<void> tearDown() async {
    await modeBloc?.close();
    modeBloc = null;
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  }

  /// Build the mode bloc on the test project and, unless [isWaitingForLoad] is false, wait until
  /// it holds what it read.
  Future<OcptBudgetBloc> buildBloc({bool isWaitingForLoad = true}) async {
    final bloc = OcptBudgetBloc(
      seed: smallSeed,
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    modeBloc = bloc;
    if (isWaitingForLoad) {
      await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    }

    return bloc;
  }

  /// Make the database refuse the [verb] (INSERT or UPDATE) of [table].
  Future<void> refuse(String verb, String table) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift the refusal [refuse] put on the [verb] of [table].
  Future<void> lift(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);
}
