// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';

/// Convert a [OcptBudgetAllowanceKind] to and from the text stored in the
/// `budget_allowances.kind` column.
class OcptBudgetAllowanceKindConverter extends TypeConverter<OcptBudgetAllowanceKind, String> {
  /// Class constructor
  const OcptBudgetAllowanceKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetAllowanceKind fromSql(String fromDb) => OcptBudgetAllowanceKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetAllowanceKind value) => value.name;
}
