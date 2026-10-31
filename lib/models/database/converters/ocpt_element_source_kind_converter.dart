// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';

/// Converts a [OcptElementSourceKind] to and from the text stored in the `elements.sourceKind`
/// column.
class OcptElementSourceKindConverter extends TypeConverter<OcptElementSourceKind, String> {
  /// Class constructor
  const OcptElementSourceKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptElementSourceKind fromSql(String fromDb) => OcptElementSourceKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptElementSourceKind value) => value.name;
}
