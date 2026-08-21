// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// What every PDF built off a shooting schedule prints in place of a value the project has not
/// filled in yet, or a computed figure that has none (a convocation with no PAT band, ADR 0018).
///
/// Shared by `OcptCallSheetPdfService` and `OcptShootingPlanPdfService` — the two documents read
/// the very same schedule, and a printed blank meaning two different things between them would be
/// the app disagreeing with itself about the one thing this milestone exists to get right.
const String ocptScheduleEmptyValue = "—";

/// The moment [exportDate] was produced, as `yyyy-MM-dd HH:mm` — what tells two documents of the
/// same day apart in the hand of somebody holding both.
///
/// It carries the **time** as well as the date on purpose: a call sheet is regularly reissued in the
/// afternoon of the day it was first sent out, and a stamp that stopped at the date would leave its
/// reader with two sheets and no way to tell which one is the one to follow.
///
/// It is deliberately **not** locale-formatted, unlike a day's own title, which the two services
/// take from their caller already localized: this stamp is read as an identifier rather than as a
/// sentence, and `2026-08-08 14:32` sorts, compares and is quoted over the phone in every language
/// the app ships in. It lives here rather than in either service for the reason everything else in
/// this file does — the two documents print the same shoot, and two of them stamped differently
/// would be the app disagreeing with itself about which one is the later.
String ocptScheduleGeneratedAtStamp(DateTime exportDate) =>
    "${exportDate.year.toString().padLeft(4, '0')}-${exportDate.month.toString().padLeft(2, '0')}-"
    "${exportDate.day.toString().padLeft(2, '0')} ${exportDate.hour.toString().padLeft(2, '0')}:"
    "${exportDate.minute.toString().padLeft(2, '0')}";

/// One slot's own block, already placed on the day's clock — the raw material every reader of a
/// day's timetable is built from, whichever of the two schedule PDF exports is reading it.
class OcptOrderedScheduleEntry {
  /// Class constructor
  const OcptOrderedScheduleEntry({required this.slot, required this.block, required this.entry});

  /// The slot [block] belongs to.
  final OcptShootingSlot slot;

  /// The block itself.
  final OcptShootingDayBlock block;

  /// Where [block] is placed — the *resolved* clock, never a stored anchor.
  final OcptShootingTimelineEntry entry;
}

/// Every block of [dayId], across every live slot (or only [onlySlotIds]' own, for a call sheet
/// addressed to one person), placed on the day's clock and sorted **in resolved clock order across
/// every slot**: two blocks starting at the same minute are ordered by their slot's own position in
/// the day, then by chain order — the one place a day's parallel chains are read as a single run,
/// which is what lets a call sheet's two crews, or a shooting plan's own day-part columns, fall out
/// of this app's own per-slot model.
List<OcptOrderedScheduleEntry> ocptOrderedScheduleEntriesOfDay({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  Set<String>? onlySlotIds,
}) {
  final timelines = plan.timelinesOfDay(dayId);
  if (timelines == null) {
    return const [];
  }

  final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
  final blocksById = {
    for (final block in plan.schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[]) block.id: block,
  };

  final tagged = <(int, OcptShootingSlot, OcptShootingTimelineEntry, int)>[];
  for (final (slotIndex, slot) in slots.indexed) {
    if (onlySlotIds != null && !onlySlotIds.contains(slot.id)) {
      continue;
    }
    final timeline = timelines.bySlotId[slot.id];
    if (timeline == null) {
      continue;
    }
    for (final (chainIndex, entry) in timeline.entries.indexed) {
      tagged.add((slotIndex, slot, entry, chainIndex));
    }
  }

  tagged.sort((a, b) {
    final byStart = a.$3.startMinute.compareTo(b.$3.startMinute);
    if (byStart != 0) {
      return byStart;
    }
    final bySlot = a.$1.compareTo(b.$1);
    if (bySlot != 0) {
      return bySlot;
    }
    return a.$4.compareTo(b.$4);
  });

  return [
    for (final (_, slot, entry, _) in tagged)
      if (blocksById[entry.blockId] case final block?) OcptOrderedScheduleEntry(slot: slot, block: block, entry: entry),
  ];
}

/// A map from every real scene's id to its own heading — read by both schedule PDF exports for a
/// [OcptShootingBlockKind.hold] block's own caption, and by the call sheet's main table for its own
/// `EFFET` column. A thin wrapper over `OcptSchedulePlanSnapshot.headingBySceneId`, which the
/// schedule agenda's own "Colour by effect" tint reads too — kept here so neither PDF service has to
/// know the field moved.
Map<String, String> ocptScheduleHeadingBySceneId(OcptSchedulePlanSnapshot plan) =>
    plan.headingBySceneId;

/// The numbers of the roles [slot] convokes, sorted ascending — what a
/// [OcptShootingBlockKind.hairMakeUp] block prints on its own roles line.
///
/// Read off `slot.cast` and nothing else: a make-up chair is a fact about the **unit**, not about
/// which shot happens to be running while somebody sits in it, so every role linked to the slot is
/// expected there whatever the day's blocks say. A role the cast still names but the project has
/// since deleted resolves to nothing and is skipped rather than printed as a gap.
List<int> ocptScheduleSlotRoleNumbersOf({
  required OcptShootingSlot slot,
  required Map<String, OcptRole> roleById,
}) =>
    [for (final member in slot.cast) if (roleById[member.roleId] case final role?) role.number]..sort();

/// The role numbers [block] prints under its own caption: [ocptScheduleSlotRoleNumbersOf]'s answer
/// for a [OcptShootingBlockKind.hairMakeUp] block, and nothing at all for every other kind.
///
/// They are the one thing a person reads a make-up band for: `RÔLES : 3, 5` tells the make-up
/// artist which two actors to plan for, where the caption alone leaves them counting heads off the
/// cast table. They are printed **whatever the caption turned out to be**, a production's own free
/// text for that band ("HMC Loge 2") saying what the band is rather than who is expected in it —
/// and they sit on a **line of their own, behind a label**, rather than in brackets after the
/// caption: a slot convoking forty roles is exactly the sheet whose make-up department needs them
/// most, and a bracketed run of forty numbers is unreadable where a labelled line still scans.
///
/// A slot convoking no role at all answers with an empty list, and the caller prints no line rather
/// than an empty one.
List<int> ocptScheduleBlockRoleNumbersOf({
  required OcptShootingDayBlock block,
  required OcptShootingSlot slot,
  required Map<String, OcptRole> roleById,
}) => block.kind != OcptShootingBlockKind.hairMakeUp
    ? const []
    : ocptScheduleSlotRoleNumbersOf(slot: slot, roleById: roleById);

/// The caption a non-shot [block] prints: its own free-text label when it has one, then **whatever
/// that kind of block names** — a sequence's own heading for a [OcptShootingBlockKind.hold] and a
/// [OcptShootingBlockKind.rehearsal] alike, the parts an [OcptShootingBlockKind.audition] sees, each
/// as its own `<number> · <name>` — or [blockKindLabelOf] as the final fallback.
///
/// **A band says what it is about, not merely what kind it is.** A hold and a rehearsal both name a
/// sequence through the same `shooting_day_blocks.sceneId`, so both read it here: a day of
/// rehearsals whose every band printed the bare word *Rehearsal* would be a running order saying
/// nothing about what is being worked. An audition names its candidacies through
/// `shooting_block_candidates`, and this reads the **parts** off them — deduplicated, in the block's
/// own order, joined by `·`, and in the very shape the cast table already names a role in, so a
/// reader holding both can match them without being told. Two actors of two different parts read
/// together therefore print both parts (ADR 0024).
///
/// The part is printed rather than the person because this caption goes into the shooting plan and
/// the call sheet's own main table, both read by the whole unit: who is being seen is the call
/// sheet's audition table and its candidates directory, where an assistant director needs it. A
/// candidacy [roleCandidateById] no longer holds, or one whose part [roleById] no longer holds,
/// drops out of the caption rather than printing nameless.
///
/// The role numbers a [OcptShootingBlockKind.hairMakeUp] band carries are deliberately **not** part
/// of this string: they are [ocptScheduleBlockRoleNumbersOf]'s own answer, printed on a line of
/// their own by whichever document is drawing the band — see that function for why.
///
/// [blockKindLabelOf] is a resolver rather than a labels object: the two schedule PDF exports each
/// carry their own labels class (`OcptCallSheetLabels`, `OcptShootingPlanLabels`), and this
/// function has no reason to know about either — its caller hands in the one accessor it needs.
/// [roleById] needs no such treatment: a part's own number and name are the project's own text, not
/// something either document translates.
String ocptScheduleBlockCaptionOf({
  required OcptShootingDayBlock block,
  required Map<String, String> headingBySceneId,
  required Map<String, OcptRole> roleById,
  required Map<String, OcptRoleCandidate> roleCandidateById,
  required String Function(OcptShootingBlockKind kind) blockKindLabelOf,
}) {
  final ownLabel = block.label.trim();
  if (ownLabel.isNotEmpty) {
    return ownLabel;
  }

  if (block.sceneId != null &&
      (block.kind == OcptShootingBlockKind.hold || block.kind == OcptShootingBlockKind.rehearsal)) {
    final heading = headingBySceneId[block.sceneId]?.trim();
    if (heading != null && heading.isNotEmpty) {
      return heading;
    }
  }

  if (block.kind == OcptShootingBlockKind.audition) {
    final roleLabels = <String>{};
    for (final candidate in block.candidates) {
      final roleId = roleCandidateById[candidate.roleCandidateId]?.roleId;
      if (roleId == null) {
        continue;
      }
      if (ocptScheduleRoleLabelOf(roleById[roleId]) case final label?) {
        roleLabels.add(label);
      }
    }
    if (roleLabels.isNotEmpty) {
      return roleLabels.join(" · ");
    }
  }

  return blockKindLabelOf(block.kind);
}

/// [role]'s own `<number> · <name>` — the one shape every schedule document names a part in, from
/// the call sheet's cast table to its audition table to a band's own caption — or null while [role]
/// is null (a block or a link pointing at a part the project has since deleted) or names nothing
/// printable.
///
/// Null rather than [ocptScheduleEmptyValue]: a caller drawing a table cell prints the em dash
/// itself, while a caller building a caption falls back on something else entirely, and only the
/// caller knows which of the two it is.
String? ocptScheduleRoleLabelOf(OcptRole? role) {
  final name = role?.name.trim() ?? "";
  return name.isEmpty ? null : "${role!.number} · $name";
}

/// The line [ocptScheduleBlockRoleNumbersOf]'s own answer is printed as, under the band's caption:
/// `<label> : 3, 5`, or null while [roleNumbers] is empty — a band expecting nobody prints no line
/// at all rather than a label followed by nothing.
///
/// [rolesLabel] is the calling document's own already-localized `RÔLES` heading (the call sheet's
/// own main-table column header, the shooting plan's own equivalent), so neither service formats
/// that line its own way.
String? ocptScheduleBlockRoleNumbersLine({
  required List<int> roleNumbers,
  required String rolesLabel,
}) => roleNumbers.isEmpty ? null : "$rolesLabel : ${roleNumbers.join(", ")}";

/// Every distinct location of [slots], in the order they are first met — a general document's own
/// locations (every slot of the day) or a named one's own (only the slots its recipient is linked
/// to).
List<OcptLocation> ocptScheduleLocationsOfSlots(OcptSchedulePlanSnapshot plan, List<OcptShootingSlot> slots) {
  final seen = <String>{};
  final locations = <OcptLocation>[];
  for (final slot in slots) {
    final locationId = slot.locationId;
    if (locationId == null) {
      continue;
    }
    final location = plan.locationById[locationId];
    if (location == null || !seen.add(location.id)) {
      continue;
    }
    locations.add(location);
  }
  return locations;
}

/// [location]'s own name and address, joined into one printable line, or [ocptScheduleEmptyValue]
/// when every part of it is blank.
String ocptScheduleLocationAddressLine(OcptLocation location) {
  final parts = [
    location.name.trim(),
    [location.addressLine1, location.addressLine2].where((line) => line.trim().isNotEmpty).join(", "),
    [location.postalCode, location.city].where((part) => part.trim().isNotEmpty).join(" "),
  ].where((part) => part.trim().isNotEmpty).toList();

  return parts.isEmpty ? ocptScheduleEmptyValue : parts.join(" — ");
}

/// [convocation]'s own arrival – departure band, or [ocptScheduleEmptyValue] while there is no
/// convocation at all.
///
/// Shared by both schedule PDF exports: a call sheet's own crew list and cast-and-extras list read
/// it over a convocation that may not exist (nobody convoked at that position, or an uncast role),
/// which is why it stays nullable-tolerant rather than moving that check onto each caller; a day's
/// own trailing guest table ([ocptScheduleGuestRowsOfDay]) reads the very same band over a
/// convocation that always does.
String ocptScheduleArrivalDepartureLabel(OcptDayConvocation? convocation) {
  if (convocation == null) {
    return ocptScheduleEmptyValue;
  }
  return "${ocptFormatDayMinute(convocation.arrivalMinute)} – ${ocptFormatDayMinute(convocation.departureMinute)}";
}

/// One row of a day's own trailing guest table: a guest convocation's own display name, the
/// reason(s) their own `shooting_slot_guests` rows carry, and their own arrival – departure band.
/// **Never a PAT band** — a guest is not there to shoot (ADR 0018), so there is no field here to
/// carry one at all, unlike a crew or cast row's own.
///
/// Shared by `OcptCallSheetPdfService` and `OcptShootingPlanPdfService`, which both print this exact
/// table (`NOM / MOTIF / HORAIRES`) trailing their own timetable: the join belongs here for the same
/// reason [ocptScheduleBlockCaptionOf] does — two documents reading a guest's name, reason and hours
/// two different ways is exactly what this file exists to rule out. Each service keeps only its own
/// widget that draws the table, the section title and the labels object differing between them.
class OcptScheduleGuestRow {
  /// Class constructor
  const OcptScheduleGuestRow({required this.name, required this.reason, required this.notes, required this.hours});

  /// The guest's own display name — the address-book person's, the free name, or the
  /// `unnamedPersonLabel` [ocptScheduleGuestRowsOfDay] was given while neither names anybody
  /// printable.
  final String name;

  /// The distinct, non-empty reasons every `shooting_slot_guests` row naming this guest on one of
  /// their own slots carries, comma-joined — never picked down to one, since somebody attending two
  /// slots for two different reasons is telling the truth about both.
  final String reason;

  /// The same join over those rows' own free-form notes, printed under [reason] on a muted second
  /// line — empty when none of them carries any.
  final String notes;

  /// This guest's own arrival – departure band ([ocptScheduleArrivalDepartureLabel]).
  final String hours;
}

/// Whether [guest]'s own discriminator half — [OcptShootingSlotGuest.personId] or
/// [OcptShootingSlotGuest.freeName] — matches [convocation]'s, the join [ocptScheduleGuestRowsOfDay]
/// makes between a `shooting_slot_guests` row and the computed convocation it feeds.
bool _guestMatchesConvocation(OcptShootingSlotGuest guest, OcptDayConvocation convocation) =>
    convocation.guestPersonId != null
        ? guest.personId == convocation.guestPersonId
        : guest.freeName == convocation.guestFreeName;

/// [convocation]'s own display name for the trailing guest table: the address-book display name
/// when it carries a [OcptDayConvocation.guestPersonId], its own [OcptDayConvocation.guestFreeName]
/// otherwise — the same discriminator `OcptShootingSlotGuest` itself uses — or [unnamedPersonLabel]
/// while neither names anybody printable, exactly as a crew or cast convocation falls back on its
/// own labels object's equivalent word.
String _guestDisplayNameOf(
  OcptDayConvocation convocation,
  OcptSchedulePlanSnapshot plan,
  String unnamedPersonLabel,
) {
  final guestPersonId = convocation.guestPersonId;
  if (guestPersonId != null) {
    final name = plan.personById[guestPersonId]?.displayName.trim() ?? "";
    if (name.isNotEmpty) {
      return name;
    }
  }

  final freeName = convocation.guestFreeName?.trim() ?? "";
  if (freeName.isNotEmpty) {
    return freeName;
  }

  return unnamedPersonLabel;
}

/// The day's own trailing guest table rows: one per [OcptDayConvocation.isGuest] convocation of
/// [dayId], sorted the way [OcptSchedulePlanSnapshot.convocationsOfDay] already sorts every
/// convocation (by arrival, then by identity).
///
/// A convocation carries no reason and no notes of its own — those live on the
/// `shooting_slot_guests` rows themselves, one per slot a guest is linked to — so this function
/// joins [OcptDayConvocation.slotIds] back onto [OcptShootingSlot.guests], keeping only the rows
/// [_guestMatchesConvocation] matches to this convocation, and folds their distinct non-empty
/// `reason`s and `notes` into the two comma-joined strings [OcptScheduleGuestRow] prints. Both are
/// day-wide, exactly like the section they feed: a guest attending two of the day's slots for two
/// different reasons has both printed, never one picked over the other.
///
/// [unnamedPersonLabel] is the calling document's own already-localized fallback word
/// (`OcptCallSheetLabels.unnamedPersonLabel`/`OcptShootingPlanLabels.unnamedPersonLabel`), taken as a
/// plain string exactly as [ocptScheduleBlockCaptionOf] takes its own `blockKindLabelOf` resolver —
/// this file must not learn about either labels class.
List<OcptScheduleGuestRow> ocptScheduleGuestRowsOfDay({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  required String unnamedPersonLabel,
}) {
  final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
  final guestConvocations = plan.convocationsOfDay(dayId).where((convocation) => convocation.isGuest);

  final rows = <OcptScheduleGuestRow>[];
  for (final convocation in guestConvocations) {
    final ownSlotIds = convocation.slotIds.toSet();
    final reasons = <String>[];
    final notes = <String>[];

    for (final slot in slots) {
      if (!ownSlotIds.contains(slot.id)) {
        continue;
      }
      for (final guest in slot.guests) {
        if (!_guestMatchesConvocation(guest, convocation)) {
          continue;
        }
        final reason = guest.reason.trim();
        if (reason.isNotEmpty && !reasons.contains(reason)) {
          reasons.add(reason);
        }
        final note = guest.notes.trim();
        if (note.isNotEmpty && !notes.contains(note)) {
          notes.add(note);
        }
      }
    }

    rows.add(
      OcptScheduleGuestRow(
        name: _guestDisplayNameOf(convocation, plan, unnamedPersonLabel),
        reason: reasons.join(", "),
        notes: notes.join(", "),
        hours: ocptScheduleArrivalDepartureLabel(convocation),
      ),
    );
  }

  return rows;
}
