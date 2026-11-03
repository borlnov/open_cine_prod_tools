// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _RecordingRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// What the shot list blocs do when a write is refused by the database: each failing handler
/// raises its own write error, and the records stay as they were.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptShotListBloc mode;
  late OcptShotListFloorPlanSetsBloc sets;
  late OcptShotListFloorPlanCanvasBloc canvas;
  late OcptShotListStoryboardBloc storyboard;
  late OcptShotListInspectorBloc inspector;
  late String setId;
  late String shotId;
  late String symbolId;
  late String panelId;
  late String annotationId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Waits until [isDone] holds, looking again every few milliseconds.
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException("The awaited condition never held");
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_write_failure_test_");
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
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: twoSceneText,
      snapshotReason: OcptSnapshotReason.manual,
    );

    mode = OcptShotListBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    sets = OcptShotListFloorPlanSetsBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    canvas = OcptShotListFloorPlanCanvasBloc(modeBloc: mode, projectsManager: projectsManager);
    storyboard = OcptShotListStoryboardBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    inspector = OcptShotListInspectorBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    await waitUntil(() => !mode.state.isLoading);

    final epoch = mode.state.selectionEpoch;
    sets.add(const OcptShotListSetCreationRequestedEvent());
    await waitUntil(() => mode.state.selectionEpoch > epoch);
    setId = mode.state.selectedSetId!;

    mode.add(const OcptShotListShotCreationRequestedEvent());
    await waitUntil(() => mode.state.selectedShotId != null);
    shotId = mode.state.selectedShotId!;

    canvas.add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.set,
        shotId: null,
        sceneId: null,
        xM: 0,
        yM: 0,
      ),
    );
    await waitUntil(() => canvas.state.selectedFloorPlanSymbolId != null);
    symbolId = canvas.state.selectedFloorPlanSymbolId!;

    final storyboardService = projectsManager.shotListService.storyboardService;
    panelId = (await storyboardService
        .addPanel(database: project.database, shotId: shotId)
        .valueOrFail);
    annotationId = (await storyboardService
        .addAnnotation(
          database: project.database,
          panelId: panelId,
          kind: OcptStoryboardAnnotationKind.label,
          x1: 0.5,
          y1: 0.5,
        )
        .valueOrFail);
    await mode.reload({OcptShotListReloadScope.storyboard});
  });

  tearDown(() async {
    await inspector.close();
    await storyboard.close();
    await canvas.close();
    await sets.close();
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Makes every [verb] on [table] fail with a database error until the project is closed.
  Future<void> refuse(String verb, String table) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  test("a refused scope decision raises the canvas's write error and drops the decision", () async {
    canvas.add(
      OcptShotListFloorPlanScopeDecisionRequestedEvent(
        symbolId: symbolId,
        setId: setId,
        level: OcptFloorPlanOverrideLevel.sequence,
        sequenceCount: 2,
        xM: 9,
        yM: 9,
      ),
    );
    await waitUntil(() => canvas.state.pendingFloorPlanScopeDecision != null);
    await refuse("UPDATE", "floor_plan_symbols");

    canvas.add(
      const OcptShotListFloorPlanScopeDecisionResolvedEvent(choice: OcptFloorPlanScopeChoice.every),
    );
    await waitUntil(() => canvas.state.hasWriteError);

    expect(canvas.state.pendingFloorPlanScopeDecision, isNull);
    expect(mode.state.selectedSet!.symbols.single.xM, 0);
  });

  test("a refused symbol duplication raises the canvas's write error", () async {
    await refuse("INSERT", "floor_plan_symbols");

    canvas.add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: symbolId));
    await waitUntil(() => canvas.state.hasWriteError);

    expect(mode.state.selectedSet!.symbols, hasLength(1));
  });

  test("props that cannot be read leave the sequence with none", () async {
    final database = projectsManager.currentProject!.database;
    final sequence = mode.state.selectedSequence! as OcptSceneShotSequence;
    final elementId = (await projectsManager.elementsService
        .createElement(
          database: database,
          name: "Candles",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .valueOrFail);
    await projectsManager.elementsService
        .addSceneElement(database: database, sceneId: sequence.sceneId, elementId: elementId)
        .maybeValueOrFail;
    sets.add(
      OcptShotListFloorPlanPropsLoadRequestedEvent(sequenceId: mode.state.selectedSequenceId),
    );
    await waitUntil(() => sets.state.propsOfSelectedSequence.isNotEmpty);

    await projectsManager.currentProject!.database.customStatement(
      "ALTER TABLE scene_elements RENAME TO scene_elements_gone",
    );

    sets.add(
      OcptShotListFloorPlanPropsLoadRequestedEvent(sequenceId: mode.state.selectedSequenceId),
    );
    await pumpEventQueue();

    expect(sets.state.propsOfSelectedSequence, isEmpty);
    expect(sets.state.hasWriteError, isFalse);

    await projectsManager.currentProject!.database.customStatement(
      "ALTER TABLE scene_elements_gone RENAME TO scene_elements",
    );
  });

  test("a refused set unlink raises the sets bloc's write error", () async {
    await refuse("UPDATE", "scene_sets");

    sets.add(OcptShotListSetDeletionRequestedEvent(setId: setId));
    await waitUntil(() => sets.state.hasWriteError);

    expect(mode.state.selectedSetId, setId);
  });

  test("a refused set duplication raises the sets bloc's write error", () async {
    await refuse("INSERT", "sets");

    sets.add(OcptShotListSetDuplicationRequestedEvent(setId: setId, newSetName: "Copy"));
    await waitUntil(() => sets.state.hasWriteError);

    expect(mode.state.selectedSetId, setId);
  });

  test("a refused character addition raises the inspector's write error", () async {
    await refuse("INSERT", "roles");

    inspector.add(OcptShotListCharacterAddRequestedEvent(shotId: shotId, characterName: "CLARA"));
    await waitUntil(() => inspector.state.hasWriteError);

    expect(inspector.state.hasWriteError, isTrue);
  });

  group("the shared role alert banner", () {
    late String roleId;
    late String otherRoleId;

    setUp(() async {
      final project = projectsManager.currentProject!;
      Future<String> role(String name) => projectsManager.roleIndexService
          .addRole(
            database: project.database,
            screenplayId: project.primaryScreenplayId,
            name: name,
            kind: OcptRoleKind.silent,
          )
          .valueOrFail;
      roleId = await role("PASSERBY");
      otherRoleId = await role("DRIVER");
      await project.database.customStatement(
        "UPDATE roles SET is_from_screenplay = 1, orphaned_name = 'GHOST' WHERE id = '$roleId'",
      );
      await mode.reload({OcptShotListReloadScope.roles});
    });

    final cases =
        <String, ({OcptShotListInspectorEvent Function(String role, String other) event})>{
          "deleting an orphaned role": (
            event: (role, other) => OcptShotListOrphanedRoleDeleteRequestedEvent(roleId: role),
          ),
          "keeping an orphaned role": (
            event: (role, other) => OcptShotListOrphanedRoleKeptEvent(roleId: role),
          ),
          "merging a role": (
            event: (role, other) =>
                OcptShotListRoleMergeRequestedEvent(sourceRoleId: role, targetRoleId: other),
          ),
        };

    for (final entry in cases.entries) {
      test("${entry.key} raises the inspector's write error and reads nothing again", () async {
        final held = mode.state;
        await refuse("UPDATE", "roles");

        inspector.add(entry.value.event(roleId, otherRoleId));
        await waitUntil(() => inspector.state.hasWriteError);

        expect(mode.state.reloadEpoch, held.reloadEpoch);
        final live = await projectsManager.currentProject!.database
            .customSelect("SELECT id FROM roles WHERE is_deleted = 0")
            .get();
        expect(live, hasLength(2), reason: "a role was removed");
      });
    }
  });

  test(
    "a refused panel deletion raises the storyboard's write error and keeps the panel",
    () async {
      await refuse("UPDATE", "storyboard_panels");

      storyboard.add(OcptShotListPanelDeletionRequestedEvent(panelId: panelId));
      await waitUntil(() => storyboard.state.hasWriteError);

      expect(storyboard.state.hasWriteError, isTrue);
    },
  );

  test("a refused mark deletion raises the storyboard's write error", () async {
    await refuse("UPDATE", "storyboard_annotations");

    storyboard.add(OcptShotListAnnotationDeletionRequestedEvent(annotationId: annotationId));
    await waitUntil(() => storyboard.state.hasWriteError);

    expect(storyboard.state.hasWriteError, isTrue);
  });
}
