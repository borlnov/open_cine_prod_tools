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
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

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
  bool isPageSimulationEnabled = false,
  bool areSceneNumbersVisible = false,
}) async {
  await tester.pumpWidget(
    _wrap(
      OcptStyledScreenplayEditor(
        key: key,
        text: text,
        pageSetup: const OcptPageSetup.standard(),
        isPageSimulationEnabled: isPageSimulationEnabled,
        areSceneNumbersVisible: areSceneNumbersVisible,
        onTextChanged: (_) {},
        onCaretLineChanged: (_) {},
        jumpRequest: null,
        styledController: styledController,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Finds the page-simulation background painter (`_OcptPageSheetsPainter`) by the runtime name of
/// its painter: it's private to the production file, so it can't be named from here directly.
Finder _pageSheetsPainterFinder() => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == "_OcptPageSheetsPainter",
);

/// Whether the page-simulation background painter (`_OcptPageSheetsPainter`, private to the
/// production file) is currently mounted: the most that can be asserted on it from outside its own
/// library without exposing an otherwise-unneeded public type.
bool _hasPageSheetsPainter() => _pageSheetsPainterFinder().evaluate().isNotEmpty;

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

/// The node at [index] of [document]'s `ocptSceneNumber` metadata, or null if absent.
String? _sceneNumberAt(Document document, int index) {
  final value = _nodeAt(document, index).getMetadataValue(ocptSceneNumberMetadataKey);
  return value is String ? value : null;
}

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
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
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
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
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
          pageSetup: const OcptPageSetup.standard(),
          isPageSimulationEnabled: false,
          areSceneNumbersVisible: false,
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

  group("page simulation", () {
    testWidgets("renders a background page-sheets painter when enabled", (tester) async {
      await _pumpStandaloneEditor(
        tester,
        "INT. HOUSE - DAY\n\nSome action text.",
        isPageSimulationEnabled: true,
        areSceneNumbersVisible: true,
      );

      expect(_hasPageSheetsPainter(), isTrue);
    });

    testWidgets("renders no background page-sheets painter when disabled", (tester) async {
      await _pumpStandaloneEditor(tester, "INT. HOUSE - DAY\n\nSome action text.");

      expect(_hasPageSheetsPainter(), isFalse);
    });

    testWidgets(
      "paints exactly one Scrollbar, ancestor of SuperEditor, so the thumb never sits over the "
      "page",
      (tester) async {
        await _pumpStandaloneEditor(
          tester,
          "INT. HOUSE - DAY\n\nSome action text.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: true,
        );

        expect(find.byType(Scrollbar), findsOneWidget);
        expect(
          find.descendant(of: find.byType(Scrollbar), matching: find.byType(SuperEditor)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      "paints exactly one Scrollbar, ancestor of SuperEditor, with page simulation disabled too",
      (tester) async {
        await _pumpStandaloneEditor(tester, "INT. HOUSE - DAY\n\nSome action text.");

        expect(find.byType(Scrollbar), findsOneWidget);
        expect(
          find.descendant(of: find.byType(Scrollbar), matching: find.byType(SuperEditor)),
          findsOneWidget,
        );
      },
    );

    testWidgets("the page sheets are clipped to the editor's own bounds", (tester) async {
      await _pumpStandaloneEditor(
        tester,
        List.generate(80, (index) => "Action line $index.").join("\n\n"),
        isPageSimulationEnabled: true,
        areSceneNumbersVisible: true,
      );

      // `CustomPaint` does not clip its painter: without an explicit `clipRect`, a scrolled-away
      // sheet's negative top would paint the white page straight over whatever sits above the
      // editor — in the real app, the editor toolbar (it reads as the page scrolling over it).
      // Pinning the clip is what keeps every sheet inside the editor.
      expect(
        _pageSheetsPainterFinder(),
        paints
          ..clipRect()
          ..rrect(color: Colors.white),
      );
    });

    testWidgets(
      "every element still spans its exact preview width, at its exact preview indent from the "
      "page's left edge",
      (tester) async {
        // Wide enough for a full US Letter page to lay out unclipped at font size 13.
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(
          tester,
          "INT. HOUSE - DAY\n\nSome action text.\n\nSARAH\nHello there.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: true,
        );

        final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
        final metrics = layout.metrics;
        final document = SuperEditorInspector.findDocument()!;

        // The editor's box is deliberately shifted left by the stylesheet's horizontal
        // `documentPadding` inset (see `OcptStyledScreenplayEditor.build`), so the page's own left
        // edge sits exactly one inset to the right of the box's.
        final pageLeft =
            tester.getRect(find.byType(SuperEditor)).left +
            OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;

        // Blank source lines are folded into metadata, so nodes are dense: heading, action,
        // character, dialogue.
        final elementsByNodeIndex = [metrics.sceneHeading, metrics.action, metrics.character];

        for (var index = 0; index < elementsByNodeIndex.length; index++) {
          final element = elementsByNodeIndex[index];
          final nodeId = document.getNodeAt(index)!.id;

          // The whole point of the horizontal-inset compensation: page simulation must not shrink
          // any element's wrap width, nor shift its indent, away from what the raw preview
          // typesets the very same line at — otherwise the two modes would wrap the same text at
          // different columns.
          expect(
            SuperEditorInspector.findComponentSize(nodeId).width,
            closeTo(layout.widthOf(element), 0.5),
            reason: "width of node $index",
          );
          expect(
            SuperEditorInspector.findComponentOffset(nodeId, Alignment.topLeft).dx - pageLeft,
            closeTo(layout.indentOf(element), 0.5),
            reason: "indent of node $index",
          );
        }
      },
    );

    testWidgets("toggling it on and off swaps the background painter accordingly", (tester) async {
      const text = "INT. HOUSE - DAY\n\nSome action text.";

      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            key: const ValueKey("editor"),
            text: text,
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: true,
            onTextChanged: (_) {},
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_hasPageSheetsPainter(), isTrue);

      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            key: const ValueKey("editor"),
            text: text,
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            onTextChanged: (_) {},
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_hasPageSheetsPainter(), isFalse);
    });

    testWidgets("a document long enough to span multiple pages flags a page-start node", (tester) async {
      final longText = List.generate(80, (index) => "Action line $index.").join("\n\n");

      await _pumpStandaloneEditor(tester, longText, isPageSimulationEnabled: true);

      final document = SuperEditorInspector.findDocument()!;
      // The pagination pass now stores the exact top padding (a positive double), not a boolean
      // flag, so a page-starting node lands precisely at its sheet's text origin.
      final hasPageStartNode = document.any((node) {
        final value = node.getMetadataValue("ocptStartsNewPage");
        return value is double && value > 0;
      });
      expect(hasPageStartNode, isTrue);
    });

    testWidgets(
      "a full-width element's box exactly fills the editor's own width, flush with the page's "
      "left edge, leaving the true right margin outside it (no leftover super_editor centering "
      "slack eating half of it)",
      (tester) async {
        // The default test surface (800x600) is narrower than the full page-simulation width
        // (`pageWidth` can reach ~975 logical pixels at US Letter): widen it first, like the
        // M1 test above and the app's own desktop window would be in practice.
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(tester, "Some action text.", isPageSimulationEnabled: true);

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = _nodeAt(document, 0).id;
        final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());

        final editorRect = tester.getRect(find.byType(SuperEditor));
        final componentOffset = SuperEditorInspector.findComponentOffset(nodeId, Alignment.topLeft);
        final componentSize = SuperEditorInspector.findComponentSize(nodeId);

        // The editor's box spans the page's content area (`pageWidth - marginRight`) widened by the
        // stylesheet's horizontal `documentPadding` inset on each side, and is shifted left by one
        // inset — so it's the *content area inside that padding*, not the box itself, that lands
        // flush on the page's left edge (see `OcptStyledScreenplayEditor.build`). That compensation
        // is what keeps every element at its exact preview width instead of one inset short per
        // side.
        const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
        expect(editorRect.width, closeTo(layout.pageWidth - layout.marginRight + inset * 2, 0.5));
        final pageLeftEdge = editorRect.left + inset;
        final pageRightEdge = pageLeftEdge + layout.pageWidth;

        // The action element's text starts exactly `marginLeft` from the page's left edge and ends
        // exactly `marginRight` short of its right edge — the very same numbers the raw preview
        // typesets it at. Asserted to the half-pixel: the pre-fix centering bug put ~`marginRight /
        // 2` of slack on each side, and the uncompensated `documentPadding` inset a further 8px.
        final leftGap = componentOffset.dx - pageLeftEdge;
        final rightGap = pageRightEdge - (componentOffset.dx + componentSize.width);
        expect(leftGap, closeTo(layout.marginLeft, 0.5));
        expect(rightGap, closeTo(layout.marginRight, 0.5));
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
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
        parseDebounce: const Duration(milliseconds: 10),
        autosaveDebounce: const Duration(milliseconds: 30),
        statisticsDebounce: const Duration(milliseconds: 30),
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
                      pageSetup: state.pageSetup,
                      isPageSimulationEnabled: state.isPageSimulationEnabled,
                      areSceneNumbersVisible: state.areStyledSceneNumbersVisible,
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

    testWidgets(
      "a plain Tab delivered as an IME text-insertion delta (the real desktop bug, not "
      "reproduced by sendKeyEvent) cycles the block type instead of inserting a literal tab",
      (tester) async {
        // On real desktop, `SuperEditor` runs on `TextInputSource.ime`, and an unmodified Tab is
        // committed by the platform IME as a `TextEditingDeltaInsertion` of `'\t'` before Flutter
        // ever synthesizes a hardware `KeyEvent` for it — `tester.sendKeyEvent(...)` above
        // reproduces none of that; only `tester.typeImeText('\t')` (going through the same
        // `updateEditingValueWithDeltas` path a real platform Tab uses) does. Before the M2 fix
        // (no `imeOverrides` wired), this test fails: the delta reaches super_editor's own
        // document IME client unfiltered and inserts a literal tab character instead of cycling.
        var lastEncoded = "";
        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              text: "Some action text.",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = _nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);
        expect(_typeAt(document, 0), FountainLineType.action);

        await tester.typeImeText("\t");

        // The type cycled forward and the block got locked, exactly like a hardware Tab would...
        expect(_typeAt(document, 0), FountainLineType.character);
        expect(_isLockedAt(document, 0), isTrue);
        // ...and no literal tab character ever landed in the document's text (`typeImeText` itself
        // already lets enough real time elapse for the sync debounce, including the auto-uppercase
        // pass, to fire — hence the now-uppercase text rather than the original casing).
        expect(_nodeAt(document, 0).text.toPlainText(), "SOME ACTION TEXT.");

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
      },
    );

    testWidgets(
      "Shift+Tab (a hardware KeyEvent, never delivered through the IME delta channel) still "
      "reverses the cycle once imeOverrides is wired",
      (tester) async {
        await _pumpStandaloneEditor(tester, "Some action text.");

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = _nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        expect(_typeAt(document, 0), FountainLineType.action);

        await _sendShift(tester, LogicalKeyboardKey.tab);
        await tester.pump();

        expect(_typeAt(document, 0), FountainLineType.sceneHeading);
        expect(_isLockedAt(document, 0), isTrue);
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

    testWidgets(
      "splitting a scene heading before its end lets the next reclassify pass settle the "
      "carried-over remainder's type instead of forcing a mismatched one onto it",
      (tester) async {
        var lastEncoded = "";
        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              text: "INT. HOUSE - DAY",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = _nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 4);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(_nodeAt(document, 0).text.toPlainText(), "INT.");
        expect(_nodeAt(document, 1).text.toPlainText(), " HOUSE - DAY");
        // "HOUSE - DAY" alone has no scene-heading prefix, so it settles as plain action text,
        // never transiently forcing a "!" or a "." marker onto either fragment.
        expect(_typeAt(document, 1), FountainLineType.action);
        expect(_nodeAt(document, 1).getMetadataValue(ocptBlankLinesBeforeMetadataKey), 1);
        expect(lastEncoded, isNot(contains("!")));
        expect(lastEncoded, "INT. #1#\n\n HOUSE - DAY");
      },
    );

    testWidgets(
      "splitting one scene heading mid-text leaves every OTHER scene heading's number and text "
      "untouched",
      (tester) async {
        var lastEncoded = "";
        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              text: "INT. HOUSE - DAY\n\nEXT. GARDEN - NIGHT\n\nINT. ATTIC - DAY",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = _nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 4);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        // Nodes, in order after the split: "INT.", " HOUSE - DAY", "EXT. GARDEN - NIGHT",
        // "INT. ATTIC - DAY".
        expect(_nodeAt(document, 2).text.toPlainText(), "EXT. GARDEN - NIGHT");
        expect(_sceneNumberAt(document, 2), "2");
        expect(_nodeAt(document, 3).text.toPlainText(), "INT. ATTIC - DAY");
        expect(_sceneNumberAt(document, 3), "3");
        expect(lastEncoded, isNot(contains("!")));
        expect(lastEncoded, "INT. #1#\n\n HOUSE - DAY\n\nEXT. GARDEN - NIGHT #2#\n\nINT. ATTIC - DAY #3#");
      },
    );
  });

  testWidgets(
    "reclassify skips a locked block; emptying it keeps the lock and the type sticky for "
    "whatever is typed next",
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

      // Emptying the block keeps the lock (the whole point of the fix: a manual choice is always
      // made on an empty block, and must survive the debounce firing while it is still empty)...
      final textLength = _nodeAt(document, 0).text.toPlainText().length;
      await tester.placeCaretInParagraph(nodeId, textLength);
      for (var i = 0; i < textLength; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      }
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_isLockedAt(document, 0), isTrue);
      expect(_typeAt(document, 0), FountainLineType.transition);

      // ...so a scene-heading-looking prefix typed into the still-locked, now-empty block stays a
      // transition instead of being reclassified.
      await tester.typeImeText("INT. HOUSE - DAY");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_typeAt(document, 0), FountainLineType.transition);
      expect(_isLockedAt(document, 0), isTrue);
    },
  );

  group("auto-uppercase scene headings, character cues and transitions", () {
    testWidgets(
      "typing a lowercase scene heading uppercases the stored text as you type, caret offset unchanged",
      (tester) async {
        var lastEncoded = "";
        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              text: "",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = _nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        await tester.typeImeText("int. kitchen - day");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(_nodeAt(document, 0).text.toPlainText(), "INT. KITCHEN - DAY");
        expect(_typeAt(document, 0), FountainLineType.sceneHeading);
        expect(lastEncoded, "INT. KITCHEN - DAY #1#");

        final selection = SuperEditorInspector.findDocumentSelection();
        final extentOffset = (selection!.extent.nodePosition as TextNodePosition).offset;
        expect(extentOffset, "int. kitchen - day".length);
      },
    );

    testWidgets(
      "typing lowercase text into a manually-locked character cue or transition uppercases it",
      (tester) async {
        // Unlike scene headings, `FountainLineClassifier` only auto-detects a character cue or
        // transition from already-uppercase text (that asymmetry is the whole reason auto-uppercase
        // is needed for these two types): the only way such a block ever holds lowercase text in
        // practice is a manual type choice (dropdown or Tab, both of which lock the block), so that
        // is what this test drives, through `OcptStyledEditorController.setBlockType`.
        Future<String> typeIntoLockedBlock(FountainLineType type, String lowercaseText) async {
          final controller = OcptStyledEditorController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            _wrap(
              OcptStyledScreenplayEditor(
                key: ValueKey(type),
                text: "",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: false,
                areSceneNumbersVisible: false,
                onTextChanged: (_) {},
                onCaretLineChanged: (_) {},
                jumpRequest: null,
                styledController: controller,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final document = SuperEditorInspector.findDocument()!;
          final nodeId = _nodeAt(document, 0).id;
          await tester.placeCaretInParagraph(nodeId, 0);

          controller.setBlockType(type);
          await tester.pump();

          await tester.typeImeText(lowercaseText);
          await tester.pump(const Duration(milliseconds: 150));
          await tester.pump();

          expect(_typeAt(document, 0), type);
          return _nodeAt(document, 0).text.toPlainText();
        }

        expect(await typeIntoLockedBlock(FountainLineType.character, "sarah"), "SARAH");
        expect(await typeIntoLockedBlock(FountainLineType.transition, "cut to:"), "CUT TO:");
      },
    );

    testWidgets(
      "a character type set on an empty block survives the reclassify debounce firing before any "
      "text is typed",
      (tester) async {
        // Regression test: the debounce used to fire while the block was still empty and clear
        // `ocptTypeLocked` as a side effect, so the first characters typed afterwards were
        // reclassified away from character. Unlike the test above, this one explicitly pumps past
        // `_syncDebounce` (120 ms) right after `setBlockType`, before typing anything.
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await _pumpStandaloneEditor(tester, "", styledController: controller);

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = _nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        controller.setBlockType(FountainLineType.character);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(_typeAt(document, 0), FountainLineType.character);
        expect(_isLockedAt(document, 0), isTrue);

        await tester.typeImeText("john");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(_typeAt(document, 0), FountainLineType.character);
        expect(_nodeAt(document, 0).text.toPlainText(), "JOHN");
      },
    );

    testWidgets("bold/italic/underline spans survive the uppercase conversion", (tester) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            text: "",
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            onTextChanged: (value) => lastEncoded = value,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);

      await tester.typeImeText("int. ");
      await _sendCtrl(tester, LogicalKeyboardKey.keyB);
      await tester.typeImeText("kitchen");
      await _sendCtrl(tester, LogicalKeyboardKey.keyB);
      await tester.typeImeText(" - day");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(_nodeAt(document, 0).text.toPlainText(), "INT. KITCHEN - DAY");
      expect(lastEncoded, "INT. **KITCHEN** - DAY #1#");
    });
  });

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
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
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

  group("scene numbers", () {
    testWidgets(
      "typing a #N# tag that matches its sequential position is absorbed into metadata, hidden from the text",
      (tester) async {
        await _pumpStandaloneEditor(tester, "INT. HOUSE - DAY\n\nEXT. GARDEN - NIGHT");

        final document = SuperEditorInspector.findDocument()!;
        final secondHeading = _nodeAt(document, 1);
        await tester.placeCaretInParagraph(secondHeading.id, secondHeading.text.toPlainText().length);

        await tester.typeImeText(" #2#");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(_nodeAt(document, 1).text.toPlainText(), "EXT. GARDEN - NIGHT");
        expect(_sceneNumberAt(document, 1), "2");
      },
    );

    testWidgets(
      "typing a #N# tag that does not fit its position is absorbed then immediately corrected",
      (tester) async {
        await _pumpStandaloneEditor(tester, "INT. HOUSE - DAY");

        final document = SuperEditorInspector.findDocument()!;
        final node = _nodeAt(document, 0);
        await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);

        await tester.typeImeText(" #4A#");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(_nodeAt(document, 0).text.toPlainText(), "INT. HOUSE - DAY");
        expect(_sceneNumberAt(document, 0), "1");
      },
    );

    testWidgets("the scene-number gutter renders only while areSceneNumbersVisible is true", (
      tester,
    ) async {
      const text = "INT. HOUSE - DAY\n\nAction.";

      await _pumpStandaloneEditor(tester, text);
      expect(find.text("1"), findsNothing);

      await _pumpStandaloneEditor(
        tester,
        text,
        key: const Key("visible"),
        areSceneNumbersVisible: true,
      );
      expect(find.text("1"), findsOneWidget);
    });

    testWidgets("every scene heading is auto-numbered into the source, even with no #N# typed", (
      tester,
    ) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            text: "INT. HOUSE - DAY\n\nAction.\n\nEXT. GARDEN - NIGHT",
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            onTextChanged: (text) => lastEncoded = text,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lastEncoded, "INT. HOUSE - DAY #1#\n\nAction.\n\nEXT. GARDEN - NIGHT #2#");
    });

    testWidgets("badly-ordered numbers entered in raw mode are corrected once decoded into the styled view", (
      tester,
    ) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            text: "INT. HOUSE - DAY #9#\n\nEXT. GARDEN - NIGHT #2#",
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            onTextChanged: (text) => lastEncoded = text,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lastEncoded, "INT. HOUSE - DAY #1#\n\nEXT. GARDEN - NIGHT #2#");
    });
  });

  group("copy, cut and paste keep block types", () {
    // The `flutter/platform` channel's `Clipboard.setData`/`getData` methods have no built-in
    // mock handler on this SDK: without one, `Clipboard.getData` never completes at all, and
    // every paste in this group hangs forever instead of failing loudly.
    String? clipboardText;
    setUp(() {
      clipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        methodCall,
      ) async {
        switch (methodCall.method) {
          case "Clipboard.setData":
            clipboardText = (methodCall.arguments as Map)["text"] as String?;
            return null;
          case "Clipboard.getData":
            return {"text": clipboardText};
          default:
            return null;
        }
      });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets(
      "copying a character cue and its dialogue, then pasting them on a fresh blank line, "
      "reproduces both blocks with their types and spacing",
      (tester) async {
        var lastEncoded = "";
        const text = "INT. HOUSE - DAY\n\nSARAH\nHello there.\n\nSome trailing action.";

        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              text: text,
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
        // Nodes: 0 = heading, 1 = character, 2 = dialogue, 3 = trailing action.
        final characterNode = _nodeAt(document, 1);
        final dialogueNode = _nodeAt(document, 2);
        final trailingNode = _nodeAt(document, 3);

        // Placing the caret first is what actually gives the editor keyboard focus (a bare
        // `setSelectionWithReason` doesn't); the expanded selection then overrides it.
        await tester.placeCaretInParagraph(characterNode.id, 0);
        composer.setSelectionWithReason(
          DocumentSelection(
            base: DocumentPosition(nodeId: characterNode.id, nodePosition: const TextNodePosition(offset: 0)),
            extent: DocumentPosition(
              nodeId: dialogueNode.id,
              nodePosition: TextNodePosition(offset: dialogueNode.text.toPlainText().length),
            ),
          ),
        );
        await tester.pump();

        await _sendCtrl(tester, LogicalKeyboardKey.keyC);
        await tester.pumpAndSettle();

        // A fresh Enter at the very end of the document opens a new, empty blank line to paste
        // onto — the common "paste elsewhere" target.
        await tester.placeCaretInParagraph(trailingNode.id, trailingNode.text.toPlainText().length);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        await _sendCtrl(tester, LogicalKeyboardKey.keyV);
        await tester.pumpAndSettle();

        expect(document.nodeCount, 6);
        expect(_typeAt(document, 4), FountainLineType.character);
        expect(_nodeAt(document, 4).text.toPlainText(), "SARAH");
        expect(_typeAt(document, 5), FountainLineType.dialogue);
        expect(_nodeAt(document, 5).text.toPlainText(), "Hello there.");

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(
          lastEncoded,
          "INT. HOUSE - DAY #1#\n\nSARAH\nHello there.\n\nSome trailing action.\n\nSARAH\nHello there.",
        );
      },
    );

    testWidgets(
      "pasting a single-node fragment inside existing text inserts it inline without splitting the block",
      (tester) async {
        var lastEncoded = "";
        const text = "Some action text here.";

        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              text: text,
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
        final actionNode = _nodeAt(document, 0);

        // Placing the caret first is what actually gives the editor keyboard focus (a bare
        // `setSelectionWithReason` doesn't); the expanded selection then overrides it.
        await tester.placeCaretInParagraph(actionNode.id, 5);
        composer.setSelectionWithReason(
          DocumentSelection(
            base: DocumentPosition(nodeId: actionNode.id, nodePosition: const TextNodePosition(offset: 5)),
            extent: DocumentPosition(nodeId: actionNode.id, nodePosition: const TextNodePosition(offset: 11)),
          ),
        );
        await tester.pump();

        await _sendCtrl(tester, LogicalKeyboardKey.keyC);
        await tester.pumpAndSettle();

        await tester.placeCaretInParagraph(actionNode.id, 0);
        await _sendCtrl(tester, LogicalKeyboardKey.keyV);
        await tester.pumpAndSettle();

        expect(document.nodeCount, 1);
        expect(_typeAt(document, 0), FountainLineType.action);
        expect(_nodeAt(document, 0).text.toPlainText(), "actionSome action text here.");

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();
        expect(lastEncoded, "actionSome action text here.");
      },
    );

    testWidgets("cutting a selection removes it from the document and copies its Fountain text to the clipboard", (
      tester,
    ) async {
      const text = "SARAH\nHello there.\n\nSome trailing action.";

      await _pumpStandaloneEditor(tester, text);

      final document = SuperEditorInspector.findDocument()!;
      final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
      final characterNode = _nodeAt(document, 0);
      final dialogueNode = _nodeAt(document, 1);

      // Placing the caret first is what actually gives the editor keyboard focus (a bare
      // `setSelectionWithReason` doesn't); the expanded selection then overrides it.
      await tester.placeCaretInParagraph(characterNode.id, 0);
      composer.setSelectionWithReason(
        DocumentSelection(
          base: DocumentPosition(nodeId: characterNode.id, nodePosition: const TextNodePosition(offset: 0)),
          extent: DocumentPosition(
            nodeId: dialogueNode.id,
            nodePosition: TextNodePosition(offset: dialogueNode.text.toPlainText().length),
          ),
        ),
      );
      await tester.pump();

      await _sendCtrl(tester, LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();

      // super_editor's own `DeleteContentCommand` inserts a fresh empty paragraph in place of a
      // selection that fully covered every node it touched, so there's somewhere for the caret to
      // land — the deleted character cue and dialogue become one empty node, not zero.
      expect(document.nodeCount, 2);
      expect(_nodeAt(document, 0).text.toPlainText(), isEmpty);
      expect(_nodeAt(document, 1).text.toPlainText(), "Some trailing action.");

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, "SARAH\nHello there.");
    });
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

    testWidgets("currentBlockType follows a Tab cycle immediately, before the sync debounce", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await _pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);
      expect(controller.currentBlockType, FountainLineType.action);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      // A single `pump()`, deliberately short of the 120 ms sync debounce: the dropdown must
      // already reflect the new type from `_onDocumentChanged` alone, not from the debounced sync.
      await tester.pump();

      expect(controller.currentBlockType, FountainLineType.character);
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
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
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
