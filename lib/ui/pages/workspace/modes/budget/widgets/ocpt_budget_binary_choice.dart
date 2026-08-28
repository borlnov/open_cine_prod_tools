// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// A two-segment boolean choice: two small bordered, clickable labels, the active one filled and
/// bolder — the poste inspector's own way of drawing a line's tax basis, lifted here, generic over
/// its own two labels, once the cash journal's own entry dialog needed the very same shape twice
/// more (its own tax basis, and its debit/credit direction) rather than a third bespoke widget.
///
/// Mirrors `OcptBudgetHeader`'s own switch idiom rather than a [Radio] pair — this app carries no
/// `Radio` elsewhere, and this segmented look is already how it draws a two-way choice everywhere
/// else.
class OcptBudgetBinaryChoice extends StatelessWidget {
  /// The choice's current value.
  final bool value;

  /// The label of the segment selecting `true`.
  final String trueLabel;

  /// The label of the segment selecting `false`.
  final String falseLabel;

  /// Called with the value just picked, or null while it may not be changed.
  final ValueChanged<bool>? onChanged;

  /// Class constructor
  const OcptBudgetBinaryChoice({
    super.key,
    required this.value,
    required this.trueLabel,
    required this.falseLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _segment(context, true, trueLabel),
      const SizedBox(width: 8),
      _segment(context, false, falseLabel),
    ],
  );

  /// One of the choice's own two segments: filled and bold while active, muted otherwise.
  Widget _segment(BuildContext context, bool segmentValue, String label) {
    final theme = Theme.of(context);
    final isActive = segmentValue == value;
    final onChanged = this.onChanged;

    return InkWell(
      onTap: isActive || onChanged == null ? null : () => onChanged(segmentValue),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
