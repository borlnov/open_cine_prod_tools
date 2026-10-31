// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';

/// Converts a [OcptFloorPlanSetElementShape] to and from the text stored in the
/// `floor_plan_symbols.setElementShape` column.
class OcptFloorPlanSetElementShapeConverter
    extends TypeConverter<OcptFloorPlanSetElementShape, String> {
  /// Class constructor
  const OcptFloorPlanSetElementShapeConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptFloorPlanSetElementShape fromSql(String fromDb) =>
      OcptFloorPlanSetElementShape.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptFloorPlanSetElementShape value) => value.name;
}
