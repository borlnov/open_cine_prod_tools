// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';

/// A poste card's own proportion bar: the paid amount, then the committed one, over a track
/// scaled to the quote — the very same reading and the very same [ColorScheme] colours
/// `OcptBudgetFiche`'s own poste-variant proportion bar already draws these figures in, so this
/// card and the fiche it opens onto never disagree about what a poste's own bar means.
///
/// **The track's own scale is the quote, until paid-plus-committed overruns it** — the moment it
/// does, the scale becomes that overrun total instead, so the whole bar still fits its own width,
/// and the overrun's own length eats the end of the bar in [ColorScheme.error].
class OcptBudgetCostTrackingCardProportionBar extends StatelessWidget {
  /// The poste's own quoted total, in cents — the track's own scale while nothing overruns it.
  final int quotedAmountCents;

  /// The poste's own paid total, in cents — the bar's own first segment.
  final int paidCents;

  /// The poste's own committed total, in cents — the bar's own second segment, drawn right after
  /// [paidCents].
  final int committedCents;

  /// Class constructor
  const OcptBudgetCostTrackingCardProportionBar({
    super.key,
    required this.quotedAmountCents,
    required this.paidCents,
    required this.committedCents,
  });

  /// Build the budget cost tracking card proportion bar as a [LayoutBuilder].
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(ocptBudgetCostTrackingCardProportionBarHeight / 2);
    // Never negative: a poste's own quote, paid and committed totals are all sums of non-negative
    // amounts (`docs/architecture/budget.md`'s "The money rule").
    final quoteCents = quotedAmountCents < 0 ? 0 : quotedAmountCents;
    final totalCents = paidCents + committedCents;
    final overrunCents = totalCents > quoteCents ? totalCents - quoteCents : 0;
    final scaleCents = overrunCents > 0 ? totalCents : quoteCents;

    // The within-budget share of each segment stays in the accent colour; whatever is left over,
    // [overrunCents], eats the end of the track in red — see `OcptBudgetFiche`'s own proportion
    // bar for the very same reading.
    final withinBudgetPaidCents = paidCents < quoteCents ? paidCents : quoteCents;
    final remainingBudgetCents = quoteCents - withinBudgetPaidCents;
    final withinBudgetCommittedCents = committedCents < remainingBudgetCents
        ? committedCents
        : remainingBudgetCents;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final track = Container(
          width: width,
          height: ocptBudgetCostTrackingCardProportionBarHeight,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: radius),
        );

        if (scaleCents <= 0) {
          return track;
        }

        double lengthOf(int cents) => width * cents / scaleCents;

        return SizedBox(
          width: width,
          height: ocptBudgetCostTrackingCardProportionBarHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              track,
              ClipRRect(
                borderRadius: radius,
                child: Row(
                  children: [
                    Container(width: lengthOf(withinBudgetPaidCents), color: colors.primary),
                    Container(
                      width: lengthOf(withinBudgetCommittedCents),
                      color: colors.primary.withValues(alpha: 0.45),
                    ),
                    if (overrunCents > 0)
                      Container(width: lengthOf(overrunCents), color: colors.error),
                  ],
                ),
              ),
              if (overrunCents > 0)
                Positioned(
                  left: lengthOf(quoteCents) - 1,
                  top: -2,
                  bottom: -2,
                  child: Container(width: 2, color: colors.onSurface),
                ),
            ],
          ),
        );
      },
    );
  }
}
