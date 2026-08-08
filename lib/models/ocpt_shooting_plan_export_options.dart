// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off shooting plan export runs with: the physical page [format], its [margins],
/// which days are printed, and a toggle per optional section — the title page and the three summary
/// grids.
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with, exactly as `OcptBreakdownSheetsExportOptions.margins`/
/// `OcptScenarioCoverageExportOptions.margins` are, and these options are never persisted — they
/// only exist for the single export they were built for.
///
/// Deliberately its own class rather than one of its three siblings with fields added: the four
/// schedule and screenplay exports are each dispatched by their own mode through their own event,
/// and a shared options class would make one mode's dialog able to produce something another
/// mode's service would silently ignore.
class OcptShootingPlanExportOptions extends Equatable {
  /// The physical page format to typeset the exported document with. The three summary grids are
  /// always printed landscape regardless (`OcptShootingPlanPdfService`'s own doc comment); this is
  /// the format every detailed day agenda, portrait, and the title page are typeset with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported document with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// The ids of the `OcptShootingDay`s to print, in the order they are printed — both as the three
  /// summary grids' own columns and as the detailed day agendas that follow them.
  final List<String> dayIds;

  /// Whether the title page (the document's own name, `"<title>" de <director>`, and the date the
  /// export was run) is printed first.
  final bool includeTitlePage;

  /// Whether the locations summary grid is printed.
  final bool includeLocationsGrid;

  /// Whether the sequences summary grid is printed.
  final bool includeSequencesGrid;

  /// Whether the crew and cast summary grid is printed.
  final bool includePeopleGrid;

  /// Class constructor
  const OcptShootingPlanExportOptions({
    required this.format,
    required this.margins,
    required this.dayIds,
    required this.includeTitlePage,
    required this.includeLocationsGrid,
    required this.includeSequencesGrid,
    required this.includePeopleGrid,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingPlanExportOptions(format: $format, margins: $margins, dayIds: $dayIds, "
      "includeTitlePage: $includeTitlePage, includeLocationsGrid: $includeLocationsGrid, "
      "includeSequencesGrid: $includeSequencesGrid, includePeopleGrid: $includePeopleGrid)";

  /// Object properties
  @override
  List<Object?> get props => [
    format,
    margins,
    dayIds,
    includeTitlePage,
    includeLocationsGrid,
    includeSequencesGrid,
    includePeopleGrid,
  ];
}
