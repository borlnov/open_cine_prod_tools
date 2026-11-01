// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';

/// Convert a [OcptBudgetResourceStatus] to and from the text stored in the
/// `budget_resources.status` column.
class OcptBudgetResourceStatusConverter extends TypeConverter<OcptBudgetResourceStatus, String> {
  /// Class constructor
  const OcptBudgetResourceStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetResourceStatus fromSql(String fromDb) => OcptBudgetResourceStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetResourceStatus value) => value.name;
}
