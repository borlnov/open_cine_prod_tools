// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_role_casting_stage.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status_lead.dart';

/// Where one role's casting stands: [stage], and how many candidates back it up.
///
/// The one place this reading is written, so the roles tab's pill and any later reader of the same
/// question — a casting call sheet, a future report — cannot disagree about it.
class OcptRoleCastingProgress extends Equatable {
  /// Where the role's casting stands.
  final OcptRoleCastingStage stage;

  /// The number of live candidacies of the role **still in the running**
  /// (`OcptRoleCandidateStatus.isStillALead`), whatever [stage] reads.
  ///
  /// The leads rather than every candidacy: a part where three of the four people seen have
  /// declined has one real possibility left, and a pill counting four would say the casting is in
  /// better shape than it is. The ones who fell out are not lost — they stay on the role sheet,
  /// with their status and their notes, which is where that history is read.
  ///
  /// A cast role may still carry some, having kept the candidates who lost to the one retained; the
  /// pill's `{n} leads` reading is only drawn while [stage] is [OcptRoleCastingStage.inProgress].
  final int candidateCount;

  /// Class constructor
  const OcptRoleCastingProgress({required this.stage, required this.candidateCount});

  /// Reads [role]'s own casting progress off [candidates].
  ///
  /// [candidates] is assumed to already be **that role's own** live candidacies — the caller reads
  /// them out of `OcptResourcesSnapshot.candidatesByRoleId[role.id]` (or the empty list, absent an
  /// entry) — and nothing here filters by `roleId` again: a second filter could only ever agree
  /// with the caller's own read or silently hide a caller's mistake, neither of which this function
  /// is in a position to do anything about.
  factory OcptRoleCastingProgress.of({
    required OcptRole role,
    required List<OcptRoleCandidate> candidates,
  }) {
    final leadCount = candidates.where((candidate) => candidate.status.isStillALead).length;

    final stage = role.personId != null
        ? OcptRoleCastingStage.cast
        : switch ((candidates.isEmpty, leadCount)) {
            (true, _) => OcptRoleCastingStage.notStarted,
            (false, 0) => OcptRoleCastingStage.exhausted,
            (false, _) => OcptRoleCastingStage.inProgress,
          };

    return OcptRoleCastingProgress(stage: stage, candidateCount: leadCount);
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptRoleCastingProgress(stage: $stage, candidateCount: $candidateCount)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [stage, candidateCount];
}

/// How many of [roles] are cast (`OcptRole.personId != null`) — the `M` half of the roles tab
/// header's `N roles · M cast`.
int ocptCastRoleCount(List<OcptRole> roles) => roles.where((role) => role.personId != null).length;
