// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off scenario coverage export runs with: the physical page [format], its
/// [margins], the two content toggles the screenplay PDF export already has
/// ([includeSceneNumbers]/[includeTitlePage]), and one per appendix page
/// ([includeLegendPage]/[includeSummaryPage]).
///
/// The screenplay half of this list is `OcptPdfExportOptions`' own, and behaves identically: the
/// coverage document prints the very same screenplay, only annotated. [margins] is likewise always
/// carried through unedited from the `OcptPageSetup` the export dialog was opened with
/// (`OcptScenarioCoverageExportDialog` never lets the user edit it, only the page [format]), and
/// these options are never persisted — they only exist for the single export they were built for.
///
/// Deliberately not `OcptPdfExportOptions` with two fields added: the two exports are dispatched by
/// two different modes through two different events, and a shared options class would make the shot
/// list's own dialog able to produce something the screenplay editor would silently ignore.
class OcptScenarioCoverageExportOptions extends Equatable {
  /// The physical page format to typeset the exported document with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported document with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// Whether scene numbers are printed in both margins opposite each scene heading.
  final bool includeSceneNumbers;

  /// Whether a title page is generated from the screenplay's title-page metadata.
  final bool includeTitlePage;

  /// Whether the legend page — every shot, its colour swatch, its label, its shot size, framing and
  /// camera move — is printed ahead of the screenplay.
  final bool includeLegendPage;

  /// Whether the summary page — per sequence, the covered share, the shot count and the passages
  /// left uncovered — is printed ahead of the screenplay.
  final bool includeSummaryPage;

  /// Class constructor
  const OcptScenarioCoverageExportOptions({
    required this.format,
    required this.margins,
    required this.includeSceneNumbers,
    required this.includeTitlePage,
    required this.includeLegendPage,
    required this.includeSummaryPage,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptScenarioCoverageExportOptions(format: $format, margins: $margins, "
      "includeSceneNumbers: $includeSceneNumbers, includeTitlePage: $includeTitlePage, "
      "includeLegendPage: $includeLegendPage, includeSummaryPage: $includeSummaryPage)";

  /// Object properties
  @override
  List<Object?> get props => [
    format,
    margins,
    includeSceneNumbers,
    includeTitlePage,
    includeLegendPage,
    includeSummaryPage,
  ];
}
