// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// Convert a [OcptPageFormat] to and from the text stored in the `project_info.pageFormat`
/// column.
class OcptPageFormatConverter extends TypeConverter<OcptPageFormat, String> {
  /// Class constructor
  const OcptPageFormatConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptPageFormat fromSql(String fromDb) => OcptPageFormat.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptPageFormat value) => value.name;
}
