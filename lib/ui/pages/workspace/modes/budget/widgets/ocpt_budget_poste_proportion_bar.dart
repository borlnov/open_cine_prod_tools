// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_stepper.dart';

/// The poste variant's own proportion bar, drawn in [OcptBudgetFicheStepper]'s own slot: the paid
/// amount, then the committed one, over a track that fills the full width the fiche gives it —
/// measured through a [LayoutBuilder] rather than fixed, so it reads the same width as every other
/// block in the panel (`docs/architecture/budget.md`).
///
/// **The track's own scale is the quote, until paid-plus-committed overruns it** — the moment it
/// does, the scale becomes that overrun total instead, so the whole bar still fits its own width,
/// and the overrun's own length eats the end of the bar in [ColorScheme.error]. A tick marks where
/// the quote itself falls on that stretched scale — drawn only while there is an overrun to place
/// it against, since without one the quote sits exactly at the bar's own right edge, where a tick
/// would say nothing a reader could not already see.
class OcptBudgetPosteProportionBar extends StatelessWidget {
  /// The poste's own quoted total, in cents — the track's own scale while nothing overruns it.
  final int quotedAmountCents;

  /// The poste's own paid total, in cents — the bar's own first segment.
  final int paidCents;

  /// The poste's own committed total, in cents — the bar's own second segment, drawn right after
  /// [paidCents].
  final int committedCents;

  /// Class constructor
  const OcptBudgetPosteProportionBar({
    super.key,
    required this.quotedAmountCents,
    required this.paidCents,
    required this.committedCents,
  });

  /// Build the budget poste proportion bar as a [LayoutBuilder].
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(ocptBudgetPosteProportionBarHeight / 2);
    // Never negative: a poste's own quote, paid and committed totals are all sums of non-negative
    // amounts (`docs/architecture/budget.md`'s "The money rule").
    final quoteCents = quotedAmountCents < 0 ? 0 : quotedAmountCents;
    final totalCents = paidCents + committedCents;
    final overrunCents = totalCents > quoteCents ? totalCents - quoteCents : 0;
    final scaleCents = overrunCents > 0 ? totalCents : quoteCents;

    // The within-budget share of each segment — what still fits inside the quote once the other
    // has already claimed its own share of it — is what stays in the accent colour; whatever is
    // left over, [overrunCents], is what eats the end of the track in red.
    final withinBudgetPaidCents = paidCents < quoteCents ? paidCents : quoteCents;
    final remainingBudgetCents = quoteCents - withinBudgetPaidCents;
    final withinBudgetCommittedCents = committedCents < remainingBudgetCents
        ? committedCents
        : remainingBudgetCents;

    // The full width the fiche hands the bar, measured here rather than fixed, so it stretches to
    // the panel like every other block above and below it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final track = Container(
          width: width,
          height: ocptBudgetPosteProportionBarHeight,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: radius),
        );

        if (scaleCents <= 0) {
          // Nothing quoted and nothing moved: the empty track alone, no segment and no tick to
          // draw.
          return track;
        }

        double lengthOf(int cents) => width * cents / scaleCents;

        return SizedBox(
          width: width,
          height: ocptBudgetPosteProportionBarHeight,
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
