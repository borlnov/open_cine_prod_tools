// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';

/// Converts a [OcptImageRightsStatus] to and from the text stored in the
/// `people.imageRightsStatus` column.
class OcptImageRightsStatusConverter extends TypeConverter<OcptImageRightsStatus, String> {
  /// Class constructor
  const OcptImageRightsStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptImageRightsStatus fromSql(String fromDb) => OcptImageRightsStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptImageRightsStatus value) => value.name;
}
