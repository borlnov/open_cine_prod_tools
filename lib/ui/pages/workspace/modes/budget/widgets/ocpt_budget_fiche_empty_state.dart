// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';

/// The plain hint shown while nothing is selected, or the selected object has disappeared from a
/// freshly loaded snapshot.
class OcptBudgetFicheEmptyState extends StatelessWidget {
  /// Class constructor
  const OcptBudgetFicheEmptyState({super.key});

  @override
  Widget build(BuildContext context) => OcptWorkspaceEmptyMode(
    icon: Icons.receipt_long_outlined,
    message: Tr.of(context).budgetFicheEmptyHint,
  );
}
