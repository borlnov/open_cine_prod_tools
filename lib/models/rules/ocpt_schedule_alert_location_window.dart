// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';

/// One availability window of a location, reduced to what [OcptScheduleLocationUncoveredAlert]
/// needs — the mirror of `OcptLocationAvailability`, minus `OcptLocationAvailabilityKind` (both of
/// its values count as covering, so the caller need not even resolve which one this is) and its
/// free-text note.
class OcptScheduleAlertLocationWindow {
  /// The first date this window covers.
  final DateTime startDate;

  /// The last date this window covers, inclusive.
  final DateTime endDate;

  /// Which days of the week, inside the range, this window covers — the mask `ocptWeekdayMask*`
  /// reads (`lib/models/rules/ocpt_weekday_mask.dart`).
  final int weekdays;

  /// Which part of each covered day this window takes.
  final OcptDayPartSlot dayPart;

  /// The start of the window in minutes from midnight, or null unless [dayPart] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [dayPart] is
  /// [OcptDayPartSlot.custom].
  final int? endMinute;

  /// Builds a location window to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertLocationWindow({
    required this.startDate,
    required this.endDate,
    required this.weekdays,
    required this.dayPart,
    required this.startMinute,
    required this.endMinute,
  });
}
