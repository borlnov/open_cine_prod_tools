// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';

/// The plain hint shown while nothing is selected, or the selected object has disappeared from a
/// freshly loaded snapshot.
class OcptBudgetDetailEmptyState extends StatelessWidget {
  /// Class constructor
  const OcptBudgetDetailEmptyState({super.key});

  /// Build the budget detail panel empty as an [OcptWorkspaceEmptyMode].
  @override
  Widget build(BuildContext context) => OcptWorkspaceEmptyMode(
    icon: Icons.receipt_long_outlined,
    message: Tr.of(context).budgetDetailEmptyHint,
  );
}
