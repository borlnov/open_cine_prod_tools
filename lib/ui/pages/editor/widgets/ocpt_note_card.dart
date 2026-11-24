// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_matches.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_card_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_highlight_spans.dart';

/// The card showing the text of one note in the margin of the styled editor: a header naming it
/// and the text of the note below, with its line breaks.
///
/// While the card [isSelected] and [onChanged] is given, the text is a field the note is written
/// in, and a button under it removes the note: both are withheld when their callback is null, which
/// leaves the card a read-only one.
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
  static const double _padding = 8;

  /// The inset of the header and of the read-only text, which puts them in line with the text of
  /// the field, padded by as much inside its outline.
  static const EdgeInsetsDirectional _textInset = EdgeInsetsDirectional.symmetric(
    horizontal: OcptNoteCardField.contentInset,
  );

  /// The text of the note.
  final String text;

  /// Whether the card is the one of the selected note.
  final bool isSelected;

  /// Called when the card is tapped, or null to make it inert.
  final VoidCallback? onTap;

  /// Called with the new text of the note when the writer edits it, or null for a read-only card.
  final ValueChanged<String>? onChanged;

  /// Called when the writer asked to remove the note, or null to withhold the button.
  final VoidCallback? onRemoveRequested;

  /// Called when the writer is done with the note and the focus belongs back to the text.
  final VoidCallback? onLeaveRequested;

  /// Called when the writer asked to undo while the field has the focus.
  final VoidCallback? onUndoRequested;

  /// Called when the writer asked to redo while the field has the focus.
  final VoidCallback? onRedoRequested;

  /// Called when the field of the card lost the focus it had.
  final VoidCallback? onFocusLost;

  /// Whether the note may hold a blank line: see [OcptNoteCardField.allowsBlankLines].
  final bool allowsBlankLines;

  /// The matches of the find/replace query inside the text, painted over it, or null for none.
  final OcptNoteMatches? matches;

  /// Whether the field takes the focus when it appears, which it does unless the search selected
  /// the note.
  final bool takesFocus;

  /// Class constructor.
  const OcptNoteCard({
    super.key,
    required this.text,
    required this.isSelected,
    this.onTap,
    this.onChanged,
    this.onRemoveRequested,
    this.onLeaveRequested,
    this.onUndoRequested,
    this.onRedoRequested,
    this.onFocusLost,
    this.allowsBlankLines = true,
    this.matches,
    this.takesFocus = true,
  });

  /// Build the card.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cardShape = theme.cardTheme.shape;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface);
    final onChanged = this.onChanged;
    final onRemoveRequested = this.onRemoveRequested;

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
        onTap: isSelected ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: _textInset,
                child: Row(
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
              ),
              const SizedBox(height: 6),
              if (isSelected && onChanged != null)
                OcptNoteCardField(
                  text: text,
                  hint: Tr.of(context).editorNoteFieldHint,
                  style: textStyle,
                  onChanged: onChanged,
                  onLeaveRequested: onLeaveRequested ?? () {},
                  onUndoRequested: onUndoRequested ?? () {},
                  onRedoRequested: onRedoRequested ?? () {},
                  onFocusLost: onFocusLost ?? () {},
                  allowsBlankLines: allowsBlankLines,
                  matches: matches,
                  takesFocus: takesFocus,
                )
              else
                Padding(
                  padding: _textInset,
                  child: Text.rich(OcptNoteHighlightSpans.build(text, textStyle, matches)),
                ),
              if (isSelected && onRemoveRequested != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: onRemoveRequested,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(Tr.of(context).editorContextMenuRemoveNoteAction),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
