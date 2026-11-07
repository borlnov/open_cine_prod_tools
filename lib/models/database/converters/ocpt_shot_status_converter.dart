// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Convert a [OcptShotStatus] to and from the text stored in the `shots.status` column.
class OcptShotStatusConverter extends TypeConverter<OcptShotStatus, String> {
  /// Class constructor
  const OcptShotStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShotStatus fromSql(String fromDb) => OcptShotStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShotStatus value) => value.name;
}
