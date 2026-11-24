// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// The small speech bubble standing in a line of the styled editor for a note
/// (`OcptFountainNote`), drawn in place of its `[[text]]`.
///
/// The page is white in every theme, so its colours are fixed like the rest of the paper styling:
/// the app's accent on a light tint of itself. Its size follows the text it sits in, 18 by 16
/// logical pixels at the base font size and as much more as the editor is zoomed.
class OcptFountainNoteMarker extends StatelessWidget {
  /// The accent colour of the app, the one of the marker's icon.
  static const Color accentColor = Color(0xFF6C5CE7);

  /// The opacity of [accentColor] making the tint behind the icon.
  static const double tintOpacity = 0.14;

  /// The width of the marker at the base font size.
  static const double baseWidth = 18;

  /// The height of the marker at the base font size.
  static const double baseHeight = 16;

  /// The size of the icon at the base font size.
  static const double baseIconSize = 12;

  /// The corner radius of the tint at the base font size.
  static const double baseRadius = 4;

  /// The font size of the text the marker sits in, which it is scaled by.
  final double fontSize;

  /// The label read out for the marker, empty for none.
  final String semanticLabel;

  /// Class constructor.
  const OcptFountainNoteMarker({super.key, required this.fontSize, this.semanticLabel = ""});

  /// Build the marker.
  @override
  Widget build(BuildContext context) {
    final scale = fontSize / OcptEditorPreviewLayout.baseFontSize;

    return Semantics(
      label: semanticLabel.isEmpty ? null : semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          width: baseWidth * scale,
          height: baseHeight * scale,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: tintOpacity),
            borderRadius: BorderRadius.circular(baseRadius * scale),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.chat_bubble_outline, size: baseIconSize * scale, color: accentColor),
        ),
      ),
    );
  }
}
