// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_matches.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// The small speech bubble standing in a line of the styled editor for a note
/// (`OcptFountainNote`), drawn in place of its `[[text]]`.
///
/// The page is white in every theme, so its colours are fixed like the rest of the paper styling:
/// the app's accent on a light tint of itself. Its size follows the text it sits in, 18 by 16
/// logical pixels at the base font size and as much more as the editor is zoomed. While its note is
/// the selected one, it is drawn solid: the accent filled, with a white icon. While the find/replace
/// query matches inside its note, it is drawn over the match highlight colours, stronger for the
/// current match.
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

  /// The identifier of the note the marker stands for, which tells whether it is the selected one.
  final String? noteId;

  /// The notes the marker follows the selection and the search matches of, or null for a marker
  /// that is never selected and never hints at a match.
  final OcptStyledNotes? notes;

  /// Class constructor.
  const OcptFountainNoteMarker({
    super.key,
    required this.fontSize,
    this.semanticLabel = "",
    this.noteId,
    this.notes,
  });

  /// Build the marker, following the selection and the matches when there are some to follow.
  @override
  Widget build(BuildContext context) {
    final notes = this.notes;
    if (notes == null) {
      return _NoteBubble(fontSize: fontSize, semanticLabel: semanticLabel, isSelected: false);
    }

    return ListenableBuilder(
      listenable: Listenable.merge([notes.selectedId, notes.matches]),
      builder: (context, child) {
        final isSelected = noteId != null && notes.selectedId.value == noteId;
        final bubble = _NoteBubble(
          fontSize: fontSize,
          semanticLabel: semanticLabel,
          isSelected: isSelected,
          matches: notes.matches.value[noteId],
        );
        return isSelected ? KeyedSubtree(key: notes.selectedMarkerKey, child: bubble) : bubble;
      },
    );
  }
}

/// The drawing of [OcptFountainNoteMarker]: the bubble, tinted, or solid when [isSelected].
class _NoteBubble extends StatelessWidget {
  /// The width of the outline of a bubble holding a match, at the base font size.
  static const double _matchBorderWidth = 1.5;

  /// The font size of the text the bubble sits in, which it is scaled by.
  final double fontSize;

  /// The label read out for the bubble, empty for none.
  final String semanticLabel;

  /// Whether the bubble is drawn solid.
  final bool isSelected;

  /// The matches of the search inside the note of the bubble, or null when it holds none.
  final OcptNoteMatches? matches;

  /// Class constructor.
  const _NoteBubble({
    required this.fontSize,
    required this.semanticLabel,
    required this.isSelected,
    this.matches,
  });

  /// Build the bubble.
  @override
  Widget build(BuildContext context) {
    final scale = fontSize / OcptEditorPreviewLayout.baseFontSize;
    const baseWidth = OcptFountainNoteMarker.baseWidth;
    const baseHeight = OcptFountainNoteMarker.baseHeight;
    const accentColor = OcptFountainNoteMarker.accentColor;
    final matches = this.matches;
    final base = isSelected
        ? accentColor
        : accentColor.withValues(alpha: OcptFountainNoteMarker.tintOpacity);

    return Semantics(
      label: semanticLabel.isEmpty ? null : semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          width: baseWidth * scale,
          height: baseHeight * scale,
          decoration: BoxDecoration(
            color: matches == null
                ? base
                : Color.alphaBlend(
                    matches.hasCurrent
                        ? ocptEditorSearchCurrentMatchColor
                        : ocptEditorSearchMatchColor,
                    base,
                  ),
            border: matches == null
                ? null
                : Border.all(
                    color: matches.hasCurrent
                        ? ocptEditorSearchCurrentMatchColor
                        : ocptEditorSearchMatchColor,
                    width: _matchBorderWidth * scale,
                  ),
            borderRadius: BorderRadius.circular(OcptFountainNoteMarker.baseRadius * scale),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.chat_bubble_outline,
            size: OcptFountainNoteMarker.baseIconSize * scale,
            color: isSelected ? Colors.white : accentColor,
          ),
        ),
      ),
    );
  }
}
