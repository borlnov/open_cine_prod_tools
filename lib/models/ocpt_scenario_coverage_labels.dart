// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';

/// Every localized string the exported scenario coverage document carries, resolved by the caller.
///
/// `OcptScenarioCoveragePdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason [OcptShotListXlsxLabels] already exists for the workbook, and
/// the same reason `OcptExportManager`'s other exports take their native dialog's `fileTypeLabel`
/// from their caller.
///
/// Only the two extra pages and the file name are localized — the screenplay pages themselves print
/// nothing but the screenplay, the shots' own free-text fields and their labels.
class OcptScenarioCoverageLabels extends Equatable {
  /// The suffix the suggested file name is built with (`<project> - <suffix>.pdf`).
  final String fileNameSuffix;

  /// The heading of the legend page.
  final String legendTitle;

  /// The legend's column header naming a shot's label (its abbreviation and code).
  final String legendShotHeader;

  /// The legend's column header naming a shot's shot size.
  final String legendShotSizeHeader;

  /// The legend's column header naming a shot's framing.
  final String legendFramingHeader;

  /// The legend's column header naming a shot's camera move.
  final String legendCameraMoveHeader;

  /// The heading of the summary page.
  final String summaryTitle;

  /// The summary's column header naming a sequence.
  final String summarySequenceHeader;

  /// The summary's column header naming how many shots a sequence holds.
  final String summaryShotCountHeader;

  /// The summary's column header naming the share of a sequence's words at least one shot covers.
  final String summaryCoveredHeader;

  /// The summary's column header naming how many of a sequence's coverage ranges are stale.
  final String summaryStaleHeader;

  /// The summary's column header naming the passages of a sequence no shot covers.
  final String summaryUncoveredHeader;

  /// The note printed under the summary when a page held more bars than its margins have lanes for,
  /// so some of them had to share the outermost lane.
  final String laneOverflowNote;

  /// The title of each sequence, keyed by `OcptShotSequence.id`, used both to group the legend's
  /// rows and to name the summary's.
  ///
  /// A real scene's own `Sequence 1 — INT. …` header and the orphan group's title are both
  /// localized messages taking the scene's number and heading as placeholders, so they are resolved
  /// sequence by sequence by the caller rather than formatted here — exactly as
  /// [OcptShotListXlsxLabels.sequenceTitles] already is.
  final Map<String, String> sequenceTitles;

  /// Class constructor
  const OcptScenarioCoverageLabels({
    required this.fileNameSuffix,
    required this.legendTitle,
    required this.legendShotHeader,
    required this.legendShotSizeHeader,
    required this.legendFramingHeader,
    required this.legendCameraMoveHeader,
    required this.summaryTitle,
    required this.summarySequenceHeader,
    required this.summaryShotCountHeader,
    required this.summaryCoveredHeader,
    required this.summaryStaleHeader,
    required this.summaryUncoveredHeader,
    required this.laneOverflowNote,
    required this.sequenceTitles,
  });

  /// The title of the sequence [sequenceId], or an empty string if [sequenceTitles] holds none for
  /// it.
  String titleOfSequence(String sequenceId) => sequenceTitles[sequenceId] ?? "";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptScenarioCoverageLabels(legendTitle: $legendTitle)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    legendTitle,
    legendShotHeader,
    legendShotSizeHeader,
    legendFramingHeader,
    legendCameraMoveHeader,
    summaryTitle,
    summarySequenceHeader,
    summaryShotCountHeader,
    summaryCoveredHeader,
    summaryStaleHeader,
    summaryUncoveredHeader,
    laneOverflowNote,
    sequenceTitles,
  ];
}
