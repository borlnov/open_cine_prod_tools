// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_column.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_column_input.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_event_input.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_event_marker.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_event_placement.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_tile.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';

/// A day's own timetable, read as a grid: rows every [stepMinutes] from the day's earliest
/// resolved start to its latest resolved end, one column per slot, a block drawn as a tile
/// spanning the rows its band covers, an event drawn as a full-width marker — inside the grid on
/// its own row, or leading/trailing just outside it when its own minute falls beyond the blocks'
/// own band (see the "its bounds" paragraph below).
///
/// Pure Dart on purpose (no `pdf`, no Flutter, no drift): exactly the shape
/// `OcptScenarioCoverageLayout` already is, and for the same reason — every rule lives here, where
/// it can be tested against exact rows, and the PDF service that consumes it is left with nothing
/// but drawing.
///
/// **Its bounds.** [startMinute] is the earliest of every column's own resolved start
/// ([OcptShootingSlotTimeline.startMinute], which a slot always has, blocks or none) and
/// [endMinute] the latest of every column's own resolved end (its
/// [OcptShootingSlotTimeline.endMinute], or that same start when the slot carries no block at all
/// — the `endMinute ?? startMinute` convention `ocptComputeShootingDayTimelines` already applies),
/// both then snapped **outward** onto [stepMinutes] so the first and the last row are always whole.
/// **An event plays no part in this span** — a deliberate difference from the schedule mode's own
/// on-screen week grid (`OcptScheduleWeekGrid`), which does stretch its hour range to reach one.
/// That grid is read by scrolling, so widening it costs nothing; this one is a printed page, where
/// the very same stretch turns a day shooting 07:00–12:00 with one event pinned at 17:00 into
/// thirty-odd blank rows and a second page to reach a single marker — worse than the problem it
/// would have solved. An event outside `[startMinute, endMinute)` is instead drawn at the edge it
/// falls beyond, adjacent to the grid with no blank row in between
/// ([OcptShootingDayAgendaEventPlacement.beforeGrid]/`.afterGrid`); only one that already falls
/// inside the blocks' own band gets a row of its own (`.inGrid`), exactly as before this placement
/// existed.
///
/// **A block that does not fall on tens.** A 12-minute block on a 10-minute grid spans the rows it
/// touches — [OcptShootingDayAgendaTile.rowSpan] rounds up rather than down, so a block is never
/// drawn shorter than it runs — and its **exact** times are carried on the tile
/// ([OcptShootingDayAgendaTile.startMinute]/`.endMinute`) for the caller to print inside it: the
/// grid is a reading aid, never a claim that everything falls on tens.
///
/// **Two slots whose chains overlap.** They are separate columns and do not interact at all here —
/// that is what slots are for, and this class draws no relationship between them beyond sharing
/// one set of rows. Overlap is legal, never a conflict, exactly as
/// `ocptComputeShootingDayTimelines`'s own doc comment already argues.
///
/// **A night crossing midnight.** Every minute here is an offset from the day's own midnight and
/// **may exceed 1440**; nothing is ever taken modulo anything. `ocptFormatDayMinute` is the only
/// thing in this app that ever wraps one onto a clock face, and it lives at the drawing end, never
/// here.
///
/// **A day with nothing on it.** [columns] being empty — the day carries no live slot at all — is
/// the one case [isEmpty] answers true for, and the only bound this class ever refuses to compute:
/// a column carrying no block still has a row (its own resolved start), so a slot with an empty
/// timetable is not "nothing", only a day with no slot is. The caller reads [isEmpty] and prints a
/// note instead of a zero-row table.
class OcptShootingDayAgendaGrid extends Equatable {
  /// The number of minutes one row of the grid spans — fixed, not configurable: a finer or coarser
  /// grid is a different document.
  static const int stepMinutes = 10;

  /// Class constructor
  const OcptShootingDayAgendaGrid({
    required this.isEmpty,
    required this.startMinute,
    required this.endMinute,
    required this.columns,
    required this.tiles,
    required this.events,
  });

  /// The empty grid: no column, no tile, no event — see the class doc comment's own "day with
  /// nothing on it" paragraph.
  const OcptShootingDayAgendaGrid.empty()
    : isEmpty = true,
      startMinute = 0,
      endMinute = 0,
      columns = const [],
      tiles = const [],
      events = const [];

  /// Whether this grid has nothing to draw at all — [columns] came in empty, so no bound could be
  /// computed. A caller must check this before reading [rowCount] or drawing anything.
  final bool isEmpty;

  /// The grid's own first row's start minute, already snapped down onto [stepMinutes]. Meaningless
  /// while [isEmpty].
  final int startMinute;

  /// The grid's own last row's end minute, already snapped up onto [stepMinutes] — always strictly
  /// greater than [startMinute] once the grid holds anything at all. Meaningless while [isEmpty].
  final int endMinute;

  /// One entry per slot with a live timetable that day, in the order given to
  /// [OcptShootingDayAgendaGrid.of].
  final List<OcptShootingDayAgendaColumn> columns;

  /// Every block placed as a tile, across every column.
  final List<OcptShootingDayAgendaTile> tiles;

  /// Every event, each carrying its own [OcptShootingDayAgendaEventPlacement] — inside the grid's
  /// own rows, or leading/trailing just outside them.
  final List<OcptShootingDayAgendaEventMarker> events;

  /// How many [stepMinutes]-wide rows the grid holds, 0 while [isEmpty].
  int get rowCount => isEmpty ? 0 : (endMinute - startMinute) ~/ stepMinutes;

  /// Builds the grid from [columns]' own resolved timelines and [events], both pure inputs — see
  /// this class's own doc comment for the rules this applies.
  ///
  /// [columns] carries one entry per slot the caller wants a column for, in the order the columns
  /// are drawn in — ordinarily every live slot of the day, in `sortKey` order, exactly as
  /// `OcptShootingDayTimelines.bySlotId` is walked elsewhere in this mode.
  factory OcptShootingDayAgendaGrid.of({
    required List<OcptShootingDayAgendaColumnInput> columns,
    required List<OcptShootingDayAgendaEventInput> events,
  }) {
    if (columns.isEmpty) {
      return const OcptShootingDayAgendaGrid.empty();
    }

    int? earliest;
    int? latest;
    for (final column in columns) {
      final start = column.timeline.startMinute;
      final end = column.timeline.endMinute ?? start;
      if (earliest == null || start < earliest) {
        earliest = start;
      }
      if (latest == null || end > latest) {
        latest = end;
      }
    }

    final snappedStart = _floorToStep(earliest!);
    var snappedEnd = _ceilToStep(latest!);
    if (snappedEnd <= snappedStart) {
      // Every column's own band fell on the very same minute (a single slot with no block yet):
      // one row is still owed, so something is visible.
      snappedEnd = snappedStart + stepMinutes;
    }

    final tiles = <OcptShootingDayAgendaTile>[];
    for (final column in columns) {
      for (final entry in column.timeline.entries) {
        final caption = column.captionByBlockId[entry.blockId];
        if (caption == null) {
          continue;
        }
        final startRow = _floorDiv(entry.startMinute - snappedStart, stepMinutes);
        final endRowExclusive = _ceilDiv(entry.endMinute - snappedStart, stepMinutes);
        final rowSpan = endRowExclusive - startRow < 1 ? 1 : endRowExclusive - startRow;
        tiles.add(
          OcptShootingDayAgendaTile(
            blockId: entry.blockId,
            slotId: column.slotId,
            caption: caption,
            startMinute: entry.startMinute,
            endMinute: entry.endMinute,
            startRow: startRow,
            rowSpan: rowSpan,
          ),
        );
      }
    }

    final eventMarkers = [
      for (final event in events)
        _eventMarkerOf(event, snappedStart: snappedStart, snappedEnd: snappedEnd),
    ];

    return OcptShootingDayAgendaGrid(
      isEmpty: false,
      startMinute: snappedStart,
      endMinute: snappedEnd,
      columns: [
        for (final column in columns)
          OcptShootingDayAgendaColumn(slotId: column.slotId, label: column.label),
      ],
      tiles: tiles,
      events: eventMarkers,
    );
  }

  /// [event] placed against the grid's already-snapped `[snappedStart, snappedEnd)` band: outside
  /// it on either side reads as [OcptShootingDayAgendaEventPlacement.beforeGrid]/`.afterGrid` with
  /// no [OcptShootingDayAgendaEventMarker.row], inside it as `.inGrid` with one.
  ///
  /// No `.clamp` is needed here, unlike a first version of this method that folded an event's own
  /// minute into the bounds themselves: an event can no longer be the source of either bound, so an
  /// `.inGrid` marker's own `event.minute - snappedStart` is always in
  /// `[0, snappedEnd - snappedStart)` by the two comparisons just above it, and [_floorDiv] of a
  /// value already in that range can never land outside `[0, rowCount)`.
  static OcptShootingDayAgendaEventMarker _eventMarkerOf(
    OcptShootingDayAgendaEventInput event, {
    required int snappedStart,
    required int snappedEnd,
  }) {
    if (event.minute < snappedStart) {
      return OcptShootingDayAgendaEventMarker(
        eventId: event.id,
        label: event.label,
        minute: event.minute,
        placement: OcptShootingDayAgendaEventPlacement.beforeGrid,
        row: null,
      );
    }
    if (event.minute >= snappedEnd) {
      return OcptShootingDayAgendaEventMarker(
        eventId: event.id,
        label: event.label,
        minute: event.minute,
        placement: OcptShootingDayAgendaEventPlacement.afterGrid,
        row: null,
      );
    }
    return OcptShootingDayAgendaEventMarker(
      eventId: event.id,
      label: event.label,
      minute: event.minute,
      placement: OcptShootingDayAgendaEventPlacement.inGrid,
      row: _floorDiv(event.minute - snappedStart, stepMinutes),
    );
  }

  /// [minute] rounded down to the nearest [stepMinutes] — including below the day's own midnight,
  /// see [_floorDiv]'s own doc comment for why this cannot be `(minute ~/ stepMinutes) *
  /// stepMinutes`.
  static int _floorToStep(int minute) => _floorDiv(minute, stepMinutes) * stepMinutes;

  /// [minute] rounded up to the nearest [stepMinutes], mirroring [_floorToStep].
  static int _ceilToStep(int minute) => _ceilDiv(minute, stepMinutes) * stepMinutes;

  /// Integer division of [value] by [divisor] (always [stepMinutes], always positive), rounded
  /// **down** — floor, not truncation. Dart's `~/` truncates toward zero, which already is the
  /// floor for a non-negative [value] but rounds the *wrong* way for a negative one (`-5 ~/ 10`
  /// gives `0`, one row too late, where the floor is `-1`). An end-anchored slot resolves its own
  /// start as `anchor − Σ durations` with no floor of its own (ADR 0015, amended a second time), so
  /// a slot pinned to end at 02:00 with four hours of blocks starts at minute `-120`, before the
  /// day's own midnight — reachable, not a defensive corner case. Deliberately integer-only (no
  /// `double`/`.floor()`, which would need a precision argument this file has no business making):
  /// Dart's `%` is Euclidean (non-negative whenever [divisor] is positive, unlike `.remainder()`),
  /// so a negative, inexact [value] truncates *up* one step too many and is walked back down by
  /// one.
  static int _floorDiv(int value, int divisor) {
    final quotient = value ~/ divisor;
    return (value < 0 && value % divisor != 0) ? quotient - 1 : quotient;
  }

  /// Integer division of [value] by [divisor], rounded **up** — what turns an end minute into the
  /// row index one past the last row it touches. The mirror of [_floorDiv]: Dart's truncation
  /// already rounds a negative, inexact [value] up (toward zero), so only a **positive** inexact
  /// one needs the extra step — `_floorDiv`'s minus becomes this function's plus.
  static int _ceilDiv(int value, int divisor) {
    final quotient = value ~/ divisor;
    return (value > 0 && value % divisor != 0) ? quotient + 1 : quotient;
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingDayAgendaGrid(isEmpty: $isEmpty, rowCount: $rowCount, columns: "
      "${columns.length}, "
      "tiles: ${tiles.length}, events: ${events.length})";

  /// Object properties
  @override
  List<Object?> get props => [isEmpty, startMinute, endMinute, columns, tiles, events];
}
