// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The search field at the top of the resources mode's left dock, under `OcptResourcesTabBar`,
/// shown only while the toolbar's search toggle has it open.
///
/// Autofocuses the moment it is mounted, which only happens when the toolbar's toggle opens the
/// field — the mode never builds this widget while search is closed — never on an unrelated
/// rebuild of the surrounding panel. It carries its own clear (×) button, distinct from closing the
/// search altogether: `_handleClear` only blanks the query, the field itself stays open and
/// focused.
///
/// [query] is the field's current authoritative value — `OcptResourcesState.searchQuery` —
/// mirroring how `OcptResourcesSheetField` resolves its own `value`: the controller is only reset
/// to it when it genuinely differs from what the controller already holds (the bloc cleared it on
/// a tab change or on closing the search), never on an unrelated rebuild, so the caret never jumps
/// mid-typing.
class OcptResourcesSearchField extends StatefulWidget {
  /// The field's current authoritative value.
  final String query;

  /// Called with the field's raw text on every keystroke, and by the clear button with an empty
  /// string.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const OcptResourcesSearchField({super.key, required this.query, required this.onChanged});

  @override
  State<OcptResourcesSearchField> createState() => _OcptResourcesSearchFieldState();
}

/// The state of [OcptResourcesSearchField]: owns the controller the class doc comment explains the
/// reasoning for.
class _OcptResourcesSearchFieldState extends State<OcptResourcesSearchField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(covariant OcptResourcesSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _controller,
        autofocus: true,
        onChanged: widget.onChanged,
        style: Theme.of(context).textTheme.bodySmall,
        decoration: InputDecoration(
          isDense: true,
          hintText: tr.resourcesSearchHint,
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: widget.query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: tr.resourcesSearchClearTooltip,
                  onPressed: _handleClear,
                ),
        ),
      ),
    );
  }

  /// Blanks the field and reports the empty query, without closing the search itself.
  void _handleClear() {
    _controller.clear();
    widget.onChanged("");
  }
}
