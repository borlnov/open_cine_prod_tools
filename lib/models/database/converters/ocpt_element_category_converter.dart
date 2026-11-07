// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';

/// Convert a [OcptElementCategory] to and from the text stored in the `elements.category` column.
class OcptElementCategoryConverter extends TypeConverter<OcptElementCategory, String> {
  /// Class constructor
  const OcptElementCategoryConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptElementCategory fromSql(String fromDb) => OcptElementCategory.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptElementCategory value) => value.name;
}
