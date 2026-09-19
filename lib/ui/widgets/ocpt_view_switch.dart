// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// The horizontal padding of [OcptViewSwitch]'s own segments, in logical pixels.
const double _ocptViewSwitchSegmentPadding = 14;

/// One segment of [OcptViewSwitch]: the value it selects and its own label.
class OcptViewSwitchSegment<T> {
  /// The value this segment selects when clicked.
  final T value;

  /// The segment's own label.
  final String label;

  /// Class constructor
  const OcptViewSwitchSegment({required this.value, required this.label});
}

/// A small bordered, rounded segmented control switching a centre view — the active segment filled
/// `primary` and bolder, the others `onSurfaceVariant`.
///
/// Lifted out of the breakdown mode's own private `Script`/`Recap` switch so the shot list mode's
/// `Table`/`Board` one is built from the very same widget rather than a second copy that could drift
/// from it (`docs/plans/storyboard.md`, §4.1): purely presentational, generic over the value type
/// [T], reporting every click upward through [onChanged] rather than knowing what a segment means.
class OcptViewSwitch<T> extends StatelessWidget {
  /// The switch's own segments, in display order.
  final List<OcptViewSwitchSegment<T>> segments;

  /// The switch's own current value.
  final T value;

  /// Called with the segment's value just clicked, when it differs from [value].
  final ValueChanged<T> onChanged;

  /// Class constructor
  const OcptViewSwitch({super.key, required this.segments, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final segment in segments) _buildSegment(context, segment)],
      ),
    );
  }

  /// One of the switch's own segments.
  Widget _buildSegment(BuildContext context, OcptViewSwitchSegment<T> segment) {
    final theme = Theme.of(context);
    final isActive = value == segment.value;

    return InkWell(
      onTap: isActive ? null : () => onChanged(segment.value),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _ocptViewSwitchSegmentPadding,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          segment.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
