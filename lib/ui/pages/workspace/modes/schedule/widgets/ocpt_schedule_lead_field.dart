// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The unit every lead time in this mode is expressed in, printed beside the figure in both of
/// [OcptScheduleLeadField]'s own states — deliberately not localized: `min` is the symbol, and it
/// is the same one in both UI languages.
const String _ocptScheduleMinutesUnit = "min";

/// How wide the typed figure's own box is, in logical pixels — the unit now sits outside it, so it
/// only has to hold three digits.
const double _ocptScheduleLeadFieldWidth = 56;

/// A compact field editing one of the schedule's own lead-time columns
/// (`shooting_day_groups.leadMinutes`, a crew or cast row's own `leadMinutes` override) — how many
/// minutes before the moment a person is needed they have to be there (ADR 0017).
///
/// Unlike `OcptScheduleMinuteField`, which reads and writes a **clock face**, this field's own
/// value is a **duration**: a plain count of minutes, parsed and printed with no `HH:mm` shape at
/// all. It otherwise mirrors that widget closely — the same commit-on-submit-or-focus-loss idiom,
/// and the same "never write the same value twice" `_lastReportedLeadMinutes` guard, since a
/// submission takes the focus off the field and would otherwise commit twice.
///
/// **Two shapes of caller**: a convocation row's own [leadMinutes] is nullable — null means "use my
/// group's own figure instead" (or zero, with none either), and [isClearable] is true so an empty
/// submission clears it back to that. [inheritedLeadMinutes] is what is shown, in a muted italic
/// style, while the field itself is empty — the row's own already-resolved
/// `OcptCrewConvocation.leadMinutes`/`OcptCastConvocation.leadMinutes` (ADR 0017), so "empty" reads
/// as *inherited* rather than *blank*. A group's own [leadMinutes] is never null and [isClearable]
/// is false: a group always carries a figure, and an empty submission simply reverts to it rather
/// than being accepted.
///
/// **A negative figure is refused rather than written**: `ocptComputeSlotConvocations` throws an
/// `ArgumentError` on a negative resolved lead (`lib/utils/ocpt_shooting_convocations.dart`,
/// ADR 0017), so this field reverts to its last valid text instead of ever reporting one.
class OcptScheduleLeadField extends StatefulWidget {
  /// This field's own currently held value, or null while unset (only possible when [isClearable]).
  final int? leadMinutes;

  /// The figure shown, muted and in italics, as long as [leadMinutes] is null — the group's own
  /// resolved figure (or the zero it falls back to with none), so an unset row still says what it
  /// is about to be convoked at rather than looking abandoned. Ignored while [leadMinutes] is set,
  /// and irrelevant when [isClearable] is false (that shape of caller is never null).
  final int? inheritedLeadMinutes;

  /// Called with the minutes just parsed once the field commits, or null when [isClearable] and the
  /// field was submitted empty; null itself while the field may not be written to (a project
  /// version being previewed read-only), which renders this as plain text.
  final ValueChanged<int?>? onChanged;

  /// Whether an empty submission clears [leadMinutes] to null. True for a convocation row's own
  /// lead (clearable back to "use the group's"); false for a group's own lead, which always carries
  /// a figure and reverts to it instead of accepting an empty submission.
  final bool isClearable;

  /// Class constructor
  const OcptScheduleLeadField({
    super.key,
    required this.leadMinutes,
    this.inheritedLeadMinutes,
    required this.onChanged,
    required this.isClearable,
  });

  @override
  State<OcptScheduleLeadField> createState() => _OcptScheduleLeadFieldState();
}

/// The state of [OcptScheduleLeadField]: the field's own controller and focus-loss commit.
class _OcptScheduleLeadFieldState extends State<OcptScheduleLeadField> {
  /// The field's own text controller, seeded from [OcptScheduleLeadField.leadMinutes].
  late final TextEditingController _controller = TextEditingController(text: _formattedLeadMinutes);

  /// The field's own focus node, committing the moment it loses focus.
  final FocusNode _focusNode = FocusNode();

  /// The value this field last reported — see `OcptScheduleMinuteField`'s own doc comment on why
  /// this, rather than [OcptScheduleLeadField.leadMinutes] itself, is what a fresh commit is
  /// compared against: a submission takes the focus off the field, which would otherwise commit the
  /// very same edit twice.
  late int? _lastReportedLeadMinutes = widget.leadMinutes;

  /// [OcptScheduleLeadField.leadMinutes] as plain digits, or the empty string while it is null.
  String get _formattedLeadMinutes => widget.leadMinutes == null ? "" : "${widget.leadMinutes}";

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant OcptScheduleLeadField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leadMinutes != widget.leadMinutes) {
      _lastReportedLeadMinutes = widget.leadMinutes;
      if (!_focusNode.hasFocus) {
        _controller.text = _formattedLeadMinutes;
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

  /// Commits the field's current text once it loses focus, mirroring `OcptScheduleMinuteField`'s
  /// own flush-on-focus-lost idiom.
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  /// Parses the field's current text and reports it, or reverts the field to
  /// [OcptScheduleLeadField.leadMinutes]'s own formatted reading when the text is neither empty nor
  /// a valid, non-negative figure.
  void _commit() {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (!widget.isClearable) {
        _controller.text = _formattedLeadMinutes;
      } else if (_lastReportedLeadMinutes != null) {
        _lastReportedLeadMinutes = null;
        onChanged(null);
      }
      return;
    }

    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) {
      _controller.text = _formattedLeadMinutes;
      return;
    }

    _controller.text = "$parsed";
    if (parsed != _lastReportedLeadMinutes) {
      _lastReportedLeadMinutes = parsed;
      onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onChanged = widget.onChanged;

    if (onChanged == null) {
      final ownValue = widget.leadMinutes;
      if (ownValue != null) {
        return Text("$ownValue $_ocptScheduleMinutesUnit", style: theme.textTheme.bodySmall);
      }

      final inherited = widget.inheritedLeadMinutes;
      return Text(
        inherited == null ? "—" : "$inherited $_ocptScheduleMinutesUnit",
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final inherited = widget.inheritedLeadMinutes;

    // The unit is a plain [Text] beside the field rather than the decoration's own `suffixText`:
    // Material only paints a suffix while the field has text or the focus, so a row reading its
    // group's figure — an empty field showing that figure as a hint — lost the `min` exactly when
    // the reader most needs to know what unit the number is in.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _ocptScheduleLeadFieldWidth,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onSubmitted: (_) => _commit(),
            keyboardType: TextInputType.number,
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              isDense: true,
              hintText: inherited == null ? null : "$inherited",
              hintStyle: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _ocptScheduleMinutesUnit,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
