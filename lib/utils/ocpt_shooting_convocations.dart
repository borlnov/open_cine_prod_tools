// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One slot of a day, already resolved by the caller (`OcptScheduleState`, never this file, which
/// knows nothing of drift, of `shots`/`shot_characters`/`roles`, or of `ocpt_shooting_day_timeline
/// .dart`'s own types) into exactly what [ocptComputeDayConvocations] needs: who is linked to it,
/// and where its own chain of blocks starts, ends and shoots.
///
/// A person is convoked by being **linked to a slot** (ADR 0018) — there is no lead time, no group
/// and no per-block role resolution left in this file: whoever [personIds]/[uncastRoleIds] names is
/// convoked by this slot, for the whole of it, and every clock a convocation carries is read off
/// [startMinute]/[endMinute]/[shootingStartMinute]/[shootingEndMinute] alone.
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

  /// The earliest start over this slot's own `shot` and `hold` blocks — the two kinds that count as
  /// shooting time (ADR 0018) — or null when it has neither. Null exactly when [shootingEndMinute]
  /// is: both are built from the same walk over the same blocks.
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
}

/// One person's or one uncast role's whole call for a day, joined across every slot they are linked
/// to (ADR 0018) — the app's one answer to "when does this human arrive, when are they ready to
/// shoot, and when are they done".
///
/// Exactly one of [personId]/[roleId] is non-null, the same discriminator `breakdown_tags` uses
/// (ADR 0014): a cast role with nobody cast in it is still a convocation the production has to
/// honour, named by the role rather than by nobody.
class OcptDayConvocation {
  /// Builds a computed day convocation.
  const OcptDayConvocation({
    required this.personId,
    required this.roleId,
    required this.arrivalMinute,
    required this.patStartMinute,
    required this.patEndMinute,
    required this.departureMinute,
    required this.slotIds,
  });

  /// The person this convocation is for, or null when [roleId] names it instead.
  final String? personId;

  /// The uncast role this convocation is for, or null when [personId] names it instead.
  final String? roleId;

  /// The earliest minute this person or role is expected — the minimum
  /// [OcptConvocationSlot.startMinute] over every slot they are linked to.
  final int arrivalMinute;

  /// The start of this person's or role's *prêt à tourner* band — the minimum non-null
  /// [OcptConvocationSlot.shootingStartMinute] over every slot they are linked to, or null when none
  /// of those slots carries a shooting block at all: someone convoked only on preparation slots is
  /// there, not waiting to shoot, which is a different fact from having no band computed yet.
  /// Null exactly when [patEndMinute] is.
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

  /// The ids of every slot this person or role is linked to, in the order [ocptComputeDayConvocations]
  /// was given [OcptConvocationSlot]s.
  final List<String> slotIds;
}

/// Computes every convocation of a day from its [slots] — the rule recorded as ADR 0018, implemented
/// exactly once, here.
///
/// **Nothing is offset from anything, and nobody types a call time, a wrap time or a PAT band.** A
/// person (or an uncast role) is convoked by being linked to one or more of [slots]
/// (`OcptConvocationSlot.personIds`/`.uncastRoleIds`), and every clock this function returns for
/// them is read off the slots they are linked to — `S`, the subset of [slots] listing them — and
/// nothing else:
///
/// - [OcptDayConvocation.arrivalMinute] is the minimum `startMinute` over `S`.
/// - [OcptDayConvocation.patStartMinute]/[OcptDayConvocation.patEndMinute] are the minimum non-null
///   `shootingStartMinute` and the maximum non-null `shootingEndMinute` over `S`, both null together
///   when no slot of `S` carries a shooting block at all (built from the same walk, so there is
///   nothing to assert about the two agreeing).
/// - [OcptDayConvocation.departureMinute] is the maximum, over `S`, of `endMinute ?? startMinute` —
///   a slot with no block at all yet still ends at its own start, for whoever is linked to only
///   that.
/// - [OcptDayConvocation.slotIds] is the ids of `S`, in the order [slots] was given.
///
/// The result is one [OcptDayConvocation] per person and per uncast role named anywhere in [slots],
/// sorted by [OcptDayConvocation.arrivalMinute], ties broken by [OcptDayConvocation.personId] `??`
/// [OcptDayConvocation.roleId] — deterministic, but not "arrival then **name**": nothing here knows
/// a person's or a role's own display name, so a caller wanting that ordering re-sorts on top of
/// this one.
///
/// Minutes are offsets from the day's own midnight and **may exceed 1440** for a night shoot's small
/// hours — nothing here ever takes anything modulo anything. Nothing here throws, either: there is
/// no typed figure left to refuse, a lead time being gone along with the group it used to belong to
/// (ADR 0018).
List<OcptDayConvocation> ocptComputeDayConvocations({required List<OcptConvocationSlot> slots}) {
  final slotsByPersonId = <String, List<OcptConvocationSlot>>{};
  final slotsByRoleId = <String, List<OcptConvocationSlot>>{};

  for (final slot in slots) {
    for (final personId in slot.personIds) {
      (slotsByPersonId[personId] ??= <OcptConvocationSlot>[]).add(slot);
    }
    for (final roleId in slot.uncastRoleIds) {
      (slotsByRoleId[roleId] ??= <OcptConvocationSlot>[]).add(slot);
    }
  }

  final convocations = <OcptDayConvocation>[
    for (final entry in slotsByPersonId.entries)
      _convocationOf(personId: entry.key, roleId: null, ownSlots: entry.value),
    for (final entry in slotsByRoleId.entries)
      _convocationOf(personId: null, roleId: entry.key, ownSlots: entry.value),
  ];

  convocations.sort((left, right) {
    final byArrival = left.arrivalMinute.compareTo(right.arrivalMinute);
    if (byArrival != 0) {
      return byArrival;
    }
    return (left.personId ?? left.roleId ?? "").compareTo(right.personId ?? right.roleId ?? "");
  });

  return convocations;
}

/// Builds the [OcptDayConvocation] of [personId] (or [roleId]) over the slots naming them, [ownSlots]
/// — see [ocptComputeDayConvocations]'s own doc comment for what each figure is read from.
OcptDayConvocation _convocationOf({
  required String? personId,
  required String? roleId,
  required List<OcptConvocationSlot> ownSlots,
}) {
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

    final shootingStart = slot.shootingStartMinute;
    if (shootingStart != null && (patStartMinute == null || shootingStart < patStartMinute)) {
      patStartMinute = shootingStart;
    }
    final shootingEnd = slot.shootingEndMinute;
    if (shootingEnd != null && (patEndMinute == null || shootingEnd > patEndMinute)) {
      patEndMinute = shootingEnd;
    }

    final ownDeparture = slot.endMinute ?? slot.startMinute;
    if (departureMinute == null || ownDeparture > departureMinute) {
      departureMinute = ownDeparture;
    }
  }

  return OcptDayConvocation(
    personId: personId,
    roleId: roleId,
    arrivalMinute: arrivalMinute!,
    patStartMinute: patStartMinute,
    patEndMinute: patEndMinute,
    departureMinute: departureMinute!,
    slotIds: slotIds,
  );
}
