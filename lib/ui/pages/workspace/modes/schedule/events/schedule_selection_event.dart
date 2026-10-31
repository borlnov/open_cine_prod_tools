// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/events/schedule_base_event.dart';

/// The events that move the selected day, block or shot.
sealed class OcptScheduleSelectionEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleSelectionEvent();
}

/// Selects day [dayId] in the left dock's own list, or on a strip/week/month cell, showing its own
/// read-out in the inspector. Clears both the selected block and the selected shot: a day selected
/// on its own has neither, and the day's own read-out is what the inspector must fall back to when
/// the user goes looking at a day — leaving a shot selected would silently keep it on screen
/// instead.
class OcptScheduleDaySelectedEvent extends OcptScheduleSelectionEvent {
  /// The id of the day to select.
  final String dayId;

  /// Class constructor
  const OcptScheduleDaySelectedEvent({required this.dayId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, dayId];
}

/// Selects block [blockId] — a placed shot's own strip chip, or one of a slot card's own timetable
/// rows — showing its own read-out in the inspector. Also selects [dayId], the block's own day, so
/// the left dock and the inspector stay in step, and clears the selected shot
/// (`OcptScheduleShotSelectedEvent`'s own doc comment): the two selections are mutually exclusive.
class OcptScheduleBlockSelectedEvent extends OcptScheduleSelectionEvent {
  /// The id of the block to select.
  final String blockId;

  /// The id of the day the block belongs to.
  final String dayId;

  /// Class constructor
  const OcptScheduleBlockSelectedEvent({required this.blockId, required this.dayId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, dayId];
}

/// Selects shot [shotId] — a row of the left dock's own "shots still to place" list — showing its
/// own read-out in the inspector, and opens the right dock on the `Inspector` tab. Clears the
/// selected block: the two selections are mutually exclusive, so bringing a shot's own read-out up
/// would otherwise silently leave a stale block one showing underneath it. A [shotId] naming no
/// live shot is ignored, mirroring how `OcptScheduleBlockSelectedEvent` ignores an unknown day.
class OcptScheduleShotSelectedEvent extends OcptScheduleSelectionEvent {
  /// The id of the shot to select.
  final String shotId;

  /// Class constructor
  const OcptScheduleShotSelectedEvent({required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId];
}
