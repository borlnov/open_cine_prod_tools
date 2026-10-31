// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/events/schedule_base_event.dart';

/// The events about the free-text fields typed into the day view and the inspector.
sealed class OcptScheduleFieldsEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleFieldsEvent();
}

/// Records the raw text just typed into [field] of entity [targetId] as a pending edit, dispatched
/// on every keystroke into a day/slot/block/crew/cast/group free-text field — rides
/// `OcptScheduleBloc`'s own 2 s field-edit debounce.
class OcptScheduleFieldChangedEvent extends OcptScheduleFieldsEvent {
  /// The id of the entity being edited (a day, a slot, a block, a crew assignment, a cast
  /// convocation or a group, according to [field]).
  final String targetId;

  /// Which field is being edited.
  final OcptScheduleField field;

  /// The field's raw text, as typed.
  final String rawValue;

  /// Class constructor
  const OcptScheduleFieldChangedEvent({
    required this.targetId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, targetId, field, rawValue];
}

/// Fired by the field-edit debounce timer once it elapses with no further typing: writes every
/// pending field edit. Not meant to be dispatched by a widget; the bloc dispatches it itself.
class OcptScheduleFieldEditFlushRequestedEvent extends OcptScheduleFieldsEvent {
  /// Class constructor
  const OcptScheduleFieldEditFlushRequestedEvent();
}
