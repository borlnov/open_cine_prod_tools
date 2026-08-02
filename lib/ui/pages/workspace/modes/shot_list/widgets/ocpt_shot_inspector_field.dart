// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// The number of lines a [OcptShotInspectorField.multiline] field is tall before it grows with
/// what is typed into it.
const int _multilineMinLines = 4;

/// One editable field row of the shot inspector: an uppercase, `onSurfaceVariant` label over a
/// themed text field, following the same visual idiom as the screenplay editor's own read-only
/// dock fields (a rounded, filled box) without being the same widget — the two production modes
/// stay independent of one another.
///
/// A field with a non-empty [suggestions] list shows an autocomplete overlay that
/// filters as the user types: a convenience over the project's own vocabulary, never a closed
/// list — typing a brand-new value always stays possible. A [multiline] field keeps its
/// suggestions, since the fields written as several lines (Framing & composition, Camera move,
/// Sound) are exactly the ones whose first words are worth reusing across a project. Built on
/// [RawAutocomplete] with an explicit [TextEditingController]/[FocusNode] of this widget's own
/// (rather than letting [RawAutocomplete] create its own internal ones, which would fight the
/// caret on every rebuild), so keeps the caret and the autocomplete overlay perfectly in step with
/// the shot list bloc's own debounce.
///
/// A field whose value has a grammar of its own (the estimated duration's `mm:ss`) additionally
/// gets [inputFormatters] keeping the characters that grammar has no room for out, a [hintText]
/// stating it while the field is empty, and an [errorText] its caller computes from what was
/// typed: this widget stays a plain text box and never reads a value it is bound to.
///
/// [value] is the field's current authoritative value — a pending edit still sitting in the
/// bloc's debounce, or the shot's own stored value otherwise. The internal controller is only
/// ever reset to it when [shotId] changes (the inspector now shows a different shot) or when
/// [value] genuinely differs from what the controller already holds (an edit landed, or a reload
/// changed the underlying data): a rebuild that changes for an unrelated reason (another field's
/// pending edit, a dock resize) never touches the controller, so the caret never jumps mid-typing.
class OcptShotInspectorField extends StatefulWidget {
  /// The id of the shot this field belongs to, used only to detect a shot switch (see the class
  /// doc comment).
  final String shotId;

  /// The field's label, upper-cased for display. An empty label renders no label row at all: the
  /// Director's notes and Location scouting sections use their own section title as the field's
  /// label and would otherwise show it twice.
  final String label;

  /// The field's current authoritative value, raw (not formatted for read-only display): an
  /// empty string for a missing value, never `ocptShotListEmptyValue`.
  final String value;

  /// The project-wide suggestions to filter as the user types, or null/empty for a field with
  /// none: only the free-text fields the service has a `distinct` query for ever get one.
  final List<String>? suggestions;

  /// Whether this field is written as several lines (Framing & composition, Camera move, Sound,
  /// Director's notes, Location scouting) instead of being a single line.
  final bool multiline;

  /// The greyed placeholder shown while the field is empty, or null for a field whose label says
  /// everything there is to say: the estimated duration's `mm:ss` is the only one so far.
  final String? hintText;

  /// The error shown under the field, or null while what it holds is fine. Computed by the caller
  /// (which is the one that knows how to read the field's own grammar) rather than by this widget,
  /// which stays a plain text box whatever it is bound to.
  final String? errorText;

  /// The formatters restricting what the field accepts, or null for a field taking any text at
  /// all: the estimated duration allows nothing but digits and its `:` separator, so a wrong
  /// character can never even be typed and [errorText] is only ever about the shape of what was.
  final List<TextInputFormatter>? inputFormatters;

  /// The width of the text box itself, or null for one filling the dock's width as every field
  /// does by default: a field whose values are only ever a couple of characters long (the shot
  /// size's abbreviation) says so by being that wide. The label above it keeps the full width
  /// whatever this holds, so a narrow box never wraps its own label.
  final double? fieldWidth;

  /// Called with the field's raw text on every keystroke, and when a suggestion is picked, or null
  /// while the field may not be written to (a project version being previewed read-only): it then
  /// reads its value out — selectable, so it can still be copied — with no autocomplete overlay of
  /// its own, since there is nothing left to complete.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const OcptShotInspectorField({
    super.key,
    required this.shotId,
    required this.label,
    required this.value,
    this.suggestions,
    this.multiline = false,
    this.hintText,
    this.errorText,
    this.inputFormatters,
    this.fieldWidth,
    required this.onChanged,
  });

  @override
  State<OcptShotInspectorField> createState() => _OcptShotInspectorFieldState();
}

/// The state of [OcptShotInspectorField]: owns the controller and focus node the class doc
/// comment explains the reasoning for.
class _OcptShotInspectorFieldState extends State<OcptShotInspectorField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  /// The field's own focus node, so [RawAutocomplete] never has to create (and therefore churn) one
  /// of its own across rebuilds.
  late final FocusNode _focusNode = FocusNode();

  /// The [OcptShotInspectorField.shotId] the controller was last synced against, so a shot switch
  /// is detected even when the two shots happen to share the same field value.
  late String _trackedShotId = widget.shotId;

  @override
  void didUpdateWidget(covariant OcptShotInspectorField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.shotId != _trackedShotId || widget.value != _controller.text) {
      _controller.text = widget.value;
      _trackedShotId = widget.shotId;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
          ],
          _buildSizedField(context),
        ],
      ),
    );
  }

  /// [_buildField], kept to [OcptShotInspectorField.fieldWidth] and aligned to the left of the
  /// panel when the caller asked for a narrow box, left to fill the dock's width otherwise.
  Widget _buildSizedField(BuildContext context) {
    final fieldWidth = widget.fieldWidth;
    if (fieldWidth == null) {
      return _buildField(context);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: fieldWidth, child: _buildField(context)),
    );
  }

  /// Builds the field itself: a plain [TextField] when there is nothing to suggest (or nothing to
  /// type at all), or one bound through [RawAutocomplete] otherwise.
  Widget _buildField(BuildContext context) {
    final suggestions = widget.suggestions;
    final onChanged = widget.onChanged;
    if (onChanged == null || suggestions == null || suggestions.isEmpty) {
      return _textField(_controller, _focusNode);
    }

    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return const Iterable<String>.empty();
        }
        return suggestions.where((option) => option.toLowerCase().contains(query));
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
          _textField(controller, focusNode),
      optionsViewBuilder: (context, onSelected, options) => _OcptShotInspectorFieldOptions(
        options: options,
        onSelected: onSelected,
      ),
    );
  }

  /// The text field itself, given the controller and focus node to bind it to: this widget's own
  /// ones when there is nothing to suggest, the very same ones handed back by [RawAutocomplete]
  /// otherwise (it is given them, see the class doc comment).
  ///
  /// A [OcptShotInspectorField.multiline] field grows from [_multilineMinLines] lines upwards
  /// instead of scrolling a single line sideways, which is what makes the fields written as a
  /// sentence readable in a dock this narrow.
  Widget _textField(TextEditingController controller, FocusNode focusNode) => TextField(
    controller: controller,
    focusNode: focusNode,
    readOnly: widget.onChanged == null,
    onChanged: widget.onChanged,
    maxLines: widget.multiline ? null : 1,
    minLines: widget.multiline ? _multilineMinLines : 1,
    style: Theme.of(context).textTheme.bodySmall,
    inputFormatters: widget.inputFormatters,
    decoration: InputDecoration(
      isDense: true,
      hintText: widget.hintText,
      errorText: widget.errorText,
    ),
  );
}

/// The autocomplete overlay [OcptShotInspectorField] shows under a field while it has suggestions
/// worth showing: a themed surface matching the app's popup menus, rather than
/// [RawAutocomplete]'s own unstyled default.
class _OcptShotInspectorFieldOptions extends StatelessWidget {
  /// The suggestions currently matching what was typed, in the order [RawAutocomplete] resolved
  /// them.
  final Iterable<String> options;

  /// Called with the option picked.
  final ValueChanged<String> onSelected;

  /// Class constructor
  const _OcptShotInspectorFieldOptions({required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 3,
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 220),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            children: [
              for (final option in options)
                InkWell(
                  onTap: () => onSelected(option),
                  mouseCursor: ocptClickableCursor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(option, style: theme.textTheme.bodySmall),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One read-only field row of the shot inspector and metadata panels: an uppercase,
/// `onSurfaceVariant` label over a rounded `surfaceContainer` value box.
///
/// Deliberately not imported from the screenplay editor's own `OcptEditorDockField`, which
/// follows the exact same idiom: the two production modes stay independent of one another.
class OcptShotInspectorReadOnlyField extends StatelessWidget {
  /// The field's label, upper-cased for display.
  final String label;

  /// The field's value, already formatted for display (a dash for a missing value, not an empty
  /// string).
  final String value;

  /// Class constructor
  const OcptShotInspectorReadOnlyField({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(ocptRadiusSmall),
            ),
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
