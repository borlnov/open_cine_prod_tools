// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_crew_position_ref.dart';

/// The answer [ocptCrewPositionPrefillOf] gives: what a fresh crew row should be pre-filled with,
/// and what the picker beside it should offer.
class OcptCrewPositionPrefill {
  /// The position to pre-fill on the row being added, or null when nothing declared is left to
  /// offer.
  final OcptCrewPositionRef? prefill;

  /// The person's declared positions not already held on that slot, in their declared order — what
  /// the picker shows above the catalogue.
  final List<OcptCrewPositionRef> promotedPositions;

  /// Every position this person already holds on that slot — what the picker must not offer,
  /// catalogue entries included.
  final Set<OcptCrewPositionRef> takenPositions;

  /// Class constructor
  const OcptCrewPositionPrefill({
    required this.prefill,
    required this.promotedPositions,
    required this.takenPositions,
  });
}

/// Get the join between the address book and the schedule: `person_positions` says *that* someone
/// holds
/// a function on the film, a slot's own crew row says *when* and *at which post*, and nothing
/// joined the two until this function did.
///
/// It joins a person's [declaredPositions] (`person_positions`, in their display order) with the
/// positions they already [heldOnSlot] (that slot's own live `shooting_slot_crew` rows for that
/// same person) into the pre-fill and the picker's promoted order — so adding a person to a slot
/// lands on their first declared position not already taken by them **on that slot**, and adding
/// the same person again lands on their second, then their third.
///
/// [OcptCrewPositionPrefill.takenPositions] is every non-empty ref of [heldOnSlot] — an empty ref
/// holds nothing, so it makes nothing taken. [OcptCrewPositionPrefill.promotedPositions] is
/// [declaredPositions], in order, dropping empty refs, dropping duplicates (first occurrence wins
/// — a person may have declared the same thing twice), and dropping anything already taken.
/// [OcptCrewPositionPrefill.prefill] is the first entry of the promoted list, or null when it is
/// empty: nothing declared, or everything already taken, pre-fills nothing — exactly the behaviour
/// before this join existed.
OcptCrewPositionPrefill ocptCrewPositionPrefillOf({
  required List<OcptCrewPositionRef> declaredPositions,
  required List<OcptCrewPositionRef> heldOnSlot,
}) {
  final takenPositions = <OcptCrewPositionRef>{
    for (final ref in heldOnSlot)
      if (!ref.isEmpty) ref,
  };

  final promotedPositions = <OcptCrewPositionRef>[];
  final seen = <OcptCrewPositionRef>{};
  for (final ref in declaredPositions) {
    if (ref.isEmpty || takenPositions.contains(ref) || !seen.add(ref)) {
      continue;
    }
    promotedPositions.add(ref);
  }

  return OcptCrewPositionPrefill(
    prefill: promotedPositions.isEmpty ? null : promotedPositions.first,
    promotedPositions: promotedPositions,
    takenPositions: takenPositions,
  );
}
