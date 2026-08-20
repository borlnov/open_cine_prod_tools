// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';

/// Where a role's casting stands, read off [OcptRole.personId] and its live candidacies.
enum OcptRoleCastingStage {
  /// The role is cast — `personId` is set, whether by hand through the sheet's own picker or by a
  /// candidacy retained through `OcptRoleCandidatesService`. The roles tab and any later reader draw
  /// no distinction between the two: both are, simply, "cast".
  cast,

  /// The role is not cast, but at least one candidacy is live: somebody has been seen for it.
  inProgress,

  /// The role is not cast and nobody has been seen for it yet.
  notStarted,
}

/// Where one role's casting stands: [stage], and how many candidates back it up.
///
/// The one place this reading is written, so the roles tab's pill and any later reader of the same
/// question — a casting call sheet, a future report — cannot disagree about it.
class OcptRoleCastingProgress extends Equatable {
  /// Where the role's casting stands.
  final OcptRoleCastingStage stage;

  /// The number of live candidacies the role carries, whatever [stage] reads — a cast role may
  /// still have kept the candidates who lost to the one retained, and the pill's `{n} seen` reading
  /// is only drawn while [stage] is [OcptRoleCastingStage.inProgress].
  final int candidateCount;

  /// Class constructor
  const OcptRoleCastingProgress({required this.stage, required this.candidateCount});

  /// Reads [role]'s own casting progress off [candidates].
  ///
  /// [candidates] is assumed to already be **that role's own** live candidacies — the caller reads
  /// them out of `OcptResourcesSnapshot.candidatesByRoleId[role.id]` (or the empty list, absent an
  /// entry) — and nothing here filters by `roleId` again: a second filter could only ever agree with
  /// the caller's own read or silently hide a caller's mistake, neither of which this function is in
  /// a position to do anything about.
  factory OcptRoleCastingProgress.of({
    required OcptRole role,
    required List<OcptRoleCandidate> candidates,
  }) {
    final stage = role.personId != null
        ? OcptRoleCastingStage.cast
        : (candidates.isEmpty ? OcptRoleCastingStage.notStarted : OcptRoleCastingStage.inProgress);

    return OcptRoleCastingProgress(stage: stage, candidateCount: candidates.length);
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptRoleCastingProgress(stage: $stage, candidateCount: $candidateCount)";

  /// Object properties
  @override
  List<Object?> get props => [stage, candidateCount];
}

/// How many of [roles] are cast (`OcptRole.personId != null`) — the `M` half of the roles tab
/// header's `N roles · M cast`.
int ocptCastRoleCount(List<OcptRole> roles) =>
    roles.where((role) => role.personId != null).length;
