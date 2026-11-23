// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_pagination.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
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
Future<void> _wheel(WidgetTester tester, Offset at, Offset delta, {required bool withCtrl}) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(at));
  if (withCtrl) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  }
  await tester.sendEventToBinding(pointer.scroll(delta));
  if (withCtrl) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
  await tester.pumpAndSettle();
}

/// Run the tests of the styled editor's page zoom.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  final metrics = FountainLayoutMetrics.usLetter();

  group("pagination", () {
    test("splits the pages at the same nodes at 50 %, 100 % and 200 %", () {
      final reference = computeOcptStyledPagination(
        document: OcptWysiwygCodec.decode(_longSource).document,
        metrics: metrics,
      );
      expect(reference.pageCount, greaterThan(1));

      for (final zoom in [0.5, 1.0, 2.0]) {
        final document = OcptWysiwygCodec.decode(_longSource).document;
        final pagination = computeOcptStyledPagination(
          document: document,
          metrics: metrics,
          zoom: zoom,
        );

        expect(pagination.pageCount, reference.pageCount, reason: "zoom $zoom");
        expect(pagination.pageStartNodeIds.length, reference.pageStartNodeIds.length);
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

    testWidgets("a page zoomed in wider than the area scrolls sideways", (tester) async {
      await _pumpEditor(
        tester,
        text: _longSource,
        zoom: 2,
        width: 700,
        isPageSimulationEnabled: true,
      );

      expect(horizontalScroller, findsOneWidget);
    });

    testWidgets("a page at 100 % is scaled down to a narrow area instead of scrolling", (
      tester,
    ) async {
      await _pumpEditor(tester, text: _longSource, width: 500, isPageSimulationEnabled: true);

      expect(horizontalScroller, findsNothing);
    });

    testWidgets("a page that fits the area stays centred, with no scrolling", (tester) async {
      await _pumpEditor(tester, text: _longSource, zoom: 1.1, isPageSimulationEnabled: true);

      expect(horizontalScroller, findsNothing);
    });
  });
}
