// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';

/// Converts a [OcptBreakdownSceneStatus] to and from the text stored in the
/// `scene_breakdowns.status` column.
class OcptBreakdownSceneStatusConverter extends TypeConverter<OcptBreakdownSceneStatus, String> {
  /// Class constructor
  const OcptBreakdownSceneStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBreakdownSceneStatus fromSql(String fromDb) => OcptBreakdownSceneStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBreakdownSceneStatus value) => value.name;
}
