// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../ocpt_result_expectations.dart';

/// What the workspace does when the database really fails the read of the episodes, with a real
/// SQLite failure: the first load stays where it was and the reload leaves the state alone, then
/// both go through once the episodes can be read.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late String secondId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Make the second episode unreadable, so that reading the episodes fails.
  Future<void> spoil() => projectsManager.currentProject!.database.customStatement(
    "UPDATE screenplays SET number = 'unreadable' WHERE id = '$secondId'",
  );

  /// Make the second episode readable again.
  Future<void> mend() => projectsManager.currentProject!.database.customStatement(
    "UPDATE screenplays SET number = 2 WHERE id = '$secondId'",
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_workspace_episodes_failure_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
    await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    secondId = await projectsManager.screenplayService
        .createEpisode(database: projectsManager.currentProject!.database, title: "Two")
        .valueOrFail;
  });

  tearDown(() async {
    // Closing the project counts its episodes, which a spoilt one would refuse.
    await mend();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Build a bloc on the test project.
  OcptWorkspaceBloc buildBloc() {
    final bloc = OcptWorkspaceBloc(
      propertiesManager: propertiesManager,
      projectsManager: projectsManager,
    );
    addTearDown(bloc.close);

    return bloc;
  }

  test("the first load stays where it was while the episodes cannot be read", () async {
    await spoil();

    final bloc = buildBloc();
    await pumpEventQueue(times: 200);

    expect(bloc.state.isLoading, isTrue);

    await mend();
    bloc.add(const AsyncInitEvent());
    await pumpEventQueue(times: 200);

    expect(bloc.state.isLoading, isFalse);
    expect(bloc.state.episodes, hasLength(2));
  });

  test("a reload that cannot read the episodes leaves the state alone", () async {
    final bloc = buildBloc();
    await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    final before = bloc.state;
    await spoil();

    bloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
    await pumpEventQueue(times: 200);

    expect(bloc.state, same(before));

    await mend();
    await projectsManager.screenplayService
        .createEpisode(database: projectsManager.currentProject!.database, title: "Three")
        .okOrFail;
    bloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
    await pumpEventQueue(times: 200);

    expect(bloc.state.episodes, hasLength(3));
  });
}
