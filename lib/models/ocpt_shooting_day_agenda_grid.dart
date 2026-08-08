// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// One slot's own column, as fed to [OcptShootingDayAgendaGrid.of]: its id, its already-resolved
/// [OcptShootingSlotTimeline] and the caption every one of its own blocks prints on its tile.
///
/// The timeline is read straight from `ocpt_shooting_day_timeline.dart` rather than re-derived —
/// this file adds no chaining rule of its own, only a reading of one already computed. A caption
/// is handed in **already localized** (through `ocptScheduleBlockCaptionOf`, or a shot's own code)
/// because it may need a `Tr` this pure-Dart file must never import, exactly the trade
/// `OcptScenarioCoverageLayout` makes for a bar's own label.
class OcptShootingDayAgendaColumnInput {
  /// Class constructor
  const OcptShootingDayAgendaColumnInput({
    required this.slotId,
    required this.label,
    required this.timeline,
    required this.captionByBlockId,
  });

  /// The slot's own id (`shooting_slots.id`).
  final String slotId;

  /// The slot's own free-text label, exactly as typed — never substituted with a placeholder here,
  /// which is a drawing-time decision.
  final String label;

  /// The slot's own resolved timeline — every block already chained onto the day's clock.
  final OcptShootingSlotTimeline timeline;

  /// Every one of this slot's own blocks' printable caption, keyed by [OcptShootingTimelineEntry
  /// .blockId]. A block whose id has no entry here is skipped rather than drawn blank: a caller
  /// that forgot one is a bug to surface as a missing tile, not as an empty one.
  final Map<String, String> captionByBlockId;
}

/// One event, as fed to [OcptShootingDayAgendaGrid.of]: its id, its absolute minute and its
/// already-localized label — the same trade [OcptShootingDayAgendaColumnInput.captionByBlockId]
/// makes, for the same reason.
class OcptShootingDayAgendaEventInput {
  /// Class constructor
  const OcptShootingDayAgendaEventInput({required this.id, required this.minute, required this.label});

  /// The event's own id (`shooting_day_events.id`).
  final String id;

  /// The minute, from the day's own midnight, this event happens at. May exceed 1440, exactly as
  /// every other minute in this file may.
  final int minute;

  /// The event's own printable label.
  final String label;
}

/// One slot column of the grid: its id and its own label, carried through from
/// [OcptShootingDayAgendaColumnInput] unchanged — everything else that input held (the timeline,
/// the captions) has already been turned into [OcptShootingDayAgendaGrid.tiles] by the time the
/// grid is built.
class OcptShootingDayAgendaColumn extends Equatable {
  /// Class constructor
  const OcptShootingDayAgendaColumn({required this.slotId, required this.label});

  /// The slot's own id.
  final String slotId;

  /// The slot's own free-text label.
  final String label;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingDayAgendaColumn(slotId: $slotId, label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [slotId, label];
}

/// One block drawn as a tile: which column it sits in, which rows it spans, and its own exact
/// clock — carried alongside the row span rather than instead of it, since the row span is a
/// **reading aid**, not a claim that the block actually starts and ends on a ten-minute mark. A
/// renderer prints [caption] and the exact `[startMinute, endMinute)` inside the tile
/// [startRow]..[startRow] + [rowSpan] - 1 spans.
class OcptShootingDayAgendaTile extends Equatable {
  /// Class constructor
  const OcptShootingDayAgendaTile({
    required this.blockId,
    required this.slotId,
    required this.caption,
    required this.startMinute,
    required this.endMinute,
    required this.startRow,
    required this.rowSpan,
  });

  /// The block's own id (`shooting_day_blocks.id`).
  final String blockId;

  /// The id of the [OcptShootingDayAgendaColumn] this tile is drawn in.
  final String slotId;

  /// The tile's own already-localized caption.
  final String caption;

  /// The block's own **exact** resolved start, unsnapped — what the tile prints inside itself, a
  /// 12-minute block on a 10-minute grid still reading `09:12` rather than `09:10`.
  final int startMinute;

  /// The block's own exact resolved end, unsnapped, mirroring [startMinute]. Always strictly
  /// greater than [startMinute] once [OcptShootingDayAgendaGrid.stepMinutes] rounding is undone by
  /// the caller — the grid geometry itself never claims a zero-length span, see [rowSpan].
  final int endMinute;

  /// The 0-based row, within [OcptShootingDayAgendaGrid.rowCount], this tile's own band starts on.
  final int startRow;

  /// How many rows this tile spans, always at least 1: a block resolving to zero minutes (a
  /// milestone marker) or to a duration shorter than [OcptShootingDayAgendaGrid.stepMinutes] (the
  /// 12-minute case) still occupies one whole row rather than a sliver of one — a grid can only
  /// draw whole rows, and a tile with no row of its own would be invisible.
  final int rowSpan;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingDayAgendaTile(blockId: $blockId, slotId: $slotId, rows: $startRow+$rowSpan)";

  /// Object properties
  @override
  List<Object?> get props => [blockId, slotId, caption, startMinute, endMinute, startRow, rowSpan];
}

/// One event drawn as a full-width marker on its own [row].
class OcptShootingDayAgendaEventMarker extends Equatable {
  /// Class constructor
  const OcptShootingDayAgendaEventMarker({
    required this.eventId,
    required this.label,
    required this.minute,
    required this.row,
  });

  /// The event's own id.
  final String eventId;

  /// The event's own already-localized label.
  final String label;

  /// The event's own exact minute, unsnapped — mirrors [OcptShootingDayAgendaTile.startMinute].
  final int minute;

  /// The 0-based row this event's marker is drawn across, the whole width of the grid — the row
  /// [minute] falls into once the grid's own bounds are snapped to [OcptShootingDayAgendaGrid
  /// .stepMinutes].
  final int row;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingDayAgendaEventMarker(eventId: $eventId, row: $row)";

  /// Object properties
  @override
  List<Object?> get props => [eventId, label, minute, row];
}

/// A day's own timetable, read as a grid: rows every [stepMinutes] from the day's earliest
/// resolved start to its latest resolved end, one column per slot, a block drawn as a tile
/// spanning the rows its band covers, an event drawn as a full-width marker.
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
/// An event's own minute is folded into that same span before the snapping runs: the schedule
/// mode's own week grid (`OcptScheduleWeekGrid`) already stretches its hour range the same way, for
/// the same reason — an event pinned an hour before the first slot's call, or an hour after the
/// last one wraps, is exactly the kind of fact a call sheet's reader most needs to see, and a
/// marker drawn off the edge of a printed page says nothing at all.
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

  /// Every event placed as a full-width marker.
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
    for (final event in events) {
      if (earliest == null || event.minute < earliest) {
        earliest = event.minute;
      }
      if (latest == null || event.minute > latest) {
        latest = event.minute;
      }
    }

    final snappedStart = _floorToStep(earliest!);
    var snappedEnd = _ceilToStep(latest!);
    if (snappedEnd <= snappedStart) {
      // Every column's own band and every event fell on the very same minute (a single slot with
      // no block yet, no event outside it): one row is still owed, so something is visible.
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

    final rowCount = (snappedEnd - snappedStart) ~/ stepMinutes;
    final eventMarkers = <OcptShootingDayAgendaEventMarker>[
      for (final event in events)
        OcptShootingDayAgendaEventMarker(
          eventId: event.id,
          label: event.label,
          minute: event.minute,
          // The lower bound is unreachable by construction (`snappedStart` is floored from the very
          // minimum this loop folded every event's own minute into, so the difference is always
          // >= 0) and is only here because `clamp` takes both ends together. The **upper** bound is
          // not dead: when the single latest event is itself the grid's own latest bound and already
          // an exact multiple of `stepMinutes`, `snappedEnd` lands exactly on that minute — the
          // half-open row convention `[row start, row start + stepMinutes)` has no row that *starts*
          // there, so the unclamped index would be `rowCount`, one past the last real row, rather
          // than land inside it.
          row: _floorDiv(event.minute - snappedStart, stepMinutes).clamp(0, rowCount - 1),
        ),
    ];

    return OcptShootingDayAgendaGrid(
      isEmpty: false,
      startMinute: snappedStart,
      endMinute: snappedEnd,
      columns: [for (final column in columns) OcptShootingDayAgendaColumn(slotId: column.slotId, label: column.label)],
      tiles: tiles,
      events: eventMarkers,
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
  /// so a negative, inexact [value] truncates *up* one step too many and is walked back down by one.
  static int _floorDiv(int value, int divisor) {
    final quotient = value ~/ divisor;
    return (value < 0 && value % divisor != 0) ? quotient - 1 : quotient;
  }

  /// Integer division of [value] by [divisor], rounded **up** — what turns an end minute into the
  /// row index one past the last row it touches. The mirror of [_floorDiv]: Dart's truncation
  /// already rounds a negative, inexact [value] up (toward zero), so only a **positive** inexact one
  /// needs the extra step — `_floorDiv`'s minus becomes this function's plus.
  static int _ceilDiv(int value, int divisor) {
    final quotient = value ~/ divisor;
    return (value > 0 && value % divisor != 0) ? quotient + 1 : quotient;
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingDayAgendaGrid(isEmpty: $isEmpty, rowCount: $rowCount, columns: ${columns.length}, "
      "tiles: ${tiles.length}, events: ${events.length})";

  /// Object properties
  @override
  List<Object?> get props => [isEmpty, startMinute, endMinute, columns, tiles, events];
}
