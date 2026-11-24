// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The card showing the text of one note in the margin of the styled editor: a header naming it
/// and the text of the note below, with its line breaks.
///
/// Its look comes from the theme's card (shape and radius), only recoloured: a raised surface, and
/// while [isSelected] a primary outline, a lighter surface and a soft shadow. Where the card is
/// placed, and the shift a selected one has towards the page, is up to its parent.
class OcptNoteCard extends StatelessWidget {
  /// The width of the outline of a selected card, in logical pixels.
  static const double selectedBorderWidth = 1.5;

  /// The elevation, hence the shadow, of a selected card.
  static const double selectedElevation = 6;

  /// The size of the speech bubble in the header, in logical pixels.
  static const double _iconSize = 12;

  /// The padding between the edge of the card and its content, in logical pixels.
  static const double _padding = 12;

  /// The text of the note.
  final String text;

  /// Whether the card is the one of the selected note.
  final bool isSelected;

  /// Called when the card is tapped, or null to make it inert.
  final VoidCallback? onTap;

  /// Class constructor.
  const OcptNoteCard({super.key, required this.text, required this.isSelected, this.onTap});

  /// Build the card.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cardShape = theme.cardTheme.shape;

    return Card(
      margin: EdgeInsets.zero,
      color: isSelected ? colors.surfaceContainerHigh : colors.surfaceContainer,
      elevation: isSelected ? selectedElevation : null,
      shape: isSelected && cardShape is RoundedRectangleBorder
          ? cardShape.copyWith(
              side: BorderSide(color: colors.primary, width: selectedBorderWidth),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: _iconSize, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    Tr.of(context).editorNoteMarkerLabel.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
