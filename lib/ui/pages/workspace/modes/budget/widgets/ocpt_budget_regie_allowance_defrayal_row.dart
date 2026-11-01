// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_allowances.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_cells.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One defrayal sub-row: its own wording — nature, when, and how many, joined by `·` — in the
/// detail column, its own amount under `ADVANCED`, `REIMBURSED`/`OWED` left blank since a single
/// défraiement carries no running account of its own, only the person above it does. Then its own
/// `⋮` menu — see `OcptBudgetRegie`'s own class doc comment for the menu's own withholding rules.
class OcptBudgetRegieAllowanceDefrayalRow extends StatelessWidget {
  /// The defrayal this row draws.
  final OcptBudgetAllowance allowance;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Called when the reader asks to open the person's own sheet.
  final VoidCallback onPersonOpenRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const OcptBudgetRegieAllowanceDefrayalRow({
    super.key,
    required this.allowance,
    required this.currencyCode,
    required this.onTap,
    required this.onPersonOpenRequested,
    required this.onDeletionRequested,
  });

  /// Build the budget regie allowance defrayal row as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? null : ocpt_theme.ocptClickableCursor,
      child: SizedBox(
        height: ocptBudgetRegieAllowanceSubRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: ocptBudgetRegieAllowanceTwistyWidth + ocptBudgetRegieAllowanceIndentStep,
                  right: 8,
                ),
                child: Text(
                  _detailTextOf(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            ocptBudgetRegieAllowanceAmountCell(
              context,
              ocptBudgetAllowanceCentsOf(allowance),
              currencyCode,
            ),
            ocptBudgetRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
            ocptBudgetRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
            SizedBox(
              width: ocptBudgetRegieAllowanceMenuColumnWidth,
              child: PopupMenuButton<String>(
                tooltip: "",
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) => switch (value) {
                  "person" => onPersonOpenRequested(),
                  _ => onDeletionRequested?.call(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: "person",
                    child: Text(tr.budgetRegieAllowanceOpenPersonAction),
                  ),
                  if (onDeletionRequested != null)
                    PopupMenuItem<String>(
                      value: "delete",
                      child: Text(tr.budgetCommittedDeleteAction),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `nature · when · ×quantity` — see the class doc comment.
  String _detailTextOf(BuildContext context) {
    final tr = Tr.of(context);
    final nature = ocptBudgetAllowanceKindLabel(tr, allowance.kind);
    final when = _whenLabel(context);
    final quantity = ocptBudgetQuantityLabel(allowance.quantityMilli);

    return "$nature · $when · ×$quantity";
  }

  /// A single date, a span for a stay, or [ocptBudgetEmptyValue] while nobody has said — a defrayal
  /// with no date is a real, ordinary state, not an unfinished row.
  String _whenLabel(BuildContext context) {
    final date = allowance.date;
    if (date == null) {
      return ocptBudgetEmptyValue;
    }

    final format = DateFormat.Md(Localizations.localeOf(context).toLanguageTag());
    final endDate = allowance.endDate;

    return endDate == null
        ? format.format(date)
        : "${format.format(date)} – ${format.format(endDate)}";
  }
}
