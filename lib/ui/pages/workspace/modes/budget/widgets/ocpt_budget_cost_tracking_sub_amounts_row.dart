// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The scrolling pane's own generic sub-row: a commitment or an entry, printing exactly one figure
/// — at [activeColumnIndex], or the em dash there while [activeCents] is null — and the em dash in
/// every other one of the six columns, then an optional `⋮` menu. The "no entry" hint row reuses
/// this same widget with [activeColumnIndex] null, so every one of its own six cells reads the em
/// dash and it carries no menu at all.
class OcptBudgetCostTrackingSubAmountsRow extends StatelessWidget {
  /// Whether this row is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked, or null while it draws no selection at all (the hint row).
  final VoidCallback? onTap;

  /// Which of the six columns (`0` `Devis` … `5` `Écart`) carries [activeCents], or null while this
  /// row has no figure of its own at all.
  final int? activeColumnIndex;

  /// The one figure this row prints, in cents, at [activeColumnIndex] — or null while it cannot be
  /// read, in which case that column reads the em dash too.
  final int? activeCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Builds this row's own `⋮` menu, or null while it carries none — and may itself answer null
  /// too, once every one of its own entries is withheld, see
  /// [OcptBudgetCostTracking._commitmentMenuOf]/[OcptBudgetCostTracking._entryMenuOf].
  final Widget? Function(BuildContext context)? menuBuilder;

  /// Class constructor
  const OcptBudgetCostTrackingSubAmountsRow({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.activeColumnIndex,
    required this.activeCents,
    required this.currencyCode,
    required this.menuBuilder,
  });

  /// Build the budget cost tracking sub amounts row as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCents = this.activeCents;
    final activeText = activeCents == null
        ? null
        : ocptBudgetAmountLabel(activeCents, currencyCode);
    final onTap = this.onTap;

    final row = Row(
      children: [
        for (var index = 0; index < 6; index++)
          _cell(context, index == activeColumnIndex ? activeText : null),
        SizedBox(width: ocptBudgetCostTrackingMenuColumnWidth, child: menuBuilder?.call(context)),
      ],
    );

    return SizedBox(
      height: ocptBudgetCostTrackingSubRowHeight,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
            : Colors.transparent,
        child: onTap == null
            ? row
            : InkWell(onTap: onTap, mouseCursor: ocpt_theme.ocptClickableCursor, child: row),
      ),
    );
  }

  /// Build one amount cell, right-aligned, reading [ocptBudgetEmptyValue] while [text] is null.
  Widget _cell(BuildContext context, String? text) => SizedBox(
    width: ocptBudgetCostTrackingAmountColumnWidth,
    child: Text(
      text ?? ocptBudgetEmptyValue,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}
