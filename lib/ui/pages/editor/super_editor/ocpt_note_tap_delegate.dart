// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes.dart';
import 'package:super_editor/super_editor.dart';

/// The content tap delegate of the styled editor that makes a note's marker clickable: a tap on it
/// selects the note and is not handled any further, and a tap anywhere else in the text drops the
/// selection and goes on as usual.
class OcptNoteTapDelegate extends ContentTapDelegate {
  /// The distance from the edge of a marker inside which a tap does not count as being on it, in
  /// logical pixels: a tap at the very edge is one placing the caret next to the marker.
  static const double _edgeInset = 2;

  /// The notes whose selection the delegate drives.
  final OcptStyledNotes notes;

  /// Class constructor.
  OcptNoteTapDelegate({required this.notes});

  /// Get the click cursor over a note's marker, or null over anything else.
  @override
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) {
    final nodePosition = hoverPosition.nodePosition;
    if (nodePosition is! TextNodePosition) {
      return null;
    }

    final hasNote = notes.entries.value.any(
      (entry) =>
          entry.nodeId == hoverPosition.nodeId &&
          (entry.offset == nodePosition.offset || entry.offset + 1 == nodePosition.offset),
    );
    return hasNote ? SystemMouseCursors.click : null;
  }

  /// Select the note under the tap and halt, or drop the selection and let the tap go on.
  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    final noteId = _noteIdAt(details);
    if (noteId == null) {
      notes.clearSelection();
      return TapHandlingInstruction.continueHandling;
    }

    notes.select(noteId);
    return TapHandlingInstruction.halt;
  }

  /// Find the identifier of the note whose marker the tap in [details] landed on, or null.
  String? _noteIdAt(DocumentTapDetails details) {
    final layout = details.documentLayout;
    final position = layout.getDocumentPositionNearestToOffset(details.layoutOffset);
    final nodePosition = position?.nodePosition;
    if (position == null || nodePosition is! TextNodePosition) {
      return null;
    }

    for (final entry in notes.entries.value) {
      if (entry.nodeId != position.nodeId ||
          (entry.offset != nodePosition.offset && entry.offset + 1 != nodePosition.offset)) {
        continue;
      }

      final rect = layout.getRectForSelection(
        entry.position,
        DocumentPosition(
          nodeId: entry.nodeId,
          nodePosition: TextNodePosition(offset: entry.offset + 1),
        ),
      );
      if (rect != null && rect.deflate(_edgeInset).contains(details.layoutOffset)) {
        return entry.note.id;
      }
    }

    return null;
  }
}
