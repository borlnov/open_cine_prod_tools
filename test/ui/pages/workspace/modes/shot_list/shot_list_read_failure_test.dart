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
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_reader.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// What the shot list does when the schedule it joins to the shots cannot be read, with a real
/// SQLite failure (the table of the shooting days is gone): the reader answers the failure, the
/// mode shows its write error, and whatever the read was for does not happen.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptShotListBloc mode;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Build the mode bloc and wait for it to load, or just give it time when [expectsLoaded] is
  /// false.
  Future<void> buildMode({bool expectsLoaded = true}) async {
    mode = OcptShotListBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    if (expectsLoaded) {
      await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    } else {
      await pumpEventQueue(times: 200);
    }
  }

  /// Make the schedule unreadable.
  Future<void> loseTheSchedule() => projectsManager.currentProject!.database.customStatement(
    "ALTER TABLE shooting_days RENAME TO shooting_days_gone",
  );

  /// Give the mode time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_read_failure_test_");
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

    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: twoSceneText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  });

  tearDown(() async {
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  test("the reader answers the failure of the placements instead of a snapshot", () async {
    await buildMode();
    await loseTheSchedule();
    final project = projectsManager.currentProject!;
    final reader = OcptShotListReader(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      shotListService: projectsManager.shotListService,
      roleIndexService: projectsManager.roleIndexService,
      scheduleService: projectsManager.scheduleService,
      storyboardService: projectsManager.storyboardService,
      floorPlanService: projectsManager.floorPlanService,
      locationsService: projectsManager.locationsService,
      screenplayIdOf: (project) => project.primaryScreenplayId,
    );

    final read = await reader.loadSnapshot(project);

    expect(read.status, OcptDatabaseStatus.databaseError);
    expect(read.value, isNull);
  });

  group("when the shot list itself cannot be read", () {
    /// Make the shots unreadable.
    Future<void> loseTheShots() => projectsManager.currentProject!.database.customStatement(
      "ALTER TABLE shots RENAME TO shots_gone",
    );

    test("the reader answers the failure of the shot list instead of a snapshot", () async {
      await buildMode();
      await loseTheShots();
      final reader = OcptShotListReader(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        shotListService: projectsManager.shotListService,
        roleIndexService: projectsManager.roleIndexService,
        scheduleService: projectsManager.scheduleService,
        storyboardService: projectsManager.storyboardService,
        floorPlanService: projectsManager.floorPlanService,
        locationsService: projectsManager.locationsService,
        screenplayIdOf: (project) => project.primaryScreenplayId,
      );

      final read = await reader.loadSnapshot(projectsManager.currentProject!);

      expect(read.status, OcptDatabaseStatus.databaseError);
      expect(read.value, isNull);
    });

    test("a mode that cannot read it stays loading", () async {
      await loseTheShots();

      await buildMode(expectsLoaded: false);

      expect(mode.state.isLoading, isTrue);
      expect(mode.state.hasWriteError, isFalse);
    });

    test("reading it again answers false and shows the write error", () async {
      await buildMode();
      final snapshot = mode.state.snapshot;
      final epoch = mode.state.reloadEpoch;
      await loseTheShots();

      expect(await mode.reload({OcptShotListReloadScope.snapshot}), isFalse);

      expect(mode.state.hasWriteError, isTrue);
      expect(mode.state.snapshot, same(snapshot));
      expect(mode.state.reloadEpoch, epoch);
    });
  });

  test("a mode that cannot read the placements stays loading", () async {
    await loseTheSchedule();

    await buildMode(expectsLoaded: false);

    expect(mode.state.isLoading, isTrue);
    expect(mode.state.hasWriteError, isFalse);
  });

  test("reading the snapshot again answers false and shows the write error", () async {
    await buildMode();
    final snapshot = mode.state.snapshot;
    final epoch = mode.state.reloadEpoch;
    await loseTheSchedule();

    expect(await mode.reload({OcptShotListReloadScope.snapshot}), isFalse);

    expect(mode.state.hasWriteError, isTrue);
    expect(mode.state.snapshot, same(snapshot));
    expect(mode.state.reloadEpoch, epoch);
  });

  group("when the cast cannot be read", () {
    /// Make the cast unreadable.
    Future<void> loseTheCast() => projectsManager.currentProject!.database.customStatement(
      "ALTER TABLE roles RENAME TO roles_gone",
    );

    test("the reader answers the failure of the cast", () async {
      await buildMode();
      await loseTheCast();
      final reader = OcptShotListReader(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        shotListService: projectsManager.shotListService,
        roleIndexService: projectsManager.roleIndexService,
        scheduleService: projectsManager.scheduleService,
        storyboardService: projectsManager.storyboardService,
        floorPlanService: projectsManager.floorPlanService,
        locationsService: projectsManager.locationsService,
        screenplayIdOf: (project) => project.primaryScreenplayId,
      );

      final read = await reader.loadRoles(projectsManager.currentProject!);

      expect(read.status, OcptDatabaseStatus.databaseError);
      expect(read.value, isNull);
    });

    test("a mode that cannot read it stays loading", () async {
      await loseTheCast();

      await buildMode(expectsLoaded: false);

      expect(mode.state.isLoading, isTrue);
    });

    test("reading the cast again answers false and shows the write error", () async {
      await buildMode();
      final roles = mode.state.roles;
      final epoch = mode.state.reloadEpoch;
      await loseTheCast();

      expect(await mode.reload({OcptShotListReloadScope.roles}), isFalse);

      expect(mode.state.hasWriteError, isTrue);
      expect(mode.state.roles, same(roles));
      expect(mode.state.reloadEpoch, epoch);
    });
  });

  test("creating a shot shows the write error and selects nothing when the read fails", () async {
    await buildMode();
    final selectedShotId = mode.state.selectedShotId;
    await loseTheSchedule();

    mode.add(const OcptShotListShotCreationRequestedEvent());
    await settle();

    expect(mode.state.hasWriteError, isTrue);
    expect(mode.state.selectedShotId, selectedShotId);
  });

  test("deleting a shot shows the write error and reselects nothing when the read fails", () async {
    await buildMode();
    mode.add(const OcptShotListShotCreationRequestedEvent());
    await mode.stream.firstWhere((state) => state.selectedShotId != null);
    final shotId = mode.state.selectedShotId!;
    expect(mode.state.hasWriteError, isFalse);
    final snapshot = mode.state.snapshot;
    await loseTheSchedule();

    mode.add(OcptShotListShotDeletionRequestedEvent(shotId: shotId));
    await settle();

    expect(mode.state.hasWriteError, isTrue);
    expect(mode.state.selectedShotId, shotId);
    expect(mode.state.snapshot, same(snapshot));
  });

  group("when the locations cannot be read", () {
    /// Make the locations unreadable.
    Future<void> loseTheLocations() => projectsManager.currentProject!.database.customStatement(
      "ALTER TABLE locations RENAME TO locations_gone",
    );

    test("the reader answers the failure of the locations", () async {
      await buildMode();
      await loseTheLocations();
      final reader = OcptShotListReader(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        shotListService: projectsManager.shotListService,
        roleIndexService: projectsManager.roleIndexService,
        scheduleService: projectsManager.scheduleService,
        storyboardService: projectsManager.storyboardService,
        floorPlanService: projectsManager.floorPlanService,
        locationsService: projectsManager.locationsService,
        screenplayIdOf: (project) => project.primaryScreenplayId,
      );

      final read = await reader.loadLocations(projectsManager.currentProject!);

      expect(read.status, OcptDatabaseStatus.databaseError);
      expect(read.value, isNull);
    });

    test("a mode that cannot read them stays loading", () async {
      await loseTheLocations();

      await buildMode(expectsLoaded: false);

      expect(mode.state.isLoading, isTrue);
    });

    test("reading them again answers false and shows the write error", () async {
      await buildMode();
      final locations = mode.state.locations;
      final epoch = mode.state.reloadEpoch;
      await loseTheLocations();

      expect(await mode.reload({OcptShotListReloadScope.locations}), isFalse);

      expect(mode.state.hasWriteError, isTrue);
      expect(mode.state.locations, same(locations));
      expect(mode.state.reloadEpoch, epoch);
    });
  });
}
