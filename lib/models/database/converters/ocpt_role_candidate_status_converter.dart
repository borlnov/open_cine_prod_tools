// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';

/// Converts a [OcptRoleCandidateStatus] to and from the text stored in the
/// `role_candidates.status` column.
class OcptRoleCandidateStatusConverter extends TypeConverter<OcptRoleCandidateStatus, String> {
  /// Class constructor
  const OcptRoleCandidateStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptRoleCandidateStatus fromSql(String fromDb) => OcptRoleCandidateStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptRoleCandidateStatus value) => value.name;
}
