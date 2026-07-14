// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// A screenplay service that records every [saveScreenplayText] call instead of touching the
/// database, so a test can assert a save happened (and with which text) without depending on real
/// persistence timing.
class _RecordingScreenplayService extends OcptScreenplayService {
  /// Class constructor
  const _RecordingScreenplayService({required this.savedTexts})
    : super(sceneIndexService: const OcptSceneIndexService());

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

/// Wraps [child] with a [MaterialApp] and a bounded, sized surface: `SuperEditor` needs a
/// constrained size to lay its document out.
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox.expand(child: child)),
);

/// A bare [OcptStyledScreenplayEditor] pumped with [text] and no bloc behind it: most of the
/// tests below only care about the live super_editor document a keyboard interaction produces,
/// not about autosave/dirty tracking (already covered by the bloc-wired group above).
///
/// Pass a distinct [key] whenever a single `testWidgets` body calls this more than once with the
/// same [text] (for example, pumping a fresh instance per case in a loop): otherwise
/// `_OcptStyledScreenplayEditorState.didUpdateWidget`'s own "only rebuild the document if the text
/// actually changed" guard sees an unchanged [text] across the identically-shaped widget tree and
/// keeps reusing the previous call's already-edited live document instead of starting fresh.
Future<void> _pumpStandaloneEditor(
  WidgetTester tester,
  String text, {
  Key? key,
  OcptStyledEditorController? styledController,
}) async {
  await tester.pumpWidget(
    _wrap(
      OcptStyledScreenplayEditor(
        key: key,
        text: text,
        pageFormat: OcptPageFormat.usLetter,
        onTextChanged: (_) {},
        onCaretLineChanged: (_) {},
        jumpRequest: null,
        styledController: styledController,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The node at [index] of [document], freshly re-read: every node-metadata/block-type change
/// (`ChangeParagraphBlockTypeRequest`, `OcptChangeNodeMetadataRequest`) replaces the node object
/// in place rather than mutating it, so a [ParagraphNode] reference captured before such a change
/// goes stale; call this again after every edit instead of reusing an old reference.
ParagraphNode _nodeAt(Document document, int index) => document.getNodeAt(index)! as ParagraphNode;

/// The [FountainLineType] the node at [index] of [document] is currently classified as.
FountainLineType _typeAt(Document document, int index) =>
    OcptFountainLineAttributions.typeOfAttributionValue(_nodeAt(document, index).getMetadataValue("blockType"));

/// Whether the node at [index] of [document] currently carries a manual type lock.
bool _isLockedAt(Document document, int index) =>
    _nodeAt(document, index).getMetadataValue(ocptTypeLockedMetadataKey) == true;

/// Sends the hardware key combo for [key] with Ctrl held (Cmd has no equivalent test helper here;
/// this app targets Linux/Windows first).
Future<void> _sendCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

/// Sends the hardware key combo for [key] with Shift held.
Future<void> _sendShift(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; every test below that gives the styled editor a selection is affected.
  BlinkController.indeterminateAnimationsEnabled = false;

  testWidgets(
    "renders a scene heading bold at the margin and indents a character cue further than action",
    (tester) async {
      const text = "INT. HOUSE - DAY\n\nSome action text.\n\nSARAH\nHello.";

      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            text: text,
            pageFormat: OcptPageFormat.usLetter,
            onTextChanged: (_) {},
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      // Blank source lines are folded into node metadata (not their own node), so nodes are
      // dense: 0 = heading, 1 = action, 2 = character, 3 = dialogue.
      final headingNodeId = document.getNodeAt(0)!.id;
      final actionNodeId = document.getNodeAt(1)!.id;
      final characterNodeId = document.getNodeAt(2)!.id;

      expect(SuperEditorInspector.findParagraphStyle(headingNodeId)?.fontWeight, FontWeight.bold);

      final headingOffset = SuperEditorInspector.findComponentOffset(headingNodeId, Alignment.topLeft);
      final actionOffset = SuperEditorInspector.findComponentOffset(actionNodeId, Alignment.topLeft);
      final characterOffset = SuperEditorInspector.findComponentOffset(characterNodeId, Alignment.topLeft);

      // The scene heading sits at the same left margin as action text...
      expect(headingOffset.dx, actionOffset.dx);
      // ...while the character cue is indented noticeably further in.
      expect(characterOffset.dx, greaterThan(actionOffset.dx));
    },
  );

  testWidgets(
    "sizes and positions every element type at the raw preview's indent/width, wide enough that "
    "a long character cue never wraps",
    (tester) async {
      // One line per element type. "DETECTIVE JONATHAN" (19 characters) is comfortably narrower
      // than the character box's correct width (38 columns on US Letter) but would have wrapped
      // to nearly one letter per line under the pre-fix box, whose usable text width collapsed to
      // roughly `width - indent` (about 1 column).
      const text =
          "INT. HOUSE - DAY\n\n"
          "Some action text describing the scene in some detail.\n\n"
          "DETECTIVE JONATHAN\n"
          "(quietly)\n"
          "Hello there, how are you doing today my friend?\n\n"
          "CUT TO:\n\n"
          ">THE END<";

      // The default test surface (800x600) is narrower than a full-width US Letter box at font
      // size 13 (indent + width can reach ~975 logical pixels), which would clip every full-width
      // element's rendered size before it ever reached its styled `maxWidth`: widen the surface,
      // like the app's own desktop window would be in practice.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            text: text,
            pageFormat: OcptPageFormat.usLetter,
            onTextChanged: (_) {},
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
      final metrics = layout.metrics;

      // Blank source lines are folded into node metadata (not their own node), so nodes are
      // dense in source order: heading, action, character, parenthetical, dialogue, transition,
      // centered text.
      final elementsByNodeIndex = [
        metrics.sceneHeading,
        metrics.action,
        metrics.character,
        metrics.parenthetical,
        metrics.dialogue,
        metrics.transition,
        metrics.centeredText,
      ];
      final nodeIds = [
        for (var index = 0; index < elementsByNodeIndex.length; index++) _nodeAt(document, index).id,
      ];
      final actionOffset = SuperEditorInspector.findComponentOffset(nodeIds[1], Alignment.topLeft);

      for (var index = 0; index < elementsByNodeIndex.length; index++) {
        final element = elementsByNodeIndex[index];
        final nodeId = nodeIds[index];

        // The component's rendered width is `Styles.maxWidth` minus the left padding super_editor
        // applies inside it: with the fix, that's exactly the element's own text width.
        final size = SuperEditorInspector.findComponentSize(nodeId);
        expect(size.width, closeTo(layout.widthOf(element), 1), reason: "width of node $index ($element)");

        // The component's left edge sits at the element's indent, relative to the action box's —
        // but only for element types whose box is exactly as wide as action's (`indent + width`,
        // the fixed value the `Styles.maxWidth` fix now sets): the document's internal `Column`
        // centers each block's box within the widest sibling's, so a narrower box (dialogue,
        // fixed at 3.5in regardless of page size, unlike the others which stretch to the
        // printable area's right edge) picks up extra centering offset that has nothing to do
        // with this fix, and would make a direct indent comparison against action meaningless.
        final sameBoxWidthAsAction =
            layout.indentOf(element) + layout.widthOf(element) ==
            layout.indentOf(metrics.action) + layout.widthOf(metrics.action);
        if (!sameBoxWidthAsAction) {
          continue;
        }
        final offset = SuperEditorInspector.findComponentOffset(nodeId, Alignment.topLeft);
        expect(
          offset.dx - actionOffset.dx,
          closeTo(layout.indentOf(element) - layout.indentOf(metrics.action), 1),
          reason: "indent of node $index ($element)",
        );
      }

      // The most visible symptom of the bug: the character cue box collapsed to near-zero usable
      // width, wrapping to one letter per line. `findOffsetOfLineBreak` throws when a text node
      // renders on a single line, which is what must happen now.
      expect(() => SuperEditorInspector.findOffsetOfLineBreak(nodeIds[2]), throwsException);
    },
  );

  testWidgets("moving the caret to another line reports its 0-based source line", (tester) async {
    const text = "INT. HOUSE - DAY\n\nSome action text.";
    var reportedLine = -1;

    await tester.pumpWidget(
      _wrap(
        OcptStyledScreenplayEditor(
          text: text,
          pageFormat: OcptPageFormat.usLetter,
          onTextChanged: (_) {},
          onCaretLineChanged: (line) => reportedLine = line,
          jumpRequest: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final document = SuperEditorInspector.findDocument()!;
    // Blank source lines are folded into node metadata (not their own node): node 1 is the
    // action line, at source line 2 (source lines: 0 = heading, 1 = blank, 2 = action).
    final actionNodeId = document.getNodeAt(1)!.id;

    await tester.placeCaretInParagraph(actionNodeId, 0);

    expect(reportedLine, 2);
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
      projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
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
      final bloc = OcptEditorBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: OcptRouterManager(),
        screenplayService: _RecordingScreenplayService(savedTexts: savedTexts),
        exportManager: OcptExportManager(
          fileSaverManager: const FileSaverManager(),
          fileSelectorManager: const FileSelectorManager(),
        ),
        parseDebounce: const Duration(milliseconds: 10),
        autosaveDebounce: const Duration(milliseconds: 30),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(
        _wrap(
          BlocProvider<OcptEditorBloc>.value(
            value: bloc,
            child: BlocBuilder<OcptEditorBloc, OcptEditorState>(
              builder: (context, state) => state.isLoading
                  ? const SizedBox.shrink()
                  : OcptStyledScreenplayEditor(
                      text: state.text,
                      pageFormat: state.pageFormat,
                      onTextChanged: (text) =>
                          context.read<OcptEditorBloc>().add(OcptEditorTextChangedEvent(text: text)),
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

      expect(bloc.state.text, "EXT. STREET - DAY");
      expect(bloc.state.isDirty, isFalse);
      expect(savedTexts, isNotEmpty);
      expect(savedTexts.last, "EXT. STREET - DAY");
    });
  });

  group("Tab cycles the caret's block type", () {
    testWidgets(
      "Tab advances through the six common types (wrapping) and locks the block; Shift+Tab "
      "reverses",
      (tester) async {
        await _pumpStandaloneEditor(tester, "Some action text.");

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = _nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        expect(_typeAt(document, 0), FountainLineType.action);

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
          expect(_typeAt(document, 0), expectedType);
          expect(_isLockedAt(document, 0), isTrue);
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
          await _sendShift(tester, LogicalKeyboardKey.tab);
          await tester.pump();
          expect(_typeAt(document, 0), expectedType);
        }
      },
    );

    testWidgets("Tab from outside the cycle enters at sceneHeading", (tester) async {
      await _pumpStandaloneEditor(tester, "~A lyric line");

      final document = SuperEditorInspector.findDocument()!;
      expect(_typeAt(document, 0), FountainLineType.lyrics);

      await tester.placeCaretInParagraph(_nodeAt(document, 0).id, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(_typeAt(document, 0), FountainLineType.sceneHeading);
    });

    testWidgets("Shift+Tab from outside the cycle enters at transition", (tester) async {
      await _pumpStandaloneEditor(tester, "~A lyric line");

      final document = SuperEditorInspector.findDocument()!;
      expect(_typeAt(document, 0), FountainLineType.lyrics);

      await tester.placeCaretInParagraph(_nodeAt(document, 0).id, 0);
      await _sendShift(tester, LogicalKeyboardKey.tab);
      await tester.pump();

      expect(_typeAt(document, 0), FountainLineType.transition);
    });
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
        await _pumpStandaloneEditor(tester, contextText, key: ValueKey(testCase.nodeIndex));

        final document = SuperEditorInspector.findDocument()!;
        final node = _nodeAt(document, testCase.nodeIndex);
        await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        final newNode = _nodeAt(document, testCase.nodeIndex + 1);
        expect(
          OcptFountainLineAttributions.typeOfAttributionValue(newNode.getMetadataValue("blockType")),
          testCase.nextType,
          reason: "new node after node ${testCase.nodeIndex}",
        );
        expect(newNode.getMetadataValue(ocptBlankLinesBeforeMetadataKey), testCase.blankLinesBefore);
        expect(newNode.getMetadataValue(ocptTypeLockedMetadataKey), isFalse);
        expect(newNode.text.toPlainText(), isEmpty);
      }
    });

    testWidgets("splits mid-text, carrying the remainder into the new node", (tester) async {
      await _pumpStandaloneEditor(tester, "Some action text here.");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(_nodeAt(document, 0).text.toPlainText(), "Some ");
      expect(_nodeAt(document, 1).text.toPlainText(), "action text here.");
      expect(_typeAt(document, 1), FountainLineType.action);
    });

    testWidgets("Shift+Enter splits into a node of the same type with no blank line before it", (
      tester,
    ) async {
      await _pumpStandaloneEditor(tester, "First action line.");

      final document = SuperEditorInspector.findDocument()!;
      final node = _nodeAt(document, 0);
      await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final newNode = _nodeAt(document, 1);
      expect(_typeAt(document, 1), FountainLineType.action);
      expect(newNode.getMetadataValue(ocptBlankLinesBeforeMetadataKey), 0);
      expect(newNode.getMetadataValue(ocptTypeLockedMetadataKey), isFalse);
    });
  });

  testWidgets(
    "reclassify skips a locked block; emptying it clears the lock, after which auto-detection "
    "reclassifies it again",
    (tester) async {
      await _pumpStandaloneEditor(tester, "Some plain text.");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;

      await tester.placeCaretInParagraph(nodeId, 0);
      // Lock the block as `transition` (a type auto-detection would never assign to this text)
      // by cycling forward from `action` four times: character, parenthetical, dialogue,
      // transition.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.pump();
      expect(_typeAt(document, 0), FountainLineType.transition);
      expect(_isLockedAt(document, 0), isTrue);

      // Typing a scene-heading-looking prefix into the locked block must not reclassify it.
      await tester.placeCaretInParagraph(nodeId, 0);
      await tester.typeImeText("INT. ");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_typeAt(document, 0), FountainLineType.transition);
      expect(_isLockedAt(document, 0), isTrue);

      // Emptying the block clears the lock...
      final textLength = _nodeAt(document, 0).text.toPlainText().length;
      await tester.placeCaretInParagraph(nodeId, textLength);
      for (var i = 0; i < textLength; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      }
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_isLockedAt(document, 0), isFalse);

      // ...and auto-detection reclassifies the (now unlocked, empty) block once it's typed again.
      await tester.typeImeText("INT. HOUSE - DAY");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_typeAt(document, 0), FountainLineType.sceneHeading);
    },
  );

  testWidgets("Ctrl+B, Ctrl+I and Ctrl+U toggle bold/italic/underline, serialized as **/*/_", (
    tester,
  ) async {
    Future<String> encodedAfterToggling(LogicalKeyboardKey key) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            // A distinct key per call: same rationale as `_pumpStandaloneEditor`'s doc comment
            // (identical `text` across calls would otherwise reuse the previous call's document).
            key: ValueKey(key),
            text: "Base ",
            pageFormat: OcptPageFormat.usLetter,
            onTextChanged: (value) => lastEncoded = value,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final node = _nodeAt(document, 0);
      await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);

      await _sendCtrl(tester, key);
      await tester.typeImeText("styled");
      await _sendCtrl(tester, key);
      await tester.typeImeText(" end");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      return lastEncoded;
    }

    expect(await encodedAfterToggling(LogicalKeyboardKey.keyB), "Base **styled** end");
    expect(await encodedAfterToggling(LogicalKeyboardKey.keyI), "Base *styled* end");
    expect(await encodedAfterToggling(LogicalKeyboardKey.keyU), "Base _styled_ end");
  });

  group("OcptStyledEditorController", () {
    testWidgets("becomes attached once the editor is pumped", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      expect(controller.isAttached, isFalse);

      await _pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

      expect(controller.isAttached, isTrue);
    });

    testWidgets("currentBlockType follows the caret across nodes of different types", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      const text = "INT. HOUSE - DAY\n\nSARAH\nHello.";

      await _pumpStandaloneEditor(tester, text, styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final headingNodeId = _nodeAt(document, 0).id;
      final characterNodeId = _nodeAt(document, 1).id;
      final dialogueNodeId = _nodeAt(document, 2).id;

      await tester.placeCaretInParagraph(headingNodeId, 0);
      expect(controller.currentBlockType, FountainLineType.sceneHeading);

      await tester.placeCaretInParagraph(characterNodeId, 0);
      expect(controller.currentBlockType, FountainLineType.character);

      await tester.placeCaretInParagraph(dialogueNodeId, 0);
      expect(controller.currentBlockType, FountainLineType.dialogue);
    });

    testWidgets("setBlockType changes the live document's node blockType and locks it", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await _pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);

      expect(_typeAt(document, 0), FountainLineType.action);
      expect(_isLockedAt(document, 0), isFalse);

      controller.setBlockType(FountainLineType.character);
      await tester.pump();

      expect(_typeAt(document, 0), FountainLineType.character);
      expect(_isLockedAt(document, 0), isTrue);
      expect(controller.currentBlockType, FountainLineType.character);
    });

    testWidgets("toggleInlineStyle on a collapsed caret flips activeInlineStyles", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await _pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);

      expect(controller.activeInlineStyles.contains(OcptInlineStyle.bold), isFalse);

      controller.toggleInlineStyle(OcptInlineStyle.bold);
      await tester.pump();
      expect(controller.activeInlineStyles.contains(OcptInlineStyle.bold), isTrue);

      controller.toggleInlineStyle(OcptInlineStyle.bold);
      await tester.pump();
      expect(controller.activeInlineStyles.contains(OcptInlineStyle.bold), isFalse);
    });

    testWidgets("toggleInlineStyle on an expanded selection serializes to **/*/_", (tester) async {
      Future<String> encodedAfterToggling(OcptInlineStyle style) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        var lastEncoded = "";

        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              // A distinct key per call: same rationale as `_pumpStandaloneEditor`'s doc comment.
              key: ValueKey(style),
              text: "Base styled end",
              pageFormat: OcptPageFormat.usLetter,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
              styledController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = _nodeAt(document, 0).id;
        // A double tap selects the whole word under it: "Base styled end" has "styled" starting
        // at offset 5, so tapping mid-word (offset 7) selects exactly "styled".
        await tester.doubleTapInParagraph(nodeId, 7);

        controller.toggleInlineStyle(style);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        return lastEncoded;
      }

      expect(await encodedAfterToggling(OcptInlineStyle.bold), "Base **styled** end");
      expect(await encodedAfterToggling(OcptInlineStyle.italic), "Base *styled* end");
      expect(await encodedAfterToggling(OcptInlineStyle.underline), "Base _styled_ end");
    });
  });
}
