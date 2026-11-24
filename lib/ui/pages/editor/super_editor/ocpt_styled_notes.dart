// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_tap_delegate.dart';
import 'package:super_editor/super_editor.dart';

/// One note of the styled editor's document, with the place its marker holds in it.
final class OcptNoteEntry extends Equatable {
  /// The identifier of the node holding the note's marker.
  final String nodeId;

  /// The offset of the note's marker in the text of its node.
  final int offset;

  /// The note itself.
  final OcptFountainNote note;

  /// Get the position of the note's marker in the document.
  DocumentPosition get position => DocumentPosition(
    nodeId: nodeId,
    nodePosition: TextNodePosition(offset: offset),
  );

  /// Class constructor.
  const OcptNoteEntry({required this.nodeId, required this.offset, required this.note});

  /// Get the properties the equality of the entry reads.
  @override
  List<Object?> get props => [nodeId, offset, note];
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

  /// Resolves the document the notes are read from, which the editor replaces on a rebuild.
  final Document Function() _documentOf;

  /// Get the tap delegate factories to hand to `SuperEditor`: the one selecting a note on a tap
  /// on its marker, and the one launching a link.
  List<SuperEditorContentTapDelegateFactory> get tapDelegateFactories => [
    superEditorLaunchLinkTapHandlerFactory,
    (editContext) => OcptNoteTapDelegate(notes: this),
  ];

  /// Class constructor.
  OcptStyledNotes({required Document Function() documentOf}) : _documentOf = documentOf;

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

  /// Select the note with the identifier [id].
  // ignore: use_setters_to_change_properties
  void select(String id) => selectedId.value = id;

  /// Select no note at all.
  void clearSelection() => selectedId.value = null;

  /// Release the notifiers.
  void dispose() {
    selectedId.dispose();
    entries.dispose();
  }
}
