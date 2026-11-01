// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';

/// The frame the two panes are drawn in: [child] at exactly [height], scrolling vertically as soon
/// as that is taller than the view.
///
/// **The height is always stated, never left to the panes.** Side by side, both of them size their
/// own table with an `Expanded`, which needs a bounded height to mean anything, so this hands them
/// the view's own — floored at [ocptBudgetRegiePaneMinHeight], under which the pair scrolls rather than
/// being crushed out of its rows.
class OcptBudgetRegieVerticalScroller extends StatelessWidget {
  /// The height the child is drawn at.
  final double height;

  /// The pane, or the pair of panes, being framed.
  final Widget child;

  /// Class constructor
  const OcptBudgetRegieVerticalScroller({super.key, required this.height, required this.child});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: SizedBox(height: height, child: child),
  );
}
