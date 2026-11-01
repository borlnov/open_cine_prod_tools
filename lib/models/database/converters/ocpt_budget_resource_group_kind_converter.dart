// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';

/// Convert a [OcptBudgetResourceGroupKind] to and from the text stored in the
/// `budget_resources.groupKind` column.
class OcptBudgetResourceGroupKindConverter
    extends TypeConverter<OcptBudgetResourceGroupKind, String> {
  /// Class constructor
  const OcptBudgetResourceGroupKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetResourceGroupKind fromSql(String fromDb) =>
      OcptBudgetResourceGroupKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetResourceGroupKind value) => value.name;
}
