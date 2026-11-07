// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

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

  /// Create the [_OcptWorkspaceDockDividerState] holding the state of the workspace dock divider.
  @override
  State<OcptWorkspaceDockDivider> createState() => _OcptWorkspaceDockDividerState();
}

/// The state of [OcptWorkspaceDockDivider]: tracks hover and drag to tint the divider line and its
/// grip.
class _OcptWorkspaceDockDividerState extends State<OcptWorkspaceDockDivider> {
  /// Whether the pointer is currently hovering the divider.
  bool _isHovered = false;

  /// Whether the divider is currently being dragged.
  bool _isDragging = false;

  /// Build the workspace dock divider as a [MouseRegion].
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
              Center(child: _OcptWorkspaceDockGrip(isTinted: isTinted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The divider's three-dot grip: a rounded, faintly filled pill carrying three stacked dots, all of
/// it tinted `primary` while [isTinted] (hovered or dragged) so grabbing it lights it up.
class _OcptWorkspaceDockGrip extends StatelessWidget {
  /// The grip's own width, in pixels — narrower than [OcptWorkspaceDock.dividerHitWidth] so it sits
  /// clear of both edges of the hit area.
  static const double _gripWidth = 6;

  /// The grip's own height, in pixels.
  static const double _gripHeight = 32;

  /// The diameter of each of the grip's three dots.
  static const double _gripDotSize = 2.5;

  /// The vertical gap between two of the grip's dots.
  static const double _gripDotGap = 3;

  /// Whether the divider is hovered or dragged.
  final bool isTinted;

  /// Class constructor
  const _OcptWorkspaceDockGrip({required this.isTinted});

  /// Build the workspace dock grip as a [Container].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
