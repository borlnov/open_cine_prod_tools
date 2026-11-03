// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// What every mode that reads the screenplay's episodes or its text does when the database really
/// fails them: it stays loading, shows nothing it did not read, and reads on once they can be read.
///
/// The episodes are made unreadable through a second episode whose number cannot be read: the text
/// of the first one is still readable, so the read that fails is the one of the episodes alone.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late String primaryId;
  late String secondId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Make the number of the episode [id] unreadable, so that reading it fails.
  Future<void> spoil(String id) => projectsManager.currentProject!.database.customStatement(
    "UPDATE screenplays SET number = 'unreadable' WHERE id = '$id'",
  );

  /// Tombstone the episode [id]: its text is no longer there to read, while the other episodes
  /// still are.
  Future<void> tombstone(String id) => projectsManager.currentProject!.database.customStatement(
    "UPDATE screenplays SET is_deleted = 1 WHERE id = '$id'",
  );

  /// Make the episode [id] readable again.
  Future<void> mend(String id) => projectsManager.currentProject!.database.customStatement(
    "UPDATE screenplays SET number = 1, is_deleted = 0 WHERE id = '$id'",
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_screenplay_reads_failure_test_");
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
    primaryId = project.primaryScreenplayId;
    secondId = await projectsManager.screenplayService
        .createEpisode(database: project.database, title: "Two")
        .valueOrFail;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: primaryId,
          fountainText: "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  });

  tearDown(() async {
    // Closing the project counts its episodes, which a spoilt one would refuse.
    await mend(primaryId);
    await mend(secondId);
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  group("the shot list", () {
    late OcptShotListBloc mode;

    /// Build the mode bloc and give it time to load.
    Future<void> buildMode() async {
      mode = OcptShotListBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
      addTearDown(mode.close);
      await settle();
    }

    test("stays loading while the episodes cannot be read, and loads once they can", () async {
      await spoil(secondId);

      await buildMode();

      expect(mode.state.isLoading, isTrue);
      expect(mode.state.hasWriteError, isFalse);

      await mend(secondId);
      mode.add(const AsyncInitEvent());
      await settle();

      expect(mode.state.isLoading, isFalse);
    });

    test("stays loading while the text of the screenplay cannot be read", () async {
      await tombstone(primaryId);

      await buildMode();

      expect(mode.state.isLoading, isTrue);
      expect(mode.state.hasWriteError, isFalse);
    });

    test("reading the snapshot again answers false and shows the write error", () async {
      await buildMode();
      final snapshot = mode.state.snapshot;
      final epoch = mode.state.reloadEpoch;
      await spoil(secondId);

      expect(await mode.reload({OcptShotListReloadScope.snapshot}), isFalse);

      expect(mode.state.hasWriteError, isTrue);
      expect(mode.state.snapshot, same(snapshot));
      expect(mode.state.reloadEpoch, epoch);
    });
  });

  group("the breakdown", () {
    late OcptBreakdownBloc mode;

    /// Build the mode bloc and give it time to load.
    Future<void> buildMode() async {
      mode = OcptBreakdownBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
      addTearDown(mode.close);
      await settle();
    }

    test("stays loading while the episodes cannot be read, and loads once they can", () async {
      await spoil(secondId);

      await buildMode();

      expect(mode.state.isLoading, isTrue);

      await mend(secondId);
      mode.add(const AsyncInitEvent());
      await settle();

      expect(mode.state.isLoading, isFalse);
    });

    test("stays loading while the text of the screenplay cannot be read", () async {
      await tombstone(primaryId);

      await buildMode();

      expect(mode.state.isLoading, isTrue);
    });

    test("reading the snapshot again answers false", () async {
      await buildMode();
      final snapshot = mode.state.snapshot;
      final epoch = mode.state.reloadEpoch;
      await spoil(secondId);

      expect(await mode.reload({OcptBreakdownReloadScope.snapshot}), isFalse);

      expect(mode.state.snapshot, same(snapshot));
      expect(mode.state.reloadEpoch, epoch);
    });
  });

  group("the resources", () {
    late OcptResourcesBloc mode;

    /// Build the mode bloc and give it time to load.
    Future<void> buildMode() async {
      mode = OcptResourcesBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
      addTearDown(mode.close);
      await settle();
    }

    test("stay loading while the episodes cannot be read, and load once they can", () async {
      await spoil(secondId);

      await buildMode();

      expect(mode.state.isLoading, isTrue);

      await mend(secondId);
      mode.add(const AsyncInitEvent());
      await settle();

      expect(mode.state.isLoading, isFalse);
    });

    test("reading the snapshot again answers false and shows the write error", () async {
      await buildMode();
      final epoch = mode.state.reloadEpoch;
      await spoil(secondId);

      expect(await mode.reload({OcptResourcesReloadScope.snapshot}), isFalse);

      expect(mode.state.hasWriteError, isTrue);
      expect(mode.state.reloadEpoch, epoch);
    });
  });

  group("the schedule", () {
    test("stays loading while the episodes cannot be read, and loads once they can", () async {
      await spoil(secondId);
      final mode = OcptScheduleBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
      addTearDown(mode.close);
      await settle();

      expect(mode.state.isLoading, isTrue);

      await mend(secondId);
      mode.add(const AsyncInitEvent());
      await settle();

      expect(mode.state.isLoading, isFalse);
    });
  });
}
