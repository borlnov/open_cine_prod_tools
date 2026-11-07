// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_badge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_breadcrumb.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_figures_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_outstanding.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_stepper.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The shared layout every variant of [OcptBudgetDetail] draws: breadcrumb, title and amount, an
/// optional hint (with an optional status badge beside it), an optional stepper, the figures row,
/// an optional outstanding block, an optional details section (the account's or the line's own
/// editable fields), one primary action and up to two secondary ones.
class OcptBudgetDetailScaffold extends StatelessWidget {
  /// The breadcrumb segments, from the outermost ancestor to the object itself.
  final List<String> breadcrumb;

  /// The object's own name.
  final String title;

  /// The object's own amount, already formatted (or [ocptBudgetEmptyValue]).
  final String amountText;

  /// A short hint under the title, or null.
  final String? hint;

  /// A status badge's own text, drawn beside [hint], or null — the resource/revenue `Dossier` fact.
  final String? badge;

  /// [badge]'s own accent colour.
  final Color? badgeColor;

  /// The stepper's own step labels — two or three words, or empty while this variant draws none
  /// (the account variant, which draws [proportionBar] in this very slot instead).
  final List<String> stepLabels;

  /// How many of [stepLabels] are reached.
  final int reachedCount;

  /// The account variant's own proportion bar, drawn in the very slot [stepLabels] would otherwise
  /// fill — null for every other variant, which keeps its stepper
  /// (`docs/architecture/budget.md`). Never both at once: an account
  /// carries no [stepLabels], and every other variant carries no [proportionBar].
  final Widget? proportionBar;

  /// The figures that make the amount up: a label paired with an already-formatted value, or null
  /// for [ocptBudgetEmptyValue].
  final List<(String label, String? value)> figures;

  /// The outstanding block's own label, or null while this variant draws none.
  final String? outstandingLabel;

  /// The outstanding block's own value, already formatted, or null for [ocptBudgetEmptyValue] —
  /// drawn only while [outstandingLabel] is not null.
  final String? outstandingValue;

  /// The account's or the line's own editable fields, or null while this variant carries none.
  final Widget? details;

  /// A quote line's own list of the payments made against its commitment, one instalment per row —
  /// null for every other variant, and for a line whose commitment has never been paid at all.
  final Widget? paymentsSection;

  /// A card drawn just above the primary action button, or null while this variant draws none: an
  /// off-line debit entry's or an off-line commitment's own `Add to the quote`/`Move off-quote`
  /// banner (`OcptBudgetOffLineBanner`), a counterpart quote line's own calm note naming the
  /// contribution it is covered in kind by, or an in-kind resource's own calm note naming the
  /// account its counterpart line offsets (both `OcptBudgetDetailInfoBanner`).
  final Widget? banner;

  /// The one primary action, or null while withheld or none applies.
  final OcptBudgetDetailAction? primary;

  /// Up to two secondary actions.
  final List<OcptBudgetDetailAction> secondaries;

  /// Class constructor
  const OcptBudgetDetailScaffold({
    super.key,
    required this.breadcrumb,
    required this.title,
    required this.amountText,
    this.hint,
    this.badge,
    this.badgeColor,
    required this.stepLabels,
    required this.reachedCount,
    this.proportionBar,
    required this.figures,
    this.outstandingLabel,
    this.outstandingValue,
    this.details,
    this.paymentsSection,
    this.banner,
    required this.primary,
    required this.secondaries,
  });

  /// Build the budget detail panel scaffold as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = this.details;
    final hint = this.hint;
    final badge = this.badge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OcptBudgetDetailBreadcrumb(segments: breadcrumb),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountText,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (hint != null || badge != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (hint != null)
                Expanded(
                  child: Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (badge != null) ...[
                if (hint != null) const SizedBox(width: 8),
                OcptBudgetDetailBadge(text: badge, color: badgeColor ?? theme.colorScheme.primary),
              ],
            ],
          ),
        ],
        if (details != null) ...[const SizedBox(height: 16), details],
        if (stepLabels.isNotEmpty || proportionBar != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  proportionBar ??
                      OcptBudgetDetailStepper(stepLabels: stepLabels, reachedCount: reachedCount),
                  const SizedBox(height: 12),
                  OcptBudgetDetailFiguresRow(figures: figures),
                ],
              ),
            ),
          ),
        ] else if (figures.isNotEmpty) ...[
          const SizedBox(height: 16),
          OcptBudgetDetailFiguresRow(figures: figures),
        ],
        if (paymentsSection != null) ...[const SizedBox(height: 16), paymentsSection!],
        if (outstandingLabel != null) ...[
          const SizedBox(height: 16),
          OcptBudgetDetailOutstanding(
            label: outstandingLabel!,
            value: outstandingValue ?? ocptBudgetEmptyValue,
          ),
        ],
        if (banner != null) ...[const SizedBox(height: 16), banner!],
        if (primary != null || secondaries.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (primary != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: primary!.onTap, child: Text(primary!.label)),
            ),
          if (secondaries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var index = 0; index < secondaries.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: secondaries[index].onTap,
                      child: Text(secondaries[index].label),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ],
    );
  }
}
