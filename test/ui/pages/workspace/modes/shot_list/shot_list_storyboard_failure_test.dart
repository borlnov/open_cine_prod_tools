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
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'shot_list_storyboard_bloc_test_doubles.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// The rows the handlers work on, and the view that handles the events.
typedef _Seeded = ({
  OcptShotListStoryboardBloc view,
  String shotId,
  String firstPanelId,
  String secondPanelId,
  String annotationId,
});

/// What the storyboard does when the database refuses a write, with a real SQLite failure: the
/// handler stops where the exception stopped it, raises the board's write error, reads nothing
/// again, and the same event goes through once the refusal is lifted.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptShotListBloc mode;
  late _Seeded seeded;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_storyboard_failure_test_");
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
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    final view = OcptShotListStoryboardBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fileSelectorManager: const StubFileSelectorManager(pickedPath: "/frames/frame.png"),
      fieldEditDebounce: const Duration(days: 1),
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));

    mode.add(const OcptShotListShotCreationRequestedEvent());
    await settle();
    final shotId = mode.state.selectedShotId!;
    final service = projectsManager.storyboardService;
    final firstPanelId = await service
        .addPanel(database: project.database, shotId: shotId)
        .valueOrFail;
    final secondPanelId = await service
        .addPanel(database: project.database, shotId: shotId)
        .valueOrFail;
    final annotationId = await service
        .addAnnotation(
          database: project.database,
          panelId: firstPanelId,
          kind: OcptStoryboardAnnotationKind.label,
          x1: 0.5,
          y1: 0.5,
        )
        .valueOrFail;
    await mode.reload({OcptShotListReloadScope.storyboard});
    seeded = (
      view: view,
      shotId: shotId,
      firstPanelId: firstPanelId,
      secondPanelId: secondPanelId,
      annotationId: annotationId,
    );
  });

  tearDown(() async {
    await seeded.view.close();
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make the database refuse the [verb] of [table].
  Future<void> refuse(String verb, String table) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift the refusal [refuse] put on the [verb] of [table].
  Future<void> lift(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// The handlers, each with the table and the verb that fail it, and the event it dispatches.
  final cases = <String, ({String table, String verb, OcptShotListEvent Function(_Seeded) event})>{
    "importing a frame whose panel is refused": (
      table: "storyboard_panels",
      verb: "INSERT",
      event: (s) => OcptShotListPanelImportRequestedEvent(shotId: s.shotId, fileTypeLabel: "Image"),
    ),
    "importing a frame whose image is refused": (
      table: "assets",
      verb: "INSERT",
      event: (s) => OcptShotListPanelImportRequestedEvent(shotId: s.shotId, fileTypeLabel: "Image"),
    ),
    "replacing the image of a panel": (
      table: "assets",
      verb: "INSERT",
      event: (s) =>
          OcptShotListPanelReplaceRequestedEvent(panelId: s.firstPanelId, fileTypeLabel: "Image"),
    ),
    "reordering a panel": (
      table: "storyboard_panels",
      verb: "UPDATE",
      event: (s) => OcptShotListPanelReorderedEvent(
        shotId: s.shotId,
        panelId: s.firstPanelId,
        newPosition: 1,
      ),
    ),
    "deleting a panel": (
      table: "storyboard_panels",
      verb: "UPDATE",
      event: (s) => OcptShotListPanelDeletionRequestedEvent(panelId: s.secondPanelId),
    ),
    "drawing an arrow": (
      table: "storyboard_annotations",
      verb: "INSERT",
      event: (s) => OcptShotListAnnotationDrawnEvent(
        panelId: s.firstPanelId,
        kind: OcptStoryboardAnnotationKind.movementArrow,
        x1: 0.1,
        y1: 0.1,
        x2: 0.8,
        y2: 0.8,
      ),
    ),
    "placing a label": (
      table: "storyboard_annotations",
      verb: "INSERT",
      event: (s) => OcptShotListAnnotationPlacedEvent(panelId: s.firstPanelId, x1: 0.3, y1: 0.3),
    ),
    "deleting a mark": (
      table: "storyboard_annotations",
      verb: "UPDATE",
      event: (s) => OcptShotListAnnotationDeletionRequestedEvent(annotationId: s.annotationId),
    ),
  };

  for (final entry in cases.entries) {
    final case_ = entry.value;
    test(
      "${entry.key} raises the write error, reads nothing again, and goes through once lifted",
      () async {
        final held = mode.state;
        await refuse(case_.verb, case_.table);

        seeded.view.add(case_.event(seeded));
        await settle();

        expect(seeded.view.state.hasWriteError, isTrue);
        expect(mode.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");
        expect(seeded.view.state.selectedPanelId, isNull);
        expect(seeded.view.state.selectedAnnotationId, isNull);

        await lift(case_.verb, case_.table);
        seeded.view.add(const OcptShotListStoryboardWriteErrorDismissedEvent());
        seeded.view.add(case_.event(seeded));
        await settle();

        expect(seeded.view.state.hasWriteError, isFalse);
        expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
      },
    );
  }

  group("flushing the typed edits", () {
    /// Type a comment into the first panel and a text into the mark.
    Future<void> type() async {
      seeded.view.add(
        OcptShotListPanelCommentChangedEvent(panelId: seeded.firstPanelId, rawValue: "Wide"),
      );
      seeded.view.add(
        OcptShotListAnnotationTextChangedEvent(
          annotationId: seeded.annotationId,
          rawValue: "Pan left",
        ),
      );
      await settle();
    }

    test("a refused write loses the edits, raises the write error and goes on", () async {
      await type();
      final held = mode.state;
      await refuse("UPDATE", "storyboard_panels");

      final status = await seeded.view.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      expect(seeded.view.state.hasWriteError, isTrue);
      expect(seeded.view.state.pendingFieldEdits, isEmpty);
      expect(mode.state.reloadEpoch, held.reloadEpoch);

      await lift("UPDATE", "storyboard_panels");
      await type();

      expect(await seeded.view.flushPendingWrites(), OcptPendingWritesStatus.ok);
      expect(seeded.view.state.pendingFieldEdits, isEmpty);
      expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
    });

    test("a refused write stops the edits after it", () async {
      await type();
      await refuse("UPDATE", "storyboard_panels");

      await seeded.view.flushPendingWrites();
      await lift("UPDATE", "storyboard_panels");

      final snapshot = await projectsManager.storyboardService
          .loadStoryboard(
            database: projectsManager.currentProject!.database,
            screenplayId: projectsManager.currentProject!.primaryScreenplayId,
          )
          .valueOrFail;
      final panel = snapshot.panelsByShotId[seeded.shotId]!.first;
      expect(panel.comment, isEmpty);
      expect(panel.annotations.single.text, isNot("Pan left"), reason: "written after a failure");
    });

    test("a refused write leaves the edit to the next flush that has no state", () async {
      await type();
      final held = mode.state;
      await refuse("UPDATE", "storyboard_annotations");

      await seeded.view.flushPendingWritesWithoutState();

      expect(mode.state.reloadEpoch, held.reloadEpoch);
      expect(seeded.view.state.pendingFieldEdits, isNotEmpty);

      await lift("UPDATE", "storyboard_annotations");
      await seeded.view.flushPendingWritesWithoutState();
      await mode.reload({OcptShotListReloadScope.storyboard});

      final panel = mode.state.storyboardSnapshot!.panelsByShotId[seeded.shotId]!.first;
      expect(panel.annotations.single.text, "Pan left");
    });
  });
}
