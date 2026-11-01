// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// One editable field, mirroring `OcptResourcesSheetField`'s own controller idiom without depending
/// on that mode's widget — unchanged from `OcptBudgetPosteInspector`'s own private field widget.
class OcptBudgetInlineField extends StatefulWidget {
  /// The field's label.
  final String label;

  /// The field's current authoritative value.
  final String value;

  /// The greyed placeholder shown while the field is empty, or null.
  final String? hintText;

  /// A helper sentence drawn under the field, standing whatever the field holds, or null — the
  /// poste estimate-to-complete field's own sentence saying what typing a figure changes.
  final String? helperText;

  /// Chrome shown after the typed text, or null.
  final String? suffixText;

  /// Whether this field is written as several lines.
  final bool multiline;

  /// An inline error message, or null while the field's own value stands as typed. Never blocks nor
  /// reverts the typed value — it is drawn beside it, exactly the way a duplicate poste code is
  /// signalled rather than blocked (`docs/architecture/budget.md`).
  final String? errorText;

  /// Called with the field's raw text on every keystroke, or null while it may not be written to.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const OcptBudgetInlineField({
    super.key,
    required this.label,
    required this.value,
    this.hintText,
    this.helperText,
    this.suffixText,
    this.multiline = false,
    this.errorText,
    required this.onChanged,
  });

  @override
  State<OcptBudgetInlineField> createState() => _OcptBudgetInlineFieldState();
}

/// The state of [OcptBudgetInlineField]: owns the controller, kept in sync with the widget's own
/// authoritative value exactly as `OcptResourcesSheetField` keeps its own.
class _OcptBudgetInlineFieldState extends State<OcptBudgetInlineField> {
  /// The field's own text editing controller.
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant OcptBudgetInlineField oldWidget) {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: hasError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          readOnly: widget.onChanged == null,
          onChanged: widget.onChanged,
          maxLines: widget.multiline ? null : 1,
          minLines: widget.multiline ? 3 : 1,
          style: theme.textTheme.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            helperText: widget.helperText,
            helperMaxLines: 3,
            suffixText: widget.suffixText,
            errorText: widget.errorText,
          ),
        ),
      ],
    );
  }
}
