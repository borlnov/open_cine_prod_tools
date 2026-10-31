// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alert_kind.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';

/// How urgently an [OcptScheduleAlert] needs a human to look at it.
///
/// A property of the *kind* ([OcptScheduleAlertKind.severity]), never of one occurrence: a
/// double-booked person is exactly as hard an alert on a quiet Tuesday as on the busiest day of the
/// shoot, so nothing here is computed per instance.
enum OcptScheduleAlertSeverity {
  /// The plan, as written, cannot be shot the way it stands — somebody is asked to be in two places
  /// at once, or a location isn't cleared for the slot booked in it.
  hard,

  /// The plan is shootable but worth a second look before the day arrives — a position quietly
  /// dropped, a role nobody has cast yet, a figure the app computed running past what was recorded
  /// for it.
  soft,
}
