// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// The raw Fountain source editor: a full-height, multi-line text field typeset in Courier
/// Prime, themed with the app (so it keeps the studio dark background in dark mode, unlike the
/// preview's simulated paper).
///
/// The [controller], [scrollController], [focusNode] and [undoController] are owned by the page's
/// State (the documented RFL1 exception: an editing surface is exactly what StatefulWidget-held
/// controllers are for), which is also where text and caret changes are turned into bloc events.
class OcptEditorSourceField extends StatelessWidget {
  /// The editor's font size, in logical pixels.
  static const double fontSize = 14;

  /// The editor's line height factor, applied to [fontSize].
  ///
  /// It's public so the page can estimate a line's vertical scroll position when jumping to a
  /// scene.
  static const double lineHeightFactor = 1.5;

  /// The controller holding the live source text and selection.
  final TextEditingController controller;

  /// The controller of the editor's vertical scroll, used when jumping to a scene.
  final ScrollController scrollController;

  /// The editor's focus node, focused back when jumping to a scene.
  final FocusNode focusNode;

  /// The controller of the undo history [EditableText] keeps for this field on its own — this
  /// only hands the page a handle on it, so the `⋮` menu's `Undo`/`Redo` entries can read whether
  /// there is anything to take back and drive it, exactly as they drive the styled editor's own
  /// history in the other mode. Ctrl+Z and Ctrl+Shift+Z/Ctrl+Y reach that same history through
  /// Flutter's own `DefaultTextEditingShortcuts` whether this is handed in or not.
  final UndoHistoryController undoController;

  /// Class constructor
  const OcptEditorSourceField({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
    required this.undoController,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    scrollController: scrollController,
    focusNode: focusNode,
    undoController: undoController,
    maxLines: null,
    expands: true,
    keyboardType: TextInputType.multiline,
    textAlignVertical: TextAlignVertical.top,
    style: const TextStyle(
      fontFamily: OcptEditorPreviewLayout.fontFamily,
      fontSize: fontSize,
      height: lineHeightFactor,
    ),
    decoration: const InputDecoration(
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  );
}
