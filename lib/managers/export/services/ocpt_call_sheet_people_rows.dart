// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_rows.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_style.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_ordered_schedule_entry.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shot_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// Get the day's own candidates list: **one row per candidacy** the day sees
/// ([OcptDayConvocation.roleCandidateIds]), carrying the person's name, the part they are coming to
/// be seen for, their phone, their email and their arrival – departure band.
///
/// One row per candidacy rather than per person, unlike the sheet itself: somebody read for two
/// parts is one call and two things to look up, and this list is what an assistant director looks
/// things up in. Their two rows carry the same hours — one person, one call — and differ by the
/// part, which is the whole of what the reader came for.
///
/// **Day-wide on both sheets**, printed under the cast table: this is a directory, and it answers
/// "who is expected today for a part and how do I reach them" — a question about the day rather
/// than about which of its slots happens to convoke the reader, exactly as the crew list, the
/// cast-and-extras list and the trailing guest table already are.
///
/// **[onlyRoleCandidateIds] is the one exception in this whole file**, and a named sheet whose
/// recipient the day sees for a part is the only thing that ever passes it: their sheet prints
/// their own lines and no other. The reason is not tidiness — who else is being seen for a part,
/// and on what phone number, is the production's business and not another candidate's. Every other
/// directory on that same sheet stays day-wide, a candidate reading the crew and cast lists exactly
/// as any other recipient does.
///
/// The part is named through the **candidacy** rather than through the person, which is the whole
/// reason `shooting_block_candidates` points at a `role_candidates` row: two candidacies of one
/// person are two convocations, and a list naming the person alone could not tell an assistant
/// director which of the two they are looking at. A convocation whose candidacy
/// [OcptSchedulePlanSnapshot.roleCandidateById] no longer holds is left out entirely rather than
/// printed nameless — the same reading the convocations panel already gives a vanished candidacy.
///
/// Sorted by name, as the two lists beside it are, rather than by arrival: a directory is read by
/// looking somebody up.
List<OcptCallSheetPeopleListEntry> ocptCallSheetCandidateListEntries({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  required OcptCallSheetLabels labels,
  Set<String>? onlyRoleCandidateIds,
}) {
  final entries = <OcptCallSheetPeopleListEntry>[];

  for (final convocation in plan.convocationsOfDay(dayId)) {
    for (final roleCandidateId in convocation.roleCandidateIds) {
      if (onlyRoleCandidateIds != null && !onlyRoleCandidateIds.contains(roleCandidateId)) {
        continue;
      }
      final candidate = plan.roleCandidateById[roleCandidateId];
      if (candidate == null) {
        continue;
      }

      final name = candidate.person.displayName.trim();
      entries.add(
        OcptCallSheetPeopleListEntry(
          name: name.isEmpty ? labels.unnamedPersonLabel : name,
          positionOrRole: ocptScheduleRoleLabelOf(plan.roleById[candidate.roleId]) ?? "",
          phone: candidate.person.phone,
          email: candidate.person.email,
          scheduleLabel: ocptScheduleArrivalDepartureLabel(convocation),
        ),
      );
    }
  }

  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}

/// Get a named sheet's own "to bring" rows: [OcptSchedulePlanSnapshot.elementsToBringOnDay] for
/// [personId] — already sorted by category then by name — paired with the scene numbers of
/// [dayEntries]' own shot blocks that play a scene each element is linked to, mirroring how
/// [ocptCallSheetCastRowsOfDay]'s own `sceneNumbers` is built off the very same [dayEntries]. Both
/// this function and [ocptCallSheetCastRowsOfDay] are handed the **day's** own entries rather than
/// the recipient's restricted `orderedEntries`, for the comment there's own reason: what an element
/// is needed for today is a fact about the day, not about which of its slots happens to convoke
/// this reader.
List<OcptCallSheetToBringRow> ocptCallSheetToBringRowsOfDay({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  required String personId,
  required List<OcptOrderedScheduleEntry> dayEntries,
}) {
  final elements = plan.elementsToBringOnDay(dayId: dayId, personId: personId);
  if (elements.isEmpty) {
    return const [];
  }

  return [
    for (final element in elements)
      OcptCallSheetToBringRow(
        element: element,
        sceneNumbers: ocptCallSheetSceneNumbersForElement(
          element: element,
          plan: plan,
          dayEntries: dayEntries,
        ),
      ),
  ];
}

/// Get the scene numbers of [dayEntries]' own shot blocks whose scene is one of [element]'s own
/// [OcptElement.sceneLinks], sorted — the join [ocptCallSheetToBringRowsOfDay] prints on each of
/// its rows.
List<String> ocptCallSheetSceneNumbersForElement({
  required OcptElement element,
  required OcptSchedulePlanSnapshot plan,
  required List<OcptOrderedScheduleEntry> dayEntries,
}) {
  final sceneIds = {for (final link in element.sceneLinks) link.sceneId};
  final sceneNumbers = <String>{};

  for (final ordered in dayEntries) {
    if (ordered.block.kind != OcptShootingBlockKind.shot || ordered.block.shotId == null) {
      continue;
    }
    final shot = plan.shotById(ordered.block.shotId!);
    if (shot != null && shot.sceneId != null && sceneIds.contains(shot.sceneId)) {
      sceneNumbers.add(ocptShotSceneNumberOf(shot));
    }
  }

  return sceneNumbers.toList()..sort();
}

/// Get every crew contact of [dayId], across every live slot, deduplicated by (person, position
/// label)
/// — a person linked to two slots under the same position prints once, not twice.
List<OcptCallSheetCrewContact> ocptCallSheetCrewContactsOfDay({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  required OcptCallSheetLabels labels,
}) {
  final positionById = {for (final position in ocptCrewPositions) position.id: position};
  final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
  final seen = <String>{};
  final contacts = <OcptCallSheetCrewContact>[];

  for (final slot in slots) {
    for (final member in slot.crew) {
      final person = plan.personById[member.personId];
      if (person == null) {
        continue;
      }
      final position = member.positionId.isEmpty ? null : positionById[member.positionId];
      final positionLabel = position != null
          ? labels.crewPositionLabelOf(position.id)
          : member.customLabel;
      final key = "${person.id}|$positionLabel";
      if (!seen.add(key)) {
        continue;
      }
      contacts.add(
        OcptCallSheetCrewContact(
          person: person,
          positionLabel: positionLabel,
          department: position?.department,
        ),
      );
    }
  }

  return contacts;
}

/// Get the crew list's own rows: one per distinct person of [crewContacts], their own positions
/// comma-joined, their own arrival – departure band read off [convocations].
List<OcptCallSheetPeopleListEntry> ocptCallSheetCrewListEntries({
  required List<OcptCallSheetCrewContact> crewContacts,
  required List<OcptDayConvocation> convocations,
}) {
  final convocationByPersonId = {
    for (final c in convocations)
      if (c.personId != null) c.personId!: c,
  };
  final positionsByPersonId = <String, List<String>>{};
  final personById = <String, OcptPerson>{};

  for (final contact in crewContacts) {
    personById[contact.person.id] = contact.person;
    (positionsByPersonId[contact.person.id] ??= <String>[]).add(contact.positionLabel);
  }

  final entries = [
    for (final person in personById.values)
      OcptCallSheetPeopleListEntry(
        name: person.displayName,
        positionOrRole: (positionsByPersonId[person.id] ?? const <String>[]).join(", "),
        phone: person.phone,
        email: person.email,
        scheduleLabel: ocptScheduleArrivalDepartureLabel(convocationByPersonId[person.id]),
      ),
  ];

  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}

/// Get the cast-and-extras list's own rows: one per [castRows] entry, the actor's own name (or
/// [OcptCallSheetLabels.unnamedPersonLabel] for an uncast role) and the role's own number and name
/// as its position column.
///
/// It follows the cast table row for row, a role the day's shots play but nobody convoked included:
/// this list answers "how do I reach the people this day is about", and the one person an assistant
/// director needs to phone on the morning of a shoot is precisely the actor nobody called. Their
/// `HORAIRES` cell reads as an em dash, as their cast row's own times do.
List<OcptCallSheetPeopleListEntry> ocptCallSheetCastListEntries({
  required List<OcptCallSheetCastRow> castRows,
  required OcptCallSheetLabels labels,
}) {
  final entries = [
    for (final row in castRows)
      OcptCallSheetPeopleListEntry(
        name: (row.actor?.displayName ?? "").trim().isEmpty
            ? labels.unnamedPersonLabel
            : row.actor!.displayName,
        positionOrRole: "${row.role.number} · ${row.role.name}",
        phone: row.actor?.phone ?? "",
        email: row.actor?.email ?? "",
        scheduleLabel: ocptScheduleArrivalDepartureLabel(row.convocation),
      ),
  ];

  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}

/// Get [convocation]'s own PAT band, or [ocptScheduleEmptyValue] while it has none — ADR 0018: a
/// slot
/// with no shooting block gives no band at all, and this is never fabricated.
String ocptCallSheetPatCellOf(OcptDayConvocation? convocation) {
  if (convocation == null) {
    return ocptScheduleEmptyValue;
  }
  final start = convocation.patStartMinute;
  final end = convocation.patEndMinute;
  if (start == null || end == null) {
    return ocptScheduleEmptyValue;
  }
  return "${ocptFormatDayMinute(start)} – ${ocptFormatDayMinute(end)}";
}

/// Get the role numbers of every role whose character is in one of [row]'s own
/// [OcptCallSheetDayRow.shots], among [roles] — matched the way the app already matches a shot's
/// own characters to a role everywhere else, through `normalizeCharacterName`.
String ocptCallSheetRolesLabelOf(OcptCallSheetDayRow row, List<OcptRole> roles) {
  final characterNames = <String>{for (final shot in row.shots) ...shot.characters};
  if (characterNames.isEmpty) {
    return ocptScheduleEmptyValue;
  }

  final byNormalizedName = {for (final role in roles) normalizeCharacterName(role.name): role};
  final matched = <OcptRole>{};
  for (final name in characterNames) {
    final role = byNormalizedName[name];
    if (role != null) {
      matched.add(role);
    }
  }

  if (matched.isEmpty) {
    return ocptScheduleEmptyValue;
  }

  final sorted = matched.toList()..sort((a, b) => a.number.compareTo(b.number));
  return sorted.map((role) => "${role.number}").join(", ");
}

/// Get one time-band line (`<label> : 16:45 – 22:45`), or `<label> : 16:45` when [endMinute] is
/// null —
/// a milestone whose block resolves to zero duration, or a slot with nothing placed on it yet.
String ocptCallSheetTimeBandLine({
  required String label,
  required int startMinute,
  required int? endMinute,
}) {
  final start = ocptFormatDayMinute(startMinute);
  if (endMinute == null) {
    return "$label : $start";
  }
  return "$label : $start – ${ocptFormatDayMinute(endMinute)}";
}

/// Get the Google Maps URL built from [location]'s own coordinates, or null while it has none — the
/// app
/// holds no map-link column of its own and makes no network call to build one (§A.8 of the
/// reference note this service was built against).
String? ocptCallSheetMapsUrlOf(OcptLocation location) {
  final latitude = location.latitude;
  final longitude = location.longitude;
  if (latitude == null || longitude == null) {
    return null;
  }
  return "https://www.google.com/maps?q=$latitude,$longitude";
}

/// Get [convocation]'s own display name: the person's — a candidate being a person like any other,
/// so
/// there is nothing extra to resolve — the uncast role's, or
/// [OcptCallSheetLabels.unnamedPersonLabel] while neither names anybody printable.
String ocptCallSheetConvocationDisplayNameOf(
  OcptDayConvocation convocation,
  OcptSchedulePlanSnapshot plan,
  OcptCallSheetLabels labels,
) {
  final personId = convocation.personId;
  if (personId != null) {
    final name = plan.personById[personId]?.displayName.trim() ?? "";
    if (name.isNotEmpty) {
      return name;
    }
  }

  final roleId = convocation.roleId;
  if (roleId != null) {
    final name = plan.roleById[roleId]?.name.trim() ?? "";
    if (name.isNotEmpty) {
      return name;
    }
  }

  return labels.unnamedPersonLabel;
}

/// Get **everything the day asks of [convocation]**, comma-joined: the positions they crew under,
/// the
/// parts they play, and the parts they are coming to be seen for — or, for an uncast convocation,
/// the role it names and nothing else.
///
/// One line rather than one reason, because a sheet is addressed to a **person**: somebody
/// gaffering the morning and read for Marie at eleven holds both that day, and a header naming one
/// of the two would be picking which half of their day counts. Read off [ownSlots] for the work and
/// off [OcptDayConvocation.roleCandidateIds] for the auditions, so it can never name something the
/// timetable below it does not.
///
/// Each part is prefixed by [OcptCallSheetLabels.roleHeader] and printed in the shape the cast
/// table names a role in, so a reader holding both can match them; a crew position carries no
/// prefix, being unambiguous on its own.
String ocptCallSheetConvocationPositionsLabel({
  required OcptDayConvocation convocation,
  required List<OcptShootingSlot> ownSlots,
  required OcptSchedulePlanSnapshot plan,
  required OcptCallSheetLabels labels,
}) {
  final personId = convocation.personId;
  if (personId == null) {
    final roleId = convocation.roleId;
    final label = ocptScheduleRoleLabelOf(roleId == null ? null : plan.roleById[roleId]);
    return label == null ? "" : "${labels.roleHeader} $label";
  }

  final positionById = {for (final position in ocptCrewPositions) position.id: position};
  final seen = <String>{};
  final parts = <String>[];

  void add(String label) {
    if (label.isNotEmpty && seen.add(label)) {
      parts.add(label);
    }
  }

  for (final slot in ownSlots) {
    for (final member in slot.crew) {
      if (member.personId != personId) {
        continue;
      }
      final position = member.positionId.isEmpty ? null : positionById[member.positionId];
      add(position != null ? labels.crewPositionLabelOf(position.id) : member.customLabel);
    }

    // The parts they play on this unit: a cast row names a role, and the actor behind it is
    // `roles.personId` — the same join the cast table itself makes.
    for (final member in slot.cast) {
      final role = plan.roleById[member.roleId];
      if (role == null || role.personId != personId) {
        continue;
      }
      if (ocptScheduleRoleLabelOf(role) case final label?) {
        add("${labels.roleHeader} $label");
      }
    }
  }

  // And the parts they are being seen for, which is the one thing on this line that is not work
  // they already hold.
  for (final roleCandidateId in convocation.roleCandidateIds) {
    final candidate = plan.roleCandidateById[roleCandidateId];
    if (candidate == null) {
      continue;
    }
    if (ocptScheduleRoleLabelOf(plan.roleById[candidate.roleId]) case final label?) {
      add("${labels.roleHeader} $label");
    }
  }

  return parts.join(", ");
}

/// Turn [value] into a safe fragment of a file name: diacritics folded (through
/// [ocptCallSheetFileNameDiacriticsFold], case kept), unsafe characters
/// ([ocptCallSheetUnsafeFileNameChars]) dropped, runs of whitespace turned into a single dash, and
/// any leading/trailing dash trimmed.
String ocptCallSheetSafeFileNamePart(String value) {
  final folded = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final replacement = ocptCallSheetFileNameDiacriticsFold[lower];
    if (replacement == null) {
      folded.write(char);
    } else {
      folded.write(char == lower ? replacement : replacement.toUpperCase());
    }
  }

  final withoutUnsafe = folded.toString().replaceAll(ocptCallSheetUnsafeFileNameChars, "");
  final dashed = withoutUnsafe.trim().replaceAll(RegExp(r"\s+"), "-");
  return dashed.replaceAll(RegExp(r"^-+|-+$"), "");
}
