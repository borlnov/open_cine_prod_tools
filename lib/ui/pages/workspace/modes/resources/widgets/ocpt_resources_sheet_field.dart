// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The number of lines a [OcptResourcesSheetField.multiline] field is tall before it grows with
/// what is typed into it.
const int _multilineMinLines = 3;

/// One editable text field of a resources sheet, whichever tab's sheet it is: an optional
/// uppercase, `onSurfaceVariant` label over a themed text field, following the same idiom as the
/// shot inspector's own `OcptShotInspectorField` without being the same widget — the two
/// production modes stay independent of one another (see `OcptShotInspectorReadOnlyField`'s own
/// doc comment for the same reasoning).
///
/// A field may **flag** what it holds without refusing it, through [errorTextOf]: nothing here
/// ever blocks a write, since a sheet autosaves as it is typed.
///
/// [value] is the field's current authoritative value — a pending edit still sitting in
/// `OcptResourcesState.pendingFieldEdits` (or `pendingRoleFieldEdits`), or the record's own stored
/// value otherwise, exactly as `OcptShotListMode._fieldValueOf` resolves a shot's own fields. The
/// internal controller is only ever reset to it when [ownerId] changes (the sheet now shows a
/// different record) or when [value] genuinely differs from what the controller already holds (an
/// edit landed, or a reload changed the underlying data): a rebuild for an unrelated reason
/// (another field's pending edit, a dock resize) never touches the controller, so the caret never
/// jumps mid-typing.
class OcptResourcesSheetField extends StatefulWidget {
  /// The id of the record this field belongs to — a person on the people tab, a role on the roles
  /// tab — used only to detect a switch from one to another (see the class doc comment).
  final String ownerId;

  /// The field's label, upper-cased for display. An empty label renders no label row at all: the
  /// header's name fields use their own placeholder instead of a label.
  final String label;

  /// The field's current authoritative value, raw (not formatted for read-only display): an empty
  /// string for a missing value, never `ocptResourcesEmptyValue`.
  final String value;

  /// Whether this field is written as several lines (the notes cards, the legal hours callout,
  /// a role's casting notes) instead of being a single line.
  final bool multiline;

  /// The greyed placeholder shown while the field is empty, or null for a field whose label says
  /// everything there is to say.
  final String? hintText;

  /// The message to show under the field for the value it currently holds, or null when there is
  /// nothing to say about it; null itself for a field that is never checked.
  ///
  /// The message is only ever shown **while the field does not have the focus**: the sheet writes
  /// as it is typed, and flagging a half-typed address on every keystroke would make the field
  /// red for as long as it takes to enter a correct value. It is a remark on what is now there,
  /// not a gate — the value is written either way.
  final String? Function(String value)? errorTextOf;

  /// The text style overriding this field's default `bodySmall`, used by a sheet header's own
  /// name fields to read as a title rather than as an ordinary field.
  final TextStyle? textStyle;

  /// Called with the field's raw text on every keystroke, or null while the field may not be
  /// written to (a project version being previewed read-only): it then reads its value out —
  /// selectable, so it can still be copied — with no reaction to typing.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const OcptResourcesSheetField({
    super.key,
    required this.ownerId,
    required this.label,
    required this.value,
    this.multiline = false,
    this.hintText,
    this.errorTextOf,
    this.textStyle,
    required this.onChanged,
  });

  @override
  State<OcptResourcesSheetField> createState() => _OcptResourcesSheetFieldState();
}

/// The state of [OcptResourcesSheetField]: owns the controller the class doc comment explains the
/// reasoning for.
class _OcptResourcesSheetFieldState extends State<OcptResourcesSheetField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  /// The [OcptResourcesSheetField.ownerId] the controller was last synced against, so a switch
  /// from one record to another is detected even when the two happen to share the same field
  /// value.
  late String _trackedOwnerId = widget.ownerId;

  /// The field's own focus node, watched so the check of
  /// [OcptResourcesSheetField.errorTextOf] is only shown once typing has stopped.
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  /// Rebuilds so the error message appears the moment the field loses the focus, and disappears
  /// again the moment it regains it.
  void _onFocusChanged() {
    if (widget.errorTextOf != null) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant OcptResourcesSheetField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.ownerId != _trackedOwnerId || widget.value != _controller.text) {
      _controller.text = widget.value;
      _trackedOwnerId = widget.ownerId;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The message to show under the field right now: what [OcptResourcesSheetField.errorTextOf] says
  /// about the current value, or null while the field has the focus or is never checked.
  String? _resolveErrorText() {
    final errorTextOf = widget.errorTextOf;
    if (errorTextOf == null || _focusNode.hasFocus) {
      return null;
    }
    return errorTextOf(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
        ],
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          readOnly: widget.onChanged == null,
          onChanged: widget.onChanged,
          maxLines: widget.multiline ? null : 1,
          minLines: widget.multiline ? _multilineMinLines : 1,
          style: widget.textStyle ?? theme.textTheme.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            errorText: _resolveErrorText(),
          ),
        ),
      ],
    );
  }
}
