// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
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
/// Purely presentational: selecting a day only ever reads, so it needs no `isReadOnly` flag.
class OcptScheduleWeekGrid extends StatelessWidget {
  /// The date the week shown is the one containing.
  final DateTime anchorDate;

  /// Which day the week's own seven columns start on — the user's app-wide preference.
  final OcptFirstWeekday firstWeekday;

  /// Every live day, in `dayNumber` order — the grid draws whichever of these fall in the shown
  /// week.
  final List<OcptShootingDay> days;

  /// Each day's own first slot's location, keyed by day id.
  final Map<String, OcptLocation?> firstLocationByDayId;

  /// Each day's own live blocks, keyed by day id.
  final Map<String, List<OcptShootingDayBlock>> blocksByDayId;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// Resolves a day id to its own computed timetable, or null while it has nothing placed.
  final OcptShootingDayTimelines? Function(String dayId) timelineOf;

  /// Resolves a day id to its own computed sun times, or null while its first slot has no location
  /// with coordinates.
  final OcptSunTimes? Function(String dayId) sunTimesOf;

  /// The id of the currently selected day, or null while none is.
  final String? selectedDayId;

  /// Called with a day's id when its own column header is clicked, selecting it and opening the
  /// day view.
  final ValueChanged<String> onDayOpenRequested;

  /// Class constructor
  const OcptScheduleWeekGrid({
    super.key,
    required this.anchorDate,
    required this.firstWeekday,
    required this.days,
    required this.firstLocationByDayId,
    required this.blocksByDayId,
    required this.shotOf,
    required this.timelineOf,
    required this.sunTimesOf,
    required this.selectedDayId,
    required this.onDayOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekStart = ocptScheduleStartOfWeek(anchorDate, firstWeekday);
    final weekDates = [for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i))];
    final dayByDate = {for (final day in days) _dateOnly(day.date): day};
    final weekDays = [for (final date in weekDates) dayByDate[date]];

    final (startMinute, endMinute) = _ocptWeekGridRange(weekDays, timelineOf);
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
                        location: dayByDate[date] == null ? null : firstLocationByDayId[dayByDate[date]!.id],
                        blocks: dayByDate[date] == null ? const [] : blocksByDayId[dayByDate[date]!.id] ?? const [],
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
/// whatever every one of [weekDays]' own computed timeline actually returns — the rule that lets a
/// night shoot's blocks (ending past minute 1440) draw correctly rather than being clipped to a
/// bare 24 hours.
(int, int) _ocptWeekGridRange(
  List<OcptShootingDay?> weekDays,
  OcptShootingDayTimelines? Function(String dayId) timelineOf,
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

  /// Called when this header is clicked, or null while [day] is null (nothing to open).
  final VoidCallback? onOpenRequested;

  /// Class constructor
  const _OcptScheduleWeekColumnHeader({
    required this.date,
    required this.day,
    required this.isSelected,
    required this.onOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                Text(
                  ocptScheduleDayTagLabel(day.dayNumber),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One day's own column body: its sun shading and its placed blocks, positioned against the
/// grid's own `[startMinute, endMinute)` range.
class _OcptScheduleWeekColumnBody extends StatelessWidget {
  /// This column's own first slot's location, or null.
  final OcptLocation? location;

  /// This column's own live blocks.
  final List<OcptShootingDayBlock> blocks;

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
    required this.location,
    required this.blocks,
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
        child: Stack(
          children: [..._buildHourLines(context), ..._buildSunBands(context), ..._buildBlocks(context)],
        ),
      ),
    );
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

  /// This column's own placed blocks, positioned by their computed start/duration.
  List<Widget> _buildBlocks(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final entryByBlockId = {
      for (final entry in timeline?.entries ?? const <OcptShootingTimelineEntry>[]) entry.blockId: entry,
    };
    final overrunBlockIds = {
      for (final overrun in timeline?.overruns ?? const <OcptTimelineOverrun>[]) overrun.blockId,
    };
    final tint = ocptScheduleDayLocationTint(context, location);

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

      widgets.add(
        Positioned(
          top: (entry.startMinute - startMinute) * _ocptWeekGridPixelsPerMinute,
          height: (entry.durationMinutes * _ocptWeekGridPixelsPerMinute).clamp(12, double.infinity).toDouble(),
          left: 2,
          right: 2,
          child: Container(
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
          ),
        ),
      );
    }

    return widgets;
  }
}
