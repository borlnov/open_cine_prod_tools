// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_alert_badge.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// How many pixels one minute of the grid is drawn as — the same figure the row hour lines, the
/// sun bands and the blocks are all positioned with, so the three never drift out of alignment.
const double _ocptWeekGridPixelsPerMinute = 0.9;

/// The default first hour shown when nothing placed on any of the week's days would push the grid
/// earlier — the mock's own `H0`.
const int _ocptWeekGridDefaultStartHour = 6;

/// The default last hour shown when nothing placed on any of the week's days would push the grid
/// later — the mock's own `H1`, one hour of margin past midnight.
const int _ocptWeekGridDefaultEndHour = 24;

/// The width of the grid's own time gutter, the [_ocptWeekGridGutterGap] below included.
const double _ocptWeekGridGutterWidth = 50;

/// How far the gutter's hour labels stop short of the grid's own first column rule, so a `08:00`
/// reads as a label beside the grid rather than as something stuck to Monday's edge.
const double _ocptWeekGridGutterGap = 8;

/// How opaque an hour rule is drawn against `outlineVariant` — enough to read the grid as hour
/// bands, discreet enough that the blocks drawn over it stay the thing being looked at.
const double _ocptWeekGridHourLineAlpha = 0.45;

/// How opaque a lane divider is drawn against `outlineVariant` — a touch more than an hour rule
/// ([_ocptWeekGridHourLineAlpha]), since a divider is the one cue that two bands sitting side by
/// side belong to two different slots rather than to one that happens to be split.
const double _ocptWeekGridLaneDividerAlpha = 0.6;

/// The horizontal gap a block band keeps from its own lane's edges — the neighbouring lane's
/// divider on one or both sides, or the column's own edge for the single-lane case, which is the
/// common day and the one this figure must keep looking exactly as it did before lanes existed.
const double _ocptWeekGridBlockHorizontalMargin = 2;

/// The week presentation of the agenda: an hour grid, one column per day of the week
/// [anchorDate] falls in, a time gutter down the side, each shooting day's blocks drawn as
/// positioned bands against sunrise/sunset shading (`design.html` lines 170-197,
/// `planningVals()`'s own `weekCols`/`weekHours`).
///
/// **The grid's own vertical range covers whatever the timelines it draws actually return**, never
/// a bare 24 hours: a night shoot's blocks may end past minute 1440, and the grid's own bottom
/// bound stretches to meet them (`ocptComputeShootingDayTimelines`'s own convention — see
/// `lib/utils/ocpt_day_minute.dart`). A day with no sun-time figures at all (no coordinates pinned
/// on its first slot's location) draws no shading band for that column rather than a wrong one.
///
/// **A day's own slots draw as parallel lanes within its own column**, in the day's own
/// [OcptShootingSlot] `sortKey` order, rather than as one band spanning the full width: two slots
/// of a day may overlap in wall-clock time (ADR 0015, amended), and drawing them on top of one
/// another would hide that a second unit exists at all. A day with a single slot — the common case
/// — draws exactly as it did before lanes existed, one lane spanning the whole column. Which lane
/// belongs to which slot is read from a block band's own tooltip, naming that slot's label; a lane
/// divider marks where one slot's column ends and the next begins.
///
/// **A day's own events draw as a full-width marker**, across every lane rather than inside one of
/// them — an event belongs to the day, not to a unit, and is never dragged or chained: moving one
/// is typing another hour in the day view's own events band, never a gesture on this grid. Its
/// `[startMinute, endMinute)` range stretches to cover an event exactly as it stretches to cover a
/// night block (see [_ocptWeekGridRange]), so an event pinned outside every block's own span still
/// draws rather than being clipped. The strip and month agendas draw no such marker — out of scope
/// for this milestone.
///
/// Purely presentational: selecting a day only ever reads, so it needs no `isReadOnly` flag.
class OcptScheduleWeekGrid extends StatelessWidget {
  /// The date the week shown is the one containing.
  final DateTime anchorDate;

  /// Which day the week's own seven columns start on — the user's app-wide preference.
  final OcptFirstWeekday firstWeekday;

  /// Every live day, in `dayNumber` order — the grid draws whichever of these fall in the shown
  /// week.
  final List<OcptShootingDay> days;

  /// A day's own resolved tint, under whichever `OcptScheduleAgendaColorMode` is currently active —
  /// `ocptScheduleDayLocationTint`/`ocptScheduleDayEffectTint` applied by the caller, so this widget
  /// stays ignorant of which fact a day is coloured by.
  final Color Function(String dayId) dayTintOf;

  /// Each day's own live slots, keyed by day id, in `sortKey` order — the lanes a day's own column
  /// is divided into.
  final Map<String, List<OcptShootingSlot>> slotsByDayId;

  /// Each day's own live blocks, keyed by day id.
  final Map<String, List<OcptShootingDayBlock>> blocksByDayId;

  /// Each day's own live events, keyed by day id, already ordered by hour — what a day's own
  /// full-width marker is drawn from.
  final Map<String, List<OcptShootingDayEvent>> eventsByDayId;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// Resolves a day id to its own computed timetable, or null while it has nothing placed.
  final OcptShootingDayTimelines? Function(String dayId) timelineOf;

  /// Resolves a day id to its own computed sun times, or null while its first slot has no location
  /// with coordinates.
  final OcptSunTimes? Function(String dayId) sunTimesOf;

  /// The id of the currently selected day, or null while none is.
  final String? selectedDayId;

  /// Resolves a day id to the alerts the plan raises about it (`OcptScheduleState.alertsOfDay`) —
  /// what each column header's own [OcptScheduleDayAlertBadge] is drawn from, empty for a day
  /// raising none.
  final List<OcptScheduleAlert> Function(String dayId) alertsOfDay;

  /// Called with a day's id when its own column header is clicked, selecting it and opening the
  /// day view.
  final ValueChanged<String> onDayOpenRequested;

  /// Class constructor
  const OcptScheduleWeekGrid({
    super.key,
    required this.anchorDate,
    required this.firstWeekday,
    required this.days,
    required this.dayTintOf,
    required this.slotsByDayId,
    required this.blocksByDayId,
    required this.eventsByDayId,
    required this.shotOf,
    required this.timelineOf,
    required this.sunTimesOf,
    required this.selectedDayId,
    required this.alertsOfDay,
    required this.onDayOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekStart = ocptScheduleStartOfWeek(anchorDate, firstWeekday);
    final weekDates = [for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i))];
    final dayByDate = {for (final day in days) _dateOnly(day.date): day};
    final weekDays = [for (final date in weekDates) dayByDate[date]];

    final (startMinute, endMinute) = _ocptWeekGridRange(weekDays, timelineOf, eventsByDayId);
    final gridHeight = (endMinute - startMinute) * _ocptWeekGridPixelsPerMinute;
    final hourLabels = <Widget>[
      for (var minute = startMinute; minute < endMinute; minute += 60)
        Positioned(
          top: (minute - startMinute) * _ocptWeekGridPixelsPerMinute,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.only(right: _ocptWeekGridGutterGap),
            child: Text(
              ocptFormatDayMinute(minute),
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
    ];

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(ocptRadiusMedium),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The header row (day-of-week, day-of-month, day tag) is a row of its own so the
            // gutter's hour labels below can start exactly level with the grid, rather than under
            // whatever height the headers happen to need.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: _ocptWeekGridGutterWidth),
                  for (final date in weekDates)
                    Expanded(
                      child: _OcptScheduleWeekColumnHeader(
                        date: date,
                        day: dayByDate[date],
                        isSelected: dayByDate[date] != null && dayByDate[date]!.id == selectedDayId,
                        alerts: dayByDate[date] == null ? const [] : alertsOfDay(dayByDate[date]!.id),
                        onOpenRequested: dayByDate[date] == null
                            ? null
                            : () => onDayOpenRequested(dayByDate[date]!.id),
                      ),
                    ),
                ],
              ),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _ocptWeekGridGutterWidth,
                    height: gridHeight,
                    child: Stack(children: hourLabels),
                  ),
                  for (final date in weekDates)
                    Expanded(
                      child: _OcptScheduleWeekColumnBody(
                        tint: dayByDate[date] == null
                            ? theme.colorScheme.outlineVariant
                            : dayTintOf(dayByDate[date]!.id),
                        slots: dayByDate[date] == null ? const [] : slotsByDayId[dayByDate[date]!.id] ?? const [],
                        blocks: dayByDate[date] == null ? const [] : blocksByDayId[dayByDate[date]!.id] ?? const [],
                        events: dayByDate[date] == null ? const [] : eventsByDayId[dayByDate[date]!.id] ?? const [],
                        shotOf: shotOf,
                        timeline: dayByDate[date] == null ? null : timelineOf(dayByDate[date]!.id),
                        sunTimes: dayByDate[date] == null ? null : sunTimesOf(dayByDate[date]!.id),
                        startMinute: startMinute,
                        endMinute: endMinute,
                        gridHeight: gridHeight,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [date] with its time component dropped, so it can key a `Map` alongside `OcptShootingDay.date`.
DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// The `[startMinute, endMinute)` the grid draws, covering the default 06:00-24:00 span **and**
/// whatever every one of [weekDays]' own computed timeline or own events actually returns — the
/// rule that lets a night shoot's blocks (ending past minute 1440) draw correctly rather than being
/// clipped to a bare 24 hours, and that lets an event pinned outside every block's own span still
/// stretch the grid to show it.
(int, int) _ocptWeekGridRange(
  List<OcptShootingDay?> weekDays,
  OcptShootingDayTimelines? Function(String dayId) timelineOf,
  Map<String, List<OcptShootingDayEvent>> eventsByDayId,
) {
  var startMinute = _ocptWeekGridDefaultStartHour * 60;
  var endMinute = _ocptWeekGridDefaultEndHour * 60;

  for (final day in weekDays) {
    if (day == null) {
      continue;
    }
    final timeline = timelineOf(day.id);
    for (final entry in timeline?.entries ?? const <OcptShootingTimelineEntry>[]) {
      if (entry.startMinute < startMinute) {
        startMinute = (entry.startMinute ~/ 60) * 60;
      }
      if (entry.endMinute > endMinute) {
        endMinute = ((entry.endMinute + 59) ~/ 60) * 60;
      }
    }
    for (final event in eventsByDayId[day.id] ?? const <OcptShootingDayEvent>[]) {
      if (event.minute < startMinute) {
        startMinute = (event.minute ~/ 60) * 60;
      }
      if (event.minute >= endMinute) {
        endMinute = ((event.minute + 60) ~/ 60) * 60;
      }
    }
  }

  return (startMinute, endMinute);
}

/// One day's own column header: the day-of-week, the day-of-month and, for a shooting day, its
/// own day tag — clickable to select that day and open the day view.
class _OcptScheduleWeekColumnHeader extends StatelessWidget {
  /// The calendar date this column stands for.
  final DateTime date;

  /// The shooting day dated [date], or null while none is.
  final OcptShootingDay? day;

  /// Whether [day] is the currently selected one.
  final bool isSelected;

  /// The alerts the plan raises about [day], empty while it raises none (or while [day] is null).
  final List<OcptScheduleAlert> alerts;

  /// Called when this header is clicked, or null while [day] is null (nothing to open).
  final VoidCallback? onOpenRequested;

  /// Class constructor
  const _OcptScheduleWeekColumnHeader({
    required this.date,
    required this.day,
    required this.isSelected,
    required this.alerts,
    required this.onOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final day = this.day;
    final locale = Localizations.localeOf(context).toString();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: InkWell(
        onTap: onOpenRequested,
        mouseCursor: onOpenRequested == null ? MouseCursor.defer : ocptClickableCursor,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: day == null
                ? Colors.transparent
                : theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha),
            border: Border(
              bottom: BorderSide(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.E(locale).format(date).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text("${date.day}", style: theme.textTheme.titleSmall),
              if (day != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ocptScheduleDayTagLabel(tr, day.dayNumber),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (alerts.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      OcptScheduleDayAlertBadge(alerts: alerts, isCompact: true),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One day's own column body: its sun shading, its placed blocks (split into one lane per live
/// slot) and its own events, positioned against the grid's own `[startMinute, endMinute)` range.
class _OcptScheduleWeekColumnBody extends StatelessWidget {
  /// This column's own resolved tint (`OcptScheduleWeekGrid.dayTintOf`, already applied) — the
  /// grid's own `outlineVariant` fallback when the date carries no shooting day at all.
  final Color tint;

  /// This column's own live slots, in `sortKey` order — the lanes the column's own width is split
  /// into. Empty for a date with no shooting day at all, in which case there is nothing to lay out
  /// regardless ([blocks] is then empty too).
  final List<OcptShootingSlot> slots;

  /// This column's own live blocks.
  final List<OcptShootingDayBlock> blocks;

  /// This column's own live events, already ordered by hour.
  final List<OcptShootingDayEvent> events;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// This column's own computed timetable, or null while it has nothing placed (or there is no
  /// shooting day on this date).
  final OcptShootingDayTimelines? timeline;

  /// This column's own computed sun times, or null while its first slot has no location with
  /// coordinates (or there is no shooting day on this date).
  final OcptSunTimes? sunTimes;

  /// The grid's own first minute shown — every position in this column is relative to it.
  final int startMinute;

  /// The grid's own last minute shown (exclusive).
  final int endMinute;

  /// The grid's own total height, in pixels.
  final double gridHeight;

  /// Class constructor
  const _OcptScheduleWeekColumnBody({
    required this.tint,
    required this.slots,
    required this.blocks,
    required this.events,
    required this.shotOf,
    required this.timeline,
    required this.sunTimes,
    required this.startMinute,
    required this.endMinute,
    required this.gridHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: gridHeight,
        // A `LayoutBuilder` rather than reading `MediaQuery` or a fixed fraction: the lanes need
        // this column's own pixel width, which only its own parent (the `Expanded` in the header
        // row above) knows, and that width can differ from one week's grid to the next screen size.
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              ..._buildHourLines(context),
              ..._buildSunBands(context),
              ..._buildLaneDividers(context, constraints.maxWidth),
              ..._buildBlocks(context, constraints.maxWidth),
              ..._buildEvents(context),
            ],
          ),
        ),
      ),
    );
  }

  /// The vertical hairline(s) marking where one slot's lane ends and the next begins — nothing at
  /// all for a single-slot day, since there is then only one lane and nothing to divide.
  List<Widget> _buildLaneDividers(BuildContext context, double columnWidth) {
    if (slots.length <= 1) {
      return const [];
    }

    final color = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: _ocptWeekGridLaneDividerAlpha);
    final laneWidth = columnWidth / slots.length;

    return [
      for (var lane = 1; lane < slots.length; lane++)
        Positioned(
          top: 0,
          bottom: 0,
          left: laneWidth * lane,
          width: 1,
          child: ColoredBox(color: color),
        ),
    ];
  }

  /// The lane index [slots] places [slotId] at, or `0` when [slotId] names none of them — a block
  /// whose slot has since been deleted from under it (the timeline reads a snapshot that is always
  /// at least as fresh, so this is defensive rather than expected) still has to land somewhere
  /// rather than vanish from the grid.
  int _laneIndexOf(String slotId) {
    final index = slots.indexWhere((slot) => slot.id == slotId);
    return index < 0 ? 0 : index;
  }

  /// One hair line per hour of the grid's own range, drawn first so the sun bands and the blocks
  /// both sit over it.
  ///
  /// Every column draws its own rather than one overlay spanning the week: the columns are
  /// [Expanded] siblings with no shared coordinate space, and a line drawn per column can never
  /// land a pixel off the gutter label it belongs to. The grid's own first minute carries none —
  /// the header row's bottom border already rules that edge.
  List<Widget> _buildHourLines(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: _ocptWeekGridHourLineAlpha);

    return [
      for (var minute = startMinute + 60; minute < endMinute; minute += 60)
        Positioned(
          top: (minute - startMinute) * _ocptWeekGridPixelsPerMinute,
          left: 0,
          right: 0,
          height: 1,
          child: ColoredBox(color: color),
        ),
    ];
  }

  /// The sun-shading bands for this column: pre-sunrise and post-civil-dusk are tinted as night,
  /// the sunset-to-civil-dusk stretch as dusk — nothing at all when [sunTimes] is null (no
  /// coordinates pinned yet), which is deliberate: a plausible wrong band is worse than none.
  List<Widget> _buildSunBands(BuildContext context) {
    final sunTimes = this.sunTimes;
    if (sunTimes == null) {
      return const [];
    }

    final theme = Theme.of(context);
    final nightColor = theme.colorScheme.primary.withValues(alpha: 0.05);
    final duskColor = theme.colorScheme.tertiary.withValues(alpha: 0.08);
    final bands = <Widget>[];

    final sunrise = sunTimes.sunriseMinute;
    if (sunrise != null && sunrise > startMinute) {
      bands.add(_buildBand(top: startMinute, bottom: sunrise, color: nightColor));
    }

    final sunset = sunTimes.sunsetMinute;
    final civilDusk = sunTimes.civilDuskMinute;
    if (sunset != null && civilDusk != null && civilDusk > sunset) {
      bands.add(_buildBand(top: sunset, bottom: civilDusk, color: duskColor));
    }
    if (civilDusk != null) {
      bands.add(_buildBand(top: civilDusk, bottom: endMinute, color: nightColor));
    }

    return bands;
  }

  /// One shading band from [top] to [bottom] (in grid minutes), clamped to the column's own drawn
  /// range.
  Widget _buildBand({required int top, required int bottom, required Color color}) {
    final clampedTop = top < startMinute ? startMinute : top;
    final clampedBottom = bottom > endMinute ? endMinute : bottom;
    final topPx = (clampedTop - startMinute) * _ocptWeekGridPixelsPerMinute;
    final height = (clampedBottom - clampedTop) * _ocptWeekGridPixelsPerMinute;
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(top: topPx, left: 0, right: 0, height: height, child: ColoredBox(color: color));
  }

  /// This column's own placed blocks, positioned by their computed start/duration, and by their
  /// own slot's lane — [columnWidth] split evenly across [slots], one lane per slot, in the order
  /// [slots] itself already carries ([OcptShootingSlot] `sortKey` order). A single-slot day (the
  /// common case) has exactly one lane spanning the whole width, so this draws identically to
  /// before lanes existed.
  ///
  /// Each band carries a [Tooltip] naming the slot's own label — a lane a few dozen pixels wide has
  /// no room to print it, but hovering (or long-pressing, on a touch surface) still answers "whose
  /// lane is this". A single-lane day skips the tooltip: with one lane there is nothing to tell
  /// apart.
  List<Widget> _buildBlocks(BuildContext context, double columnWidth) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final entryByBlockId = {
      for (final entry in timeline?.entries ?? const <OcptShootingTimelineEntry>[]) entry.blockId: entry,
    };
    final overrunBlockIds = {
      for (final overrun in timeline?.overruns ?? const <OcptTimelineOverrun>[]) overrun.blockId,
    };
    final laneCount = slots.isEmpty ? 1 : slots.length;
    final laneWidth = columnWidth / laneCount;

    final widgets = <Widget>[];
    for (final block in blocks) {
      final entry = entryByBlockId[block.id];
      if (entry == null) {
        continue;
      }

      final isShot = block.kind == OcptShootingBlockKind.shot;
      final shot = isShot && block.shotId != null ? shotOf(block.shotId!) : null;
      final label = isShot
          ? "${shot?.code ?? ""} · ${shot?.shotSize ?? ""}"
          : (block.label.isEmpty ? ocptShootingBlockKindLabel(tr, block.kind) : block.label);
      final color = isShot ? tint : theme.colorScheme.onSurfaceVariant;
      final isOverrun = overrunBlockIds.contains(block.id);
      final lane = _laneIndexOf(block.slotId);

      final band = Container(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border(left: BorderSide(color: isOverrun ? theme.colorScheme.error : color, width: 2)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
        ),
      );

      widgets.add(
        Positioned(
          top: (entry.startMinute - startMinute) * _ocptWeekGridPixelsPerMinute,
          height: (entry.durationMinutes * _ocptWeekGridPixelsPerMinute).clamp(12, double.infinity).toDouble(),
          left: lane * laneWidth + _ocptWeekGridBlockHorizontalMargin,
          width: laneWidth - 2 * _ocptWeekGridBlockHorizontalMargin,
          child: slots.length <= 1
              ? band
              : Tooltip(
                  message: lane < slots.length && slots[lane].label.isNotEmpty
                      ? slots[lane].label
                      : tr.scheduleInspectorUnnamedSlot,
                  child: band,
                ),
        ),
      );
    }

    return widgets;
  }

  /// This column's own events, one full-width marker per event, positioned at its own
  /// `OcptShootingDayEvent.minute` — across every lane rather than inside one of them, an event
  /// belonging to the day rather than to a unit (see the class doc comment). Drawn discreetly, off
  /// the ambient theme's own `outline` rather than a bespoke colour, so the blocks stay the thing
  /// being looked at; a [Tooltip] names the hour and the label (falling back to `Untitled event`
  /// when it has none).
  List<Widget> _buildEvents(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = theme.colorScheme.outline;

    return [
      for (final event in events)
        Positioned(
          top: (event.minute - startMinute) * _ocptWeekGridPixelsPerMinute - 3,
          left: 0,
          right: 0,
          height: 6,
          child: Tooltip(
            message:
                "${ocptFormatDayMinute(event.minute)} · "
                "${event.label.isEmpty ? tr.scheduleDayEventUnnamedLabel : event.label}",
            child: Center(child: Container(height: 2, color: color)),
          ),
        ),
    ];
  }
}
