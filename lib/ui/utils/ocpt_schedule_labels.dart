// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/constants/ocpt_schedule_effect_palette.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_scene_effect_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_plan_xlsx_column.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_workspace_episode_label.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_out_of_days.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';
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
  OcptShootingBlockKind.audition => tr.scheduleBlockKindAudition,
  OcptShootingBlockKind.rehearsal => tr.scheduleBlockKindRehearsal,
};

/// The full display label of presence code [code], read by the presence grid's own cell tooltip.
String ocptPresenceCodeLabel(Tr tr, OcptPresenceCode code) => switch (code) {
  OcptPresenceCode.working => tr.presenceCodeLabelWorking,
  OcptPresenceCode.unavailable => tr.presenceCodeLabelUnavailable,
};

/// The single-letter pill label of presence code [code] — **not** the enum's own name, and not the
/// same letter in every language: the presence grid's own cell is too narrow for a word, so it
/// prints the initial the reference paperwork's own language uses (`T`/`X` in French, for
/// `travail`/`indisponible`; English gets its own initials rather than a translation of those).
String ocptPresenceCodeLetterLabel(Tr tr, OcptPresenceCode code) => switch (code) {
  OcptPresenceCode.working => tr.presenceCodeLetterWorking,
  OcptPresenceCode.unavailable => tr.presenceCodeLetterUnavailable,
};

/// The colour presence code [code] is painted with in the grid — two colours pulled off the ambient
/// theme rather than a bespoke palette, since a code is a state of one person on one day, not a
/// category with its own identity to keep stable across exports the way a coverage colour or a
/// breakdown category colour is.
Color ocptPresenceCodeColor(BuildContext context, OcptPresenceCode code) {
  final theme = Theme.of(context);

  return switch (code) {
    OcptPresenceCode.working => theme.colorScheme.primary,
    OcptPresenceCode.unavailable => ocptWarningColor(context),
  };
}

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

/// The colour a day (or a week/month cell) is tinted with under [OcptScheduleAgendaColorMode.effect]
/// — [ocptScheduleEffectColorOf] applied to [category], or the same neutral `outlineVariant`
/// [ocptScheduleDayLocationTint] falls back to while [category] is null: a day with nothing placed,
/// or whose placed shots carry nothing classifiable (`ocptSceneEffectCategoryOf`), has nothing to
/// say either way.
Color ocptScheduleDayEffectTint(BuildContext context, OcptSceneEffectCategory? category) {
  if (category == null) {
    return Theme.of(context).colorScheme.outlineVariant;
  }

  return Color(ocptScheduleEffectColorOf(category));
}

/// The display label of "Colour by" segment [mode], read by the header's own segmented control.
String ocptScheduleAgendaColorModeLabel(Tr tr, OcptScheduleAgendaColorMode mode) => switch (mode) {
  OcptScheduleAgendaColorMode.location => tr.scheduleAgendaColorModeLocation,
  OcptScheduleAgendaColorMode.effect => tr.scheduleAgendaColorModeEffect,
};

/// The display label of legend entry [category], read by the header's own effect legend.
String ocptSceneEffectCategoryLabel(Tr tr, OcptSceneEffectCategory category) => switch (category) {
  OcptSceneEffectCategory.interiorDay => tr.scheduleAgendaEffectLegendInteriorDay,
  OcptSceneEffectCategory.interiorNight => tr.scheduleAgendaEffectLegendInteriorNight,
  OcptSceneEffectCategory.exteriorDay => tr.scheduleAgendaEffectLegendExteriorDay,
  OcptSceneEffectCategory.exteriorNight => tr.scheduleAgendaEffectLegendExteriorNight,
  OcptSceneEffectCategory.mixed => tr.scheduleAgendaEffectLegendMixed,
};

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
  OcptShootingBlockKind.audition => Icons.record_voice_over_outlined,
  OcptShootingBlockKind.rehearsal => Icons.groups_outlined,
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
/// a person, [roleById]'s own name read through [Tr.scheduleConvocationsUncastRoleLabel] for an
/// uncast role, [personById]'s own display name again for an address-book guest, the guest's own
/// verbatim free name, or — for a candidate — **who is coming and the part they are coming to be
/// seen for**, read through [roleCandidateById] and printed in the very shape an audition block's
/// own timetable row already prints it. Exactly one of [OcptDayConvocation.personId]/
/// [OcptDayConvocation.roleId]/[OcptDayConvocation.guestPersonId]/
/// [OcptDayConvocation.guestFreeName]/[OcptDayConvocation.roleCandidateId] is ever non-null (the
/// same discriminator `breakdown_tags` uses, ADR 0014), so there is never a choice to make between
/// the five readings, only which one applies. No suffix marks a guest's or a candidate's title: the
/// panel groups each under its own trailing heading instead of decorating every row.
///
/// A candidate's title names the part **because nobody plays it yet**: two candidacies of one person
/// are two convocations, and a name alone could not tell an assistant director which of the two they
/// are looking at.
///
/// An uncast role's own suffix is what keeps a role's row from reading as a person's: the question
/// this panel answers is "when does this human arrive", and a role nobody is cast in is still a
/// convocation the production has to honour, just not yet a human one.
String ocptScheduleConvocationTitle(
  Tr tr,
  OcptDayConvocation convocation,
  Map<String, OcptPerson> personById,
  Map<String, OcptRole> roleById, {
  Map<String, OcptRoleCandidate> roleCandidateById = const {},
}) {
  final personId = convocation.personId;
  if (personId != null) {
    final person = personById[personId];
    return person == null || person.displayName.isEmpty
        ? tr.resourcesUnnamedPerson
        : person.displayName;
  }

  final guestPersonId = convocation.guestPersonId;
  if (guestPersonId != null) {
    final guest = personById[guestPersonId];
    return guest == null || guest.displayName.isEmpty ? tr.resourcesUnnamedPerson : guest.displayName;
  }

  final guestFreeName = convocation.guestFreeName;
  if (guestFreeName != null) {
    return guestFreeName.isEmpty ? tr.resourcesUnnamedPerson : guestFreeName;
  }

  final roleCandidateId = convocation.roleCandidateId;
  if (roleCandidateId != null) {
    final candidate = roleCandidateById[roleCandidateId];
    final candidateName = candidate == null || candidate.person.displayName.isEmpty
        ? tr.resourcesUnnamedPerson
        : candidate.person.displayName;
    final role = candidate == null ? null : roleById[candidate.roleId];

    return tr.scheduleAuditionBlockLabel(
      candidateName,
      role == null || role.name.isEmpty ? tr.resourcesRoleUnnamed : role.name,
    );
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

/// The display name of whoever holds the `director` position in [people] — the address book's own
/// declared `person_positions`, not a project column — or an empty string when nobody does.
///
/// Read by [ocptCallSheetLabelsOf]/[ocptShootingPlanLabelsOf] to build the `directorLine` both
/// label classes carry (through [ocptScheduleDirectorLineOf]): the director's name is not typed
/// anywhere on the project, it is read off whoever the crew catalogue already says holds the
/// position, and printing nothing is the honest reading when nobody does yet.
String ocptScheduleDirectorNameOf(List<OcptPerson> people) {
  for (final person in people) {
    if (person.positions.any((position) => position.positionId == ocptDirectorPositionId)) {
      return person.displayName;
    }
  }
  return "";
}

/// The `directorLine` both `OcptCallSheetLabels` and `OcptShootingPlanLabels` carry:
/// [Tr.scheduleExportDirectorLine] naming whoever [ocptScheduleDirectorNameOf] finds among [people],
/// or an empty string while nobody holds the position yet — the manager-layer PDF services print
/// nothing rather than a guess (both classes' own `directorLine` doc comments).
String ocptScheduleDirectorLineOf(Tr tr, List<OcptPerson> people) {
  final name = ocptScheduleDirectorNameOf(people);
  return name.isEmpty ? "" : tr.scheduleExportDirectorLine(name);
}

/// Builds every localized string the exported call sheets — general and named alike — carry.
///
/// The single bridge between the UI's `Tr` and `OcptCallSheetPdfService`, which runs in the manager
/// layer and has no `BuildContext` of its own to resolve anything with — mirroring
/// `ocptBreakdownSheetsLabelsOf`. Every enum label map reuses the very `ocpt…Label` helpers this
/// file and `ocpt_resources_labels.dart` already expose to the mode's own widgets
/// ([ocptCrewDepartmentLabel], [ocptCrewPositionLabel], [ocptShootingBlockKindLabel] — and, for
/// [ocptShootingPlanLabelsOf]'s own [OcptShootingPlanLabels.elementCategoryLabels],
/// [ocptElementCategoryLabel]), so a printed call sheet or shooting plan can never name a
/// department, a position, a block kind or an element category differently from the screen.
///
/// [days] is resolved into [OcptCallSheetLabels.dayTitles] through `DateFormat.yMMMMEEEEd`, in the
/// UI's own locale, upper-cased to match the reference `.docx`'s own shouted day heading
/// (`FEUILLE DE SERVICE DU JEUDI 10 AOÛT 2023`) — the one section of this document whose whole
/// point is to be read at a glance pinned to a wall. [people] is read for
/// [ocptScheduleDirectorLineOf] alone.
///
/// [OcptCallSheetLabels.eventsSectionTitle], [OcptCallSheetLabels.candidatesSectionTitle] and
/// [OcptCallSheetLabels.guestsSectionTitle] reuse the very `Tr` keys the day view and the
/// `Convocations` dock panel already print those three words under
/// (`scheduleDayEventsSectionTitle`, `scheduleConvocationsCandidatesSectionTitle`,
/// `scheduleConvocationsGuestsSectionTitle`): a printed sheet must not name a thing differently
/// from the screen it was planned on. [OcptCallSheetLabels.auditionsSectionTitle] gets a key of its
/// own because no screen carries that word in the plural: the timetable names one block at a time
/// (`scheduleBlockKindAudition`), where the printed table heads a list of them.
OcptCallSheetLabels ocptCallSheetLabelsOf(
  BuildContext context, {
  required List<OcptShootingDay> days,
  required List<OcptPerson> people,
}) {
  final tr = Tr.of(context);
  final locale = Localizations.localeOf(context).toString();

  return OcptCallSheetLabels(
    fileNamePrefix: tr.scheduleExportCallSheetFileNamePrefix,
    documentTitle: tr.scheduleExportCallSheetDocumentTitle,
    dayTitles: {
      for (final day in days)
        day.id: tr
            .scheduleExportCallSheetDayTitle(DateFormat.yMMMMEEEEd(locale).format(day.date))
            .toUpperCase(),
    },
    directorLine: ocptScheduleDirectorLineOf(tr, people),
    versionLabel: tr.scheduleExportVersionLabel,
    dayTagPrefix: tr.scheduleDayTagPrefix,
    dayNumberLabel: tr.scheduleExportDayNumberLabel,
    recipientsSectionTitle: tr.scheduleExportRecipientsSectionTitle,
    namedRecipientLabel: tr.scheduleExportNamedRecipientLabel,
    crewNoteSectionTitle: tr.scheduleInspectorCrewNoteLabel,
    locationSectionTitle: tr.scheduleInspectorLocationsLabel,
    mapsLinkLabel: tr.scheduleExportMapsLinkLabel,
    sunSectionTitle: tr.scheduleInspectorSunLabel,
    civilDawnLabel: tr.scheduleExportCivilDawnLabel,
    sunriseLabel: tr.scheduleExportSunriseLabel,
    sunsetLabel: tr.scheduleExportSunsetLabel,
    civilDuskLabel: tr.scheduleExportCivilDuskLabel,
    contactsSectionTitle: tr.scheduleExportContactsSectionTitle,
    crewDepartmentLabels: {
      for (final department in OcptCrewDepartment.values) department: ocptCrewDepartmentLabel(tr, department),
    },
    crewPositionLabels: {
      for (final position in ocptCrewPositions) position.id: ocptCrewPositionLabel(tr, position.id),
    },
    hoursLinePrefix: tr.scheduleExportHoursLinePrefix,
    patLabel: tr.scheduleExportPatLabel,
    arrivalHeader: tr.scheduleExportArrivalHeader,
    departureLabel: tr.scheduleExportDepartureLabel,
    toBringSectionTitle: tr.scheduleExportToBringSectionTitle,
    blockKindLabels: {
      for (final kind in OcptShootingBlockKind.values) kind: ocptShootingBlockKindLabel(tr, kind),
    },
    seqHeader: tr.scheduleExportSeqHeader,
    plansHeader: tr.scheduleExportPlansHeader,
    effetHeader: tr.scheduleExportEffetHeader,
    decorsHeader: tr.scheduleExportDecorsHeader,
    rolesHeader: tr.scheduleExportRolesHeader,
    castSectionTitle: tr.scheduleExportCastSectionTitle,
    roleHeader: tr.scheduleExportRoleHeader,
    actorHeader: tr.scheduleExportActorHeader,
    nameHeader: tr.scheduleExportNameHeader,
    positionsHeader: tr.scheduleExportPositionsHeader,
    phoneHeader: tr.scheduleExportPhoneHeader,
    emailHeader: tr.scheduleExportEmailHeader,
    crewListSectionTitle: tr.scheduleExportCrewListSectionTitle,
    castAndExtrasListSectionTitle: tr.scheduleExportCastAndExtrasListSectionTitle,
    emptyDayNote: tr.scheduleExportEmptyDayNote,
    unnamedPersonLabel: tr.scheduleExportUnnamedPersonLabel,
    eventsSectionTitle: tr.scheduleDayEventsSectionTitle,
    auditionsSectionTitle: tr.scheduleExportAuditionsSectionTitle,
    candidatesSectionTitle: tr.scheduleConvocationsCandidatesSectionTitle,
    guestsSectionTitle: tr.scheduleConvocationsGuestsSectionTitle,
    guestReasonHeader: tr.scheduleExportGuestReasonHeader,
  );
}

/// Builds every localized string the exported shooting plan carries — mirrors
/// [ocptCallSheetLabelsOf] for the same reasons; see its own doc comment.
///
/// [days] is resolved into [OcptShootingPlanLabels.dayTitles] through `DateFormat.MMMMEEEEd` (no
/// year, unlike the call sheet's own day heading): a day agenda page is a working document read
/// alongside the rest of the plan rather than a sheet pinned on its own, so it reads in the app's
/// ordinary sentence case rather than the call sheet's shouted one.
OcptShootingPlanLabels ocptShootingPlanLabelsOf(
  BuildContext context, {
  required List<OcptShootingDay> days,
  required List<OcptPerson> people,
}) {
  final tr = Tr.of(context);
  final locale = Localizations.localeOf(context).toString();

  return OcptShootingPlanLabels(
    fileNameSuffix: tr.scheduleExportShootingPlanFileNameSuffix,
    documentTitle: tr.scheduleExportShootingPlanDocumentTitle,
    dayTitles: {
      for (final day in days)
        day.id: tr.scheduleExportShootingPlanDayTitle(DateFormat.MMMMEEEEd(locale).format(day.date)),
    },
    tenMinuteGridSectionTitle: tr.scheduleExportTenMinuteGridSectionTitle,
    directorLine: ocptScheduleDirectorLineOf(tr, people),
    versionLabel: tr.scheduleExportVersionLabel,
    dayTagPrefix: tr.scheduleDayTagPrefix,
    locationsGridTitle: tr.scheduleExportLocationsGridTitle,
    sequencesGridTitle: tr.scheduleExportSequencesGridTitle,
    peopleGridTitle: tr.scheduleExportPeopleGridTitle,
    elementsGridTitle: tr.scheduleExportElementsGridTitle,
    locationsGridRowHeader: tr.scheduleExportLocationsGridRowHeader,
    sequencesGridRowHeader: tr.scheduleExportSequencesGridRowHeader,
    peopleGridRowHeader: tr.scheduleExportPeopleGridRowHeader,
    elementsGridRowHeader: tr.scheduleExportElementsGridRowHeader,
    elementCategoryLabels: {
      for (final category in OcptElementCategory.values) category: ocptElementCategoryLabel(tr, category),
    },
    persoLabel: tr.scheduleExportPersoLabel,
    sequenceRowPrefix: tr.scheduleExportSequenceRowPrefix,
    presenceMark: tr.scheduleExportPresenceMark,
    crewPositionLabels: {
      for (final position in ocptCrewPositions) position.id: ocptCrewPositionLabel(tr, position.id),
    },
    dayLocationLabel: tr.scheduleExportDayLocationLabel,
    dayHoursLabel: tr.scheduleExportDayHoursLabel,
    daySetsLabel: tr.scheduleExportDaySetsLabel,
    dayTimetableLabel: tr.scheduleExportDayTimetableLabel,
    callTimeLabel: tr.scheduleExportCallTimeLabel,
    estimatedEndLabel: tr.scheduleExportEstimatedEndLabel,
    milestoneFromLabel: tr.scheduleExportMilestoneFromLabel,
    milestoneToLabel: tr.scheduleExportMilestoneToLabel,
    blockKindLabels: {
      for (final kind in OcptShootingBlockKind.values) kind: ocptShootingBlockKindLabel(tr, kind),
    },
    rolesLabel: tr.scheduleExportRolesHeader,
    hoursHeader: tr.scheduleExportShotHoursHeader,
    planHeader: tr.shotListColumnShot,
    shotSizeHeader: tr.shotListColumnShotSize,
    moveHeader: tr.scheduleExportMoveHeader,
    framingHeader: tr.scheduleExportFramingHeader,
    commentHeader: tr.scheduleExportCommentHeader,
    emptyPlanNote: tr.scheduleExportEmptyPlanNote,
    emptyDayScheduleNote: tr.scheduleExportEmptyDayNote,
    eventsSectionTitle: tr.scheduleDayEventsSectionTitle,
    guestsSectionTitle: tr.scheduleConvocationsGuestsSectionTitle,
    guestReasonHeader: tr.scheduleExportGuestReasonHeader,
    nameHeader: tr.scheduleExportNameHeader,
    hoursLinePrefix: tr.scheduleExportHoursLinePrefix,
    unnamedPersonLabel: tr.scheduleExportUnnamedPersonLabel,
  );
}

/// Builds every localized string the exported shooting plan **workbook** carries.
///
/// The sibling of [ocptShootingPlanLabelsOf] for the second export the shooting plan offers
/// (`OcptShootingPlanXlsxExportService`, which runs in the manager layer and has no `BuildContext`
/// of its own), reusing the very same `ocpt…Label` helpers — the day tag, the presence mark, the
/// `Perso.`/sequence-row words, the crew position and element category labels — so a workbook cell
/// can never name a day, a position or a category differently from the printed plan.
/// [OcptShootingPlanXlsxLabels.blockKindLabels] is the one map with no counterpart on
/// [OcptShootingPlanLabels]: it carries all eight [OcptShootingBlockKind] values,
/// [OcptShootingBlockKind.shot] included, where the printed plan's own map only ever falls back to
/// the seven milestone kinds a caption may need.
///
/// Unlike [ocptShootingPlanLabelsOf], this takes no `days`/`people`: nothing here needs a day's own
/// formatted title or the project's director line, a spreadsheet naming a day through its own
/// `dayTagPrefix` and a real date cell instead.
OcptShootingPlanXlsxLabels ocptShootingPlanXlsxLabelsOf(BuildContext context) {
  final tr = Tr.of(context);

  return OcptShootingPlanXlsxLabels(
    fileNameSuffix: tr.scheduleExportShootingPlanFileNameSuffix,
    locationsSheetName: tr.scheduleExportShootingPlanXlsxLocationsSheetName,
    sequencesSheetName: tr.scheduleExportShootingPlanXlsxSequencesSheetName,
    peopleSheetName: tr.scheduleExportShootingPlanXlsxPeopleSheetName,
    elementsSheetName: tr.scheduleExportShootingPlanXlsxElementsSheetName,
    chronologySheetName: tr.scheduleExportShootingPlanXlsxChronologySheetName,
    locationsRowHeader: tr.scheduleExportLocationsGridRowHeader,
    sequencesRowHeader: tr.scheduleExportSequencesGridRowHeader,
    peopleRowHeader: tr.scheduleExportPeopleGridRowHeader,
    elementsRowHeader: tr.scheduleExportElementsGridRowHeader,
    chronologyColumnHeaders: {
      OcptShootingPlanXlsxColumn.dayTag: tr.scheduleExportDayNumberLabel,
      OcptShootingPlanXlsxColumn.date: tr.scheduleExportShootingPlanXlsxDateColumnHeader,
      OcptShootingPlanXlsxColumn.slot: tr.scheduleInspectorSlotLabel,
      OcptShootingPlanXlsxColumn.start: tr.scheduleSlotStartLabel,
      OcptShootingPlanXlsxColumn.end: tr.scheduleSlotEndLabel,
      OcptShootingPlanXlsxColumn.kind: tr.scheduleExportShootingPlanXlsxKindColumnHeader,
      OcptShootingPlanXlsxColumn.shot: tr.shotListColumnShot,
      OcptShootingPlanXlsxColumn.sequence: tr.scheduleExportSeqHeader,
      OcptShootingPlanXlsxColumn.set: tr.scheduleExportDecorsHeader,
      OcptShootingPlanXlsxColumn.roles: tr.scheduleExportRolesHeader,
      OcptShootingPlanXlsxColumn.durationMinutes: tr.scheduleExportShootingPlanXlsxDurationColumnHeader,
      OcptShootingPlanXlsxColumn.crewNote: tr.scheduleInspectorBlockCrewNoteLabel,
    },
    dayTagPrefix: tr.scheduleDayTagPrefix,
    presenceMark: tr.scheduleExportPresenceMark,
    persoLabel: tr.scheduleExportPersoLabel,
    sequenceRowPrefix: tr.scheduleExportSequenceRowPrefix,
    crewPositionLabels: {
      for (final position in ocptCrewPositions) position.id: ocptCrewPositionLabel(tr, position.id),
    },
    elementCategoryLabels: {
      for (final category in OcptElementCategory.values) category: ocptElementCategoryLabel(tr, category),
    },
    blockKindLabels: {
      for (final kind in OcptShootingBlockKind.values) kind: ocptShootingBlockKindLabel(tr, kind),
    },
  );
}

/// Builds every localized string the exported *Day Out of Days* carries — mirrors
/// [ocptShootingPlanLabelsOf] for the same reasons; see [ocptCallSheetLabelsOf]'s own doc comment.
///
/// [days] is resolved into [OcptDayOutOfDaysLabels.dayDateLabels] through `DateFormat.Md` — the
/// shortest date this app prints anywhere, and deliberately so: it sits under a day tag in a column
/// two or three letters wide, one of as many columns as the shoot has days. [people] is read for
/// [ocptScheduleDirectorLineOf] alone.
///
/// The five code letters are carried through `Tr` like everything else rather than hard-coded, so a
/// production working in another convention can be given its own — see
/// [OcptDayOutOfDaysLabels.codeLabels]. They read the same in both languages the app ships in
/// today, which is exactly why the legend beside them is fully localized.
OcptDayOutOfDaysLabels ocptDayOutOfDaysLabelsOf(
  BuildContext context, {
  required List<OcptShootingDay> days,
  required List<OcptPerson> people,
}) {
  final tr = Tr.of(context);
  final locale = Localizations.localeOf(context).toString();

  return OcptDayOutOfDaysLabels(
    fileNameSuffix: tr.scheduleExportDayOutOfDaysFileNameSuffix,
    documentTitle: tr.scheduleExportDayOutOfDaysDocumentTitle,
    directorLine: ocptScheduleDirectorLineOf(tr, people),
    versionLabel: tr.scheduleExportVersionLabel,
    dayTagPrefix: tr.scheduleDayTagPrefix,
    dayDateLabels: {for (final day in days) day.id: DateFormat.Md(locale).format(day.date)},
    roleHeader: tr.scheduleExportDayOutOfDaysRoleHeader,
    workedDaysHeader: tr.scheduleExportDayOutOfDaysWorkedDaysHeader,
    heldDaysHeader: tr.scheduleExportDayOutOfDaysHeldDaysHeader,
    codeLabels: {
      for (final code in OcptDayOutOfDaysCode.values) code: ocptDayOutOfDaysCodeLabel(tr, code),
    },
    codeDescriptions: {
      for (final code in OcptDayOutOfDaysCode.values) code: ocptDayOutOfDaysCodeDescription(tr, code),
    },
    legendSectionTitle: tr.scheduleExportDayOutOfDaysLegendTitle,
    unnamedRoleLabel: tr.resourcesRoleUnnamed,
    emptyTableNote: tr.scheduleExportDayOutOfDaysEmptyNote,
  );
}

/// The letter [code] is printed as in a *Day Out of Days* cell — `SW`, `W`, `WF`, `SWF` or `H`.
String ocptDayOutOfDaysCodeLabel(Tr tr, OcptDayOutOfDaysCode code) => switch (code) {
  OcptDayOutOfDaysCode.startWork => tr.scheduleExportDayOutOfDaysStartWorkCode,
  OcptDayOutOfDaysCode.work => tr.scheduleExportDayOutOfDaysWorkCode,
  OcptDayOutOfDaysCode.workFinish => tr.scheduleExportDayOutOfDaysWorkFinishCode,
  OcptDayOutOfDaysCode.startWorkFinish => tr.scheduleExportDayOutOfDaysStartWorkFinishCode,
  OcptDayOutOfDaysCode.hold => tr.scheduleExportDayOutOfDaysHoldCode,
};

/// What [code] means, as the *Day Out of Days*' own legend reads it out.
String ocptDayOutOfDaysCodeDescription(Tr tr, OcptDayOutOfDaysCode code) => switch (code) {
  OcptDayOutOfDaysCode.startWork => tr.scheduleExportDayOutOfDaysStartWorkDescription,
  OcptDayOutOfDaysCode.work => tr.scheduleExportDayOutOfDaysWorkDescription,
  OcptDayOutOfDaysCode.workFinish => tr.scheduleExportDayOutOfDaysWorkFinishDescription,
  OcptDayOutOfDaysCode.startWorkFinish => tr.scheduleExportDayOutOfDaysStartWorkFinishDescription,
  OcptDayOutOfDaysCode.hold => tr.scheduleExportDayOutOfDaysHoldDescription,
};

/// Builds every localized string the exported one-line schedule carries — mirrors
/// [ocptShootingPlanLabelsOf] for the same reasons; see [ocptCallSheetLabelsOf]'s own doc comment.
///
/// [days] is resolved into [OcptOneLineScheduleLabels.dayTitles] through the very
/// `DateFormat.MMMMEEEEd` [ocptShootingPlanLabelsOf] uses for its own [OcptShootingPlanLabels
/// .dayTitles]: a day band prints its tag on its own, so its title needs only the date, never a
/// sentence built around it. [people] is read for [ocptScheduleDirectorLineOf] alone.
OcptOneLineScheduleLabels ocptOneLineScheduleLabelsOf(
  BuildContext context, {
  required List<OcptShootingDay> days,
  required List<OcptPerson> people,
}) {
  final tr = Tr.of(context);
  final locale = Localizations.localeOf(context).toString();

  return OcptOneLineScheduleLabels(
    fileNameSuffix: tr.scheduleExportOneLineScheduleFileNameSuffix,
    documentTitle: tr.scheduleExportOneLineScheduleDocumentTitle,
    directorLine: ocptScheduleDirectorLineOf(tr, people),
    versionLabel: tr.scheduleExportVersionLabel,
    dayTagPrefix: tr.scheduleDayTagPrefix,
    dayTitles: {for (final day in days) day.id: DateFormat.MMMMEEEEd(locale).format(day.date)},
    seqHeader: tr.scheduleExportSeqHeader,
    effectHeader: tr.scheduleExportEffetHeader,
    decorHeader: tr.scheduleExportDecorsHeader,
    rolesHeader: tr.scheduleExportRolesHeader,
    durationHeader: tr.scheduleExportOneLineScheduleDurationHeader,
    noLocationLabel: tr.scheduleDayNoLocation,
    emptyDayNote: tr.scheduleExportEmptyDayNote,
    emptyDocumentNote: tr.scheduleExportEmptyPlanNote,
  );
}

/// Builds every localized string [day]'s own exported sides booklet carries — mirrors
/// [ocptOneLineScheduleLabelsOf] for the same reasons; see [ocptCallSheetLabelsOf]'s own doc
/// comment.
///
/// Takes the one printed [day] rather than the whole list every other resolver here takes, and
/// resolves its title through the very `DateFormat.MMMMEEEEd` they use for their own day bands: a
/// booklet is one day's own paperwork, so there is a single title to carry rather than a map keyed
/// by day id. A null [day] — a selection naming a day the mode no longer holds — leaves that title
/// empty, which the running head prints as its own document title alone.
///
/// [episodes] is resolved into [OcptSidesLabels.episodeLabels] through [ocptWorkspaceEpisodeLabelOf]
/// — one entry per episode while [episodes] holds more than one ([ocptEpisodePrefixNumberOf] is
/// what already runs that test for every other export of this app, reused here rather than
/// restated), and an empty map on a single-episode project, so the booklet names no episode
/// anywhere (ADR 0019).
OcptSidesLabels ocptSidesLabelsOf(
  BuildContext context, {
  required OcptShootingDay? day,
  required List<OcptEpisode> episodes,
}) {
  final tr = Tr.of(context);
  final locale = Localizations.localeOf(context).toString();

  return OcptSidesLabels(
    fileNameSuffix: tr.scheduleExportSidesFileNameSuffix,
    documentTitle: tr.scheduleExportSidesDocumentTitle,
    versionLabel: tr.scheduleExportVersionLabel,
    dayTagPrefix: tr.scheduleDayTagPrefix,
    dayTitle: day == null ? "" : DateFormat.MMMMEEEEd(locale).format(day.date),
    episodeLabels: {
      for (final episode in episodes)
        if (ocptEpisodePrefixNumberOf(episodes: episodes, screenplayId: episode.id) != null)
          episode.id: ocptWorkspaceEpisodeLabelOf(tr, episode),
    },
    scriptPagePrefix: tr.scheduleExportSidesScriptPagePrefix,
    emptyDayNote: tr.scheduleExportSidesEmptyDayNote,
  );
}

/// The sides export dialog's own label for [presentation] — what each of the two shapes a booklet
/// can take is called where the user picks between them.
String ocptSidesPresentationLabel(Tr tr, OcptSidesPresentation presentation) => switch (presentation) {
  OcptSidesPresentation.scriptPages => tr.scheduleExportSidesScriptPagesOption,
  OcptSidesPresentation.packed => tr.scheduleExportSidesPackedOption,
};

/// The alerts panel's own title for an [OcptScheduleAlertKind] card — see that enum's own doc
/// comment for exactly what each of the eleven rules claims.
String ocptScheduleAlertKindLabel(Tr tr, OcptScheduleAlertKind kind) => switch (kind) {
  OcptScheduleAlertKind.personUnavailable => tr.scheduleAlertKindPersonUnavailable,
  OcptScheduleAlertKind.personDoubleBooked => tr.scheduleAlertKindPersonDoubleBooked,
  OcptScheduleAlertKind.locationUncovered => tr.scheduleAlertKindLocationUncovered,
  OcptScheduleAlertKind.roleNotConvoked => tr.scheduleAlertKindRoleNotConvoked,
  OcptScheduleAlertKind.roleUncast => tr.scheduleAlertKindRoleUncast,
  OcptScheduleAlertKind.timelineOverrun => tr.scheduleAlertKindTimelineOverrun,
  OcptScheduleAlertKind.slotFixedEndMissed => tr.scheduleAlertKindFixedEndMissed,
  OcptScheduleAlertKind.presenceExceeded => tr.scheduleAlertKindPresenceExceeded,
  OcptScheduleAlertKind.restTime => tr.scheduleAlertKindRestTime,
  OcptScheduleAlertKind.permitNotValid => tr.scheduleAlertKindPermitNotValid,
};

/// The alerts panel's own body sentence for [alert] — the one place an id or a raw minute figure
/// `lib/utils/ocpt_schedule_alerts.dart` carries is turned into a name or a formatted time, that
/// file knowing neither by design (its own class doc comment).
///
/// A person, a role or a location an alert names that no longer resolves through [personById]/
/// [roleById]/[locationById] still reads as something (`Tr.resourcesUnnamedPerson`/
/// `Tr.resourcesRoleUnnamed`/`Tr.resourcesLocationUnnamed`), exactly as every other reader of those
/// maps in this mode falls back — an alert computed against a stale read is not expected in
/// practice ([alert] and the maps are built from the very same snapshot), but a sentence must never
/// go blank over it. [slotById] and [blockById] are keyed across the **whole schedule**, not one
/// day, since an alert's own [OcptScheduleAlert.dayId] is read separately by the caller (the day
/// control beside the sentence) — this function only ever resolves the ids the alert itself carries.
String ocptScheduleAlertSentence(
  Tr tr,
  OcptScheduleAlert alert, {
  required Map<String, OcptPerson> personById,
  required Map<String, OcptRole> roleById,
  required Map<String, OcptLocation> locationById,
  required Map<String, OcptShootingSlot> slotById,
  required Map<String, OcptShootingDayBlock> blockById,
  required OcptShot? Function(String shotId) shotOf,
}) => switch (alert) {
  OcptSchedulePersonUnavailableAlert(:final personId, :final slotIds) =>
    tr.scheduleAlertPersonUnavailableSentence(
      _ocptScheduleAlertPersonNameOf(tr, personById, personId),
      [for (final slotId in slotIds) _ocptConvocationSlotLabelOf(tr, slotById[slotId])].join(" · "),
    ),
  OcptSchedulePersonDoubleBookedAlert(:final personId, :final firstSlotId, :final secondSlotId) =>
    tr.scheduleAlertPersonDoubleBookedSentence(
      _ocptScheduleAlertPersonNameOf(tr, personById, personId),
      _ocptConvocationSlotLabelOf(tr, slotById[firstSlotId]),
      _ocptConvocationSlotLabelOf(tr, slotById[secondSlotId]),
    ),
  OcptScheduleLocationUncoveredAlert(:final slotId, :final locationId) =>
    tr.scheduleAlertLocationUncoveredSentence(
      _ocptConvocationSlotLabelOf(tr, slotById[slotId]),
      _ocptScheduleAlertLocationNameOf(tr, locationById, locationId),
    ),
  OcptScheduleRoleNotConvokedAlert(:final roleId, :final shotId) =>
    tr.scheduleAlertRoleNotConvokedSentence(
      _ocptScheduleAlertRoleNameOf(tr, roleById, roleId),
      shotOf(shotId)?.code ?? "",
    ),
  OcptScheduleRoleUncastAlert(:final roleId) =>
    tr.scheduleAlertRoleUncastSentence(_ocptScheduleAlertRoleNameOf(tr, roleById, roleId)),
  OcptScheduleTimelineOverrunAlert(:final blockId, :final reachedMinute, :final anchorMinute) =>
    tr.scheduleAlertTimelineOverrunSentence(
      _ocptScheduleAlertBlockLabelOf(tr, blockById[blockId], shotOf),
      ocptFormatDayMinute(anchorMinute),
      ocptFormatDayMinute(reachedMinute),
    ),
  OcptScheduleFixedEndMissedAlert(:final slotId, :final fixedEndMinute, :final actualEndMinute) =>
    tr.scheduleAlertFixedEndMissedSentence(
      _ocptConvocationSlotLabelOf(tr, slotById[slotId]),
      ocptFormatDayMinute(fixedEndMinute),
      ocptFormatDayMinute(actualEndMinute),
    ),
  OcptSchedulePresenceExceededAlert(
    :final personId,
    :final presenceMinutes,
    :final maxDailyPresenceMinutes,
  ) =>
    tr.scheduleAlertPresenceExceededSentence(
      _ocptScheduleAlertPersonNameOf(tr, personById, personId),
      ocptFormatMinuteDuration(presenceMinutes),
      ocptFormatMinuteDuration(maxDailyPresenceMinutes),
    ),
  OcptScheduleRestTimeAlert(:final personId, :final restMinutes, :final minimumRestMinutes) =>
    tr.scheduleAlertRestTimeSentence(
      _ocptScheduleAlertPersonNameOf(tr, personById, personId),
      ocptFormatMinuteDuration(restMinutes),
      ocptFormatMinuteDuration(minimumRestMinutes),
    ),
  OcptSchedulePermitNotValidAlert(:final slotId, :final locationId) =>
    tr.scheduleAlertPermitNotValidSentence(
      _ocptConvocationSlotLabelOf(tr, slotById[slotId]),
      _ocptScheduleAlertLocationNameOf(tr, locationById, locationId),
    ),
};

/// [personId]'s own display name, or [Tr.resourcesUnnamedPerson] while [personById] holds nothing
/// for it (empty or missing) — see [ocptScheduleAlertSentence]'s own doc comment.
String _ocptScheduleAlertPersonNameOf(Tr tr, Map<String, OcptPerson> personById, String personId) {
  final displayName = personById[personId]?.displayName ?? "";
  return displayName.isEmpty ? tr.resourcesUnnamedPerson : displayName;
}

/// [roleId]'s own name, or [Tr.resourcesRoleUnnamed] while [roleById] holds nothing for it.
String _ocptScheduleAlertRoleNameOf(Tr tr, Map<String, OcptRole> roleById, String roleId) {
  final name = roleById[roleId]?.name ?? "";
  return name.isEmpty ? tr.resourcesRoleUnnamed : name;
}

/// [locationId]'s own name, or [Tr.resourcesLocationUnnamed] while [locationById] holds nothing for
/// it.
String _ocptScheduleAlertLocationNameOf(
  Tr tr,
  Map<String, OcptLocation> locationById,
  String locationId,
) {
  final name = locationById[locationId]?.name ?? "";
  return name.isEmpty ? tr.resourcesLocationUnnamed : name;
}

/// [block]'s own readable identity for the timeline-overrun sentence: a shot block reads as its own
/// shot's code (falling back to the block kind's own label while the shot itself doesn't resolve),
/// any other kind reads as its own free-text label (falling back to the block kind's own label while
/// that is empty) — mirroring how a timetable row itself reads a block (`OcptScheduleTimetable`). An
/// em dash while [block] itself doesn't resolve, which should not happen in practice (an alert is
/// computed against the very snapshot the caller's own map is keyed from) but must still read as
/// something.
String _ocptScheduleAlertBlockLabelOf(
  Tr tr,
  OcptShootingDayBlock? block,
  OcptShot? Function(String shotId) shotOf,
) {
  if (block == null) {
    return "—";
  }

  final shotId = block.shotId;
  if (block.kind == OcptShootingBlockKind.shot && shotId != null) {
    final code = shotOf(shotId)?.code ?? "";
    if (code.isNotEmpty) {
      return code;
    }
  }

  return block.label.isEmpty ? ocptShootingBlockKindLabel(tr, block.kind) : block.label;
}
