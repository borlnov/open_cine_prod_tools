// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_out_of_days.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_out_of_days_row.dart';

/// A whole *Day Out of Days*: one column per day of the printed range, one row per role that range
/// actually convokes, and a code in every cell inside a role's own span.
///
/// Pure Dart on purpose (no `pdf`, no Flutter, no drift, no `Tr`): the shape
/// `OcptShootingDayAgendaGrid` and `OcptScenarioCoverageLayout` already have, and for the same
/// reason — every rule lives here, where it is tested against exact cells, and the PDF service that
/// consumes it is left with nothing but drawing and ordering.
///
/// **The order of [dayIds] is the caller's**, and it is what the whole reading rests on: "first"
/// and "last" mean first and last *in that order*, so a caller handing the days in anything but
/// chronological order gets a table about that other order rather than a wrong one. The schedule
/// mode ranks its days by date (`OcptShootingDay.dayNumber` is a read-time rank over exactly that
/// order), so the printed document reads chronologically without this file ever learning what a
/// date is.
///
/// **A day the printed range skips is not a gap.** Only the days handed in are columns, so a range
/// printed for the second week alone reads that week's own first and last convoked days as `SW` and
/// `WF` — the honest reading of a document that says, on its face, which days it covers.
class OcptDayOutOfDaysTable extends Equatable {
  /// The days this table crosses, in the order given to [ocptComputeDayOutOfDays] — the columns.
  final List<String> dayIds;

  /// One row per role convoked at least once over [dayIds], in the order the roles were given.
  final List<OcptDayOutOfDaysRow> rows;

  /// Whether there is nothing at all to draw — no column, or no role convoked anywhere in the
  /// range.
  bool get isEmpty => dayIds.isEmpty || rows.isEmpty;

  /// Class constructor
  const OcptDayOutOfDaysTable({required this.dayIds, required this.rows});

  /// The empty table: no day, no row — what a range naming no day, or one no role is convoked
  /// anywhere in, computes to. The caller prints a note rather than a table with no cell.
  const OcptDayOutOfDaysTable.empty() : dayIds = const [], rows = const [];

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptDayOutOfDaysTable(days: ${dayIds.length}, rows: ${rows.length})";

  /// Object properties
  @override
  List<Object?> get props => [dayIds, rows];
}
