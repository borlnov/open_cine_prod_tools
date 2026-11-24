// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/rendering.dart';

/// Paint the thin horizontal line joining the marker of the selected note to its card: from [from]
/// to [to], in the coordinates of the notes margin.
class OcptNoteConnectorPainter extends CustomPainter {
  /// The thickness of the line, in logical pixels.
  static const double strokeWidth = 1.5;

  /// The opacity of the line's colour.
  static const double opacity = 0.7;

  /// The colour of the line, before [opacity] is applied.
  final Color color;

  /// The point the line starts at, just after the marker.
  final Offset from;

  /// The point the line ends at, on the left edge of the card.
  final Offset to;

  /// Class constructor.
  const OcptNoteConnectorPainter({required this.color, required this.from, required this.to});

  /// Paint the line.
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Tell whether the line differs from the one [oldDelegate] painted.
  @override
  bool shouldRepaint(covariant OcptNoteConnectorPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.from != from || oldDelegate.to != to;
}
