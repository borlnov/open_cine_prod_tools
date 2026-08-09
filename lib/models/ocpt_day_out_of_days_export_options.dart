// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off *Day Out of Days* export runs with: the physical page [format], its
/// [margins], which days are crossed, and whether the title page is printed.
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with, exactly as `OcptShootingPlanExportOptions.margins` is, and these options are never
/// persisted — they only exist for the single export they were built for.
///
/// Deliberately its own class rather than one of its siblings with fields added, for the reason
/// `OcptShootingPlanExportOptions`'s own doc comment already gives: each schedule export is
/// dispatched by its own event, and a shared options class would let one dialog produce something
/// another service silently ignores.
class OcptDayOutOfDaysExportOptions extends Equatable {
  /// The physical page format to typeset the exported document with. The table itself is always
  /// printed landscape regardless (`OcptDayOutOfDaysPdfService`'s own doc comment); this is the
  /// format the title page is typeset with, and the paper the landscape pages are that of turned on
  /// its side.
  final OcptPageFormat format;

  /// The page margins to typeset the exported document with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// The ids of the `OcptShootingDay`s to cross, in the order they are printed — the table's own
  /// columns, and the order every `SW`/`WF` reading rests on (`ocptComputeDayOutOfDays`).
  final List<String> dayIds;

  /// Whether the title page (the document's own name, `"<title>" de <director>` and the version
  /// line) is printed first.
  final bool includeTitlePage;

  /// Class constructor
  const OcptDayOutOfDaysExportOptions({
    required this.format,
    required this.margins,
    required this.dayIds,
    required this.includeTitlePage,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptDayOutOfDaysExportOptions(format: $format, margins: $margins, dayIds: $dayIds, "
      "includeTitlePage: $includeTitlePage)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins, dayIds, includeTitlePage];
}
