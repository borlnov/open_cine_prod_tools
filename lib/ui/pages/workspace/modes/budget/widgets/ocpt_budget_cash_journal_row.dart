// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_voucher_marker.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One entry row: date, voucher number, poste, label, debit, credit, running balance, then its own
/// `⋮` menu — `Edit`/`Delete`, mirroring `OcptBudgetCostTracking`'s own row-menu idiom. Clicking
/// the row itself only selects it, opening the right dock's fiche on it — never a write, so never
/// withheld under a previewed version.
///
/// **Only the side money actually moved on is tinted** — a debit in [ColorScheme.error], a credit
/// in [ColorScheme.primary], each read off the entry's own raw column rather than off the row's
/// tax-inclusive figure, so the tint says which way the movement went and the figure says how much.
/// Every ordinary entry moves on one side alone, so every ordinary row carries exactly one coloured
/// cell: colouring both would paint an accent onto the untouched side's zero and leave a reader
/// with two competing signals per line, which is the opposite of what the colour is there for.
///
/// Both figures print exactly as [ocptBudgetJournalRowsOf] gives them, zero included: an entry
/// recorded entirely on one side of the account shows a real `0,00 €` on the other, never an
/// invented dash. [row]'s own null figures ([OcptBudgetJournalRow.debitCents]/`.creditCents`/
/// `.balanceAfterCents`, always null together for an entry that cannot be read tax-inclusive) print
/// [ocptBudgetEmptyValue] instead, in the ordinary muted body colour rather than either accent.
class OcptBudgetCashJournalRow extends StatelessWidget {
  /// The row this widget draws.
  final OcptBudgetJournalRow row;

  /// The poste [row]'s own entry names, or null while it names none.
  final OcptBudgetPoste? poste;

  /// This entry's own voucher, or null while it carries none.
  final OcptAssetRef? receipt;

  /// Whether this row's own entry is the one currently selected.
  final bool isSelected;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when this row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Called when this row's own `⋮` menu asks to edit it, or null while withheld.
  final VoidCallback? onEditRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const OcptBudgetCashJournalRow({
    super.key,
    required this.row,
    required this.poste,
    required this.receipt,
    required this.isSelected,
    required this.isSimplified,
    required this.currencyCode,
    required this.onTap,
    required this.onEditRequested,
    required this.onDeletionRequested,
  });

  /// Build the budget cash journal row as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final entry = row.entry;
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.yMMMd(locale).format(entry.date);
    final debitCents = row.debitCents;
    final creditCents = row.creditCents;
    final balanceCents = row.balanceAfterCents;
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
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: ocptBudgetCashJournalVoucherColumnWidth,
                child: Text(
                  entry.voucherNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: poste == null ? theme.colorScheme.onSurfaceVariant : null,
                      fontStyle: poste == null ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      if (receipt != null) ...[
                        OcptBudgetCashJournalVoucherMarker(path: receipt!.path),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _amountCell(
                context,
                debitCents,
                color: (debitCents != null && entry.debitCents != 0)
                    ? theme.colorScheme.error
                    : null,
              ),
              _amountCell(
                context,
                creditCents,
                color: (creditCents != null && entry.creditCents != 0)
                    ? theme.colorScheme.primary
                    : null,
              ),
              _amountCell(context, balanceCents, bold: true),
              SizedBox(
                width: ocptBudgetCashJournalMenuColumnWidth,
                child: onEditRequested == null && onDeletionRequested == null
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: "",
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (value) => switch (value) {
                          "edit" => onEditRequested?.call(),
                          "delete" => onDeletionRequested?.call(),
                          _ => null,
                        },
                        itemBuilder: (context) => [
                          if (onEditRequested != null)
                            PopupMenuItem<String>(
                              value: "edit",
                              child: Text(tr.budgetFinancingEditAction),
                            ),
                          if (onDeletionRequested != null)
                            PopupMenuItem<String>(
                              value: "delete",
                              child: Text(tr.budgetEntryDeleteAction),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build one amount cell, right-aligned, printing [ocptBudgetEmptyValue] while [cents] is null.
  Widget _amountCell(BuildContext context, int? cents, {Color? color, bool bold = false}) =>
      SizedBox(
        width: ocptBudgetCashJournalAmountColumnWidth,
        child: Text(
          cents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(cents, currencyCode),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: color, fontWeight: bold ? FontWeight.w600 : null),
        ),
      );
}
