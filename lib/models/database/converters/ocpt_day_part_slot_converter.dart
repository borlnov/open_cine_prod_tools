// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';

/// Converts an [OcptDayPartSlot] to and from the text stored in the `slot` column of
/// `person_unavailabilities` and `location_availabilities`.
///
/// The one converter this app declares outside a table file, because it is the one an enum shared
/// by **two** tables needs: a person is unavailable over a part of a day, a location is available
/// over a part of a day, and the four values are the same four values. Declaring it inside either
/// table would make the other import a table it has nothing to do with.
class OcptDayPartSlotConverter extends TypeConverter<OcptDayPartSlot, String> {
  /// Class constructor
  const OcptDayPartSlotConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptDayPartSlot fromSql(String fromDb) => OcptDayPartSlot.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptDayPartSlot value) => value.name;
}
