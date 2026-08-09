// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';

/// A neutral element layout box: only [FountainLayoutMetrics.linesPerPage] matters to this layout,
/// so every element box below is the same harmless placeholder.
const FountainElementLayout _box = FountainElementLayout(
  leftIndentInches: 0,
  leftIndentColumns: 0,
  maxWidthInches: 1,
  maxWidthColumns: 1,
  alignment: FountainLayoutAlignment.left,
);

/// Builds metrics whose own [FountainLayoutMetrics.linesPerPage] is [linesPerPage] and nothing else
/// about them is read by this layout — the standard US Letter preset's own page geometry would work
/// just as well, but a small, explicit count is what makes the overflow test's arithmetic legible.
FountainLayoutMetrics _metrics(int linesPerPage) => FountainLayoutMetrics(
  pageWidthInches: 8.5,
  pageHeightInches: 11,
  marginLeftInches: 1.5,
  marginRightInches: 1,
  marginTopInches: 1,
  marginBottomInches: 1,
  charsPerInch: 10,
  linesPerInch: 6,
  linesPerPage: linesPerPage,
  sceneHeading: _box,
  action: _box,
  character: _box,
  parenthetical: _box,
  dialogue: _box,
  transition: _box,
  centeredText: _box,
  lyrics: _box,
);

/// An ordinary, anchored line of action text printed from `[start, end)` of the screenplay's own
/// source, tagged with [tag] so a test can tell two otherwise-identical lines apart at a glance.
FountainScriptLine _line(String tag, {required int start, required int end}) => FountainScriptLine(
  runs: [
    FountainStyledRun(
      text: tag,
      sourceRange: FountainSourceRange(startLine: 0, endLine: 0, startOffset: start, endOffset: end),
    ),
  ],
  lineType: FountainLineType.action,
  leftIndentInches: 0,
  alignment: FountainLayoutAlignment.left,
  isSceneHeading: false,
);

/// A synthetic `(MORE)` line, carrying no source range at all — the kind of row the bridge rule
/// must pull into a scene without ever being able to test it against the scene's own span.
const FountainScriptLine _moreLine = FountainScriptLine(
  runs: [FountainStyledRun(text: "(MORE)")],
  lineType: FountainLineType.parenthetical,
  leftIndentInches: 0,
  alignment: FountainLayoutAlignment.left,
  isSceneHeading: false,
  isSynthetic: true,
);

/// A generic blank spacer line, the one every real screenplay carries between two blocks — built
/// from exactly the fields [OcptScriptSidesLayout] fills its own gaps with, on purpose: a test
/// relying on distinguishing the two by value alone would be testing the wrong thing.
const FountainScriptLine _blank = FountainScriptLine(
  runs: [],
  lineType: FountainLineType.blank,
  leftIndentInches: 0,
  alignment: FountainLayoutAlignment.left,
  isSceneHeading: false,
);

/// A one-page script holding exactly [lines].
FountainScriptLayout _onePageScript(List<FountainScriptLine> lines) =>
    FountainScriptLayout(pages: [FountainScriptPage(lines: lines)]);

void main() {
  group("a single scene wholly inside one page", () {
    // Page: [row0 (outside), row1 (in span), row2 (in span), row3 (outside), row4 (outside)].
    final script = _onePageScript([
      _line("row0", start: 0, end: 5),
      _line("row1", start: 10, end: 15),
      _line("row2", start: 20, end: 25),
      _line("row3", start: 30, end: 35),
      _line("row4", start: 40, end: 45),
    ]);
    const span = (charStart: 10, charEnd: 25);

    test("scriptPages keeps the page's own row indices, blanking what is not selected", () {
      final layout = OcptScriptSidesLayout.of(
        script: script,
        sceneSpans: const [span],
        metrics: _metrics(54),
        presentation: OcptSidesPresentation.scriptPages,
      );

      expect(layout.pages, hasLength(1));
      expect(layout.pages.single.scriptPageIndex, 0);
      // row0 is not selected but sits before the last selected row, so it survives as a blank
      // filler at its own true index; row3/row4 are trailing and dropped outright.
      expect(layout.pages.single.lines, [_blank, script.pages[0].lines[1], script.pages[0].lines[2]]);
    });

    test("packed keeps only the selected rows, contiguous", () {
      final layout = OcptScriptSidesLayout.of(
        script: script,
        sceneSpans: const [span],
        metrics: _metrics(54),
        presentation: OcptSidesPresentation.packed,
      );

      expect(layout.pages, hasLength(1));
      expect(layout.pages.single.scriptPageIndex, isNull);
      expect(layout.pages.single.lines, [script.pages[0].lines[1], script.pages[0].lines[2]]);
    });
  });

  group("a scene spanning a page break", () {
    // Page 0: [row0 (outside), row1 (outside), row2 (in span)].
    // Page 1: [row0 (in span), row1 (outside), row2 (outside)].
    final script = FountainScriptLayout(
      pages: [
        FountainScriptPage(
          lines: [
            _line("p0-row0", start: 0, end: 5),
            _line("p0-row1", start: 10, end: 15),
            _line("p0-row2", start: 20, end: 25),
          ],
        ),
        FountainScriptPage(
          lines: [
            _line("p1-row0", start: 30, end: 35),
            _line("p1-row1", start: 40, end: 45),
            _line("p1-row2", start: 50, end: 55),
          ],
        ),
      ],
    );
    const span = (charStart: 20, charEnd: 35);

    test("scriptPages gives two pages", () {
      final layout = OcptScriptSidesLayout.of(
        script: script,
        sceneSpans: const [span],
        metrics: _metrics(54),
        presentation: OcptSidesPresentation.scriptPages,
      );

      expect(layout.pages, hasLength(2));
      expect(layout.pages[0].scriptPageIndex, 0);
      expect(layout.pages[0].lines, [_blank, _blank, script.pages[0].lines[2]]);
      expect(layout.pages[1].scriptPageIndex, 1);
      expect(layout.pages[1].lines, [script.pages[1].lines[0]]);
    });

    test("packed keeps the two rows contiguous, with no separator between them", () {
      final layout = OcptScriptSidesLayout.of(
        script: script,
        sceneSpans: const [span],
        metrics: _metrics(54),
        presentation: OcptSidesPresentation.packed,
      );

      expect(layout.pages, hasLength(1));
      expect(layout.pages.single.lines, [script.pages[0].lines[2], script.pages[1].lines[0]]);
    });
  });

  group("two scenes on one script page with unselected rows between them", () {
    // [row0 (scene A), row1 (gap), row2 (gap), row3 (scene B), row4 (trailing, outside both)].
    final script = _onePageScript([
      _line("row0", start: 0, end: 5),
      _line("row1", start: 10, end: 15),
      _line("row2", start: 20, end: 25),
      _line("row3", start: 30, end: 35),
      _line("row4", start: 40, end: 45),
    ]);
    const sceneA = (charStart: 0, charEnd: 5);
    const sceneB = (charStart: 30, charEnd: 35);

    test("scriptPages gives one page whose gap rows are blank fillers at their true indices", () {
      final layout = OcptScriptSidesLayout.of(
        script: script,
        sceneSpans: const [sceneA, sceneB],
        metrics: _metrics(54),
        presentation: OcptSidesPresentation.scriptPages,
      );

      expect(layout.pages, hasLength(1));
      expect(layout.pages.single.lines, [
        script.pages[0].lines[0],
        _blank,
        _blank,
        script.pages[0].lines[3],
      ]);
    });

    test("packed gives one separator row between the two runs", () {
      final layout = OcptScriptSidesLayout.of(
        script: script,
        sceneSpans: const [sceneA, sceneB],
        metrics: _metrics(54),
        presentation: OcptSidesPresentation.packed,
      );

      expect(layout.pages, hasLength(1));
      expect(layout.pages.single.lines, [script.pages[0].lines[0], _blank, script.pages[0].lines[3]]);
    });
  });

  test("the bridge rule pulls an unanchored row between two anchored ones into the scene", () {
    // row0 and row2 are anchored inside the span; row1 (the synthetic (MORE) token) carries no
    // source range at all and can only be reached by bridging between the two rows around it.
    final script = _onePageScript([_line("row0", start: 0, end: 5), _moreLine, _line("row2", start: 5, end: 10)]);
    const span = (charStart: 0, charEnd: 10);

    final scriptPages = OcptScriptSidesLayout.of(
      script: script,
      sceneSpans: const [span],
      metrics: _metrics(54),
      presentation: OcptSidesPresentation.scriptPages,
    );
    expect(scriptPages.pages.single.lines, [script.pages[0].lines[0], _moreLine, script.pages[0].lines[2]]);

    final packed = OcptScriptSidesLayout.of(
      script: script,
      sceneSpans: const [span],
      metrics: _metrics(54),
      presentation: OcptSidesPresentation.packed,
    );
    expect(packed.pages.single.lines, [script.pages[0].lines[0], _moreLine, script.pages[0].lines[2]]);
  });

  test("a span no row overlaps contributes nothing", () {
    final script = _onePageScript([_line("row0", start: 0, end: 5), _line("row1", start: 10, end: 15)]);
    // Falls strictly between the two anchored rows: overlaps neither.
    const span = (charStart: 6, charEnd: 9);

    for (final presentation in OcptSidesPresentation.values) {
      final layout = OcptScriptSidesLayout.of(
        script: script,
        sceneSpans: const [span],
        metrics: _metrics(54),
        presentation: presentation,
      );
      expect(layout.pages, isEmpty, reason: presentation.name);
    }
  });

  test("packed overflow splits into pages, dropping a separator that would open one", () {
    // Two runs of two rows each, with a gap between them, packed at two rows per page: the first
    // run fills the first page exactly, so the separator that would otherwise open the second page
    // is dropped rather than drawn.
    final script = _onePageScript([
      _line("row0", start: 0, end: 5),
      _line("row1", start: 10, end: 15),
      _line("gap", start: 20, end: 25),
      _line("row3", start: 30, end: 35),
      _line("row4", start: 40, end: 45),
    ]);
    const spanA = (charStart: 0, charEnd: 15);
    const spanB = (charStart: 30, charEnd: 45);

    final layout = OcptScriptSidesLayout.of(
      script: script,
      sceneSpans: const [spanA, spanB],
      metrics: _metrics(2),
      presentation: OcptSidesPresentation.packed,
    );

    expect(layout.pages, hasLength(2));
    expect(layout.pages[0].lines, [script.pages[0].lines[0], script.pages[0].lines[1]]);
    expect(layout.pages[1].lines, [script.pages[0].lines[3], script.pages[0].lines[4]]);
  });

  test("an empty sceneSpans gives an empty pages list", () {
    final script = _onePageScript([_line("row0", start: 0, end: 5)]);

    for (final presentation in OcptSidesPresentation.values) {
      final layout = OcptScriptSidesLayout.of(
        script: script,
        sceneSpans: const [],
        metrics: _metrics(54),
        presentation: presentation,
      );
      expect(layout.pages, isEmpty, reason: presentation.name);
    }
  });

  test("sceneSpans handed in out of order come back in screenplay order", () {
    final script = _onePageScript([
      _line("row0", start: 0, end: 5),
      _line("row1", start: 10, end: 15),
      _line("row2", start: 20, end: 25),
      _line("row3", start: 30, end: 35),
    ]);
    const sceneA = (charStart: 0, charEnd: 15);
    const sceneB = (charStart: 20, charEnd: 35);

    // sceneB is handed in before sceneA, deliberately out of screenplay order.
    final layout = OcptScriptSidesLayout.of(
      script: script,
      sceneSpans: const [sceneB, sceneA],
      metrics: _metrics(54),
      presentation: OcptSidesPresentation.packed,
    );

    expect(layout.pages.single.lines, script.pages[0].lines);
  });
}
