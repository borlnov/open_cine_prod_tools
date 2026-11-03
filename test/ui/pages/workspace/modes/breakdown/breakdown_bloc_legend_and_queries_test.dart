// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'breakdown_bloc_test_doubles.dart';

/// Run the tests of the breakdown bloc legend and queries.
void main() {
  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() resolvable; the bloc's dependencies
    // themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_breakdown_bloc_test_");
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

  /// Writes [text] as the project's screenplay, which reconciles its scene index and therefore
  /// gives the breakdown mode its scenes.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  }

  /// Builds a bloc wired to the test project. [overrideProjectsManager] lets a test swap in a
  /// manager of its own (already holding an open project), for the one that needs to observe it.
  /// The export manager is a real one no test asks to export, so no test ever reaches a native save
  /// dialog.
  OcptBreakdownBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptProjectsManager? overrideProjectsManager,
    String? selectedEpisodeId,
  }) => OcptBreakdownBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    selectedEpisodeId: selectedEpisodeId,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group("the compact role alert banner", () {
    test("orphanedRoleAlerts reports a role the screenplay no longer names", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nCLARA\nHello.\n");

      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => state.roles.isNotEmpty);
      expect(loaded.orphanedRoleAlerts, isEmpty);

      await writeScreenplay("INT. HOUSE - DAY\n\nAction, no dialogue anymore.\n");
      // Forces a full reload: unlike the resources mode's own handler, this event's breakdown
      // sibling only re-reads the page setup, not the whole snapshot.
      bloc.add(const AsyncInitEvent());
      final orphaned = await waitForState(bloc, (state) => state.orphanedRoleAlerts.isNotEmpty);

      expect(orphaned.orphanedRoleAlerts, hasLength(1));
      expect(orphaned.orphanedRoleAlerts.single.characterName, "CLARA");
      expect(orphaned.orphanedRoleAlerts.single.roleId, orphaned.roles.single.id);

      await bloc.close();
    });

    test(
      "roleCollisionAlerts reports a hand-added role sharing a screenplay role's name",
      () async {
        await writeScreenplay("INT. HOUSE - DAY\n\nCLARA\nHello.\n");
        final project = projectsManager.currentProject!;

        final bloc = buildBloc();
        final loaded = await waitForState(bloc, (state) => state.roles.isNotEmpty);
        expect(loaded.roleCollisionAlerts, isEmpty);
        final screenplayRoleId = loaded.roles.single.id;

        final handAddedRoleId = await projectsManager.roleIndexService
            .addRole(
              database: project.database,
              screenplayId: project.primaryScreenplayId,
              name: "Clara",
              kind: OcptRoleKind.extra,
            )
            .maybeValueOrFail;

        bloc.add(const AsyncInitEvent());
        final state = await waitForState(bloc, (state) => state.roleCollisionAlerts.isNotEmpty);

        expect(state.roleCollisionAlerts, hasLength(1));
        expect(state.roleCollisionAlerts.single.screenplayRoleId, screenplayRoleId);
        expect(state.roleCollisionAlerts.single.handAddedRoleId, handAddedRoleId);

        await bloc.close();
      },
    );
  });

  test("toggling a legend entry hides it, toggling it again reveals it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    const key = (OcptBreakdownTargetKind.element, OcptElementCategory.prop);

    bloc.add(const OcptBreakdownLegendEntryToggledEvent(key: key));
    final hidden = await waitForState(bloc, (state) => state.hiddenLegendKeys.isNotEmpty);
    expect(hidden.hiddenLegendKeys, {key});

    bloc.add(const OcptBreakdownLegendEntryToggledEvent(key: key));
    final revealed = await waitForState(bloc, (state) => state.hiddenLegendKeys.isEmpty);
    expect(revealed.hiddenLegendKeys, isEmpty);

    await bloc.close();
  });

  test("show all reveals every hidden legend key", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptBreakdownLegendEntryToggledEvent(
        key: (OcptBreakdownTargetKind.element, OcptElementCategory.prop),
      ),
    );
    bloc.add(const OcptBreakdownLegendEntryToggledEvent(key: (OcptBreakdownTargetKind.role, null)));
    await waitForState(bloc, (state) => state.hiddenLegendKeys.length == 2);

    bloc.add(const OcptBreakdownLegendShowAllRequestedEvent());
    final state = await waitForState(bloc, (state) => state.hiddenLegendKeys.isEmpty);

    expect(state.hiddenLegendKeys, isEmpty);

    await bloc.close();
  });

  test("the centre starts on the script view with an empty search query", () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.centreView, OcptBreakdownCentreView.script);
    expect(state.searchQuery, "");

    await bloc.close();
  });

  test("switching back to the script view leaves the search query untouched", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "lamp"));
    await waitForState(bloc, (state) => state.searchQuery == "lamp");

    bloc.add(const OcptBreakdownCentreViewSelectedEvent(view: OcptBreakdownCentreView.script));
    final state = await waitForState(
      bloc,
      (state) => state.centreView == OcptBreakdownCentreView.script,
    );

    expect(state.searchQuery, "lamp");

    await bloc.close();
  });

  test("typing a query from the script view switches to the recap, carrying the text", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.centreView, OcptBreakdownCentreView.script);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "Peugeot"));
    final state = await waitForState(
      bloc,
      (state) => state.centreView == OcptBreakdownCentreView.recap,
    );

    expect(state.searchQuery, "Peugeot");

    await bloc.close();
  });

  test("typing a query while already on the recap stays there", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptBreakdownCentreViewSelectedEvent(view: OcptBreakdownCentreView.recap));
    await waitForState(bloc, (state) => state.centreView == OcptBreakdownCentreView.recap);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "Peugeot"));
    final state = await waitForState(bloc, (state) => state.searchQuery == "Peugeot");

    expect(state.centreView, OcptBreakdownCentreView.recap);

    await bloc.close();
  });

  test("clearing the query afterward does not switch back to the script view", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "Peugeot"));
    await waitForState(bloc, (state) => state.centreView == OcptBreakdownCentreView.recap);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: ""));
    final state = await waitForState(bloc, (state) => state.searchQuery == "");

    expect(state.centreView, OcptBreakdownCentreView.recap);

    await bloc.close();
  });

  test("selecting a target also selects the scene the click happened in", () async {
    await writeScreenplay(
      "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
    );
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.length == 2);
    final gardenSceneId = loaded.scenes[1].id;

    bloc.add(
      OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: gardenSceneId,
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedTargetRef != null);

    expect(state.selectedTargetRef, (OcptBreakdownTargetKind.element, "el-1"));
    expect(state.selectedSceneId, gardenSceneId);

    await bloc.close();
  });

  test(
    "selecting a target naming a scene id that no longer exists drops the scene selection",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => state.scenes.isNotEmpty);

      bloc.add(
        const OcptBreakdownTargetSelectedEvent(
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "el-1",
          sceneId: "not-a-scene",
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedTargetRef != null);

      expect(state.selectedTargetRef, (OcptBreakdownTargetKind.element, "el-1"));
      expect(state.selectedSceneId, isNull);

      await bloc.close();
    },
  );

  test("a selected target resolves against the loaded snapshot's own targets", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");

    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

    final elementId = await projectsManager.elementsService
        .createElement(
          database: project.database,
          name: "Desk lamp",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .maybeValueOrFail;
    expect(elementId, isNotNull);

    await projectsManager.breakdownService
        .createTag(
          database: project.database,
          sceneId: sceneId,
          startOffset: 2,
          endOffset: 6,
          taggedText: "lamp",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: elementId!,
        )
        .maybeValueOrFail;

    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    bloc.add(
      OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId,
        sceneId: sceneId,
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedTarget != null);

    expect(state.selectedTarget?.name, "Desk lamp");

    await bloc.close();
  });

  test("clearing the target selection drops it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: "scene-1",
      ),
    );
    await waitForState(bloc, (state) => state.selectedTargetRef != null);

    bloc.add(const OcptBreakdownTargetSelectionClearedEvent());
    final state = await waitForState(bloc, (state) => state.selectedTargetRef == null);

    expect(state.selectedTargetRef, isNull);

    await bloc.close();
  });

  test("a fresh load always drops the selected target, exactly as the selected scene", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(
      OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: sceneId,
      ),
    );
    await waitForState(bloc, (state) => state.selectedTargetRef != null);

    bloc.add(const OcptBreakdownProjectSettingsChangedEvent());
    // `_onProjectSettingsChanged` doesn't reload the snapshot itself; reload through a version
    // preview round trip instead, which does go through `_load`.
    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "Checkpoint", note: ""));
    final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = withVersion.projectVersions.single.id;

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    final previewing = await waitForState(bloc, (state) => state.previewedVersionId != null);

    expect(previewing.selectedTargetRef, isNull);

    await bloc.close();
  });

  test(
    "leaving a preview reloads the working copy's own read, clearing the previewed id",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => state.scenes.isNotEmpty);

      bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "Base", note: ""));
      final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
      final versionId = withVersion.projectVersions.single.id;

      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
      await waitForState(bloc, (state) => state.previewedVersionId != null);

      bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
      final state = await waitForState(bloc, (state) => state.previewedVersionId == null);

      expect(state.isPreviewingVersion, isFalse);
      expect(state.scenes, isNotEmpty);

      await bloc.close();
    },
  );

  test("selecting a target opens the right dock on the Inspector tab", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.rightDockTab, isNull);

    bloc.add(
      const OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: "scene-1",
      ),
    );
    final state = await waitForState(bloc, (state) => state.rightDockTab != null);

    expect(state.rightDockTab, OcptBreakdownRightDockTab.inspector);
    expect(state.lastRightDockTab, OcptBreakdownRightDockTab.inspector);

    await bloc.close();
  });

  test(
    "the right dock toggle reopens the last tab explicitly selected, persisted across entries",
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptBreakdownRightDockTabSelectedEvent(tab: OcptBreakdownRightDockTab.versions),
      );
      await waitForState(bloc, (state) => state.rightDockTab == OcptBreakdownRightDockTab.versions);

      bloc.add(const OcptBreakdownRightDockClosedEvent());
      await waitForState(bloc, (state) => state.rightDockTab == null);

      bloc.add(const OcptBreakdownRightDockToggledEvent());
      final reopened = await waitForState(bloc, (state) => state.rightDockTab != null);
      expect(reopened.rightDockTab, OcptBreakdownRightDockTab.versions);

      await bloc.close();

      expect(
        await propertiesManager.breakdownLastRightDockTab.load(),
        OcptBreakdownRightDockTab.versions,
      );

      final nextEntry = buildBloc();
      final loaded = await waitForState(nextEntry, (state) => !state.isLoading);
      expect(loaded.lastRightDockTab, OcptBreakdownRightDockTab.versions);

      await nextEntry.close();
    },
  );

  test("the loaded snapshot carries the address book for the inspector's pickers", () async {
    final project = projectsManager.currentProject!;
    final personId = await projectsManager.peopleService
        .createPerson(database: project.database)
        .maybeValueOrFail;
    expect(personId, isNotNull);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => state.people.isNotEmpty);

    expect(state.people.single.id, personId);

    await bloc.close();
  });

  test("an occurrence click selects its own scene", () async {
    await writeScreenplay(
      "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
    );
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.length == 2);
    final gardenSceneId = loaded.scenes[1].id;

    bloc.add(OcptBreakdownOccurrenceSelectedEvent(sceneId: gardenSceneId));
    final state = await waitForState(bloc, (state) => state.selectedSceneId == gardenSceneId);

    expect(state.selectedSceneId, gardenSceneId);

    await bloc.close();
  });
}
