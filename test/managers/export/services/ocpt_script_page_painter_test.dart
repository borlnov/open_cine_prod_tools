// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts_loader.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';

/// Run the tests of [OcptScriptPagePainter].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const parser = FountainParser();
  const composer = FountainScriptComposer();
  final metrics = FountainLayoutMetrics.usLetter();

  late OcptScriptPagePainter painter;

  setUpAll(() async {
    painter = OcptScriptPagePainter(
      metrics: metrics,
      fonts: await OcptCourierPrimeFontsLoader().load(),
    );
  });

  /// The single printed line of [source] whose text is [text].
  FountainScriptLine lineOf(String source, String text) {
    final layout = composer.compose(document: parser.parse(source), metrics: metrics);
    return layout.pages
        .expand((page) => page.lines)
        .firstWhere((line) => line.plainText.trim() == text);
  }

  group("geometry", () {
    test("a row's top is the top margin plus its own share of the line grid", () {
      expect(painter.rowTopPt(0), painter.marginTopPt);
      expect(painter.rowTopPt(3), painter.marginTopPt + 3 * painter.lineHeightPt);
      // 6 lines per inch at 12pt, the pitch the pagination itself is built on.
      expect(painter.lineHeightPt, 12);
    });

    test("a column is as wide as the pitch the composer wrapped the text to", () {
      expect(painter.columnWidthPt, ocptPdfPointsPerInch / metrics.charsPerInch);
    });

    test("a line's box is exactly as wide as the columns its element was wrapped to", () {
      expect(
        painter.lineBoxWidthPt(FountainLineType.action),
        metrics.action.maxWidthColumns * painter.columnWidthPt,
      );
      expect(
        painter.lineBoxWidthPt(FountainLineType.dialogue),
        metrics.dialogue.maxWidthColumns * painter.columnWidthPt,
      );
    });
  });

  group("columnLeftPt", () {
    test("a left-aligned line starts at its element's own indent", () {
      final line = lineOf("INT. HOUSE - DAY\n\nAn action line.\n", "An action line.");

      expect(line.alignment, FountainLayoutAlignment.left);
      expect(
        painter.columnLeftPt(line: line, column: 0),
        closeTo(line.leftIndentInches * ocptPdfPointsPerInch, 0.001),
      );
    });

    test("a column of a left-aligned line is that many columns further right", () {
      final line = lineOf("INT. HOUSE - DAY\n\nAn action line.\n", "An action line.");

      expect(
        painter.columnLeftPt(line: line, column: 3) - painter.columnLeftPt(line: line, column: 0),
        closeTo(3 * painter.columnWidthPt, 0.001),
      );
    });

    test("a centered line's text is centered in its box, not flush with its indent", () {
      final line = lineOf("> Centered text <\n", "Centered text");
      final boxLeftPt = line.leftIndentInches * ocptPdfPointsPerInch;
      final boxWidthPt = painter.lineBoxWidthPt(line.lineType);
      final textWidthPt = line.plainText.length * painter.columnWidthPt;

      expect(line.alignment, FountainLayoutAlignment.center);
      expect(
        painter.columnLeftPt(line: line, column: 0),
        closeTo(boxLeftPt + (boxWidthPt - textWidthPt) / 2, 0.001),
      );
    });

    test("a right-aligned line ends flush with the right edge of its box", () {
      final line = lineOf("INT. HOUSE - DAY\n\nAction.\n\n> FADE OUT.\n", "FADE OUT.");
      final boxLeftPt = line.leftIndentInches * ocptPdfPointsPerInch;
      final boxWidthPt = painter.lineBoxWidthPt(line.lineType);

      expect(line.alignment, FountainLayoutAlignment.right);
      expect(
        painter.columnLeftPt(line: line, column: line.plainText.length),
        closeTo(boxLeftPt + boxWidthPt, 0.001),
      );
    });
  });

  group("dual dialogue", () {
    const source =
        "INT. HOUSE - DAY\n\n"
        "ROSS\nShort.\n\n"
        "KIM ^\nA much longer reply that has to wrap onto several rows of its own column.\n";

    /// The rows of [source] that are part of a pair.
    List<FountainScriptLine> pairRows() {
      final layout = composer.compose(document: parser.parse(source), metrics: metrics);
      return [
        for (final page in layout.pages)
          for (final line in page.lines)
            if (line.dualSide != null) line,
      ];
    }

    test("a column's box is as wide as the columns its cell was wrapped to", () {
      final dualMetrics = metrics.dualDialogue!;
      final rows = pairRows();
      final left = rows.first;
      final right = rows.first.dualCompanion!;

      expect(
        painter.lineBoxWidthPt(left.lineType, side: left.dualSide),
        dualMetrics.elementOf(FountainDualDialogueSide.left, left.lineType)!.maxWidthColumns *
            painter.columnWidthPt,
      );
      expect(
        painter.lineBoxWidthPt(right.lineType, side: right.dualSide),
        dualMetrics.elementOf(FountainDualDialogueSide.right, right.lineType)!.maxWidthColumns *
            painter.columnWidthPt,
      );
      expect(
        painter.lineBoxWidthPt(left.lineType, side: left.dualSide),
        lessThan(painter.lineBoxWidthPt(left.lineType)),
      );
    });

    test("the right cell starts further right than the left one, at its own indent", () {
      final row = pairRows().first;
      final right = row.dualCompanion!;

      expect(
        painter.columnLeftPt(line: right, column: 0),
        closeTo(right.leftIndentInches * ocptPdfPointsPerInch, 0.001),
      );
      expect(
        painter.columnLeftPt(line: right, column: 0),
        greaterThan(painter.columnLeftPt(line: row, column: 0)),
      );
    });

    test("a row whose left column is exhausted carries a blank left cell", () {
      final blank = pairRows().firstWhere((row) => row.runs.isEmpty);

      expect(blank.dualCompanion, isNotNull);
      expect(blank.dualCompanion!.runs, isNotEmpty);
    });

    test("a page holding a pair builds, blank left cell included", () {
      final layout = composer.compose(document: parser.parse(source), metrics: metrics);

      expect(
        () => painter.buildScriptPage(
          page: layout.pages.first,
          pageNumber: 1,
          includeSceneNumbers: false,
        ),
        returnsNormally,
      );
    });
  });
}
