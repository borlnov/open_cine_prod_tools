// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_matches.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_tap_delegate.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_inline_runs.dart';
import 'package:super_editor/super_editor.dart';

/// One note of the styled editor's document, with the place its marker holds in it.
final class OcptNoteEntry extends Equatable {
  /// The identifier of the node holding the note's marker.
  final String nodeId;

  /// The offset of the note's marker in the text of its node.
  final int offset;

  /// The note itself.
  final OcptFountainNote note;

  /// Whether the node of the note holds nothing but notes and whitespace, so that the note may
  /// hold a blank line: amid other text, a blank line would split that text in two paragraphs.
  final bool standsAlone;

  /// Get the position of the note's marker in the document.
  DocumentPosition get position => DocumentPosition(
    nodeId: nodeId,
    nodePosition: TextNodePosition(offset: offset),
  );

  /// Class constructor.
  const OcptNoteEntry({
    required this.nodeId,
    required this.offset,
    required this.note,
    this.standsAlone = false,
  });

  /// Get the properties the equality of the entry reads.
  @override
  List<Object?> get props => [nodeId, offset, note, standsAlone];
}

/// The view state of the notes of the styled editor: which notes the document holds, in document
/// order, and which one is selected.
///
/// The selected note is pure view state of the editing surface, like the composer's selection:
/// the marker of the note in the text, its card in the margin and the line joining them all follow
/// [selectedId], and nothing of it reaches the document or the bloc. The selection is dropped as
/// soon as the document no longer holds the selected note, or when a tap lands elsewhere in the
/// text.
final class OcptStyledNotes {
  /// The identifier of the selected note, or null when none is.
  final ValueNotifier<String?> selectedId = ValueNotifier(null);

  /// The notes of the document, in document order.
  final ValueNotifier<List<OcptNoteEntry>> entries = ValueNotifier(const []);

  /// Whether the margin column of cards is shown beside the page, which is what makes a selected
  /// note open in the column rather than in a popover under its marker.
  final ValueNotifier<bool> hasMargin = ValueNotifier(false);

  /// The matches of the find/replace query inside the notes, by note identifier. A note holding
  /// none has no entry.
  final ValueNotifier<Map<String, OcptNoteMatches>> matches = ValueNotifier(const {});

  /// The key of the marker of the selected note, which the popover under it is placed against.
  final GlobalKey selectedMarkerKey = GlobalKey(debugLabel: "selectedNoteMarker");

  /// Resolves the document the notes are read from, which the editor replaces on a rebuild.
  final Document Function() _documentOf;

  /// Whether the selected note was selected by the search, which must not take the focus from the
  /// find field.
  bool _isSelectionQuiet = false;

  /// Whether the notifiers are released.
  bool _isDisposed = false;

  /// Tell whether the field of a card taking the selection takes the focus too, which it does
  /// unless the search selected the note.
  bool get takesFocusOnSelect => !_isSelectionQuiet;

  /// Get the tap delegate factories to hand to `SuperEditor`: the one selecting a note on a tap
  /// on its marker, and the one launching a link.
  List<SuperEditorContentTapDelegateFactory> get tapDelegateFactories => [
    superEditorLaunchLinkTapHandlerFactory,
    (editContext) => OcptNoteTapDelegate(notes: this),
  ];

  /// Class constructor.
  OcptStyledNotes({required this._documentOf});

  /// Read the notes from the document again, and drop the selection if its note is gone.
  void refresh() {
    final fresh = <OcptNoteEntry>[
      for (final node in _documentOf())
        if (node is TextNode)
          for (final placeholder in node.text.placeholders.entries)
            if (placeholder.value is OcptFountainNote)
              OcptNoteEntry(
                nodeId: node.id,
                offset: placeholder.key,
                note: placeholder.value as OcptFountainNote,
                standsAlone: OcptWysiwygInlineRuns.holdsOnlyNotes(node.text),
              ),
    ];

    if (!listEquals(fresh, entries.value)) {
      entries.value = fresh;
    }

    final selected = selectedId.value;
    if (selected != null && !fresh.any((entry) => entry.note.id == selected)) {
      selectedId.value = null;
    }
  }

  /// Find the note with the identifier [id], or null when the document holds none.
  OcptNoteEntry? entryOf(String id) {
    for (final entry in entries.value) {
      if (entry.note.id == id) {
        return entry;
      }
    }
    return null;
  }

  /// Select the note with the identifier [id]. Its card takes the focus, unless [takesFocus] is
  /// false, as for a note the search navigates to while the writer types in the find field.
  void select(String id, {bool takesFocus = true}) {
    _isSelectionQuiet = !takesFocus;
    selectedId.value = id;
  }

  /// Select no note at all.
  void clearSelection() {
    _isSelectionQuiet = false;
    selectedId.value = null;
  }

  /// Select no note, when the one selected is so only because the search navigated to it.
  void clearQuietSelection() {
    if (_isSelectionQuiet) {
      clearSelection();
    }
  }

  /// Tell whether the margin column is [isShown] now, which takes effect once the frame is built:
  /// it is told from a build.
  void reportMargin({required bool isShown}) {
    if (hasMargin.value == isShown) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        hasMargin.value = isShown;
      }
    });
  }

  /// Set the matches of the find/replace query inside the notes.
  void setMatches(Map<String, OcptNoteMatches> value) {
    if (!mapEquals(matches.value, value)) {
      matches.value = value;
    }
  }

  /// Release the notifiers.
  void dispose() {
    _isDisposed = true;
    selectedId.dispose();
    entries.dispose();
    hasMargin.dispose();
    matches.dispose();
  }
}
