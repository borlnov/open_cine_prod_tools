// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';

/// A table card inside its own pane: drawn at exactly [height] once the panes stack, and taking
/// whatever the heading band leaves it while they sit side by side.
///
/// See [ocptBudgetRegieStackedMinRowCount] for why the stacked reading states a height rather than
/// taking a share of one.
class OcptBudgetRegieTablePane extends StatelessWidget {
  /// The height the card is drawn at, or null while it takes what is left.
  final double? height;

  /// The card being framed.
  final Widget child;

  /// Class constructor
  const OcptBudgetRegieTablePane({super.key, required this.height, required this.child});

  /// Build the budget regie table pane.
  @override
  Widget build(BuildContext context) =>
      height == null ? Expanded(child: child) : SizedBox(height: height, child: child);
}
