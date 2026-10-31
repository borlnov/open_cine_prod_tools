// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';

/// Converts an [OcptLocationAvailabilityKind] to and from the text stored in the
/// `location_availabilities.kind` column.
class OcptLocationAvailabilityKindConverter
    extends TypeConverter<OcptLocationAvailabilityKind, String> {
  /// Class constructor
  const OcptLocationAvailabilityKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptLocationAvailabilityKind fromSql(String fromDb) =>
      OcptLocationAvailabilityKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptLocationAvailabilityKind value) => value.name;
}
