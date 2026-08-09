// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The options a one-off shooting plan **workbook** export runs with: which days are printed, and
/// nothing else.
///
/// Deliberately narrower than `OcptShootingPlanExportOptions`, its PDF sibling: there is no page
/// format or margins to ask about (a workbook has no page), no title page and no per-grid toggle (a
/// sheet costs nothing to hide once written, unlike a PDF page that had to be laid out to be
/// skipped) — the export panel's own card goes straight from picking days to writing the file.
class OcptShootingPlanXlsxExportOptions extends Equatable {
  /// The ids of the `OcptShootingDay`s to print, in the order they are printed — both as the four
  /// summary grids' own columns and as the `Chronology` sheet's own rows.
  final List<String> dayIds;

  /// Class constructor
  const OcptShootingPlanXlsxExportOptions({required this.dayIds});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingPlanXlsxExportOptions(dayIds: $dayIds)";

  /// Object properties
  @override
  List<Object?> get props => [dayIds];
}
