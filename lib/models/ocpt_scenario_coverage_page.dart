// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_bar_segment.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_bar_side.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_gap.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_layout.dart';

/// Everything the coverage export draws on top of one composed script page: its bars, its
/// uncovered runs, and the lane geometry both were laid out against.
///
/// One of these exists per composed script page, whether or not it carries any bar at all, so a
/// renderer walking the script's pages always has the page's own lane pitch at hand.
class OcptScenarioCoveragePage extends Equatable {
  /// The 0-based index of this page among the composed script pages.
  final int pageIndex;

  /// The bars drawn in this page's margins, in the order their lanes were assigned in, i.e. by
  /// [OcptCoverageBarSegment.firstRow].
  final List<OcptCoverageBarSegment> segments;

  /// The uncovered runs washed on this page, in reading order.
  final List<OcptCoverageGap> gaps;

  /// The distance, in inches, between two consecutive lanes of this page.
  ///
  /// [OcptScenarioCoverageLayout.defaultLanePitchInches] on an ordinary page; shrunk, down to
  /// [OcptScenarioCoverageLayout.minimumLanePitchInches], on a page dense enough to need more
  /// lanes than the margins hold at the default pitch.
  final double lanePitchInches;

  /// The number of lanes this page's margins hold at [lanePitchInches], both sides together.
  final int laneCapacity;

  /// Whether this page needed more lanes than [laneCapacity], so its excess bars had to share the
  /// outermost lane ([OcptCoverageBarSegment.sharesOutermostLane]).
  ///
  /// Only ever true where a dozen shots cover the very same lines; the summary page reports it
  /// when it happens, so a reader knows the margin is not telling the whole story.
  final bool hasLaneOverflow;

  /// Class constructor
  const OcptScenarioCoveragePage({
    required this.pageIndex,
    required this.segments,
    required this.gaps,
    required this.lanePitchInches,
    required this.laneCapacity,
    required this.hasLaneOverflow,
  });

  /// The distance, in inches, from the printable area's edge (the left margin for
  /// [OcptCoverageBarSide.left], the right margin for [OcptCoverageBarSide.right]) outward to the
  /// inner edge of [segment]'s own lane band, which is [lanePitchInches] wide.
  ///
  /// The renderer draws the bar inside that band — it is the single place both sides' geometry is
  /// derived from, so a bar and its label can never drift apart from the lane they were assigned.
  double laneInsetInches(OcptCoverageBarSegment segment) =>
      OcptScenarioCoverageLayout.sceneNumberGutterInches + segment.lane * lanePitchInches;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptScenarioCoveragePage(pageIndex: $pageIndex, segments: ${segments.length}, "
      "gaps: ${gaps.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    pageIndex,
    segments,
    gaps,
    lanePitchInches,
    laneCapacity,
    hasLaneOverflow,
  ];
}
