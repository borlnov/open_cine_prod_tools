// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One slot of a day, already resolved by the caller (`OcptScheduleState`, never this file, which
/// knows nothing of drift, of `shots`/`shot_characters`/`roles`, or of `ocpt_shooting_day_timeline
/// .dart`'s own types) into exactly what [ocptComputeDayConvocations] needs: who is linked to it,
/// and where its own chain of blocks starts, ends and shoots.
///
/// A person is convoked by being **linked to a slot** (ADR 0018) — there is no lead time, no group
/// and no per-block role resolution left in this file: whoever [personIds]/[uncastRoleIds]/
/// [guestPersonIds]/[guestFreeNames] names is convoked by this slot, for the
/// whole of it, and every clock a convocation carries is read off [startMinute]/[endMinute]/
/// [shootingStartMinute]/[shootingEndMinute] alone.
///
/// **A candidate is the one exception, and is not named here at all**: somebody seen for a part is
/// linked to the audition block that sees them rather than to the unit
/// ([OcptConvocationAudition], ADR 0024).
class OcptConvocationSlot {
  /// Builds a slot to feed to [ocptComputeDayConvocations].
  const OcptConvocationSlot({
    required this.id,
    required this.startMinute,
    required this.endMinute,
    required this.shootingStartMinute,
    required this.shootingEndMinute,
    required this.personIds,
    required this.uncastRoleIds,
    required this.guestPersonIds,
    required this.guestFreeNames,
  });

  /// The slot's own id (`shooting_slots.id`), echoed back on every [OcptDayConvocation.slotIds] that
  /// includes it.
  final String id;

  /// The slot's own `startMinute` — where its chain of blocks starts, whether or not it carries any
  /// yet.
  final int startMinute;

  /// The slot's own last block end (`OcptShootingSlotTimeline.endMinute`), or null while it carries
  /// no block at all — a slot with nothing placed on it yet still convokes whoever is linked to it,
  /// just with nothing to say "the end" of (see [ocptComputeDayConvocations]'s own doc comment).
  final int? endMinute;

  /// The earliest start over this slot's own **shooting** blocks — `shot`, `hold`, `audition` and
  /// `rehearsal`, `OcptShootingBlockKind.isShootingTime`'s own answer (ADR 0018) — or null when it
  /// carries none of them. Null exactly when [shootingEndMinute] is: both are built from the same
  /// walk over the same blocks.
  final int? shootingStartMinute;

  /// The latest end over the same blocks, or null under the same condition as [shootingStartMinute].
  final int? shootingEndMinute;

  /// Every person linked to this slot as a human: its crew rows' own people, plus the actors of its
  /// cast roles that are cast — resolving a role's actor is the caller's job, this file knowing
  /// nothing of `roles.personId`.
  final Set<String> personIds;

  /// The cast roles of this slot nobody is cast in yet — each its own convocation, named by the
  /// role rather than by nobody.
  final Set<String> uncastRoleIds;

  /// The address-book guests attending this slot — the first half of `shooting_slot_guests`' own
  /// discriminator, resolving a guest's own `personId` being the caller's job, this file knowing
  /// nothing of that table.
  final Set<String> guestPersonIds;

  /// The free-named guests attending this slot — the discriminator's other half, each entry the
  /// guest's own verbatim `freeName`.
  final Set<String> guestFreeNames;
}

/// One **audition block** of a day, already resolved by the caller into what
/// [ocptComputeDayConvocations] needs of it: when it runs, whose hour it is, and which slot it sits
/// in.
///
/// The one convocation in this app read off a block rather than off a slot (ADR 0024), and ADR 0018
/// applied rather than bent: a candidate is expected at twenty past ten, for twenty minutes, which
/// is exactly what this block is — so this, and not the unit's whole day, is what their arrival,
/// their PAT band and their departure are read off.
class OcptConvocationAudition {
  /// Builds an audition to feed to [ocptComputeDayConvocations].
  const OcptConvocationAudition({
    required this.slotId,
    required this.startMinute,
    required this.endMinute,
    required this.roleCandidateIds,
  });

  /// The id of the slot this audition sits in — what [OcptDayConvocation.slotIds] echoes back for a
  /// candidate, so a named call sheet can narrow the timetable to the unit they are expected on
  /// exactly as it does for everybody else.
  final String slotId;

  /// The audition's own resolved start (`OcptShootingTimelineEntry.startMinute`), never a stored
  /// column.
  final int startMinute;

  /// The audition's own resolved end (`OcptShootingTimelineEntry.endMinute`).
  final int endMinute;

  /// The candidacies this audition sees (`shooting_block_candidates.roleCandidateId`) — somebody
  /// seen **for a part**, which is why the id is a candidacy's and not a person's: two candidacies
  /// of one person on one day are two convocations, each about a different twenty minutes. Several
  /// on one audition is ordinary — two actors of two different parts read together — and an
  /// audition naming none convokes nobody. Resolving one to a name and a part is the caller's job,
  /// this file knowing nothing of `role_candidates`.
  final Set<String> roleCandidateIds;
}

/// One person's, one uncast role's, one guest's or one candidate's whole call for a day, joined
/// across everything they are linked to (ADR 0018) — every slot for the first three, every audition
/// block for a candidate (ADR 0024) — the app's one answer to "when does this human arrive, when are
/// they ready to shoot, and when are they done" (a guest excepted from the middle question, see
/// [patStartMinute]).
///
/// **Exactly one of [personId]/[roleId]/[guestPersonId]/[guestFreeName]/[roleCandidateId] is
/// non-null**, the same discriminator `breakdown_tags` uses (ADR 0014): a cast role with nobody cast
/// in it is still a convocation the production has to honour, named by the role rather than by
/// nobody; a guest is named by the address book or by a free name exactly as `shooting_slot_guests`
/// itself discriminates one; and a candidate is named by their **candidacy**, which is what says
/// which part they are coming to be seen for.
class OcptDayConvocation {
  /// Builds a computed day convocation.
  const OcptDayConvocation({
    required this.personId,
    required this.roleId,
    required this.guestPersonId,
    required this.guestFreeName,
    required this.roleCandidateId,
    required this.arrivalMinute,
    required this.patStartMinute,
    required this.patEndMinute,
    required this.departureMinute,
    required this.slotIds,
  });

  /// The person this convocation is for (crew or cast), or null when another of the four fields
  /// names it instead.
  final String? personId;

  /// The uncast role this convocation is for, or null when another of the five fields names it
  /// instead.
  final String? roleId;

  /// The address-book guest this convocation is for, or null when another of the five fields names
  /// it instead.
  final String? guestPersonId;

  /// The free-named guest this convocation is for, or null when another of the five fields names it
  /// instead.
  final String? guestFreeName;

  /// The candidacy this convocation is for — somebody seen for a part — or null when another of the
  /// five fields names it instead.
  final String? roleCandidateId;

  /// Whether this convocation is a guest's — either half of the discriminator, [guestPersonId] or
  /// [guestFreeName].
  bool get isGuest => guestPersonId != null || guestFreeName != null;

  /// The key this convocation is picked by when named call sheets are asked for one recipient at a
  /// time — its own [personId], [roleId] or [roleCandidateId], the three arms of the discriminator a
  /// named sheet is ever addressed to, and stable across the days of one export (somebody convoked
  /// on three days is one recipient, ticked once).
  ///
  /// **Null for a guest** ([isGuest]), who is never a named sheet's recipient: they are on the day
  /// and owed an hour, and the sheet an assistant director reads down is not addressed to them — the
  /// same reason the trailing guest table exists rather than a guest row in the crew list. A caller
  /// building that recipient list therefore filters on this being non-null and needs no second rule
  /// of its own.
  String? get selectionKey => personId ?? roleId ?? roleCandidateId;

  /// Whether this convocation is a candidate's — [roleCandidateId] being the arm of the
  /// discriminator that says so.
  ///
  /// Unlike [isGuest], this changes **nothing** about the shape of the figures below: a candidate
  /// arrives, is ready to be seen and leaves exactly as everybody else does. What differs is only
  /// where they are read from — the audition blocks naming this candidacy rather than the slots a
  /// person is linked to (ADR 0024) — which is what gives them an hour of their own inside a unit
  /// seeing eleven other people the same day. It otherwise only ever says which group of the
  /// convocations panel the card belongs in.
  bool get isCandidate => roleCandidateId != null;

  /// The earliest minute this person or role is expected — the minimum
  /// [OcptConvocationSlot.startMinute] over every slot they are linked to.
  final int arrivalMinute;

  /// The start of this person's or role's *prêt à tourner* band — the minimum non-null
  /// [OcptConvocationSlot.shootingStartMinute] over every slot they are linked to, or null when none
  /// of those slots carries a shooting block at all: someone convoked only on preparation slots is
  /// there, not waiting to shoot, which is a different fact from having no band computed yet.
  /// **Always null for a guest** ([isGuest]), whatever shooting blocks the slots they are linked to
  /// carry: a guest does not shoot, and a band would say they were waiting to. Null exactly when
  /// [patEndMinute] is.
  final int? patStartMinute;

  /// The end of the band — the maximum non-null [OcptConvocationSlot.shootingEndMinute] over the
  /// same slots — under the same condition as [patStartMinute]. The band is **not** clipped to one
  /// slot: someone on a morning slot and an evening slot reads one band spanning both, gaps
  /// included.
  final int? patEndMinute;

  /// The latest minute this person or role is done — the maximum, over every slot they are linked
  /// to, of that slot's own [OcptConvocationSlot.endMinute] when it has one, or its own
  /// [OcptConvocationSlot.startMinute] otherwise: a slot carrying no block at all yet still ends the
  /// instant it begins, for someone linked to nothing more than that.
  final int departureMinute;

  /// The ids of every slot this person, role or candidacy is expected on, in the order
  /// [ocptComputeDayConvocations] was given [OcptConvocationSlot]s — or, for a candidate, the slots
  /// their own auditions sit in, deduplicated, in the order it was given
  /// [OcptConvocationAudition]s.
  final List<String> slotIds;
}

/// Computes every convocation of a day from its [slots] — the rule recorded as ADR 0018, implemented
/// exactly once, here.
///
/// **Nothing is offset from anything, and nobody types a call time, a wrap time or a PAT band.** A
/// person (or an uncast role, or a guest) is convoked by being
/// linked to one or more of [slots] (`OcptConvocationSlot.personIds`/`.uncastRoleIds`/
/// `.guestPersonIds`/`.guestFreeNames`), and every
/// clock this function returns for them is read off the slots they are linked to — `S`, the subset
/// of [slots] listing them — and nothing else:
///
/// - [OcptDayConvocation.arrivalMinute] is the minimum `startMinute` over `S`.
/// - [OcptDayConvocation.patStartMinute]/[OcptDayConvocation.patEndMinute] are the minimum non-null
///   `shootingStartMinute` and the maximum non-null `shootingEndMinute` over `S`, both null together
///   when no slot of `S` carries a shooting block at all (built from the same walk, so there is
///   nothing to assert about the two agreeing) — **and always both null for a guest**, whatever `S`
///   carries: a guest is never handed a shooting block to be measured against, which is what keeps
///   [OcptDayConvocation.isGuest] from ever reading a band (see that field's own doc comment).
/// - [OcptDayConvocation.departureMinute] is the maximum, over `S`, of `endMinute ?? startMinute` —
///   a slot with no block at all yet still ends at its own start, for whoever is linked to only
///   that.
/// - [OcptDayConvocation.slotIds] is the ids of `S`, in the order [slots] was given.
///
/// **A candidate is read off [auditions] instead, and off nothing else** (ADR 0024): the same three
/// figures, from the audition blocks naming their candidacy — `A`, the subset of [auditions] listing
/// it. `arrivalMinute` is the minimum `startMinute` over `A`, the PAT band is that same minimum and
/// the maximum `endMinute` over `A` (an audition **is** shooting time, so a candidate always reads a
/// band), `departureMinute` is that same maximum, and `slotIds` is the slots those auditions sit in,
/// deduplicated. That is what gives each candidate an hour of their own: four people seen twenty
/// minutes each inside one slot read four different bands, where a slot-wide link could only ever
/// have said "09:00 – 18:00" four times over. A candidacy named on two auditions of one day reads
/// **one** convocation spanning both, gaps included, exactly as a person on two slots does.
///
/// The result is one [OcptDayConvocation] per person, per uncast role and per guest (address-book or
/// free-named) named anywhere in [slots], plus one per candidacy named anywhere in [auditions],
/// sorted by
/// [OcptDayConvocation.arrivalMinute], ties broken by [OcptDayConvocation.personId] `??`
/// [OcptDayConvocation.roleId] `??` [OcptDayConvocation.guestPersonId] `??`
/// [OcptDayConvocation.guestFreeName] `??` [OcptDayConvocation.roleCandidateId] — deterministic, but
/// not "arrival then **name**": nothing here knows a person's, a role's or a guest's own display
/// name, so a caller wanting that ordering re-sorts on top of this one. A free-named guest is
/// grouped by that name **verbatim**: nothing here normalises it, since nothing in this app says two
/// spellings name the same visitor, and assuming so would silently merge two different guests.
///
/// **A person convoked as crew or cast and attending the same day as a guest reads as two separate
/// convocations, deliberately**: a guest link says nothing about work, and folding the two into one
/// would put a PAT band on somebody's visit, or lose the guest's own reason and notes under a crew
/// row that has no room for them.
///
/// Minutes are offsets from the day's own midnight and **may exceed 1440** for a night shoot's small
/// hours — nothing here ever takes anything modulo anything. Nothing here throws, either: there is
/// no typed figure left to refuse, a lead time being gone along with the group it used to belong to
/// (ADR 0018).
List<OcptDayConvocation> ocptComputeDayConvocations({
  required List<OcptConvocationSlot> slots,
  List<OcptConvocationAudition> auditions = const [],
}) {
  final slotsByPersonId = <String, List<OcptConvocationSlot>>{};
  final slotsByRoleId = <String, List<OcptConvocationSlot>>{};
  final slotsByGuestPersonId = <String, List<OcptConvocationSlot>>{};
  final slotsByGuestFreeName = <String, List<OcptConvocationSlot>>{};
  final auditionsByRoleCandidateId = <String, List<OcptConvocationAudition>>{};

  for (final slot in slots) {
    for (final personId in slot.personIds) {
      (slotsByPersonId[personId] ??= <OcptConvocationSlot>[]).add(slot);
    }
    for (final roleId in slot.uncastRoleIds) {
      (slotsByRoleId[roleId] ??= <OcptConvocationSlot>[]).add(slot);
    }
    for (final guestPersonId in slot.guestPersonIds) {
      (slotsByGuestPersonId[guestPersonId] ??= <OcptConvocationSlot>[]).add(slot);
    }
    for (final guestFreeName in slot.guestFreeNames) {
      (slotsByGuestFreeName[guestFreeName] ??= <OcptConvocationSlot>[]).add(slot);
    }
  }

  for (final audition in auditions) {
    for (final roleCandidateId in audition.roleCandidateIds) {
      (auditionsByRoleCandidateId[roleCandidateId] ??= <OcptConvocationAudition>[]).add(audition);
    }
  }

  final convocations = <OcptDayConvocation>[
    for (final entry in slotsByPersonId.entries) _convocationOf(personId: entry.key, ownSlots: entry.value),
    for (final entry in slotsByRoleId.entries) _convocationOf(roleId: entry.key, ownSlots: entry.value),
    for (final entry in slotsByGuestPersonId.entries)
      _convocationOf(guestPersonId: entry.key, ownSlots: entry.value),
    for (final entry in slotsByGuestFreeName.entries)
      _convocationOf(guestFreeName: entry.key, ownSlots: entry.value),
    for (final entry in auditionsByRoleCandidateId.entries)
      _candidateConvocationOf(roleCandidateId: entry.key, ownAuditions: entry.value),
  ];

  convocations.sort((left, right) {
    final byArrival = left.arrivalMinute.compareTo(right.arrivalMinute);
    if (byArrival != 0) {
      return byArrival;
    }
    return (left.personId ??
            left.roleId ??
            left.guestPersonId ??
            left.guestFreeName ??
            left.roleCandidateId ??
            "")
        .compareTo(
          right.personId ??
              right.roleId ??
              right.guestPersonId ??
              right.guestFreeName ??
              right.roleCandidateId ??
              "",
        );
  });

  return convocations;
}

/// Builds the [OcptDayConvocation] of [personId] (or [roleId], or [guestPersonId], or
/// [guestFreeName] — exactly one of the four is ever passed) over the slots naming them, [ownSlots]
/// — see [ocptComputeDayConvocations]'s own doc comment for what each figure is read from. A
/// candidate has [_candidateConvocationOf] instead, reading auditions rather than slots.
///
/// `isGuest` (computed locally, true exactly when [guestPersonId]/[guestFreeName] is the one passed)
/// is what keeps [OcptDayConvocation.patStartMinute]/[OcptDayConvocation.patEndMinute] null whatever
/// [ownSlots] carries: a guest does not shoot, so their band is never computed at all rather than
/// computed and discarded.
OcptDayConvocation _convocationOf({
  String? personId,
  String? roleId,
  String? guestPersonId,
  String? guestFreeName,
  required List<OcptConvocationSlot> ownSlots,
}) {
  final isGuest = guestPersonId != null || guestFreeName != null;

  int? arrivalMinute;
  int? patStartMinute;
  int? patEndMinute;
  int? departureMinute;
  final slotIds = <String>[];

  for (final slot in ownSlots) {
    slotIds.add(slot.id);

    if (arrivalMinute == null || slot.startMinute < arrivalMinute) {
      arrivalMinute = slot.startMinute;
    }

    if (!isGuest) {
      final shootingStart = slot.shootingStartMinute;
      if (shootingStart != null && (patStartMinute == null || shootingStart < patStartMinute)) {
        patStartMinute = shootingStart;
      }
      final shootingEnd = slot.shootingEndMinute;
      if (shootingEnd != null && (patEndMinute == null || shootingEnd > patEndMinute)) {
        patEndMinute = shootingEnd;
      }
    }

    final ownDeparture = slot.endMinute ?? slot.startMinute;
    if (departureMinute == null || ownDeparture > departureMinute) {
      departureMinute = ownDeparture;
    }
  }

  return OcptDayConvocation(
    personId: personId,
    roleId: roleId,
    guestPersonId: guestPersonId,
    guestFreeName: guestFreeName,
    roleCandidateId: null,
    arrivalMinute: arrivalMinute!,
    patStartMinute: patStartMinute,
    patEndMinute: patEndMinute,
    departureMinute: departureMinute!,
    slotIds: slotIds,
  );
}

/// Builds the [OcptDayConvocation] of candidacy [roleCandidateId] over the audition blocks naming
/// it, [ownAuditions] — see [ocptComputeDayConvocations]'s own doc comment for what each figure is
/// read from.
///
/// [_convocationOf]'s sibling rather than a branch inside it, because a candidate is convoked by
/// something else entirely (ADR 0024): an audition is one span rather than a window with a shooting
/// stretch somewhere inside it, so the band **is** the span — an audition is shooting time by
/// definition, and there is no "linked to a slot that carries no shooting block" state for a
/// candidate to be in.
///
/// [OcptDayConvocation.slotIds] is deduplicated: two auditions of one slot are still one unit to
/// turn up on, and a named call sheet narrowing the timetable to those ids would otherwise pass the
/// same slot twice.
OcptDayConvocation _candidateConvocationOf({
  required String roleCandidateId,
  required List<OcptConvocationAudition> ownAuditions,
}) {
  int? startMinute;
  int? endMinute;
  final slotIds = <String>[];

  for (final audition in ownAuditions) {
    if (!slotIds.contains(audition.slotId)) {
      slotIds.add(audition.slotId);
    }

    if (startMinute == null || audition.startMinute < startMinute) {
      startMinute = audition.startMinute;
    }
    if (endMinute == null || audition.endMinute > endMinute) {
      endMinute = audition.endMinute;
    }
  }

  return OcptDayConvocation(
    personId: null,
    roleId: null,
    guestPersonId: null,
    guestFreeName: null,
    roleCandidateId: roleCandidateId,
    arrivalMinute: startMinute!,
    patStartMinute: startMinute,
    patEndMinute: endMinute,
    departureMinute: endMinute!,
    slotIds: slotIds,
  );
}
