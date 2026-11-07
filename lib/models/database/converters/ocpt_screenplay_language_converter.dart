// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// Convert a [OcptScreenplayLanguage] to and from the text stored in the
/// `project_info.screenplayLanguage` column.
class OcptScreenplayLanguageConverter extends TypeConverter<OcptScreenplayLanguage, String> {
  /// Class constructor
  const OcptScreenplayLanguageConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptScreenplayLanguage fromSql(String fromDb) => OcptScreenplayLanguage.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptScreenplayLanguage value) => value.name;
}
