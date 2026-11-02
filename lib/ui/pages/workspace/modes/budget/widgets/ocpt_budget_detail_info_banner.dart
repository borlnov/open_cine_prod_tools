// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_scaffold.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_off_line_banner.dart';

/// A calm, action-less info banner — the detail panel's own quiet note for a fact worth stating
/// plainly rather than folding into [OcptBudgetDetailScaffold]'s own `hint` line: a counterpart
/// quote line's own covering contribution, or an in-kind resource's own offset poste. Shares
/// [OcptBudgetOffLineBanner]'s own visual vocabulary — a `Card`, the same padding, the same muted
/// body text — without its promote/move actions, which neither of these two facts offers.
class OcptBudgetDetailInfoBanner extends StatelessWidget {
  /// The banner's own text.
  final String message;

  /// Class constructor
  const OcptBudgetDetailInfoBanner({super.key, required this.message});

  /// Build the budget detail panel info banner as a [Card].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
