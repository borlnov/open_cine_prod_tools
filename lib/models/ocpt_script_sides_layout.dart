// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';

/// Which shape a sides booklet is printed in — see [OcptScriptSidesLayout] for what each one keeps
/// and what it gives up.
enum OcptSidesPresentation {
  /// One output page per composed script page holding at least one selected row, laid out exactly
  /// as the screenplay itself prints it — a reader recognises the page they already know.
  scriptPages,

  /// The selected rows alone, reflowed onto fresh pages with nothing of the screenplay's own
  /// pagination between them — a shorter booklet, at the cost of no longer looking like a
  /// particular page of the script.
  packed,
}

/// One printed page of a sides booklet.
///
/// [lines] is already the exact row order a renderer draws: build a `FountainScriptPage` straight
/// from it and every line lands where this layout put it, whichever presentation produced it.
class OcptScriptSidesPage extends Equatable {
  /// The 0-based index, into the composed script's own `FountainScriptLayout.pages`, of the
  /// screenplay page this one reproduces — null for a [OcptSidesPresentation.packed] page, which
  /// reproduces no single one.
  final int? scriptPageIndex;

  /// The lines drawn on this page, its first row first.
  final List<FountainScriptLine> lines;

  /// Class constructor
  const OcptScriptSidesPage({required this.scriptPageIndex, required this.lines});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptScriptSidesPage(scriptPageIndex: $scriptPageIndex, lines: ${lines.length})";

  /// Object properties
  @override
  List<Object?> get props => [scriptPageIndex, lines];
}

/// A day's scenes, extracted from an already-composed screenplay and laid out as a printable
/// booklet — a side is only useful if it looks like the script, so it is a slice of the real
/// screenplay layout, never re-typeset.
///
/// Pure Dart on purpose (no `pdf`, no Flutter, no drift, no `Tr`): exactly the shape
/// `OcptShootingDayAgendaGrid` and `OcptScenarioCoverageLayout` already are — every hard case is
/// decided and tested here, and the PDF service that consumes it is left with nothing but drawing.
///
/// **Which rows belong.** `sceneSpans` are absolute offsets into the screenplay's own Fountain
/// source (`OcptSchedulePlanSnapshot.sceneSpanBySceneId`'s values, not scene-relative the way a
/// shot's own coverage range is), each resolved against the composed script's own printed rows the
/// very same way
/// `OcptScenarioCoverageLayout._segmentsOf` resolves a coverage range: the first and the last
/// printed row whose own `FountainScriptLine.sourceRange` overlaps the span, and *every* row
/// between them, anchored or not. That bridge rule is what keeps a scene's blank separator lines,
/// its `(MORE)` token and its repeated `NAME (CONT'D)` cue — none of which carry a source range —
/// inside the extract rather than punching a hole through it. A span no printed row overlaps (a
/// scene the screenplay no longer prints) contributes nothing at all, rather than a guess at where
/// it might have been. The whole selection is the **union** across every span.
///
/// **Order.** `sceneSpans` are sorted by their own start here rather than trusted in the caller's
/// order, so the extract is always in **screenplay order, never shooting order**. The
/// [OcptSidesPresentation.scriptPages] presentation cannot read any other way — one printed page
/// regularly holds two scenes, and reordering them on the page would stop it looking like the
/// script, which is the whole reason a side is a slice of the real layout rather than a
/// re-typeset excerpt — and two presentations of one booklet that ordered their own scenes
/// differently would be two documents rather than two readings of one. Nothing is lost by it: the
/// order a day actually shoots in is already printed elsewhere, in the call sheet's own table and
/// in the one-line schedule.
///
/// **Both presentations reproduce the composer's own lines verbatim** — the runs, the indents, the
/// alignments, the scene numbers and the `sourceRange`s are exactly the ones `FountainScriptComposer`
/// produced. Nothing is re-wrapped and nothing is re-paginated: a side that re-typeset its text
/// would stop being the very page the crew is holding.
///
/// It follows that [OcptSidesPresentation.packed], which does move rows onto pages of its own, may
/// cut a speech where the composer — paginating the whole screenplay — would have closed it with a
/// `(MORE)` and reopened it with a repeated `NAME (CONT'D)` cue. **Neither token is synthesised
/// here**, deliberately: those two are the composer's own statement about the screenplay's
/// pagination, and one invented on a booklet that has already given that pagination up would claim
/// a page break the script does not have. A reader who wants the script's own breaks asks for
/// [OcptSidesPresentation.scriptPages], which is exactly what that presentation is for.
class OcptScriptSidesLayout extends Equatable {
  /// The blank row every gap this layout has to fill — a script page's own unselected rows, and a
  /// packed page's own separator between two runs — is filled with. Carries no source of its own,
  /// exactly as a genuine spacer line the composer emits does, so a renderer cannot tell the two
  /// apart by inspecting the row it is handed; only this class needs to, and it never does so by
  /// value (see `_PackedLine.isSeparator`), since a real blank spacer line the bridge rule pulled
  /// into a scene is built from exactly the same fields and must never be mistaken for one of these.
  static const FountainScriptLine _blankFiller = FountainScriptLine(
    runs: [],
    lineType: FountainLineType.blank,
    leftIndentInches: 0,
    alignment: FountainLayoutAlignment.left,
    isSceneHeading: false,
  );

  /// The booklet's own pages, in reading order.
  final List<OcptScriptSidesPage> pages;

  /// Class constructor
  const OcptScriptSidesLayout({required this.pages});

  /// Lays [sceneSpans] out over [script] — the screenplay composed with [metrics] — as
  /// [presentation] says.
  ///
  /// [script] must be the layout `FountainScriptComposer` produced from the very screenplay
  /// [sceneSpans]' offsets address, at the very [metrics]: the rows a span is resolved against are
  /// the rows that composer wrapped the text onto, and nothing here re-derives them.
  ///
  /// [sceneSpans] naming no scene at all, or naming only scenes no printed row overlaps, both give
  /// back an empty [pages]: this factory states the absence rather than inventing a page to
  /// explain it, leaving what to print in its place to the caller.
  factory OcptScriptSidesLayout.of({
    required FountainScriptLayout script,
    required List<({int charStart, int charEnd})> sceneSpans,
    required FountainLayoutMetrics metrics,
    required OcptSidesPresentation presentation,
  }) {
    final lines = _printedLinesOf(script);
    final sortedSpans = sceneSpans.toList()
      ..sort((a, b) => a.charStart.compareTo(b.charStart));

    final selected = List<bool>.filled(lines.length, false);
    for (final span in sortedSpans) {
      final range = _rowRangeOf(span, lines);
      if (range == null) {
        continue;
      }
      for (var index = range.$1; index <= range.$2; index++) {
        selected[index] = true;
      }
    }

    return OcptScriptSidesLayout(
      pages: switch (presentation) {
        OcptSidesPresentation.scriptPages => _scriptPagesOf(script: script, lines: lines, selected: selected),
        OcptSidesPresentation.packed => _packedOf(lines: lines, selected: selected, metrics: metrics),
      },
    );
  }

  /// Flattens [script]'s pages into one list of printed lines, in reading order — the same first
  /// move `OcptScenarioCoverageLayout._printedRowsOf` makes, and for the same reason: resolving a
  /// span against one flat list is what lets a scene spanning a page break be found in a single
  /// pass.
  ///
  /// Unlike that one it keeps the lines alone rather than pairing each with the page and row it
  /// came from: a coverage bar is *drawn* at a given row of a given page and needs both, whereas
  /// this layout only ever asks which rows belong, and both presentations then cut that answer up
  /// their own way — [_scriptPagesOf] walking [script]'s own page lengths, [_packedOf] ignoring
  /// them entirely.
  static List<FountainScriptLine> _printedLinesOf(FountainScriptLayout script) => [
    for (final page in script.pages) ...page.lines,
  ];

  /// The first and last index, into [lines], whose own `FountainScriptLine.sourceRange` overlaps
  /// [span] — the same overlap test `OcptScenarioCoverageLayout._segmentsOf` uses for a coverage
  /// range — or null when no line overlaps it at all.
  static (int, int)? _rowRangeOf(({int charStart, int charEnd}) span, List<FountainScriptLine> lines) {
    int? first;
    var last = 0;
    for (var index = 0; index < lines.length; index++) {
      final source = lines[index].sourceRange;
      if (source == null) {
        continue;
      }
      if (source.startOffset < span.charEnd && source.endOffset > span.charStart) {
        first ??= index;
        last = index;
      }
    }
    return first == null ? null : (first, last);
  }

  /// The [OcptSidesPresentation.scriptPages] reading: one output page per script page holding at
  /// least one selected row, an unselected row inside that span replaced by [_blankFiller] so a
  /// selected row keeps its own true row index and the page keeps the shape a reader recognises.
  ///
  /// A page's own trailing unselected rows are dropped rather than padded out to its full height:
  /// both draw nothing, and the shorter list is simply the honest one — there is no later selected
  /// row on that page left to keep a place for.
  static List<OcptScriptSidesPage> _scriptPagesOf({
    required FountainScriptLayout script,
    required List<FountainScriptLine> lines,
    required List<bool> selected,
  }) {
    final pages = <OcptScriptSidesPage>[];

    var pageStart = 0;
    for (var pageIndex = 0; pageIndex < script.pages.length; pageIndex++) {
      final pageLineCount = script.pages[pageIndex].lines.length;

      var lastSelectedLocal = -1;
      for (var local = 0; local < pageLineCount; local++) {
        if (selected[pageStart + local]) {
          lastSelectedLocal = local;
        }
      }

      if (lastSelectedLocal >= 0) {
        pages.add(
          OcptScriptSidesPage(
            scriptPageIndex: pageIndex,
            lines: [
              for (var local = 0; local <= lastSelectedLocal; local++)
                selected[pageStart + local] ? lines[pageStart + local] : _blankFiller,
            ],
          ),
        );
      }

      pageStart += pageLineCount;
    }

    return pages;
  }

  /// The [OcptSidesPresentation.packed] reading: the selected rows alone, in reading order,
  /// reflowed onto fresh pages of [FountainLayoutMetrics.linesPerPage] rows each.
  ///
  /// A run — a maximal contiguous stretch of selected rows — is never immediately followed by
  /// another one without at least one unselected row between them in the script (that is exactly
  /// what "maximal" means), so a single [_blankFiller] separator is inserted between every pair of
  /// runs this reflow packs next to each other; a scene spanning a page break is one run with no
  /// gap in it at all, and therefore gets no separator. A separator that would land as a page's
  /// **first** row — because the run before it happened to fill the previous page exactly — is
  /// dropped instead: a page never opens on a blank.
  static List<OcptScriptSidesPage> _packedOf({
    required List<FountainScriptLine> lines,
    required List<bool> selected,
    required FountainLayoutMetrics metrics,
  }) {
    final flat = <_PackedLine>[];
    var previousSelectedIndex = -2;
    for (var index = 0; index < lines.length; index++) {
      if (!selected[index]) {
        continue;
      }
      if (flat.isNotEmpty && index != previousSelectedIndex + 1) {
        flat.add(const _PackedLine(line: _blankFiller, isSeparator: true));
      }
      flat.add(_PackedLine(line: lines[index], isSeparator: false));
      previousSelectedIndex = index;
    }

    final pages = <OcptScriptSidesPage>[];
    var current = <FountainScriptLine>[];
    for (final entry in flat) {
      if (current.isEmpty && entry.isSeparator) {
        continue;
      }
      current.add(entry.line);
      if (current.length >= metrics.linesPerPage) {
        pages.add(OcptScriptSidesPage(scriptPageIndex: null, lines: current));
        current = [];
      }
    }
    if (current.isNotEmpty) {
      pages.add(OcptScriptSidesPage(scriptPageIndex: null, lines: current));
    }

    return pages;
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptScriptSidesLayout(pages: ${pages.length})";

  /// Object properties
  @override
  List<Object?> get props => [pages];
}

/// One line of the [OcptScriptSidesLayout._packedOf] reflow, before it is cut into pages: the
/// composed line itself and whether it is one of this class's own separators rather than a row the
/// screenplay actually printed.
///
/// The flag exists because a separator is built from exactly the same fields as a genuine blank
/// spacer line the bridge rule selected (see [OcptScriptSidesLayout._blankFiller]'s own doc
/// comment) — telling the two apart by field-for-field equality, or worse by object identity, would
/// misfire the moment the two happened to coincide, so this class carries the answer instead of
/// ever having to recompute it.
class _PackedLine {
  /// The line to draw.
  final FountainScriptLine line;

  /// Whether [line] is a separator this reflow inserted, rather than a row the script printed.
  final bool isSeparator;

  /// Class constructor
  const _PackedLine({required this.line, required this.isSeparator});
}
