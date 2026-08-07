// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off call sheet export runs with: the physical page [format], its [margins],
/// which days are printed, and — for the named variant alone — which of a day's own convoked
/// people or roles are printed.
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with, exactly as `OcptBreakdownSheetsExportOptions.margins` is, and these options are
/// never persisted — they only exist for the single export they were built for.
///
/// Deliberately its own class rather than reusing one of its three siblings with a field added: the
/// general and named sheets are dispatched from the same `⋮` menu entry but write a *folder* of
/// files rather than one, through `OcptExportManager.exportGeneralCallSheets`/
/// `exportNamedCallSheets`, and [dayIds]/[selectedConvocationKeys] are what tell those two apart
/// from a single-file export like `OcptBreakdownSheetsExportOptions`.
class OcptCallSheetExportOptions extends Equatable {
  /// The physical page format to typeset the exported documents with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported documents with, carried through unedited from the
  /// page setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// The ids of the `OcptShootingDay`s to print, in the order they are printed. One general sheet is
  /// written per entry; a named export prints exactly one day (§4 of `docs/plans/schedule-mode.md`),
  /// so it holds a single id.
  final List<String> dayIds;

  /// For a named export alone: which of [dayIds]' single day's own convoked people or roles are
  /// printed, one file each — keyed the same way `OcptDayConvocation` discriminates its own subject,
  /// a person's `id` or an uncast role's, so a caller can select straight out of the one list
  /// `OcptSchedulePlanSnapshot.convocationsOfDay` already returns. Empty (and unused) for a general
  /// export, which always prints every day it names in full.
  final Set<String> selectedConvocationKeys;

  /// Class constructor
  const OcptCallSheetExportOptions({
    required this.format,
    required this.margins,
    required this.dayIds,
    this.selectedConvocationKeys = const {},
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptCallSheetExportOptions(format: $format, margins: $margins, "
      "dayIds: $dayIds, selectedConvocationKeys: $selectedConvocationKeys)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins, dayIds, selectedConvocationKeys];
}
