// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_fountain_line_type_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_script_page_number.dart';
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
    : super(
        sceneIndexService: const OcptSceneIndexService(),
        shotListService: const OcptShotListService(),
        shotCoverageService: const OcptShotCoverageService(),
        roleIndexService: const OcptRoleIndexService(),
        breakdownService: const OcptBreakdownService(
          elementsService: OcptElementsService(),
          locationsService: OcptLocationsService(),
        ),
        scheduleService: const OcptScheduleService(),
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

/// Wraps [child] with a [MaterialApp] and a bounded, sized surface: `SuperEditor` needs a
/// constrained size to lay its document out. The localization delegates are needed for the
/// title-page placeholder builder's field labels, which only ever resolve while page simulation
/// is on (see the "page simulation" group below).
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
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

/// The number of leading title-page field nodes a page-simulation-on document starts with when
/// its source text has no title page of its own: all six [ocptTitlePageFieldKeys] then synthesize
/// as one empty node each (see `OcptWysiwygCodec.decodeWithTitlePage`), ahead of every body node
/// the "page simulation" test group below otherwise indexes by position.
const int _titlePageFieldCount = 6;

/// Places the caret at the start of the node with [nodeId] and asserts it actually landed there,
/// so a silently-failed tap (for example a field sitting outside the test surface's viewport, see
/// the title-page tests' own `tester.view.physicalSize` overrides) can never be mistaken for the
/// Backspace guard doing its job — every caller below would otherwise still pass even if the
/// caret, and with it the whole gesture, never actually reached the target field.
Future<void> _placeCaretAtStartOf(WidgetTester tester, String nodeId) async {
  await tester.placeCaretInParagraph(nodeId, 0);
  final selection = SuperEditorInspector.findDocumentSelection();
  expect(selection, isNotNull, reason: "caret placement in node $nodeId failed");
  expect(selection!.extent.nodeId, nodeId);
  expect((selection.extent.nodePosition as TextNodePosition).offset, 0);
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

/// Sends the hardware key combo for [key] with both Ctrl and Shift held (Ctrl+Shift+Z's redo, which
/// neither [_sendCtrl] nor [_sendShift] alone can produce).
Future<void> _sendCtrlShift(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

/// A global offset landing inside the actual glyphs of the node with [nodeId], for a secondary tap
/// meant to resolve to a document position within its text: [Alignment.center] alone isn't reliable
/// for that, since a Fountain element's box is typically much wider than a short line of text (its
/// `Styles.maxWidth`, not the text's own measured width) — the dead centre of the box then falls in
/// the empty space to the right of the actual characters, where `getDocumentPositionNearestToOffset`
/// snaps to the end of the text with an *upstream* affinity, which the exact-offset, *downstream*-
/// affinity end of a selection built with a plain `TextNodePosition(offset: ...)` doesn't compare
/// equal to (`doesSelectionContainPosition` cares about affinity, not just offset).
Offset _tapOffsetInsideText(String nodeId) =>
    SuperEditorInspector.findComponentOffset(nodeId, Alignment.centerLeft) + const Offset(4, 0);

/// Runs a right-click context-menu [testWidgets] case with [defaultTargetPlatform] forced to a
/// desktop platform for [body]'s whole duration.
///
/// `flutter test` forces `defaultTargetPlatform` to [TargetPlatform.android] (see
/// `_platform_io.dart`'s own `FLUTTER_TEST` check), which would otherwise make `SuperEditor` build
/// its Android touch interactor instead of `DocumentMouseInteractor` — a completely different
/// gesture surface, whose selection-handle machinery ends up swallowing a right-click's pointer
/// event before it ever reaches this widget's own `GestureDetector`. Overriding it to a desktop
/// platform is what actually exercises the code path this app ships on Linux/Windows, where a real
/// OS never sets `FLUTTER_TEST` in the first place.
///
/// The override is set and reset from *inside* the test body (a `try`/`finally` here), not through
/// `setUp`/`tearDown`: `testWidgets` asserts every foundation debug variable is back to its default
/// before the `test` package's own `tearDown` queue ever runs, so resetting it there fires that
/// assertion too late — resetting it before this function's own `async` body returns is what
/// actually lands in time.
void _testWidgetsAsDesktop(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; every test below that gives the styled editor a selection is affected.
  BlinkController.indeterminateAnimationsEnabled = false;

  testWidgets("renders a scene heading bold at the margin and indents a character cue further than action", (
    tester,
  ) async {
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
  });

  testWidgets("sizes and positions every element type at the raw preview's indent/width, wide enough that "
      "a long character cue never wraps", (tester) async {
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
    final nodeIds = [for (var index = 0; index < elementsByNodeIndex.length; index++) _nodeAt(document, index).id];
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
  });

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

    testWidgets("paints exactly one Scrollbar, ancestor of SuperEditor, so the thumb never sits over the "
        "page", (tester) async {
      await _pumpStandaloneEditor(
        tester,
        "INT. HOUSE - DAY\n\nSome action text.",
        isPageSimulationEnabled: true,
        areSceneNumbersVisible: true,
      );

      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.descendant(of: find.byType(Scrollbar), matching: find.byType(SuperEditor)), findsOneWidget);
    });

    testWidgets("paints exactly one Scrollbar, ancestor of SuperEditor, with page simulation disabled too", (
      tester,
    ) async {
      await _pumpStandaloneEditor(tester, "INT. HOUSE - DAY\n\nSome action text.");

      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.descendant(of: find.byType(Scrollbar), matching: find.byType(SuperEditor)), findsOneWidget);
    });

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

    testWidgets("a screenplay that fits on one sheet is not numbered at all", (tester) async {
      await _pumpStandaloneEditor(
        tester,
        "INT. HOUSE - DAY\n\nSome action text.",
        isPageSimulationEnabled: true,
      );

      // Two sheets are painted here (the title page, then the one and only script page), and
      // neither of them is ever numbered: the printed screenplay numbers nothing before its
      // second script page, and the styled mode prints that rule and no other.
      expect(_pageSheetsPainterFinder(), paintsExactlyCountTimes(#drawParagraph, 0));
    });

    testWidgets("the second script page is numbered, half an inch below its own sheet's top edge and "
        "right-aligned at the page's right margin", (tester) async {
      final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
      // Tall enough for the title sheet, the first script page and the second one to be laid out
      // at once: a sheet scrolled out of view has its number skipped (see `_paintPageNumber`), and
      // wide enough for a full US Letter page to lay out unscaled.
      tester.view.physicalSize = Size(1600, 3 * (layout.pageHeight + OcptEditorPreviewLayout.pageGap) + 100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 40 one-line action paragraphs, each preceded by a blank line: 79 lines, which overflows
      // US Letter's 54 lines per page exactly once — a title sheet plus two script pages.
      await _pumpStandaloneEditor(
        tester,
        List.generate(40, (index) => "Action line $index.").join("\n\n"),
        isPageSimulationEnabled: true,
      );

      // "2." is two columns wide in a fixed-pitch font, and the number's right edge lands exactly
      // where the printed page's own right margin starts.
      final expectedOffset = Offset(
        layout.pageWidth - layout.marginRight - 2 * layout.glyphWidth,
        2 * (layout.pageHeight + OcptEditorPreviewLayout.pageGap) + ocptScriptPageNumberTopInches * layout.pixelsPerInch,
      );

      expect(
        _pageSheetsPainterFinder(),
        paints..paragraph(offset: within(distance: 0.5, from: expectedOffset)),
      );
      // Exactly one number on screen: the title sheet and the first script page carry none.
      expect(_pageSheetsPainterFinder(), paintsExactlyCountTimes(#drawParagraph, 1));
    });

    testWidgets("every element still spans its exact preview width, at its exact preview indent from the "
        "page's left edge", (tester) async {
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
          tester.getRect(find.byType(SuperEditor)).left + OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;

      // Blank source lines are folded into metadata, so nodes are dense: heading, action,
      // character, dialogue. `titlePageFieldCount` leading nodes come first (page simulation is
      // on, and this text has no title page of its own, so all six fields synthesize empty).
      final elementsByNodeIndex = [metrics.sceneHeading, metrics.action, metrics.character];

      for (var index = 0; index < elementsByNodeIndex.length; index++) {
        final element = elementsByNodeIndex[index];
        final nodeId = document.getNodeAt(index + _titlePageFieldCount)!.id;

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
    });

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

    testWidgets("a full-width element's box exactly fills the editor's own width, flush with the page's "
        "left edge, leaving the true right margin outside it (no leftover super_editor centering "
        "slack eating half of it)", (tester) async {
      // The default test surface (800x600) is narrower than the full page-simulation width
      // (`pageWidth` can reach ~975 logical pixels at US Letter): widen it first, like the
      // M1 test above and the app's own desktop window would be in practice.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpStandaloneEditor(tester, "Some action text.", isPageSimulationEnabled: true);

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, _titlePageFieldCount).id;
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
    });

    testWidgets("a panel narrower than the page scales the page down instead of squeezing it", (
      tester,
    ) async {
      final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
      // Narrower than the page on purpose — what the centre panel actually is once both workspace
      // docks are open. The regression this guards: the page used to be laid out at whatever width
      // the panel offered, and since every element's `Styles.maxWidth` is an absolute pixel width
      // taken from the page metrics, each line then wrapped several columns early. Those surplus
      // lines made every page render taller than the sheet `computeOcptStyledPagination` sized for
      // it, and the text ran out under the sheet's bottom edge, page after page.
      final narrowPanelWidth = layout.pageWidth / 2;
      tester.view.physicalSize = Size(narrowPanelWidth, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpStandaloneEditor(tester, "Some action text.", isPageSimulationEnabled: true);

      // The editor's own box keeps the page's geometry (`getSize` reports it before the scale),
      // while its on-screen bounds (`getRect`, after it) fit inside the narrow panel.
      const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
      final unscaledWidth = layout.pageWidth - layout.marginRight + inset * 2;
      expect(tester.getSize(find.byType(SuperEditor)).width, closeTo(unscaledWidth, 0.5));
      expect(
        tester.getRect(find.byType(SuperEditor)).width,
        closeTo(unscaledWidth / 2, 0.5),
      );
      expect(tester.getRect(find.byType(SuperEditor)).right, lessThanOrEqualTo(narrowPanelWidth + 0.5));
    });
  });

  group("title page", () {
    // Every title-page widget test used to pump with `areSceneNumbersVisible: false`, while the
    // app always runs with it on — the blind spot that let F5's regression ship unnoticed. Running
    // the whole group both ways closes it: the `true` variants below must pass exactly like the
    // `false` ones once a title-page node is only ever claimed by its own component builder.
    for (final sceneNumbersVisible in [false, true]) {
      testWidgets(
        "an empty title-page field shows its label as a placeholder hint (scene numbers: $sceneNumbersVisible)",
        (tester) async {
          await _pumpStandaloneEditor(
            tester,
            "Some action.",
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: sceneNumbersVisible,
          );

          expect(find.text("Title"), findsOneWidget);
          expect(find.text("Credit"), findsOneWidget);
          expect(find.text("Source"), findsOneWidget);
        },
      );

      testWidgets("an empty title-page field's placeholder sits exactly where the real value would be typeset "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        // The title fields sit hundreds of pixels down the simulated page: tall enough that the
        // default 800x600 test surface would leave the lower fields outside the viewport.
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        // Same "page's content area" reconstruction the page-simulation group above uses: the
        // editor's own box spans the content area widened by the stylesheet's horizontal
        // `documentPadding` inset on each side (see `OcptStyledScreenplayEditor.build`).
        final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
        const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
        final editorRect = tester.getRect(find.byType(SuperEditor));
        final pageLeftEdge = editorRect.left + inset;
        final pageRightEdge = pageLeftEdge + layout.pageWidth;
        final contentLeft = pageLeftEdge + layout.marginLeft;
        final contentRight = pageRightEdge - layout.marginRight;
        final contentCentreX = (contentLeft + contentRight) / 2;

        // Title/Credit/Author are centred on the content area, exactly like the value that will
        // replace them (this is the assertion that fails against the pre-fix `TextWithHintComponent`,
        // whose hint `Text.rich` never receives a `textAlign` and so always sits flush left).
        for (final label in ["Title", "Credit", "Author"]) {
          final rect = tester.getRect(find.text(label));
          expect(rect.center.dx, closeTo(contentCentreX, 1), reason: "$label placeholder");
        }

        // Draft date is right-aligned, its text ending flush with the content area's right edge.
        final draftDateRect = tester.getRect(find.text("Draft date"));
        expect(draftDateRect.right, closeTo(contentRight, 1));
      });

      testWidgets("the Title placeholder is typeset at the Title rule's own font size and weight "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        // Fails against the pre-fix `hintStyleBuilder`, which built a fresh `TextStyle` at body
        // size instead of decorating the Title rule's own resolved style (`fontSize * 1.6`, bold).
        final titleHint = tester.widget<Text>(find.text("Title"));
        expect(titleHint.style?.fontSize, OcptEditorPreviewLayout.fontSize * 1.6);
        expect(titleHint.style?.fontWeight, FontWeight.bold);
      });

      testWidgets(
        "the title sheet disappears entirely while page simulation is off (scene numbers: $sceneNumbersVisible)",
        (tester) async {
          await _pumpStandaloneEditor(tester, "Some action.", areSceneNumbersVisible: sceneNumbersVisible);

          expect(find.text("Title"), findsNothing);
          final document = SuperEditorInspector.findDocument()!;
          expect(document.nodeCount, 1);
        },
      );

      testWidgets(
        "typing into the empty Title placeholder writes it into the encoded source (scene numbers: $sceneNumbersVisible)",
        (tester) async {
          // The title fields sit hundreds of pixels down the simulated page (Title alone opens with a
          // top gap landing it in the upper-middle area): tall enough that the default 800x600 test
          // surface would leave it (and every field below it) outside the viewport a tap can reach.
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          String? encodedText;

          await tester.pumpWidget(
            _wrap(
              OcptStyledScreenplayEditor(
                text: "INT. HOUSE - DAY\n\nSome action.",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: true,
                areSceneNumbersVisible: sceneNumbersVisible,
                onTextChanged: (text) => encodedText = text,
                onCaretLineChanged: (_) {},
                jumpRequest: null,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final document = SuperEditorInspector.findDocument()!;
          final titleNodeId = document.getNodeAt(0)!.id;

          await tester.placeCaretInParagraph(titleNodeId, 0);
          await tester.typeImeText("My Movie");
          await tester.pump(const Duration(milliseconds: 200));

          // The scene heading is auto-numbered by default (see the "scene numbers" group below).
          expect(encodedText, "Title: My Movie\n\nINT. HOUSE - DAY #1#\n\nSome action.");
          // The placeholder is gone now that the field has real text.
          expect(find.text("Title"), findsNothing);
        },
      );

      testWidgets(
        "pressing Enter inside the Author field adds a sibling line, not a body block (scene numbers: $sceneNumbersVisible)",
        (tester) async {
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          String? encodedText;

          await tester.pumpWidget(
            _wrap(
              OcptStyledScreenplayEditor(
                text: "Some action.",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: true,
                areSceneNumbersVisible: sceneNumbersVisible,
                onTextChanged: (text) => encodedText = text,
                onCaretLineChanged: (_) {},
                jumpRequest: null,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Title, Credit, Author: indices 0, 1, 2.
          final authorNodeId = SuperEditorInspector.findDocument()!.getNodeAt(2)!.id;
          await tester.placeCaretInParagraph(authorNodeId, 0);
          await tester.typeImeText("Jane Doe");
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          await tester.typeImeText("John Smith");
          await tester.pump(const Duration(milliseconds: 200));

          final document = SuperEditorInspector.findDocument()!;
          expect(document.nodeCount, 8);
          expect((document.getNodeAt(2)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey), "Author");
          expect((document.getNodeAt(3)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey), "Author");
          expect((document.getNodeAt(2)! as ParagraphNode).text.toPlainText(), "Jane Doe");
          expect((document.getNodeAt(3)! as ParagraphNode).text.toPlainText(), "John Smith");
          expect(encodedText, "Author:\n    Jane Doe\n    John Smith\n\nSome action.");
        },
      );

      testWidgets("Backspace at the start of an empty field never deletes it (scene numbers: $sceneNumbersVisible)", (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        final document = SuperEditorInspector.findDocument()!;
        expect(document.nodeCount, _titlePageFieldCount + 1);
        // Credit: index 1.
        final creditNodeId = document.getNodeAt(1)!.id;

        await _placeCaretAtStartOf(tester, creditNodeId);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump(const Duration(milliseconds: 200));

        expect(document.nodeCount, _titlePageFieldCount + 1);
        expect(document.getNodeById(creditNodeId), isNotNull);
      });

      testWidgets("Backspace at the start of a filled field never deletes it (scene numbers: $sceneNumbersVisible)", (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        final document = SuperEditorInspector.findDocument()!;
        // Credit: index 1.
        final creditNodeId = document.getNodeAt(1)!.id;
        await _placeCaretAtStartOf(tester, creditNodeId);
        await tester.typeImeText("written by");
        await tester.pump(const Duration(milliseconds: 200));

        await _placeCaretAtStartOf(tester, creditNodeId);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump(const Duration(milliseconds: 200));

        expect(document.nodeCount, _titlePageFieldCount + 1);
        expect((document.getNodeById(creditNodeId)! as ParagraphNode).text.toPlainText(), "written by");
      });

      testWidgets(
        "Backspace at the start of the first body line never merges it into Source (scene numbers: $sceneNumbersVisible)",
        (tester) async {
          // Taller than the other title-page tests' own 1400x1200: with a title page present, the
          // still-open pagination defect (fixed separately, not by this change) currently renders the
          // body's first node around y=2600 instead of its eventual correct position, so the surface
          // needs enough headroom to reach it regardless of whether that fix has landed.
          tester.view.physicalSize = const Size(1400, 2700);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await _pumpStandaloneEditor(
            tester,
            "Some action.",
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: sceneNumbersVisible,
          );

          final document = SuperEditorInspector.findDocument()!;
          // Source: index 5. The body's only line: index 6.
          final sourceNodeId = document.getNodeAt(5)!.id;
          final bodyNodeId = document.getNodeAt(6)!.id;

          await _placeCaretAtStartOf(tester, bodyNodeId);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.pump(const Duration(milliseconds: 200));

          expect(document.nodeCount, _titlePageFieldCount + 1);
          expect(document.getNodeById(sourceNodeId), isNotNull);
          expect((document.getNodeById(bodyNodeId)! as ParagraphNode).text.toPlainText(), "Some action.");
        },
      );

      testWidgets(
        "Backspace can still remove an extra line added to a multi-line field (scene numbers: $sceneNumbersVisible)",
        (tester) async {
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await _pumpStandaloneEditor(
            tester,
            "Some action.",
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: sceneNumbersVisible,
          );

          // Title, Credit, Author: indices 0, 1, 2.
          final authorNodeId = SuperEditorInspector.findDocument()!.getNodeAt(2)!.id;
          await _placeCaretAtStartOf(tester, authorNodeId);
          await tester.typeImeText("Jane Doe");
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          await tester.typeImeText("John Smith");
          await tester.pump(const Duration(milliseconds: 200));

          final document = SuperEditorInspector.findDocument()!;
          expect(document.nodeCount, _titlePageFieldCount + 2);
          final secondAuthorLineId = document.getNodeAt(3)!.id;

          await _placeCaretAtStartOf(tester, secondAuthorLineId);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.pump(const Duration(milliseconds: 200));

          expect(document.nodeCount, _titlePageFieldCount + 1);
          expect((document.getNodeAt(2)! as ParagraphNode).text.toPlainText(), "Jane DoeJohn Smith");
          expect((document.getNodeAt(2)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey), "Author");
        },
      );

      testWidgets(
        "typing into a field then pressing Backspace deletes the last character "
        "(scene numbers: $sceneNumbersVisible)",
        (tester) async {
          // The F6 defect itself: `NodeMetadata.isDeletable: false` used to make
          // `DeleteContentCommand`/`DeleteSelectionCommand` abort *any* deletion inside a single
          // title-page node, not just the node's own removal — so typed text could never be
          // shortened, only added to.
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          String? encodedText;

          await tester.pumpWidget(
            _wrap(
              OcptStyledScreenplayEditor(
                text: "Some action.",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: true,
                areSceneNumbersVisible: sceneNumbersVisible,
                onTextChanged: (text) => encodedText = text,
                onCaretLineChanged: (_) {},
                jumpRequest: null,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Credit: index 1.
          final creditNodeId = SuperEditorInspector.findDocument()!.getNodeAt(1)!.id;
          await _placeCaretAtStartOf(tester, creditNodeId);
          await tester.typeImeText("written by");
          await tester.pump(const Duration(milliseconds: 200));

          // The caret sits at the end of "written by" (offset 10): a plain hardware Backspace, the
          // same key `CommonEditorOperations.deleteUpstreamCharacter`-driven path a real desktop
          // keypress travels through.
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.pump(const Duration(milliseconds: 200));

          expect((SuperEditorInspector.findDocument()!.getNodeById(creditNodeId)! as ParagraphNode).text.toPlainText(), "written b");
          expect(encodedText, contains("Credit: written b\n"));
        },
      );

      testWidgets(
        "deleting a selection inside a field removes just the selection "
        "(scene numbers: $sceneNumbersVisible)",
        (tester) async {
          tester.view.physicalSize = const Size(1400, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          String? encodedText;

          await tester.pumpWidget(
            _wrap(
              OcptStyledScreenplayEditor(
                text: "Some action.",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: true,
                areSceneNumbersVisible: sceneNumbersVisible,
                onTextChanged: (text) => encodedText = text,
                onCaretLineChanged: (_) {},
                jumpRequest: null,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Credit: index 1.
          final creditNodeId = SuperEditorInspector.findDocument()!.getNodeAt(1)!.id;
          await _placeCaretAtStartOf(tester, creditNodeId);
          await tester.typeImeText("written by");
          await tester.pump(const Duration(milliseconds: 200));

          // Extend the selection upstream over the last two characters ("by"), then delete them —
          // exactly the "typing over/deleting an expanded selection inside a field" case F2's flag
          // used to also silently block.
          await _sendShift(tester, LogicalKeyboardKey.arrowLeft);
          await _sendShift(tester, LogicalKeyboardKey.arrowLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.pump(const Duration(milliseconds: 200));

          expect((SuperEditorInspector.findDocument()!.getNodeById(creditNodeId)! as ParagraphNode).text.toPlainText(), "written ");
          expect(encodedText, contains("Credit: written \n"));
        },
      );

      testWidgets(
        "select-all then Delete clears the body but leaves the six title-page fields standing "
        "(scene numbers: $sceneNumbersVisible)",
        (tester) async {
          // Taller than most other title-page tests' own 1400x1200: with a title page present, the
          // still-open pagination defect (fixed separately, not by this change) currently renders the
          // body's first node around y=2600 instead of its eventual correct position, but this test
          // never needs to see the body at all — only the surface needs to be wide enough for the
          // widget tree to lay out without throwing.
          tester.view.physicalSize = const Size(1400, 2700);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          String? encodedText;

          await tester.pumpWidget(
            _wrap(
              OcptStyledScreenplayEditor(
                text: "INT. HOUSE - DAY\n\nSome action.",
                pageSetup: const OcptPageSetup.standard(),
                isPageSimulationEnabled: true,
                areSceneNumbersVisible: sceneNumbersVisible,
                onTextChanged: (text) => encodedText = text,
                onCaretLineChanged: (_) {},
                jumpRequest: null,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final fieldIds = [
            for (var index = 0; index < _titlePageFieldCount; index++)
              SuperEditorInspector.findDocument()!.getNodeAt(index)!.id,
          ];

          // Ctrl+A only reaches `SuperEditor`'s keyboard handlers once it has focus: place a caret
          // first, exactly like a real user would before selecting everything.
          await _placeCaretAtStartOf(tester, fieldIds.first);

          await _sendCtrl(tester, LogicalKeyboardKey.keyA);
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
          await tester.pump(const Duration(milliseconds: 200));

          final document = SuperEditorInspector.findDocument()!;
          // The two deleted body nodes (heading + action) are replaced by a single fresh empty one:
          // the six fields are untouched, so the sheet still always has all of them.
          expect(document.nodeCount, _titlePageFieldCount + 1);
          for (final fieldId in fieldIds) {
            expect(document.getNodeById(fieldId), isNotNull, reason: "field node $fieldId");
          }
          expect((document.getNodeAt(_titlePageFieldCount)! as ParagraphNode).text.toPlainText(), isEmpty);
          expect(encodedText, "");
        },
      );

      testWidgets("the Draft date and Contact placeholders share the same row, split at the page's horizontal centre "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        // Same "page's content area" reconstruction the earlier placeholder-alignment test uses.
        final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
        const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
        final editorRect = tester.getRect(find.byType(SuperEditor));
        final pageLeftEdge = editorRect.left + inset;
        final pageRightEdge = pageLeftEdge + layout.pageWidth;
        final contentLeft = pageLeftEdge + layout.marginLeft;
        final contentRight = pageRightEdge - layout.marginRight;
        final contentCentreX = (contentLeft + contentRight) / 2;

        final draftDateRect = tester.getRect(find.text("Draft date"));
        final contactRect = tester.getRect(find.text("Contact"));

        // Same row (Contact's own top gap is 0; the shift takes its place), split at the centre:
        // Contact stops at or before it, Draft date starts at or after it.
        expect(draftDateRect.top, closeTo(contactRect.top, 1));
        expect(contactRect.right, lessThanOrEqualTo(contentCentreX + 1));
        expect(draftDateRect.left, greaterThanOrEqualTo(contentCentreX - 1));
      });

      testWidgets("a filled Draft date and Contact still share the same row (scene numbers: $sceneNumbersVisible)", (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        // Draft date, Contact: indices 3, 4.
        final document = SuperEditorInspector.findDocument()!;
        final draftDateNodeId = document.getNodeAt(3)!.id;
        final contactNodeId = document.getNodeAt(4)!.id;

        await _placeCaretAtStartOf(tester, draftDateNodeId);
        await tester.typeImeText("2026-07-26");
        await tester.pump(const Duration(milliseconds: 200));

        await _placeCaretAtStartOf(tester, contactNodeId);
        await tester.typeImeText("Jane Doe");
        await tester.pump(const Duration(milliseconds: 200));

        // A filled node's own text no longer renders through a plain `Text` widget this builder
        // controls (unlike the empty placeholder), so the component's own box — read straight off
        // its `RenderBox`, the same way `SuperEditorInspector` and the document layout's own hit
        // testing both do — is what stands in for "where the field visually sits" here.
        final draftDateOffset = SuperEditorInspector.findComponentOffset(draftDateNodeId, Alignment.topRight);
        final contactOffset = SuperEditorInspector.findComponentOffset(contactNodeId, Alignment.topLeft);
        final contactSize = SuperEditorInspector.findComponentSize(contactNodeId);

        expect(draftDateOffset.dy, closeTo(contactOffset.dy, 1));
        expect(contactOffset.dx + contactSize.width, lessThanOrEqualTo(draftDateOffset.dx + 1));
      });

      testWidgets("tapping the Draft date and Contact fields routes the caret to the right node, not the other "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        // The risky assertion: it proves the paint-time shift `OcptTitlePageComponentBuilder`
        // applies to Contact/Source does not also move where a tap is hit-tested to, since both
        // are derived from the exact same (transformed) component `RenderBox` (see that builder's
        // own doc comment). A regression here would make one field swallow the other's clicks.
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        final document = SuperEditorInspector.findDocument()!;
        final draftDateNodeId = document.getNodeAt(3)!.id;
        final contactNodeId = document.getNodeAt(4)!.id;

        await _placeCaretAtStartOf(tester, draftDateNodeId);
        await _placeCaretAtStartOf(tester, contactNodeId);
      });

      testWidgets("a multi-line Contact still stacks under the row, and Source follows with no leftover gap "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpStandaloneEditor(
          tester,
          "Some action.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: sceneNumbersVisible,
        );

        // Contact: index 4.
        final contactNodeId = SuperEditorInspector.findDocument()!.getNodeAt(4)!.id;
        await _placeCaretAtStartOf(tester, contactNodeId);
        await tester.typeImeText("123 Reel Street");
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.typeImeText("Second line");
        await tester.pump(const Duration(milliseconds: 200));

        final document = SuperEditorInspector.findDocument()!;
        expect(document.nodeCount, _titlePageFieldCount + 2);
        // Title, Credit, Author, Draft date, Contact (first line): indices 0-4. Contact's second
        // line and Source follow at 5 and 6.
        final firstLineId = document.getNodeAt(4)!.id;
        final secondLineId = document.getNodeAt(5)!.id;
        final sourceNodeId = document.getNodeAt(6)!.id;

        final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
        final firstLineTop = SuperEditorInspector.findComponentOffset(firstLineId, Alignment.topLeft).dy;
        final secondLineOffset = SuperEditorInspector.findComponentOffset(secondLineId, Alignment.topLeft);
        final secondLineHeight = SuperEditorInspector.findComponentSize(secondLineId).height;
        // The two Contact lines stack with no gap between them, exactly one lineHeight apart.
        expect(secondLineOffset.dy - firstLineTop, closeTo(layout.lineHeight, 1));

        // Source keeps its usual one-line gap below the last Contact line, unaffected by the
        // shift: both nodes are painted with the exact same `rowShift` translation, so their
        // relative spacing is exactly what it was before this node ever needed shifting.
        final sourceTop = SuperEditorInspector.findComponentOffset(sourceNodeId, Alignment.topLeft).dy;
        expect(sourceTop - (secondLineOffset.dy + secondLineHeight), closeTo(layout.lineHeight, 1));
      });

      testWidgets("the shared Draft date/Contact row is purely visual: the encoded source is unaffected "
          "(scene numbers: $sceneNumbersVisible)", (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? encodedText;

        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              text: "Some action.",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: true,
              areSceneNumbersVisible: sceneNumbersVisible,
              onTextChanged: (text) => encodedText = text,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final draftDateNodeId = document.getNodeAt(3)!.id;
        final contactNodeId = document.getNodeAt(4)!.id;

        await tester.placeCaretInParagraph(draftDateNodeId, 0);
        await tester.typeImeText("2026-07-26");
        await tester.pump(const Duration(milliseconds: 200));

        await tester.placeCaretInParagraph(contactNodeId, 0);
        await tester.typeImeText("jane@example.com");
        await tester.pump(const Duration(milliseconds: 200));

        expect(encodedText, "Draft date: 2026-07-26\nContact: jane@example.com\n\nSome action.");
      });
    }

    testWidgets("a scene heading still shows its gutter number with a title page and scene numbers on", (tester) async {
      // Tall enough to reach the body's first (and only) node past the whole title sheet, same as
      // the "Backspace ... never merges it into Source" case above.
      tester.view.physicalSize = const Size(1400, 2700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpStandaloneEditor(
        tester,
        "INT. HOUSE - DAY\n\nSome action.",
        isPageSimulationEnabled: true,
        areSceneNumbersVisible: true,
      );

      // Proves `OcptSceneNumberGutterComponentBuilder` still claims its own nodes even though it
      // now falls through for every title-page node ahead of it in `componentBuilders`.
      expect(find.text("1"), findsOneWidget);
    });

    testWidgets("a multi-line field's placeholder hints only its first line", (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A Contact value split by Enter with no typed text left before the split: both resulting
      // nodes are empty, so both would show the "Contact" hint if the placeholder were still keyed
      // by node id rather than by "is this the field's first node".
      await _pumpStandaloneEditor(tester, "Some action.", isPageSimulationEnabled: true);

      // Contact: index 4.
      final contactNodeId = SuperEditorInspector.findDocument()!.getNodeAt(4)!.id;
      await _placeCaretAtStartOf(tester, contactNodeId);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      final document = SuperEditorInspector.findDocument()!;
      // Six title-page fields, one split into two lines, plus the body's one node.
      expect(document.nodeCount, _titlePageFieldCount + 2);
      expect((document.getNodeAt(4)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey), "Contact");
      expect((document.getNodeAt(5)! as ParagraphNode).getMetadataValue(ocptTitlePageKeyMetadataKey), "Contact");

      expect(find.text("Contact"), findsOneWidget);
    });

    testWidgets("Backspace via the IME delta channel at the start of a field does not merge it into its neighbour", (
      tester,
    ) async {
      // The IME delta channel is a genuinely different code path from `sendKeyEvent`: at offset 0
      // of a node, `document_delta_editing.dart`'s `delete()` sends a
      // `DeleteUpstreamAtBeginningOfNodeRequest`, never a `CombineParagraphsRequest` — so this
      // exercises `ocptTitlePageGuardRequestHandler`'s dedicated rule for that request, not the one
      // the hardware-Backspace tests above already cover.
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpStandaloneEditor(tester, "Some action.", isPageSimulationEnabled: true);

      // Credit: index 1.
      final creditNodeId = SuperEditorInspector.findDocument()!.getNodeAt(1)!.id;
      await _placeCaretAtStartOf(tester, creditNodeId);
      await tester.typeImeText("written by");
      await tester.pump(const Duration(milliseconds: 200));
      await _placeCaretAtStartOf(tester, creditNodeId);

      await tester.ime.backspace(getter: imeClientGetter);
      await tester.pump(const Duration(milliseconds: 200));

      final document = SuperEditorInspector.findDocument()!;
      expect(document.nodeCount, _titlePageFieldCount + 1);
      expect(document.getNodeById(creditNodeId), isNotNull);
      expect((document.getNodeById(creditNodeId)! as ParagraphNode).text.toPlainText(), "written by");
    });
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
    testWidgets("Tab advances through the six common types (wrapping) and locks the block; Shift+Tab "
        "reverses", (tester) async {
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
    });

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

    testWidgets("a plain Tab delivered as an IME text-insertion delta (the real desktop bug, not "
        "reproduced by sendKeyEvent) cycles the block type instead of inserting a literal tab", (tester) async {
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
    });

    testWidgets("Shift+Tab (a hardware KeyEvent, never delivered through the IME delta channel) still "
        "reverses the cycle once imeOverrides is wired", (tester) async {
      await _pumpStandaloneEditor(tester, "Some action text.");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);

      expect(_typeAt(document, 0), FountainLineType.action);

      await _sendShift(tester, LogicalKeyboardKey.tab);
      await tester.pump();

      expect(_typeAt(document, 0), FountainLineType.sceneHeading);
      expect(_isLockedAt(document, 0), isTrue);
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

    testWidgets("Shift+Enter splits into a node of the same type with no blank line before it", (tester) async {
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

    testWidgets("splitting a scene heading before its end lets the next reclassify pass settle the "
        "carried-over remainder's type instead of forcing a mismatched one onto it", (tester) async {
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
    });

    testWidgets("splitting one scene heading mid-text leaves every OTHER scene heading's number and text "
        "untouched", (tester) async {
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
    });
  });

  group("flushing a pending sync on deactivate", () {
    testWidgets("a scene heading split mid-text, then removed from the tree before its debounce clears, "
        "reports the same settled text a normal debounce would have", (tester) async {
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
      // A bounded pump shorter than the styled editor's 120 ms sync debounce: long enough to
      // process the split, short enough that `_syncTimer` is still pending when this widget is
      // removed from the tree below — the exact race `_flushPendingSync` has to handle.
      await tester.pump(const Duration(milliseconds: 20));

      // Replacing the whole widget tree removes `OcptStyledScreenplayEditor`, running
      // `deactivate()` (and, with it, `_flushPendingSync`) without ever letting `_syncTimer`
      // fire on its own.
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump();

      // Before this fix, flushing skipped reclassification entirely and encoded the split
      // fragment under its stale `sceneHeading` type, forcing a "." marker onto text that no
      // longer read as a heading (and, once decoded again, sticking as a permanent forcing
      // marker misclassified as user intent).
      expect(lastEncoded, isNot(contains("!")));
      expect(lastEncoded, "INT. #1#\n\n HOUSE - DAY");
    });
  });

  testWidgets("reclassify skips a locked block; emptying it keeps the lock and the type sticky for "
      "whatever is typed next", (tester) async {
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
  });

  group("auto-uppercase scene headings, character cues and transitions", () {
    testWidgets("typing a lowercase scene heading uppercases the stored text as you type, caret offset unchanged", (
      tester,
    ) async {
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
    });

    testWidgets("typing lowercase text into a manually-locked character cue or transition uppercases it", (
      tester,
    ) async {
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
    });

    testWidgets("a character type set on an empty block survives the reclassify debounce firing before any "
        "text is typed", (tester) async {
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
    });

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

  testWidgets("Ctrl+B, Ctrl+I and Ctrl+U toggle bold/italic/underline, serialized as **/*/_", (tester) async {
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

    testWidgets("typing a #N# tag that does not fit its position is absorbed then immediately corrected", (
      tester,
    ) async {
      await _pumpStandaloneEditor(tester, "INT. HOUSE - DAY");

      final document = SuperEditorInspector.findDocument()!;
      final node = _nodeAt(document, 0);
      await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);

      await tester.typeImeText(" #4A#");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(_nodeAt(document, 0).text.toPlainText(), "INT. HOUSE - DAY");
      expect(_sceneNumberAt(document, 0), "1");
    });

    testWidgets("the scene-number gutter renders only while areSceneNumbersVisible is true", (tester) async {
      const text = "INT. HOUSE - DAY\n\nAction.";

      await _pumpStandaloneEditor(tester, text);
      expect(find.text("1"), findsNothing);

      await _pumpStandaloneEditor(tester, text, key: const Key("visible"), areSceneNumbersVisible: true);
      expect(find.text("1"), findsOneWidget);
    });

    testWidgets("every scene heading is auto-numbered into the source, even with no #N# typed", (tester) async {
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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          switch (methodCall.method) {
            case "Clipboard.setData":
              clipboardText = (methodCall.arguments as Map)["text"] as String?;
              return null;
            case "Clipboard.getData":
              return {"text": clipboardText};
            default:
              return null;
          }
        },
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets("copying a character cue and its dialogue, then pasting them on a fresh blank line, "
        "reproduces both blocks with their types and spacing", (tester) async {
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
    });

    testWidgets("pasting a single-node fragment inside existing text inserts it inline without splitting the block", (
      tester,
    ) async {
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
    });

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

  group("OcptStyledEditorController — find/replace", () {
    /// Reads the [TextStyle] currently painted behind the exact substring [text] inside the
    /// paragraph [nodeId]'s own rendered [TextSpan] tree — the only way to observe
    /// `OcptSearchMatchStyler`'s effect from outside its own library, since it never touches the
    /// live document or exposes anything of its own.
    TextStyle? styleOfSubstring(String nodeId, String text) {
      TextStyle? found;
      SuperEditorInspector.findRichTextInParagraph(nodeId).visitChildren((span) {
        if (span is TextSpan && span.text == text) {
          found = span.style;
          return false;
        }
        return true;
      });
      return found;
    }

    testWidgets("matches are highlighted, the current one more strongly than the rest", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await _pumpStandaloneEditor(tester, "Line one.\n\nLine two.\n", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final firstNodeId = _nodeAt(document, 0).id;
      final secondNodeId = _nodeAt(document, 1).id;

      controller.updateSearch(
        query: const OcptEditorSearchQuery(query: "Line", isCaseSensitive: false, isWholeWord: false),
        currentMatchIndex: 0,
      );
      await tester.pump();

      expect(styleOfSubstring(firstNodeId, "Line")?.backgroundColor, ocptEditorSearchCurrentMatchColor);
      expect(styleOfSubstring(secondNodeId, "Line")?.backgroundColor, ocptEditorSearchMatchColor);
    });

    testWidgets("navigation moves the current match without stealing keyboard focus", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      // Stands in for the real find field's own `FocusNode`, which is what must keep the keyboard
      // focus across a navigation: this test proves it never loses it, rather than asserting on
      // Flutter's own ambient "some scope always has *a* primary focus" default, which would be
      // true even if this widget did nothing at all.
      final proxyFindFieldFocusNode = FocusNode();
      addTearDown(proxyFindFieldFocusNode.dispose);

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              SizedBox(height: 40, child: TextField(focusNode: proxyFindFieldFocusNode)),
              Expanded(
                child: OcptStyledScreenplayEditor(
                  text: "Line one.\n\nLine two.\n\nLine three.\n",
                  pageSetup: const OcptPageSetup.standard(),
                  isPageSimulationEnabled: false,
                  areSceneNumbersVisible: false,
                  onTextChanged: (_) {},
                  onCaretLineChanged: (_) {},
                  jumpRequest: null,
                  styledController: controller,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      proxyFindFieldFocusNode.requestFocus();
      await tester.pump();
      expect(proxyFindFieldFocusNode.hasFocus, isTrue);

      final document = SuperEditorInspector.findDocument()!;
      final firstNodeId = _nodeAt(document, 0).id;
      final secondNodeId = _nodeAt(document, 1).id;
      const query = OcptEditorSearchQuery(query: "Line", isCaseSensitive: false, isWholeWord: false);

      controller.updateSearch(query: query, currentMatchIndex: 0);
      await tester.pump();

      var selection = SuperEditorInspector.findDocumentSelection();
      expect(selection?.extent.nodeId, firstNodeId);
      expect((selection!.extent.nodePosition as TextNodePosition).offset, "Line".length);
      expect(proxyFindFieldFocusNode.hasFocus, isTrue);

      controller.updateSearch(query: query, currentMatchIndex: 1);
      await tester.pump();

      selection = SuperEditorInspector.findDocumentSelection();
      expect(selection?.extent.nodeId, secondNodeId);
      expect(proxyFindFieldFocusNode.hasFocus, isTrue);
    });

    testWidgets("a replacement reaches the encoded text and reports the next match's index", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      var lastEncoded = "";

      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            text: "Line one.\n\nLine two.\n",
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

      controller.updateSearch(
        query: const OcptEditorSearchQuery(query: "Line", isCaseSensitive: false, isWholeWord: false),
        currentMatchIndex: 0,
      );
      await tester.pump();

      final nextIndex = controller.replaceCurrentMatch("Scene");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(lastEncoded, contains("Scene one."));
      expect(lastEncoded, contains("Line two."));
      // Only "Line two." matches "Line" once "Line one." became "Scene one.", so it's the sole
      // remaining match, at index 0.
      expect(nextIndex, 0);
    });

    testWidgets(
      "replacing advances past a replacement that itself still matches the query, renaming every "
      "occurrence exactly once rather than compounding onto the same spot",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        var lastEncoded = "";

        await tester.pumpWidget(
          _wrap(
            OcptStyledScreenplayEditor(
              text: "MARIE enters.\n\nMARIE speaks.\n",
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

        const query = OcptEditorSearchQuery(query: "MARIE", isCaseSensitive: false, isWholeWord: false);
        controller.updateSearch(query: query, currentMatchIndex: 0);
        await tester.pump();

        // "MARIE" replaced by "MARIE-JEANNE" still matches "MARIE" at that very same offset, so
        // this is the plan's own headline scenario for putting replace in scope at all.
        final firstNextIndex = controller.replaceCurrentMatch("MARIE-JEANNE");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        // The first occurrence is renamed, the second isn't touched yet, and — the actual
        // regression this guards — the current match did not stay stuck inside what was just
        // written (it would otherwise turn the next replace into "MARIE-JEANNE-JEANNE").
        expect(lastEncoded, contains("MARIE-JEANNE enters."));
        expect(lastEncoded, contains("MARIE speaks."));
        expect(lastEncoded, isNot(contains("JEANNE-JEANNE")));
        expect(firstNextIndex, isNotNull);

        // The page's own follow-up: dispatching `OcptEditorSearchCurrentMatchSelectedEvent` with
        // `firstNextIndex` ultimately reaches the delegate through another `updateSearch` call.
        controller.updateSearch(query: query, currentMatchIndex: firstNextIndex);
        await tester.pump();

        controller.replaceCurrentMatch("MARIE-JEANNE");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(lastEncoded, "MARIE-JEANNE enters.\n\nMARIE-JEANNE speaks.\n");
      },
    );
  });

  group("a parenthetical opens on ()", () {
    testWidgets("setBlockType(parenthetical) on an empty block inserts () and places the caret between them", (
      tester,
    ) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await _pumpStandaloneEditor(tester, "", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);

      controller.setBlockType(FountainLineType.parenthetical);
      await tester.pump();

      expect(_typeAt(document, 0), FountainLineType.parenthetical);
      expect(_isLockedAt(document, 0), isTrue);
      expect(_nodeAt(document, 0).text.toPlainText(), "()");

      final selection = SuperEditorInspector.findDocumentSelection();
      expect(selection, isNotNull);
      expect(selection!.isCollapsed, isTrue);
      expect(selection.extent.nodeId, nodeId);
      expect((selection.extent.nodePosition as TextNodePosition).offset, 1);
    });

    testWidgets("setBlockType(parenthetical) on a block that already holds text leaves the text untouched", (
      tester,
    ) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await _pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);

      controller.setBlockType(FountainLineType.parenthetical);
      await tester.pump();

      expect(_typeAt(document, 0), FountainLineType.parenthetical);
      expect(_nodeAt(document, 0).text.toPlainText(), "Some action text.");
    });

    testWidgets("Tab-cycling onto parenthetical from an empty block inserts the () pair, and the encoded "
        "text carries it through the sync debounce", (tester) async {
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
      // An empty block auto-detects as `action`, and `parenthetical` sits two steps further down
      // the cycle, right after `character`: hence the two Tab presses below.
      expect(_typeAt(document, 0), FountainLineType.action);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_typeAt(document, 0), FountainLineType.character);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(_typeAt(document, 0), FountainLineType.parenthetical);
      expect(_nodeAt(document, 0).text.toPlainText(), "()");

      final selection = SuperEditorInspector.findDocumentSelection();
      expect(selection, isNotNull);
      expect(selection!.extent.nodeId, nodeId);
      expect((selection.extent.nodePosition as TextNodePosition).offset, 1);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(lastEncoded.contains("()"), isTrue);
    });
  });

  group("right-click context menu", () {
    // Mirrors the "copy, cut and paste keep block types" group's own clipboard mock: without it,
    // `Clipboard.getData`/`setData` never complete, and a context-menu Copy/Paste hangs forever.
    String? clipboardText;
    setUp(() {
      clipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          switch (methodCall.method) {
            case "Clipboard.setData":
              clipboardText = (methodCall.arguments as Map)["text"] as String?;
              return null;
            case "Clipboard.getData":
              return {"text": clipboardText};
            default:
              return null;
          }
        },
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    _testWidgetsAsDesktop("right-clicking with a collapsed caret shows Paste, Select all and Block type, but "
        "neither Cut nor Copy", (tester) async {
      await _pumpStandaloneEditor(tester, "Some action text.");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      final tapOffset = _tapOffsetInsideText(nodeId);

      await tester.tapAt(tapOffset, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
      expect(find.text(tr.editorContextMenuPasteAction), findsOneWidget);
      expect(find.text(tr.editorContextMenuSelectAllAction), findsOneWidget);
      expect(find.text(tr.editorContextMenuBlockTypeSubmenu), findsOneWidget);
      expect(find.text(tr.editorContextMenuCutAction), findsNothing);
      expect(find.text(tr.editorContextMenuCopyAction), findsNothing);
    });

    _testWidgetsAsDesktop("right-clicking with an expanded selection shows Cut and Copy too, and picking Copy "
        "puts that selection's Fountain source on the clipboard", (tester) async {
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

      final tapOffset = _tapOffsetInsideText(dialogueNode.id);
      await tester.tapAt(tapOffset, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
      expect(find.text(tr.editorContextMenuCutAction), findsOneWidget);
      expect(find.text(tr.editorContextMenuCopyAction), findsOneWidget);

      await tester.tap(find.text(tr.editorContextMenuCopyAction));
      await tester.pumpAndSettle();

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, "SARAH\nHello there.");
    });

    _testWidgetsAsDesktop("picking Paste inserts the clipboard's Fountain source at the caret, block types "
        "and all", (tester) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        _wrap(
          OcptStyledScreenplayEditor(
            text: "Some trailing action.",
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

      // Fountain source put on the clipboard by anything at all — another app, or this editor's own
      // Copy: the payload is plain Fountain text either way, which is the whole point of sharing
      // `ocptPasteFountainClipboardContent` with the Ctrl+V handler.
      await Clipboard.setData(const ClipboardData(text: "SARAH\nHello there."));

      final document = SuperEditorInspector.findDocument()!;
      final actionNode = _nodeAt(document, 0);
      // A fresh empty line at the very end of the document, the common "paste elsewhere" target.
      await tester.placeCaretInParagraph(actionNode.id, actionNode.text.toPlainText().length);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      await tester.tapAt(_tapOffsetInsideText(_nodeAt(document, 1).id), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
      await tester.tap(find.text(tr.editorContextMenuPasteAction));
      await tester.pumpAndSettle();

      expect(document.nodeCount, 3);
      expect(_typeAt(document, 1), FountainLineType.character);
      expect(_nodeAt(document, 1).text.toPlainText(), "SARAH");
      expect(_typeAt(document, 2), FountainLineType.dialogue);
      expect(_nodeAt(document, 2).text.toPlainText(), "Hello there.");

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(lastEncoded, "Some trailing action.\n\nSARAH\nHello there.");
    });

    _testWidgetsAsDesktop("right-clicking a different block than the one holding the caret retypes THAT block "
        "through the submenu, not the previously-focused one", (tester) async {
      const text = "INT. HOUSE - DAY\n\nSome action text.";
      await _pumpStandaloneEditor(tester, text);

      final document = SuperEditorInspector.findDocument()!;
      final headingNode = _nodeAt(document, 0);
      final actionNode = _nodeAt(document, 1);

      await tester.placeCaretInParagraph(headingNode.id, 0);

      final tapOffset = _tapOffsetInsideText(actionNode.id);
      await tester.tapAt(tapOffset, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
      await tester.tap(find.text(tr.editorContextMenuBlockTypeSubmenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ocptFountainLineTypeLabel(tr, FountainLineType.character)));
      await tester.pumpAndSettle();

      // The heading (where the caret used to sit) is untouched; the action block the right-click
      // actually landed on is the one that got retyped.
      expect(_typeAt(document, 0), FountainLineType.sceneHeading);
      expect(_typeAt(document, 1), FountainLineType.character);
    });

    _testWidgetsAsDesktop("right-clicking inside an existing expanded selection leaves that selection intact", (
      tester,
    ) async {
      const text = "SARAH\nHello there.\n\nSome trailing action.";
      await _pumpStandaloneEditor(tester, text);

      final document = SuperEditorInspector.findDocument()!;
      final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
      final characterNode = _nodeAt(document, 0);
      final dialogueNode = _nodeAt(document, 1);

      await tester.placeCaretInParagraph(characterNode.id, 0);
      final expandedSelection = DocumentSelection(
        base: DocumentPosition(nodeId: characterNode.id, nodePosition: const TextNodePosition(offset: 0)),
        extent: DocumentPosition(
          nodeId: dialogueNode.id,
          nodePosition: TextNodePosition(offset: dialogueNode.text.toPlainText().length),
        ),
      );
      composer.setSelectionWithReason(expandedSelection);
      await tester.pump();

      // The tap lands on the character cue, itself inside the selection's own range.
      final tapOffset = _tapOffsetInsideText(characterNode.id);
      await tester.tapAt(tapOffset, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(SuperEditorInspector.findDocumentSelection(), expandedSelection);
    });

    _testWidgetsAsDesktop("picking a type in the submenu changes the block's type and locks it, exactly like "
        "the toolbar dropdown", (tester) async {
      await _pumpStandaloneEditor(tester, "Some action text.");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      final tapOffset = _tapOffsetInsideText(nodeId);

      expect(_typeAt(document, 0), FountainLineType.action);
      expect(_isLockedAt(document, 0), isFalse);

      await tester.tapAt(tapOffset, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
      await tester.tap(find.text(tr.editorContextMenuBlockTypeSubmenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ocptFountainLineTypeLabel(tr, FountainLineType.character)));
      await tester.pumpAndSettle();

      expect(_typeAt(document, 0), FountainLineType.character);
      expect(_isLockedAt(document, 0), isTrue);
    });

    _testWidgetsAsDesktop("a left click elsewhere on the document closes the menu and still places the "
        "caret", (tester) async {
      const text = "INT. HOUSE - DAY\n\nSome action text.";
      await _pumpStandaloneEditor(tester, text);

      final document = SuperEditorInspector.findDocument()!;
      final headingNode = _nodeAt(document, 0);
      final actionNode = _nodeAt(document, 1);

      // Right-clicked on the lower node and left-clicked back on the upper one, so the second click
      // lands on the document itself rather than on the menu the first one just opened below it.
      await tester.tapAt(_tapOffsetInsideText(actionNode.id), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
      expect(find.text(tr.editorContextMenuSelectAllAction), findsOneWidget);

      await tester.tapAt(_tapOffsetInsideText(headingNode.id));
      await tester.pumpAndSettle();

      expect(find.text(tr.editorContextMenuSelectAllAction), findsNothing);
      expect(SuperEditorInspector.findDocumentSelection()?.extent.nodeId, headingNode.id);
    });

    _testWidgetsAsDesktop("Select all expands the selection across the whole document", (tester) async {
      const text = "INT. HOUSE - DAY\n\nSome action text.";
      await _pumpStandaloneEditor(tester, text);

      final document = SuperEditorInspector.findDocument()!;
      final headingNode = _nodeAt(document, 0);
      final actionNode = _nodeAt(document, 1);
      final tapOffset = _tapOffsetInsideText(headingNode.id);

      await tester.tapAt(tapOffset, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
      await tester.tap(find.text(tr.editorContextMenuSelectAllAction));
      await tester.pumpAndSettle();

      final selection = SuperEditorInspector.findDocumentSelection();
      expect(selection, isNotNull);
      expect(selection!.base.nodeId, headingNode.id);
      expect((selection.base.nodePosition as TextNodePosition).offset, 0);
      expect(selection.extent.nodeId, actionNode.id);
      expect(
        (selection.extent.nodePosition as TextNodePosition).offset,
        actionNode.text.toPlainText().length,
      );
    });
  });

  group("undo and redo", () {
    // These cases only assert that Ctrl+Z/Ctrl+Shift+Z/Ctrl+Y reach a live, history-enabled
    // `Editor` and restore the document rather than throwing. How many keystrokes one Ctrl+Z gives
    // back is a separate question, decided by the `historyGroupingPolicy`
    // `_rebuildEditorFrom` hands its `Editor`, so every case below types a single character and
    // asserts nothing about grouping.

    testWidgets("typing a character then Ctrl+Z removes it, with no exception", (tester) async {
      await _pumpStandaloneEditor(tester, "");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);
      await tester.typeImeText("A");

      expect(_nodeAt(document, 0).text.toPlainText(), "A");

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();

      expect(document.nodeCount, 1);
      expect(_nodeAt(document, 0).text.toPlainText(), "");
    });

    testWidgets("Ctrl+Shift+Z redoes what Ctrl+Z just undid", (tester) async {
      await _pumpStandaloneEditor(tester, "");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);
      await tester.typeImeText("A");

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();
      expect(_nodeAt(document, 0).text.toPlainText(), "");

      await _sendCtrlShift(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();

      expect(document.nodeCount, 1);
      expect(_nodeAt(document, 0).text.toPlainText(), "A");
    });

    testWidgets("Ctrl+Y redoes what Ctrl+Z just undid (the Windows habit Ctrl+Shift+Z coexists with)", (
      tester,
    ) async {
      await _pumpStandaloneEditor(tester, "");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = _nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);
      await tester.typeImeText("A");

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();
      expect(_nodeAt(document, 0).text.toPlainText(), "");

      await _sendCtrl(tester, LogicalKeyboardKey.keyY);
      await tester.pumpAndSettle();

      expect(document.nodeCount, 1);
      expect(_nodeAt(document, 0).text.toPlainText(), "A");
    });
  });
}
