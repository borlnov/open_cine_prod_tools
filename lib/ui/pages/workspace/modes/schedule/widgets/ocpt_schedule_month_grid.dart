// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// The number of week rows the grid always draws — six covers every month regardless of which
/// weekday it starts or ends on, so the grid's own shape never changes from one month to the next.
const int _ocptMonthGridWeekCount = 6;

/// The month presentation of the agenda: the shoot at a glance, one cell per day of the month
/// [anchorDate] falls in, each shooting day's cell carrying its day tag, its location, its call →
/// estimated end and its sun line (`design.html` lines 199-227, `planningVals()`'s own
/// `monthWeeks`).
///
/// Purely presentational: selecting a day only ever reads, so it needs no `isReadOnly` flag.
class OcptScheduleMonthGrid extends StatelessWidget {
  /// The date the month shown is the one containing.
  final DateTime anchorDate;

  /// Which day the grid's own seven columns start on — the user's app-wide preference.
  final OcptFirstWeekday firstWeekday;

  /// Every live day, in `dayNumber` order — the grid draws whichever of these fall in the shown
  /// month's own weeks, as [firstWeekday] cuts them.
  final List<OcptShootingDay> days;

  /// Each day's own live slots, keyed by day id — what a cell's own call time is read off.
  final Map<String, List<OcptShootingSlot>> slotsByDayId;

  /// Each day's own first slot's location, keyed by day id.
  final Map<String, OcptLocation?> firstLocationByDayId;

  /// Resolves a day id to its own computed timetable, or null while it has nothing placed.
  final OcptShootingDayTimelines? Function(String dayId) timelineOf;

  /// Resolves a day id to its own computed sun times, or null while its first slot has no location
  /// with coordinates.
  final OcptSunTimes? Function(String dayId) sunTimesOf;

  /// The id of the currently selected day, or null while none is.
  final String? selectedDayId;

  /// Called with a day's id when its own cell is clicked, selecting it and opening the day view.
  final ValueChanged<String> onDayOpenRequested;

  /// Class constructor
  const OcptScheduleMonthGrid({
    super.key,
    required this.anchorDate,
    required this.firstWeekday,
    required this.days,
    required this.slotsByDayId,
    required this.firstLocationByDayId,
    required this.timelineOf,
    required this.sunTimesOf,
    required this.selectedDayId,
    required this.onDayOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayByDate = {for (final day in days) _dateOnly(day.date): day};
    final firstOfMonth = DateTime(anchorDate.year, anchorDate.month);
    final gridStart = ocptScheduleStartOfWeek(firstOfMonth, firstWeekday);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var week = 0; week < _ocptMonthGridWeekCount; week++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var weekday = 0; weekday < 7; weekday++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final date = gridStart.add(Duration(days: week * 7 + weekday));
                          final day = dayByDate[date];
                          return _OcptScheduleMonthCell(
                            date: date,
                            isInMonth: date.month == anchorDate.month,
                            day: day,
                            slots: day == null ? const [] : slotsByDayId[day.id] ?? const [],
                            location: day == null ? null : firstLocationByDayId[day.id],
                            timeline: day == null ? null : timelineOf(day.id),
                            sunTimes: day == null ? null : sunTimesOf(day.id),
                            isSelected: day != null && day.id == selectedDayId,
                            onOpenRequested: day == null ? null : () => onDayOpenRequested(day.id),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// [date] with its time component dropped, so it can key a `Map` alongside `OcptShootingDay.date`.
DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// One cell of the month grid.
class _OcptScheduleMonthCell extends StatelessWidget {
  /// The calendar date this cell stands for.
  final DateTime date;

  /// Whether [date] falls within the month currently shown (a leading/trailing cell from an
  /// adjacent month reads dimmer).
  final bool isInMonth;

  /// The shooting day dated [date], or null while none is.
  final OcptShootingDay? day;

  /// [day]'s own live slots.
  final List<OcptShootingSlot> slots;

  /// [day]'s own first slot's location, or null.
  final OcptLocation? location;

  /// [day]'s own computed timetable, or null while it has nothing placed (or [day] is null).
  final OcptShootingDayTimelines? timeline;

  /// [day]'s own computed sun times, or null while its first slot has no location with
  /// coordinates (or [day] is null).
  final OcptSunTimes? sunTimes;

  /// Whether [day] is the currently selected one.
  final bool isSelected;

  /// Called when this cell is clicked, or null while [day] is null (nothing to open).
  final VoidCallback? onOpenRequested;

  /// Class constructor
  const _OcptScheduleMonthCell({
    required this.date,
    required this.isInMonth,
    required this.day,
    required this.slots,
    required this.location,
    required this.timeline,
    required this.sunTimes,
    required this.isSelected,
    required this.onOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final day = this.day;
    final tint = day == null ? null : ocptScheduleDayLocationTint(context, location);
    final firstCallMinute = slots.isEmpty ? null : slots.first.crewCallMinute;
    final sunTimes = this.sunTimes;

    return InkWell(
      onTap: onOpenRequested,
      mouseCursor: onOpenRequested == null ? MouseCursor.defer : ocptClickableCursor,
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isSelected ? theme.colorScheme.primary : (tint ?? Colors.transparent),
              width: 2,
            ),
            left: BorderSide(color: theme.colorScheme.outlineVariant),
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          color: day == null
              ? Colors.transparent
              : theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha / 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${date.day}",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: day != null
                          ? theme.colorScheme.onSurface
                          : (isInMonth
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.outlineVariant),
                    ),
                  ),
                ),
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
            if (day != null) ...[
              const SizedBox(height: 3),
              Text(
                location?.name ?? tr.scheduleDayNoLocation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
              ),
              Text(
                ocptScheduleDayMinuteRangeLabel(firstCallMinute, timeline?.dayEndMinute),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (sunTimes != null)
                Text(
                  _sunLine(sunTimes),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// `☀ 06:12 / 21:04`, the cell's own compact sun line.
  String _sunLine(OcptSunTimes sunTimes) {
    final sunrise = sunTimes.sunriseMinute;
    final sunset = sunTimes.sunsetMinute;
    return "☀ ${sunrise == null ? "—" : ocptFormatDayMinute(sunrise)} / "
        "${sunset == null ? "—" : ocptFormatDayMinute(sunset)}";
  }
}
