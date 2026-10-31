// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';

/// Converts a [OcptShootingDayStatus] to and from the text stored in the `shooting_days.status`
/// column.
class OcptShootingDayStatusConverter extends TypeConverter<OcptShootingDayStatus, String> {
  /// Class constructor
  const OcptShootingDayStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShootingDayStatus fromSql(String fromDb) => OcptShootingDayStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShootingDayStatus value) => value.name;
}
