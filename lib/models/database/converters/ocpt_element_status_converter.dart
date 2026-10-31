// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';

/// Converts a [OcptElementStatus] to and from the text stored in the `elements.status` column.
class OcptElementStatusConverter extends TypeConverter<OcptElementStatus, String> {
  /// Class constructor
  const OcptElementStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptElementStatus fromSql(String fromDb) => OcptElementStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptElementStatus value) => value.name;
}
