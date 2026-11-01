// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection_step.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_row.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One `À venir` row: a commitment falling due, still unsettled — [step]'s own cash figure, read
/// against [commitment] so the row can print its own label and poste, [step] itself carrying
/// neither. Clicking the row only selects it, opening the right dock's fiche on the commitment —
/// never a write, so never withheld under a previewed version, exactly as [OcptBudgetCashJournalRow]'s
/// own click is never withheld.
///
/// Drawn in the very same fixed column widths [OcptBudgetCashJournalRow] uses, so the two tables' amount
/// columns line up — the `Voucher` and `⋮` menu columns print nothing, an unsettled commitment
/// carrying neither a voucher of its own nor the entry table's `Modifier`/`Supprimer` menu (see the
/// class doc comment for why this section carries no `⋮` menu at all). `Credit` and `Balance` print
/// [ocptBudgetEmptyValue]: a commitment is a cost still owed, never a credit, and its own row
/// contributes no running balance of its own — that reading is the footer's.
class OcptBudgetCashUpcomingRow extends StatelessWidget {
  /// The projection step this row draws.
  final OcptBudgetProjectionStep step;

  /// The commitment [step] stands for.
  final OcptBudgetCommitment commitment;

  /// [commitment]'s own poste, or null while it names none still live.
  final OcptBudgetPoste? poste;

  /// Whether this row's own commitment is the one currently selected.
  final bool isSelected;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when this row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Class constructor
  const OcptBudgetCashUpcomingRow({
    super.key,
    required this.step,
    required this.commitment,
    required this.poste,
    required this.isSelected,
    required this.isSimplified,
    required this.currencyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dueDate = step.dueDate;
    final poste = this.poste;

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? null : ocpt_theme.ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: ocptBudgetCashJournalRowHeight,
          child: Row(
            children: [
              SizedBox(
                width: ocptBudgetCashJournalDateColumnWidth,
                child: Text(
                  dueDate == null
                      ? tr.budgetCommittedNoDueDateLabel
                      : DateFormat.yMMMd(locale).format(dueDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dueDate == null ? theme.colorScheme.onSurfaceVariant : null,
                    fontStyle: dueDate == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              const SizedBox(width: ocptBudgetCashJournalVoucherColumnWidth),
              SizedBox(
                width: ocptBudgetCashJournalPosteColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    poste == null
                        ? tr.budgetCashJournalNoPosteLabel
                        : ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    commitment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              SizedBox(
                width: ocptBudgetCashJournalAmountColumnWidth,
                child: Text(
                  ocptBudgetAmountLabel(step.amountCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: ocptBudgetCashJournalAmountColumnWidth,
                child: Text(
                  ocptBudgetEmptyValue,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: ocptBudgetCashJournalAmountColumnWidth,
                child: Text(
                  ocptBudgetEmptyValue,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: ocptBudgetCashJournalMenuColumnWidth),
            ],
          ),
        ),
      ),
    );
  }
}
