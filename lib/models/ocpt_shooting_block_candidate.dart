// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// One candidacy an audition block sees — who is read at this hour, and for which part.
///
/// **The candidacy is convoked, not the person** — see `OcptShootingBlockCandidatesTable`'s own doc
/// comment: [roleCandidateId] names a `role_candidates` row, so the convocation says *seen for
/// which part*, and one person read for two parts on one day is two convocations. The person
/// themselves, and everything about them, is resolved through that candidacy at the point this is
/// displayed, exactly as `OcptShootingSlotCastMember` resolves an actor through `roles.personId`.
///
/// **This row's arrival, PAT band and departure are computed, never typed** (ADR 0018 as ADR 0024
/// applies it, `lib/utils/ocpt_shooting_convocations.dart`): the **block** is the convocation, and
/// every figure about it is read off every live audition block naming this candidacy that day,
/// joined together — which is what gives each candidate an hour of their own rather than the
/// unit's whole day.
class OcptShootingBlockCandidate extends Equatable {
  /// The stable, unique id of this convocation (a UUID).
  final String id;

  /// The audition block this convocation is read off.
  final String blockId;

  /// The candidacy seen during the block — who, for which part.
  final String roleCandidateId;

  /// What this convocation says beside the hour.
  final String notes;

  /// Class constructor
  const OcptShootingBlockCandidate({
    required this.id,
    required this.blockId,
    required this.roleCandidateId,
    required this.notes,
  });

  /// Builds an [OcptShootingBlockCandidate] from its stored [row].
  factory OcptShootingBlockCandidate.fromRow(OcptShootingBlockCandidateRow row) =>
      OcptShootingBlockCandidate(
        id: row.id,
        blockId: row.blockId,
        roleCandidateId: row.roleCandidateId,
        notes: row.notes,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingBlockCandidate(id: $id, blockId: $blockId, roleCandidateId: $roleCandidateId)";

  /// Object properties
  @override
  List<Object?> get props => [id, blockId, roleCandidateId, notes];
}
