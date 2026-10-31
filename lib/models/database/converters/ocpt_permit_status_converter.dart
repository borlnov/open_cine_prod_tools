// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';

/// Converts a [OcptPermitStatus] to and from the text stored in the `locations.permitStatus`
/// column.
class OcptPermitStatusConverter extends TypeConverter<OcptPermitStatus, String> {
  /// Class constructor
  const OcptPermitStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptPermitStatus fromSql(String fromDb) => OcptPermitStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptPermitStatus value) => value.name;
}
