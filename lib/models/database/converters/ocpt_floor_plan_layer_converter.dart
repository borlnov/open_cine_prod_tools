// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';

/// Convert a [OcptFloorPlanLayer] to and from the text stored in the `floor_plan_symbols.layer`
/// column.
class OcptFloorPlanLayerConverter extends TypeConverter<OcptFloorPlanLayer, String> {
  /// Class constructor
  const OcptFloorPlanLayerConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptFloorPlanLayer fromSql(String fromDb) => OcptFloorPlanLayer.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptFloorPlanLayer value) => value.name;
}
