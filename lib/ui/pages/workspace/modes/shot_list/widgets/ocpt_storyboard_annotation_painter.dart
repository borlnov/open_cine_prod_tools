// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

/// The length, in logical pixels, of an arrow's own head.
const double _headLength = 12;

/// The half-angle, in radians, an arrow head's two side strokes open at.
const double _headHalfAngle = 0.45;

/// The radius, in logical pixels, of a label's anchor dot.
const double _labelDotRadius = 4;

/// The radius, in logical pixels, of a selected mark's endpoint handles.
const double _handleRadius = 4;

/// Paints `OcptStoryboardPanel.annotations` (and, while a drag is in progress, one extra "draft"
/// mark) over an `OcptStoryboardPanelFrame`'s image, in the frame's own pixel space
/// (`docs/plans/storyboard.md`, §4.2).
///
/// **Coordinate convention** (reused by the M7 storyboard PDF, so it is stated once, here, rather
/// than re-derived per renderer): every mark's `x1`/`y1`/`x2`/`y2` is normalised 0..1 to the frame
/// — see `OcptStoryboardAnnotationsTable`'s own doc comment — and is mapped to this painter's own
/// [Size] by a plain product, `x * size.width` / `y * size.height`. No other transform, offset or
/// clamp is applied by the painter itself (the gesture layer that produces these coordinates is
/// what clamps them to 0..1 before they ever reach a stored row). An arrow's head is the second
/// point (`x2`/`y2`); its **arrowhead** is drawn as two strokes of [_headLength] logical pixels,
/// each turned [_headHalfAngle] radians off the shaft's own direction, meeting only at the tip —
/// filled solid for a [OcptStoryboardAnnotationKind.movementArrow] (an "in frame" movement), left
/// open (unfilled) for a [OcptStoryboardAnnotationKind.cameraMoveArrow] (a camera move), whose
/// shaft is additionally dashed rather than solid: two visually distinct arrows, per
/// `docs/adr/0031`. A [OcptStoryboardAnnotationKind.label] draws a small anchor dot at `x1`/`y1`
/// and, when its text isn't empty, a rounded caption chip beside it.
///
/// [movementArrowColor], [cameraMoveArrowColor] and [labelColor] are the three kinds' own base
/// colours; [selectedColor] overrides whichever of the three applies to the mark [selectedId]
/// names, which is additionally drawn with a thicker stroke and small round handles at its own
/// defining points. Every colour is a token the caller reads off [Theme], never a literal here.
class OcptStoryboardAnnotationOverlayPainter extends CustomPainter {
  /// The panel's own marks, in draw order.
  final List<OcptStoryboardAnnotation> annotations;

  /// The id of the currently selected mark, or null while none is.
  final String? selectedId;

  /// The colour a [OcptStoryboardAnnotationKind.movementArrow] is drawn with while not selected.
  final Color movementArrowColor;

  /// The colour a [OcptStoryboardAnnotationKind.cameraMoveArrow] is drawn with while not selected.
  final Color cameraMoveArrowColor;

  /// The colour a [OcptStoryboardAnnotationKind.label] is drawn with while not selected.
  final Color labelColor;

  /// The colour the selected mark is drawn with, whichever kind it is.
  final Color selectedColor;

  /// The colour a label's caption text is painted in.
  final Color labelTextColor;

  /// The background colour of a label's caption chip.
  final Color labelBackgroundColor;

  /// The kind of mark currently being dragged out, or null while no drag is in progress.
  final OcptStoryboardAnnotationKind? draftKind;

  /// The in-progress drag's own tail (or anchor, for a label), normalised 0..1 to the frame, or
  /// null while no drag is in progress.
  final Offset? draftStart;

  /// The in-progress drag's own current head, normalised 0..1 to the frame, or null while no drag
  /// is in progress.
  final Offset? draftEnd;

  /// Class constructor
  const OcptStoryboardAnnotationOverlayPainter({
    required this.annotations,
    required this.selectedId,
    required this.movementArrowColor,
    required this.cameraMoveArrowColor,
    required this.labelColor,
    required this.selectedColor,
    required this.labelTextColor,
    required this.labelBackgroundColor,
    this.draftKind,
    this.draftStart,
    this.draftEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      _paintMark(
        canvas: canvas,
        size: size,
        kind: annotation.kind,
        x1: annotation.x1,
        y1: annotation.y1,
        x2: annotation.x2,
        y2: annotation.y2,
        text: annotation.text,
        isSelected: annotation.id == selectedId,
      );
    }

    final draftKind = this.draftKind;
    final draftStart = this.draftStart;
    final draftEnd = this.draftEnd;
    if (draftKind != null && draftStart != null && draftEnd != null) {
      _paintMark(
        canvas: canvas,
        size: size,
        kind: draftKind,
        x1: draftStart.dx,
        y1: draftStart.dy,
        x2: draftEnd.dx,
        y2: draftEnd.dy,
        text: '',
        isSelected: false,
        isDraft: true,
      );
    }
  }

  /// Paints one mark, dispatching on [kind]. Normalised coordinates are mapped to [size] here —
  /// the one place this painter does it — per the class doc comment's coordinate convention.
  void _paintMark({
    required Canvas canvas,
    required Size size,
    required OcptStoryboardAnnotationKind kind,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required String text,
    required bool isSelected,
    bool isDraft = false,
  }) {
    final tail = Offset(x1 * size.width, y1 * size.height);
    final head = Offset(x2 * size.width, y2 * size.height);
    final opacity = isDraft ? 0.7 : 1.0;

    switch (kind) {
      case OcptStoryboardAnnotationKind.movementArrow:
        _paintSolidArrow(
          canvas: canvas,
          tail: tail,
          head: head,
          color: (isSelected ? selectedColor : movementArrowColor).withValues(alpha: opacity),
          isSelected: isSelected,
        );
      case OcptStoryboardAnnotationKind.cameraMoveArrow:
        _paintDashedArrow(
          canvas: canvas,
          tail: tail,
          head: head,
          color: (isSelected ? selectedColor : cameraMoveArrowColor).withValues(alpha: opacity),
          isSelected: isSelected,
        );
      case OcptStoryboardAnnotationKind.label:
        _paintLabel(
          canvas: canvas,
          anchor: tail,
          text: text,
          color: (isSelected ? selectedColor : labelColor).withValues(alpha: opacity),
          isSelected: isSelected,
        );
    }
  }

  /// A [OcptStoryboardAnnotationKind.movementArrow]: a solid shaft and a filled triangular head.
  void _paintSolidArrow({
    required Canvas canvas,
    required Offset tail,
    required Offset head,
    required Color color,
    required bool isSelected,
  }) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3 : 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tail, head, strokePaint);

    final headPoints = _headSidePoints(tail, head);
    if (headPoints != null) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(
        Path()
          ..moveTo(head.dx, head.dy)
          ..lineTo(headPoints.$1.dx, headPoints.$1.dy)
          ..lineTo(headPoints.$2.dx, headPoints.$2.dy)
          ..close(),
        fillPaint,
      );
    }

    if (isSelected) {
      _paintHandle(canvas, tail, color);
      _paintHandle(canvas, head, color);
    }
  }

  /// A [OcptStoryboardAnnotationKind.cameraMoveArrow]: a dashed shaft and an open (unfilled)
  /// chevron head — visually distinct from [_paintSolidArrow]'s solid shaft and filled head.
  void _paintDashedArrow({
    required Canvas canvas,
    required Offset tail,
    required Offset head,
    required Color color,
    required bool isSelected,
  }) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3 : 2
      ..strokeCap = StrokeCap.round;

    _drawDashedLine(canvas: canvas, from: tail, to: head, paint: strokePaint);

    final headPoints = _headSidePoints(tail, head);
    if (headPoints != null) {
      canvas.drawLine(head, headPoints.$1, strokePaint);
      canvas.drawLine(head, headPoints.$2, strokePaint);
    }

    if (isSelected) {
      _paintHandle(canvas, tail, color);
      _paintHandle(canvas, head, color);
    }
  }

  /// A [OcptStoryboardAnnotationKind.label]: a small anchor dot, and — while [text] isn't empty —
  /// a rounded caption chip drawn beside it.
  void _paintLabel({
    required Canvas canvas,
    required Offset anchor,
    required String text,
    required Color color,
    required bool isSelected,
  }) {
    canvas.drawCircle(
      anchor,
      isSelected ? _labelDotRadius + 1.5 : _labelDotRadius,
      Paint()..color = color,
    );
    if (isSelected) {
      canvas.drawCircle(
        anchor,
        _labelDotRadius + 4,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (text.isEmpty) {
      return;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelTextColor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 140);

    const horizontalPadding = 6.0;
    const verticalPadding = 3.0;
    final chipRect = Rect.fromLTWH(
      anchor.dx + _labelDotRadius + 6,
      anchor.dy - (textPainter.height / 2) - verticalPadding,
      textPainter.width + horizontalPadding * 2,
      textPainter.height + verticalPadding * 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(ocptRadiusSmall)),
      Paint()..color = labelBackgroundColor,
    );
    textPainter.paint(
      canvas,
      Offset(chipRect.left + horizontalPadding, chipRect.top + verticalPadding),
    );
  }

  /// A small round handle marking a selected mark's own defining point.
  void _paintHandle(Canvas canvas, Offset point, Color color) {
    canvas.drawCircle(point, _handleRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      point,
      _handleRadius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// The two points an arrowhead's side strokes reach back to from [head], turned
  /// [_headHalfAngle] off the shaft's own direction (tail to head), or null when [tail] and [head]
  /// coincide (nothing to turn an angle off of).
  (Offset, Offset)? _headSidePoints(Offset tail, Offset head) {
    final shaft = head - tail;
    if (shaft.distance == 0) {
      return null;
    }

    final angle = math.atan2(shaft.dy, shaft.dx);
    Offset sideAt(double turn) => head - Offset.fromDirection(angle + turn, _headLength);

    return (sideAt(_headHalfAngle), sideAt(-_headHalfAngle));
  }

  /// Draws a dashed line from [from] to [to], each dash and gap `dashLength` logical pixels long
  /// — the same technique `OcptDashedRoundedRectPainter` uses for its own outline.
  void _drawDashedLine({required Canvas canvas, required Offset from, required Offset to, required Paint paint}) {
    const dashLength = 6.0;
    final total = (to - from).distance;
    if (total == 0) {
      return;
    }

    final direction = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final next = math.min(travelled + dashLength, total);
      canvas.drawLine(from + direction * travelled, from + direction * next, paint);
      travelled = next + dashLength;
    }
  }

  @override
  bool shouldRepaint(covariant OcptStoryboardAnnotationOverlayPainter oldDelegate) =>
      !_annotationsEqual(oldDelegate.annotations, annotations) ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.movementArrowColor != movementArrowColor ||
      oldDelegate.cameraMoveArrowColor != cameraMoveArrowColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.selectedColor != selectedColor ||
      oldDelegate.labelTextColor != labelTextColor ||
      oldDelegate.labelBackgroundColor != labelBackgroundColor ||
      oldDelegate.draftKind != draftKind ||
      oldDelegate.draftStart != draftStart ||
      oldDelegate.draftEnd != draftEnd;

  /// Whether [a] and [b] hold the same marks in the same order — `Equatable`'s own `==` per
  /// element, already comparing every stored field.
  bool _annotationsEqual(List<OcptStoryboardAnnotation> a, List<OcptStoryboardAnnotation> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
