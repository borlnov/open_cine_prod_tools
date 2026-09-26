// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_annotation_painter.dart';

/// The distance, in logical pixels, a drag must travel before [OcptStoryboardAnnotationOverlay]
/// treats it as an arrow rather than an accidental jitter on what was meant to be a tap.
const double _minDragDistance = 6;

/// The distance, in logical pixels, a tap may land from a mark's own point (a label's anchor, or
/// an arrow's shaft) and still select it.
const double _hitTestRadius = 14;

/// The board's annotation layer, drawn over an `OcptStoryboardPanelFrame`'s image: always paints
/// [annotations] (a read, kept even under a read-only preview), and — only while [activeTool] is
/// non-null — turns into a live gesture surface: a drag draws an arrow of [activeTool]'s own kind,
/// a click with the label tool places one and a click on an existing mark selects it
/// (`docs/plans/storyboard.md`, §4.2).
///
/// [activeTool] is null for every panel but the one the mode has already narrowed both the tool
/// and read-only status down to (`OcptStoryboardPanelStrip`'s own doc comment): this widget itself
/// only ever asks "is a tool on for *this* frame right now", never re-derives selection or
/// read-only from anywhere else. While [activeTool] is null this widget mounts no gesture
/// detector at all, so a tap on the frame falls through to `OcptStoryboardPanelFrame`'s own
/// `InkWell` exactly as before this layer existed — M3's scroll/reorder and panel-select are
/// untouched.
class OcptStoryboardAnnotationOverlay extends StatefulWidget {
  /// The panel's own marks, in draw order.
  final List<OcptStoryboardAnnotation> annotations;

  /// The id of the currently selected mark, or null while none is.
  final String? selectedAnnotationId;

  /// The tool currently on for this exact frame, or null while gestures are withheld (no tool
  /// picked, another panel is selected, or the mode is showing a read-only preview).
  final OcptStoryboardAnnotationTool? activeTool;

  /// Called with the new mark's kind and its normalised tail/head once a drag finishes drawing an
  /// arrow, or null while withheld.
  final void Function(OcptStoryboardAnnotationKind kind, double x1, double y1, double x2, double y2)?
  onArrowDrawn;

  /// Called with the normalised point a label was just clicked into place at, or null while
  /// withheld.
  final void Function(double x, double y)? onLabelPlaced;

  /// Called with a mark's id when it is clicked, selecting it. Always available: selecting a mark
  /// only reads, it never withholds like the two callbacks above.
  final ValueChanged<String>? onAnnotationSelected;

  /// Class constructor
  const OcptStoryboardAnnotationOverlay({
    super.key,
    required this.annotations,
    required this.selectedAnnotationId,
    required this.activeTool,
    required this.onArrowDrawn,
    required this.onLabelPlaced,
    required this.onAnnotationSelected,
  });

  @override
  State<OcptStoryboardAnnotationOverlay> createState() => _OcptStoryboardAnnotationOverlayState();
}

class _OcptStoryboardAnnotationOverlayState extends State<OcptStoryboardAnnotationOverlay> {
  /// The in-progress drag's own start point, in this widget's own local pixel space, or null while
  /// no drag is in progress.
  Offset? _dragStart;

  /// The in-progress drag's own current point. See [_dragStart].
  Offset? _dragCurrent;

  @override
  void didUpdateWidget(covariant OcptStoryboardAnnotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTool != oldWidget.activeTool) {
      // The tool switched, or gestures were withheld, out from under an in-progress drag (the
      // selected panel changed, the mode started previewing a version…): drop the draft rather
      // than let it finish under a tool the user never confirmed, or after being withheld.
      _dragStart = null;
      _dragCurrent = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final activeTool = widget.activeTool;
        final dragStart = _dragStart;
        final dragCurrent = _dragCurrent;

        final paint = CustomPaint(
          size: size,
          painter: OcptStoryboardAnnotationOverlayPainter(
            annotations: widget.annotations,
            selectedId: widget.selectedAnnotationId,
            movementArrowColor: theme.colorScheme.primary,
            cameraMoveArrowColor: theme.colorScheme.tertiary,
            labelColor: theme.colorScheme.secondary,
            selectedColor: theme.colorScheme.onSurface,
            labelTextColor: theme.colorScheme.onSurface,
            labelBackgroundColor: theme.colorScheme.surface.withValues(alpha: 0.85),
            draftKind: dragStart != null && dragCurrent != null ? activeTool?.kind : null,
            draftStart: dragStart == null || size.isEmpty
                ? null
                : Offset(dragStart.dx / size.width, dragStart.dy / size.height),
            draftEnd: dragCurrent == null || size.isEmpty
                ? null
                : Offset(dragCurrent.dx / size.width, dragCurrent.dy / size.height),
          ),
        );

        if (activeTool == null) {
          return paint;
        }

        // A raw `Listener`, not a `GestureDetector`: the strip that carries this frame is itself
        // wrapped in a horizontally scrolling `SingleChildScrollView` (`OcptStoryboardPanelStrip`),
        // and a `PanGestureRecognizer` here would have to *win the gesture arena* against that
        // ancestor's own horizontal drag recognizer for a left-right drag — which it cannot be
        // relied on to do, since both recognize the same straight horizontal motion. `Listener`
        // sidesteps the arena entirely: it receives every pointer event routed to it regardless of
        // which recognizer, if any, an ancestor's own arena entry ends up winning, so a drag drawn
        // here is never silently swallowed by the strip's own scroll. Read/write position is
        // tracked by hand instead of through `DragDetails`.
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _handlePointerDown(event.localPosition, activeTool),
          onPointerMove: activeTool.isDrag
              ? (event) => _handlePointerMove(event.localPosition)
              : null,
          onPointerUp: (event) => _handlePointerUp(event.localPosition, size, activeTool),
          onPointerCancel: (_) => setState(() {
            _dragStart = null;
            _dragCurrent = null;
          }),
          child: paint,
        );
      },
    );
  }

  /// Records the pointer's down point as the drag's own start, but only for a drag-shaped tool
  /// ([OcptStoryboardAnnotationToolBehaviour.isDrag]): the label tool never drags, so it never
  /// shows a draft.
  void _handlePointerDown(Offset local, OcptStoryboardAnnotationTool activeTool) {
    if (!activeTool.isDrag) {
      return;
    }
    setState(() {
      _dragStart = local;
      _dragCurrent = local;
    });
  }

  /// Updates the drag's own current point, redrawing the live draft arrow.
  void _handlePointerMove(Offset local) {
    if (_dragStart == null) {
      return;
    }
    setState(() => _dragCurrent = local);
  }

  /// The pointer lifted: if it travelled at least [_minDragDistance] under an arrow tool, reports
  /// [OcptStoryboardAnnotationOverlay.onArrowDrawn] with the normalised tail/head; otherwise treats
  /// the whole gesture as a tap ([_handleTap]) — selecting a mark under the point, or (label tool
  /// only) placing a new one there.
  void _handlePointerUp(Offset local, Size size, OcptStoryboardAnnotationTool activeTool) {
    final start = _dragStart;
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });

    if (size.isEmpty) {
      return;
    }

    if (activeTool.isDrag && start != null && (local - start).distance >= _minDragDistance) {
      widget.onArrowDrawn?.call(
        activeTool.kind,
        (start.dx / size.width).clamp(0.0, 1.0),
        (start.dy / size.height).clamp(0.0, 1.0),
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );
      return;
    }

    _handleTap(local, size, activeTool);
  }

  /// A tap (no drag, or one that never travelled far enough to count as one): selects the mark
  /// under [local] if there is one, otherwise — only with the label tool — places a new label
  /// there.
  void _handleTap(Offset local, Size size, OcptStoryboardAnnotationTool activeTool) {
    final hitId = _hitTestAnnotation(local, size);
    if (hitId != null) {
      widget.onAnnotationSelected?.call(hitId);
      return;
    }

    if (activeTool == OcptStoryboardAnnotationTool.label) {
      widget.onLabelPlaced?.call(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );
    }
  }

  /// The id of the topmost (last-drawn) mark within [_hitTestRadius] of [local], or null when none
  /// is that close — a label is tested against its own anchor point, an arrow against its whole
  /// shaft (the closest point of the tail-head segment).
  String? _hitTestAnnotation(Offset local, Size size) {
    for (final annotation in widget.annotations.reversed) {
      final tail = Offset(annotation.x1 * size.width, annotation.y1 * size.height);
      if (annotation.kind == OcptStoryboardAnnotationKind.label) {
        if ((local - tail).distance <= _hitTestRadius) {
          return annotation.id;
        }
        continue;
      }

      final head = Offset(annotation.x2 * size.width, annotation.y2 * size.height);
      if (_distanceToSegment(local, tail, head) <= _hitTestRadius) {
        return annotation.id;
      }
    }
    return null;
  }

  /// The shortest distance from [point] to the segment [a]-[b].
  double _distanceToSegment(Offset point, Offset a, Offset b) {
    final segment = b - a;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) {
      return (point - a).distance;
    }

    final t = (((point - a).dx * segment.dx + (point - a).dy * segment.dy) / lengthSquared).clamp(
      0.0,
      1.0,
    );
    final projection = a + segment * t;
    return (point - projection).distance;
  }
}
