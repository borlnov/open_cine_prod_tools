// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_choice_segment.dart';

/// A two-segment boolean choice: two small bordered, clickable labels, the active one filled and
/// bolder — the account inspector's own way of drawing a line's tax basis, lifted here, generic
/// over its own two labels, once the cash journal's own entry dialog needed the very same shape
/// twice more (its own tax basis, and its debit/credit direction) rather than a third bespoke
/// widget.
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

  /// Build the budget binary choice as a [Row].
  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;

    return Row(
      children: [
        // Each segment is [Flexible] so the pair shrinks and ellipsizes rather than overflowing
        // when the row is narrower than the two labels want — the account inspector's own right
        // dock can be dragged down to its 300 px floor, narrower than these two chips at their
        // natural width.
        // Both keep that natural width wherever there is room: under the entry dialog's
        // [IntrinsicWidth] the row is handed `2·max(label) + gap`, so each flex share still clears
        // the wider label.
        Flexible(
          child: OcptBudgetChoiceSegment(
            label: trueLabel,
            isActive: value,
            accent: null,
            hasAccentBorder: false,
            isEllipsized: true,
            onTap: value || onChanged == null ? null : () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: OcptBudgetChoiceSegment(
            label: falseLabel,
            isActive: !value,
            accent: null,
            hasAccentBorder: false,
            isEllipsized: true,
            onTap: !value || onChanged == null ? null : () => onChanged(false),
          ),
        ),
      ],
    );
  }
}
