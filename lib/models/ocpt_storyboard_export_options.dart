// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off storyboard export runs with: the physical page [format], its [margins]
/// (carried through unedited from the `OcptPageSetup` the dialog was opened with, exactly as
/// `OcptScenarioCoverageExportOptions.margins` is), how many shots [shotsPerPage] print before the
/// document breaks onto a fresh page, and whether the floor plan sheets are appended after each
/// sequence's own shots ([includeFloorPlansAfterEachSequence]).
///
/// Never persisted: these options only exist for the single export they were built for, exactly
/// like their scenario coverage sibling.
class OcptStoryboardExportOptions extends Equatable {
  /// The physical page format to typeset the exported document with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported document with, carried through unedited from the
  /// page setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// How many shots print on one page before the document breaks onto a fresh one.
  final int shotsPerPage;

  /// Whether the floor plan sheets of each sequence — the very ones `OcptFloorPlanPdfService`
  /// prints on its own — are appended right after that sequence's own shot rows, so the two
  /// documents can also travel as one (`docs/plans/storyboard.md`, §5, §8 decision 8).
  final bool includeFloorPlansAfterEachSequence;

  /// Class constructor
  const OcptStoryboardExportOptions({
    required this.format,
    required this.margins,
    required this.shotsPerPage,
    required this.includeFloorPlansAfterEachSequence,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptStoryboardExportOptions(format: $format, shotsPerPage: $shotsPerPage, "
      "includeFloorPlansAfterEachSequence: $includeFloorPlansAfterEachSequence)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins, shotsPerPage, includeFloorPlansAfterEachSequence];
}
