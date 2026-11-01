// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_bar_side.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_tick.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_page.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';

/// One coloured bar drawn in a page's margin, alongside the rows a single coverage range was
/// printed on.
///
/// There is one segment per (coverage range × page it appears on), never one per shot: a shot
/// covering two disjoint passages draws two bars of the same [colorIndex] and [label], and a range
/// spanning a page break draws one segment per page, its label repeated — both exactly as the
/// reference document does.
class OcptCoverageBarSegment extends Equatable {
  /// The 0-based index, among the composed script pages, of the page this bar is drawn on. See
  /// [OcptScenarioCoverageLayout] for what that index does *not* count.
  final int pageIndex;

  /// The 0-based row, within that page, this bar starts on.
  final int firstRow;

  /// The 0-based row, within that page, this bar ends on (inclusive).
  final int lastRow;

  /// The 0-based lane this bar sits in, counted outward from the text: lane 0 is the innermost
  /// lane of its [side]. See [OcptScenarioCoveragePage.laneInsetInches].
  final int lane;

  /// Which margin this bar is drawn in.
  final OcptCoverageBarSide side;

  /// The rank, within its own sequence, of the shot this bar belongs to: the index the coverage
  /// palette is read at (`ocptCoverageColorAt`).
  final int colorIndex;

  /// The bar's label — the shot's abbreviation followed by its code (`PM1/1`), or its code alone
  /// when it has no abbreviation yet.
  final String label;

  /// Whether the covered range no longer agrees with the screenplay's text
  /// ([OcptShotCoverageRange.isStale]), so the renderer can draw it hollow rather than solid.
  final bool isStale;

  /// Whether this bar had to share the outermost lane of its page with other bars, because the
  /// page needs more lanes than its margins can hold even at the smallest lane pitch. See
  /// [OcptScenarioCoveragePage.hasLaneOverflow].
  final bool sharesOutermostLane;

  /// Whether [firstRow] is where the covered range really begins, so the renderer can cap the bar
  /// there.
  ///
  /// False on the continuation a range spanning a page break draws on its later pages: that bar's
  /// top edge is the page's doing, not the range's, and capping it would claim a shot starts where
  /// the paper merely ran out.
  final bool startsRange;

  /// Whether [lastRow] is where the covered range really ends, the mirror of [startsRange].
  final bool endsRange;

  /// Where inside [firstRow]'s text the covered range starts, or null when it starts on that
  /// line's first column (nothing to mark) or that line could not be resolved precisely.
  final OcptCoverageTick? startTick;

  /// Where inside [lastRow]'s text the covered range ends, or null when it ends on that line's
  /// last column.
  final OcptCoverageTick? endTick;

  /// Class constructor
  const OcptCoverageBarSegment({
    required this.pageIndex,
    required this.firstRow,
    required this.lastRow,
    required this.lane,
    required this.side,
    required this.colorIndex,
    required this.label,
    required this.isStale,
    required this.sharesOutermostLane,
    required this.startsRange,
    required this.endsRange,
    required this.startTick,
    required this.endTick,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptCoverageBarSegment(label: $label, page: $pageIndex, rows: $firstRow-$lastRow, "
      "${side.name} lane $lane)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [
    pageIndex,
    firstRow,
    lastRow,
    lane,
    side,
    colorIndex,
    label,
    isStale,
    sharesOutermostLane,
    startsRange,
    endsRange,
    startTick,
    endTick,
  ];
}
