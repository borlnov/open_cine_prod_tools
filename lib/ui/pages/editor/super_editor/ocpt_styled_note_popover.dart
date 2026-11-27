// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_popover_layout_delegate.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_note_card.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_note_editing.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes_margin.dart';

/// The popover a note opens in, under its marker, while the margin column has no room: the card
/// of the selected note with a pointer to its marker, over the editor.
///
/// It is the card of the column, and writes to the note the same way. It closes when the writer
/// clicks outside it while typing in it, and on Enter and Escape, which give the focus back to the
/// text with the caret after the marker; it also gives way to the column when that appears. It
/// has no close button of its own.
///
/// It wraps [child], the area it keeps inside, and shows through an [OverlayPortal] so that
/// nothing clips it.
class OcptStyledNotePopover extends StatefulWidget {
  /// The notes of the document, and the selected one.
  final OcptStyledNotes notes;

  /// The writes the card makes to the note.
  final OcptStyledNoteEditing editing;

  /// The scroll controller of the editor, which the popover follows.
  final ScrollController scrollController;

  /// The area the popover stays inside.
  final Widget child;

  /// Class constructor.
  const OcptStyledNotePopover({
    super.key,
    required this.notes,
    required this.editing,
    required this.scrollController,
    required this.child,
  });

  /// Create the [_OcptStyledNotePopoverState] holding the overlay.
  @override
  State<OcptStyledNotePopover> createState() => _OcptStyledNotePopoverState();
}

/// The state of [OcptStyledNotePopover]: the overlay the popover is shown in, and the key of the
/// area it stays inside.
class _OcptStyledNotePopoverState extends State<OcptStyledNotePopover> {
  /// Shows the popover in the overlay.
  final OverlayPortalController _overlay = OverlayPortalController();

  /// The key of the area the popover stays inside.
  final GlobalKey _areaKey = GlobalKey(debugLabel: "notePopoverArea");

  /// Show the overlay once the first frame is out. The popover itself builds nothing while no
  /// note is open.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _overlay.show();
      }
    });
  }

  /// Build the area, with the popover over it.
  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _overlay,
    overlayChildBuilder: (context) => Positioned.fill(
      child: _NotePopoverContent(
        notes: widget.notes,
        editing: widget.editing,
        scrollController: widget.scrollController,
        areaKey: _areaKey,
      ),
    ),
    child: KeyedSubtree(key: _areaKey, child: widget.child),
  );
}

/// The popover in the overlay: measures where the marker of the selected note is, and places the
/// card against it.
class _NotePopoverContent extends StatefulWidget {
  /// The notes of the document, and the selected one.
  final OcptStyledNotes notes;

  /// The writes the card makes to the note.
  final OcptStyledNoteEditing editing;

  /// The scroll controller of the editor, which the popover follows.
  final ScrollController scrollController;

  /// The key of the area the popover stays inside.
  final GlobalKey areaKey;

  /// Class constructor.
  const _NotePopoverContent({
    required this.notes,
    required this.editing,
    required this.scrollController,
    required this.areaKey,
  });

  /// Create the [_NotePopoverContentState] holding the measure.
  @override
  State<_NotePopoverContent> createState() => _NotePopoverContentState();
}

/// The state of [_NotePopoverContent].
class _NotePopoverContentState extends State<_NotePopoverContent> {
  /// The group of the regions a click lands inside of, for the popover not to see them as outside.
  final Object _regionGroup = Object();

  /// The focus node telling whether the writer is typing in the card.
  final FocusNode _cardFocus = FocusNode(
    debugLabel: "notePopoverCard",
    skipTraversal: true,
    canRequestFocus: false,
  );

  /// Where the marker and the area are, in the coordinates of the popover, or null until measured.
  ({Rect anchor, Rect bounds})? _measure;

  /// Whether a measure is already waiting for the end of the frame.
  bool _isMeasureScheduled = false;

  /// Follow what moves the marker, and measure it once the first frame is out.
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scheduleMeasure);
    _scheduleMeasure();
  }

  /// Follow the scroll controller the editor now has.
  @override
  void didUpdateWidget(covariant _NotePopoverContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_scheduleMeasure);
      widget.scrollController.addListener(_scheduleMeasure);
    }
  }

  /// Build the card with its pointer when a note is open and the column is not there.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.notes.selectedId,
      widget.notes.entries,
      widget.notes.hasMargin,
    ]),
    builder: (context, child) {
      _scheduleMeasure();
      final selectedId = widget.notes.selectedId.value;
      final entry = selectedId == null || widget.notes.hasMargin.value
          ? null
          : widget.notes.entryOf(selectedId);
      final measure = _measure;
      if (entry == null || measure == null || !measure.bounds.overlaps(measure.anchor)) {
        return const SizedBox.shrink();
      }

      final colors = Theme.of(context).colorScheme;
      return CustomMultiChildLayout(
        delegate: OcptNotePopoverLayoutDelegate(
          anchor: measure.anchor,
          bounds: measure.bounds,
          cardWidth: OcptStyledNotesMargin.cardWidth,
        ),
        children: [
          LayoutId(
            id: OcptNotePopoverPart.card,
            child: TapRegion(
              groupId: _regionGroup,
              onTapOutside: (event) {
                if (_cardFocus.hasFocus) {
                  widget.notes.clearSelection();
                }
              },
              child: Focus(
                focusNode: _cardFocus,
                child: OcptStyledNoteCard(
                  key: ValueKey(entry.note.id),
                  entry: entry,
                  notes: widget.notes,
                  editing: widget.editing,
                  isSelected: true,
                  closesOnLeave: true,
                ),
              ),
            ),
          ),
          for (final part in [OcptNotePopoverPart.pointerUp, OcptNotePopoverPart.pointerDown])
            LayoutId(
              id: part,
              child: TapRegion(
                groupId: _regionGroup,
                child: CustomPaint(
                  painter: _PointerPainter(
                    fill: colors.surfaceContainerHigh,
                    outline: colors.primary,
                    pointsUp: part == OcptNotePopoverPart.pointerUp,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  /// Ask for the marker to be measured at the end of the frame, once only however often it is
  /// asked for.
  void _scheduleMeasure() {
    if (_isMeasureScheduled) {
      return;
    }

    _isMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasureScheduled = false;
      if (!mounted) {
        return;
      }

      final measure = _measureNow();
      if (measure != _measure) {
        setState(() => _measure = measure);
      }
    });
  }

  /// Read where the marker of the selected note and the area are, or null when there is no marker
  /// to read.
  ({Rect anchor, Rect bounds})? _measureNow() {
    final own = context.findRenderObject();
    final marker = widget.notes.selectedMarkerKey.currentContext?.findRenderObject();
    final area = widget.areaKey.currentContext?.findRenderObject();
    if (own is! RenderBox ||
        marker is! RenderBox ||
        area is! RenderBox ||
        !own.hasSize ||
        !marker.attached ||
        !marker.hasSize ||
        !area.attached ||
        !area.hasSize) {
      return null;
    }

    Rect rectOf(RenderBox box) =>
        MatrixUtils.transformRect(box.getTransformTo(own), Offset.zero & box.size);
    return (anchor: rectOf(marker), bounds: rectOf(area));
  }

  /// Stop following the scroll and release the focus node.
  @override
  void dispose() {
    widget.scrollController.removeListener(_scheduleMeasure);
    _cardFocus.dispose();
    super.dispose();
  }
}

/// The pointer of the popover: a small triangle joining the card to the marker.
class _PointerPainter extends CustomPainter {
  /// The width of the line along the two sides of the pointer, in logical pixels.
  static const double _strokeWidth = 1.5;

  /// The colour filling the pointer, the one of the card.
  final Color fill;

  /// The colour of the two sides of the pointer, the one of the outline of the card.
  final Color outline;

  /// Whether the pointer points up, at a marker above the card.
  final bool pointsUp;

  /// Class constructor.
  const _PointerPainter({required this.fill, required this.outline, required this.pointsUp});

  /// Paint the triangle, with its tip at the top or at the bottom of [size].
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final tipY = pointsUp ? 0.0 : size.height;
    final baseY = pointsUp ? size.height : 0.0;
    final path = Path()
      ..moveTo(0, baseY)
      ..lineTo(size.width / 2, tipY)
      ..lineTo(size.width, baseY);
    canvas
      ..drawPath(Path.from(path)..close(), Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth,
      );
  }

  /// Tell whether the pointer must be painted again for [oldDelegate].
  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      outline != oldDelegate.outline ||
      pointsUp != oldDelegate.pointsUp;
}
