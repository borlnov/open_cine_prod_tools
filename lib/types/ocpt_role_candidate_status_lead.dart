// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';

/// Whether a candidacy in this status is still a **lead** for the part — somebody the production
/// could yet end up casting.
///
/// The three closed statuses are the three ways a candidacy ends without becoming the casting:
/// [OcptRoleCandidateStatus.notRetained], [OcptRoleCandidateStatus.declined] and
/// [OcptRoleCandidateStatus.unavailable]. [OcptRoleCandidateStatus.retained] is **open**: it is not
/// a dead end, it is the answer — a role holding one reads as cast long before this getter is
/// consulted (`OcptRoleCastingProgress`).
///
/// Written here, on the enum, rather than in whichever reader needs it first: "is this person still
/// a possibility" is a question about the status itself, and a second reader deciding it again is
/// how two counts of the same casting come to disagree.
extension OcptRoleCandidateStatusLead on OcptRoleCandidateStatus {
  /// Tell whether this status leaves the candidacy in the running. See the extension's doc comment.
  ///
  /// A `switch` with no `default`: a ninth status must be placed on one side or the other here
  /// rather than silently counting as a lead.
  bool get isStillALead => switch (this) {
    OcptRoleCandidateStatus.spotted => true,
    OcptRoleCandidateStatus.toMeet => true,
    OcptRoleCandidateStatus.seen => true,
    OcptRoleCandidateStatus.shortlisted => true,
    OcptRoleCandidateStatus.retained => true,
    OcptRoleCandidateStatus.notRetained => false,
    OcptRoleCandidateStatus.declined => false,
    OcptRoleCandidateStatus.unavailable => false,
  };
}
