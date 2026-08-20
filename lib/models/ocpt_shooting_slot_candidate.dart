// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// One candidate convoked during a `shooting_slots` window — the fourth kind of link a slot
/// carries, beside its crew, its cast and its guests.
///
/// **The candidacy is convoked, not the person** — see `OcptShootingSlotCandidatesTable`'s own doc
/// comment: [roleCandidateId] names a `role_candidates` row, so the convocation says *seen for
/// which part*, and one person seen for two parts on one day reads as two convocations. The person
/// themselves, and everything about them, is resolved through that candidacy at the point this is
/// displayed, exactly as `OcptShootingSlotCastMember` resolves an actor through `roles.personId`.
///
/// **This row's arrival, PAT band and departure are computed, never typed** (ADR 0018,
/// `lib/utils/ocpt_shooting_convocations.dart`): the slot is the convocation, and every figure
/// about it is read off every live slot this candidacy is on that day, joined together.
class OcptShootingSlotCandidate extends Equatable {
  /// The stable, unique id of this convocation (a UUID).
  final String id;

  /// The slot this convocation is for.
  final String slotId;

  /// The candidacy convoked during the slot — who, for which part.
  final String roleCandidateId;

  /// Free-form notes about this convocation.
  final String notes;

  /// Class constructor
  const OcptShootingSlotCandidate({
    required this.id,
    required this.slotId,
    required this.roleCandidateId,
    required this.notes,
  });

  /// Builds an [OcptShootingSlotCandidate] from its stored [row].
  factory OcptShootingSlotCandidate.fromRow(OcptShootingSlotCandidateRow row) =>
      OcptShootingSlotCandidate(
        id: row.id,
        slotId: row.slotId,
        roleCandidateId: row.roleCandidateId,
        notes: row.notes,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingSlotCandidate(id: $id, slotId: $slotId, roleCandidateId: $roleCandidateId)";

  /// Object properties
  @override
  List<Object?> get props => [id, slotId, roleCandidateId, notes];
}
