// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alert_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';

/// One person's unavailability window, reduced to what [OcptSchedulePersonUnavailableAlert] needs
/// — the mirror of `OcptPersonUnavailability`, minus the person's own id (the caller already groups
/// these under [OcptScheduleAlertPerson]) and the free-text reason, which this file never reads.
class OcptScheduleAlertUnavailability {
  /// This window's own id, echoed back on [OcptSchedulePersonUnavailableAlert.unavailabilityId].
  final String id;

  /// The first date this window covers.
  final DateTime startDate;

  /// The last date this window covers, inclusive.
  final DateTime endDate;

  /// Which part of each covered day this window takes.
  final OcptDayPartSlot dayPart;

  /// The start of the window in minutes from midnight, or null unless [dayPart] is
  /// [OcptDayPartSlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [dayPart] is
  /// [OcptDayPartSlot.custom].
  final int? endMinute;

  /// Build an unavailability window to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertUnavailability({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.dayPart,
    required this.startMinute,
    required this.endMinute,
  });
}
