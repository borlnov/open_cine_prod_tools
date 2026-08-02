// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// The number of dots a rating row draws, one per value of the 0-5 scale a difficulty axis is
/// rated on.
const int _dotCount = 6;

/// The diameter of one rating dot.
const double _dotSize = 18;

/// The side of the square hit target a dot sits centred in: the whole square is what reacts to a
/// click, so a dot never asks for a precise aim, and two neighbouring squares touching is what
/// spaces the dots apart.
const double _dotHitSize = 28;

/// One difficulty axis of the shot inspector: a label, a row of [_dotCount] clickable dots filled
/// up to [value] (dot *n* filled means the axis is at least *n*), and the numeric value at the
/// end of the row. Clicking anywhere in the *n*-th dot's square sets the axis to *n*.
///
/// Deliberately not a bar (the reference mock-up's own rendering): dots read better at this
/// density and make every one of the six discrete values individually clickable. The filled dots
/// and the numeric value share one colour, the accent normally, warning-coloured at
/// [ocptShotListDifficultyWarningThreshold]'s own integer floor (3) and error-coloured at 4 and
/// above, matching the mock-up's own thresholds; unfilled dots stay a muted outline colour
/// regardless.
class OcptShotDifficultyRating extends StatelessWidget {
  /// The axis's label (e.g. "Set", "Camera move").
  final String label;

  /// The axis's current value, 0-5.
  final int value;

  /// Called with the value of the dot clicked, or null while the axis may not be rated (a project
  /// version being previewed read-only): the dots are then drawn exactly as they are, without
  /// reacting to a click at all.
  final ValueChanged<int>? onChanged;

  /// Class constructor
  const OcptShotDifficultyRating({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // The dots are what must never be squeezed, so the label is the part that gives way
          // when the dock is dragged narrow.
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          for (var dot = 0; dot < _dotCount; dot++) _buildDot(theme: theme, color: color, dot: dot),
          const SizedBox(width: 4),
          Text(
            "$value",
            style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Builds the [dot]-th dot of the row: filled with [color] when the axis is at least that high,
  /// and clickable only while the row has an [onChanged] to report to.
  Widget _buildDot({required ThemeData theme, required Color color, required int dot}) {
    final onChanged = this.onChanged;

    final circle = SizedBox(
      width: _dotHitSize,
      height: _dotHitSize,
      child: Center(
        child: Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dot <= value ? color : theme.colorScheme.outlineVariant,
          ),
        ),
      ),
    );

    if (onChanged == null) {
      return circle;
    }

    return InkWell(
      customBorder: const CircleBorder(),
      mouseCursor: ocptClickableCursor,
      onTap: () => onChanged(dot),
      child: circle,
    );
  }

  /// The colour of this row's filled dots and its numeric value: the accent below 3, the warning
  /// colour at 3, the error colour at 4 and above.
  Color _colorFor(BuildContext context) {
    final theme = Theme.of(context);
    if (value >= 4) {
      return theme.colorScheme.error;
    }
    if (value >= 3) {
      return ocptWarningColor(context);
    }
    return theme.colorScheme.primary;
  }
}
