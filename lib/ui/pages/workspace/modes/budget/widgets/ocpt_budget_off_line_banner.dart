// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// An off-line record's own banner (`OcptBudgetDetailScaffold.banner`): a short, neutral, factual
/// [message], and one or two ways to reconcile the record with the quote it never went through.
/// `Add to the quote` ([promoteLabel]) is always the first, and `Move off-quote`
/// ([moveOffQuoteLabel], null for a record that has no such reconciliation) the optional second —
/// `docs/architecture/budget.md`'s "Off-quote spending is named, never hidden". An off-line debit
/// entry offers both (promote into a quote line and a settled commitment, or clear its own
/// account); an off-line commitment offers only the first, since a commitment always names an
/// account and cannot be moved off-quote. Either action clears the banner in one click, so it
/// carries no warning colour of its own: the message states the fact, and, while the account is
/// currently over its quote, by how much, but the banner itself is neither an alert nor a verdict.
///
/// **Withheld, not disabled** (`AGENTS.md`): a null action is simply not drawn, rather than a
/// button greyed out — `OcptBudgetDetail`'s own callbacks arrive null under a previewed version,
/// and the text stands alone.
class OcptBudgetOffLineBanner extends StatelessWidget {
  /// The banner's own explanatory text.
  final String message;

  /// `Add to the quote`'s own label.
  final String promoteLabel;

  /// `Move off-quote`'s own label, or null for a record that offers no such action.
  final String? moveOffQuoteLabel;

  /// Called when `Add to the quote` is pressed, or null while withheld.
  final VoidCallback? onPromoteToQuoteRequested;

  /// Called when `Move off-quote` is pressed, or null while withheld or the record offers none.
  final VoidCallback? onMoveOffQuoteRequested;

  /// Class constructor
  const OcptBudgetOffLineBanner({
    super.key,
    required this.message,
    required this.promoteLabel,
    required this.moveOffQuoteLabel,
    required this.onPromoteToQuoteRequested,
    required this.onMoveOffQuoteRequested,
  });

  /// Build the budget off line banner as a [Card].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPromoteToQuoteRequested = this.onPromoteToQuoteRequested;
    final onMoveOffQuoteRequested = this.onMoveOffQuoteRequested;
    final moveOffQuoteLabel = this.moveOffQuoteLabel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (onPromoteToQuoteRequested != null || onMoveOffQuoteRequested != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onPromoteToQuoteRequested != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPromoteToQuoteRequested,
                        child: Text(promoteLabel),
                      ),
                    ),
                  if (onPromoteToQuoteRequested != null &&
                      onMoveOffQuoteRequested != null &&
                      moveOffQuoteLabel != null)
                    const SizedBox(width: 8),
                  if (onMoveOffQuoteRequested != null && moveOffQuoteLabel != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onMoveOffQuoteRequested,
                        child: Text(moveOffQuoteLabel),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
