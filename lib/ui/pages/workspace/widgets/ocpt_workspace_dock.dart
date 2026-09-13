// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// A side dock of the workspace shell: a panel shown at a resolved pixel [width], with the
/// `surfaceContainerLow` background every dock uses.
///
/// This widget only renders the background and sizing; the fraction-to-pixel resolution (with
/// its minimums, maximums and centre floor) lives in [resolveDockWidths], a pure function so it
/// can be unit-tested without pumping a widget.
class OcptWorkspaceDock extends StatelessWidget {
  /// The minimum width, in pixels, the left (scenes) dock can be resized down to.
  static const double leftMinWidth = 180;

  /// The left dock's default width, as a fraction of the editing row's width.
  static const double leftDefaultFraction = 0.18;

  /// The maximum width the left dock can be resized up to, as a fraction of the editing row's
  /// width.
  static const double leftMaxFraction = 0.40;

  /// The minimum width, in pixels, the right (preview / syntax) dock can be resized down to.
  static const double rightMinWidth = 300;

  /// The right dock's default width, as a fraction of the editing row's width.
  static const double rightDefaultFraction = 0.40;

  /// The maximum width the right dock can be resized up to, as a fraction of the editing row's
  /// width.
  static const double rightMaxFraction = 0.65;

  /// The minimum width, in pixels, the centre area is always guaranteed: when the row is
  /// too narrow to honour both docks' current widths plus this floor, the right dock gives up
  /// width first, then the left one (see [resolveDockWidths]).
  static const double centreMinWidth = 320;

  /// The width of a divider's hit area (see [OcptWorkspaceDockDivider]), reserved out of the row's
  /// width before splitting the rest between the docks and the centre floor. Wide enough to be a
  /// comfortable target for a finger, not only a mouse, since a tablet resizes its docks by touch.
  static const double dividerHitWidth = 12;

  /// The resolved pixel width this dock is given.
  final double width;

  /// The panel content, filling [width] and the full height handed to it.
  final Widget child;

  /// Class constructor
  const OcptWorkspaceDock({super.key, required this.width, required this.child});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: child,
    ),
  );

  /// Clamps [fraction] to the left dock's valid range for a row of [rowWidth]: at least
  /// [leftMinWidth] pixels, at most [leftMaxFraction] of the row.
  ///
  /// Returns [fraction] unchanged when [rowWidth] isn't strictly positive (nothing to resolve
  /// against yet, e.g. the very first layout pass). On a row so narrow that [leftMinWidth]
  /// itself already exceeds [leftMaxFraction] of it, the minimum wins (a plain `.clamp(min, max)`
  /// would otherwise throw on `min > max`).
  static double clampLeftFraction(double fraction, double rowWidth) {
    if (rowWidth <= 0) {
      return fraction;
    }
    final minFraction = leftMinWidth / rowWidth;
    final maxFraction = minFraction > leftMaxFraction ? minFraction : leftMaxFraction;
    return fraction.clamp(minFraction, maxFraction);
  }

  /// Clamps [fraction] to the right dock's valid range for a row of [rowWidth]: at least
  /// [rightMinWidth] pixels, at most [rightMaxFraction] of the row.
  ///
  /// Returns [fraction] unchanged when [rowWidth] isn't strictly positive (nothing to resolve
  /// against yet, e.g. the very first layout pass). On a row so narrow that [rightMinWidth]
  /// itself already exceeds [rightMaxFraction] of it, the minimum wins (a plain `.clamp(min, max)`
  /// would otherwise throw on `min > max`).
  static double clampRightFraction(double fraction, double rowWidth) {
    if (rowWidth <= 0) {
      return fraction;
    }
    final minFraction = rightMinWidth / rowWidth;
    final maxFraction = minFraction > rightMaxFraction ? minFraction : rightMaxFraction;
    return fraction.clamp(minFraction, maxFraction);
  }

  /// Resolves [leftFraction] and [rightFraction] (each a fraction of [rowWidth]) to the pixel
  /// widths the left and right docks should actually be given, honouring [centreMinWidth]: when
  /// the row is too narrow for both docks at their clamped widths plus the centre floor, the
  /// right dock gives up width first, then the left one. A dock not currently visible
  /// ([isLeftDockVisible], [isRightDockVisible]) contributes no width and reserves no divider.
  ///
  /// Degenerate rows (narrower than both docks' minimums plus the centre floor combined) still
  /// return non-negative widths; the centre area is left to collapse to 0 rather than going
  /// negative.
  static ({double left, double right}) resolveDockWidths({
    required double rowWidth,
    required double leftFraction,
    required double rightFraction,
    required bool isLeftDockVisible,
    required bool isRightDockVisible,
  }) {
    final dividerCount = (isLeftDockVisible ? 1 : 0) + (isRightDockVisible ? 1 : 0);
    final availableWidth = (rowWidth - dividerCount * dividerHitWidth).clamp(0.0, double.infinity);

    var leftWidth = isLeftDockVisible
        ? clampLeftFraction(leftFraction, rowWidth) * rowWidth
        : 0.0;
    var rightWidth = isRightDockVisible
        ? clampRightFraction(rightFraction, rowWidth) * rowWidth
        : 0.0;

    final centreBeforeFloor = availableWidth - leftWidth - rightWidth;
    if (centreBeforeFloor < centreMinWidth) {
      var deficit = centreMinWidth - centreBeforeFloor;

      final rightGiveUp = deficit < rightWidth ? deficit : rightWidth;
      rightWidth -= rightGiveUp;
      deficit -= rightGiveUp;

      if (deficit > 0) {
        final leftGiveUp = deficit < leftWidth ? deficit : leftWidth;
        leftWidth -= leftGiveUp;
      }
    }

    return (left: leftWidth, right: rightWidth);
  }
}

/// The draggable divider separating a dock from the centre area: a hit area
/// ([OcptWorkspaceDock.dividerHitWidth]) drawn as a centred 1 px `outlineVariant` line carrying a
/// small three-dot grip, both tinted `primary` while hovered or dragged, with a resize cursor on
/// hover.
///
/// The grip is what makes the divider read as *grabbable* rather than as a passive seam — it shows
/// on desktop and on a tablet alike, so a finger has a visible thing to catch where a hover cursor
/// never appears.
///
/// Reports raw horizontal drag deltas in pixels through [onDragUpdate]; converting them to a
/// fraction (and picking their sign for the dock being resized) is the caller's job, since only
/// the caller knows the current row width and which side the dock it resizes is on.
/// [onDragEnd] fires once the drag gesture ends, for the caller to persist the final fraction.
class OcptWorkspaceDockDivider extends StatefulWidget {
  /// Called with the horizontal drag delta, in pixels, on every drag update.
  final ValueChanged<double> onDragUpdate;

  /// Called once the drag gesture ends.
  final VoidCallback onDragEnd;

  /// Class constructor
  const OcptWorkspaceDockDivider({super.key, required this.onDragUpdate, required this.onDragEnd});

  @override
  State<OcptWorkspaceDockDivider> createState() => _OcptWorkspaceDockDividerState();
}

/// The state of [OcptWorkspaceDockDivider]: tracks hover and drag to tint the divider line and its
/// grip.
class _OcptWorkspaceDockDividerState extends State<OcptWorkspaceDockDivider> {
  /// The grip's own width, in pixels — narrower than [OcptWorkspaceDock.dividerHitWidth] so it sits
  /// clear of both edges of the hit area.
  static const double _gripWidth = 6;

  /// The grip's own height, in pixels.
  static const double _gripHeight = 32;

  /// The diameter of each of the grip's three dots.
  static const double _gripDotSize = 2.5;

  /// The vertical gap between two of the grip's dots.
  static const double _gripDotGap = 3;

  /// Whether the pointer is currently hovering the divider.
  bool _isHovered = false;

  /// Whether the divider is currently being dragged.
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTinted = _isHovered || _isDragging;
    final lineColor = isTinted ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragUpdate: (details) => widget.onDragUpdate(details.delta.dx),
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          widget.onDragEnd();
        },
        child: SizedBox(
          width: OcptWorkspaceDock.dividerHitWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The full-height seam line, behind the grip: a childless [Container] with a forced
              // width fills the loose height Center hands it.
              Center(child: Container(width: 1, color: lineColor)),
              Center(child: _buildGrip(theme, isTinted)),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the three-dot grip: a rounded, faintly filled pill carrying three stacked dots, all of
  /// it tinted `primary` while [isTinted] (hovered or dragged) so grabbing it lights it up.
  Widget _buildGrip(ThemeData theme, bool isTinted) {
    final dotColor = isTinted ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    final pillColor = isTinted
        ? theme.colorScheme.primary.withValues(alpha: 0.16)
        : theme.colorScheme.surfaceContainerHighest;

    return Container(
      width: _gripWidth,
      height: _gripHeight,
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(_gripWidth / 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: _gripDotGap),
            DecoratedBox(
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: _gripDotSize),
            ),
          ],
        ],
      ),
    );
  }
}
