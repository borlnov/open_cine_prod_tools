// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What one cell of a *Day Out of Days* says about a role on a day.
///
/// Five values for **four codes plus their collision**, and every one of them is *derived* from the
/// schedule alone — which is the whole rule this document is built on. The two codes a standard
/// *Day Out of Days* also carries, `T` (travel) and `R` (rehearsal), are deliberately absent: no
/// field of this app says either, and the one column that could once have carried travel was the
/// presence override schema v17 dropped. Printing a `T` nobody entered would be this app inventing
/// a paid day; if a production ever needs one, it comes back as a **typed** fact with a table of its
/// own, never as a code guessed here.
enum OcptDayOutOfDaysCode {
  /// The role's own **first** convoked day of the printed range, and not also its last (`SW`).
  startWork,

  /// A day the role is convoked on, between its first and its last (`W`).
  work,

  /// The role's own **last** convoked day of the printed range, and not also its first (`WF`).
  workFinish,

  /// The role's own first **and** last convoked day, being convoked on exactly one day of the
  /// printed range (`SWF`).
  ///
  /// Not a fifth kind of information, and not the `T`/`R` this document refuses to guess: it is the
  /// one cell on which [startWork] and [workFinish] fall together, and it is derived from exactly
  /// the same reading as either of them. Printing a bare `SW` there would say the role starts and
  /// never finishes — a claim about the plan that the plan does not make.
  startWorkFinish,

  /// A day **between** the role's own first and last convoked days on which it is not convoked at
  /// all (`H`) — the days a production still owes an actor because it has not released them.
  hold,
}

/// One day of the printed range, as fed to [ocptComputeDayOutOfDays]: its own id and the roles it
/// convokes.
///
/// [convokedRoleIds] names **roles**, never actors: a *Day Out of Days* is negotiated per part, an
/// uncast role is exactly as scheduled as a cast one, and recasting must not redraw this table. It
/// is a fact about the day as a whole, joined across every one of its slots by the caller — this
/// file knows nothing of slots, of `shooting_slot_cast` or of drift.
class OcptDayOutOfDaysDay {
  /// Class constructor
  const OcptDayOutOfDaysDay({required this.id, required this.convokedRoleIds});

  /// The day's own id (`shooting_days.id`).
  final String id;

  /// The ids of every role this day convokes, on any of its own slots.
  final Set<String> convokedRoleIds;
}

/// One role's own row of the table: its code on each day it has one, and the two counts a printed
/// row trails.
///
/// [codeByDayId] holds an entry **only inside the role's own span** — from its first convoked day of
/// the printed range to its last, inclusive. A day before the first or after the last carries no
/// entry at all rather than a code meaning "not working": the role is simply not on this shoot yet,
/// or no longer is, and a mark there would be a claim about days the production has not committed.
class OcptDayOutOfDaysRow extends Equatable {
  /// Class constructor
  const OcptDayOutOfDaysRow({
    required this.roleId,
    required this.codeByDayId,
    required this.workedDayCount,
    required this.heldDayCount,
  });

  /// The role this row is about (`roles.id`).
  final String roleId;

  /// This role's own code per day, keyed by `shooting_days.id` — see the class doc comment for why
  /// a day outside its span has no entry.
  final Map<String, OcptDayOutOfDaysCode> codeByDayId;

  /// How many days of the printed range this role is convoked on — every cell but
  /// [OcptDayOutOfDaysCode.hold], so always at least 1 (a row exists only for a role convoked
  /// somewhere, see [ocptComputeDayOutOfDays]).
  final int workedDayCount;

  /// How many [OcptDayOutOfDaysCode.hold] days this role's own span holds — the days it is owed
  /// without being called.
  final int heldDayCount;

  /// This role's own code on [dayId], or null when [dayId] falls outside its span.
  OcptDayOutOfDaysCode? codeOf(String dayId) => codeByDayId[dayId];

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptDayOutOfDaysRow(roleId: $roleId, worked: $workedDayCount, held: $heldDayCount)";

  /// Object properties
  @override
  List<Object?> get props => [roleId, codeByDayId, workedDayCount, heldDayCount];
}

/// A whole *Day Out of Days*: one column per day of the printed range, one row per role that range
/// actually convokes, and a code in every cell inside a role's own span.
///
/// Pure Dart on purpose (no `pdf`, no Flutter, no drift, no `Tr`): the shape
/// `OcptShootingDayAgendaGrid` and `OcptScenarioCoverageLayout` already have, and for the same
/// reason — every rule lives here, where it is tested against exact cells, and the PDF service that
/// consumes it is left with nothing but drawing and ordering.
///
/// **The order of [dayIds] is the caller's**, and it is what the whole reading rests on: "first" and
/// "last" mean first and last *in that order*, so a caller handing the days in anything but
/// chronological order gets a table about that other order rather than a wrong one. The schedule
/// mode ranks its days by date (`OcptShootingDay.dayNumber` is a read-time rank over exactly that
/// order), so the printed document reads chronologically without this file ever learning what a
/// date is.
///
/// **A day the printed range skips is not a gap.** Only the days handed in are columns, so a range
/// printed for the second week alone reads that week's own first and last convoked days as `SW` and
/// `WF` — the honest reading of a document that says, on its face, which days it covers.
class OcptDayOutOfDaysTable extends Equatable {
  /// Class constructor
  const OcptDayOutOfDaysTable({required this.dayIds, required this.rows});

  /// The empty table: no day, no row — what a range naming no day, or one no role is convoked
  /// anywhere in, computes to. The caller prints a note rather than a table with no cell.
  const OcptDayOutOfDaysTable.empty() : dayIds = const [], rows = const [];

  /// The days this table crosses, in the order given to [ocptComputeDayOutOfDays] — the columns.
  final List<String> dayIds;

  /// One row per role convoked at least once over [dayIds], in the order the roles were given.
  final List<OcptDayOutOfDaysRow> rows;

  /// Whether there is nothing at all to draw — no column, or no role convoked anywhere in the
  /// range.
  bool get isEmpty => dayIds.isEmpty || rows.isEmpty;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptDayOutOfDaysTable(days: ${dayIds.length}, rows: ${rows.length})";

  /// Object properties
  @override
  List<Object?> get props => [dayIds, rows];
}

/// Computes the *Day Out of Days* of [days] over [roleIds] — the most standard cast-scheduling
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
/// every character that opens its mouth, most of which a given week never calls. That a cast role is
/// scheduled nowhere is a real thing to notice, and it is noticed in the app, where
/// `OcptScheduleRoleNotConvokedAlert` and the `Convocations` panel say it against the day it
/// concerns; a column of blanks on a printed grid is not where anybody would find it.
///
/// A [roleIds] entry repeated by the caller yields one row, the first occurrence's own position
/// keeping its place: the rows are keyed by role, and two rows about one part would each claim to be
/// its whole schedule.
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

/// The code of the day at [index], inside a role's own `[firstIndex, lastIndex]` span:
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
