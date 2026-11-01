// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_bar_segment.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_bar_side.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_gap.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_legend_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_summary_row.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_tick.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_page.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';

/// The whole scenario coverage export, laid out over an already-composed screenplay: which bar
/// goes in which margin lane of which page, which printed text no shot covers, and the two extra
/// pages' own data.
///
/// Pure Dart on purpose (no `pdf`, no Flutter): every rule the reference document follows lives
/// here, where it can be tested against exact rows and columns, and the renderer that consumes it
/// is left with nothing but drawing.
///
/// **What [OcptCoverageBarSegment.pageIndex] counts.** It indexes [FountainScriptLayout.pages],
/// the *script* pages, exactly as `FountainScriptComposer` produced them — a title page, which the
/// PDF exporter adds ahead of them, is not one of them. A renderer offsetting script pages by a
/// title page must offset these indexes the same way.
///
/// **How a source offset becomes a row.** A coverage range is a pair of offsets into the raw
/// Fountain source, scene-relative; every printed line carries the span of source it was composed
/// from ([FountainScriptLine.sourceRange]). A range's first and last rows are the first and last
/// printed lines whose own span it overlaps, and *every* row between those two belongs to the bar,
/// anchored or not — which is the bridge rule that makes a bar run continuously across the blank
/// line separating two paragraphs, across a `(MORE)` token, and across a page break.
class OcptScenarioCoverageLayout extends Equatable {
  /// The width, in inches, reserved between the printable text and the innermost lane on either
  /// side, so the scene numbers the screenplay prints in both margins keep their place.
  ///
  /// Four Courier columns' worth of number plus a column of air, which is what a scene number
  /// (`12`, `4A`, at worst `112B`) actually needs.
  static const double sceneNumberGutterInches = 0.5;

  /// The distance, in inches, between two consecutive lanes on an ordinary page.
  static const double defaultLanePitchInches = 0.16;

  /// The smallest lane pitch, in inches, a dense page is allowed to shrink to before its excess
  /// bars start sharing the outermost lane instead.
  static const double minimumLanePitchInches = 0.08;

  /// How much a dense page's lane pitch is shaved off at a time while looking for the widest
  /// pitch that still fits every lane the page needs.
  static const double _lanePitchStepInches = 0.01;

  /// The greatest number of uncovered extracts one summary row quotes.
  static const int _maxUncoveredExtracts = 5;

  /// The greatest number of characters one quoted uncovered extract keeps, before it is cut short
  /// with [_ellipsis].
  static const int _maxUncoveredExtractLength = 60;

  /// The character a quoted extract too long for [_maxUncoveredExtractLength] ends on.
  static const String _ellipsis = "…";

  /// Everything drawn on top of the composed script pages, one entry per script page, in order.
  final List<OcptScenarioCoveragePage> pages;

  /// The legend page's rows: every shot of the shot list, in sequence then rank order.
  final List<OcptCoverageLegendEntry> legend;

  /// The summary page's rows: every sequence, in the snapshot's own order, orphan group last.
  final List<OcptCoverageSummaryRow> summary;

  /// Whether any page needed more lanes than its margins hold: what the summary page prints its
  /// "some bars share a lane" warning from.
  bool get hasLaneOverflow => pages.any((page) => page.hasLaneOverflow);

  /// Class constructor
  const OcptScenarioCoverageLayout({
    required this.pages,
    required this.legend,
    required this.summary,
  });

  /// Lays [snapshot]'s coverage ranges out over [script], the screenplay [screenplayText] composed
  /// with [metrics].
  ///
  /// [script] must be the layout `FountainScriptComposer` produced from that very text and those
  /// very metrics: the rows a bar is placed on are the rows that composer wrapped the text onto,
  /// and nothing here re-derives them.
  ///
  /// A shot whose scene no longer exists (the orphan group) contributes no bar, since its ranges
  /// address a scene the screenplay no longer prints; it is still listed in [legend] and named in
  /// [summary].
  factory OcptScenarioCoverageLayout.of({
    required FountainScriptLayout script,
    required OcptShotListSnapshot snapshot,
    required String screenplayText,
    required FountainLayoutMetrics metrics,
  }) {
    final scenesById = <String, OcptSceneShotSequence>{
      for (final sequence in snapshot.sequences)
        if (sequence is OcptSceneShotSequence) sequence.sceneId: sequence,
    };

    final rows = _printedRowsOf(script);
    final resolvedRanges = _resolveRanges(
      snapshot: snapshot,
      scenesById: scenesById,
      textLength: screenplayText.length,
    );

    final pending = <_PendingSegment>[
      for (final range in resolvedRanges) ..._segmentsOf(range, rows),
    ];
    final coveredIntervals = _mergedIntervals(resolvedRanges);

    return OcptScenarioCoverageLayout(
      pages: _pagesOf(
        script: script,
        rows: rows,
        pending: pending,
        coveredIntervals: coveredIntervals,
        metrics: metrics,
      ),
      legend: _legendOf(snapshot),
      summary: _summaryOf(snapshot: snapshot, screenplayText: screenplayText),
    );
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptScenarioCoverageLayout(pages: ${pages.length}, legend: ${legend.length}, "
      "summary: ${summary.length})";

  /// The label [shot]'s bars and legend row carry: its abbreviation followed by its code
  /// (`PM1/1`), or its code alone (`1/1`) while it has no abbreviation.
  static String labelOf(OcptShot shot) =>
      shot.abbreviation.isEmpty ? shot.code : "${shot.abbreviation}${shot.code}";

  /// Flattens [script]'s pages into one list of printed rows, in reading order, each still
  /// knowing which page and which row of it it is.
  ///
  /// Resolving a coverage range against one flat list is what lets a range spanning a page break
  /// be found in a single pass and only then be cut back into one segment per page.
  static List<_PrintedRow> _printedRowsOf(FountainScriptLayout script) => [
    for (var pageIndex = 0; pageIndex < script.pages.length; pageIndex++)
      for (var row = 0; row < script.pages[pageIndex].lines.length; row++)
        _PrintedRow(pageIndex: pageIndex, rowIndex: row, line: script.pages[pageIndex].lines[row]),
  ];

  /// Turns every coverage range of [snapshot] into the absolute source span it addresses in the
  /// screenplay's text, together with the colour and label the bar drawn for it carries.
  ///
  /// A range is stored relative to its scene's `charStart`, so this is where the two are added
  /// back together; [scenesById] is what a range's own scene id is resolved through, rather than
  /// the sequence its shot happens to sit in, so a range still lands on the right scene whatever
  /// the shot list did with its shot. A range of a scene the screenplay no longer holds resolves
  /// to nothing at all, and is dropped here.
  static List<_ResolvedRange> _resolveRanges({
    required OcptShotListSnapshot snapshot,
    required Map<String, OcptSceneShotSequence> scenesById,
    required int textLength,
  }) {
    final resolved = <_ResolvedRange>[];

    for (final sequence in snapshot.sequences) {
      for (var rank = 0; rank < sequence.shots.length; rank++) {
        final shot = sequence.shots[rank];
        for (final range in shot.coverageRanges) {
          final scene = scenesById[range.sceneId];
          if (scene == null) {
            continue;
          }

          final start = (scene.charStart + range.startOffset).clamp(0, textLength);
          final end = (scene.charStart + range.endOffset).clamp(start, textLength);
          if (end <= start) {
            continue;
          }

          resolved.add(
            _ResolvedRange(
              startOffset: start,
              endOffset: end,
              colorIndex: rank,
              label: labelOf(shot),
              isStale: range.isStale,
            ),
          );
        }
      }
    }

    return resolved;
  }

  /// The bar segments [range] draws: one per page it reaches, each carrying the rows it spans on
  /// that page.
  ///
  /// The rows come from the first and the last printed line whose own source span [range]
  /// overlaps; every row in between belongs to the bar whether it is anchored or not (see this
  /// class's doc comment). A range no printed line overlaps — one covering source the screenplay
  /// no longer prints — draws nothing at all.
  static List<_PendingSegment> _segmentsOf(_ResolvedRange range, List<_PrintedRow> rows) {
    int? firstIndex;
    var lastIndex = 0;

    for (var index = 0; index < rows.length; index++) {
      final source = rows[index].line.sourceRange;
      if (source == null) {
        continue;
      }
      if (source.startOffset < range.endOffset && source.endOffset > range.startOffset) {
        firstIndex ??= index;
        lastIndex = index;
      }
    }

    if (firstIndex == null) {
      return const [];
    }

    final startTickColumn = _columnOf(rows[firstIndex].line, range.startOffset);
    final endTickColumn = _columnOf(rows[lastIndex].line, range.endOffset);

    final segments = <_PendingSegment>[];
    var groupStart = firstIndex;
    for (var index = firstIndex; index <= lastIndex; index++) {
      final isLastOfPage = index == lastIndex || rows[index + 1].pageIndex != rows[index].pageIndex;
      if (!isLastOfPage) {
        continue;
      }

      segments.add(
        _PendingSegment(
          pageIndex: rows[groupStart].pageIndex,
          firstRow: rows[groupStart].rowIndex,
          lastRow: rows[index].rowIndex,
          colorIndex: range.colorIndex,
          label: range.label,
          isStale: range.isStale,
          startsRange: groupStart == firstIndex,
          endsRange: index == lastIndex,
          startTick: groupStart == firstIndex && startTickColumn != null
              ? OcptCoverageTick(row: rows[firstIndex].rowIndex, column: startTickColumn)
              : null,
          endTick: index == lastIndex && endTickColumn != null
              ? OcptCoverageTick(row: rows[lastIndex].rowIndex, column: endTickColumn)
              : null,
        ),
      );
      groupStart = index + 1;
    }

    return segments;
  }

  /// The column, in [line]'s own printed text, the absolute source [offset] falls at, or null
  /// when the boundary needs no tick because it lands on the line's first or last column.
  ///
  /// Walks the line's runs rather than its merged source range, so an emphasis marker between two
  /// runs (which occupies source but no printed column) never shifts the tick. Within a run whose
  /// printed text is as long as the source it came from — the ordinary case — the column is exact;
  /// where a print-time upper-casing or an escape sequence made the two differ, it is interpolated
  /// proportionally, which can be a character or two off inside that one run and never moves the
  /// tick to another row.
  static int? _columnOf(FountainScriptLine line, int offset) {
    final column = _rawColumnOf(line, offset);
    if (column == null || column <= 0 || column >= line.plainText.length) {
      return null;
    }
    return column;
  }

  /// The column [offset] falls at in [line]'s printed text, without [_columnOf]'s "is it worth a
  /// tick" filtering, or null when the line carries no anchored run at all.
  static int? _rawColumnOf(FountainScriptLine line, int offset) {
    var cursor = 0;
    var anchored = false;

    for (final run in line.runs) {
      final source = run.sourceRange;
      if (source == null) {
        cursor += run.text.length;
        continue;
      }
      anchored = true;
      if (offset <= source.startOffset) {
        return cursor;
      }
      if (offset < source.endOffset) {
        return cursor + _offsetIntoRun(offset, source, run.text.length);
      }
      cursor += run.text.length;
    }

    return anchored ? cursor : null;
  }

  /// Where the absolute source [offset] falls inside a run of [textLength] printed characters
  /// composed from [source], as a 0-based offset into that run's own text.
  static int _offsetIntoRun(int offset, FountainSourceRange source, int textLength) {
    final sourceLength = source.endOffset - source.startOffset;
    if (sourceLength <= 0 || textLength == 0) {
      return 0;
    }
    final local = offset - source.startOffset;
    if (sourceLength == textLength) {
      return local.clamp(0, textLength);
    }
    return (local * textLength / sourceLength).round().clamp(0, textLength);
  }

  /// The union of every resolved range, merged into disjoint intervals sorted by start offset:
  /// what an uncovered run is the complement of.
  static List<_Interval> _mergedIntervals(List<_ResolvedRange> ranges) {
    final sorted = ranges.map((range) => _Interval(range.startOffset, range.endOffset)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <_Interval>[];
    for (final interval in sorted) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null && interval.start <= last.end) {
        merged[merged.length - 1] = _Interval(
          last.start,
          interval.end > last.end ? interval.end : last.end,
        );
      } else {
        merged.add(interval);
      }
    }

    return merged;
  }

  /// Builds one [OcptScenarioCoveragePage] per script page: its bars, once their lanes are
  /// assigned, and the uncovered runs washed on it.
  static List<OcptScenarioCoveragePage> _pagesOf({
    required FountainScriptLayout script,
    required List<_PrintedRow> rows,
    required List<_PendingSegment> pending,
    required List<_Interval> coveredIntervals,
    required FountainLayoutMetrics metrics,
  }) {
    final segmentsByPage = <int, List<_PendingSegment>>{};
    for (final segment in pending) {
      segmentsByPage.putIfAbsent(segment.pageIndex, () => []).add(segment);
    }

    final gapsByPage = <int, List<OcptCoverageGap>>{};
    for (final row in rows) {
      final gaps = _gapsOf(row, coveredIntervals);
      if (gaps.isNotEmpty) {
        gapsByPage.putIfAbsent(row.pageIndex, () => []).addAll(gaps);
      }
    }

    return [
      for (var pageIndex = 0; pageIndex < script.pages.length; pageIndex++)
        _pageOf(
          pageIndex: pageIndex,
          pending: segmentsByPage[pageIndex] ?? const [],
          gaps: gapsByPage[pageIndex] ?? const [],
          metrics: metrics,
        ),
    ];
  }

  /// Assigns [pending]'s bars to the lanes of page [pageIndex] and freezes the whole page.
  ///
  /// The lanes come from a greedy interval colouring over the segments sorted by their first row:
  /// each bar takes the innermost lane no bar it overlaps already holds. Those lane indexes then
  /// fill the left margin first and the right margin next, at the widest pitch that fits them all
  /// (down to [minimumLanePitchInches]); the bars a page still has no lane for share the outermost
  /// one, and say so.
  static OcptScenarioCoveragePage _pageOf({
    required int pageIndex,
    required List<_PendingSegment> pending,
    required List<OcptCoverageGap> gaps,
    required FountainLayoutMetrics metrics,
  }) {
    final sorted = pending.toList()
      ..sort((a, b) {
        final byFirstRow = a.firstRow.compareTo(b.firstRow);
        if (byFirstRow != 0) {
          return byFirstRow;
        }
        final byLastRow = a.lastRow.compareTo(b.lastRow);
        return byLastRow != 0 ? byLastRow : a.label.compareTo(b.label);
      });

    // The last row each greedy lane is occupied up to, so far.
    final laneEnds = <int>[];
    final laneIndexes = <int>[];
    for (final segment in sorted) {
      var lane = laneEnds.indexWhere((end) => end < segment.firstRow);
      if (lane < 0) {
        laneEnds.add(segment.lastRow);
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = segment.lastRow;
      }
      laneIndexes.add(lane);
    }

    final geometry = _LaneGeometry.of(metrics: metrics, requiredLanes: laneEnds.length);

    return OcptScenarioCoveragePage(
      pageIndex: pageIndex,
      segments: [
        for (var index = 0; index < sorted.length; index++)
          sorted[index].placed(geometry.place(laneIndexes[index])),
      ],
      gaps: gaps,
      lanePitchInches: geometry.pitchInches,
      laneCapacity: geometry.capacity,
      hasLaneOverflow: laneEnds.length > geometry.capacity,
    );
  }

  /// The runs of [row]'s printed text no interval of [covered] covers, trimmed of their
  /// surrounding whitespace and merged where two consecutive runs meet.
  ///
  /// A row with no anchored run of its own is left alone rather than washed whole: a blank spacer
  /// line, a `(MORE)` token or a line the composer could not anchor says nothing about whether it
  /// is covered, and washing it would claim it does.
  ///
  /// A scene heading is left alone for a different reason: it names the scene rather than playing
  /// in it, so no shot has any business covering it and washing it would report an omission nobody
  /// can act on.
  static List<OcptCoverageGap> _gapsOf(_PrintedRow row, List<_Interval> covered) {
    final line = row.line;
    if (line.isSynthetic || line.runs.isEmpty || line.isSceneHeading) {
      return const [];
    }

    final text = line.plainText;
    final columns = <_Interval>[];
    var cursor = 0;

    for (final run in line.runs) {
      final source = run.sourceRange;
      final length = run.text.length;
      if (source == null || length == 0) {
        cursor += length;
        continue;
      }

      for (final gap in _complementOf(source.startOffset, source.endOffset, covered)) {
        final start = cursor + _offsetIntoRun(gap.start, source, length);
        final end = cursor + _offsetIntoRun(gap.end, source, length);
        if (end > start) {
          columns.add(_Interval(start, end));
        }
      }
      cursor += length;
    }

    final gaps = <OcptCoverageGap>[];
    for (final interval in columns) {
      final previous = gaps.isEmpty ? null : gaps.last;
      if (previous != null && interval.start <= previous.endColumn) {
        gaps[gaps.length - 1] = OcptCoverageGap(
          pageIndex: row.pageIndex,
          row: row.rowIndex,
          startColumn: previous.startColumn,
          endColumn: interval.end > previous.endColumn ? interval.end : previous.endColumn,
        );
        continue;
      }
      gaps.add(
        OcptCoverageGap(
          pageIndex: row.pageIndex,
          row: row.rowIndex,
          startColumn: interval.start,
          endColumn: interval.end,
        ),
      );
    }

    return [
      for (final gap in gaps)
        if (_trimmed(gap, text) case final trimmed?) trimmed,
    ];
  }

  /// [gap] with the whitespace at either end of it dropped, or null once nothing but whitespace
  /// is left: the wash goes behind words, never behind the blank columns around them.
  static OcptCoverageGap? _trimmed(OcptCoverageGap gap, String text) {
    var start = gap.startColumn.clamp(0, text.length);
    var end = gap.endColumn.clamp(start, text.length);

    while (start < end && text[start].trim().isEmpty) {
      start++;
    }
    while (end > start && text[end - 1].trim().isEmpty) {
      end--;
    }

    if (end <= start) {
      return null;
    }
    return OcptCoverageGap(
      pageIndex: gap.pageIndex,
      row: gap.row,
      startColumn: start,
      endColumn: end,
    );
  }

  /// The parts of `[start, end)` no interval of [covered] (disjoint and sorted) covers.
  static List<_Interval> _complementOf(int start, int end, List<_Interval> covered) {
    final result = <_Interval>[];
    var cursor = start;

    for (final interval in covered) {
      if (interval.end <= cursor) {
        continue;
      }
      if (interval.start >= end) {
        break;
      }
      if (interval.start > cursor) {
        result.add(_Interval(cursor, interval.start));
      }
      cursor = interval.end;
      if (cursor >= end) {
        return result;
      }
    }

    if (cursor < end) {
      result.add(_Interval(cursor, end));
    }
    return result;
  }

  /// The legend page's rows: every shot of [snapshot], in sequence then rank order, orphan shots
  /// included — an orphan draws no bar, but it is still a shot the reader may be looking for.
  static List<OcptCoverageLegendEntry> _legendOf(OcptShotListSnapshot snapshot) => [
    for (final sequence in snapshot.sequences)
      for (var rank = 0; rank < sequence.shots.length; rank++)
        OcptCoverageLegendEntry(
          shotId: sequence.shots[rank].id,
          sequenceId: sequence.id,
          colorIndex: rank,
          label: labelOf(sequence.shots[rank]),
          shotSize: sequence.shots[rank].shotSize,
          framing: sequence.shots[rank].framing,
          cameraMove: sequence.shots[rank].cameraMove,
        ),
  ];

  /// The summary page's rows, one per sequence of [snapshot] in its own order.
  ///
  /// The word counts go through [OcptScriptWordLayout], the very model the coverage editor lays
  /// a scene out with, so what the summary calls covered is exactly what the editor calls covered.
  static List<OcptCoverageSummaryRow> _summaryOf({
    required OcptShotListSnapshot snapshot,
    required String screenplayText,
  }) => [
    for (final sequence in snapshot.sequences)
      switch (sequence) {
        OcptSceneShotSequence() => _sceneSummaryOf(sequence, screenplayText),
        OcptOrphanShotSequence() => OcptCoverageSummaryRow(
          sequenceId: sequence.id,
          sceneNumber: null,
          heading: "",
          shotCount: sequence.shotCount,
          wordCount: 0,
          coveredWordCount: 0,
          staleRangeCount: _staleRangeCountOf(sequence),
          uncoveredExtracts: const [],
          isOrphanGroup: true,
        ),
      },
  ];

  /// The summary row of a real scene [sequence], measured against its own slice of
  /// [screenplayText].
  ///
  /// Measured over [_coverableBlocksOf] rather than over the whole scene, so the percentage and the
  /// extracts answer for exactly the text the printed page washes — a heading counted as uncovered
  /// would hold every scene's share below 100% with nothing a shot could do about it.
  static OcptCoverageSummaryRow _sceneSummaryOf(
    OcptSceneShotSequence sequence,
    String screenplayText,
  ) {
    final start = sequence.charStart.clamp(0, screenplayText.length);
    final end = sequence.charEnd.clamp(start, screenplayText.length);
    final layout = OcptScriptWordLayout.of(
      sceneId: sequence.sceneId,
      sceneText: screenplayText.substring(start, end),
    );
    final blocks = _coverableBlocksOf(layout);
    final ranges = [for (final shot in sequence.shots) ...shot.coverageRanges];

    var wordCount = 0;
    var coveredWordCount = 0;
    for (final block in blocks) {
      wordCount += block.words.length;
      for (final word in block.words) {
        if (layout.isWordCovered(word, ranges)) {
          coveredWordCount++;
        }
      }
    }

    return OcptCoverageSummaryRow(
      sequenceId: sequence.id,
      sceneNumber: sequence.displaySceneNumber,
      heading: sequence.heading,
      shotCount: sequence.shotCount,
      wordCount: wordCount,
      coveredWordCount: coveredWordCount,
      staleRangeCount: _staleRangeCountOf(sequence),
      uncoveredExtracts: _uncoveredExtractsOf(layout, blocks, ranges),
      isOrphanGroup: false,
    );
  }

  /// The blocks of [layout] a shot can meaningfully cover: everything but the scene headings, which
  /// name the scene rather than play in it and are left out of the whole coverage report — the
  /// washes drawn on the page as much as the figures measuring them.
  static List<OcptScriptWordBlock> _coverableBlocksOf(OcptScriptWordLayout layout) => [
    for (final block in layout.blocks)
      if (block.type != FountainLineType.sceneHeading) block,
  ];

  /// How many of [sequence]'s shots' coverage ranges no longer agree with the screenplay's text.
  static int _staleRangeCountOf(OcptShotSequence sequence) {
    var count = 0;
    for (final shot in sequence.shots) {
      count += shot.coverageRanges.where((range) => range.isStale).length;
    }
    return count;
  }

  /// The uncovered passages of [blocks] — the coverable part of the scene [layout] lays out —
  /// quoted in reading order.
  ///
  /// Built from the scene's own words rather than from the printed rows, so an extract reads as
  /// the screenplay wrote it (markers and all) rather than as the paginator wrapped it. Consecutive
  /// uncovered words of one block make one extract; each is cut at [_maxUncoveredExtractLength]
  /// characters and the list itself at [_maxUncoveredExtracts] entries.
  static List<String> _uncoveredExtractsOf(
    OcptScriptWordLayout layout,
    List<OcptScriptWordBlock> blocks,
    List<OcptShotCoverageRange> ranges,
  ) {
    final extracts = <String>[];

    for (final block in blocks) {
      OcptScriptWord? first;
      OcptScriptWord? last;

      /// Closes the run of uncovered words accumulated so far, if any, into an extract.
      void flush() {
        if (first == null || last == null) {
          return;
        }
        extracts.add(_shortened(layout.sceneText.substring(first!.startOffset, last!.endOffset)));
        first = null;
        last = null;
      }

      for (final word in block.words) {
        if (layout.isWordCovered(word, ranges)) {
          flush();
          continue;
        }
        first ??= word;
        last = word;
      }
      flush();

      if (extracts.length >= _maxUncoveredExtracts) {
        return extracts.take(_maxUncoveredExtracts).toList(growable: false);
      }
    }

    return extracts;
  }

  /// [text] cut at [_maxUncoveredExtractLength] characters, ending on [_ellipsis] when it had to
  /// be cut.
  static String _shortened(String text) => text.length <= _maxUncoveredExtractLength
      ? text
      : "${text.substring(0, _maxUncoveredExtractLength).trimRight()}$_ellipsis";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [pages, legend, summary];
}

/// One printed line of the composed screenplay, still knowing where it was printed.
class _PrintedRow {
  /// The 0-based index of the page this line is printed on.
  final int pageIndex;

  /// The 0-based row of that page this line is printed on.
  final int rowIndex;

  /// The composed line itself.
  final FountainScriptLine line;

  /// Class constructor
  const _PrintedRow({required this.pageIndex, required this.rowIndex, required this.line});
}

/// A coverage range once its scene-relative offsets have been resolved against the screenplay's
/// whole text, carrying everything the bar drawn for it needs.
class _ResolvedRange {
  /// The absolute character offset, in the screenplay's text, this range starts at.
  final int startOffset;

  /// The absolute character offset one past this range's last character.
  final int endOffset;

  /// The rank, within its sequence, of the shot this range belongs to.
  final int colorIndex;

  /// The label the shot's bars carry.
  final String label;

  /// Whether the range no longer agrees with the screenplay's text.
  final bool isStale;

  /// Class constructor
  const _ResolvedRange({
    required this.startOffset,
    required this.endOffset,
    required this.colorIndex,
    required this.label,
    required this.isStale,
  });
}

/// A bar segment before its lane is known: everything [OcptCoverageBarSegment] holds except where
/// in the margin it goes, which only the whole page's segments together can decide.
class _PendingSegment {
  /// The page this bar is drawn on.
  final int pageIndex;

  /// The row this bar starts on.
  final int firstRow;

  /// The row this bar ends on, inclusive.
  final int lastRow;

  /// The rank, within its sequence, of the shot this bar belongs to.
  final int colorIndex;

  /// The bar's label.
  final String label;

  /// Whether the covered range no longer agrees with the screenplay's text.
  final bool isStale;

  /// Whether [firstRow] is where the covered range really begins.
  final bool startsRange;

  /// Whether [lastRow] is where the covered range really ends.
  final bool endsRange;

  /// The tick marking where inside [firstRow] the range starts, if any.
  final OcptCoverageTick? startTick;

  /// The tick marking where inside [lastRow] the range ends, if any.
  final OcptCoverageTick? endTick;

  /// Class constructor
  const _PendingSegment({
    required this.pageIndex,
    required this.firstRow,
    required this.lastRow,
    required this.colorIndex,
    required this.label,
    required this.isStale,
    required this.startsRange,
    required this.endsRange,
    required this.startTick,
    required this.endTick,
  });

  /// This segment, frozen into its final form now that [placement] says which lane it sits in.
  OcptCoverageBarSegment placed(_LanePlacement placement) => OcptCoverageBarSegment(
    pageIndex: pageIndex,
    firstRow: firstRow,
    lastRow: lastRow,
    lane: placement.lane,
    side: placement.side,
    colorIndex: colorIndex,
    label: label,
    isStale: isStale,
    sharesOutermostLane: placement.sharesOutermostLane,
    startsRange: startsRange,
    endsRange: endsRange,
    startTick: startTick,
    endTick: endTick,
  );
}

/// Where one bar ends up in the margins, once its page's lane geometry is settled.
class _LanePlacement {
  /// Which margin the bar is drawn in.
  final OcptCoverageBarSide side;

  /// The bar's 0-based lane within that margin, counted outward from the text.
  final int lane;

  /// Whether the bar had to share the outermost lane for want of a free one.
  final bool sharesOutermostLane;

  /// Class constructor
  const _LanePlacement({required this.side, required this.lane, required this.sharesOutermostLane});
}

/// How many lanes one page's margins hold, at which pitch, and how a greedy lane index maps onto
/// them.
class _LaneGeometry {
  /// The distance between two consecutive lanes, in inches.
  final double pitchInches;

  /// How many lanes fit in the left margin at [pitchInches].
  final int leftCapacity;

  /// How many lanes fit in both margins together at [pitchInches], never less than one.
  final int capacity;

  /// Class constructor
  const _LaneGeometry({
    required this.pitchInches,
    required this.leftCapacity,
    required this.capacity,
  });

  /// The geometry of a page needing [requiredLanes] lanes, given [metrics]' margins.
  ///
  /// The pitch starts at [OcptScenarioCoverageLayout.defaultLanePitchInches] and is shaved down,
  /// never past [OcptScenarioCoverageLayout.minimumLanePitchInches], until the margins hold every
  /// lane the page needs. What that floor still cannot hold shares the outermost lane, which is
  /// what [place] hands back.
  factory _LaneGeometry.of({required FountainLayoutMetrics metrics, required int requiredLanes}) {
    final availableLeft =
        metrics.marginLeftInches - OcptScenarioCoverageLayout.sceneNumberGutterInches;
    final availableRight =
        metrics.marginRightInches - OcptScenarioCoverageLayout.sceneNumberGutterInches;

    int lanesFitting(double available, double pitch) =>
        available <= 0 ? 0 : (available / pitch).floor();
    int totalFitting(double pitch) =>
        lanesFitting(availableLeft, pitch) + lanesFitting(availableRight, pitch);

    var pitch = OcptScenarioCoverageLayout.defaultLanePitchInches;
    while (totalFitting(pitch) < requiredLanes &&
        pitch > OcptScenarioCoverageLayout.minimumLanePitchInches) {
      final shrunk = pitch - OcptScenarioCoverageLayout._lanePitchStepInches;
      pitch = shrunk < OcptScenarioCoverageLayout.minimumLanePitchInches
          ? OcptScenarioCoverageLayout.minimumLanePitchInches
          : shrunk;
    }

    final total = totalFitting(pitch);
    return _LaneGeometry(
      pitchInches: pitch,
      leftCapacity: lanesFitting(availableLeft, pitch),
      // Margins too narrow to hold a single lane are not worth dropping every bar over: the page
      // then has exactly one lane, which every bar shares.
      capacity: total < 1 ? 1 : total,
    );
  }

  /// Where the bar holding the greedy lane [index] is drawn: the left margin's lanes first,
  /// innermost to outermost, then the right margin's, and the outermost lane of all for whatever
  /// this page has no room left for.
  _LanePlacement place(int index) {
    final isOverflowing = index >= capacity;
    final clamped = isOverflowing ? capacity - 1 : index;
    if (clamped < leftCapacity || leftCapacity >= capacity) {
      return _LanePlacement(
        side: OcptCoverageBarSide.left,
        lane: clamped,
        sharesOutermostLane: isOverflowing,
      );
    }
    return _LanePlacement(
      side: OcptCoverageBarSide.right,
      lane: clamped - leftCapacity,
      sharesOutermostLane: isOverflowing,
    );
  }
}

/// A half-open `[start, end)` range of character offsets, used both for source spans and for
/// column spans.
class _Interval {
  /// The range's inclusive start.
  final int start;

  /// The range's exclusive end.
  final int end;

  /// Class constructor
  const _Interval(this.start, this.end);
}
