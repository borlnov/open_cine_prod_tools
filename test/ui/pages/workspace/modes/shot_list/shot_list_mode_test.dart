// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_character_name_picker_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_focus_strip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_scenario_coverage_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_annotation_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_board.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panel_strip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panels_group.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_shot_leader_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The navigator [_wrapWithLocalization] mounts, so [_RecordingRouterManager.pop] can close a
/// dialog opened through `showDialog` (the export panel, the scenario coverage options dialog)
/// exactly as the real `GoRouter.pop` would — both push onto the very same root `Navigator`. See
/// `test/ui/pages/editor/editor_page_test.dart`'s own instance of the same pattern.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] records every call and then pops [_navigatorKey]'s own navigator,
/// so a dialog opened through `showDialog` genuinely closes: this mode's own bloc resolves its
/// router manager from `globalGetIt()`, with no real GoRouter for `pop` to delegate to.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests,
/// [_navigatorKey] so [_RecordingRouterManager.pop] can close a dialog opened through
/// `showDialog`, a bare [Scaffold]: unlike `EditorPage`, a production mode expects the real
/// `WorkspacePage` to provide one, and an `OcptWorkspaceBloc` ancestor — `WorkspacePage` always
/// provides one too, and this mode now reads it for the toolbar episode selector's
/// episodes/selection.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  navigatorKey: _navigatorKey,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: BlocProvider<OcptWorkspaceBloc>(
    create: (context) => OcptWorkspaceBloc(),
    child: Scaffold(body: child),
  ),
);

/// An export manager whose [exportShotListXlsx] is stubbed and records the episode tag it was
/// handed, so a test can tell what `OcptShotListMode` itself computed and dispatched — the mode's
/// own `_episodeExportTag`, not the bloc's own scoped episode, is under test here.
class _RecordingExportManager extends OcptExportManager {
  /// Class constructor
  _RecordingExportManager() : super(fileSelectorManager: const FileSelectorManager());

  /// The episode tag of the last [exportShotListXlsx] call.
  String? lastExportedEpisodeTag;

  @override
  Future<OcptExportOutcome?> exportShotListXlsx({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedEpisodeTag = episodeTag;
    return OcptExportSaved("/tmp/$projectName.xlsx");
  }
}

/// A file selector manager answering the picker with a file of its own, so a board test never
/// opens a native dialog: [pickedPath] is what the user is pretending to pick. Mirrors
/// `shot_list_bloc_test.dart`'s own test double of the same name.
class _StubFileSelectorManager extends FileSelectorManager {
  /// The path the next pick answers with.
  final String pickedPath;

  /// Class constructor
  const _StubFileSelectorManager({required this.pickedPath});

  /// Answers with [pickedPath] instead of opening the platform's own dialog.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async => ResultWithBoolStatus(status: BoolResultStatus.success, value: XFile(pickedPath));
}

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(_RecordingRouterManager())
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      )
      // `OcptShotListBloc` resolves this itself for the board's own frame picker, with no test
      // seam of its own (built by the mode, exactly like the export manager above) — the plain
      // manager here never actually opens a dialog unless a board test swaps it for
      // `_StubFileSelectorManager` through `useFileSelectorManager`.
      ..registerSingleton<FileSelectorManager>(const FileSelectorManager());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_mode_test_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);

    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: "INT. KITCHEN - DAY\n\nAction.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
  });

  tearDown(() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  });

  /// A finder scoped to the export panel's own `AlertDialog`: the panel's card titles
  /// (`Shot list`) can otherwise collide with the toolbar's own muted mode label, which reads the
  /// same word.
  Finder inPanel(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  /// Swaps the registered `OcptExportManager` for [manager] for the rest of the current test,
  /// restoring the shared real one afterward — `OcptShotListBloc` resolves its export manager from
  /// `globalGetIt()` (it's built by the mode itself, with no test seam of its own), so this is what
  /// lets a test observe what a real export call was handed.
  void useExportManager(OcptExportManager manager) {
    final managers = OcptGlobalManager.instance.managers;
    final previous = managers.get<OcptExportManager>();
    managers
      // `unregister` returns `FutureOr` only because it may await a disposing function; none is
      // registered here, so it never actually returns anything to wait for.
      // ignore: discarded_futures
      ..unregister<OcptExportManager>()
      ..registerSingleton<OcptExportManager>(manager);
    addTearDown(() {
      managers
        // See the identical `unregister` call above for why this is safe to leave un-awaited.
        // ignore: discarded_futures
        ..unregister<OcptExportManager>()
        ..registerSingleton<OcptExportManager>(previous);
    });
  }

  /// Swaps the registered `FileSelectorManager` for [manager] for the rest of the current test,
  /// restoring the plain one afterward — mirrors [useExportManager] exactly, for the board's own
  /// frame picker.
  void useFileSelectorManager(FileSelectorManager manager) {
    final managers = OcptGlobalManager.instance.managers;
    final previous = managers.get<FileSelectorManager>();
    managers
      // `unregister` returns `FutureOr` only because it may await a disposing function; none is
      // registered here, so it never actually returns anything to wait for.
      // ignore: discarded_futures
      ..unregister<FileSelectorManager>()
      ..registerSingleton<FileSelectorManager>(manager);
    addTearDown(() {
      managers
        // See the identical `unregister` call above for why this is safe to leave un-awaited.
        // ignore: discarded_futures
        ..unregister<FileSelectorManager>()
        ..registerSingleton<FileSelectorManager>(previous);
    });
  }

  testWidgets(
    "with no shot placed, the export panel lists both documents as unavailable and says why",
    (tester) async {
      // Wide enough for the whole shell, so the toolbar's own `Export` button is on screen.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(find.text(tr.shotListExportPanelTitle), findsOneWidget);
      expect(inPanel(find.text(tr.shotListExportXlsxTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.shotListExportCoverageTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.shotListExportUnavailableReason)), findsNWidgets(2));
      expect(inPanel(find.text(tr.shotListExportXlsxDescription)), findsNothing);
      expect(inPanel(find.text(tr.shotListExportCoverageDescription)), findsNothing);

      // An unavailable card is inert: tapping it pops nothing, so the panel stays open.
      await tester.tap(inPanel(find.text(tr.shotListExportXlsxTitle)));
      await tester.pumpAndSettle();
      expect(find.text(tr.shotListExportPanelTitle), findsOneWidget);
    },
  );

  testWidgets(
    "once a shot is placed, picking the scenario coverage card opens its own export options "
    "dialog",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListAddShotAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(inPanel(find.text(tr.shotListExportUnavailableReason)), findsNothing);
      expect(inPanel(find.text(tr.shotListExportXlsxDescription)), findsOneWidget);
      expect(inPanel(find.text(tr.shotListExportCoverageDescription)), findsOneWidget);

      await tester.tap(inPanel(find.text(tr.shotListExportCoverageTitle)));
      await tester.pumpAndSettle();

      expect(find.text(tr.shotListExportPanelTitle), findsNothing);
      expect(find.byType(OcptScenarioCoverageExportDialog), findsOneWidget);
    },
  );

  testWidgets(
    "picking the shot list card dispatches the export request directly, with no options dialog "
    "of its own",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListAddShotAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(inPanel(find.text(tr.shotListExportXlsxTitle)));
      await tester.pumpAndSettle();

      expect(find.text(tr.shotListExportPanelTitle), findsNothing);
      expect(find.byType(OcptScenarioCoverageExportDialog), findsNothing);
      expect(find.byType(OcptShotListMode), findsOneWidget);
    },
  );

  testWidgets(
    "a project holding one episode dispatches a null episode tag when exporting the workbook",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final exportManager = _RecordingExportManager();
      useExportManager(exportManager);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListAddShotAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(inPanel(find.text(tr.shotListExportXlsxTitle)));
      await tester.pumpAndSettle();

      expect(exportManager.lastExportedEpisodeTag, isNull);
    },
  );

  testWidgets(
    "a project holding two episodes dispatches the selected one's tag when exporting the "
    "workbook",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
      );

      final exportManager = _RecordingExportManager();
      useExportManager(exportManager);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptShotListMode));
      final tr = Tr.of(context);

      // The workspace bloc lands on the first episode by default; select the second one so the
      // exported tag can be told apart from what a single-episode project would produce.
      context.read<OcptWorkspaceBloc>().add(
        OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr.shotListAddShotAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(inPanel(find.text(tr.shotListExportXlsxTitle)));
      await tester.pumpAndSettle();

      expect(exportManager.lastExportedEpisodeTag, tr.workspaceEpisodeTag(2));
    },
  );

  group("the floating add at a compact width", () {
    /// Closes the left dock, open by default, so its drawer stops covering the centre — the
    /// floating add sits behind it otherwise, exactly as the scrim does for any other tap.
    testWidgets("is present at a compact width", (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets("is absent at a desktop width", (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets(
      "tapping it fires the shot creation flow and opens the inspector drawer on the new shot",
      (tester) async {
        tester.view.physicalSize = const Size(700, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
        await tester.pumpAndSettle();

        // On compact the docks start closed, so the left sequence panel is not covering the centre
        // and the floating add button is free to tap — no need to close a dock first.

        // Read from a descendant of the mode's own `BlocProvider` — `OcptShotListMode` builds it,
        // so its own element sits above it and cannot resolve it.
        final bloc = tester.element(find.byType(FloatingActionButton)).read<OcptShotListBloc>();
        expect(bloc.state.totalShotCount, 0);
        expect(find.byType(OcptShotInspectorPanel), findsNothing);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // The very same event the left dock's own `+ Shot` button fires: one more shot, selected,
        // with the right dock opened on its inspector tab.
        expect(bloc.state.totalShotCount, 1);
        expect(find.byType(OcptShotInspectorPanel), findsOneWidget);
      },
    );

    testWidgets("is withheld under a previewed version", (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final version = await projectsManager.createProjectVersion(name: "v1", note: "");
      expect(version, isNotNull);
      final previewResult = await projectsManager.previewVersion(version!.id);
      expect(previewResult.status.isSuccess, isTrue);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);

      // Leave the preview so the working copy is what the next test opens onto.
      await projectsManager.exitPreview();
    });
  });

  group("the board", () {
    /// Sets the test surface past the 800 px compact breakpoint, mounts the mode, and creates and
    /// selects a shot — the starting point every board test but the compact-width one shares.
    Future<OcptShotListBloc> mountWithASelectedShot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final bloc = tester.element(find.byType(OcptShotListStatusBar)).read<OcptShotListBloc>();
      bloc.add(const OcptShotListShotCreationRequestedEvent());
      await tester.pumpAndSettle();
      expect(bloc.state.selectedShotId, isNotNull);

      return bloc;
    }

    testWidgets("switching to the board keeps the selected shot", (tester) async {
      final bloc = await mountWithASelectedShot(tester);
      final shotId = bloc.state.selectedShotId;
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListBoardBoardSegmentLabel));
      await tester.pumpAndSettle();

      expect(bloc.state.centreView, OcptShotListCentreView.board);
      expect(bloc.state.selectedShotId, shotId);
      expect(find.byType(OcptStoryboardBoard), findsOneWidget);

      // Switching back keeps it too.
      await tester.tap(find.text(tr.shotListBoardTableSegmentLabel));
      await tester.pumpAndSettle();

      expect(bloc.state.centreView, OcptShotListCentreView.table);
      expect(bloc.state.selectedShotId, shotId);
    });

    testWidgets("a compact width offers the table only, the Board segment never shown", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));
      expect(find.text(tr.shotListBoardTableSegmentLabel), findsOneWidget);
      expect(find.text(tr.shotListBoardBoardSegmentLabel), findsNothing);
      expect(find.byType(OcptStoryboardBoard), findsNothing);
    });

    testWidgets(
      "importing a frame appends a panel, and Delete panel asks through the confirm dialog "
      "before removing it",
      (tester) async {
        useFileSelectorManager(const _StubFileSelectorManager(pickedPath: "/frames/a.png"));

        final bloc = await mountWithASelectedShot(tester);
        final shotId = bloc.state.selectedShotId!;
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

        await tester.tap(find.text(tr.shotListBoardBoardSegmentLabel));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await tester.pumpAndSettle();

        expect(bloc.state.panelsOfShot(shotId), hasLength(1));

        // The inspector's Panels group own `Delete panel` action only asks.
        await tester.tap(
          find.descendant(
            of: find.byType(OcptStoryboardPanelsGroup),
            matching: find.byIcon(Icons.delete_outline),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OcptConfirmDialog), findsOneWidget);
        expect(bloc.state.panelsOfShot(shotId), hasLength(1));

        await tester.tap(find.text(tr.shotListDeleteConfirmDeleteAction));
        await tester.pumpAndSettle();

        expect(bloc.state.panelsOfShot(shotId), isEmpty);
      },
    );

    testWidgets(
      "the board's own frame shows a Delete panel action too, asking through the same "
      "confirm dialog before removing it",
      (tester) async {
        useFileSelectorManager(const _StubFileSelectorManager(pickedPath: "/frames/a.png"));

        final bloc = await mountWithASelectedShot(tester);
        final shotId = bloc.state.selectedShotId!;
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

        await tester.tap(find.text(tr.shotListBoardBoardSegmentLabel));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await tester.pumpAndSettle();

        expect(bloc.state.panelsOfShot(shotId), hasLength(1));

        // The frame's own `Delete panel` action, drawn on the panel itself — not the inspector's —
        // only asks, exactly like the inspector's Panels group action above.
        final boardDeleteFinder = find.descendant(
          of: find.byType(OcptStoryboardPanelFrame),
          matching: find.byIcon(Icons.delete_outline),
        );
        await tester.ensureVisible(boardDeleteFinder);
        await tester.pumpAndSettle();
        await tester.tap(boardDeleteFinder);
        await tester.pumpAndSettle();

        expect(find.byType(OcptConfirmDialog), findsOneWidget);
        expect(bloc.state.panelsOfShot(shotId), hasLength(1));

        await tester.tap(find.text(tr.shotListDeleteConfirmDeleteAction));
        await tester.pumpAndSettle();

        expect(bloc.state.panelsOfShot(shotId), isEmpty);
      },
    );

    testWidgets("a previewed version withholds Import frame and Delete panel", (tester) async {
      useFileSelectorManager(const _StubFileSelectorManager(pickedPath: "/frames/a.png"));

      final bloc = await mountWithASelectedShot(tester);
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListBoardBoardSegmentLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();
      expect(bloc.state.panelsOfShot(bloc.state.selectedShotId!), hasLength(1));

      final version = await projectsManager.createProjectVersion(name: "v1", note: "");
      expect(version, isNotNull);
      final previewResult = await projectsManager.previewVersion(version!.id);
      expect(previewResult.status.isSuccess, isTrue);

      // Unmounts, then remounts fresh: `pumpWidget` alone would just rebuild the very same
      // element tree in place — the same `BlocProvider`, so the same bloc, never reloaded —
      // whereas every other previewed-version test of this file enters the preview *before* its
      // very first mount. Tearing down first forces a genuinely new `OcptShotListBloc`, which
      // loads from the project exactly as those do; the centre view and the panel just imported
      // both come back from what was just persisted/written, since a preview reads the very same
      // project.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final previewedBloc = tester.element(find.byType(OcptShotListStatusBar)).read<OcptShotListBloc>();
      expect(previewedBloc.state.isPreviewingVersion, isTrue);
      expect(previewedBloc.state.centreView, OcptShotListCentreView.board);

      // The strip's own import slot no longer reports a tap, whichever of its two labels
      // (`+ Import frame` or `no panel yet`) is the one showing.
      final importSlotFinder = find.byIcon(Icons.add_photo_alternate_outlined);
      expect(importSlotFinder, findsOneWidget);
      final importInkWell = tester.widget<InkWell>(
        find.ancestor(of: importSlotFinder, matching: find.byType(InkWell)).first,
      );
      expect(importInkWell.onTap, isNull);

      // Selecting the shot is never withheld (it only reads), and once selected neither the
      // Panels group's own `Delete panel` icon nor the board frame's own copy of it is built at
      // all.
      await tester.tap(find.byType(OcptStoryboardShotLeaderCard));
      await tester.pumpAndSettle();
      expect(previewedBloc.state.selectedShotId, isNotNull);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // Leave the preview so the working copy is what the next test opens onto.
      await projectsManager.exitPreview();
    });

    group("annotations", () {
      /// [mountWithASelectedShot], switched to the board, with one panel imported onto the
      /// selected shot and selected — the starting point every annotation test shares.
      Future<OcptShotListBloc> mountWithASelectedPanel(WidgetTester tester) async {
        useFileSelectorManager(const _StubFileSelectorManager(pickedPath: "/frames/a.png"));

        final bloc = await mountWithASelectedShot(tester);
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

        await tester.tap(find.text(tr.shotListBoardBoardSegmentLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await tester.pumpAndSettle();
        expect(bloc.state.selectedPanelId, isNotNull);

        return bloc;
      }

      testWidgets(
        "picking the label tool then clicking the frame places a mark, and Remove asks "
        "through the confirm dialog before removing it",
        (tester) async {
          final bloc = await mountWithASelectedPanel(tester);
          final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

          await tester.tap(find.text(tr.shotListBoardAnnotationToolLabelSegmentLabel));
          await tester.pumpAndSettle();
          expect(bloc.state.activeAnnotationTool, OcptStoryboardAnnotationTool.label);

          await tester.tapAt(tester.getCenter(find.byType(OcptStoryboardPanelFrame)));
          await tester.pumpAndSettle();

          final panel = bloc.state.selectedPanel!;
          expect(panel.annotations, hasLength(1));
          expect(bloc.state.selectedAnnotationId, panel.annotations.single.id);

          await tester.tap(find.byTooltip(tr.shotListBoardRemoveAnnotationAction));
          await tester.pumpAndSettle();

          expect(find.byType(OcptConfirmDialog), findsOneWidget);
          expect(bloc.state.selectedPanel!.annotations, hasLength(1));

          await tester.tap(find.text(tr.shotListDeleteConfirmDeleteAction));
          await tester.pumpAndSettle();

          expect(bloc.state.selectedPanel!.annotations, isEmpty);
        },
      );

      testWidgets("dragging over the frame with the movement arrow tool draws a mark", (
        tester,
      ) async {
        final bloc = await mountWithASelectedPanel(tester);
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

        await tester.tap(find.text(tr.shotListBoardAnnotationToolMovementArrowLabel));
        await tester.pumpAndSettle();
        expect(bloc.state.activeAnnotationTool, OcptStoryboardAnnotationTool.movementArrow);

        final frameCenter = tester.getCenter(find.byType(OcptStoryboardPanelFrame));
        final gesture = await tester.startGesture(frameCenter - const Offset(30, 0));
        await gesture.moveBy(const Offset(60, 0));
        await gesture.up();
        await tester.pumpAndSettle();

        final annotations = bloc.state.selectedPanel!.annotations;
        expect(annotations, hasLength(1));
        expect(annotations.single.kind, OcptStoryboardAnnotationKind.movementArrow);
      });

      testWidgets(
        "a previewed version withholds the Annotate control, the gestures and the remove "
        "action, while still drawing the existing mark",
        (tester) async {
          final bloc = await mountWithASelectedPanel(tester);
          final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));
          final panelId = bloc.state.selectedPanelId!;

          bloc.add(
            OcptShotListAnnotationPlacedEvent(panelId: panelId, x1: 0.5, y1: 0.4),
          );
          await tester.pumpAndSettle();
          expect(bloc.state.selectedPanel!.annotations, hasLength(1));

          final version = await projectsManager.createProjectVersion(name: "With a mark", note: "");
          expect(version, isNotNull);
          final previewResult = await projectsManager.previewVersion(version!.id);
          expect(previewResult.status.isSuccess, isTrue);

          // Remounts fresh, exactly as the sibling panel-level test above does, so a genuinely
          // new, read-only `OcptShotListBloc` loads from what was just captured.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
          await tester.pumpAndSettle();

          final previewedBloc = tester
              .element(find.byType(OcptShotListStatusBar))
              .read<OcptShotListBloc>();
          expect(previewedBloc.state.isPreviewingVersion, isTrue);
          expect(previewedBloc.state.centreView, OcptShotListCentreView.board);

          // Selecting the shot, then its panel, is never withheld (it only reads) — a fresh
          // reload starts with neither selected, and `selectedPanel` needs both (it reads off
          // `panelsOfSelectedShot`, which is empty without a selected shot).
          await tester.tap(find.byType(OcptStoryboardShotLeaderCard));
          await tester.pumpAndSettle();
          expect(previewedBloc.state.selectedShotId, isNotNull);
          await tester.tap(find.byType(OcptStoryboardPanelFrame));
          await tester.pumpAndSettle();
          expect(previewedBloc.state.selectedPanelId, isNotNull);

          // The Annotate control and the mark's own remove action are never built at all.
          expect(find.byType(SegmentedButton<OcptStoryboardAnnotationTool>), findsNothing);
          expect(find.byTooltip(tr.shotListBoardRemoveAnnotationAction), findsNothing);

          // The overlay still draws the mark captured in the version — a read, kept read-only.
          final painters = tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((widget) => widget.painter)
              .whereType<OcptStoryboardAnnotationOverlayPainter>()
              .toList();
          expect(painters, isNotEmpty);
          expect(painters.first.annotations, hasLength(1));

          // A drag over the frame draws nothing: with no tool ever pickable, the gesture layer
          // never turns live.
          final frameCenter = tester.getCenter(find.byType(OcptStoryboardPanelFrame));
          final gesture = await tester.startGesture(frameCenter - const Offset(30, 0));
          await gesture.moveBy(const Offset(60, 0));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(previewedBloc.state.selectedPanel!.annotations, hasLength(1));

          // Leave the preview so the working copy is what the next test opens onto.
          await projectsManager.exitPreview();
        },
      );
    });
  });

  group("the floor plans", () {
    /// Sets the test surface past the 800 px compact breakpoint, mounts the mode, and switches to
    /// the floor plans view — the starting point every floor plans test but the compact-width one
    /// shares.
    Future<OcptShotListBloc> mountOnFloorPlans(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final bloc = tester.element(find.byType(OcptShotListStatusBar)).read<OcptShotListBloc>();
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListFloorPlanSegmentLabel));
      await tester.pumpAndSettle();
      expect(bloc.state.centreView, OcptShotListCentreView.floorPlans);

      return bloc;
    }

    /// [mountOnFloorPlans], with a case created (and selected) on the sole sequence.
    Future<OcptShotListBloc> mountWithACase(WidgetTester tester) async {
      final bloc = await mountOnFloorPlans(tester);
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.byTooltip(tr.shotListFloorPlanAddCaseAction));
      await tester.pumpAndSettle();
      expect(bloc.state.selectedSetId, isNotNull);

      return bloc;
    }

    testWidgets("a compact width offers the table only, the Floor plans segment never shown", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));
      expect(find.text(tr.shotListBoardTableSegmentLabel), findsOneWidget);
      expect(find.text(tr.shotListFloorPlanSegmentLabel), findsNothing);
      expect(find.byType(OcptFloorPlanCanvas), findsNothing);
    });

    testWidgets("+ Case creates a case named from the scene heading's place and selects it", (
      tester,
    ) async {
      final bloc = await mountOnFloorPlans(tester);
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.byTooltip(tr.shotListFloorPlanAddCaseAction));
      await tester.pumpAndSettle();

      expect(bloc.state.setsOfSelectedSequence, hasLength(1));
      final createdCase = bloc.state.setsOfSelectedSequence.single;
      expect(bloc.state.selectedSetId, createdCase.id);
      expect(createdCase.name, "KITCHEN");
      expect(find.text("KITCHEN"), findsOneWidget);
    });

    testWidgets("picking the set element tool and clicking the canvas places a symbol", (
      tester,
    ) async {
      final bloc = await mountWithACase(tester);
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.byTooltip(tr.shotListFloorPlanToolSetElementAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OcptFloorPlanCanvas));
      await tester.pumpAndSettle();

      final symbols = bloc.state.selectedSet!.symbols;
      expect(symbols, hasLength(1));
      // Sequence-scoped: the M5 scope invariant this whole milestone stands on.
      expect(symbols.single.shotId, isNull);
      expect(symbols.single.layer.isSequenceScoped, isTrue);
      expect(bloc.state.selectedFloorPlanSymbolId, symbols.single.id);
    });

    testWidgets("deleting the selected symbol asks through the confirm dialog", (tester) async {
      final bloc = await mountWithACase(tester);
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.byTooltip(tr.shotListFloorPlanToolSetElementAction));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OcptFloorPlanCanvas));
      await tester.pumpAndSettle();
      expect(bloc.state.selectedSet!.symbols, hasLength(1));

      await tester.tap(find.byTooltip(tr.shotListFloorPlanDeleteSymbolAction));
      await tester.pumpAndSettle();

      expect(find.byType(OcptConfirmDialog), findsOneWidget);
      expect(bloc.state.selectedSet!.symbols, hasLength(1));

      await tester.tap(find.text(tr.shotListDeleteConfirmDeleteAction));
      await tester.pumpAndSettle();

      expect(bloc.state.selectedSet!.symbols, isEmpty);
    });

    testWidgets(
      "a previewed version withholds + Case, the set element tool and symbol placement",
      (tester) async {
        await mountWithACase(tester);

        final version = await projectsManager.createProjectVersion(name: "v1", note: "");
        expect(version, isNotNull);
        final previewResult = await projectsManager.previewVersion(version!.id);
        expect(previewResult.status.isSuccess, isTrue);

        // Unmounts, then remounts fresh — see the board's own previewed-version test for why.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
        await tester.pumpAndSettle();

        final previewedBloc = tester
            .element(find.byType(OcptShotListStatusBar))
            .read<OcptShotListBloc>();
        expect(previewedBloc.state.isPreviewingVersion, isTrue);
        expect(previewedBloc.state.centreView, OcptShotListCentreView.floorPlans);
        expect(previewedBloc.state.selectedSetId, isNotNull);

        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

        // `+ Case` no longer reports a tap.
        final addSetButton = tester.widget<IconButton>(
          find.descendant(
            of: find.byTooltip(tr.shotListFloorPlanAddCaseAction),
            matching: find.byType(IconButton),
          ),
        );
        expect(addSetButton.onPressed, isNull);

        // The `setElement` tool is withheld too (a null `onPressed`), so it can never be picked
        // to place anything in the first place.
        final setElementButton = tester.widget<IconButton>(
          find.descendant(
            of: find.byTooltip(tr.shotListFloorPlanToolSetElementAction),
            matching: find.byType(IconButton),
          ),
        );
        expect(setElementButton.onPressed, isNull);

        // The shot-scoped camera tool is withheld too, under the preview (no tool is ever dimmed
        // any more, R2 — only `isReadOnly` withholds a tool bar button now).
        final cameraButton = tester.widget<IconButton>(
          find.descendant(
            of: find.byTooltip(tr.shotListFloorPlanToolCameraAction),
            matching: find.byType(IconButton),
          ),
        );
        expect(cameraButton.onPressed, isNull);

        // The canvas's own write callback is withheld directly, whichever tool ends up active —
        // the null closes the whole placing gesture at its source, exactly like the board's own
        // null callbacks. Reads (selecting, focusing a ghost's shot) stay available.
        final canvas = tester.widget<OcptFloorPlanCanvas>(find.byType(OcptFloorPlanCanvas));
        expect(canvas.onSymbolPlaced, isNull);
        expect(canvas.onSymbolMoved, isNull);
        expect(canvas.onSymbolDeleteRequested, isNull);
        expect(canvas.onArrowSymbolTapped, isNull);
        expect(canvas.onArrowAnchorCancelled, isNull);
        expect(canvas.onSymbolLabelChanged, isNull);
        expect(canvas.onSymbolSelected, isNotNull);
        expect(canvas.onGhostShotFocusRequested, isNotNull);

        // Leave the preview so the working copy is what the next test opens onto.
        await projectsManager.exitPreview();
      },
    );

    testWidgets(
      "creating a second shot's own chip selects it, always one active (R2)",
      (tester) async {
        final bloc = await mountWithACase(tester);

        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await tester.pumpAndSettle();
        final firstShotId = bloc.state.selectedShotId!;
        final firstShotCode = bloc.state.selectedShot!.code;
        expect(bloc.state.isFloorPlanShotFocusActive, isTrue);

        // The shot's own chip is already active (the very selection the table's rows share) —
        // scoped to the focus strip: the shot's own code is also shown by the left tree and the
        // inspector header.
        final firstShotChipFinder = find.descendant(
          of: find.byType(OcptFloorPlanFocusStrip),
          matching: find.text(firstShotCode),
        );
        expect(firstShotChipFinder, findsOneWidget);

        // A second shot's own creation selects it in turn — there is no `Sequence` chip to flip
        // back to any more: the current shot is never null while the sequence holds one.
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await tester.pumpAndSettle();
        final secondShotId = bloc.state.selectedShotId!;
        expect(secondShotId, isNot(firstShotId));

        // Tapping the first shot's own chip again re-selects it — the mode's one selection,
        // shared with the table.
        await tester.tap(firstShotChipFinder);
        await tester.pumpAndSettle();
        expect(bloc.state.selectedShotId, firstShotId);
      },
    );

    testWidgets(
      "placing a camera under the shot focus, then deleting it, asks through the confirm dialog",
      (tester) async {
        final bloc = await mountWithACase(tester);
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await tester.pumpAndSettle();
        final shotId = bloc.state.selectedShotId!;
        expect(bloc.state.isFloorPlanShotFocusActive, isTrue);

        // Creating the shot opened the right dock on its own inspector tab, narrowing the centre
        // column enough to make the tool bar's own tap targets unreliable to hit-test against in
        // this harness; closing it again leaves the shot focus untouched (`selectedShotId` is a
        // separate field from `rightDockTab`) and restores the same full-width toolbar every other
        // floor plans test taps against.
        bloc.add(const OcptShotListRightDockClosedEvent());
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(tr.shotListFloorPlanToolCameraAction));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(OcptFloorPlanCanvas));
        await tester.pumpAndSettle();

        final symbols = bloc.state.selectedSet!.symbols;
        expect(symbols, hasLength(1));
        expect(symbols.single.shotId, shotId);
        expect(symbols.single.layer, OcptFloorPlanLayer.cameras);

        // Deleting it, exactly as a sequence-scoped symbol's own delete does, only asks.
        await tester.tap(find.byTooltip(tr.shotListFloorPlanDeleteSymbolAction));
        await tester.pumpAndSettle();
        expect(find.byType(OcptConfirmDialog), findsOneWidget);
        expect(bloc.state.selectedSet!.symbols, hasLength(1));

        await tester.tap(find.text(tr.shotListDeleteConfirmDeleteAction));
        await tester.pumpAndSettle();
        expect(bloc.state.selectedSet!.symbols, isEmpty);
      },
    );

    testWidgets(
      "placing a character symbol opens the name popover at once, picking a name writes it "
      "(R2)",
      (tester) async {
        final bloc = await mountWithACase(tester);
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await tester.pumpAndSettle();
        bloc.add(const OcptShotListRightDockClosedEvent());
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(tr.shotListFloorPlanToolCharacterAction));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(OcptFloorPlanCanvas));
        await tester.pumpAndSettle();

        // The placed symbol is selected at once, and the name popover opens for it immediately —
        // no further click needed.
        final symbolId = bloc.state.selectedSet!.symbols.single.id;
        expect(bloc.state.selectedFloorPlanSymbolId, symbolId);
        expect(find.byType(OcptFloorPlanCharacterNamePickerDialog), findsOneWidget);
        expect(find.text(tr.shotListFloorPlanCharacterNamePickerTitle), findsOneWidget);

        await tester.enterText(
          find.descendant(
            of: find.byType(OcptFloorPlanCharacterNamePickerDialog),
            matching: find.byType(TextField),
          ),
          "SAM",
        );
        await tester.tap(find.text(tr.shotListFloorPlanCharacterNamePickerSetAction));
        await tester.pumpAndSettle();

        expect(find.byType(OcptFloorPlanCharacterNamePickerDialog), findsNothing);
        expect(bloc.state.selectedSet!.symbols.single.label, "SAM");
      },
    );
  });
}
