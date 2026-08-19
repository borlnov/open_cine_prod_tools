// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
    await propertiesManager.deleteAll();

    tempDir = await Directory.systemTemp.createTemp("ocpt_workspace_bloc_test_");
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

  /// Builds a bloc wired to the test properties manager and, unless the test needs no open
  /// project, the test project manager (already holding an open project by [setUp]).
  OcptWorkspaceBloc buildBloc({OcptProjectsManager? overrideProjectsManager}) => OcptWorkspaceBloc(
    propertiesManager: propertiesManager,
    projectsManager: overrideProjectsManager ?? projectsManager,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptWorkspaceState> waitForState(
    OcptWorkspaceBloc bloc,
    bool Function(OcptWorkspaceState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test('defaults to the screenplay mode when nothing was ever persisted', () async {
    final bloc = buildBloc();

    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.mode, OcptWorkspaceMode.screenplay);
    await bloc.close();
  });

  test('loads the persisted workspace mode on entry', () async {
    await propertiesManager.workspaceMode.store(OcptWorkspaceMode.budget);
    final bloc = buildBloc();

    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.mode, OcptWorkspaceMode.budget);
    await bloc.close();
  });

  test('selecting a mode emits it and persists it', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.schedule));
    final state = await waitForState(bloc, (state) => state.mode == OcptWorkspaceMode.schedule);

    expect(state.mode, OcptWorkspaceMode.schedule);
    expect(await propertiesManager.workspaceMode.load(), OcptWorkspaceMode.schedule);
    await bloc.close();
  });

  test('selecting a mode carries the reveal request it was given', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(
          tab: OcptResourcesTab.elements,
          recordId: "element-1",
        ),
      ),
    );
    final state = await waitForState(bloc, (state) => state.revealRequest != null);

    expect(state.mode, OcptWorkspaceMode.resources);
    expect(
      state.revealRequest,
      const OcptResourcesRevealRequest(tab: OcptResourcesTab.elements, recordId: "element-1"),
    );
    await bloc.close();
  });

  test('consuming the reveal request clears it without touching the mode', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(
      const OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.roles, recordId: "role-1"),
      ),
    );
    await waitForState(bloc, (state) => state.revealRequest != null);

    bloc.add(const OcptWorkspaceRevealRequestConsumedEvent());
    final state = await waitForState(bloc, (state) => state.revealRequest == null);

    expect(state.mode, OcptWorkspaceMode.resources);
    await bloc.close();
  });

  test('a plain mode switch clears a reveal request an earlier one left behind', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(
      const OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.roles, recordId: "role-1"),
      ),
    );
    await waitForState(bloc, (state) => state.revealRequest != null);

    bloc.add(const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.screenplay));
    final state = await waitForState(bloc, (state) => state.mode == OcptWorkspaceMode.screenplay);

    expect(state.revealRequest, isNull);
    await bloc.close();
  });

  test('loads the single episode a project starts with, landing the selection on it', () async {
    final bloc = buildBloc();

    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.episodes, hasLength(1));
    expect(state.selectedEpisodeId, state.episodes.single.id);
    await bloc.close();
  });

  test('loads every episode in their sortKey order, still landing on the first', () async {
    final project = projectsManager.currentProject!;
    final firstEpisodeId = project.primaryScreenplayId;
    final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
      database: project.database,
      title: "Episode two",
    );
    expect(secondEpisodeId, isNotNull);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.episodes.map((episode) => episode.id).toList(), [
      firstEpisodeId,
      secondEpisodeId,
    ]);
    expect(state.selectedEpisodeId, firstEpisodeId);
    await bloc.close();
  });

  test('selecting an episode changes nothing else', () async {
    final project = projectsManager.currentProject!;
    final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
      database: project.database,
      title: "Episode two",
    );
    expect(secondEpisodeId, isNotNull);

    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => !state.isLoading);
    expect(loaded.mode, OcptWorkspaceMode.screenplay);

    bloc.add(OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!));
    final state = await waitForState(
      bloc,
      (state) => state.selectedEpisodeId == secondEpisodeId,
    );

    expect(state.selectedEpisodeId, secondEpisodeId);
    expect(state.mode, OcptWorkspaceMode.screenplay);
    expect(state.episodes, hasLength(2));
    await bloc.close();
  });

  test(
    'a currentProjectStream reload keeps the selection when it still names a live episode',
    () async {
      final project = projectsManager.currentProject!;
      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
        title: "Episode two",
      );
      expect(secondEpisodeId, isNotNull);

      final version = await projectsManager.createProjectVersion(
        name: "Both episodes",
        note: "",
      );
      expect(version, isNotNull);

      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      expect(loaded.selectedEpisodeId, project.primaryScreenplayId);

      bloc.add(OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!));
      await waitForState(bloc, (state) => state.selectedEpisodeId == secondEpisodeId);

      final previewResult = await projectsManager.previewVersion(version!.id);
      expect(previewResult.status.isSuccess, isTrue);

      final state = await waitForState(
        bloc,
        (state) => state.episodes.length == 2 && state.selectedEpisodeId == secondEpisodeId,
      );

      expect(state.selectedEpisodeId, secondEpisodeId);
      expect(state.episodes.map((episode) => episode.id).toList(), contains(secondEpisodeId));
      await bloc.close();
    },
  );

  test(
    'a currentProjectStream reload falls back to the first episode when the selection no longer '
    'names one',
    () async {
      final project = projectsManager.currentProject!;
      final firstEpisodeId = project.primaryScreenplayId;

      final version = await projectsManager.createProjectVersion(
        name: "One episode only",
        note: "",
      );
      expect(version, isNotNull);

      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
        title: "Episode two",
      );
      expect(secondEpisodeId, isNotNull);

      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!));
      await waitForState(bloc, (state) => state.selectedEpisodeId == secondEpisodeId);

      final previewResult = await projectsManager.previewVersion(version!.id);
      expect(previewResult.status.isSuccess, isTrue);

      final state = await waitForState(
        bloc,
        (state) => state.episodes.length == 1 && state.selectedEpisodeId == firstEpisodeId,
      );

      expect(state.selectedEpisodeId, firstEpisodeId);
      expect(state.episodes.map((episode) => episode.id).toList(), [firstEpisodeId]);
      await bloc.close();
    },
  );
}
