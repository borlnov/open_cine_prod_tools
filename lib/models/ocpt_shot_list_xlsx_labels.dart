// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Every localized string the exported shot list workbook carries, resolved by the caller.
///
/// `OcptShotListXlsxExportService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptExportManager`'s other exports already take their
/// native dialog's `fileTypeLabel` from their caller. The UI builds this once through
/// `ocptShotListXlsxLabelsOf`, which is also what keeps a sheet's headers named exactly as the
/// table's own columns are.
class OcptShotListXlsxLabels extends Equatable {
  /// The name given to the workbook's single sheet.
  final String sheetName;

  /// The header label of every column of the sheet.
  ///
  /// Holds an entry for every [OcptShotListXlsxColumn]; a column missing from it is written with
  /// an empty header rather than being skipped, so a forgotten label can never shift the columns
  /// out of step with their values.
  final Map<OcptShotListXlsxColumn, String> columnHeaders;

  /// The label written in the status column for every shooting status.
  final Map<OcptShotStatus, String> statusLabels;

  /// The title of the separator row introducing each sequence, keyed by `OcptShotSequence.id`.
  ///
  /// A real scene's own `Sequence 1 — INT. …` header and the orphan group's title are both
  /// localized messages taking the scene's number and heading as placeholders, so they are
  /// resolved sequence by sequence by the caller rather than formatted here.
  final Map<String, String> sequenceTitles;

  /// The single letter printed before a day's rank, **one per `OcptShootingDayKind`**: `D`/`J` for
  /// a shooting day, `C` for a casting day, `R` for a rehearsal.
  ///
  /// Three rather than one because the three kinds are ranked in three separate series
  /// (`OcptShootingDay.dayNumber`), so a placement's own number means nothing without the letter
  /// its day's kind wears. Resolved by the caller, there being no `Tr` here, and reused rather than
  /// reimplemented so a placement cell never disagrees with the shot list's own
  /// `ocptScheduleDayTagLabel` read-out.
  ///
  /// A shot normally sits on a day that shoots; the other two entries exist because nothing forbids
  /// a block outliving a change of kind, and a cell must print the tag the day actually wears.
  final Map<OcptShootingDayKind, String> dayTagPrefixes;

  /// Class constructor
  const OcptShotListXlsxLabels({
    required this.sheetName,
    required this.columnHeaders,
    required this.statusLabels,
    required this.sequenceTitles,
    required this.dayTagPrefixes,
  });

  /// The header of [column], or an empty string if [columnHeaders] holds none for it.
  String headerOf(OcptShotListXlsxColumn column) => columnHeaders[column] ?? "";

  /// The label of [status], or an empty string if [statusLabels] holds none for it.
  String labelOf(OcptShotStatus status) => statusLabels[status] ?? "";

  /// The separator row title of the sequence [sequenceId], or an empty string if
  /// [sequenceTitles] holds none for it.
  String titleOfSequence(String sequenceId) => sequenceTitles[sequenceId] ?? "";

  /// The day tag letter of [kind], or an empty string if [dayTagPrefixes] holds none for it — a
  /// tag reading `3` alone rather than a cell claiming a kind nobody resolved a letter for.
  String dayTagPrefixOf(OcptShootingDayKind kind) => dayTagPrefixes[kind] ?? "";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShotListXlsxLabels(sheetName: $sheetName)";

  /// Object properties
  @override
  List<Object?> get props => [
    sheetName,
    columnHeaders,
    statusLabels,
    sequenceTitles,
    dayTagPrefixes,
  ];
}
