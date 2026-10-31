// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// A slot card's own note field, drawn as a body-sized field that grows with what is typed into it:
/// [value] is the field's current authoritative value, and the internal controller is only reset to
/// it when it genuinely differs from what the controller already holds, so the caret never jumps
/// mid-typing.
class OcptScheduleSlotNoteField extends StatefulWidget {
  /// The field's current authoritative value.
  final String value;

  /// The hint shown while [value] is empty.
  final String hintText;

  /// Called with the field's raw text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const OcptScheduleSlotNoteField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<OcptScheduleSlotNoteField> createState() => _OcptScheduleSlotNoteFieldState();
}

/// The state of [OcptScheduleSlotNoteField]: owns the controller the class doc comment explains.
class _OcptScheduleSlotNoteFieldState extends State<OcptScheduleSlotNoteField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant OcptScheduleSlotNoteField oldWidget) {
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
