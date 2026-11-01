// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_cells.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_row_figures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_twisty.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// A family row: bold, a twisty, the three money aggregates, no `Dossier` cell and no menu.
class OcptBudgetFinancingFamilyRow extends StatelessWidget {
  /// The family this row shows.
  final OcptBudgetResourceFamily family;

  /// This family's own three aggregate figures.
  final OcptBudgetFinancingRowFigures aggregates;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this family is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked.
  final VoidCallback onTwistyTap;

  /// Class constructor
  const OcptBudgetFinancingFamilyRow({
    super.key,
    required this.family,
    required this.aggregates,
    required this.currencyCode,
    required this.isExpanded,
    required this.onTwistyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700);

    return SizedBox(
      height: ocptBudgetFinancingRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ocpt_theme.ocptTableRowHorizontalPadding),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  OcptBudgetFinancingTwisty(
                    isExpandable: true,
                    isExpanded: isExpanded,
                    onTap: onTwistyTap,
                    rowHeight: ocptBudgetFinancingRowHeight,
                  ),
                  Expanded(
                    child: Text(
                      ocptBudgetResourceFamilyLabel(tr, family),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: boldStyle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ocptBudgetFinancingDossierColumnWidth),
            ocptBudgetFinancingAmountCell(
              context,
              aggregates.promisedCents,
              currencyCode,
              style: boldStyle,
            ),
            ocptBudgetFinancingAmountCell(
              context,
              aggregates.receivedCents,
              currencyCode,
              style: boldStyle,
            ),
            ocptBudgetFinancingAmountCell(
              context,
              aggregates.outstandingCents,
              currencyCode,
              style: boldStyle,
            ),
            const SizedBox(width: ocptBudgetFinancingMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}
