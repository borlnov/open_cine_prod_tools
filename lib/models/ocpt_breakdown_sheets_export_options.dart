// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off breakdown sheets export runs with: the physical page [format], its
/// [margins], which scenes are printed ([onlyDoneScenes]) and the two sections a sheet may leave
/// out ([includeNotes]/[includeToFindList]).
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with (`OcptBreakdownSheetsExportDialog` never lets the user edit it, only the page
/// [format]), exactly as `OcptScenarioCoverageExportOptions` does, and these options are never
/// persisted — they only exist for the single export they were built for.
///
/// Deliberately its own class rather than `OcptScenarioCoverageExportOptions` with its toggles
/// swapped: the two exports are dispatched by two different modes through two different events,
/// and a shared options class would make one mode's dialog able to produce something the other's
/// service would silently ignore.
class OcptBreakdownSheetsExportOptions extends Equatable {
  /// The physical page format to typeset the exported document with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported document with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// Whether only the scenes marked `done` are printed, rather than every scene of the screenplay.
  ///
  /// Off by default: the sheets are what a department head reads to prepare, and a scene half
  /// broken down is still a scene they have to prepare for. Turning it on is how the person doing
  /// the pass prints only what they have actually finished.
  final bool onlyDoneScenes;

  /// Whether a scene's own breakdown notes are printed under its meta band.
  final bool includeNotes;

  /// Whether a scene's closing "still to find" list is printed.
  final bool includeToFindList;

  /// Class constructor
  const OcptBreakdownSheetsExportOptions({
    required this.format,
    required this.margins,
    required this.onlyDoneScenes,
    required this.includeNotes,
    required this.includeToFindList,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBreakdownSheetsExportOptions(format: $format, margins: $margins, "
      "onlyDoneScenes: $onlyDoneScenes, includeNotes: $includeNotes, "
      "includeToFindList: $includeToFindList)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins, onlyDoneScenes, includeNotes, includeToFindList];
}
