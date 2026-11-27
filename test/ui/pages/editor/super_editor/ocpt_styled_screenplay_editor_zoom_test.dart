// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_pagination.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_zoom_anchor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_zoom_wheel_physics.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// A screenplay long enough to span several pages: 80 one-line action paragraphs.
final String _longSource = List.generate(80, (index) => "Action line $index.").join("\n\n");

/// Pump a styled editor on a [width] wide surface, at [zoom], recording every step requested.
Future<List<int>> _pumpEditor(
  WidgetTester tester, {
  required String text,
  double zoom = 1,
  double width = 1600,
  bool isPageSimulationEnabled = false,
  OcptStyledEditorController? styledController,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final steps = <int>[];
  await tester.pumpWidget(
    testWrap(
      OcptStyledScreenplayEditor(
        text: text,
        pageSetup: const OcptPageSetup.standard(),
        isPageSimulationEnabled: isPageSimulationEnabled,
        areSceneNumbersVisible: false,
        isSpellCheckVisible: false,
        onTextChanged: (_) {},
        onCaretLineChanged: (_) {},
        jumpRequest: null,
        zoom: zoom,
        onZoomStepRequested: steps.add,
        styledController: styledController,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return steps;
}

/// Get the vertical scroll offset of the styled editor.
double _verticalOffset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: find.byType(SuperEditor), matching: find.byType(Scrollable)).first,
    )
    .position
    .pixels;

/// Turn the wheel by [delta] over [at], with Ctrl held when [withCtrl] is.
Future<void> _wheel(
  WidgetTester tester,
  Offset at,
  Offset delta, {
  required bool withCtrl,
  bool settles = true,
}) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(at));
  if (withCtrl) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  }
  await tester.sendEventToBinding(pointer.scroll(delta));
  if (withCtrl) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
  if (settles) {
    await tester.pumpAndSettle();
  }
}

/// Run the tests of the styled editor's page zoom.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  final metrics = FountainLayoutMetrics.usLetter();

  group("pagination", () {
    test("splits the pages at the same nodes at 50 %, 100 % and 200 %", () {
      /// Get the nodes starting a page, by position, and what the pass says of each.
      ({List<int> starts, int pageCount, List<double> inches}) paginate(double zoom) {
        final document = OcptWysiwygCodec.decode(_longSource).document;
        final pagination = computeOcptStyledPagination(
          document: document,
          metrics: metrics,
          zoom: zoom,
        );
        final layout = OcptEditorPreviewLayout(metrics: metrics, zoom: zoom);
        final starts = [
          for (var index = 0; index < document.nodeCount; index++)
            if (pagination.pageStartNodeIds.contains(document.getNodeAt(index)!.id)) index,
        ];

        return (
          starts: starts,
          pageCount: pagination.pageCount,
          // What a page start stores: the part of its padding that scales with the page.
          inches: [
            for (final index in starts)
              ocptPageStartMetadataOf(
                pagination.pageStartTopPaddings[document.getNodeAt(index)!.id]!,
                layout,
              ),
          ],
        );
      }

      final reference = paginate(1);
      expect(reference.pageCount, greaterThan(2));

      for (final zoom in [0.5, 2.0]) {
        final result = paginate(zoom);

        expect(result.pageCount, reference.pageCount, reason: "zoom $zoom");
        // The very same nodes start the pages...
        expect(result.starts, reference.starts, reason: "zoom $zoom");
        // ...and what is stored for them is the same, so a zoom never rewrites the document.
        for (var index = 0; index < result.inches.length; index++) {
          expect(
            result.inches[index],
            closeTo(reference.inches[index], 1e-6),
            reason: "zoom $zoom",
          );
        }
      }
    });

    test("a clamped page start is stored the same at every zoom, and reads back as no padding", () {
      final stored = [
        for (final zoom in [0.5, 1.0, 2.0])
          ocptPageStartMetadataOf(0, OcptEditorPreviewLayout(metrics: metrics, zoom: zoom)),
      ];

      expect(stored.toSet(), hasLength(1));
      expect(stored.first, isNot(0));
      for (final zoom in [0.5, 1.0, 2.0]) {
        expect(
          ocptPageStartPaddingOf(
            stored.first,
            OcptEditorPreviewLayout(metrics: metrics, zoom: zoom),
          ),
          0,
        );
      }
    });

    test("a page start's padding lands its text at the sheet's text origin at any zoom", () {
      for (final zoom in [0.5, 1.0, 2.0]) {
        final layout = OcptEditorPreviewLayout(metrics: metrics, zoom: zoom);
        final document = OcptWysiwygCodec.decode(_longSource).document;
        final pagination = computeOcptStyledPagination(
          document: document,
          metrics: metrics,
          zoom: zoom,
        );

        for (final entry in pagination.pageStartTopPaddings.entries) {
          // Stored, then worked out again at the zoom it is rendered at.
          final stored = ocptPageStartMetadataOf(entry.value, layout);

          expect(ocptPageStartPaddingOf(stored, layout), closeTo(entry.value, 1e-6));
        }
      }
    });
  });

  group("wheel", () {
    testWidgets("Ctrl + wheel asks for one step per notch and does not scroll the page", (
      tester,
    ) async {
      final steps = await _pumpEditor(tester, text: _longSource);
      final center = tester.getCenter(find.byType(SuperEditor));

      await _wheel(tester, center, const Offset(0, -100), withCtrl: true);
      await _wheel(tester, center, const Offset(0, 100), withCtrl: true);
      await _wheel(tester, center, const Offset(0, 100), withCtrl: true);

      expect(steps, [1, -1, -1]);
      expect(_verticalOffset(tester), 0);
    });

    testWidgets("a plain wheel scrolls the page and asks for no step", (tester) async {
      final steps = await _pumpEditor(tester, text: _longSource);

      await _wheel(
        tester,
        tester.getCenter(find.byType(SuperEditor)),
        const Offset(0, 200),
        withCtrl: false,
      );

      expect(steps, isEmpty);
      expect(_verticalOffset(tester), greaterThan(0));
    });
  });

  group("layout", () {
    testWidgets("zooming in re-typesets the text at the zoomed font size", (tester) async {
      const text = "INT. HOUSE - DAY\n\nSome action text.";
      await _pumpEditor(tester, text: text);
      final document = SuperEditorInspector.findDocument()!;
      final nodeId = document.getNodeAt(1)!.id;
      expect(
        SuperEditorInspector.findParagraphStyle(nodeId)?.fontSize,
        OcptEditorPreviewLayout.baseFontSize,
      );

      await _pumpEditor(tester, text: text, zoom: 2);

      expect(
        SuperEditorInspector.findParagraphStyle(document.getNodeAt(1)!.id)?.fontSize,
        OcptEditorPreviewLayout.baseFontSize * 2,
      );
    });

    testWidgets("a tap at 200 % places the caret on the character under the pointer", (
      tester,
    ) async {
      const text = "Some action text.";
      await _pumpEditor(tester, text: text, zoom: 2, width: 2000);
      final nodeId = SuperEditorInspector.findDocument()!.getNodeAt(0)!.id;
      final layout = OcptEditorPreviewLayout(metrics: metrics, zoom: 2);
      final origin = SuperEditorInspector.findComponentOffset(nodeId, Alignment.topLeft);

      // The middle of the glyph of the 6th character ("a" of "action").
      await tester.tapAt(origin + Offset(layout.glyphWidth * 5.5, layout.lineHeight / 2));
      await tester.pumpAndSettle();

      final selection = SuperEditorInspector.findDocumentSelection()!;
      expect(selection.isCollapsed, isTrue);
      // A tap on the left half of a glyph lands before it, on the right half after it.
      expect((selection.extent.nodePosition as TextNodePosition).offset, 6);
    });
  });

  group("horizontal overflow", () {
    final horizontalScroller = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
    );

    /// Get how far the page can be scrolled sideways.
    double sidewaysExtent(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(of: horizontalScroller, matching: find.byType(Scrollable)).first,
        )
        .position
        .maxScrollExtent;

    testWidgets("a page zoomed in wider than the area scrolls sideways", (tester) async {
      await _pumpEditor(
        tester,
        text: _longSource,
        zoom: 2,
        width: 700,
        isPageSimulationEnabled: true,
      );

      expect(sidewaysExtent(tester), greaterThan(0));
    });

    testWidgets("a page at 100 % is scaled down to a narrow area instead of scrolling", (
      tester,
    ) async {
      await _pumpEditor(tester, text: _longSource, width: 500, isPageSimulationEnabled: true);

      expect(sidewaysExtent(tester), 0);
    });

    testWidgets("a page that fits the area stays centred, with no scrolling", (tester) async {
      await _pumpEditor(tester, text: _longSource, zoom: 1.1, isPageSimulationEnabled: true);

      expect(sidewaysExtent(tester), 0);
    });

    for (final isPageSimulationEnabled in [true, false]) {
      final mode = isPageSimulationEnabled ? "with" : "without";

      testWidgets("the editor is not mounted again as the page starts to overflow, $mode page "
          "simulation", (tester) async {
        // Wide enough for 100 %, too narrow for 200 %, so the zoom crosses the overflow.
        await _pumpEditor(
          tester,
          text: _longSource,
          width: 1000,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );
        final state = tester.state(find.byType(OcptStyledScreenplayEditor));
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: find.byType(SuperEditor), matching: find.byType(Scrollable)).first,
        );
        scrollable.position.jumpTo(600);
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getCenter(find.byType(SuperEditor)) + const Offset(-100, 0));
        await tester.pumpAndSettle();
        final id = SuperEditorInspector.findDocumentSelection()!.extent.nodeId;

        await _pumpEditor(
          tester,
          text: _longSource,
          zoom: 2,
          width: 1000,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );
        expect(sidewaysExtent(tester), greaterThan(0));
        await _pumpEditor(
          tester,
          text: _longSource,
          width: 1000,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );

        // The same state all along, holding the same document, scrolled, with the same caret.
        expect(tester.state(find.byType(OcptStyledScreenplayEditor)), same(state));
        expect(SuperEditorInspector.findDocumentSelection()?.extent.nodeId, id);
        expect(
          tester
              .state<ScrollableState>(
                find
                    .descendant(of: find.byType(SuperEditor), matching: find.byType(Scrollable))
                    .first,
              )
              .position
              .pixels,
          greaterThan(0),
        );
      });
    }
  });

  group("scroll physics", () {
    /// Get the scroll physics chain of the editor's vertical scrollable, outermost first.
    List<ScrollPhysics> chain(WidgetTester tester) {
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: find.byType(SuperEditor), matching: find.byType(Scrollable)).first,
      );
      final physics = <ScrollPhysics>[];
      for (ScrollPhysics? next = scrollable.position.physics; next != null; next = next.parent) {
        physics.add(next);
      }

      return physics;
    }

    testWidgets("a surface where the page can't be zoomed keeps the platform's own scrolling", (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: _longSource,
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              isSpellCheckVisible: false,
              onTextChanged: (_) {},
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final physics = chain(tester);
        expect(physics.whereType<OcptZoomWheelPhysics>(), isEmpty);
        expect(physics.first, isA<BouncingScrollPhysics>());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets("where it can be zoomed, the platform's scrolling stays underneath", (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await _pumpEditor(tester, text: _longSource);

        final physics = chain(tester);
        expect(physics.first, isA<OcptZoomWheelPhysics>());
        expect(physics.whereType<BouncingScrollPhysics>(), isNotEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group("anchor", () {
    final manyPages = List.generate(500, (index) => "Action line $index.").join("\n\n");

    /// Get the vertical distance from the middle of the node [id]'s component to [point], or null
    /// while that node is not built.
    double? distanceFromMiddle(String id, Offset point) {
      double? distance;
      try {
        final top = SuperEditorInspector.findComponentOffset(id, Alignment.topLeft);
        final bottom = SuperEditorInspector.findComponentOffset(id, Alignment.bottomRight);
        distance = ((top.dy + bottom.dy) / 2 - point.dy).abs();
      } on Object {
        distance = null;
      }

      return distance;
    }

    /// Get the id of the built node whose component is nearest to [point], vertically.
    String nodeAtPoint(Offset point) {
      String? nearest;
      var nearestDistance = double.infinity;
      for (final node in SuperEditorInspector.findDocument()!) {
        final distance = distanceFromMiddle(node.id, point);
        if (distance != null && distance < nearestDistance) {
          nearest = node.id;
          nearestDistance = distance;
        }
      }

      return nearest!;
    }

    /// Get how far below the top of the node [id] [point] is, vertically.
    double distanceTo(String id, Offset point) =>
        point.dy - SuperEditorInspector.findComponentOffset(id, Alignment.topLeft).dy;

    for (final isPageSimulationEnabled in [true, false]) {
      final mode = isPageSimulationEnabled ? "with" : "without";

      testWidgets("the centre of the area stays put on a late page, $mode page simulation", (
        tester,
      ) async {
        await _pumpEditor(
          tester,
          text: manyPages,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: find.byType(SuperEditor), matching: find.byType(Scrollable)).first,
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent * 0.6);
        await tester.pumpAndSettle();
        final centre = tester.getCenter(find.byType(SuperEditor));
        final id = nodeAtPoint(centre);
        final before = distanceTo(id, centre);

        await _pumpEditor(
          tester,
          text: manyPages,
          zoom: 2,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );

        // The same line is under the centre, and about as far down its own box as before (scaled).
        expect(distanceTo(id, centre), closeTo(before * 2, 40));
      });

      testWidgets("the pointer's point stays put on a late page, $mode page simulation", (
        tester,
      ) async {
        final steps = await _pumpEditor(
          tester,
          text: manyPages,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: find.byType(SuperEditor), matching: find.byType(Scrollable)).first,
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent * 0.6);
        await tester.pumpAndSettle();
        final pointer = tester.getCenter(find.byType(SuperEditor)) + const Offset(0, -250);
        final id = nodeAtPoint(pointer);
        final before = distanceTo(id, pointer);

        // Not settled: the zoom the bloc would apply arrives in the very frame the step asked for.
        await _wheel(tester, pointer, const Offset(0, -100), withCtrl: true, settles: false);
        expect(steps, [1]);
        await _pumpEditor(
          tester,
          text: manyPages,
          zoom: 2,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );

        expect(distanceTo(id, pointer), closeTo(before * 2, 40));
      });

      testWidgets("the caret stays put when it is in view, $mode page simulation", (tester) async {
        await _pumpEditor(
          tester,
          text: manyPages,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: find.byType(SuperEditor), matching: find.byType(Scrollable)).first,
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent * 0.6);
        await tester.pumpAndSettle();
        // A line well above the centre, so the caret is not where the centre is.
        final point = tester.getCenter(find.byType(SuperEditor)) + const Offset(0, -250);
        final id = nodeAtPoint(point);
        await tester.placeCaretInParagraph(id, 3);
        await tester.pumpAndSettle();
        final before = SuperEditorInspector.findComponentOffset(id, Alignment.topLeft).dy;

        await _pumpEditor(
          tester,
          text: manyPages,
          zoom: 2,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );

        expect(
          SuperEditorInspector.findComponentOffset(id, Alignment.topLeft).dy,
          closeTo(before, 40),
        );
      });
    }

    for (final isPageSimulationEnabled in [true, false]) {
      final mode = isPageSimulationEnabled ? "with" : "without";

      testWidgets("keeps the centre of a narrow area put while the page is scaled down, $mode "
          "page simulation", (tester) async {
        // Narrower than a sheet: at 100 % or less it is scaled down to fit, so what is drawn is
        // not what is laid out, and the scroll offset is in the latter.
        await _pumpEditor(
          tester,
          text: manyPages,
          zoom: 0.75,
          width: 560,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: find.byType(SuperEditor), matching: find.byType(Scrollable)).first,
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent * 0.6);
        await tester.pumpAndSettle();
        final centre = tester.getCenter(find.byType(SuperEditor));
        final id = nodeAtPoint(centre);
        final before = distanceTo(id, centre);

        await _pumpEditor(
          tester,
          text: manyPages,
          zoom: 0.9,
          width: 560,
          isPageSimulationEnabled: isPageSimulationEnabled,
        );

        // A scaled-down sheet is drawn at the same size at any zoom; a fluid page is not.
        expect(
          distanceTo(id, centre),
          closeTo(isPageSimulationEnabled ? before : before * 1.2, 12),
        );
      });
    }

    test("walks the sheets: the gap between two of them does not scale", () {
      final actual = OcptEditorPreviewLayout(metrics: metrics);
      final zoomed = OcptEditorPreviewLayout(metrics: metrics, zoom: 1.1);

      // A point 60 sheets down, a little below the top of the sheet.
      final sheet = actual.pageHeight + OcptEditorPreviewLayout.pageGap;
      final y = 60 * sheet + 100;
      final target = OcptStyledZoomAnchor.verticalTargetOf(
        offset: y - 300,
        focal: 300,
        oldLayout: actual,
        newLayout: zoomed,
        hasSheets: true,
      );

      // The point is still 100 below the top of its sheet, at the new scale, on the same sheet.
      final newSheet = zoomed.pageHeight + OcptEditorPreviewLayout.pageGap;
      expect(
        target + 300,
        closeTo(60 * newSheet + 100 * zoomed.pageHeight / actual.pageHeight, 1e-6),
      );
      // What a plain ratio would give is a gap per sheet off.
      final plain = y * zoomed.pageHeight / actual.pageHeight;
      expect(
        (plain - (target + 300)).abs(),
        greaterThan(60 * OcptEditorPreviewLayout.pageGap * 0.05),
      );
    });

    test("scales the whole content when there are no sheets", () {
      final actual = OcptEditorPreviewLayout(metrics: metrics);
      final zoomed = OcptEditorPreviewLayout(metrics: metrics, zoom: 2);

      expect(
        OcptStyledZoomAnchor.verticalTargetOf(
          offset: 1000,
          focal: 200,
          oldLayout: actual,
          newLayout: zoomed,
          hasSheets: false,
        ),
        closeTo(1200 * 2 - 200, 1),
      );
    });

    testWidgets("a pointer position left by a step that changed nothing is not kept", (
      tester,
    ) async {
      final anchor = OcptStyledZoomAnchor(
        vertical: ScrollController(),
        layoutKey: GlobalKey(),
        selectionOf: () => null,
      );
      addTearDown(anchor.dispose);
      var steps = 0;
      final callback = anchor.wheelCallback((direction) => steps++)!;

      callback(1, const Offset(10, 20));
      expect(anchor.focal, const Offset(10, 20));
      expect(steps, 1);

      // Nothing was zoomed, so nothing consumed it: the next frame drops it.
      await tester.pump();
      await tester.pump();
      expect(anchor.focal, isNull);
    });
  });

  group("undo and redo", () {
    final manyPages = List.generate(200, (index) => "Action line $index.").join("\n\n");

    /// Type a few characters at the start of the first body line and wait for the settle.
    Future<void> typeAtStart(WidgetTester tester) async {
      final document = SuperEditorInspector.findDocument()!;
      final first = document.firstWhere(
        (node) => node is ParagraphNode && node.text.toPlainText().startsWith("Action line 0"),
      );
      // The title sheet comes first under page simulation: bring the line into view.
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: find.byType(SuperEditor), matching: find.byType(Scrollable)).first,
      );
      scrollable.position.jumpTo(
        scrollable.position.pixels +
            SuperEditorInspector.findComponentOffset(first.id, Alignment.topLeft).dy -
            200,
      );
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph(first.id, 0);
      await tester.typeImeText("Typed ");
      await pumpPastSettleDebounce(tester);
    }

    /// Get the text of the first body line.
    String firstLine() => SuperEditorInspector.findDocument()!
        .firstWhere((node) => node is ParagraphNode && node.text.toPlainText().contains("line 0"))
        .asTextNode
        .text
        .toPlainText();

    testWidgets("a zoom between an undo and a redo leaves the redo available", (tester) async {
      await _pumpEditor(tester, text: manyPages, isPageSimulationEnabled: true);
      await typeAtStart(tester);
      expect(firstLine(), startsWith("Typed "));

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      expect(firstLine(), isNot(startsWith("Typed ")));

      await _pumpEditor(tester, text: manyPages, zoom: 1.5, isPageSimulationEnabled: true);
      await pumpPastSettleDebounce(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await pumpPastSettleDebounce(tester);

      expect(firstLine(), startsWith("Typed "));
    });

    testWidgets("an undo after a zoom never shows page breaks at the old size", (tester) async {
      final layout = OcptEditorPreviewLayout(metrics: metrics, zoom: 2);
      await _pumpEditor(tester, text: manyPages, isPageSimulationEnabled: true);
      await typeAtStart(tester);

      await _pumpEditor(tester, text: manyPages, zoom: 2, isPageSimulationEnabled: true);
      await pumpPastSettleDebounce(tester);
      final document = SuperEditorInspector.findDocument()!;
      final stored = [
        for (final node in document)
          if ((node.getMetadataValue("ocptStartsNewPage") as Object?) case final double value
              when value != 0)
            value,
      ];
      expect(stored, isNotEmpty);

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      // Only a frame: the debounced repagination has not run yet.
      await tester.pump();

      // What is stored does not depend on the zoom: it is never a pixel amount of the old size,
      // and rendering it at the new one is the page break the new pagination wants.
      for (final node in SuperEditorInspector.findDocument()!) {
        final value = node.getMetadataValue("ocptStartsNewPage");
        if (value is double && value != 0) {
          expect(stored.any((kept) => (kept - value).abs() < 1e-6), isTrue);
          expect(ocptPageStartPaddingOf(value, layout), lessThan(layout.pageHeight));
        }
      }
    });
  });

  group("caret", () {
    final horizontalScroller = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
    );

    /// Get the horizontal scroll offset of the zoomed page.
    double horizontalOffset(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(of: horizontalScroller, matching: find.byType(Scrollable)).first,
        )
        .position
        .pixels;

    testWidgets("is followed sideways when the page is wider than the area", (tester) async {
      const line = "A line of action that fits its box but not a narrow area";
      await _pumpEditor(tester, text: line, zoom: 2, width: 700);
      final id = SuperEditorInspector.findDocument()!.getNodeAt(0)!.id;
      expect(horizontalOffset(tester), 0);

      // The end of the line is off to the right: typing brings it into view.
      await tester.placeCaretInParagraph(id, 0);
      // Walk right along the line, the way typing does.
      for (var step = 0; step < line.length; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final scrolled = horizontalOffset(tester);
      expect(scrolled, greaterThan(0));

      // And back along the line, the left of the page is back in view.
      for (var step = 0; step < line.length; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(horizontalOffset(tester), lessThan(scrolled));
    });

    testWidgets("is followed to a find match on the right half of a line", (tester) async {
      const line = "A line of action that fits its box but not a narrow area";
      final controller = OcptStyledEditorController();
      await _pumpEditor(tester, text: line, zoom: 2, width: 700, styledController: controller);
      expect(horizontalOffset(tester), 0);

      controller.updateSearch(
        query: const OcptEditorSearchQuery(
          query: "narrow area",
          isCaseSensitive: false,
          isWholeWord: false,
        ),
        currentMatchIndex: 0,
      );
      await tester.pumpAndSettle();

      expect(horizontalOffset(tester), greaterThan(0));
    });
  });
}
