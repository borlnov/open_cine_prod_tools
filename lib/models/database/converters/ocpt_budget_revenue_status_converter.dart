// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';

/// Converts a [OcptBudgetRevenueStatus] to and from the text stored in the
/// `budget_revenues.status` column.
class OcptBudgetRevenueStatusConverter extends TypeConverter<OcptBudgetRevenueStatus, String> {
  /// Class constructor
  const OcptBudgetRevenueStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetRevenueStatus fromSql(String fromDb) => OcptBudgetRevenueStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetRevenueStatus value) => value.name;
}
