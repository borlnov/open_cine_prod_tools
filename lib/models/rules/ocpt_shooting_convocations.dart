// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0
import 'package:open_cine_prod_tools/models/rules/ocpt_convocation_audition.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_convocation_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';

/// Compute every convocation of a day from its [slots] — the rule recorded as ADR 0018,
/// implemented exactly once, here.
///
/// **Nothing is offset from anything, and nobody types a call time, a wrap time or a PAT band.** A
/// person (or an uncast role, or a guest) is convoked by being
/// linked to one or more of [slots] (`OcptConvocationSlot.personIds`/`.uncastRoleIds`/
/// `.guestPersonIds`/`.guestFreeNames`), and every
/// clock this function returns for them is read off the slots they are linked to — `S`, the subset
/// of [slots] listing them — and nothing else:
///
/// - [OcptDayConvocation.arrivalMinute] is the minimum `startMinute` over `S`.
/// - [OcptDayConvocation.isPatBand] is true when any slot of `S` carries a filming block
///   (`OcptConvocationSlot.filmingStartMinute` is set), which is what says whether the band may be
///   called *prêt à tourner* at all.
/// - [OcptDayConvocation.patStartMinute]/[OcptDayConvocation.patEndMinute] are then the minimum
///   non-null `filmingStartMinute` and the maximum non-null `filmingEndMinute` over `S`: the
///   filming blocks alone, so neither an audition nor a rehearsal ever stretches a PAT band. When
///   no slot of `S` films, they are the minimum non-null `shootingStartMinute` and the maximum
///   non-null `shootingEndMinute` instead — a presence band — both null together when no slot of
///   `S` carries a shooting block at all — **and always both null for a guest**, whatever `S`
///   carries: a guest is never handed a shooting block to be measured against, which is what keeps
///   [OcptDayConvocation.isGuest] from ever reading a band (see that field's own doc comment).
/// - [OcptDayConvocation.departureMinute] is the maximum, over `S`, of `endMinute ?? startMinute` —
///   a slot with no block at all yet still ends at its own start, for whoever is linked to only
///   that.
/// - [OcptDayConvocation.slotIds] is the ids of `S`, in the order [slots] was given, followed by
///   the slots this person's own auditions sit in — deduplicated, so a unit reached both ways is
///   named once.
///
/// **A person's [auditions] join the same walk** (ADR 0024): `A`, the subset of [auditions] whose
/// candidacies name them, widens their arrival and departure rather than making a convocation of
/// its own, and widens their band too while it is a presence one. An audition is one span rather
/// than a window with work somewhere inside it, so it opens and closes a presence band where it
/// opens and closes itself; it never makes that band a PAT one, filming nothing, and never
/// stretches one that already is. That is what gives each candidate an hour of their own — four
/// people seen twenty minutes each inside one slot read four different bands, where a slot-wide
/// link could only ever have said "09:00 – 18:00" four times over — and what gives a person who
/// crews the day **and** is seen for a part a single call, arriving at the earlier of the two and
/// leaving at the later. Somebody the day only sees for a part has an empty `S`, and reads their
/// first audition as their arrival.
///
/// The result is one [OcptDayConvocation] per person the day asks anything of at all, per uncast
/// role and per guest (address-book or free-named), sorted by [OcptDayConvocation.arrivalMinute],
/// ties broken by [OcptDayConvocation.personId] `??` [OcptDayConvocation.roleId] `??`
/// [OcptDayConvocation.guestPersonId] `??` [OcptDayConvocation.guestFreeName] — deterministic, but
/// not "arrival then **name**": nothing here knows a person's, a role's or a guest's own display
/// name, so a caller wanting that ordering re-sorts on top of this one. A free-named guest is
/// grouped by that name **verbatim**: nothing here normalises it, since nothing in this app says
/// two spellings name the same visitor, and assuming so would silently merge two different guests.
///
/// **A person convoked as crew or cast and attending the same day as a guest reads as two separate
/// convocations, deliberately**: a guest link says nothing about work, and folding the two into one
/// would put a PAT band on somebody's visit, or lose the guest's own reason and notes under a crew
/// row that has no room for them.
///
/// Minutes are offsets from the day's own midnight and **may exceed 1440** for a night shoot's
/// small hours — nothing here ever takes anything modulo anything. Nothing here throws, either:
/// there is no typed figure left to refuse, a lead time being gone along with the group it used to
/// belong to (ADR 0018).
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
      (roleCandidateIdsByPersonId[candidacy.personId] ??= <String>{}).add(
        candidacy.roleCandidateId,
      );
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
    for (final entry in slotsByRoleId.entries)
      _convocationOf(roleId: entry.key, ownSlots: entry.value),
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
    return (left.personId ?? left.roleId ?? left.guestPersonId ?? left.guestFreeName ?? "")
        .compareTo(
          right.personId ?? right.roleId ?? right.guestPersonId ?? right.guestFreeName ?? "",
        );
  });

  return convocations;
}

/// Build the [OcptDayConvocation] of [personId] (or [roleId], or [guestPersonId], or
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
/// `isGuest` (computed locally, true exactly when [guestPersonId]/[guestFreeName] is the one
/// passed) is what keeps [OcptDayConvocation.patStartMinute]/[OcptDayConvocation.patEndMinute] null
/// whatever [ownSlots] carries: a guest does not shoot, so their band is never computed at all
/// rather than computed and discarded. A guest is never handed auditions either — nothing names
/// one.
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
  int? presenceStartMinute;
  int? presenceEndMinute;
  int? filmingStartMinute;
  int? filmingEndMinute;
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
      if (shootingStart != null &&
          (presenceStartMinute == null || shootingStart < presenceStartMinute)) {
        presenceStartMinute = shootingStart;
      }
      final shootingEnd = slot.shootingEndMinute;
      if (shootingEnd != null && (presenceEndMinute == null || shootingEnd > presenceEndMinute)) {
        presenceEndMinute = shootingEnd;
      }
      final filmingStart = slot.filmingStartMinute;
      if (filmingStart != null &&
          (filmingStartMinute == null || filmingStart < filmingStartMinute)) {
        filmingStartMinute = filmingStart;
      }
      final filmingEnd = slot.filmingEndMinute;
      if (filmingEnd != null && (filmingEndMinute == null || filmingEnd > filmingEndMinute)) {
        filmingEndMinute = filmingEnd;
      }
    }

    final ownDeparture = slot.endMinute ?? slot.startMinute;
    if (departureMinute == null || ownDeparture > departureMinute) {
      departureMinute = ownDeparture;
    }
  }

  // An audition is one span rather than a window with a stretch of work somewhere inside it, so it
  // opens a presence band where it opens itself. It never touches the filming figures: an audition
  // films nothing (see [OcptDayConvocation.isPatBand]).
  for (final audition in ownAuditions) {
    reachSlot(audition.slotId);

    if (arrivalMinute == null || audition.startMinute < arrivalMinute) {
      arrivalMinute = audition.startMinute;
    }
    if (presenceStartMinute == null || audition.startMinute < presenceStartMinute) {
      presenceStartMinute = audition.startMinute;
    }
    if (presenceEndMinute == null || audition.endMinute > presenceEndMinute) {
      presenceEndMinute = audition.endMinute;
    }
    if (departureMinute == null || audition.endMinute > departureMinute) {
      departureMinute = audition.endMinute;
    }
  }

  // Filming anywhere in the day makes the band a PAT one, read off the filming blocks alone; a day
  // of auditions and rehearsals only keeps its presence band.
  final isPatBand = filmingStartMinute != null;

  return OcptDayConvocation(
    personId: personId,
    roleId: roleId,
    guestPersonId: guestPersonId,
    guestFreeName: guestFreeName,
    roleCandidateIds: roleCandidateIds,
    hasSlotConvocation: ownSlots.isNotEmpty,
    arrivalMinute: arrivalMinute!,
    patStartMinute: isPatBand ? filmingStartMinute : presenceStartMinute,
    patEndMinute: isPatBand ? filmingEndMinute : presenceEndMinute,
    isPatBand: isPatBand,
    departureMinute: departureMinute!,
    slotIds: slotIds,
  );
}
