// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// Converts a [OcptShootingBlockKind] to and from the text stored in the
/// `shooting_day_blocks.kind` column.
class OcptShootingBlockKindConverter extends TypeConverter<OcptShootingBlockKind, String> {
  /// Class constructor
  const OcptShootingBlockKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShootingBlockKind fromSql(String fromDb) => OcptShootingBlockKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShootingBlockKind value) => value.name;
}
