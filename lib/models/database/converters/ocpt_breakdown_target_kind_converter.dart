// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';

/// Converts a [OcptBreakdownTargetKind] to and from the text stored in the
/// `breakdown_tags.targetKind` column.
class OcptBreakdownTargetKindConverter extends TypeConverter<OcptBreakdownTargetKind, String> {
  /// Class constructor
  const OcptBreakdownTargetKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBreakdownTargetKind fromSql(String fromDb) => OcptBreakdownTargetKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBreakdownTargetKind value) => value.name;
}
