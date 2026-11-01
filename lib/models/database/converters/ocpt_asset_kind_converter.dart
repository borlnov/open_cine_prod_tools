// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';

/// Convert a [OcptAssetKind] to and from the text stored in the `assets.kind` column.
class OcptAssetKindConverter extends TypeConverter<OcptAssetKind, String> {
  /// Class constructor
  const OcptAssetKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptAssetKind fromSql(String fromDb) => OcptAssetKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptAssetKind value) => value.name;
}
