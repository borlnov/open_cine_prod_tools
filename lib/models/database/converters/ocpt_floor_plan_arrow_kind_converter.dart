// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';

/// Convert a [OcptFloorPlanArrowKind] to and from the text stored in the
/// `floor_plan_arrows.kind` column.
class OcptFloorPlanArrowKindConverter extends TypeConverter<OcptFloorPlanArrowKind, String> {
  /// Class constructor
  const OcptFloorPlanArrowKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptFloorPlanArrowKind fromSql(String fromDb) => OcptFloorPlanArrowKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptFloorPlanArrowKind value) => value.name;
}
