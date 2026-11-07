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
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager that counts the pops.
class _CountingRouterManager extends OcptRouterManager {
  /// How many times [pop] was called.
  int pops = 0;

  /// Count the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) => pops++;
}

/// A projects manager whose close fails while [isCloseFailing] is set, leaving the project open.
class _ClosingProjectsManager extends OcptProjectsManager {
  /// Whether [closeCurrentProject] answers a failure.
  bool isCloseFailing = false;

  /// How many times [closeCurrentProject] was called.
  int closes = 0;

  /// Class constructor
  _ClosingProjectsManager({required super.propertiesManager}) : super(appLanguageCode: () => "en");

  /// Fail as a project whose episodes cannot be read does while told to.
  @override
  Future<OcptDatabaseOutcome> closeCurrentProject() async {
    closes++;
    if (isCloseFailing) {
      return const OcptDatabaseOutcome(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "close intentionally failed for the test",
      );
    }

    return super.closeCurrentProject();
  }
}

/// What leaving a workspace does when the project cannot be closed: it stops there, the page is
/// not left, and the same event leaves once the project can be closed.
void main() {
  late OcptPropertiesManager propertiesManager;
  late _ClosingProjectsManager projectsManager;
  late _CountingRouterManager router;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_back_requested_failure_test_");
    projectsManager = _ClosingProjectsManager(propertiesManager: propertiesManager);
    await projectsManager.initLifeCycle();
    router = _CountingRouterManager();
    final created = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(created.status.isSuccess, isTrue);
  });

  tearDown(() async {
    projectsManager.isCloseFailing = false;
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  final export = OcptExportManager(fileSelectorManager: const FileSelectorManager());

  final cases = <String, void Function() Function()>{
    "the editor": () {
      final bloc = OcptEditorBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: router,
        exportManager: export,
      );
      addTearDown(bloc.close);

      return () => bloc.add(const OcptEditorBackRequestedEvent());
    },
    "the resources mode": () {
      final bloc = OcptResourcesBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: router,
        exportManager: export,
      );
      addTearDown(bloc.close);

      return () => bloc.add(const OcptResourcesBackRequestedEvent());
    },
    "the schedule mode": () {
      final bloc = OcptScheduleBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: router,
        exportManager: export,
      );
      addTearDown(bloc.close);

      return () => bloc.add(const OcptScheduleBackRequestedEvent());
    },
    "the budget mode": () {
      final bloc = OcptBudgetBloc(
        seed: const [],
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: router,
        exportManager: export,
      );
      addTearDown(bloc.close);

      return () => bloc.add(const OcptBudgetBackRequestedEvent());
    },
    "the breakdown mode": () {
      final bloc = OcptBreakdownBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: router,
        exportManager: export,
      );
      addTearDown(bloc.close);

      return () => bloc.add(const OcptBreakdownBackRequestedEvent());
    },
    "the shot list mode": () {
      final bloc = OcptShotListBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: router,
        exportManager: export,
      );
      addTearDown(bloc.close);

      return () => bloc.add(const OcptShotListBackRequestedEvent());
    },
  };

  for (final entry in cases.entries) {
    test("${entry.key} does not leave when the project cannot be closed", () async {
      final back = entry.value();
      await pumpEventQueue(times: 300);
      projectsManager.isCloseFailing = true;

      back();
      await pumpEventQueue(times: 300);

      expect(projectsManager.closes, greaterThan(0));
      expect(router.pops, 0);
      expect(projectsManager.currentProject, isNotNull);

      projectsManager.isCloseFailing = false;
      back();
      await pumpEventQueue(times: 300);

      expect(router.pops, 1);
      expect(projectsManager.currentProject, isNull);
    });
  }
}
