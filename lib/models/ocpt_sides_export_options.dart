// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off sides export runs with: the physical page [format], its [margins], the one
/// day printed, whether scene numbers are printed, and which [presentation] the booklet is laid out
/// in.
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with, exactly as `OcptOneLineScheduleExportOptions.margins` is, and these options are
/// never persisted — they only exist for the single export they were built for.
///
/// [dayId] is a **single** day where every other schedule export carries a list: a booklet of sides
/// is one day's own paperwork, stapled and handed round on the morning of that day, so printing two
/// of them at once would be printing two documents rather than a longer one.
///
/// Deliberately its own class rather than one of its siblings with fields added, for the reason
/// `OcptShootingPlanExportOptions`'s own doc comment already gives: each schedule export is
/// dispatched by its own event, and a shared options class would let one dialog produce something
/// another service silently ignores.
class OcptSidesExportOptions extends Equatable {
  /// The physical page format to typeset the exported booklet with. Unlike the four other schedule
  /// documents, this one is typeset **portrait**, being the screenplay's own pages: the format is
  /// the paper those pages are printed on rather than a table's own sheet.
  final OcptPageFormat format;

  /// The page margins to typeset the exported booklet with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// The id of the one `OcptShootingDay` whose scenes are printed — see the class doc comment for
  /// why there is only ever one.
  final String dayId;

  /// Whether a scene heading prints its own scene number in both margins, exactly as the screenplay
  /// PDF export's own option does.
  final bool includeSceneNumbers;

  /// Whether the booklet reproduces the screenplay's own pages or packs its extracts onto fresh
  /// ones — see [OcptSidesPresentation] for what each keeps and what it gives up.
  final OcptSidesPresentation presentation;

  /// Class constructor
  const OcptSidesExportOptions({
    required this.format,
    required this.margins,
    required this.dayId,
    required this.includeSceneNumbers,
    required this.presentation,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptSidesExportOptions(format: $format, margins: $margins, dayId: $dayId, "
      "includeSceneNumbers: $includeSceneNumbers, presentation: $presentation)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins, dayId, includeSceneNumbers, presentation];
}
