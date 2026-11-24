// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_matches.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_note_editing.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_card.dart';

/// The card of one note of the styled editor, wired to the notes and to the writes made to them:
/// the card of the margin column, and the one of the popover under a marker, which are the same.
///
/// It follows the matches of the find/replace query by itself, so the owner of the card does not
/// have to be rebuilt for them.
class OcptStyledNoteCard extends StatelessWidget {
  /// The note the card shows.
  final OcptNoteEntry entry;

  /// The notes of the document, and the selected one.
  final OcptStyledNotes notes;

  /// The writes the card makes to the note.
  final OcptStyledNoteEditing editing;

  /// Whether the card is the one of the selected note.
  final bool isSelected;

  /// Whether leaving the card, with Enter or Escape, also drops the selection of its note, which
  /// closes the popover it is shown in.
  final bool closesOnLeave;

  /// Class constructor.
  const OcptStyledNoteCard({
    super.key,
    required this.entry,
    required this.notes,
    required this.editing,
    required this.isSelected,
    this.closesOnLeave = false,
  });

  /// Build the card of the note.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Map<String, OcptNoteMatches>>(
    valueListenable: notes.matches,
    builder: (context, matches, child) => OcptNoteCard(
      text: entry.note.text,
      isSelected: isSelected,
      onTap: () => notes.select(entry.note.id),
      onChanged: (text) => editing.changeText(entry.note.id, text),
      onRemoveRequested: () => editing.removeNoteById(entry.note.id),
      onLeaveRequested: _leave,
      onUndoRequested: editing.undo,
      onRedoRequested: editing.redo,
      onFocusLost: () => editing.focusLost(entry.note.id),
      allowsBlankLines: entry.standsAlone,
      matches: matches[entry.note.id],
      takesFocus: notes.takesFocusOnSelect,
    ),
  );

  /// Give the focus back to the text, and drop the selection when the card closes on it.
  void _leave() {
    editing.leave(entry.note.id);
    if (closesOnLeave) {
      notes.clearSelection();
    }
  }
}
