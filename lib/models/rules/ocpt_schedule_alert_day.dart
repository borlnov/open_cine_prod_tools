// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alert_called_role.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alert_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timelines.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_fixed_end_miss.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_overrun.dart';

/// One day, joined by the caller into everything the ten rules read about it.
class OcptScheduleAlertDay extends Equatable {
  /// This day's own id.
  final String id;

  /// This day's own calendar date — what rules 1 and 3 cross against a window's date range and
  /// weekday mask.
  final DateTime date;

  /// This day's own live slots, in **resolved-start order**: rule 2 names the earlier and the later
  /// of two overlapping slots out of this list's own order, so the caller orders it, not this file.
  final List<OcptScheduleAlertSlot> slots;

  /// This day's own [OcptShootingDayTimelines.overruns], passed straight through by rule 6.
  final List<OcptTimelineOverrun> overruns;

  /// This day's own [OcptShootingDayTimelines.fixedEndMisses], passed straight through by rule 7.
  final List<OcptTimelineFixedEndMiss> fixedEndMisses;

  /// Every role a shot placed on this day calls for, in the order the caller found them — rule 4
  /// keeps the first [OcptScheduleAlertCalledRole.shotId] it meets for a given role and ignores the
  /// rest.
  final List<OcptScheduleAlertCalledRole> calledRoles;

  /// Build a day to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertDay({
    required this.id,
    required this.date,
    required this.slots,
    required this.overruns,
    required this.fixedEndMisses,
    required this.calledRoles,
  });

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [id, date, slots, overruns, fixedEndMisses, calledRoles];
}
