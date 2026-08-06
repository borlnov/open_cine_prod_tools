// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

// Imported for this file's doc comments alone: `comment_references` needs the types they name
// (`OcptShootingTimelineEntry`, `ocptComputeSlotTimeline`) to resolve.
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// One block already placed on a slot's timeline (an [OcptShootingTimelineEntry] from
/// `ocpt_shooting_day_timeline.dart`, run through [ocptComputeSlotTimeline] first), carrying the
/// one further fact [ocptComputeSlotConvocations] needs about it: which roles it puts on the floor.
///
/// Resolving [roleIds] is entirely the **caller**'s job — this file knows nothing of `shots`,
/// `shot_characters`, `shooting_day_blocks` or any other drift row. A shot block's roles are its
/// shot's own `shot_characters`; a hold block's are the scene it reserves time for; every other
/// block kind (`preparation`, `hairMakeUp`, `meal`, `move`, `wrap`) puts no role anywhere and is
/// passed with an empty [roleIds].
class OcptConvocationBlock {
  /// Builds a block to feed to [ocptComputeSlotConvocations].
  const OcptConvocationBlock({required this.startMinute, required this.endMinute, required this.roleIds});

  /// The minute, from the day's own midnight, this block starts at — [
  /// OcptShootingTimelineEntry.startMinute], already chained.
  final int startMinute;

  /// The minute this block ends at — [OcptShootingTimelineEntry.endMinute].
  final int endMinute;

  /// Every role this block puts on the floor, or empty for a block kind that names none.
  final Set<String> roleIds;
}

/// One `shooting_slot_crew` row's own figure and the figure of the group it belongs to (§2.3 of
/// `docs/plans/schedule-slots-and-computed-convocations.md`) — resolving *which* group a row points
/// at, from its nullable `groupId`, is the caller's job, groups being scoped to a day rather than
/// known here.
class OcptCrewConvocationInput {
  /// Builds a crew row to feed to [ocptComputeSlotConvocations].
  const OcptCrewConvocationInput({required this.id, this.leadMinutes, this.groupLeadMinutes});

  /// The row's own id (`shooting_slot_crew.id`), echoed back on its [OcptCrewConvocation].
  final String id;

  /// This row's own lead time, when it carries one of its own. Wins over [groupLeadMinutes] when
  /// both are set.
  final int? leadMinutes;

  /// The lead time of the group this row belongs to, when it belongs to one and that group carries
  /// a figure. Used only when [leadMinutes] is null.
  final int? groupLeadMinutes;
}

/// One `shooting_slot_cast` row's own figure and the figure of the group it belongs to — the cast
/// sibling of [OcptCrewConvocationInput], carrying the role it convokes rather than a position.
class OcptCastConvocationInput {
  /// Builds a cast row to feed to [ocptComputeSlotConvocations].
  const OcptCastConvocationInput({
    required this.id,
    required this.roleId,
    this.leadMinutes,
    this.groupLeadMinutes,
  });

  /// The row's own id (`shooting_slot_cast.id`), echoed back on its [OcptCastConvocation].
  final String id;

  /// The role this row convokes (`roles.id`) — never the person: the actor is read through
  /// `roles.personId`, so recasting never rewrites the schedule.
  final String roleId;

  /// This row's own lead time, when it carries one of its own. Wins over [groupLeadMinutes] when
  /// both are set.
  final int? leadMinutes;

  /// The lead time of the group this row belongs to, when it belongs to one and that group carries
  /// a figure. Used only when [leadMinutes] is null.
  final int? groupLeadMinutes;
}

/// A crew member's computed convocation for one slot: when they are called, when they wrap, and
/// the lead time [ocptComputeSlotConvocations] actually resolved for them (own or group's, or
/// zero), so a caller can show *why* the call time is what it is without re-resolving it.
class OcptCrewConvocation {
  /// Builds a computed crew convocation.
  const OcptCrewConvocation({
    required this.id,
    required this.callMinute,
    required this.wrapMinute,
    required this.leadMinutes,
  });

  /// The [OcptCrewConvocationInput.id] this convocation answers.
  final String id;

  /// The minute this person is called for, from the day's own midnight.
  final int callMinute;

  /// The minute this person wraps at, or null when the slot has no block at all yet — see
  /// [ocptComputeSlotConvocations]'s own doc comment on the empty-slot case.
  final int? wrapMinute;

  /// The lead time actually used to compute [callMinute]: [OcptCrewConvocationInput.leadMinutes] if
  /// set, else [OcptCrewConvocationInput.groupLeadMinutes], else zero.
  final int leadMinutes;
}

/// A cast member's computed convocation for one slot: their PAT (*prêt à tourner*) band and their
/// arrival, ahead of it by their lead time — the make-up chair.
class OcptCastConvocation {
  /// Builds a computed cast convocation.
  const OcptCastConvocation({
    required this.id,
    required this.arrivalMinute,
    required this.patStartMinute,
    required this.patEndMinute,
    required this.leadMinutes,
  });

  /// The [OcptCastConvocationInput.id] this convocation answers.
  final String id;

  /// The minute this role is expected on set, ready — [patStartMinute] minus [leadMinutes].
  final int arrivalMinute;

  /// The start of this role's *prêt à tourner* band: when the first block of the slot naming it
  /// begins, or the slot's own bounds when no block does — see [ocptComputeSlotConvocations]'s own
  /// doc comment.
  final int patStartMinute;

  /// The end of this role's PAT band, or null exactly when [OcptCrewConvocation.wrapMinute] is —
  /// the slot has no block at all yet.
  final int? patEndMinute;

  /// The lead time actually used to compute [arrivalMinute]: [OcptCastConvocationInput.leadMinutes]
  /// if set, else [OcptCastConvocationInput.groupLeadMinutes], else zero — a lead of zero means
  /// arriving ready, with no make-up chair needed.
  final int leadMinutes;
}

/// One slot's whole set of computed convocations.
class OcptSlotConvocations {
  /// Builds a computed set of convocations.
  const OcptSlotConvocations({required this.crew, required this.cast});

  /// Every crew convocation, in the order [ocptComputeSlotConvocations] was given [
  /// OcptCrewConvocationInput]s.
  final List<OcptCrewConvocation> crew;

  /// Every cast convocation, in the order [ocptComputeSlotConvocations] was given [
  /// OcptCastConvocationInput]s.
  final List<OcptCastConvocation> cast;
}

/// Computes every convocation of one slot from its already-chained [blocks] — the rule stated in
/// `docs/plans/schedule-slots-and-computed-convocations.md` §2.2 and recorded as ADR 0017,
/// implemented exactly once, here.
///
/// **Nobody types a call time, a wrap time or a PAT band.** [OcptCrewConvocationInput] and
/// [OcptCastConvocationInput] carry only a lead time — a typed fact about a person and a look
/// (hair, make-up, costume) or about the band they walk in with — and every clock this function
/// returns is derived from [slotStartMinute] and [blocks] alone. Nothing computed here is ever
/// overridable by hand: a typed clock is a claim nothing keeps true once a block moves, which is
/// exactly the retyping this rework exists to remove (see ADR 0017's Decision).
///
/// **The slot's own band** is the minimum [OcptConvocationBlock.startMinute] and the maximum
/// [OcptConvocationBlock.endMinute] over [blocks] — a minimum and a maximum rather than "the first
/// and the last of the list", since a pinned anchor can put a block earlier than the one before it
/// in the chain's own order.
///
/// **A crew convocation**'s `callMinute` is the slot's own band start minus the resolved lead, and
/// its `wrapMinute` is the band end, full stop — there is no after-offset anywhere in this model.
/// Finishing later is stated as a `wrap` block in the chain, which moves the band end, and with it
/// every crew member's wrap at once, rather than one row's.
///
/// **A cast convocation**'s `patStartMinute`/`patEndMinute` are the same minimum/maximum, but taken
/// only over the blocks that actually name that role (a shot block through its `shot_characters`, a
/// hold block through the scene it reserves time for — resolved into [OcptConvocationBlock.roleIds]
/// by the caller). A role no block of the slot names keeps the **slot's own** band instead: someone
/// convoked and not used is still convoked, and a production that put them on the sheet said so
/// deliberately. `arrivalMinute` is `patStartMinute` minus the resolved lead — the make-up chair,
/// which is why it is per role and per day rather than per film; a lead of zero means arriving
/// ready.
///
/// **A resolved lead** is `leadMinutes ?? groupLeadMinutes ?? 0` on the matching input — the row's
/// own figure wins over its group's. A resolved lead that is negative throws an [ArgumentError],
/// for the same reason a negative block duration does in `ocpt_shooting_day_timeline.dart`: nothing
/// in this mode means "be convoked after you are needed", and a lead is typed, not derived.
///
/// **A slot with no block at all** has no band to read: every [OcptCrewConvocation.wrapMinute] and
/// [OcptCastConvocation.patEndMinute] comes back null (the same convention as [
/// OcptShootingSlotTimeline.endMinute]'s own empty-slot case), while `callMinute`, `patStartMinute`
/// and `arrivalMinute` are computed off [slotStartMinute] instead — a convocation still has a call
/// time when nothing is planned yet.
OcptSlotConvocations ocptComputeSlotConvocations({
  required int slotStartMinute,
  required List<OcptConvocationBlock> blocks,
  required List<OcptCrewConvocationInput> crew,
  required List<OcptCastConvocationInput> cast,
}) {
  final slotBand = _bandOf(blocks);

  final crewConvocations = <OcptCrewConvocation>[];
  for (final input in crew) {
    final leadMinutes = _resolveLead(input.leadMinutes, input.groupLeadMinutes);
    crewConvocations.add(
      OcptCrewConvocation(
        id: input.id,
        callMinute: (slotBand.start ?? slotStartMinute) - leadMinutes,
        wrapMinute: slotBand.end,
        leadMinutes: leadMinutes,
      ),
    );
  }

  final castConvocations = [
    for (final input in cast)
      _castConvocationOf(input: input, slotStartMinute: slotStartMinute, slotBand: slotBand, blocks: blocks),
  ];

  return OcptSlotConvocations(crew: crewConvocations, cast: castConvocations);
}

/// Builds [input]'s [OcptCastConvocation]: its own band, when a block of [blocks] names its role, or
/// [slotBand] otherwise — see [ocptComputeSlotConvocations]'s own doc comment.
OcptCastConvocation _castConvocationOf({
  required OcptCastConvocationInput input,
  required int slotStartMinute,
  required ({int? start, int? end}) slotBand,
  required List<OcptConvocationBlock> blocks,
}) {
  final roleBand = _bandOf(blocks.where((block) => block.roleIds.contains(input.roleId)));
  final patStartMinute = roleBand.start ?? slotBand.start ?? slotStartMinute;
  final patEndMinute = roleBand.end ?? slotBand.end;
  final leadMinutes = _resolveLead(input.leadMinutes, input.groupLeadMinutes);

  return OcptCastConvocation(
    id: input.id,
    arrivalMinute: patStartMinute - leadMinutes,
    patStartMinute: patStartMinute,
    patEndMinute: patEndMinute,
    leadMinutes: leadMinutes,
  );
}

/// The minimum [OcptConvocationBlock.startMinute] and the maximum [OcptConvocationBlock.endMinute]
/// over [blocks], both null when [blocks] is empty.
({int? start, int? end}) _bandOf(Iterable<OcptConvocationBlock> blocks) {
  int? start;
  int? end;
  for (final block in blocks) {
    if (start == null || block.startMinute < start) {
      start = block.startMinute;
    }
    if (end == null || block.endMinute > end) {
      end = block.endMinute;
    }
  }
  return (start: start, end: end);
}

/// `own ?? group ?? 0` — the row's own lead time wins over its group's, and a convocation with
/// neither carries no lead at all. Throws an [ArgumentError] when the resolved figure is negative:
/// see [ocptComputeSlotConvocations]'s own doc comment on why that is refused rather than clamped.
int _resolveLead(int? own, int? group) {
  final lead = own ?? group ?? 0;
  if (lead < 0) {
    throw ArgumentError("A convocation's resolved lead time is negative ($lead minutes)");
  }
  return lead;
}
