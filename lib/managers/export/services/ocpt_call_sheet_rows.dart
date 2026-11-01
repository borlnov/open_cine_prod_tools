// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_ordered_schedule_entry.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shot_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind_shooting_time.dart';

/// One printed row of the main table: either a run of one or more consecutive [shots] on the same
/// slot and the same scene, collapsed the way the reference call sheets do, or a single
/// [milestoneCaption] naming a full-width band.
class OcptCallSheetDayRow {
  /// The slot this row's [shots] were placed on, or null for a milestone.
  final String? slotId;

  /// The scene this row's [shots] belong to, or null for a milestone or an orphaned shot.
  final String? sceneId;

  /// The heading of [sceneId], or null.
  final String? heading;

  /// The name of the set this row's slot is shot at, or null.
  final String? decors;

  /// The shots collapsed into this row — always exactly one until a following shot of the same
  /// scene, on the same slot, is appended to it.
  final List<OcptShot> shots;

  /// This row's own caption, non-null exactly for a milestone.
  final String? milestoneCaption;

  /// The numbers of the roles this milestone's own band expects, sorted — always empty but for a
  /// hair-and-make-up band, and empty there too while its slot convokes nobody.
  final List<int> milestoneRoleNumbers;

  /// Where this row starts, resolved.
  final int startMinute;

  /// Where this row ends, resolved — mutable so a following collapsed shot can extend it.
  int? endMinute;

  /// The trimmed, non-empty [OcptShootingDayBlock.crewNote]s of the blocks collapsed into this row,
  /// in the blocks' own order — always at most one entry for a milestone row (one block), and
  /// possibly several for a shot run once a following collapsed shot's own note is appended to it.
  /// **Never** the block's own private `notes`, which this document never prints at all.
  final List<String> crewNotes;

  /// Whether this is a milestone row rather than a run of shot blocks.
  bool get isMilestone => milestoneCaption != null;

  /// Create a row from its parts, for the factories below.
  OcptCallSheetDayRow._({
    required this.slotId,
    required this.sceneId,
    required this.heading,
    required this.decors,
    required this.shots,
    required this.milestoneCaption,
    required this.milestoneRoleNumbers,
    required this.startMinute,
    required this.endMinute,
    required this.crewNotes,
  });

  /// Builds a row starting a new run of shot blocks, seeded with [crewNote]'s own printable crew
  /// note, if it has one.
  factory OcptCallSheetDayRow.shotRun({
    required String slotId,
    required String? sceneId,
    required String? heading,
    required String? decors,
    required OcptShot shot,
    required int startMinute,
    required int endMinute,
    required String crewNote,
  }) => OcptCallSheetDayRow._(
    slotId: slotId,
    sceneId: sceneId,
    heading: heading,
    decors: decors,
    shots: [shot],
    milestoneCaption: null,
    milestoneRoleNumbers: const [],
    startMinute: startMinute,
    endMinute: endMinute,
    crewNotes: crewNote.trim().isEmpty ? [] : [crewNote.trim()],
  );

  /// Builds a full-width milestone row, carrying the numbers of the roles its own band expects
  /// ([ocptScheduleBlockRoleNumbersOf]) — empty for every kind but a hair-and-make-up band — and
  /// its own block's printable crew note, if it has one.
  factory OcptCallSheetDayRow.milestone({
    required String caption,
    required List<int> roleNumbers,
    required int startMinute,
    required int? endMinute,
    required String crewNote,
  }) => OcptCallSheetDayRow._(
    slotId: null,
    sceneId: null,
    heading: null,
    decors: null,
    shots: const [],
    milestoneCaption: caption,
    milestoneRoleNumbers: roleNumbers,
    startMinute: startMinute,
    endMinute: endMinute,
    crewNotes: crewNote.trim().isEmpty ? [] : [crewNote.trim()],
  );
}

/// One row of the day's own cast table.
class OcptCallSheetCastRow {
  /// The role convoked.
  final OcptRole role;

  /// The actor cast in [role], or null while it is uncast.
  final OcptPerson? actor;

  /// The scene numbers this role's character is shot in today, sorted.
  final List<String> sceneNumbers;

  /// This role's (or its actor's) own computed convocation, or null while nobody linked it to a
  /// slot at all — which should not happen for a role a cast row already names, but is read
  /// defensively rather than assumed.
  final OcptDayConvocation? convocation;

  /// Class constructor
  const OcptCallSheetCastRow({
    required this.role,
    required this.actor,
    required this.sceneNumbers,
    required this.convocation,
  });
}

/// One printed row of the day's own audition table: an audition block's resolved hours, the part it
/// sees, and who is being seen for it.
///
/// **One row per candidacy, not per block**: two actors of two different parts read together are
/// two rows sharing one hour (ADR 0024), and a block naming nobody yet is one row carrying its hour
/// alone.
class OcptCallSheetAuditionRow {
  /// Where this audition starts, resolved off the timeline like every other hour on this sheet.
  final int startMinute;

  /// Where it ends, resolved off the same timeline.
  final int endMinute;

  /// The part being seen, as `<number> · <name>` ([ocptScheduleRoleLabelOf]), or null while the
  /// block names nobody — an ordinary state, exactly as a hold with no sequence is — or while the
  /// candidacy names a part the project has since deleted. The caller prints
  /// [ocptScheduleEmptyValue] for it.
  final String? roleLabel;

  /// Who is being seen, or null under the same conditions as [roleLabel]. Their phone number is
  /// deliberately not here: it sits in the day's own candidates directory, where a directory
  /// belongs.
  final String? candidateName;

  /// Class constructor
  const OcptCallSheetAuditionRow({
    required this.startMinute,
    required this.endMinute,
    required this.roleLabel,
    required this.candidateName,
  });
}

/// One crew member's own contact: who they are, what they hold that day, and which department that
/// position belongs to (null for a free-text `OcptShootingSlotCrewMember.customLabel` the catalogue
/// has no department for).
class OcptCallSheetCrewContact {
  /// The person themselves.
  final OcptPerson person;

  /// The label of the position they hold that day — the catalogue's own label, or their own free
  /// text.
  final String positionLabel;

  /// The department [positionLabel] belongs to, or null for a free-text position.
  final OcptCrewDepartment? department;

  /// Class constructor
  const OcptCallSheetCrewContact({
    required this.person,
    required this.positionLabel,
    required this.department,
  });
}

/// One row of the crew list or the cast-and-extras list — the two lists print the same shape, so
/// they share this type.
class OcptCallSheetPeopleListEntry {
  /// The person's own display name, or [OcptCallSheetLabels.unnamedPersonLabel] for an uncast role.
  final String name;

  /// The position(s) they hold, comma-joined, or the role's own number and name.
  final String positionOrRole;

  /// Their own phone number, empty when there is none (an uncast role has nobody's phone to print).
  final String phone;

  /// Their own email address, empty for the same reason.
  final String email;

  /// Their own arrival – departure band, or [ocptScheduleEmptyValue] while they have no convocation
  /// at all.
  final String scheduleLabel;

  /// Class constructor
  const OcptCallSheetPeopleListEntry({
    required this.name,
    required this.positionOrRole,
    required this.phone,
    required this.email,
    required this.scheduleLabel,
  });
}

/// One row of a named sheet's own "to bring" table: an element
/// [OcptSchedulePlanSnapshot.elementsToBringOnDay] joined onto that sheet's own recipient, and the
/// scene numbers of the day's own shots that play a scene it is linked to.
class OcptCallSheetToBringRow {
  /// The element the recipient is due to bring.
  final OcptElement element;

  /// The scene numbers of the day's own shots that play a scene [element] is linked to, sorted —
  /// empty when [element] is linked to a scene the day plays through no numbered shot at all, which
  /// still prints ([ocptScheduleEmptyValue]) rather than being left out: the join already
  /// established the element belongs on this list, and a bare scene id would explain nothing on a
  /// printed page.
  final List<String> sceneNumbers;

  /// Class constructor
  const OcptCallSheetToBringRow({required this.element, required this.sceneNumbers});
}

/// Turns [orderedEntries] into the printed rows of the main table: a run of consecutive
/// [OcptShootingBlockKind.shot] blocks on the same slot and the same scene collapses into one
/// [OcptCallSheetDayRow], every other kind prints its own [OcptCallSheetDayRow.milestone].
List<OcptCallSheetDayRow> ocptCallSheetBuildDayRows({
  required OcptSchedulePlanSnapshot plan,
  required List<OcptOrderedScheduleEntry> orderedEntries,
  required Map<String, String> headingBySceneId,
  required OcptCallSheetLabels labels,
}) {
  final rows = <OcptCallSheetDayRow>[];

  for (final ordered in orderedEntries) {
    final block = ordered.block;
    final entry = ordered.entry;
    final slot = ordered.slot;

    if (block.kind == OcptShootingBlockKind.shot) {
      final shot = block.shotId == null ? null : plan.shotById(block.shotId!);
      if (shot == null) {
        continue;
      }

      final last = rows.isNotEmpty ? rows.last : null;
      if (last != null &&
          !last.isMilestone &&
          last.slotId == slot.id &&
          shot.sceneId != null &&
          last.sceneId == shot.sceneId) {
        last.shots.add(shot);
        last.endMinute = entry.endMinute;
        final note = block.crewNote.trim();
        if (note.isNotEmpty) {
          last.crewNotes.add(note);
        }
        continue;
      }

      rows.add(
        OcptCallSheetDayRow.shotRun(
          slotId: slot.id,
          sceneId: shot.sceneId,
          heading: shot.sceneId == null ? null : headingBySceneId[shot.sceneId],
          decors: slot.setId == null ? null : plan.setById[slot.setId]?.name,
          shot: shot,
          startMinute: entry.startMinute,
          endMinute: entry.endMinute,
          crewNote: block.crewNote,
        ),
      );
      continue;
    }

    rows.add(
      OcptCallSheetDayRow.milestone(
        caption: ocptCallSheetCaptionOf(
          block: block,
          labels: labels,
          headingBySceneId: headingBySceneId,
          roleById: plan.roleById,
          roleCandidateById: plan.roleCandidateById,
        ),
        roleNumbers: ocptScheduleBlockRoleNumbersOf(
          block: block,
          slot: slot,
          roleById: plan.roleById,
        ),
        startMinute: entry.startMinute,
        endMinute: entry.endMinute,
        crewNote: block.crewNote,
      ),
    );
  }

  return rows;
}

/// The caption a non-shot [block] prints: its own free-text label when it has one, then whatever
/// that kind of block names — a sequence's heading for a hold or a rehearsal, the parts an audition
/// sees, each as its own `<number> · <name>` — or [OcptCallSheetLabels.blockKindLabelOf] as the
/// final fallback.
///
/// A thin alias over [ocptScheduleBlockCaptionOf] (`ocpt_schedule_pdf_shared.dart`), shared with
/// `OcptShootingPlanPdfService` — see that function's own doc comment for why. The roles a
/// hair-and-make-up band expects are **not** part of it: they are
/// [ocptScheduleBlockRoleNumbersOf]'s own answer, printed on the band's own second line.
String ocptCallSheetCaptionOf({
  required OcptShootingDayBlock block,
  required OcptCallSheetLabels labels,
  required Map<String, String> headingBySceneId,
  required Map<String, OcptRole> roleById,
  required Map<String, OcptRoleCandidate> roleCandidateById,
}) => ocptScheduleBlockCaptionOf(
  block: block,
  headingBySceneId: headingBySceneId,
  roleById: roleById,
  roleCandidateById: roleCandidateById,
  blockKindLabelOf: labels.blockKindLabelOf,
);

/// The day's own cast table rows: one per role the day **calls for** — every role convoked on one
/// of its live slots, and every role a shot placed on it plays — the scenes each of them shoots
/// today read off [orderedEntries]' own shot blocks.
///
/// **A role the day's shots name is listed even when nobody convoked it**, and that is the whole
/// point of the table: the main table's own `RÔLES` column prints role *numbers*, and a reader
/// looking `3` up has nowhere else on the sheet to find out who that is. Such a row carries no
/// convocation, so its `ARRIVÉE` and `PAT` cells read as em dashes — which is the truthful reading
/// of "this role plays today and nobody has called them", the very thing
/// `OcptScheduleRoleNotConvokedAlert` raises in the app. It is never guessed at from the shot's own
/// hours: a convocation is the slot you are linked to (ADR 0018), and a role linked to none has no
/// times at all.
///
/// Both generators pass the **whole day's** entries, a named sheet included: this table says who
/// the day calls for, and a `SEQ` cell counting only the sequences its reader happens to share a
/// slot with would understate every other actor's day.
List<OcptCallSheetCastRow> ocptCallSheetCastRowsOfDay({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  required List<OcptOrderedScheduleEntry> orderedEntries,
}) {
  final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
  final convocations = plan.convocationsOfDay(dayId);
  final convocationByPersonId = {
    for (final c in convocations)
      if (c.personId != null) c.personId!: c,
  };
  final convocationByRoleId = {
    for (final c in convocations)
      if (c.roleId != null) c.roleId!: c,
  };
  final roleByNormalizedName = {
    for (final role in plan.roles) normalizeCharacterName(role.name): role,
  };

  final seenRoleIds = <String>{};
  final rows = <OcptCallSheetCastRow>[];

  void addRow(OcptRole role) {
    if (!seenRoleIds.add(role.id)) {
      return;
    }

    final actor = role.personId == null ? null : plan.personById[role.personId];
    final convocation = actor != null
        ? convocationByPersonId[actor.id]
        : convocationByRoleId[role.id];

    final normalizedName = normalizeCharacterName(role.name);
    final sceneNumbers = <String>{};
    for (final ordered in orderedEntries) {
      if (ordered.block.kind != OcptShootingBlockKind.shot || ordered.block.shotId == null) {
        continue;
      }
      final shot = plan.shotById(ordered.block.shotId!);
      if (shot != null && shot.characters.contains(normalizedName)) {
        sceneNumbers.add(ocptShotSceneNumberOf(shot));
      }
    }

    rows.add(
      OcptCallSheetCastRow(
        role: role,
        actor: actor,
        sceneNumbers: sceneNumbers.toList()..sort(),
        convocation: convocation,
      ),
    );
  }

  for (final slot in slots) {
    for (final member in slot.cast) {
      if (plan.roleById[member.roleId] case final role?) {
        addRow(role);
      }
    }
  }

  // The roles the day's own shots play, convoked or not — the same `shot.characters` join the main
  // table's own `RÔLES` column reads, so the two can never name a role the other cannot resolve. A
  // character name matching no role of the project resolves to nothing and is skipped, exactly as
  // that column skips it.
  for (final ordered in orderedEntries) {
    if (ordered.block.kind != OcptShootingBlockKind.shot || ordered.block.shotId == null) {
      continue;
    }
    final shot = plan.shotById(ordered.block.shotId!);
    if (shot == null) {
      continue;
    }
    for (final characterName in shot.characters) {
      if (roleByNormalizedName[characterName] case final role?) {
        addRow(role);
      }
    }
  }

  rows.sort((a, b) => a.role.number.compareTo(b.role.number));
  return rows;
}

/// The subset of [ownSlotEntries] a named sheet addressed to [convocation] actually prints: what
/// its recipient is **in**, rather than everything happening on the units they are on.
///
/// A sheet is what one person reads down to know their own day, and an actor handed the whole
/// running order has to work out which of its shots are theirs — which is the job the sheet was
/// meant to do for them. Four rules, in this order:
///
/// - **Every milestone stays**, for everybody: preparation, hair and make-up, a meal, a break, a
///   travel move, the wrap. Somebody who cannot see when they eat has been handed a worse sheet,
///   not a shorter one.
/// - **A technician keeps their whole unit.** A slot naming them as crew is a running order they
///   work end to end, so every block of it stays whatever it plays.
/// - **An audition stays when it names one of their own candidacies** — the same narrowing the
///   audition table itself makes, and for the same reason: somebody else's twenty minutes is not
///   their business.
/// - **A shot, a hold or a rehearsal stays when it calls a part they play**, matched through
///   `normalizeCharacterName` exactly as the main table's own `RÔLES` column and the cast table
///   already match one.
///
/// **A block the app cannot resolve any part for stays**, which is the fourth rule's own escape
/// hatch and not an oversight: a hold reserves the time of a sequence the shot list often cannot
/// yet describe, and a scene with no shot on it names no character. Dropping it would be guessing
/// that the recipient is not in a sequence nobody has broken down yet, and the truthful reading of
/// "the app cannot say" is to leave the row where the production put it.
List<OcptOrderedScheduleEntry> ocptCallSheetEntriesOfRecipient({
  required OcptSchedulePlanSnapshot plan,
  required OcptDayConvocation convocation,
  required List<OcptOrderedScheduleEntry> ownSlotEntries,
}) {
  final personId = convocation.personId;

  // The parts this recipient plays, by normalised character name: the roles cast in them, or — for
  // an uncast convocation — the one role it names, nobody being cast in it to read through.
  final playedNames = <String>{
    for (final role in plan.roles)
      if ((personId != null && role.personId == personId) || role.id == convocation.roleId)
        normalizeCharacterName(role.name),
  };

  /// The characters a block calls, empty when the app cannot say — see the doc comment.
  Set<String> charactersOf(OcptShootingDayBlock block) {
    if (block.kind == OcptShootingBlockKind.shot) {
      final shotId = block.shotId;
      return shotId == null ? const {} : (plan.shotById(shotId)?.characters.toSet() ?? const {});
    }

    final sceneId = block.sceneId;
    if (sceneId == null) {
      return const {};
    }

    // A held or rehearsed sequence names no characters of its own: the app reads them off the shots
    // it has been broken into, which is the only join `_calledRolesOfDay` makes either.
    return {
      for (final shot in plan.shotsById.values)
        if (shot.sceneId == sceneId) ...shot.characters,
    };
  }

  /// Whether [ordered] belongs on this recipient's own sheet — the four rules of the doc comment,
  /// in order.
  bool keeps(OcptOrderedScheduleEntry ordered) {
    if (!ordered.block.kind.isShootingTime) {
      return true;
    }
    if (personId != null && ordered.slot.crew.any((member) => member.personId == personId)) {
      return true;
    }
    if (ordered.block.kind == OcptShootingBlockKind.audition) {
      return ordered.block.candidates.any(
        (link) => convocation.roleCandidateIds.contains(link.roleCandidateId),
      );
    }

    final characters = charactersOf(ordered.block);
    return characters.isEmpty || characters.intersection(playedNames).isNotEmpty;
  }

  return [
    for (final ordered in ownSlotEntries)
      if (keeps(ordered)) ordered,
  ];
}

/// The audition rows of [orderedEntries]: one per candidacy every [OcptShootingBlockKind.audition]
/// block names, in the timetable's own resolved order and, within a block, in its candidacies' own
/// `sortKey` order — each carrying that block's hours, the part being seen and who is being seen
/// for it. A block naming nobody yet still prints **one** row, carrying its hour alone: the day
/// plans something at that time, and a table that hid it would be a running order with a gap in it.
///
/// Read off the very entries the main table is built from, so the two tables of one sheet can never
/// order the day differently — which is also why a named sheet's own narrowed entries narrow the
/// audition table with it: it is a reading of the timetable, and the timetable is the one thing a
/// named sheet narrows.
///
/// **[onlyRoleCandidateIds], when given, narrows it to that recipient's own candidacies** — the
/// reading a named sheet whose recipient the day sees for a part gets, and the one place a
/// block-level link narrows something a slot-level one could not. The reason is not tidiness: who
/// else is being seen for a part is the production's business and not another candidate's. Every
/// other directory on their sheet stays day-wide.
///
/// A candidacy [OcptSchedulePlanSnapshot.roleCandidateById] no longer holds is dropped rather than
/// printed nameless — the same reading the convocations panel already gives a vanished candidacy.
List<OcptCallSheetAuditionRow> ocptCallSheetAuditionRowsOfDay({
  required OcptSchedulePlanSnapshot plan,
  required List<OcptOrderedScheduleEntry> orderedEntries,
  Set<String>? onlyRoleCandidateIds,
}) {
  final rows = <OcptCallSheetAuditionRow>[];

  for (final ordered in orderedEntries) {
    if (ordered.block.kind != OcptShootingBlockKind.audition) {
      continue;
    }

    final candidacies = <OcptRoleCandidate>[];
    for (final link in ordered.block.candidates) {
      if (onlyRoleCandidateIds != null && !onlyRoleCandidateIds.contains(link.roleCandidateId)) {
        continue;
      }
      final candidate = plan.roleCandidateById[link.roleCandidateId];
      if (candidate != null) {
        candidacies.add(candidate);
      }
    }

    // A block narrowed away entirely by [onlyRoleCandidateIds] is somebody else's hour, and says
    // nothing to this recipient — unlike a block that genuinely names nobody, which is this day's
    // own plan and keeps its empty row.
    if (candidacies.isEmpty && onlyRoleCandidateIds != null) {
      continue;
    }

    if (candidacies.isEmpty) {
      rows.add(
        OcptCallSheetAuditionRow(
          startMinute: ordered.entry.startMinute,
          endMinute: ordered.entry.endMinute,
          roleLabel: null,
          candidateName: null,
        ),
      );
      continue;
    }

    for (final candidate in candidacies) {
      rows.add(
        OcptCallSheetAuditionRow(
          startMinute: ordered.entry.startMinute,
          endMinute: ordered.entry.endMinute,
          roleLabel: ocptScheduleRoleLabelOf(plan.roleById[candidate.roleId]),
          candidateName: candidate.person.displayName.trim().isEmpty
              ? null
              : candidate.person.displayName.trim(),
        ),
      );
    }
  }

  return rows;
}
