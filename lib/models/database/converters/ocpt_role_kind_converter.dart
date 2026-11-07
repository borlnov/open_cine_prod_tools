// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// Convert a [OcptRoleKind] to and from the text stored in the `roles.kind` column.
class OcptRoleKindConverter extends TypeConverter<OcptRoleKind, String> {
  /// Class constructor
  const OcptRoleKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptRoleKind fromSql(String fromDb) => OcptRoleKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptRoleKind value) => value.name;
}
