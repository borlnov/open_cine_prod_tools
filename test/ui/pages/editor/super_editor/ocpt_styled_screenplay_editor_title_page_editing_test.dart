// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// The fixed device id every stamping service built in this file uses.
Future<String> _testDeviceId() async => "test-device";

/// A screenplay service that records every [saveScreenplayText] call instead of touching the
/// database, so a test can assert a save happened (and with which text) without depending on real
/// persistence timing.
class _RecordingScreenplayService extends OcptScreenplayService {
  /// Class constructor
  const _RecordingScreenplayService({required this.savedTexts})
    : super(
        logger: const SilentLogger(),
        sceneIndexService: const OcptSceneIndexService(logger: SilentLogger()),
        shotListService: const OcptShotListService(
          logger: SilentLogger(),
          roleIndexService: OcptRoleIndexService(
            logger: SilentLogger(),
            elementsService: OcptElementsService(
              logger: SilentLogger(),
              assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
              deviceId: _testDeviceId,
            ),
            roleCandidatesService: OcptRoleCandidatesService(
              logger: SilentLogger(),
              deviceId: _testDeviceId,
            ),
            deviceId: _testDeviceId,
          ),
          storyboardService: OcptStoryboardService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            deviceId: _testDeviceId,
          ),
          floorPlanService: OcptFloorPlanService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            deviceId: _testDeviceId,
          ),
          deviceId: _testDeviceId,
        ),
        shotCoverageService: const OcptShotCoverageService(
          logger: SilentLogger(),
          deviceId: _testDeviceId,
        ),
        roleIndexService: const OcptRoleIndexService(
          logger: SilentLogger(),
          elementsService: OcptElementsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            deviceId: _testDeviceId,
          ),
          roleCandidatesService: OcptRoleCandidatesService(
            logger: SilentLogger(),
            deviceId: _testDeviceId,
          ),
          deviceId: _testDeviceId,
        ),
        breakdownService: const OcptBreakdownService(
          logger: SilentLogger(),
          elementsService: OcptElementsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            deviceId: _testDeviceId,
          ),
          locationsService: OcptLocationsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            floorPlanService: OcptFloorPlanService(
              logger: SilentLogger(),
              assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
              deviceId: _testDeviceId,
            ),
            deviceId: _testDeviceId,
          ),
          deviceId: _testDeviceId,
        ),
        scheduleService: const OcptScheduleService(logger: SilentLogger(), deviceId: _testDeviceId),
        deviceId: _testDeviceId,
      );

  /// Every Fountain text this service was asked to save, in call order.
  final List<String> savedTexts;

  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  @override
  Future<void> saveScreenplayText({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String fountainText,
    required OcptSnapshotReason snapshotReason,
  }) async {
    savedTexts.add(fountainText);
  }
}

void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; every test below that gives the styled editor a selection is affected.
  BlinkController.indeterminateAnimationsEnabled = false;

  group("title page", () {
    testWidgets(
      "a scene heading still shows its gutter number with a title page and scene numbers on",
      (tester) async {
        // Tall enough to reach the body's first (and only) node past the whole title sheet, same as
        // the "Backspace ... never merges it into Source" case above.
        tester.view.physicalSize = const Size(1400, 2700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpStandaloneEditor(
          tester,
          "INT. HOUSE - DAY\n\nSome action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: true,
        );

        // Proves `OcptSceneNumberGutterComponentBuilder` still claims its own nodes even though it
        // now falls through for every title-page node ahead of it in `componentBuilders`.
        expect(find.text("1"), findsOneWidget);
      },
    );

    testWidgets("a multi-line field's placeholder hints only its first line", (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A Contact value split by Enter with no typed text left before the split: both resulting
      // nodes are empty, so both would show the "Contact" hint if the placeholder were still keyed
      // by node id rather than by "is this the field's first node".
      await pumpStandaloneEditor(tester, "Some action.", isPageSimulationEnabled: true);

      // Contact: index 4.
      final contactNodeId = SuperEditorInspector.findDocument()!.getNodeAt(4)!.id;
      await placeCaretAtStartOf(tester, contactNodeId);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      final document = SuperEditorInspector.findDocument()!;
      // Six title-page fields, one split into two lines, plus the body's one node.
      expect(document.nodeCount, testTitlePageFieldCount + 2);
      expect(
        (document.getNodeAt(4)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey),
        "Contact",
      );
      expect(
        (document.getNodeAt(5)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey),
        "Contact",
      );

      expect(find.text("Contact"), findsOneWidget);
    });

    testWidgets(
      "Backspace via the IME delta channel at the start of a field does not merge it into its "
      "neighbour",
      (tester) async {
        // The IME delta channel is a genuinely different code path from `sendKeyEvent`: at offset 0
        // of a node, `document_delta_editing.dart`'s `delete()` sends a
        // `DeleteUpstreamAtBeginningOfNodeRequest`, never a `CombineParagraphsRequest` — so this
        // exercises `ocptTitlePageGuardRequestHandler`'s dedicated rule for that request, not the
        // one the hardware-Backspace tests above already cover.
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpStandaloneEditor(tester, "Some action.", isPageSimulationEnabled: true);

        // Credit: index 1.
        final creditNodeId = SuperEditorInspector.findDocument()!.getNodeAt(1)!.id;
        await placeCaretAtStartOf(tester, creditNodeId);
        await tester.typeImeText("written by");
        await tester.pump(const Duration(milliseconds: 200));
        await placeCaretAtStartOf(tester, creditNodeId);

        await tester.ime.backspace(getter: imeClientGetter);
        await tester.pump(const Duration(milliseconds: 200));

        final document = SuperEditorInspector.findDocument()!;
        expect(document.nodeCount, testTitlePageFieldCount + 1);
        expect(document.getNodeById(creditNodeId), isNotNull);
        expect(
          (document.getNodeById(creditNodeId)! as ParagraphNode).text.toPlainText(),
          "written by",
        );
      },
    );
  });

  group("typing in the styled editor, wired to a real (fast) OcptEditorBloc", () {
    late OcptPropertiesManager propertiesManager;
    late OcptProjectsManager projectsManager;
    late Directory tempDir;
    late List<String> savedTexts;

    setUpAll(() async {
      OcptGlobalManager.instance;
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      propertiesManager = OcptPropertiesManager();
      await propertiesManager.initLifeCycle();
    });

    setUp(() async {
      savedTexts = [];
      tempDir = await Directory.systemTemp.createTemp("ocpt_styled_editor_test_");
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

    testWidgets("marks the screenplay dirty and autosaves the typed text", (tester) async {
      // This test is about typing/dirty/autosave, not about the title sheet: pin page simulation
      // off explicitly (rather than relying on whatever the app's own current default happens to
      // be) so the body's only node stays the document's first and only one, on screen from the
      // very first frame.
      await propertiesManager.isPageSimulationEnabled.store(false);

      final bloc = OcptEditorBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: OcptRouterManager(),
        screenplayService: _RecordingScreenplayService(savedTexts: savedTexts),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
        parseDebounce: const Duration(milliseconds: 10),
        autosaveDebounce: const Duration(milliseconds: 30),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(
        testWrap(
          BlocProvider<OcptEditorBloc>.value(
            value: bloc,
            child: BlocBuilder<OcptEditorBloc, OcptEditorState>(
              builder: (context, state) => state.isLoading
                  ? const SizedBox.shrink()
                  : OcptStyledScreenplayEditor(
                      text: state.text,
                      pageSetup: state.pageSetup,
                      isPageSimulationEnabled: state.isPageSimulationEnabled,
                      areSceneNumbersVisible: state.areStyledSceneNumbersVisible,
                      isSpellCheckVisible: state.isSpellCheckVisible,
                      onTextChanged: (text) => context.read<OcptEditorBloc>().add(
                        OcptEditorTextChangedEvent(text: text),
                      ),
                      onCaretLineChanged: (line) =>
                          context.read<OcptEditorBloc>().add(OcptEditorCaretMovedEvent(line: line)),
                      jumpRequest: state.jumpRequest,
                    ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final firstNodeId = document.getNodeAt(0)!.id;

      await tester.placeCaretInParagraph(firstNodeId, 0);
      // `typeImeText` settles fully after every character it sends (see `ImeSimulator`), which
      // drains both this widget's own sync debounce and the bloc's autosave debounce for each
      // character in turn; by the time it returns, typing has already flowed all the way through
      // to a fully-saved screenplay, one incremental save per character.
      await tester.typeImeText("EXT. STREET - DAY");

      expect(bloc.state.text, "EXT. STREET - DAY #1#");
      expect(bloc.state.isDirty, isFalse);
      expect(savedTexts, isNotEmpty);
      expect(savedTexts.last, "EXT. STREET - DAY #1#");
    });
  });

  group("Tab cycles the caret's block type", () {
    testWidgets(
      "Tab advances through the six common types (wrapping) and locks the block; Shift+Tab "
      "reverses",
      (tester) async {
        await pumpStandaloneEditor(tester, "Some action text.");

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        expect(typeAt(document, 0), FountainLineType.action);

        const forwardCycle = [
          FountainLineType.character,
          FountainLineType.parenthetical,
          FountainLineType.dialogue,
          FountainLineType.transition,
          FountainLineType.sceneHeading,
          FountainLineType.action,
        ];
        for (final expectedType in forwardCycle) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(typeAt(document, 0), expectedType);
          expect(isLockedAt(document, 0), isTrue);
        }

        // The forward loop above ends back at `action`; reversing from there steps backward
        // through the cycle the other way round (wrapping at `sceneHeading` to `transition`).
        const reverseCycle = [
          FountainLineType.sceneHeading,
          FountainLineType.transition,
          FountainLineType.dialogue,
          FountainLineType.parenthetical,
          FountainLineType.character,
          FountainLineType.action,
        ];
        for (final expectedType in reverseCycle) {
          await sendShift(tester, LogicalKeyboardKey.tab);
          await tester.pump();
          expect(typeAt(document, 0), expectedType);
        }
      },
    );

    testWidgets("Tab from outside the cycle enters at sceneHeading", (tester) async {
      await pumpStandaloneEditor(tester, "~A lyric line");

      final document = SuperEditorInspector.findDocument()!;
      expect(typeAt(document, 0), FountainLineType.lyrics);

      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(typeAt(document, 0), FountainLineType.sceneHeading);
    });

    testWidgets("Shift+Tab from outside the cycle enters at transition", (tester) async {
      await pumpStandaloneEditor(tester, "~A lyric line");

      final document = SuperEditorInspector.findDocument()!;
      expect(typeAt(document, 0), FountainLineType.lyrics);

      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
      await sendShift(tester, LogicalKeyboardKey.tab);
      await tester.pump();

      expect(typeAt(document, 0), FountainLineType.transition);
    });

    testWidgets("a plain Tab delivered as an IME text-insertion delta (the real desktop bug, not "
        "reproduced by sendKeyEvent) cycles the block type instead of inserting a literal tab", (
      tester,
    ) async {
      // On real desktop, `SuperEditor` runs on `TextInputSource.ime`, and an unmodified Tab is
      // committed by the platform IME as a `TextEditingDeltaInsertion` of `'\t'` before Flutter
      // ever synthesizes a hardware `KeyEvent` for it — `tester.sendKeyEvent(...)` above
      // reproduces none of that; only `tester.typeImeText('\t')` (going through the same
      // `updateEditingValueWithDeltas` path a real platform Tab uses) does. Without the fix
      // (no `imeOverrides` wired), this test fails: the delta reaches super_editor's own
      // document IME client unfiltered and inserts a literal tab character instead of cycling.
      var lastEncoded = "";
      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            text: "Some action text.",
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: (value) => lastEncoded = value,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);
      expect(typeAt(document, 0), FountainLineType.action);

      await tester.typeImeText("\t");

      // The type cycled forward and the block got locked, exactly like a hardware Tab would...
      expect(typeAt(document, 0), FountainLineType.character);
      expect(isLockedAt(document, 0), isTrue);
      // ...and no literal tab character ever landed in the document's text (`typeImeText` itself
      // already lets enough real time elapse for the sync debounce, including the auto-uppercase
      // pass, to fire — hence the now-uppercase text rather than the original casing).
      expect(nodeAt(document, 0).text.toPlainText(), "SOME ACTION TEXT.");

      // Let any remaining sync debounce encode the document back to text, and confirm the
      // reported source text never contains a tab character either — the leading "@" is the
      // Fountain forcing marker `FountainLineWriter` correctly prepends to a manually-forced
      // character cue whose text isn't followed by a dialogue line (unrelated to this bug; it's
      // the same marker a Tab-cycled character block already produced before this fix, on the
      // hardware-KeyEvent path).
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(lastEncoded, "@SOME ACTION TEXT.");
      expect(lastEncoded.contains("\t"), isFalse);
    });

    testWidgets(
      "Shift+Tab (a hardware KeyEvent, never delivered through the IME delta channel) still "
      "reverses the cycle once imeOverrides is wired",
      (tester) async {
        await pumpStandaloneEditor(tester, "Some action text.");

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        expect(typeAt(document, 0), FountainLineType.action);

        await sendShift(tester, LogicalKeyboardKey.tab);
        await tester.pump();

        expect(typeAt(document, 0), FountainLineType.sceneHeading);
        expect(isLockedAt(document, 0), isTrue);
      },
    );
  });

  group("smart Enter", () {
    testWidgets("maps each type to its usual screenplay successor", (tester) async {
      // Nodes, in order: sceneHeading, character, parenthetical, dialogue, transition (blank
      // source lines are folded into metadata, so these are exactly nodes 0-4).
      const contextText = "INT. HOUSE - DAY\n\nSARAH\n(quietly)\nHello.\n\nCUT TO:";
      const cases = [
        (nodeIndex: 0, nextType: FountainLineType.action, blankLinesBefore: 1),
        (nodeIndex: 1, nextType: FountainLineType.dialogue, blankLinesBefore: 0),
        (nodeIndex: 2, nextType: FountainLineType.dialogue, blankLinesBefore: 0),
        (nodeIndex: 3, nextType: FountainLineType.action, blankLinesBefore: 1),
        (nodeIndex: 4, nextType: FountainLineType.sceneHeading, blankLinesBefore: 1),
      ];

      for (final testCase in cases) {
        await pumpStandaloneEditor(tester, contextText, key: ValueKey(testCase.nodeIndex));

        final document = SuperEditorInspector.findDocument()!;
        final node = nodeAt(document, testCase.nodeIndex);
        await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        final newNode = nodeAt(document, testCase.nodeIndex + 1);
        expect(
          OcptFountainLineAttributions.typeOfAttributionValue(
            newNode.getMetadataValue("blockType"),
          ),
          testCase.nextType,
          reason: "new node after node ${testCase.nodeIndex}",
        );
        expect(
          newNode.getMetadataValue(ocptBlankLinesBeforeMetadataKey),
          testCase.blankLinesBefore,
        );
        expect(newNode.getMetadataValue(ocptTypeLockedMetadataKey), isFalse);
        expect(newNode.text.toPlainText(), isEmpty);
      }
    });

    testWidgets("splits mid-text, carrying the remainder into the new node", (tester) async {
      await pumpStandaloneEditor(tester, "Some action text here.");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(nodeAt(document, 0).text.toPlainText(), "Some ");
      expect(nodeAt(document, 1).text.toPlainText(), "action text here.");
      expect(typeAt(document, 1), FountainLineType.action);
    });

    testWidgets("Shift+Enter splits into a node of the same type with no blank line before it", (
      tester,
    ) async {
      await pumpStandaloneEditor(tester, "First action line.");

      final document = SuperEditorInspector.findDocument()!;
      final node = nodeAt(document, 0);
      await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final newNode = nodeAt(document, 1);
      expect(typeAt(document, 1), FountainLineType.action);
      expect(newNode.getMetadataValue(ocptBlankLinesBeforeMetadataKey), 0);
      expect(newNode.getMetadataValue(ocptTypeLockedMetadataKey), isFalse);
    });

    testWidgets("splitting a scene heading before its end lets the next reclassify pass settle the "
        "carried-over remainder's type instead of forcing a mismatched one onto it", (
      tester,
    ) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            text: "INT. HOUSE - DAY",
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: (value) => lastEncoded = value,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(nodeAt(document, 0).text.toPlainText(), "INT.");
      expect(nodeAt(document, 1).text.toPlainText(), " HOUSE - DAY");
      // "HOUSE - DAY" alone has no scene-heading prefix, so it settles as plain action text,
      // never transiently forcing a "!" or a "." marker onto either fragment.
      expect(typeAt(document, 1), FountainLineType.action);
      expect(nodeAt(document, 1).getMetadataValue(ocptBlankLinesBeforeMetadataKey), 1);
      expect(lastEncoded, isNot(contains("!")));
      expect(lastEncoded, "INT. #1#\n\n HOUSE - DAY");
    });

    testWidgets(
      "splitting one scene heading mid-text leaves every OTHER scene heading's number and text "
      "untouched",
      (tester) async {
        var lastEncoded = "";
        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: "INT. HOUSE - DAY\n\nEXT. GARDEN - NIGHT\n\nINT. ATTIC - DAY",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              isSpellCheckVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 4);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        // Nodes, in order after the split: "INT.", " HOUSE - DAY", "EXT. GARDEN - NIGHT",
        // "INT. ATTIC - DAY".
        expect(nodeAt(document, 2).text.toPlainText(), "EXT. GARDEN - NIGHT");
        expect(sceneNumberAt(document, 2), "2");
        expect(nodeAt(document, 3).text.toPlainText(), "INT. ATTIC - DAY");
        expect(sceneNumberAt(document, 3), "3");
        expect(lastEncoded, isNot(contains("!")));
        expect(
          lastEncoded,
          "INT. #1#\n\n HOUSE - DAY\n\nEXT. GARDEN - NIGHT #2#\n\nINT. ATTIC - DAY #3#",
        );
      },
    );
  });

  group("flushing a pending sync on deactivate", () {
    testWidgets(
      "a scene heading split mid-text, then removed from the tree before its debounce clears, "
      "reports the same settled text a normal debounce would have",
      (tester) async {
        var lastEncoded = "";
        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: "INT. HOUSE - DAY",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              isSpellCheckVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 4);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        // A bounded pump shorter than the styled editor's 120 ms sync debounce: long enough to
        // process the split, short enough that `_syncTimer` is still pending when this widget is
        // removed from the tree below — the exact race `_flushPendingSync` has to handle.
        await tester.pump(const Duration(milliseconds: 20));

        // Replacing the whole widget tree removes `OcptStyledScreenplayEditor`, running
        // `deactivate()` (and, with it, `_flushPendingSync`) without ever letting `_syncTimer`
        // fire on its own.
        await tester.pumpWidget(testWrap(const SizedBox()));
        await tester.pump();

        // Before this fix, flushing skipped reclassification entirely and encoded the split
        // fragment under its stale `sceneHeading` type, forcing a "." marker onto text that no
        // longer read as a heading (and, once decoded again, sticking as a permanent forcing
        // marker misclassified as user intent).
        expect(lastEncoded, isNot(contains("!")));
        expect(lastEncoded, "INT. #1#\n\n HOUSE - DAY");
      },
    );
  });

  testWidgets("reclassify skips a locked block; emptying it keeps the lock and the type sticky for "
      "whatever is typed next", (tester) async {
    await pumpStandaloneEditor(tester, "Some plain text.");

    final document = SuperEditorInspector.findDocument()!;
    final nodeId = nodeAt(document, 0).id;

    await tester.placeCaretInParagraph(nodeId, 0);
    // Lock the block as `transition` (a type auto-detection would never assign to this text)
    // by cycling forward from `action` four times: character, parenthetical, dialogue,
    // transition.
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pump();
    expect(typeAt(document, 0), FountainLineType.transition);
    expect(isLockedAt(document, 0), isTrue);

    // Typing a scene-heading-looking prefix into the locked block must not reclassify it.
    await tester.placeCaretInParagraph(nodeId, 0);
    await tester.typeImeText("INT. ");
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(typeAt(document, 0), FountainLineType.transition);
    expect(isLockedAt(document, 0), isTrue);

    // Emptying the block keeps the lock (the whole point of the fix: a manual choice is always
    // made on an empty block, and must survive the debounce firing while it is still empty)...
    final textLength = nodeAt(document, 0).text.toPlainText().length;
    await tester.placeCaretInParagraph(nodeId, textLength);
    for (var i = 0; i < textLength; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    }
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(isLockedAt(document, 0), isTrue);
    expect(typeAt(document, 0), FountainLineType.transition);

    // ...so a scene-heading-looking prefix typed into the still-locked, now-empty block stays a
    // transition instead of being reclassified.
    await tester.typeImeText("INT. HOUSE - DAY");
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(typeAt(document, 0), FountainLineType.transition);
    expect(isLockedAt(document, 0), isTrue);
  });
}
