// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alert_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alert_unavailability.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';

/// One person of the address book, reduced to what rules 1 and 9 need about a human: their own
/// [unavailabilities] and their recorded [maxDailyPresenceMinutes].
class OcptScheduleAlertPerson {
  /// Builds a person to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertPerson({
    required this.id,
    required this.maxDailyPresenceMinutes,
    required this.unavailabilities,
  });

  /// The person's own id, matched against a slot's own [OcptScheduleAlertSlot.personIds].
  final String id;

  /// `people.maxDailyPresenceMinutes` verbatim — null while nobody has recorded one, which
  /// [OcptSchedulePresenceExceededAlert] never fires on.
  final int? maxDailyPresenceMinutes;

  /// This person's own recorded unavailabilities, in no particular order.
  final List<OcptScheduleAlertUnavailability> unavailabilities;
}
