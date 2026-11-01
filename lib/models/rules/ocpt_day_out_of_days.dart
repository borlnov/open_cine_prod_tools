// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_day_out_of_days_day.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_out_of_days_row.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_out_of_days_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_out_of_days_code.dart';

/// Compute the *Day Out of Days* of [days] over [roleIds] — the most standard cast-scheduling
/// document there is, and one this app already holds every figure for.
///
/// [days] comes in **in printing order** (the schedule mode's own date order), and [roleIds] in the
/// order the rows are drawn in (the mode's own role numbers). Both orders are the caller's and are
/// preserved verbatim: see [OcptDayOutOfDaysTable]'s own doc comment for why the day order is what
/// the whole reading rests on.
///
/// **A role convoked on no day of [days] gets no row at all.** Its row would be blank from end to
/// end, indistinguishable from a role whose span simply holds no hold day, and it would push the
/// rows a reader is actually looking for off the page — a screenplay reconciles a speaking role for
/// every character that opens its mouth, most of which a given week never calls. That a cast role
/// is scheduled nowhere is a real thing to notice, and it is noticed in the app, where
/// `OcptScheduleRoleNotConvokedAlert` and the `Convocations` panel say it against the day it
/// concerns; a column of blanks on a printed grid is not where anybody would find it.
///
/// A [roleIds] entry repeated by the caller yields one row, the first occurrence's own position
/// keeping its place: the rows are keyed by role, and two rows about one part would each claim to
/// be its whole schedule.
OcptDayOutOfDaysTable ocptComputeDayOutOfDays({
  required List<OcptDayOutOfDaysDay> days,
  required List<String> roleIds,
}) {
  if (days.isEmpty) {
    return const OcptDayOutOfDaysTable.empty();
  }

  final dayIds = [for (final day in days) day.id];
  final rows = <OcptDayOutOfDaysRow>[];
  final seenRoleIds = <String>{};

  for (final roleId in roleIds) {
    if (!seenRoleIds.add(roleId)) {
      continue;
    }

    final workedIndexes = [
      for (final (index, day) in days.indexed)
        if (day.convokedRoleIds.contains(roleId)) index,
    ];
    if (workedIndexes.isEmpty) {
      continue;
    }

    final firstIndex = workedIndexes.first;
    final lastIndex = workedIndexes.last;
    final workedIndexSet = workedIndexes.toSet();

    final codeByDayId = <String, OcptDayOutOfDaysCode>{};
    for (var index = firstIndex; index <= lastIndex; index++) {
      codeByDayId[days[index].id] = _codeAt(
        index: index,
        firstIndex: firstIndex,
        lastIndex: lastIndex,
        isWorked: workedIndexSet.contains(index),
      );
    }

    rows.add(
      OcptDayOutOfDaysRow(
        roleId: roleId,
        codeByDayId: Map.unmodifiable(codeByDayId),
        workedDayCount: workedIndexes.length,
        heldDayCount: codeByDayId.length - workedIndexes.length,
      ),
    );
  }

  return OcptDayOutOfDaysTable(dayIds: List.unmodifiable(dayIds), rows: List.unmodifiable(rows));
}

/// Get the code of the day at [index], inside a role's own `[firstIndex, lastIndex]` span:
/// [OcptDayOutOfDaysCode.hold] while the role is not convoked there, and one of the three worked
/// codes otherwise — [OcptDayOutOfDaysCode.startWorkFinish] on the one cell where the span's two
/// ends meet.
OcptDayOutOfDaysCode _codeAt({
  required int index,
  required int firstIndex,
  required int lastIndex,
  required bool isWorked,
}) {
  if (!isWorked) {
    return OcptDayOutOfDaysCode.hold;
  }
  if (index == firstIndex && index == lastIndex) {
    return OcptDayOutOfDaysCode.startWorkFinish;
  }
  if (index == firstIndex) {
    return OcptDayOutOfDaysCode.startWork;
  }
  if (index == lastIndex) {
    return OcptDayOutOfDaysCode.workFinish;
  }
  return OcptDayOutOfDaysCode.work;
}
