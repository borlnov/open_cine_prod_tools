// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

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
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'shot_list_storyboard_bloc_test_doubles.dart';

/// Run the tests of the shot list storyboard bloc panels.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's write error path)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    // The in-memory preference store outlives a single test, so every test that reads a
    // preference back seeds the ones it cares about rather than assuming a pristine store.
    await propertiesManager.shotListVisibleColumns.store(OcptShotListColumn.defaultVisibleColumns);
    await propertiesManager.shotListLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await propertiesManager.shotListRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
    await propertiesManager.shotListLastRightDockTab.store(OcptShotListRightDockTab.inspector);

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_storyboard_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: testAppLanguageCode,
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
  /// gives the shot list its sequences.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Builds the mode bloc wired to the test project.
  OcptShotListBloc buildBloc({
    OcptStoryboardService? storyboardService,
    OcptShotListService? shotListService,
  }) => OcptShotListBloc(
    projectsManager: projectsManager,
    storyboardService: storyboardService,
    shotListService: shotListService,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the storyboard bloc of [modeBloc], picking frames through [fileSelectorManager] — a
  /// cancelled dialog unless the test says otherwise, so no test ever reaches a native one.
  OcptShotListStoryboardBloc buildBoard(
    OcptShotListBloc modeBloc, {
    FileSelectorManager fileSelectorManager = const StubFileSelectorManager(pickedPath: null),
    OcptStoryboardService? storyboardService,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptShotListStoryboardBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    storyboardService: storyboardService,
    fileSelectorManager: fileSelectorManager,
    fieldEditDebounce: fieldEditDebounce,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptShotListState> waitForState(
    OcptShotListBloc bloc,
    bool Function(OcptShotListState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Waits until [isDone] holds, looking again every few milliseconds: for a condition that spans
  /// the mode bloc and the storyboard bloc, whose states change in an order a test must not depend
  /// on.
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException("The awaited condition never held");
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Creates a shot in the first scene of [twoSceneText] and returns its id, waiting for the
  /// selection the creation event always makes.
  Future<String> createShot(OcptShotListBloc bloc) async {
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    return created.selectedShotId!;
  }

  /// Mounts both blocs on [twoSceneText] with one shot, and imports one panel onto it (selecting it,
  /// per the import handler), answering the blocs and the ids.
  Future<({OcptShotListBloc mode, OcptShotListStoryboardBloc board, String shotId, String panelId})>
  mountWithAPanel({
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
    OcptStoryboardService? storyboardService,
    OcptShotListService? shotListService,
  }) async {
    await writeScreenplay(twoSceneText);
    final mode = buildBloc(storyboardService: storyboardService, shotListService: shotListService);
    final board = buildBoard(
      mode,
      storyboardService: storyboardService,
      fileSelectorManager: const StubFileSelectorManager(pickedPath: "/frames/a.png"),
      fieldEditDebounce: fieldEditDebounce,
    );
    await waitForState(mode, (state) => !state.isLoading);
    final shotId = await createShot(mode);

    board.add(OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"));
    await waitUntil(
      () => mode.state.panelsOfShot(shotId).length == 1 && board.state.selectedPanelId != null,
    );

    return (
      mode: mode,
      board: board,
      shotId: shotId,
      panelId: mode.state.panelsOfShot(shotId).single.id,
    );
  }

  /// Closes the board and the mode, in the order the widget tree does.
  Future<void> closeAll(OcptShotListStoryboardBloc board, OcptShotListBloc mode) async {
    await board.close();
    await mode.close();
  }

  test("importing a frame appends a panel to the shot and selects it", () async {
    await writeScreenplay(twoSceneText);
    final mode = buildBloc();
    final board = buildBoard(
      mode,
      fileSelectorManager: const StubFileSelectorManager(pickedPath: "/frames/shot.png"),
    );
    await waitForState(mode, (state) => !state.isLoading);
    final shotId = await createShot(mode);

    board.add(OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"));
    await waitUntil(
      () => mode.state.panelsOfShot(shotId).length == 1 && board.state.selectedPanelId != null,
    );

    final panel = mode.state.panelsOfShot(shotId).single;
    expect(panel.imagePath, "/frames/shot.png");
    expect(panel.comment, isEmpty);
    expect(board.state.selectedPanelId, panel.id);

    await closeAll(board, mode);
  });

  test("a cancelled import leaves the shot with no panel", () async {
    await writeScreenplay(twoSceneText);
    final mode = buildBloc();
    final board = buildBoard(mode);
    await waitForState(mode, (state) => !state.isLoading);
    final shotId = await createShot(mode);

    board.add(OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"));
    // Nothing to wait for: a cancellation emits no state of its own.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(mode.state.panelsOfShot(shotId), isEmpty);

    await closeAll(board, mode);
  });

  test("replacing a panel's image re-points it without changing its id", () async {
    final mounted = await mountWithAPanel();
    final mode = mounted.mode;

    mounted.board.add(
      OcptShotListPanelReplaceRequestedEvent(panelId: mounted.panelId, fileTypeLabel: "Images"),
    );
    // The stub always answers the very same path, so wait past the moment `addPanel`'s own
    // event lands and assert the panel count never grows: only its image is re-pointed.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(mode.state.panelsOfShot(mounted.shotId).single.id, mounted.panelId);
    expect(mode.state.panelsOfShot(mounted.shotId), hasLength(1));

    await closeAll(mounted.board, mode);
  });

  test("reordering a panel moves it to the requested position, writing one row", () async {
    final mounted = await mountWithAPanel();
    final mode = mounted.mode;
    final shotId = mounted.shotId;

    for (var i = 1; i < 3; i++) {
      mounted.board.add(
        OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
      );
      await waitUntil(() => mode.state.panelsOfShot(shotId).length == i + 1);
    }

    final panelIds = mode.state.panelsOfShot(shotId).map((panel) => panel.id).toList();

    // Moves the first panel (index 0) to the last position (index 2).
    mounted.board.add(
      OcptShotListPanelReorderedEvent(shotId: shotId, panelId: panelIds[0], newPosition: 2),
    );
    await waitUntil(() => mode.state.panelsOfShot(shotId).first.id != panelIds[0]);

    expect(mode.state.panelsOfShot(shotId).map((panel) => panel.id).toList(), [
      panelIds[1],
      panelIds[2],
      panelIds[0],
    ]);

    await closeAll(mounted.board, mode);
  });

  test(
    "a panel comment is visible as a pending value and writes once after the debounce",
    () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;
      final shotId = mounted.shotId;
      final panelId = mounted.panelId;

      board.add(OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: "Push in"));
      await waitUntil(
        () =>
            board.state.pendingFieldEdits[OcptShotListPanelCommentEditKey(panelId: panelId)] ==
            "Push in",
      );
      expect(mode.state.panelsOfShot(shotId).single.comment, isEmpty);

      await waitUntil(
        () =>
            mode.state.panelsOfShot(shotId).single.comment == "Push in" &&
            board.state.pendingFieldEdits.isEmpty,
      );
      expect(board.state.pendingFieldEdits, isEmpty);

      await closeAll(board, mode);
    },
  );

  test("selecting another shot flushes a pending panel comment edit immediately", () async {
    final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(seconds: 30));
    final mode = mounted.mode;
    final board = mounted.board;
    final firstShotId = mounted.shotId;
    final panelId = mounted.panelId;

    mode.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(mode, (state) => state.totalShotCount == 2);

    board.add(OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: "Handheld"));
    // Switches back to the shot that owns the panel just typed into — a genuine change of
    // selection, unlike reselecting the second shot.
    mode.add(OcptShotListShotSelectedEvent(shotId: firstShotId));

    await waitUntil(
      () =>
          mode.state.panelsOfShot(firstShotId).single.comment == "Handheld" &&
          board.state.pendingFieldEdits.isEmpty,
    );
    expect(board.state.pendingFieldEdits, isEmpty);

    await closeAll(board, mode);
  });

  test("deleting a panel removes it and clears the selection", () async {
    final mounted = await mountWithAPanel();
    final mode = mounted.mode;
    final board = mounted.board;

    board.add(OcptShotListPanelSelectedEvent(panelId: mounted.panelId));
    await waitUntil(() => board.state.selectedPanelId == mounted.panelId);

    board.add(OcptShotListPanelDeletionRequestedEvent(panelId: mounted.panelId));
    await waitUntil(
      () => mode.state.panelsOfShot(mounted.shotId).isEmpty && board.state.selectedPanelId == null,
    );
    expect(board.state.selectedPanelId, isNull);

    await closeAll(board, mode);
  });

  test("deleting the shot cascades its panels and drops its pending comment edit", () async {
    final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(seconds: 30));
    final mode = mounted.mode;
    final board = mounted.board;
    final shotId = mounted.shotId;
    final panelId = mounted.panelId;

    board.add(OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: "Never written"));
    await waitUntil(
      () =>
          board.state.pendingFieldEdits[OcptShotListPanelCommentEditKey(panelId: panelId)] ==
          "Never written",
    );

    mode.add(OcptShotListShotDeletionRequestedEvent(shotId: shotId));
    await waitUntil(() => mode.state.totalShotCount == 0 && board.state.pendingFieldEdits.isEmpty);

    expect(board.state.pendingFieldEdits, isEmpty);
    expect(mode.state.storyboardSnapshot?.panelsOfShot(shotId), isEmpty);

    await closeAll(board, mode);
  });

  test("a captured panel is still there once its version is previewed, and once the preview "
      "is left", () async {
    // Dispatched to the very same, already-mounted blocs throughout — the path
    // `MixinOcptProjectVersionsBloc` actually uses (the Versions panel's own card),
    // mirroring `OcptResourcesBloc`'s own "a person created before the version is
    // captured, so it belongs to it" test. `OcptShotListBloc.reloadFromProjectDatabase`
    // is `_load`, which reads `_loadStoryboard` unconditionally, exactly as it
    // reads `_loadSnapshot` for the shots themselves — the board follows the identical
    // reload path a previewed version's shots already do.
    final mounted = await mountWithAPanel();
    final mode = mounted.mode;
    final shotId = mounted.shotId;

    mode.add(const OcptShotListCentreViewSelectedEvent(view: OcptShotListCentreView.board));

    mode.add(const OcptProjectVersionCreationRequestedEvent(name: "With a panel", note: ""));
    final withVersion = await waitForState(mode, (state) => state.projectVersions.isNotEmpty);
    final versionId = withVersion.projectVersions.single.id;

    mode.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    final previewing = await waitForState(mode, (state) => state.previewedVersionId != null);

    expect(previewing.isPreviewingVersion, isTrue);
    expect(previewing.centreView, OcptShotListCentreView.board);
    final previewedPanels = previewing.panelsOfShot(shotId);
    expect(previewedPanels, hasLength(1));
    expect(previewedPanels.single.imagePath, "/frames/a.png");

    mode.add(const OcptProjectVersionPreviewExitRequestedEvent());
    final backToWorkingCopy = await waitForState(mode, (state) => state.previewedVersionId == null);

    expect(backToWorkingCopy.panelsOfShot(shotId), hasLength(1));

    await closeAll(mounted.board, mode);
  });

  group("annotations", () {
    test("picking a tool sets it, and picking null again turns it off", () async {
      final mounted = await mountWithAPanel();
      final board = mounted.board;

      board.add(
        const OcptShotListAnnotationToolSelectedEvent(
          tool: OcptStoryboardAnnotationTool.movementArrow,
        ),
      );
      await waitUntil(
        () => board.state.activeAnnotationTool == OcptStoryboardAnnotationTool.movementArrow,
      );
      expect(board.state.activeAnnotationTool, OcptStoryboardAnnotationTool.movementArrow);

      board.add(const OcptShotListAnnotationToolSelectedEvent(tool: null));
      await waitUntil(() => board.state.activeAnnotationTool == null);
      expect(board.state.activeAnnotationTool, isNull);

      await closeAll(board, mounted.mode);
    });

    test("drawing an arrow adds a mark of that kind, normalised, and selects it", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.movementArrow,
          x1: 0.2,
          y1: 0.3,
          x2: 0.8,
          y2: 0.3,
        ),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.isNotEmpty &&
            board.state.selectedAnnotationId != null,
      );

      final mark = mode.state.panelsOfShot(mounted.shotId).single.annotations.single;
      expect(mark.kind, OcptStoryboardAnnotationKind.movementArrow);
      expect(mark.x1, 0.2);
      expect(mark.y1, 0.3);
      expect(mark.x2, 0.8);
      expect(mark.y2, 0.3);
      expect(board.state.selectedAnnotationId, mark.id);

      await closeAll(board, mode);
    });

    test(
      "placing a label adds it and selects it, and its text writes once after the debounce",
      () async {
        final mounted = await mountWithAPanel();
        final mode = mounted.mode;
        final board = mounted.board;

        board.add(OcptShotListAnnotationPlacedEvent(panelId: mounted.panelId, x1: 0.5, y1: 0.4));
        await waitUntil(
          () =>
              mode.state.panelsOfShot(mounted.shotId).single.annotations.isNotEmpty &&
              board.state.selectedAnnotationId != null,
        );
        final mark = mode.state.panelsOfShot(mounted.shotId).single.annotations.single;
        expect(mark.kind, OcptStoryboardAnnotationKind.label);
        expect(mark.x1, 0.5);
        expect(mark.y1, 0.4);
        expect(board.state.selectedAnnotationId, mark.id);

        // "Opens its text inline for editing": the mark is already selected once placed, ready
        // for the inspector's own text field to write into.
        board.add(
          OcptShotListAnnotationTextChangedEvent(annotationId: mark.id, rawValue: "Dolly in"),
        );
        await waitUntil(
          () =>
              board.state.pendingFieldEdits[OcptShotListAnnotationTextEditKey(
                annotationId: mark.id,
              )] ==
              "Dolly in",
        );
        expect(mode.state.panelsOfShot(mounted.shotId).single.annotations.single.text, isEmpty);

        await waitUntil(
          () =>
              mode.state.panelsOfShot(mounted.shotId).single.annotations.single.text ==
                  "Dolly in" &&
              board.state.pendingFieldEdits.isEmpty,
        );
        expect(board.state.pendingFieldEdits, isEmpty);

        await closeAll(board, mode);
      },
    );

    test("selecting a mark records its id", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.movementArrow,
          x1: 0.1,
          y1: 0.1,
          x2: 0.3,
          y2: 0.1,
        ),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.length == 1 &&
            board.state.selectedAnnotationId != null,
      );
      final firstMarkId = board.state.selectedAnnotationId!;

      // Drawing a second mark auto-selects it instead, moving selection away from the first.
      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.cameraMoveArrow,
          x1: 0.5,
          y1: 0.5,
          x2: 0.7,
          y2: 0.5,
        ),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.length == 2 &&
            board.state.selectedAnnotationId != firstMarkId,
      );
      expect(board.state.selectedAnnotationId, isNot(firstMarkId));

      board.add(OcptShotListAnnotationSelectedEvent(annotationId: firstMarkId));
      await waitUntil(() => board.state.selectedAnnotationId == firstMarkId);
      expect(board.state.selectedAnnotationId, firstMarkId);

      await closeAll(board, mode);
    });

    test("deleting a mark removes it and clears its own selection", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.movementArrow,
          x1: 0.2,
          y1: 0.2,
          x2: 0.6,
          y2: 0.2,
        ),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.isNotEmpty &&
            board.state.selectedAnnotationId != null,
      );
      final markId = board.state.selectedAnnotationId!;

      board.add(OcptShotListAnnotationDeletionRequestedEvent(annotationId: markId));
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.isEmpty &&
            board.state.selectedAnnotationId == null,
      );
      expect(board.state.selectedAnnotationId, isNull);

      await closeAll(board, mode);
    });

    test("deleting the panel cascades its marks and drops a pending mark-text edit", () async {
      final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(seconds: 30));
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(OcptShotListAnnotationPlacedEvent(panelId: mounted.panelId, x1: 0.5, y1: 0.5));
      await waitUntil(() => mode.state.panelsOfShot(mounted.shotId).single.annotations.isNotEmpty);
      final markId = mode.state.panelsOfShot(mounted.shotId).single.annotations.single.id;

      board.add(
        OcptShotListAnnotationTextChangedEvent(annotationId: markId, rawValue: "Never written"),
      );
      await waitUntil(
        () =>
            board.state.pendingFieldEdits[OcptShotListAnnotationTextEditKey(
              annotationId: markId,
            )] ==
            "Never written",
      );

      board.add(OcptShotListPanelDeletionRequestedEvent(panelId: mounted.panelId));
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).isEmpty &&
            board.state.pendingFieldEdits.isEmpty,
      );
      expect(board.state.pendingFieldEdits, isEmpty);

      await closeAll(board, mode);
    });

    test("selecting a different panel clears the active tool and the mark selection", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.movementArrow,
          x1: 0.2,
          y1: 0.2,
          x2: 0.6,
          y2: 0.2,
        ),
      );
      await waitUntil(() => board.state.selectedAnnotationId != null);

      board.add(
        const OcptShotListAnnotationToolSelectedEvent(tool: OcptStoryboardAnnotationTool.label),
      );
      await waitUntil(() => board.state.activeAnnotationTool == OcptStoryboardAnnotationTool.label);

      // Importing onto the very same shot appends and selects a second panel.
      board.add(
        OcptShotListPanelImportRequestedEvent(shotId: mounted.shotId, fileTypeLabel: "Images"),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).length == 2 &&
            board.state.selectedPanelId != mounted.panelId,
      );

      expect(board.state.selectedPanelId, isNot(mounted.panelId));
      expect(board.state.activeAnnotationTool, isNull);
      expect(board.state.selectedAnnotationId, isNull);

      await closeAll(board, mode);
    });
  });
}
