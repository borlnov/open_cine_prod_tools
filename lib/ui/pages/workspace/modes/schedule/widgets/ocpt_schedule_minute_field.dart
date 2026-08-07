// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';

/// A compact `HH:mm` field editing one of the schedule's own minute-from-midnight columns
/// (`shooting_slots.anchorMinute`, a block's own anchor), shared by the slot cards, the timetable
/// and the day inspector rather than a bespoke `TextField` at each call site — and, with a null
/// [OcptScheduleMinuteField.onChanged], the way every **computed** hour is read out too.
///
/// Unlike the mode's own free-text fields (`OcptScheduleField`), a minute is never typed into the
/// debounce: it commits the moment the field is submitted or loses focus, exactly as every other
/// discrete pick this mode writes immediately.
///
/// **Crossing midnight**: [minute] may already exceed 1440 (or fall below zero) for a night slot —
/// see `OcptShootingSlotsTable`'s own doc comment. A fresh clock reading typed here is placed on
/// the same calendar day [minute] already was on (its own `minute ~/ 1440` multiple, computed via
/// Dart's floored `%`), so re-typing a night wrap time round-trips correctly; there is no "+1 day"
/// toggle in this milestone to move a value onto a *different* day than it already read from, which
/// is a deliberate scope cut for M1.
///
/// A block's own anchor is typed here too: the pin captures the chain's current position, and this
/// field is what then names the minute the anchor actually exists for — a meal break's legal start,
/// a flight, a location lost at dusk (ADR 0015). The day-offset rule above is what makes that safe
/// on a night shoot: an anchor pinned past midnight was captured at a minute beyond 1440, so
/// retyping its clock reading keeps it in the small hours it was already in rather than dragging it
/// back to the morning of the same day.
class OcptScheduleMinuteField extends StatefulWidget {
  /// The minute currently held, or null while unset.
  final int? minute;

  /// Called with the minute just parsed once the field commits, or null when [isClearable] and the
  /// field was submitted empty; null itself while the field may not be written to (a project
  /// version being previewed read-only), which renders this as plain text.
  final ValueChanged<int?>? onChanged;

  /// Whether an empty submission clears [minute] to null. False for a slot's own crew band, which
  /// is never unset once the slot exists; true for every per-row override (a crew member's own call
  /// time, a role's own arrival…), which is meant to be clearable back to "use the slot's own".
  final bool isClearable;

  /// The hint shown in the field while [minute] and its own text are both empty, or the read-only
  /// placeholder shown in its place — the caller's own reading of "unset" (an em dash, at every
  /// call site so far), so this widget never invents its own wording for it.
  final String emptyHint;

  /// Class constructor
  const OcptScheduleMinuteField({
    super.key,
    required this.minute,
    required this.onChanged,
    required this.isClearable,
    required this.emptyHint,
  });

  @override
  State<OcptScheduleMinuteField> createState() => _OcptScheduleMinuteFieldState();
}

/// The state of [OcptScheduleMinuteField]: the field's own controller and focus-loss commit.
class _OcptScheduleMinuteFieldState extends State<OcptScheduleMinuteField> {
  /// The field's own text controller, seeded from [OcptScheduleMinuteField.minute].
  late final TextEditingController _controller = TextEditingController(text: _formattedMinute);

  /// The field's own focus node, committing the moment it loses focus.
  final FocusNode _focusNode = FocusNode();

  /// The value this field last reported, which is **not** always [OcptScheduleMinuteField.minute]:
  /// submitting the field takes the focus off it, so a single edit commits twice — once on the
  /// action, once on the focus loss — and the write the first one starts has not come back through
  /// the bloc by the time the second runs. Comparing against what was last reported, rather than
  /// against the value the widget still carries, is what keeps one edit to one write. It also means
  /// tabbing through a field without touching it writes nothing at all, which matters here because
  /// a minute reaches the database immediately rather than riding the mode's own debounce.
  late int? _lastReportedMinute = widget.minute;

  /// [OcptScheduleMinuteField.minute] formatted as `HH:mm`, or the empty string while it is null.
  String get _formattedMinute =>
      widget.minute == null ? "" : ocptFormatDayMinute(widget.minute!);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant OcptScheduleMinuteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minute != widget.minute) {
      _lastReportedMinute = widget.minute;
      if (!_focusNode.hasFocus) {
        _controller.text = _formattedMinute;
      }
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Commits the field's current text once it loses focus, mirroring the resources sheets' own
  /// flush-on-focus-lost idiom.
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  /// Parses the field's current text and reports it, or reverts the field to
  /// [OcptScheduleMinuteField.minute]'s own formatted reading when the text is neither empty nor a
  /// valid clock reading.
  void _commit() {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (!widget.isClearable) {
        _controller.text = _formattedMinute;
      } else if (_lastReportedMinute != null) {
        _lastReportedMinute = null;
        onChanged(null);
      }
      return;
    }

    final parsed = ocptParseDayMinute(text);
    if (parsed == null) {
      _controller.text = _formattedMinute;
      return;
    }

    final currentMinute = widget.minute;
    final dayOffset = currentMinute == null ? 0 : currentMinute - (currentMinute % 1440);
    final resolved = dayOffset + parsed;
    _controller.text = ocptFormatDayMinute(resolved);

    if (resolved != _lastReportedMinute) {
      _lastReportedMinute = resolved;
      onChanged(resolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onChanged = widget.onChanged;

    if (onChanged == null) {
      return Text(
        widget.minute == null ? widget.emptyHint : ocptFormatDayMinute(widget.minute!),
        style: theme.textTheme.bodySmall,
      );
    }

    return SizedBox(
      width: 64,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onSubmitted: (_) => _commit(),
        style: theme.textTheme.bodySmall,
        decoration: InputDecoration(isDense: true, hintText: widget.emptyHint),
      ),
    );
  }
}
