// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_convocation_audition.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_convocations.dart';

/// One candidacy an audition sees: **who**, and which candidacy of theirs.
///
/// Both ids, because both are needed and neither can stand for the other. [personId] is what the
/// day's call is joined on — a person arrives once and leaves once, whatever brings them in
/// ([ocptComputeDayConvocations]) — while [roleCandidateId] is what says *which part* they are
/// being seen for, which two candidacies of one person differ by and a name alone could never tell
/// apart.
class OcptConvocationCandidacy {
  /// The `role_candidates` row being seen — somebody, for a part.
  final String roleCandidateId;

  /// The person behind that candidacy (`role_candidates.personId`), resolved by the caller.
  final String personId;

  /// Build a candidacy to hang off an [OcptConvocationAudition].
  const OcptConvocationCandidacy({required this.roleCandidateId, required this.personId});
}
