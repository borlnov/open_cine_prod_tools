// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';

/// The toolbar button toggling the styled/raw editing mode.
///
/// It shows the persisted `OcptEditorState.mode` rather than the mode actually live: this toggle is
/// the user's own desktop preference, left untouched by a phone width forcing the styled editor
/// onto the screen — it keeps stating (and toggling) what will apply once the window widens back
/// out, not what happens to be rendered right this moment.
class OcptEditorModeToggle extends StatelessWidget {
  /// The persisted editing mode.
  final OcptEditorMode mode;

  /// Switches to the other mode.
  final VoidCallback onPressed;

  /// Class constructor
  const OcptEditorModeToggle({required this.mode, required this.onPressed, super.key});

  /// Build the editor mode toggle as an [IconButton].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return IconButton(
      icon: Icon(mode == OcptEditorMode.styled ? Icons.code : Icons.style, size: 20),
      tooltip: mode == OcptEditorMode.styled
          ? tr.editorSwitchToRawModeTooltip
          : tr.editorSwitchToStyledModeTooltip,
      onPressed: onPressed,
    );
  }
}
