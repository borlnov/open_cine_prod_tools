// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';

/// The `Date` column's own fixed width, in logical pixels.
const double _ocptCashJournalDateColumnWidth = 92;

/// The `Voucher` column's own fixed width, in logical pixels.
const double _ocptCashJournalVoucherColumnWidth = 76;

/// The `Poste` column's own fixed width, in logical pixels.
const double _ocptCashJournalPosteColumnWidth = 200;

/// The `Debit`, `Credit` and `Balance` columns' own fixed width, in logical pixels.
const double _ocptCashJournalAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels — matches
/// `OcptBudgetCostTracking`'s own menu column, the same affordance drawn the same size.
const double _ocptCashJournalMenuColumnWidth = 36;

/// The narrowest the entry table is ever drawn at, in logical pixels: every fixed column's own
/// width — 92 + 76 + 200 + 3 × 108 + 36 = 728 — plus the row's own 24 px inset
/// ([ocptTableRowHorizontalPadding], symmetric) and 232 for a `Label` column that can still hold a
/// wording: 728 + 24 + 232 = 984.
///
/// Below it the table **scrolls sideways inside its own frame** rather than being crushed: the
/// `Label` column is the only flexible one, so a narrower centre used to drive it to nothing and
/// the row overflowed — which is exactly what opening the right dock on a laptop screen does. No
/// column is dropped and none shrinks; the reader gets a horizontal scrollbar and keeps the whole
/// ledger, the treatment the rest of the app already gives a table too wide for its slot.
const double _ocptCashJournalMinTableWidth = 984;

/// Every entry row's own fixed height, in logical pixels.
const double _ocptCashJournalRowHeight = 44;

/// The header row's own fixed height, in logical pixels.
const double _ocptCashJournalHeaderRowHeight = 36;

/// `OcptBudgetDocument.expenses` read under `OcptBudgetDocumentReading.byDate`: the whole account
/// book, in date order — **every movement the project has ever recorded, debit and credit alike**.
/// A top band, the entry table, then a note — the layout the validated mockup lays this view out
/// as.
///
/// **This is the one place a movement naming nothing can still be reached.** A poste, a resource or
/// a revenue each has a document of its own to be found under; an entry naming none of them — a
/// till receipt for something the nomenclature never anticipated, a subsidy instalment recorded
/// before anyone got round to naming the resource it pays — lives nowhere else, so this table draws
/// **every** live entry the journal holds rather than a reading over some of them. Narrowing it to
/// one direction, the way an earlier reading of this view once did, put exactly such an entry out
/// of reach: a credit naming nothing was drawn in no view of the mode at all, and could be neither
/// selected, edited nor deleted.
///
/// **[entries] is always the whole journal, never a filtered subset.** [filterPosteId] — read
/// straight off `OcptBudgetState.filterPosteId`, the mode-wide filter the header's own poste chip
/// sets, rather than a filter state of this view's own — narrows which rows the *table* draws,
/// through [ocptBudgetJournalRowsOf]'s own running balance computed first, over **every** entry, in
/// the chronological order that function already reads them in; filtering the resulting rows down
/// to [filterPosteId], when one is set, only afterwards is what keeps a filtered balance reading
/// exactly what the account actually stood at, rather than a number invented by silently skipping
/// the entries in between.
///
/// **The top band's own `Debit`/`Credit`/`Balance` figures are the whole journal's, unchanged.**
/// Benoit's own ruling is that this is the production's bank account: an account does not change
/// because a view narrowed to one poste.
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather
/// than a null callback per affordance, and withholds — never disables — every one of its own
/// writing affordances under it: the `+ Entry` action and its own `⋮` menu's `Edit`/`Delete`
/// entries. A row's own click never writes — it selects the entry, opening the right dock's fiche
/// on it, mirroring `OcptBudgetCostTracking`'s own row selection.
///
/// **This view no longer says a filter is on, and no longer offers to remove it.** It used to, in
/// a caption and a `Remove filter` button inside its own top band, which was the only place in the
/// mode that admitted a filter existed — so a filter arriving from a click in another view was
/// invisible until the reader got here, and its off switch was buried in a row of figures. Both
/// jobs moved to the header's own chip, which is on screen whatever view is: one place to see it,
/// one place to remove it.
///
/// Empty state: [OcptWorkspaceEmptyMode] draws **in the table's place, under a top band that stays
/// drawn**, whenever the whole journal holds no live entry at all — `+ Entry` lives in that band,
/// and an untouched journal is exactly the moment a reader reaches for it.
///
/// **A narrower case is a different thing entirely**: the whole journal holds entries, but
/// [filterPosteId] narrows this table to a poste none of them name. That is the poste filter
/// finding nothing, not the journal holding nothing, so it prints the plain, un-iconed sentence
/// `OcptBudgetFiche`'s own empty state already uses for the very same fact, never
/// [OcptWorkspaceEmptyMode].
///
/// A read-only view can return the empty state as its whole body because it writes nothing at
/// all; this view cannot.
class OcptBudgetCashJournal extends StatelessWidget {
  /// Every live entry of the whole journal, in the chronological order
  /// `OcptBudgetJournalService.loadEntries` already gives them — never reordered or pre-filtered by
  /// the caller. See the class doc comment for why filtering happens inside this widget, after the
  /// running balance is computed, rather than before.
  final List<OcptBudgetEntry> entries;

  /// Every live poste of the project, used to resolve an entry's own poste name.
  final List<OcptBudgetPoste> postes;

  /// Every live voucher, keyed by the entry it evidences — an entry with no key here carries no
  /// voucher at all. Read by each row's own small marker (never a second column of text), which
  /// also says when the referenced file no longer resolves.
  final Map<String, OcptAssetRef> receiptsByEntryId;

  /// The id of the poste the table is currently filtered onto, or null while it shows every entry —
  /// `OcptBudgetState.filterPosteId` itself, the mode's own single filter.
  final String? filterPosteId;

  /// What is currently selected for the right dock's own fiche — a row reads highlighted while it
  /// is an [OcptBudgetEntrySelection] naming its own id.
  final OcptBudgetSelection? selection;

  /// Whether the header's simplified/detailed switch currently reads simplified — switches a
  /// poste's own displayed name between `simpleLabel` and `code · label`.
  final bool isSimplified;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called when the top band's own `+ Entry` action is clicked, or null while [isReadOnly].
  final VoidCallback? onEntryCreationRequested;

  /// Called with an entry's id when its row is clicked — never withheld under [isReadOnly], since
  /// selecting only opens the right dock's own fiche on it, it writes nothing.
  final ValueChanged<String>? onEntrySelected;

  /// Called with an entry when its row's own `⋮` menu asks to edit it, opening the entry dialog on
  /// it, or null while [isReadOnly].
  final ValueChanged<OcptBudgetEntry>? onEntryEditRequested;

  /// Called with an entry's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onEntryDeletionRequested;

  /// Class constructor
  const OcptBudgetCashJournal({
    super.key,
    required this.entries,
    required this.postes,
    required this.receiptsByEntryId,
    required this.filterPosteId,
    required this.selection,
    required this.isSimplified,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isReadOnly,
    required this.onEntryCreationRequested,
    required this.onEntrySelected,
    required this.onEntryEditRequested,
    required this.onEntryDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    final rows = ocptBudgetJournalRowsOf(entries, projectVatRateBasisPoints: defaultVatRateBasisPoints);
    final totals = ocptBudgetCashTotalsOf(entries, projectVatRateBasisPoints: defaultVatRateBasisPoints);
    // Filtered down **after** [rows] is computed over every entry, in chronological order: a
    // running balance only means anything read in the order money actually moved, so narrowing to
    // a poste has to happen once that order has already produced it.
    final filterPosteId = this.filterPosteId;
    final filteredRows = filterPosteId == null
        ? rows
        : [
            for (final row in rows)
              if (row.entry.posteId == filterPosteId) row,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OcptCashJournalTopBand(
          totals: totals,
          currencyCode: currencyCode,
          onEntryCreationRequested: isReadOnly ? null : onEntryCreationRequested,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: entries.isEmpty
              ? OcptWorkspaceEmptyMode(
                  icon: Icons.account_balance_wallet_outlined,
                  // The detailed wording names this ledger by its trade word, which is exactly
                  // what the simplified reading is set to spare a crew — and the empty state is
                  // the one sentence somebody who has never opened this view will read.
                  message: isSimplified ? tr.budgetCashJournalSimpleEmptyHint : tr.budgetCashJournalEmptyHint,
                )
              : filteredRows.isEmpty
              ? Center(
                  child: Text(
                    tr.budgetInspectorRelatedEntriesEmptyHint,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // The header and the rows scroll **together**, inside one frame: they share
                    // the same fixed column widths, so scrolling either alone would slide the
                    // figures out from under their own headings.
                    child: SizedBox(
                      width: math.max(constraints.maxWidth, _ocptCashJournalMinTableWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _OcptCashJournalHeaderRow(),
                            Expanded(
                              child: ListView.builder(
                                itemCount: filteredRows.length,
                                itemBuilder: (context, index) => _OcptCashJournalRow(
                                  row: filteredRows[index],
                                  poste: _posteById(filteredRows[index].entry.posteId),
                                  receipt: receiptsByEntryId[filteredRows[index].entry.id],
                                  isSelected: _isEntrySelected(filteredRows[index].entry.id),
                                  isSimplified: isSimplified,
                                  currencyCode: currencyCode,
                                  onTap: onEntrySelected == null
                                      ? null
                                      : () => onEntrySelected?.call(filteredRows[index].entry.id),
                                  onEditRequested: isReadOnly || onEntryEditRequested == null
                                      ? null
                                      : () => onEntryEditRequested?.call(filteredRows[index].entry),
                                  onDeletionRequested: isReadOnly || onEntryDeletionRequested == null
                                      ? null
                                      : () => onEntryDeletionRequested?.call(filteredRows[index].entry.id),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          tr.budgetCashJournalWholeJournalNote,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// Whether entry [entryId] is the currently selected one — mirrors
  /// `OcptBudgetCostTracking._isEntrySelected`.
  bool _isEntrySelected(String entryId) {
    final selection = this.selection;
    return selection is OcptBudgetEntrySelection && selection.entryId == entryId;
  }

  /// [postes]' own entry naming [posteId], or null while [posteId] is null or names no live poste —
  /// mirrors `OcptBudgetState.selectedPoste`'s own reading.
  OcptBudgetPoste? _posteById(String? posteId) {
    if (posteId == null) {
      return null;
    }

    for (final poste in postes) {
      if (poste.id == posteId) {
        return poste;
      }
    }

    return null;
  }
}

/// The view's own top band: what it is filtered to and the action clearing it, pushed-right the
/// whole journal's own debit/credit/balance figures, then the `+ Entry` action.
class _OcptCashJournalTopBand extends StatelessWidget {


  /// The whole journal's own debit, credit and balance.
  final OcptBudgetCashTotals totals;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when `+ Entry` is clicked, or null while withheld.
  final VoidCallback? onEntryCreationRequested;

  /// Class constructor
  const _OcptCashJournalTopBand({
    required this.totals,
    required this.currencyCode,
    required this.onEntryCreationRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final coverageText = totals.isComplete
        ? null
        : tr.budgetCashJournalCoverageReadOut(totals.coveredEntryCount, totals.entryCount);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const SizedBox(width: 16),
        _figure(
          context,
          tr.budgetCashJournalDebitLabel,
          ocptBudgetAmountLabel(totals.debitCents, currencyCode),
        ),
        const SizedBox(width: 20),
        _figure(
          context,
          tr.budgetCashJournalCreditLabel,
          ocptBudgetAmountLabel(totals.creditCents, currencyCode),
        ),
        const SizedBox(width: 20),
        _figure(
          context,
          tr.budgetCashJournalBalanceLabel,
          ocptBudgetAmountLabel(totals.balanceCents, currencyCode),
          caption: coverageText,
        ),
        const SizedBox(width: 20),
        if (onEntryCreationRequested != null)
          FilledButton.icon(
            onPressed: onEntryCreationRequested,
            icon: const Icon(Icons.add, size: 16),
            label: Text(tr.budgetCashJournalEntryCreationAction),
          ),
      ],
    );
  }

  /// One of the band's own figures: a muted label over a value, an optional muted caption
  /// underneath it (the coverage read-out, drawn only under `Balance`, once, rather than repeated
  /// under all three — see [OcptBudgetCashJournal]'s own class doc comment for why the three
  /// figures are never the filtered subset's own).
  Widget _figure(BuildContext context, String label, String value, {String? caption}) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (caption != null)
          Text(
            caption,
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// The entry table's own header row: `Date`, `Voucher`, `Poste`, `Label`, `Debit`, `Credit`,
/// `Balance`, then a blank cell over the `⋮` menu column — `Poste` ahead of `Label`, mirroring
/// `OcptBudgetCostTracking`'s own pinned `Poste` column, since both readings of the very same
/// expenses document now lead with the same identifying column.
class _OcptCashJournalHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptCashJournalHeaderRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: _ocptCashJournalHeaderRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: _ocptCashJournalDateColumnWidth,
              child: Text(tr.budgetCashJournalColumnDate.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: _ocptCashJournalVoucherColumnWidth,
              child: Text(tr.budgetCashJournalColumnVoucher.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: _ocptCashJournalPosteColumnWidth,
              child: Text(tr.budgetCostTrackingColumnPoste.toUpperCase(), style: labelStyle),
            ),
            Expanded(child: Text(tr.budgetCashJournalColumnLabel.toUpperCase(), style: labelStyle)),
            SizedBox(
              width: _ocptCashJournalAmountColumnWidth,
              child: Text(
                tr.budgetCashJournalColumnDebit.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            SizedBox(
              width: _ocptCashJournalAmountColumnWidth,
              child: Text(
                tr.budgetCashJournalColumnCredit.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            SizedBox(
              width: _ocptCashJournalAmountColumnWidth,
              child: Text(
                tr.budgetCashJournalColumnBalance.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: _ocptCashJournalMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}

/// One entry row: date, voucher number, poste, label, debit, credit, running balance, then its own
/// `⋮` menu — `Edit`/`Delete`, mirroring `OcptBudgetCostTracking`'s own row-menu idiom. Clicking
/// the row itself only selects it, opening the right dock's fiche on it — never a write, so never
/// withheld under a previewed version.
///
/// [row]'s own debit reads in [ColorScheme.error] wherever it is actually known, its own credit in
/// [ColorScheme.primary] — the same pairing a movement's own colour already carries wherever else
/// the app draws one, so a debit or a credit reads the same way whichever view shows it. Both
/// figures print exactly as [ocptBudgetJournalRowsOf] gives them, zero included: an entry recorded
/// entirely on one side of the account shows a real `0,00 €` on the other, never an invented dash.
/// [row]'s own null figures ([OcptBudgetJournalRow.debitCents]/`.creditCents`/`.balanceAfterCents`,
/// always null together for an entry that cannot be read tax-inclusive) print [ocptBudgetEmptyValue]
/// instead, in the ordinary muted body colour rather than either accent.
class _OcptCashJournalRow extends StatelessWidget {
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
  const _OcptCashJournalRow({
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
      mouseCursor: onTap == null ? null : ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: _ocptCashJournalRowHeight,
          child: Row(
            children: [
            SizedBox(
              width: _ocptCashJournalDateColumnWidth,
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptCashJournalVoucherColumnWidth,
              child: Text(
                entry.voucherNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptCashJournalPosteColumnWidth,
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
                      _OcptCashJournalVoucherMarker(path: receipt!.path),
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
            _amountCell(context, debitCents, color: debitCents != null ? theme.colorScheme.error : null),
            _amountCell(context, creditCents, color: creditCents != null ? theme.colorScheme.primary : null),
            _amountCell(context, balanceCents, bold: true),
            SizedBox(
              width: _ocptCashJournalMenuColumnWidth,
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
                          PopupMenuItem<String>(value: "delete", child: Text(tr.budgetEntryDeleteAction)),
                      ],
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// One amount cell, right-aligned, printing [ocptBudgetEmptyValue] while [cents] is null.
  Widget _amountCell(BuildContext context, int? cents, {Color? color, bool bold = false}) => SizedBox(
    width: _ocptCashJournalAmountColumnWidth,
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

/// The small marker a row carries next to its own label when its entry carries a voucher — never a
/// second column of text, just an icon whose tooltip says whether the referenced file still
/// resolves, mirroring `OcptAssetFileLine`'s own "file not found" reading (ADR 0013).
///
/// A [StatefulWidget] (the documented RFL1 exception) for the very reason `OcptAssetFileLine` is
/// one: the answer belongs to nobody else and is worth asking once, not from `build`, which would
/// run it on every frame the journal is rebuilt for an unrelated reason.
class _OcptCashJournalVoucherMarker extends StatefulWidget {
  /// The voucher's own referenced path.
  final String path;

  /// Class constructor
  const _OcptCashJournalVoucherMarker({required this.path});

  @override
  State<_OcptCashJournalVoucherMarker> createState() => _OcptCashJournalVoucherMarkerState();
}

/// The state of [_OcptCashJournalVoucherMarker]: whether the referenced file was found, once asked.
class _OcptCashJournalVoucherMarkerState extends State<_OcptCashJournalVoucherMarker> {
  /// Whether the referenced file was there when it was last asked about.
  late bool _exists = File(widget.path).existsSync();

  @override
  void didUpdateWidget(covariant _OcptCashJournalVoucherMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _exists = File(widget.path).existsSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isMissing = !_exists;

    return Tooltip(
      message: isMissing
          ? tr.budgetCashJournalVoucherFileMissingTooltip
          : tr.budgetCashJournalVoucherAttachedTooltip,
      child: Icon(
        isMissing ? Icons.error_outline : Icons.attach_file,
        size: 14,
        color: isMissing ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
