// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_block.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// The two members of a short pair: one line of dialogue each.
const _shortPair = "BOB\nHello there.\n\nALICE^\nHi back.";

/// Wrap [child] in a [MaterialApp] and a [width]x[height] box, top-left aligned.
Widget _wrap(Widget child, {required double width, required double height}) => MaterialApp(
  theme: ocpt_theme.ocptTheme.lightThemeData,
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, height: height, child: child),
  ),
);

/// Pump the preview of [source] in a panel of [height] tall, wide enough for the unscaled page.
Future<void> _pumpPreview(
  WidgetTester tester,
  String source, {
  required double panelWidth,
  required double height,
  bool isPageSimulationEnabled = false,
  int currentLine = 0,
  OcptPageSetup pageSetup = const OcptPageSetup.standard(),
}) async {
  tester.view.physicalSize = Size(panelWidth + 200, height + 100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _wrap(
      OcptEditorPreview(
        document: const FountainParser().parse(source),
        pageSetup: pageSetup,
        currentLine: currentLine,
        isPageSimulationEnabled: isPageSimulationEnabled,
      ),
      width: panelWidth,
      height: height,
    ),
  );
  await tester.pumpAndSettle();
}

/// Run the tests of the preview's dual dialogue.
void main() {
  final metrics = FountainLayoutMetrics.usLetter();
  final layout = OcptEditorPreviewLayout(metrics: metrics);
  final panelWidth = layout.pageWidth + 32;
  final dual = metrics.dualDialogue!;

  List<FountainBlock> blocksOf(String source) =>
      OcptEditorPreviewLayout.printableBlocks(const FountainParser().parse(source));

  List<OcptEditorPreviewItem> itemsOf(String source) =>
      layout.groupItems(const FountainParser().parse(source));

  group("OcptEditorPreviewLayout dual dialogue", () {
    test("a pair is one item, the right member's index kept", () {
      final items = itemsOf("Action.\n\n$_shortPair");

      expect(items, hasLength(2));
      expect(items[1].blockIndex, 1);
      expect(items[1].rightBlockIndex, 2);
      expect(items[1].rightBlock, isNotNull);
    });

    test("a pair is estimated as the taller of its two columns", () {
      final longText = List.filled(12, "word").join(" ");
      final items = itemsOf("BOB\nShort.\n\nALICE^\n$longText");

      expect(items, hasLength(1));
      final rightLines =
          1 +
          OcptEditorPreviewLayout.wrappedLineCount(longText, dual.rightDialogue.maxWidthColumns);
      expect(layout.estimatedItemLineCount(items.single), rightLines);
      expect(rightLines, greaterThan(2));
      expect(
        layout.estimateItemHeight(items.single),
        rightLines * layout.lineHeight + layout.blockSpacing,
      );
    });

    test("each column is wrapped at its own width, narrower than an ordinary dialogue", () {
      final text = List.filled(12, "aaaa").join(" ");
      final items = itemsOf("BOB\n$text\n\nALICE^\nOk.");
      final block = blocksOf("BOB\n$text").single;

      expect(
        layout.estimatedItemLineCount(items.single),
        greaterThan(layout.estimatedLineCount(block)),
      );
    });

    test("an orphan ^ stays an item of its own", () {
      final items = itemsOf("Action.\n\nALICE^\nHi back.");

      expect(items, hasLength(2));
      expect(items.every((item) => item.rightBlock == null), isTrue);
    });

    test("a page without room for two columns stacks the pair", () {
      final narrow = OcptEditorPreviewLayout(
        metrics: FountainLayoutMetrics.usLetter(
          margins: const FountainPageMargins(
            leftInches: 2.5,
            rightInches: 2.5,
            topInches: 1,
            bottomInches: 1,
          ),
        ),
      );

      expect(narrow.metrics.dualDialogue, isNull);
      expect(narrow.groupItems(const FountainParser().parse(_shortPair)), hasLength(2));
    });

    test("a pair taller than a page is stacked", () {
      final tallText = List.filled(400, "word").join(" ");
      final items = itemsOf("BOB\n$tallText\n\nALICE^\nHi.");

      expect(items, hasLength(2));
      expect(items.every((item) => item.rightBlock == null), isTrue);
    });

    test("a block that is never printed between two speeches breaks the pair", () {
      for (final between in ["[[note]]", "# Act", "= synopsis", "/* bone */"]) {
        for (final gap in ["\n\n", "\n"]) {
          final source = "ROSS\nHello.\n\n$between${gap}KIM^\nHi.\n";
          expect(itemsOf(source).where((item) => item.rightBlock != null), isEmpty, reason: source);
        }
      }
    });

    test("the composer and the preview pair the same speeches", () {
      List<String> composerPairs(String source) {
        final layout = const FountainScriptComposer().compose(
          document: const FountainParser().parse(source),
          metrics: metrics,
        );
        return [
          for (final page in layout.pages)
            for (final row in page.lines)
              if (row.dualCompanion != null && row.lineType == FountainLineType.character)
                row.dualCompanion!.plainText,
        ];
      }

      List<String> previewPairs(String source) => [
        for (final item in itemsOf(source))
          if (item.rightBlock != null) item.rightBlock!.character.name.toUpperCase(),
      ];

      final sources = [
        for (final file in Directory("packages/fountain_kit/test/corpus").listSync())
          if (file is File && file.path.endsWith(".fountain")) file.readAsStringSync(),
        "ROSS\nA.\n[[note]]\n\nKIM^\nHi.\n",
        for (final between in ["[[note]]", "# Act", "= syn", "/* bone */"])
          for (final gap in ["\n\n", "\n"]) "ROSS\nA.\n\n$between${gap}KIM^\nHi.\n",
        "ROSS\nA.\n\nKIM^\nHi.\n",
      ];
      for (final source in sources) {
        expect(previewPairs(source), composerPairs(source), reason: source);
      }
      expect(composerPairs(sources.last), ["KIM"]);
    });

    test("a script without dual dialogue keeps every block as an item of its own", () {
      const source = "Action.\n\nBOB\nHello.\n\nALICE\nHi.";

      expect(itemsOf(source), hasLength(blocksOf(source).length));
    });
  });

  group("OcptEditorPreview dual dialogue", () {
    testWidgets("a pair renders two columns at their own indents, cues without the ^", (
      tester,
    ) async {
      await _pumpPreview(tester, _shortPair, panelWidth: panelWidth, height: 600);

      final pageLeft = tester.getTopLeft(find.byType(Material).first).dx;
      expect(find.text("ALICE"), findsOneWidget);
      expect(find.textContaining("^"), findsNothing);
      expect(
        tester.getTopLeft(find.text("Hello there.")).dx - pageLeft,
        closeTo(layout.indentOf(dual.leftDialogue), 0.5),
      );
      expect(
        tester.getTopLeft(find.text("Hi back.")).dx - pageLeft,
        closeTo(layout.indentOf(dual.rightDialogue), 0.5),
      );
      expect(
        tester.getTopLeft(find.text("BOB")).dx - pageLeft,
        closeTo(layout.indentOf(dual.leftCharacter), 0.5),
      );
      expect(
        tester.getTopLeft(find.text("ALICE")).dx - pageLeft,
        closeTo(layout.indentOf(dual.rightCharacter), 0.5),
      );
      expect(
        tester.getTopLeft(find.text("Hi back.")).dy,
        tester.getTopLeft(find.text("Hello there.")).dy,
      );
    });

    testWidgets("a pair is as tall as its taller column", (tester) async {
      final longText = List.filled(12, "word").join(" ");
      final source = "BOB\nShort.\n\nALICE^\n$longText";
      await _pumpPreview(tester, source, panelWidth: panelWidth, height: 600);

      final item = itemsOf(source).single;
      final blockSize = tester.getSize(find.byType(OcptEditorPreviewBlock));

      expect(blockSize.height, closeTo(layout.estimateItemHeight(item), 2));
    });

    testWidgets("a pair that does not fit the bottom of a page moves whole to the next", (
      tester,
    ) async {
      // Leave one free line on the first page: a pair needs a separator and two rows.
      final actions = metrics.linesPerPage ~/ 2;
      final source =
          "${List.generate(actions, (index) => "Action $index.").join("\n\n")}\n\n$_shortPair";
      final tallHeight = layout.pageHeight * 2 + 200;
      await _pumpPreview(
        tester,
        source,
        panelWidth: panelWidth,
        height: tallHeight,
        isPageSimulationEnabled: true,
      );

      final sheets = find.byType(Material);
      expect(sheets, findsNWidgets(2));
      final secondSheet = tester.getRect(sheets.at(1));
      for (final text in ["BOB", "ALICE", "Hello there.", "Hi back."]) {
        expect(secondSheet.contains(tester.getTopLeft(find.text(text))), isTrue, reason: text);
      }
      expect(secondSheet.contains(tester.getTopLeft(find.text("Action ${actions - 1}."))), isFalse);
    });

    testWidgets("a scene heading ending the page moves with the pair", (tester) async {
      // 26 actions and the heading leave one free line, where a pair needs three.
      final source =
          "${List.generate(26, (index) => "Action $index.").join("\n\n")}\n\n"
          "INT. ROOM - DAY\n\n$_shortPair";
      await _pumpPreview(
        tester,
        source,
        panelWidth: panelWidth,
        height: layout.pageHeight * 2 + 200,
        isPageSimulationEnabled: true,
      );

      final sheets = find.byType(Material);
      expect(sheets, findsNWidgets(2));
      final secondSheet = tester.getRect(sheets.at(1));
      for (final text in ["INT. ROOM - DAY", "BOB", "ALICE"]) {
        expect(secondSheet.contains(tester.getTopLeft(find.text(text))), isTrue, reason: text);
      }
    });

    testWidgets("a pair taller than a page is stacked at the ordinary dialogue indent", (
      tester,
    ) async {
      final tallText = List.filled(400, "word").join(" ");
      final source = "BOB\nLeft side.\n\nALICE^\n$tallText";
      await _pumpPreview(tester, source, panelWidth: panelWidth, height: 600);

      final pageLeft = tester.getTopLeft(find.byType(Material).first).dx;
      expect(
        tester.getTopLeft(find.text("Left side.")).dx - pageLeft,
        closeTo(layout.indentOf(metrics.dialogue), 0.5),
      );
      expect(
        tester.getTopLeft(find.text("ALICE")).dy,
        greaterThan(tester.getTopLeft(find.text("Left side.")).dy),
      );
    });

    testWidgets("an orphan ^ renders as an ordinary dialogue", (tester) async {
      await _pumpPreview(tester, "ALICE^\nHi back.", panelWidth: panelWidth, height: 600);

      final pageLeft = tester.getTopLeft(find.byType(Material).first).dx;
      expect(find.text("ALICE"), findsOneWidget);
      expect(
        tester.getTopLeft(find.text("Hi back.")).dx - pageLeft,
        closeTo(layout.indentOf(metrics.dialogue), 0.5),
      );
    });

    testWidgets("the caret on either member scrolls to the same place", (tester) async {
      final source =
          "${List.generate(40, (index) => "Action $index.").join("\n\n")}\n\n$_shortPair";
      final document = const FountainParser().parse(source);
      final pair = layout.groupItems(document).last;
      final leftLine = pair.block.sourceRange.startLine;
      final rightLine = pair.rightBlock!.sourceRange.startLine;

      Future<double> scrolledTo(int line) async {
        await _pumpPreview(tester, source, panelWidth: panelWidth, height: 400);
        await tester.pumpWidget(
          _wrap(
            OcptEditorPreview(
              document: document,
              pageSetup: const OcptPageSetup.standard(),
              currentLine: line,
              isPageSimulationEnabled: false,
            ),
            width: panelWidth,
            height: 400,
          ),
        );
        await tester.pumpAndSettle();

        return tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
      }

      final left = await scrolledTo(leftLine);
      final right = await scrolledTo(rightLine);

      expect(left, greaterThan(0));
      expect(right, closeTo(left, 0.01));
    });
  });
}
