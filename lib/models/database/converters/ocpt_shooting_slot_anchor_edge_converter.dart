// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// Converts a [OcptShootingSlotAnchorEdge] to and from the text stored in the
/// `shooting_slots.anchor_edge` column.
class OcptShootingSlotAnchorEdgeConverter
    extends TypeConverter<OcptShootingSlotAnchorEdge, String> {
  /// Class constructor
  const OcptShootingSlotAnchorEdgeConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShootingSlotAnchorEdge fromSql(String fromDb) =>
      OcptShootingSlotAnchorEdge.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShootingSlotAnchorEdge value) => value.name;
}
