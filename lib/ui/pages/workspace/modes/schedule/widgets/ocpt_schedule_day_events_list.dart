// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';

/// The rows and the `+ Event` footer of a day's own events — nothing else. Benoit settled on
/// **one widget shown by both the day view and the day inspector**, so the two surfaces can never
/// read a day's events apart: each host frames it with its own title (the day view in its own
/// bordered band, mirroring the summary band's container; the inspector in its existing
/// `_OcptScheduleInspectorSection`), which is why this widget draws no title of its own.
///
/// One row per event, in the order [events] is handed them (already sorted by hour): the hour, in
/// the very [OcptScheduleMinuteField] every other time in this mode is edited or read through — the
/// hour keeps a fixed width and the label takes the rest, so the row lays out equally well in the
/// right dock's narrow column and across the day view's full width — then the label, a single-line
/// field riding the mode's usual 2 s field-edit debounce, a remove control, and finally the note on
/// a line of its own, same debounce. Both text fields follow the controller-sync idiom
/// `_OcptScheduleSlotNoteField` (`ocpt_schedule_slot_card.dart`) already does: the internal
/// controller is only reset when the value handed in genuinely differs from what it already holds,
/// so the caret never jumps mid-typing.
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed: with all of them null the row reads as plain text (the hour through
/// [OcptScheduleMinuteField]'s own read-only rendering, the label falling back to
/// `Untitled event` when empty, and the note drawing **nothing at all** when empty — exactly the
/// rule a guest card's own text lines already follow) and neither the remove control nor the
/// `+ Event` footer draws. [onEventDeletionRequested] only ever *asks*: the mode owns the
/// confirmation, through `OcptConfirmDialog`, exactly as a slot's or a block's own deletion does.
///
/// **This is deliberately the day view's only representation of an event.** The day view draws no
/// marker of its own for one: unlike the week grid, it has no time canvas to mark — each slot card
/// carries its own list-shaped timetable rather than a shared one — so the bordered band hosting
/// this widget *is* how the day view shows what the day's events are. A reader looking for a
/// marker on the day view itself will not find one; the week grid's own full-width marker
/// (`OcptScheduleWeekGrid`) is the only agenda presentation that draws one, the strip and month
/// agendas being out of scope for this milestone.
class OcptScheduleDayEventsList extends StatelessWidget {
  /// The day's own live events, already ordered by hour.
  final List<OcptShootingDayEvent> events;

  /// Resolves an event's id to its own label, as currently held (a pending edit, or its stored
  /// value).
  final String Function(String eventId) eventLabelValueOf;

  /// Resolves an event's id to its own notes, as currently held (a pending edit, or its stored
  /// value).
  final String Function(String eventId) eventNotesValueOf;

  /// Called when the `+ Event` footer is clicked, or null while withheld (the footer then draws
  /// nothing).
  final VoidCallback? onEventAdded;

  /// Called with an event's id and its own new minute once its hour field commits, or null while
  /// withheld.
  final void Function(String eventId, int minute)? onEventMinuteChanged;

  /// Called with an event's id and its raw label text on every keystroke, or null while withheld.
  final void Function(String eventId, String rawValue)? onEventLabelChanged;

  /// Called with an event's id and its raw note text on every keystroke, or null while withheld.
  final void Function(String eventId, String rawValue)? onEventNotesChanged;

  /// Called with an event's id when its own remove control is clicked, or null while withheld —
  /// only ever asks, the confirmation being the mode's own job.
  final ValueChanged<String>? onEventDeletionRequested;

  /// Class constructor
  const OcptScheduleDayEventsList({
    super.key,
    required this.events,
    required this.eventLabelValueOf,
    required this.eventNotesValueOf,
    required this.onEventAdded,
    required this.onEventMinuteChanged,
    required this.onEventLabelChanged,
    required this.onEventNotesChanged,
    required this.onEventDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final event in events) _buildEventRow(context, event),
        if (onEventAdded != null)
          OutlinedButton.icon(
            onPressed: onEventAdded,
            icon: const Icon(Icons.add, size: 16),
            label: Text(tr.scheduleAddDayEventAction),
          ),
      ],
    );
  }

  /// One event's own row: its hour and label on one line, its note (when it has one, or is
  /// editable) indented under the label on the next.
  Widget _buildEventRow(BuildContext context, OcptShootingDayEvent event) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelValue = eventLabelValueOf(event.id);
    final notesValue = eventNotesValueOf(event.id);
    final onEventLabelChanged = this.onEventLabelChanged;
    final onEventNotesChanged = this.onEventNotesChanged;
    final onEventDeletionRequested = this.onEventDeletionRequested;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OcptScheduleMinuteField(
                key: ValueKey(event.id),
                minute: event.minute,
                isClearable: false,
                emptyHint: "—",
                onChanged: onEventMinuteChanged == null
                    ? null
                    : (value) => onEventMinuteChanged!(event.id, value ?? event.minute),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: onEventLabelChanged == null
                    ? Text(
                        labelValue.isEmpty ? tr.scheduleDayEventUnnamedLabel : labelValue,
                        style: theme.textTheme.bodySmall,
                      )
                    : _OcptScheduleDayEventLabelField(
                        key: ValueKey(event.id),
                        value: labelValue,
                        hintText: tr.scheduleDayEventLabelHint,
                        onChanged: (rawValue) => onEventLabelChanged(event.id, rawValue),
                      ),
              ),
              if (onEventDeletionRequested != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr.scheduleRemoveDayEventTooltip,
                  onPressed: () => onEventDeletionRequested(event.id),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 72, top: 2),
            child: onEventNotesChanged == null
                ? (notesValue.isEmpty
                      ? const SizedBox.shrink()
                      : Text(notesValue, style: theme.textTheme.bodySmall))
                : _OcptScheduleDayEventNoteField(
                    key: ValueKey(event.id),
                    value: notesValue,
                    hintText: tr.scheduleDayEventNotesHint,
                    onChanged: (rawValue) => onEventNotesChanged(event.id, rawValue),
                  ),
          ),
        ],
      ),
    );
  }
}

/// An event row's own single-line label field, following the same controller-sync idiom as
/// `_OcptScheduleSlotLabelField` (`ocpt_schedule_slot_card.dart`): [value] is the field's current
/// authoritative value, and the internal controller is only reset to it when it genuinely differs
/// from what the controller already holds, so the caret never jumps mid-typing.
class _OcptScheduleDayEventLabelField extends StatefulWidget {
  /// The field's current authoritative value.
  final String value;

  /// The hint shown while [value] is empty.
  final String hintText;

  /// Called with the field's raw text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const _OcptScheduleDayEventLabelField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_OcptScheduleDayEventLabelField> createState() => _OcptScheduleDayEventLabelFieldState();
}

/// The state of [_OcptScheduleDayEventLabelField]: owns the controller the class doc comment
/// explains.
class _OcptScheduleDayEventLabelFieldState extends State<_OcptScheduleDayEventLabelField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OcptScheduleDayEventLabelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: widget.onChanged,
    style: Theme.of(context).textTheme.bodySmall,
    decoration: InputDecoration(isDense: true, hintText: widget.hintText),
  );
}

/// An event row's own note field, below its hour and label line — [_OcptScheduleDayEventLabelField]'s
/// own controller-sync idiom, drawn as a body-sized field that grows with what is typed into it
/// rather than a single-line title, mirroring `_OcptScheduleSlotNoteField`.
class _OcptScheduleDayEventNoteField extends StatefulWidget {
  /// The field's current authoritative value.
  final String value;

  /// The hint shown while [value] is empty.
  final String hintText;

  /// Called with the field's raw text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const _OcptScheduleDayEventNoteField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_OcptScheduleDayEventNoteField> createState() => _OcptScheduleDayEventNoteFieldState();
}

/// The state of [_OcptScheduleDayEventNoteField]: owns the controller the class doc comment
/// explains.
class _OcptScheduleDayEventNoteFieldState extends State<_OcptScheduleDayEventNoteField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OcptScheduleDayEventNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: widget.onChanged,
    maxLines: null,
    style: Theme.of(context).textTheme.bodySmall,
    decoration: InputDecoration(isDense: true, hintText: widget.hintText),
  );
}
