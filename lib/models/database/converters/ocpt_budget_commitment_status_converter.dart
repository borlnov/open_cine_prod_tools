// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';

/// Converts a [OcptBudgetCommitmentStatus] to and from the text stored in the
/// `budget_commitments.status` column.
class OcptBudgetCommitmentStatusConverter
    extends TypeConverter<OcptBudgetCommitmentStatus, String> {
  /// Class constructor
  const OcptBudgetCommitmentStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetCommitmentStatus fromSql(String fromDb) =>
      OcptBudgetCommitmentStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetCommitmentStatus value) => value.name;
}
