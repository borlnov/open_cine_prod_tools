// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/events/schedule_base_event.dart';

/// The events about a day's own events.
sealed class OcptScheduleDayEventsEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleDayEventsEvent();
}

/// Create a new event on day [dayId] at [minute], dispatched by the day view's or the day
/// inspector's own `+ Event` footer (`OcptScheduleDayEventsList.onEventAdded`). [minute] is a
/// starting point the row's own minute field immediately corrects, never a claim about when
/// anything happens — see `OcptScheduleMode`'s own default-hour helper.
class OcptScheduleDayEventCreatedEvent extends OcptScheduleDayEventsEvent {
  /// The id of the day the event is added to.
  final String dayId;

  /// The hour the event is first given.
  final int minute;

  /// Class constructor
  const OcptScheduleDayEventCreatedEvent({required this.dayId, required this.minute});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, dayId, minute];
}

/// Write a new hour onto event [eventId], dispatched the moment its own minute field commits —
/// unlike every other event field, an event's hour is never typed into the field-edit debounce
/// (`OcptScheduleField` carries no minute entry), mirroring a slot's or a block's own anchor.
class OcptScheduleDayEventMinuteChangedEvent extends OcptScheduleDayEventsEvent {
  /// The id of the event whose hour changed.
  final String eventId;

  /// The event's own new hour.
  final int minute;

  /// Class constructor
  const OcptScheduleDayEventMinuteChangedEvent({required this.eventId, required this.minute});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, eventId, minute];
}

/// Remove event [eventId] for good, dispatched once `OcptConfirmDialog` has confirmed it — named
/// for the confirmation it comes after, exactly as `OcptScheduleBlockDeletionConfirmedEvent` is.
class OcptScheduleDayEventDeletionConfirmedEvent extends OcptScheduleDayEventsEvent {
  /// The id of the event to remove.
  final String eventId;

  /// Class constructor
  const OcptScheduleDayEventDeletionConfirmedEvent({required this.eventId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, eventId];
}
