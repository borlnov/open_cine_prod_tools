// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/events/schedule_base_event.dart';

/// The events about the shooting days themselves.
sealed class OcptScheduleDaysEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleDaysEvent();
}

/// Create a new shooting day dated [date], appended at the end of the schedule.
class OcptScheduleDayCreatedEvent extends OcptScheduleDaysEvent {
  /// The new day's date.
  final DateTime date;

  /// Class constructor
  const OcptScheduleDayCreatedEvent({required this.date});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, date];
}

/// Write a new date onto day [dayId] immediately, dispatched by the day inspector's own date
/// field.
class OcptScheduleDayDateChangedEvent extends OcptScheduleDaysEvent {
  /// The id of the day being redated.
  final String dayId;

  /// The date just picked.
  final DateTime date;

  /// Class constructor
  const OcptScheduleDayDateChangedEvent({required this.dayId, required this.date});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, dayId, date];
}

/// Write a new status onto day [dayId] immediately, dispatched by the day inspector's own status
/// control.
class OcptScheduleDayStatusChangedEvent extends OcptScheduleDaysEvent {
  /// The id of the day whose status changed.
  final String dayId;

  /// The status just picked.
  final OcptShootingDayStatus status;

  /// Class constructor
  const OcptScheduleDayStatusChangedEvent({required this.dayId, required this.status});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, dayId, status];
}

/// Duplicate day [sourceDayId] into a new day dated [date], dispatched by the day card's own `⋮`
/// menu once its date picker resolved. Copies the source day's slots, crew and cast; copies
/// neither its placed shots nor its crew note (`OcptScheduleService.duplicateDay`'s own rule).
class OcptScheduleDayDuplicationRequestedEvent extends OcptScheduleDaysEvent {
  /// The id of the day to duplicate.
  final String sourceDayId;

  /// The new day's date.
  final DateTime date;

  /// Class constructor
  const OcptScheduleDayDuplicationRequestedEvent({required this.sourceDayId, required this.date});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sourceDayId, date];
}

/// Delete day [dayId] for good — its slots, their crew and cast, and its blocks along with it —
/// dispatched by the mode once its `OcptConfirmDialog` (opened by the day card's own `⋮` menu) has
/// already been answered.
class OcptScheduleDayDeletionConfirmedEvent extends OcptScheduleDaysEvent {
  /// The id of the day to delete.
  final String dayId;

  /// Class constructor
  const OcptScheduleDayDeletionConfirmedEvent({required this.dayId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, dayId];
}
