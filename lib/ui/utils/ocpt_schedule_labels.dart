// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
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
  OcptShootingBlockKind.pause => tr.scheduleBlockKindPause,
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

/// A day's printed rank, `D3`/`J3` — the shorthand the reference production documents this mode
/// is modelled on use throughout.
///
/// The letter is [Tr.scheduleDayTagPrefix], **localized**: the paperwork a crew reads is printed
/// in the language the app is set to, so the letter that opens a day's own tag follows it, the
/// same as every other word on the page.
String ocptScheduleDayTagLabel(Tr tr, int dayNumber) => "${tr.scheduleDayTagPrefix}$dayNumber";

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
  OcptShootingBlockKind.pause => Icons.pause_circle_outline,
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

/// The first day of the week [date] falls in, at midnight, own time component dropped — the week
/// grid's own column range, the month grid's own first cell and the header's own week-navigation
/// label share this one reading of "which week a date belongs to".
///
/// Which day that is, is the user's own app-wide [firstWeekday] preference rather than a constant:
/// half the world reads a week as starting on Sunday, and a grid drawing it from Monday for them
/// misplaces every date on screen.
DateTime ocptScheduleStartOfWeek(DateTime date, OcptFirstWeekday firstWeekday) {
  final dayOnly = DateTime(date.year, date.month, date.day);
  // DateTime.weekday runs 1 (Monday) to 7 (Sunday); the modulo keeps the step in [0, 6] whichever
  // of the two the week is read as starting on, so this only ever steps backward.
  final daysSinceStart = (dayOnly.weekday - firstWeekday.dateTimeWeekday + 7) % 7;
  return dayOnly.subtract(Duration(days: daysSinceStart));
}

/// `3 – 9 August 2026`, the week grid's own header label for the week starting on [weekStart] —
/// both bounds' day-of-month, the (single) month and year read off the week's own **last** day,
/// since a week crossing a month or a year boundary is still named after the one it ends in,
/// mirroring how a call sheet dates a night shoot after the day it started on.
String ocptScheduleWeekRangeLabel(BuildContext context, DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  final locale = Localizations.localeOf(context).toString();
  final monthYear = DateFormat.yMMMM(locale).format(weekEnd);
  return "${weekStart.day} – ${weekEnd.day} $monthYear";
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

/// `06:30 → 08:00–19:15 → 20:00`, the convocations panel's own card line reading arrival → PAT
/// band → departure — the whole of a day's call for one person or one uncast role, in one line, as
/// a printed call sheet would.
///
/// The PAT band prints as an em dash when [OcptDayConvocation.patStartMinute]/
/// [OcptDayConvocation.patEndMinute] are null together (ADR 0018): someone convoked only on
/// preparation slots is there, not waiting to shoot, and the dash says exactly that rather than a
/// fabricated band or a row silently missing the middle figure.
String ocptScheduleConvocationBandLabel(OcptDayConvocation convocation) {
  final patStart = convocation.patStartMinute;
  final patEnd = convocation.patEndMinute;
  final band = patStart == null || patEnd == null
      ? "—"
      : "${ocptFormatDayMinute(patStart)}–${ocptFormatDayMinute(patEnd)}";

  return "${ocptFormatDayMinute(convocation.arrivalMinute)} → $band → "
      "${ocptFormatDayMinute(convocation.departureMinute)}";
}

/// The convocations panel's own card title for [convocation]: [personById]'s own display name for
/// a person, or [roleById]'s own name read through [Tr.scheduleConvocationsUncastRoleLabel] for an
/// uncast role — exactly one of [OcptDayConvocation.personId]/[OcptDayConvocation.roleId] is ever
/// non-null (the same discriminator `breakdown_tags` uses, ADR 0014), so there is never a choice
/// to make between the two readings, only which one applies.
///
/// An uncast role's own suffix is what keeps a role's row from reading as a person's: the question
/// this panel answers is "when does this human arrive", and a role nobody is cast in is still a
/// convocation the production has to honour, just not yet a human one.
String ocptScheduleConvocationTitle(
  Tr tr,
  OcptDayConvocation convocation,
  Map<String, OcptPerson> personById,
  Map<String, OcptRole> roleById,
) {
  final personId = convocation.personId;
  if (personId != null) {
    final person = personById[personId];
    return person == null || person.displayName.isEmpty
        ? tr.resourcesUnnamedPerson
        : person.displayName;
  }

  return tr.scheduleConvocationsUncastRoleLabel(roleById[convocation.roleId]?.name ?? "");
}

/// The convocations panel's own card footer: every slot [convocation] is linked to
/// ([OcptDayConvocation.slotIds]), by label, joined with " · " — the "where" behind the card's own
/// arrival/PAT/departure line. A slot with no label of its own, or one [slotById] no longer holds
/// (a stale id, which should not happen but is read defensively rather than crashing), reads as
/// [Tr.scheduleInspectorUnnamedSlot], the day inspector's own fallback, reused here rather than a
/// second one invented for this panel.
String ocptScheduleConvocationSlotsLabel(
  Tr tr,
  OcptDayConvocation convocation,
  Map<String, OcptShootingSlot> slotById,
) => [
  for (final slotId in convocation.slotIds) _ocptConvocationSlotLabelOf(tr, slotById[slotId]),
].join(" · ");

/// [slot]'s own label, or [Tr.scheduleInspectorUnnamedSlot] while it is empty or [slot] itself is
/// null — see [ocptScheduleConvocationSlotsLabel]'s own doc comment.
String _ocptConvocationSlotLabelOf(Tr tr, OcptShootingSlot? slot) {
  final label = slot?.label ?? "";
  return label.isEmpty ? tr.scheduleInspectorUnnamedSlot : label;
}
