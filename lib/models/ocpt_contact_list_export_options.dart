// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off contact list export runs with: the physical page [format], paired with
/// [margins].
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with (`OcptContactListExportDialog` never lets the user edit it, only the page [format]),
/// exactly as `OcptBreakdownSheetsExportOptions` does, and these options are never persisted — they
/// only exist for the single export they were built for.
///
/// Deliberately its own class rather than reusing `OcptBreakdownSheetsExportOptions`: the two
/// exports are dispatched by two different modes through two different events, and a shared options
/// class would make one mode's dialog able to produce something the other's service would silently
/// ignore.
class OcptContactListExportOptions extends Equatable {
  /// The physical page format to typeset the exported document with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported document with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// Class constructor
  const OcptContactListExportOptions({required this.format, required this.margins});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptContactListExportOptions(format: $format, margins: $margins)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins];
}
