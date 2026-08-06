// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// The display label of shooting day status [status], read by the day list's own status column and
/// the day inspector's status control.
String ocptShootingDayStatusLabel(Tr tr, OcptShootingDayStatus status) => switch (status) {
  OcptShootingDayStatus.planned => tr.scheduleDayStatusPlanned,
  OcptShootingDayStatus.shot => tr.scheduleDayStatusShot,
  OcptShootingDayStatus.cancelled => tr.scheduleDayStatusCancelled,
};

/// The colour shooting day status [status] is painted with, following the shot list's own status
/// scale: [OcptShootingDayStatus.planned] is the neutral one, [OcptShootingDayStatus.cancelled]
/// reads through the workspace's warning colour (a day that needs re-planning), and
/// [OcptShootingDayStatus.shot] is the "already shot" green [OcptSpecificColors] carries.
Color ocptShootingDayStatusColor(BuildContext context, OcptShootingDayStatus status) {
  final theme = Theme.of(context);

  return switch (status) {
    OcptShootingDayStatus.planned => theme.colorScheme.onSurfaceVariant,
    OcptShootingDayStatus.cancelled => ocptWarningColor(context),
    OcptShootingDayStatus.shot =>
      theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary,
  };
}

/// The display label of block kind [kind], read by the strip agenda's own non-shot chips and, once
/// built, the day view's timetable rows.
String ocptShootingBlockKindLabel(Tr tr, OcptShootingBlockKind kind) => switch (kind) {
  OcptShootingBlockKind.shot => tr.scheduleBlockKindShot,
  OcptShootingBlockKind.preparation => tr.scheduleBlockKindPreparation,
  OcptShootingBlockKind.hairMakeUp => tr.scheduleBlockKindHairMakeUp,
  OcptShootingBlockKind.meal => tr.scheduleBlockKindMeal,
  OcptShootingBlockKind.travel => tr.scheduleBlockKindTravel,
  OcptShootingBlockKind.wrap => tr.scheduleBlockKindWrap,
  OcptShootingBlockKind.hold => tr.scheduleBlockKindHold,
};

/// The display label of agenda presentation [mode], read by the header's own segmented control.
String ocptScheduleAgendaModeLabel(Tr tr, OcptScheduleAgendaMode mode) => switch (mode) {
  OcptScheduleAgendaMode.strip => tr.scheduleAgendaModeStrip,
  OcptScheduleAgendaMode.week => tr.scheduleAgendaModeWeek,
  OcptScheduleAgendaMode.month => tr.scheduleAgendaModeMonth,
};

/// A day's printed rank, `J3` — the app's own technical convention (see `CLAUDE.md`'s schedule
/// mode section), not run through `Tr`: the letter is the trade's own shorthand for "jour de
/// tournage" and stays the same whichever UI language is active, exactly as `SÉQ`/`PLAN` markers
/// already do on the exported documents.
String ocptScheduleDayTagLabel(int dayNumber) => "J$dayNumber";

/// The colour a day (or, once built, a week/month cell) is tinted with, following its first slot's
/// own location — the M1 rule ("M1 tints a day by its location, with no choice offered", the
/// `Couleur par lieu` segmented control the mock shows arriving with M3).
///
/// [location] is the day's own first live slot's location, resolved by the caller (a day with no
/// slot, or a slot with no location chosen yet, has none), which then reads the neutral
/// `outlineVariant` instead: a day fresh out of `OcptScheduleService.createDay` is deliberately not
/// painted as if it already had a place.
Color ocptScheduleDayLocationTint(BuildContext context, OcptLocation? location) {
  if (location == null) {
    return Theme.of(context).colorScheme.outlineVariant;
  }

  return Color(ocptCoverageColorAt(location.colorIndex));
}

/// `08:00 – 18:00`, or an em dash while either bound is unset — the day list's own creneaux
/// summary and the inspector's own PAT/estimated-end line share this reading.
String ocptScheduleDayMinuteRangeLabel(int? startMinute, int? endMinute) {
  if (startMinute == null || endMinute == null) {
    return "—";
  }

  return "${ocptFormatDayMinute(startMinute)} – ${ocptFormatDayMinute(endMinute)}";
}

/// The icon a timetable row or the day view's own `+ Block` menu shows beside block kind [kind].
IconData ocptShootingBlockKindIcon(OcptShootingBlockKind kind) => switch (kind) {
  OcptShootingBlockKind.shot => Icons.videocam_outlined,
  OcptShootingBlockKind.preparation => Icons.build_outlined,
  OcptShootingBlockKind.hairMakeUp => Icons.face_retouching_natural_outlined,
  OcptShootingBlockKind.meal => Icons.restaurant_outlined,
  OcptShootingBlockKind.travel => Icons.directions_car_outlined,
  OcptShootingBlockKind.wrap => Icons.inventory_2_outlined,
  OcptShootingBlockKind.hold => Icons.hourglass_empty_outlined,
};

/// The sun/twilight summary line the day inspector and the day view's own summary band share:
/// sunrise – sunset, then the civil twilight band, then the UTC offset they were computed with —
/// or the "no coordinates" hint while [sunTimes] is null.
String ocptScheduleSunTimesLine(Tr tr, OcptSunTimes? sunTimes) {
  if (sunTimes == null) {
    return tr.scheduleInspectorNoSunTimes;
  }

  final sunrise = sunTimes.sunriseMinute;
  final sunset = sunTimes.sunsetMinute;
  final civilDawn = sunTimes.civilDawnMinute;
  final civilDusk = sunTimes.civilDuskMinute;

  return tr.scheduleInspectorSunTimesLine(
    sunrise == null ? "—" : ocptFormatDayMinute(sunrise),
    sunset == null ? "—" : ocptFormatDayMinute(sunset),
    civilDawn == null ? "—" : ocptFormatDayMinute(civilDawn),
    civilDusk == null ? "—" : ocptFormatDayMinute(civilDusk),
    ocptScheduleUtcOffsetLabel(sunTimes.utcOffsetUsed),
  );
}

/// The Monday of the week [date] falls in, at midnight, own time component dropped — the week
/// grid's own column range and the header's own week-navigation label share this one reading of
/// "which week a date belongs to".
DateTime ocptScheduleMondayOfWeek(DateTime date) {
  final dayOnly = DateTime(date.year, date.month, date.day);
  // DateTime.weekday is 1 (Monday) to 7 (Sunday) already, so this only ever steps backward.
  return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
}

/// `3 – 9 August 2026`, the week grid's own header label for the week starting on [monday] — both
/// bounds' day-of-month, the (single) month and year read off the week's own Sunday, since a week
/// crossing a month or a year boundary is still named after the one it ends in, mirroring how a
/// call sheet dates a night shoot after the day it started on.
String ocptScheduleWeekRangeLabel(BuildContext context, DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  final locale = Localizations.localeOf(context).toString();
  final monthYear = DateFormat.yMMMM(locale).format(sunday);
  return "${monday.day} – ${sunday.day} $monthYear";
}

/// `August 2026`, the month grid's own header label for the month [anyDateInMonth] falls in.
String ocptScheduleMonthLabel(BuildContext context, DateTime anyDateInMonth) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(anyDateInMonth);

/// `UTC+2`/`UTC-5`/`UTC` — how the sun times' own [Duration] offset
/// (`OcptSunTimes.utcOffsetUsed`) is printed, so the day inspector can say which one a sunrise or
/// sunset was computed with rather than leaving it implicit (ADR 0016).
String ocptScheduleUtcOffsetLabel(Duration offset) {
  final totalMinutes = offset.inMinutes;
  if (totalMinutes == 0) {
    return "UTC";
  }

  final sign = totalMinutes < 0 ? "-" : "+";
  final absoluteMinutes = totalMinutes.abs();
  final hours = absoluteMinutes ~/ 60;
  final minutes = absoluteMinutes % 60;

  return minutes == 0 ? "UTC$sign$hours" : "UTC$sign$hours:${minutes.toString().padLeft(2, "0")}";
}
