// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_history.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes.dart';
import 'package:super_editor/super_editor.dart';

/// The writes to the notes of the styled editor, made from outside the text: from the card of a
/// note in the margin, and from the right-click menu's Insert note and Remove note.
///
/// It owns no state of the document: the document, the editor and the composer are resolved
/// through callbacks at call time, since the styled editor replaces all three whenever its text is
/// rebuilt from outside. What it does to a note is always one `Editor.execute`, so one undo step,
/// and the edits of one note from its card, from its creation to the moment the writer leaves
/// it, are grouped into one (see `OcptNoteEditMergePolicy`).
final class OcptStyledNoteEditing {
  /// The notes of the document, and the selected one.
  final OcptStyledNotes notes;

  /// Resolves the document the notes are written in.
  final Document Function() _documentOf;

  /// Resolves the editor executing the writes.
  final Editor Function() _editorOf;

  /// Resolves the composer holding the selection.
  final MutableDocumentComposer Function() _composerOf;

  /// The focus node of the styled editor, which the writer's keystrokes go back to.
  final FocusNode _editorFocusNode;

  /// The history the edits are grouped in.
  final OcptStyledHistory _history;

  /// Whether the owning widget is still mounted.
  final bool Function() _isMounted;

  /// The identifier of the note that was selected before the last change of the selection.
  String? _previousSelectedId;

  /// Tell whether a note can be inserted at the selection.
  bool get canInsertNote =>
      OcptFountainNoteActions.insertRequests(_documentOf(), _composerOf().selection) != null;

  /// Tell whether a note can be removed: the one next to the caret, the one the selection holds,
  /// or the selected one.
  bool get canRemoveNote =>
      OcptFountainNoteActions.removeRequests(
        _documentOf(),
        _composerOf().selection,
        selectedNoteId: notes.selectedId.value,
      ) !=
      null;

  /// Class constructor. It starts to watch the selection of [notes], so as to remove a note left
  /// empty when the writer moves to another.
  OcptStyledNoteEditing({
    required this.notes,
    required this._documentOf,
    required this._editorOf,
    required this._composerOf,
    required this._editorFocusNode,
    required this._history,
    required this._isMounted,
  }) {
    notes.selectedId.addListener(_onSelectionChanged);
  }

  /// Insert an empty note at the selection, select it and give the focus to its card, in one undo
  /// step. Does nothing where a note cannot be inserted.
  ///
  /// When the margin has no room for the card, the note is only inserted and selected.
  void insertNote() {
    final note = OcptFountainNote.create("");
    final requests = OcptFountainNoteActions.insertRequests(
      _documentOf(),
      _composerOf().selection,
      note: note,
    );
    if (requests == null) {
      return;
    }

    _history.runNoteEdit(note.id, () => _editorOf().execute(requests));
    notes.select(note.id);
  }

  /// Remove the note next to the caret, the one the selection holds, or the selected one, in one
  /// undo step, and give the focus back to the editor.
  void removeNote() {
    final requests = OcptFountainNoteActions.removeRequests(
      _documentOf(),
      _composerOf().selection,
      selectedNoteId: notes.selectedId.value,
    );
    if (requests != null) {
      _history.endNoteSession();
      _editorOf().execute(requests);
    }
    _editorFocusNode.requestFocus();
  }

  /// Remove the note [noteId], from the button of its card, in one undo step of its own, and give
  /// the focus back to the editor.
  void removeNoteById(String noteId) {
    final requests = OcptFountainNoteActions.removeNoteRequests(_documentOf(), noteId);
    if (requests != null) {
      _history.endNoteSession();
      _editorOf().execute(requests);
    }
    _editorFocusNode.requestFocus();
  }

  /// Replace the text of the note [noteId] with [text], keeping its identifier. The successive
  /// changes of one note merge into one undo step.
  void changeText(String noteId, String text) {
    final entry = notes.entryOf(noteId);
    if (entry == null || entry.note.text == text) {
      return;
    }

    final requests = OcptFountainNoteActions.changeTextRequests(_documentOf(), noteId, text);
    if (requests != null) {
      _history.runNoteEdit(noteId, () => _editorOf().execute(requests));
    }
  }

  /// Give the focus back to the text of the editor, the caret just after the marker of the note
  /// [noteId].
  void leave(String noteId) {
    final entry = notes.entryOf(noteId);
    if (entry != null) {
      _editorOf().execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: entry.nodeId,
              nodePosition: TextNodePosition(offset: entry.offset + 1),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
    }
    _editorFocusNode.requestFocus();
  }

  /// Take back the writer's last gesture, from the field of a card.
  void undo() {
    _history.undo();
    _afterHistoryChange();
  }

  /// Put back the last undone gesture, from the field of a card.
  void redo() {
    _history.redo();
    _afterHistoryChange();
  }

  /// End the session of edits of the note [noteId], whose field lost the focus, after removing the
  /// note when it was left empty.
  void focusLost(String noteId) => _finish(noteId);

  /// Give the focus back to the editor when the note the field of a card belonged to is gone.
  void _afterHistoryChange() {
    if (_isMounted() && notes.selectedId.value == null) {
      _editorFocusNode.requestFocus();
    }
  }

  /// Remove the note that was selected before, when it was left empty.
  void _onSelectionChanged() {
    final previous = _previousSelectedId;
    _previousSelectedId = notes.selectedId.value;
    if (previous != null && previous != _previousSelectedId) {
      _finish(previous);
    }
  }

  /// Be done with the note [noteId] once the gesture that left it is over: remove it when its text
  /// is empty, in the undo step that created it when the writer has done nothing else in between,
  /// and end the session of edits.
  ///
  /// It waits so that a tap which put the caret somewhere in the text has set it before the note
  /// disappears, the selection then being carried through the removal.
  void _finish(String noteId) {
    scheduleMicrotask(() {
      final entry = notes.entryOf(noteId);
      if (_isMounted() && entry != null && entry.note.text.trim().isEmpty) {
        final requests = OcptFountainNoteActions.removeNoteRequests(
          _documentOf(),
          noteId,
          movesCaret: false,
        );
        if (requests != null) {
          _history.runNoteEdit(noteId, () => _editorOf().execute(requests));
        }
      }
      _history.endNoteSession();
    });
  }

  /// Stop watching the selection.
  void dispose() => notes.selectedId.removeListener(_onSelectionChanged);
}
