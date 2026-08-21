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
    required this.hasFilmingBlock,
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

  /// Whether any of the blocks the two figures above were read off is **filming**
  /// (`OcptShootingBlockKind.isFilming` — a `shot` or a `hold`), rather than an audition or a
  /// rehearsal.
  ///
  /// This is the whole of what says whether a band drawn over this slot may be called a PAT
  /// (*prêt à tourner*) band: that word is the hour a performer must be ready for a take, and a slot
  /// whose work is auditions alone has no take to be ready for. False whenever
  /// [shootingStartMinute] is null, there being no band to name at all.
  final bool hasFilmingBlock;

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
    required this.candidacies,
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

  /// The candidacies this audition sees, each already resolved to the person behind it. Several on
  /// one audition is ordinary — two actors of two different parts read together — and an audition
  /// naming none convokes nobody. Resolving a candidacy to a name and a part is the caller's job,
  /// this file knowing nothing of `role_candidates` beyond the two ids
  /// [OcptConvocationCandidacy] carries.
  final List<OcptConvocationCandidacy> candidacies;
}

/// One candidacy an audition sees: **who**, and which candidacy of theirs.
///
/// Both ids, because both are needed and neither can stand for the other. [personId] is what the
/// day's call is joined on — a person arrives once and leaves once, whatever brings them in
/// ([ocptComputeDayConvocations]) — while [roleCandidateId] is what says *which part* they are being
/// seen for, which two candidacies of one person differ by and a name alone could never tell apart.
class OcptConvocationCandidacy {
  /// Builds a candidacy to hang off an [OcptConvocationAudition].
  const OcptConvocationCandidacy({required this.roleCandidateId, required this.personId});

  /// The `role_candidates` row being seen — somebody, for a part.
  final String roleCandidateId;

  /// The person behind that candidacy (`role_candidates.personId`), resolved by the caller.
  final String personId;
}

/// One person's, one uncast role's, one guest's or one candidate's whole call for a day, joined
/// across everything they are linked to (ADR 0018) — every slot for the first three, every audition
/// block for a candidate (ADR 0024) — the app's one answer to "when does this human arrive, when are
/// they ready to shoot, and when are they done" (a guest excepted from the middle question, see
/// [patStartMinute]).
///
/// **Exactly one of [personId]/[roleId]/[guestPersonId]/[guestFreeName] is non-null**, the same
/// discriminator `breakdown_tags` uses (ADR 0014): a cast role with nobody cast in it is still a
/// convocation the production has to honour, named by the role rather than by nobody, and a guest is
/// named by the address book or by a free name exactly as `shooting_slot_guests` itself
/// discriminates one.
///
/// **A candidate is not a fifth arm, and deliberately.** Somebody seen for a part is a *person*, and
/// a person arrives once and leaves once whatever brings them in: crewing the day, playing a part
/// and being seen for another are three reasons and one call. So the candidacies the day sees of
/// them ride along on their own convocation, in [roleCandidateIds], rather than making a second
/// convocation of their own — which is what stopped anybody receiving two call sheets for one
/// day.
class OcptDayConvocation {
  /// Builds a computed day convocation.
  const OcptDayConvocation({
    required this.personId,
    required this.roleId,
    required this.guestPersonId,
    required this.guestFreeName,
    required this.roleCandidateIds,
    required this.hasSlotConvocation,
    required this.arrivalMinute,
    required this.patStartMinute,
    required this.patEndMinute,
    required this.isPatBand,
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

  /// The candidacies of this person the day sees, empty for everybody the day sees for no part at
  /// all — which is everybody but a candidate, [personId] being the only arm this is ever non-empty
  /// beside.
  ///
  /// **A set rather than one id**: a person read for two parts on one day is seen twice and called
  /// once. What differs between the two is the part, which is why the directories that answer "who
  /// is expected for what" print one row per entry here while the sheet addressed to them stays a
  /// single sheet.
  final Set<String> roleCandidateIds;

  /// Whether any slot names this convocation as **crew or cast** — as opposed to a day that only
  /// sees them for a part.
  ///
  /// The one thing that tells "the second camera assistant, who is also being seen for Marie at
  /// eleven" from "Marie's candidate": both carry candidacies, and only the second belongs in the
  /// convocations panel's own candidates group. Always true for an uncast role and for a guest,
  /// neither of which is ever seen for a part.
  final bool hasSlotConvocation;

  /// Whether this convocation is a guest's — either half of the discriminator, [guestPersonId] or
  /// [guestFreeName].
  bool get isGuest => guestPersonId != null || guestFreeName != null;

  /// The key this convocation is picked by when named call sheets are asked for one recipient at a
  /// time — its own [personId] or [roleId], the two arms of the discriminator a named sheet is ever
  /// addressed to, and stable across the days of one export (somebody convoked on three days is one
  /// recipient, ticked once).
  ///
  /// **A person is one recipient, whatever they do that day.** A sheet is addressed to somebody, not
  /// to one of their reasons for being there: a person crewing the day and seen for a part receives
  /// the one sheet carrying both, which is what [roleCandidateIds] riding on this convocation is
  /// for.
  ///
  /// **Null for a guest** ([isGuest]), who is never a named sheet's recipient: they are on the day
  /// and owed an hour, and the sheet an assistant director reads down is not addressed to them — the
  /// same reason the trailing guest table exists rather than a guest row in the crew list. A caller
  /// building that recipient list therefore filters on this being non-null and needs no second rule
  /// of its own.
  String? get selectionKey => personId ?? roleId;

  /// Whether the day sees this person for a part at all — one candidacy is enough.
  ///
  /// What the directories that answer "who is expected for what" read: the printed candidates list
  /// and the audition table both go through it, and both print one entry per candidacy rather than
  /// one per person.
  bool get isSeenForAPart => roleCandidateIds.isNotEmpty;

  /// Whether being seen for a part is the **only** reason the day has for this person.
  ///
  /// What the convocations panel's own candidates group holds: somebody crewing the day and seen for
  /// Marie at eleven belongs among the crew, with one band covering both, and only somebody the day
  /// has nothing else for belongs under `Candidates`. Unlike [isGuest], neither this nor
  /// [isSeenForAPart] changes anything about the figures below — a candidate arrives, is ready and
  /// leaves exactly as everybody else does, off the audition blocks naming them (ADR 0024) joined
  /// with whatever else the day asks of them.
  bool get isOnlySeenForAPart => isSeenForAPart && !hasSlotConvocation;

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

  /// Whether the band above is a **PAT** (*prêt à tourner*) band, or merely a presence one: true
  /// when any block it was read off is filming ([OcptConvocationSlot.hasFilmingBlock]), false when
  /// the work it covers is auditions and rehearsals alone.
  ///
  /// **The label follows the band, never the day.** A day that auditions in the morning and shoots
  /// in the afternoon owes its cast a `PAT` and its candidates a `PRÉSENCE`, on the one sheet: the
  /// actor is due ready for a take and the candidate is due to be seen, and one word cannot be both.
  /// Always false for a guest and for a convocation with no band at all, neither having anything to
  /// name.
  final bool isPatBand;

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
/// - [OcptDayConvocation.isPatBand] is true when any slot of `S` carries a filming block
///   (`OcptConvocationSlot.hasFilmingBlock`), which is what says whether that band may be called
///   *prêt à tourner* at all.
/// - [OcptDayConvocation.departureMinute] is the maximum, over `S`, of `endMinute ?? startMinute` —
///   a slot with no block at all yet still ends at its own start, for whoever is linked to only
///   that.
/// - [OcptDayConvocation.slotIds] is the ids of `S`, in the order [slots] was given, followed by the
///   slots this person's own auditions sit in — deduplicated, so a unit reached both ways is named
///   once.
///
/// **A person's [auditions] join the same walk** (ADR 0024): `A`, the subset of [auditions] whose
/// candidacies name them, widens all four figures rather than making a convocation of its own. An
/// audition is one span rather than a window with work somewhere inside it, so it opens and closes
/// the band where it opens and closes itself; it never makes that band a PAT one, filming nothing.
/// That is what gives each candidate an hour of their own — four people seen twenty minutes each
/// inside one slot read four different bands, where a slot-wide link could only ever have said
/// "09:00 – 18:00" four times over — and what gives a person who crews the day **and** is seen for a
/// part a single call, arriving at the earlier of the two and leaving at the later. Somebody the day
/// only sees for a part has an empty `S`, and reads their first audition as their arrival.
///
/// The result is one [OcptDayConvocation] per person the day asks anything of at all, per uncast
/// role and per guest (address-book or free-named), sorted by
/// [OcptDayConvocation.arrivalMinute], ties broken by [OcptDayConvocation.personId] `??`
/// [OcptDayConvocation.roleId] `??` [OcptDayConvocation.guestPersonId] `??`
/// [OcptDayConvocation.guestFreeName] — deterministic, but
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
  final auditionsByPersonId = <String, List<OcptConvocationAudition>>{};
  final roleCandidateIdsByPersonId = <String, Set<String>>{};

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
    for (final candidacy in audition.candidacies) {
      final ownAuditions = auditionsByPersonId[candidacy.personId] ??= <OcptConvocationAudition>[];
      // One audition naming somebody twice — two candidacies of theirs read together — is still one
      // stretch of their day, and must not be counted as two.
      if (!ownAuditions.contains(audition)) {
        ownAuditions.add(audition);
      }
      (roleCandidateIdsByPersonId[candidacy.personId] ??= <String>{})
          .add(candidacy.roleCandidateId);
    }
  }

  // Every person the day asks anything of, in the order the slots named them and then the auditions
  // did: somebody crewing the morning and seen for a part in the afternoon appears once.
  final personIds = <String>{...slotsByPersonId.keys, ...auditionsByPersonId.keys};

  final convocations = <OcptDayConvocation>[
    for (final personId in personIds)
      _convocationOf(
        personId: personId,
        ownSlots: slotsByPersonId[personId] ?? const [],
        ownAuditions: auditionsByPersonId[personId] ?? const [],
        roleCandidateIds: roleCandidateIdsByPersonId[personId] ?? const {},
      ),
    for (final entry in slotsByRoleId.entries) _convocationOf(roleId: entry.key, ownSlots: entry.value),
    for (final entry in slotsByGuestPersonId.entries)
      _convocationOf(guestPersonId: entry.key, ownSlots: entry.value),
    for (final entry in slotsByGuestFreeName.entries)
      _convocationOf(guestFreeName: entry.key, ownSlots: entry.value),
  ];

  convocations.sort((left, right) {
    final byArrival = left.arrivalMinute.compareTo(right.arrivalMinute);
    if (byArrival != 0) {
      return byArrival;
    }
    return (left.personId ?? left.roleId ?? left.guestPersonId ?? left.guestFreeName ?? "").compareTo(
      right.personId ?? right.roleId ?? right.guestPersonId ?? right.guestFreeName ?? "",
    );
  });

  return convocations;
}

/// Builds the [OcptDayConvocation] of [personId] (or [roleId], or [guestPersonId], or
/// [guestFreeName] — exactly one of the four is ever passed) over everything the day asks of them:
/// the slots naming them, [ownSlots], and — for a person alone — the audition blocks seeing them,
/// [ownAuditions], whose candidacies are [roleCandidateIds]. See [ocptComputeDayConvocations]'s own
/// doc comment for what each figure is read from.
///
/// **The two sources are joined, never kept apart** (ADR 0018, as ADR 0024 extends it): a person
/// crewing from 08:00 and seen for a part at 10:00 arrives once, at 08:00. A person the day only
/// sees for a part arrives at their first audition, which is exactly what an empty [ownSlots]
/// leaves.
///
/// `isGuest` (computed locally, true exactly when [guestPersonId]/[guestFreeName] is the one passed)
/// is what keeps [OcptDayConvocation.patStartMinute]/[OcptDayConvocation.patEndMinute] null whatever
/// [ownSlots] carries: a guest does not shoot, so their band is never computed at all rather than
/// computed and discarded. A guest is never handed auditions either — nothing names one.
OcptDayConvocation _convocationOf({
  String? personId,
  String? roleId,
  String? guestPersonId,
  String? guestFreeName,
  required List<OcptConvocationSlot> ownSlots,
  List<OcptConvocationAudition> ownAuditions = const [],
  Set<String> roleCandidateIds = const {},
}) {
  final isGuest = guestPersonId != null || guestFreeName != null;

  int? arrivalMinute;
  int? patStartMinute;
  int? patEndMinute;
  var isPatBand = false;
  int? departureMinute;
  final slotIds = <String>[];

  void reachSlot(String id) {
    if (!slotIds.contains(id)) {
      slotIds.add(id);
    }
  }

  for (final slot in ownSlots) {
    reachSlot(slot.id);

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
      isPatBand = isPatBand || slot.hasFilmingBlock;
    }

    final ownDeparture = slot.endMinute ?? slot.startMinute;
    if (departureMinute == null || ownDeparture > departureMinute) {
      departureMinute = ownDeparture;
    }
  }

  // An audition is one span rather than a window with a stretch of work somewhere inside it, so it
  // opens the band where it opens itself. It never makes the band a PAT one: an audition films
  // nothing (see [OcptDayConvocation.isPatBand]).
  for (final audition in ownAuditions) {
    reachSlot(audition.slotId);

    if (arrivalMinute == null || audition.startMinute < arrivalMinute) {
      arrivalMinute = audition.startMinute;
    }
    if (patStartMinute == null || audition.startMinute < patStartMinute) {
      patStartMinute = audition.startMinute;
    }
    if (patEndMinute == null || audition.endMinute > patEndMinute) {
      patEndMinute = audition.endMinute;
    }
    if (departureMinute == null || audition.endMinute > departureMinute) {
      departureMinute = audition.endMinute;
    }
  }

  return OcptDayConvocation(
    personId: personId,
    roleId: roleId,
    guestPersonId: guestPersonId,
    guestFreeName: guestFreeName,
    roleCandidateIds: roleCandidateIds,
    hasSlotConvocation: ownSlots.isNotEmpty,
    arrivalMinute: arrivalMinute!,
    patStartMinute: patStartMinute,
    patEndMinute: patEndMinute,
    isPatBand: isPatBand,
    departureMinute: departureMinute!,
    slotIds: slotIds,
  );
}
