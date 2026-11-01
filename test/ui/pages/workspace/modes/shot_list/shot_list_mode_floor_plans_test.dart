// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_character_name_picker_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_focus_strip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_set_gallery.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_set_tabs.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_status_bar.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'shot_list_mode_test_doubles.dart';

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
      ..registerSingleton<OcptRouterManager>(RecordingRouterManager())
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

  group("the floor plans", () {
    /// Sets the test surface past the 800 px compact breakpoint, mounts the mode, and switches to
    /// the floor plans view — the starting point every floor plans test but the compact-width one
    /// shares.
    /// The floor plan canvas bloc of the mounted mode, the one holding the tool and the selected
    /// symbol.
    OcptShotListFloorPlanCanvasBloc canvasBlocOf(WidgetTester tester) =>
        tester.element(find.byType(OcptShotListStatusBar)).read<OcptShotListFloorPlanCanvasBloc>();

    Future<OcptShotListBloc> mountOnFloorPlans(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final bloc = tester.element(find.byType(OcptShotListStatusBar)).read<OcptShotListBloc>();
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListFloorPlanSegmentLabel));
      await tester.pumpAndSettle();
      expect(bloc.state.centreView, OcptShotListCentreView.floorPlans);

      return bloc;
    }

    /// [mountOnFloorPlans], with a set created (and selected) on the sole sequence — the `＋ Set`
    /// button's own menu opened, its own `Create a set` submenu opened, then its own
    /// `New location…` entry picked (a fresh test project holds no location yet to offer instead).
    Future<OcptShotListBloc> mountWithACase(WidgetTester tester) async {
      final bloc = await mountOnFloorPlans(tester);
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.shotListFloorPlanCreateSetMenuAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.shotListFloorPlanNewLocationMenuAction));
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

      await tester.pumpWidget(wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));
      expect(find.text(tr.shotListBoardTableSegmentLabel), findsOneWidget);
      expect(find.text(tr.shotListFloorPlanSegmentLabel), findsNothing);
      expect(find.byType(OcptFloorPlanCanvas), findsNothing);
    });

    testWidgets("the empty-state gallery fills the centre until the sequence has a linked set", (
      tester,
    ) async {
      await mountOnFloorPlans(tester);
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      expect(find.byType(OcptFloorPlanSetGallery), findsOneWidget);
      expect(find.text(tr.shotListFloorPlanGalleryTitle), findsOneWidget);
      expect(find.byType(OcptFloorPlanCanvas), findsNothing);

      // The header's own ＋ Set button is still reachable (this test's own way of linking a
      // set), even while the gallery fills the centre.
      expect(
        find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel),
        findsOneWidget,
      );
    });

    testWidgets("linking the gallery's own Create a set… flow selects the new set's tab, "
        "replacing the gallery", (tester) async {
      final bloc = await mountOnFloorPlans(tester);
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListFloorPlanGalleryCreateSetAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.shotListFloorPlanNewLocationMenuAction));
      await tester.pumpAndSettle();

      expect(bloc.state.selectedSetId, isNotNull);
      expect(find.byType(OcptFloorPlanSetGallery), findsNothing);
      expect(find.byType(OcptFloorPlanCanvas), findsOneWidget);
    });

    testWidgets("＋ Set's own Create set entry names a set from the scene heading's place and "
        "selects it", (tester) async {
      final bloc = await mountOnFloorPlans(tester);
      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.shotListFloorPlanCreateSetMenuAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.shotListFloorPlanNewLocationMenuAction));
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
      // Set-scoped: the scope invariant this whole feature stands on.
      expect(symbols.single.shotId, isNull);
      expect(symbols.single.sceneId, isNull);
      expect(canvasBlocOf(tester).state.selectedFloorPlanSymbolId, symbols.single.id);
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
      "unlinking a set whose sequence has placements on it counts them in the confirm dialog",
      (tester) async {
        final bloc = await mountWithACase(tester);
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));
        final setId = bloc.state.selectedSetId!;

        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await tester.pumpAndSettle();
        bloc.add(const OcptShotListRightDockClosedEvent());
        await tester.pumpAndSettle();

        // One camera (shot-scope) and one character (shot-scope) on the selected shot.
        await tester.tap(find.byTooltip(tr.shotListFloorPlanToolCameraAction));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(OcptFloorPlanCanvas));
        await tester.pumpAndSettle();
        // The character tool opens a name popover at once; dismiss it without typing a name.
        await tester.tap(find.byTooltip(tr.shotListFloorPlanToolCharacterAction));
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getCenter(find.byType(OcptFloorPlanCanvas)) + const Offset(40, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(tr.shotListFloorPlanCharacterNamePickerCancelAction));
        await tester.pumpAndSettle();

        expect(bloc.state.selectedSet!.symbols, hasLength(2));

        // The set tab's own close control, not the selected character's delete handle.
        await tester.tap(
          find.descendant(
            of: find.byType(OcptFloorPlanSetTabs),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OcptConfirmDialog), findsOneWidget);
        expect(find.text(tr.shotListFloorPlanDeleteSetConfirmTitle), findsOneWidget);
        final unlinkParts =
            "${tr.shotListFloorPlanUnlinkCountCamerasPart(1)} "
            "${tr.shotListFloorPlanUnlinkCountConjunction} "
            "${tr.shotListFloorPlanUnlinkCountCharactersPart(1)}";
        final expectedMessage =
            "${tr.shotListFloorPlanDeleteSetConfirmMessage} "
            "${tr.shotListFloorPlanUnlinkCountMessage(2, unlinkParts)}";
        expect(find.text(expectedMessage), findsOneWidget);

        await tester.tap(find.text(tr.shotListFloorPlanUnlinkSetConfirmAction));
        await tester.pumpAndSettle();

        expect(bloc.state.setsOfSelectedSequence, isEmpty);
        // The plan itself is kept: relinking brings every placement back.
        tester
            .element(find.byType(OcptShotListStatusBar))
            .read<OcptShotListFloorPlanSetsBloc>()
            .add(OcptShotListSetLinkRequestedEvent(setId: setId));
        await tester.pumpAndSettle();
        expect(bloc.state.selectedSet!.symbols, hasLength(2));
      },
    );

    testWidgets(
      "the add-prop button's own dialog hints at a prop name, then places it at the view's own "
      "centre, selected, instead of arming a tool",
      (tester) async {
        final bloc = await mountWithACase(tester);
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

        await tester.tap(find.text(tr.shotListFloorPlanAddPropAction));
        await tester.pumpAndSettle();

        expect(find.text(tr.shotListFloorPlanOtherPropNamePickerTitle), findsOneWidget);
        // Its own hint, never the character picker's default one this widget is reused from.
        expect(find.text(tr.shotListFloorPlanOtherPropNamePickerFieldHint), findsOneWidget);
        expect(find.text(tr.shotListFloorPlanCharacterNamePickerFieldHint), findsNothing);

        await tester.enterText(
          find.descendant(
            of: find.byType(OcptFloorPlanCharacterNamePickerDialog),
            matching: find.byType(TextField),
          ),
          "Rope",
        );
        await tester.tap(
          find.descendant(
            of: find.byType(OcptFloorPlanCharacterNamePickerDialog),
            matching: find.text(tr.shotListFloorPlanCharacterNamePickerSetAction),
          ),
        );
        await tester.pumpAndSettle();

        // Placed at once — never armed the `prop` tool the way a chip click normally does.
        expect(canvasBlocOf(tester).state.floorPlanActiveTool, isNot(OcptFloorPlanTool.prop));

        final symbols = bloc.state.selectedSet!.symbols;
        expect(symbols, hasLength(1));
        final placed = symbols.single;
        expect(placed.layer, OcptFloorPlanLayer.props);
        expect(placed.label, "Rope");
        expect(placed.sceneId, bloc.state.selectedSequenceId);
        expect(placed.shotId, isNull);
        // The view's own default zoom/pan puts the visible centre at metres (0, 0).
        expect(placed.xM, closeTo(0, 1e-6));
        expect(placed.yM, closeTo(0, 1e-6));

        expect(canvasBlocOf(tester).state.selectedFloorPlanSymbolId, placed.id);
      },
    );

    testWidgets(
      "deleting a set-scope element used by two or more sequences asks the extended dialog; its "
      "own alternative action masks it for the focused sequence alone",
      (tester) async {
        // A second scene, so the set can be linked to two sequences.
        final project = projectsManager.currentProject!;
        await projectsManager.screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: "INT. KITCHEN - DAY\n\nAction.\n\nEXT. GARDEN - NIGHT\n\nMore action.\n",
          snapshotReason: OcptSnapshotReason.manual,
        );

        final bloc = await mountWithACase(tester);
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));
        final setId = bloc.state.selectedSetId!;
        final firstSequenceId = bloc.state.selectedSequenceId!;
        final secondSequenceId = bloc.state.sequences[1].id;

        // Link the same set to the second sequence too.
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
        await tester.pumpAndSettle();
        tester
            .element(find.byType(OcptShotListStatusBar))
            .read<OcptShotListFloorPlanSetsBloc>()
            .add(OcptShotListSetLinkRequestedEvent(setId: setId));
        await tester.pumpAndSettle();
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await tester.pumpAndSettle();

        // Place a set element on the (now multi-sequence) set.
        await tester.tap(find.byTooltip(tr.shotListFloorPlanToolSetElementAction));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(OcptFloorPlanCanvas));
        await tester.pumpAndSettle();
        expect(bloc.state.selectedSet!.symbols, hasLength(1));
        final originalId = canvasBlocOf(tester).state.selectedFloorPlanSymbolId!;

        await tester.tap(find.byTooltip(tr.shotListFloorPlanDeleteSymbolAction));
        await tester.pumpAndSettle();

        // Still just the one confirmation widget, now with its own third action.
        expect(find.byType(OcptConfirmDialog), findsOneWidget);
        expect(find.text(tr.shotListDeleteConfirmCancelAction), findsOneWidget);
        expect(find.text(tr.shotListFloorPlanDeleteEverywhereAction), findsOneWidget);
        expect(bloc.state.selectedSet!.symbols, hasLength(1)); // nothing written yet

        final firstSequenceCode =
            (bloc.state.sequences[0] as OcptSceneShotSequence).displaySceneNumber;
        await tester.tap(
          find.text(tr.shotListFloorPlanRemoveFromSequenceAction(firstSequenceCode)),
        );
        await tester.pumpAndSettle();

        final symbols = bloc.state.selectedSet!.symbols;
        expect(symbols, hasLength(2));
        final override = symbols.firstWhere((symbol) => symbol.id != originalId);
        expect(override.overridesSymbolId, originalId);
        expect(override.sceneId, firstSequenceId);
        expect(override.isHidden, isTrue);
      },
    );

    testWidgets(
      "deleting a scene-scope element of a sequence with two or more shots asks the shot-level "
      "extended dialog; its own destructive action tombstones it and every shot override, "
      "never reaching a set-scope original",
      (tester) async {
        final bloc = await mountWithACase(tester);
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));
        final setId = bloc.state.selectedSetId!;
        final sceneId = bloc.state.selectedSequenceId!;

        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await tester.pumpAndSettle();
        final firstShotId = bloc.state.selectedShotId!;
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await tester.pumpAndSettle();

        // A plain scene-scope furniture item — never a sequence-level override of anything.
        canvasBlocOf(tester).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: sceneId,
            xM: 0,
            yM: 0,
          ),
        );
        await tester.pumpAndSettle();
        final sceneSymbolId = canvasBlocOf(tester).state.selectedFloorPlanSymbolId!;

        bloc.add(OcptShotListShotSelectedEvent(shotId: firstShotId));
        await tester.pumpAndSettle();
        canvasBlocOf(tester).add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: sceneSymbolId));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(tr.shotListFloorPlanDeleteSymbolAction));
        await tester.pumpAndSettle();

        expect(find.byType(OcptConfirmDialog), findsOneWidget);
        expect(find.text(tr.shotListFloorPlanDeleteFromSequenceAction), findsOneWidget);
        final firstShotCode = bloc.state.sequences
            .whereType<OcptSceneShotSequence>()
            .single
            .shots
            .firstWhere((shot) => shot.id == firstShotId)
            .code;
        expect(find.text(tr.shotListFloorPlanRemoveFromShotAction(firstShotCode)), findsOneWidget);
        // Never the sequence-level wording: this element has no set-scope original at all.
        expect(find.text(tr.shotListFloorPlanDeleteEverywhereAction), findsNothing);

        await tester.tap(find.text(tr.shotListFloorPlanDeleteFromSequenceAction));
        await tester.pumpAndSettle();

        expect(bloc.state.selectedSet!.symbols, isEmpty);
      },
    );

    testWidgets(
      "deleting a selected shot-scope override resolves to its scene-scope original first, "
      "cascading every one of its own shot overrides",
      (tester) async {
        final bloc = await mountWithACase(tester);
        final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));
        final setId = bloc.state.selectedSetId!;
        final sceneId = bloc.state.selectedSequenceId!;

        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await tester.pumpAndSettle();
        final firstShotId = bloc.state.selectedShotId!;
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await tester.pumpAndSettle();

        canvasBlocOf(tester).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: sceneId,
            xM: 0,
            yM: 0,
          ),
        );
        await tester.pumpAndSettle();
        final sceneSymbolId = canvasBlocOf(tester).state.selectedFloorPlanSymbolId!;

        bloc.add(OcptShotListShotSelectedEvent(shotId: firstShotId));
        await tester.pumpAndSettle();
        canvasBlocOf(tester).add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: sceneSymbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.shot,
            xM: 1,
            yM: 1,
          ),
        );
        await tester.pumpAndSettle();
        canvasBlocOf(tester).add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.only,
          ),
        );
        await tester.pumpAndSettle();
        expect(bloc.state.selectedSet!.symbols, hasLength(2));
        final overrideId = bloc.state.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id != sceneSymbolId)
            .id;

        canvasBlocOf(tester).add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: overrideId));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(tr.shotListFloorPlanDeleteSymbolAction));
        await tester.pumpAndSettle();
        await tester.tap(find.text(tr.shotListFloorPlanDeleteFromSequenceAction));
        await tester.pumpAndSettle();

        // Both the scene-scope original and its own shot override are gone.
        expect(bloc.state.selectedSet!.symbols, isEmpty);
      },
    );

    testWidgets("a previewed version withholds ＋ Set, the set element tool and symbol placement", (
      tester,
    ) async {
      await mountWithACase(tester);

      final version = await projectsManager.createProjectVersion(name: "v1", note: "");
      expect(version, isNotNull);
      final previewResult = await projectsManager.previewVersion(version!.id);
      expect(previewResult.status.isSuccess, isTrue);

      // Unmounts, then remounts fresh — see the board's own previewed-version test for why.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final previewedBloc = tester
          .element(find.byType(OcptShotListStatusBar))
          .read<OcptShotListBloc>();
      expect(previewedBloc.state.isPreviewingVersion, isTrue);
      expect(previewedBloc.state.centreView, OcptShotListCentreView.floorPlans);
      expect(previewedBloc.state.selectedSetId, isNotNull);

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      // `＋ Set` no longer offers a menu at all (every entry withheld): a plain disabled button.
      final addSetButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel),
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
      // — only `isReadOnly` withholds a tool bar button now).
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
    });

    testWidgets("creating a second shot's own chip selects it, always one active", (tester) async {
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
    });

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
      "placing a character symbol opens the name popover at once, picking a name writes it",
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
        expect(canvasBlocOf(tester).state.selectedFloorPlanSymbolId, symbolId);
        expect(find.byType(OcptFloorPlanCharacterNamePickerDialog), findsOneWidget);
        expect(find.text(tr.shotListFloorPlanCharacterNamePickerTitle), findsOneWidget);

        await tester.enterText(
          find.descendant(
            of: find.byType(OcptFloorPlanCharacterNamePickerDialog),
            matching: find.byType(TextField),
          ),
          "SAM",
        );
        // Scoped to the dialog: its own confirm action shares its visible text ("Set") with the
        // set tabs' own filled add-set button, always in the tree behind it.
        await tester.tap(
          find.descendant(
            of: find.byType(OcptFloorPlanCharacterNamePickerDialog),
            matching: find.text(tr.shotListFloorPlanCharacterNamePickerSetAction),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OcptFloorPlanCharacterNamePickerDialog), findsNothing);
        expect(bloc.state.selectedSet!.symbols.single.label, "SAM");
      },
    );
  });
}
