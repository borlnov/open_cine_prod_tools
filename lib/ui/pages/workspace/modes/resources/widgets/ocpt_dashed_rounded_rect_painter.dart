// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// Paints a dashed rounded-rectangle outline: the mock-up's own "drop a file here" styling, worn by
/// the person sheet's photo slot and by the location sheet's own "add a photo" tile.
///
/// Neither [BoxDecoration] nor any existing dependency draws one — Flutter has no stock dashed
/// border — and this is a small enough shape to paint directly rather than pull in a package for
/// it.
class OcptDashedRoundedRectPainter extends CustomPainter {
  /// The length, in logical pixels, of one dash and of the gap following it.
  static const double _dashLength = 5;

  /// The colour of the dashes.
  final Color color;

  /// Class constructor
  const OcptDashedRoundedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(ocptRadiusLarge),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + _dashLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant OcptDashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
