// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';

/// Converts a [OcptShotCheckReason] to and from the text stored in the `shots.checkReason`
/// column.
class OcptShotCheckReasonConverter extends TypeConverter<OcptShotCheckReason, String> {
  /// Class constructor
  const OcptShotCheckReasonConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShotCheckReason fromSql(String fromDb) => OcptShotCheckReason.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShotCheckReason value) => value.name;
}
