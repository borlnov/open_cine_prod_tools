// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_role.dart';

/// Where a role's casting stands, read off [OcptRole.personId] and its live candidacies.
enum OcptRoleCastingStage {
  /// The role is cast — `personId` is set, whether by hand through the sheet's own picker or by a
  /// candidacy retained through `OcptRoleCandidatesService`. The roles tab and any later reader
  /// draw no distinction between the two: both are, simply, "cast".
  cast,

  /// The role is not cast, and at least one candidacy is still a lead
  /// (`OcptRoleCandidateStatus.isStillALead`): somebody could yet be cast in it.
  inProgress,

  /// The role is not cast, candidacies were recorded, and **not one of them is still a lead**:
  /// every person seen for it has been turned down, has declined, or is unavailable.
  ///
  /// Its own stage rather than [inProgress] with a count of zero, and rather than [notStarted]: "we
  /// saw four people and none of them can do it" is the state a production most needs to see
  /// coming, and neither of the other two says it. It is also the one stage a role can **leave**
  /// without anybody being cast — one more name entered puts it back to [inProgress].
  exhausted,

  /// The role is not cast and nobody has been recorded for it at all.
  notStarted,
}
