// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_cards_layout_delegate.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_connector_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_note_card.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_note_editing.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes.dart';
import 'package:super_editor/super_editor.dart';

/// Where the marker of a note sits in the notes margin, in the coordinates of the scrolled
/// content: independent of the scroll, so it is measured again only when the layout changes.
class _NoteAnchor extends Equatable {
  /// The top of the line holding the marker.
  final double top;

  /// The height of the line holding the marker.
  final double height;

  /// The x of the right edge of the marker, in the margin's own coordinates.
  final double markerRight;

  /// Class constructor.
  const _NoteAnchor({required this.top, required this.height, required this.markerRight});

  /// Get the properties the equality of the anchor reads.
  @override
  List<Object?> get props => [top, height, markerRight];
}

/// The clipper keeping the cards of the margin to the height of the visible area, and letting the
/// shift of a selected card and its shadow spill out sideways.
class _VerticalViewportClipper extends CustomClipper<Rect> {
  /// How far the clip extends past each side of the margin, in logical pixels.
  static const double _sideOverflow = 48;

  /// Class constructor.
  const _VerticalViewportClipper();

  /// Get the area to keep: the whole height of [size], and a little more than its width.
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-_sideOverflow, 0, size.width + _sideOverflow, size.height);

  /// Tell whether the clip differs from the one of [oldClipper], which it never does.
  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

/// The column of cards to the right of the page of the styled editor, one per note, each aligned
/// with the line of its marker, and the line joining the selected note's marker to its card.
///
/// It is laid out over the full height of the visible area, so its coordinates are the ones of the
/// viewport. It reads where each marker is from the document layout once the frame is done
/// (when the notes, the size or the zoom changed), and then follows the scroll by itself.
class OcptStyledNotesMargin extends StatefulWidget {
  /// The width of a card, in logical pixels: UI chrome, never scaled by the editor's zoom.
  static const double cardWidth = 280;

  /// The gap between the page and the column, in logical pixels.
  static const double gap = 24;

  /// The space kept free beyond the page and the column, in logical pixels.
  static const double outerMargin = 16;

  /// How far a selected card is shifted towards the page, in logical pixels.
  static const double selectedShift = 12;

  /// The notes the column shows, and the selection it shares with the text.
  final OcptStyledNotes notes;

  /// The writes the cards make to the notes.
  final OcptStyledNoteEditing editing;

  /// The key of the editor's document layout, which tells where each marker is.
  final GlobalKey documentLayoutKey;

  /// The scroll controller of the editor, which the cards follow.
  final ScrollController scrollController;

  /// Get the width a column takes beside the page: the gap and a card.
  static double get reservedWidth => gap + cardWidth;

  /// Class constructor.
  const OcptStyledNotesMargin({
    super.key,
    required this.notes,
    required this.editing,
    required this.documentLayoutKey,
    required this.scrollController,
  });

  /// Create the [_OcptStyledNotesMarginState] holding the anchors read from the layout.
  @override
  State<OcptStyledNotesMargin> createState() => _OcptStyledNotesMarginState();

  /// Tell whether the column has room: [hasNotes], no compact surface, and [availableWidth] holding
  /// [contentWidth] (the page, or the narrowest text column) with the column and its outer margin.
  static bool fits({
    required bool hasNotes,
    required bool isCompact,
    required double availableWidth,
    required double contentWidth,
  }) => hasNotes && !isCompact && availableWidth >= contentWidth + reservedWidth + outerMargin;
}

/// The cards of the notes margin and the line to the selected one, placed over the full height of
/// the margin and following [scrollController].
class _NotesContent extends StatelessWidget {
  /// The notes the cards belong to.
  final OcptStyledNotes notes;

  /// The writes the cards make to the notes.
  final OcptStyledNoteEditing editing;

  /// The notes to show a card for, in document order.
  final List<OcptNoteEntry> entries;

  /// Where the marker of each of [entries] is, by note identifier.
  final Map<String, _NoteAnchor> anchors;

  /// The identifier of the selected note, or null when none is.
  final String? selectedId;

  /// The scroll controller of the editor, which the cards follow.
  final ScrollController scrollController;

  /// Class constructor.
  const _NotesContent({
    required this.notes,
    required this.editing,
    required this.entries,
    required this.anchors,
    required this.selectedId,
    required this.scrollController,
  });

  /// Build the cards, and the line joining the selected note's marker to its card.
  @override
  Widget build(BuildContext context) {
    final scrollOffset = scrollController.hasClients ? scrollController.offset : 0.0;
    final selectedIndex = entries.indexWhere((entry) => entry.note.id == selectedId);
    final selectedAnchor = selectedIndex < 0 ? null : anchors[entries[selectedIndex].note.id];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (selectedAnchor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: OcptNoteConnectorPainter(
                  color: Theme.of(context).colorScheme.primary,
                  from: Offset(
                    selectedAnchor.markerRight,
                    selectedAnchor.top + selectedAnchor.height / 2 - scrollOffset,
                  ),
                  to: Offset(
                    -OcptStyledNotesMargin.selectedShift,
                    selectedAnchor.top + selectedAnchor.height / 2 - scrollOffset,
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: ClipRect(
            clipper: const _VerticalViewportClipper(),
            child: CustomMultiChildLayout(
              delegate: OcptNoteCardsLayoutDelegate(
                anchors: [for (final entry in entries) anchors[entry.note.id]!.top],
                selectedIndex: selectedIndex < 0 ? null : selectedIndex,
                scrollOffset: scrollOffset,
                cardWidth: OcptStyledNotesMargin.cardWidth,
                selectedShift: OcptStyledNotesMargin.selectedShift,
              ),
              children: [
                for (var index = 0; index < entries.length; index++)
                  LayoutId(
                    key: ValueKey(entries[index].note.id),
                    id: index,
                    child: OcptStyledNoteCard(
                      entry: entries[index],
                      notes: notes,
                      editing: editing,
                      isSelected: index == selectedIndex,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The state of [OcptStyledNotesMargin]: reads the anchors after each frame that may have moved a
/// marker, and builds the cards.
class _OcptStyledNotesMarginState extends State<OcptStyledNotesMargin> {
  /// The anchor of each note, by note identifier.
  Map<String, _NoteAnchor> _anchors = const {};

  /// Whether a measure is already waiting for the end of the frame.
  bool _isMeasureScheduled = false;

  /// Measure the markers once the first frame is out.
  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  /// Measure the markers again: the layout may have moved them.
  @override
  void didUpdateWidget(covariant OcptStyledNotesMargin oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  /// Build the cards and the line, over the full height of the margin.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _scheduleMeasure();
      return ValueListenableBuilder<List<OcptNoteEntry>>(
        valueListenable: widget.notes.entries,
        builder: (context, entries, child) {
          _scheduleMeasure();
          return ValueListenableBuilder<String?>(
            valueListenable: widget.notes.selectedId,
            builder: (context, selectedId, child) => ListenableBuilder(
              listenable: widget.scrollController,
              builder: (context, child) => _NotesContent(
                notes: widget.notes,
                editing: widget.editing,
                entries: entries.where((entry) => _anchors.containsKey(entry.note.id)).toList(),
                anchors: _anchors,
                selectedId: selectedId,
                scrollController: widget.scrollController,
              ),
            ),
          );
        },
      );
    },
  );

  /// Ask for the markers to be measured at the end of the frame, once only however often it is
  /// asked for.
  void _scheduleMeasure() {
    if (_isMeasureScheduled) {
      return;
    }

    _isMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Read where each marker is from the document layout, and rebuild when any of them moved.
  void _measure() {
    _isMeasureScheduled = false;
    if (!mounted) {
      return;
    }

    final layout = widget.documentLayoutKey.currentState as DocumentLayout?;
    final marginBox = context.findRenderObject();
    if (layout == null || marginBox is! RenderBox || !marginBox.attached || !marginBox.hasSize) {
      return;
    }

    final scrollOffset = widget.scrollController.hasClients ? widget.scrollController.offset : 0.0;
    Offset toMargin(Offset layoutPoint) =>
        layout.getAncestorOffsetFromDocumentOffset(layoutPoint, marginBox);

    final anchors = <String, _NoteAnchor>{};
    for (final entry in widget.notes.entries.value) {
      final line = layout.getRectForPosition(entry.position);
      if (line == null) {
        continue;
      }

      final marker = layout.getRectForSelection(
        entry.position,
        DocumentPosition(
          nodeId: entry.nodeId,
          nodePosition: TextNodePosition(offset: entry.offset + 1),
        ),
      );
      final top = toMargin(line.topLeft).dy;
      anchors[entry.note.id] = _NoteAnchor(
        top: top + scrollOffset,
        height: toMargin(line.bottomLeft).dy - top,
        markerRight: toMargin((marker ?? line).topRight).dx,
      );
    }

    if (!mapEquals(anchors, _anchors)) {
      setState(() => _anchors = anchors);
    }
  }
}
