// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The right dock's own `Inspector` tab: the selected poste's figures, its quote lines — each a
/// card collapsed to one summary row and expanding in place into its own editable fields, Benoit's
/// own decision on this view — and its related entries: the cash journal's own movements naming
/// this poste.
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] and hands
/// its own parts (every field, the tax-basis choice, the `Inherit` action, `+ Add`, `+ From
/// breakdown`, `Delete`) the null callbacks that withhold them under a version preview.
///
/// **`+ From breakdown` mints a line the same way `+ Add` does, except that its own picker names
/// where it comes from.** The mode opens `OcptBudgetElementPickerDialog` over
/// `OcptBudgetState.unpricedElements` and, once one is picked, dispatches
/// `OcptBudgetLineCreatedFromElementEvent` — this widget only reports the click
/// ([onLineFromElementRequested]), exactly as `+ Add` only reports its own
/// ([onLineCreationRequested]). [elementNameByElementId] is what lets a line that already prices one
/// say so quietly under its own label, in [_OcptBudgetLineSummaryRow] — see that widget's own doc
/// comment.
///
/// The poste's own figures are read exactly as `OcptBudgetCostTracking` reads its row: `Quote` in
/// [taxBasis], [paidCents]/[committedCents] real amounts (0 while the journal carries nothing
/// against this poste), `Consumed` alone still printing [ocptBudgetEmptyValue] for a poste with no
/// quote at all — see that widget's own class doc comment for why.
class OcptBudgetPosteInspector extends StatelessWidget {
  /// The selected poste, or null while none is — the tab then shows a plain hint.
  final OcptBudgetPoste? poste;

  /// Which basis every amount is currently read in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The selected poste's own paid total, in cents, tax-inclusive — see the class doc comment.
  final int paidCents;

  /// The selected poste's own committed total, in cents, tax-inclusive — see the class doc
  /// comment.
  final int committedCents;

  /// The selected poste's own related entries — the cash journal's own live entries naming its
  /// id, in whatever order the caller hands them in (never reordered by this widget): empty while
  /// [poste] is null or the journal carries nothing against it.
  final List<OcptBudgetEntry> entries;

  /// The id of the quote line whose card is currently expanded, or null while none is.
  final String? expandedLineId;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// A poste's or a line's current value for `field` — a pending edit, or its own stored value.
  final String Function(String targetId, OcptBudgetField field, String storedValue) fieldValueOf;

  /// Called with a poste's or a line's id, which field and the raw text just typed, or null while
  /// [isReadOnly].
  final void Function(String targetId, OcptBudgetField field, String rawValue)? onFieldChanged;

  /// Called with a line's id when its card's summary row is clicked, expanding or collapsing it.
  /// Never withheld: expanding a card only selects what is shown, it writes nothing.
  final ValueChanged<String> onLineExpanded;

  /// Called with a line's id and the including/excluding-tax choice just picked, or null while
  /// [isReadOnly]. `isTaxInclusive` is named, never positional, for the same reason
  /// `OcptBudgetCostTracking.onPosteReorderRequested`'s own `moveUp` is.
  final void Function(String lineId, {required bool isTaxInclusive})? onLineTaxInclusiveChanged;

  /// Called with a line's id when its own `Inherit` action is clicked, or null while [isReadOnly].
  final ValueChanged<String>? onLineVatRateInheritedRequested;

  /// Called with a line's id when its own `Delete` action is clicked, or null while [isReadOnly].
  /// The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onLineDeletionRequested;

  /// Called when the `+ Add` action is clicked, or null while [isReadOnly] or [poste] is null.
  final VoidCallback? onLineCreationRequested;

  /// Called when the `+ From breakdown` action is clicked, opening the element picker, or null
  /// while [isReadOnly] or [poste] is null — see the class doc comment.
  final VoidCallback? onLineFromElementRequested;

  /// A live element's own name, keyed by its id — resolves [OcptBudgetLine.elementId] into the
  /// quiet second line [_OcptBudgetLineSummaryRow] prints under a line that prices one. An id
  /// naming no key here (an element tombstoned since the line was created) prints nothing, exactly
  /// as every other id-to-name lookup of this app reads a stale reference.
  final Map<String, String> elementNameByElementId;

  /// Class constructor
  const OcptBudgetPosteInspector({
    super.key,
    required this.poste,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.paidCents,
    required this.committedCents,
    required this.entries,
    required this.expandedLineId,
    required this.isReadOnly,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onLineExpanded,
    required this.onLineTaxInclusiveChanged,
    required this.onLineVatRateInheritedRequested,
    required this.onLineDeletionRequested,
    required this.onLineCreationRequested,
    required this.onLineFromElementRequested,
    required this.elementNameByElementId,
  });

  @override
  Widget build(BuildContext context) {
    final poste = this.poste;
    final tr = Tr.of(context);

    if (poste == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.receipt_long_outlined,
        message: tr.budgetInspectorEmptyHint,
      );
    }

    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final onFieldChanged = this.onFieldChanged;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            targetId: poste.id,
            field: OcptBudgetField.posteLabel,
            label: tr.budgetInspectorPosteLabelFieldLabel,
            storedValue: poste.label,
            onFieldChanged: onFieldChanged,
          ),
          const SizedBox(height: 8),
          _field(
            targetId: poste.id,
            field: OcptBudgetField.posteCode,
            label: tr.budgetInspectorPosteCodeFieldLabel,
            storedValue: poste.code,
            onFieldChanged: onFieldChanged,
          ),
          const SizedBox(height: 16),
          _OcptBudgetInspectorFiguresRow(
            quotedAmountCents: quoted.amountCents,
            currencyCode: currencyCode,
            paidCents: paidCents,
            committedCents: committedCents,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr.budgetInspectorQuoteLinesSectionTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (!isReadOnly && onLineFromElementRequested != null)
                TextButton.icon(
                  onPressed: onLineFromElementRequested,
                  icon: const Icon(Icons.checklist_outlined, size: 16),
                  label: Text(tr.budgetLineFromElementAction),
                ),
              if (!isReadOnly && onLineCreationRequested != null)
                TextButton.icon(
                  onPressed: onLineCreationRequested,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(tr.budgetLineCreationAction),
                ),
            ],
          ),
          if (poste.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr.budgetInspectorNoLineHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final line in poste.lines)
              _OcptBudgetLineCard(
                line: line,
                elementName: line.elementId == null ? null : elementNameByElementId[line.elementId],
                isExpanded: line.id == expandedLineId,
                defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                currencyCode: currencyCode,
                isReadOnly: isReadOnly,
                fieldValueOf: fieldValueOf,
                onFieldChanged: onFieldChanged,
                onExpandRequested: () => onLineExpanded(line.id),
                onTaxInclusiveChanged: isReadOnly
                    ? null
                    : (value) => onLineTaxInclusiveChanged?.call(line.id, isTaxInclusive: value),
                onVatRateInheritedRequested: isReadOnly
                    ? null
                    : () => onLineVatRateInheritedRequested?.call(line.id),
                onDeletionRequested: isReadOnly ? null : () => onLineDeletionRequested?.call(line.id),
              ),
          const SizedBox(height: 16),
          Text(tr.budgetInspectorRelatedEntriesSectionTitle, style: Theme.of(context).textTheme.titleSmall),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr.budgetInspectorRelatedEntriesEmptyHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          else ...[
            for (final entry in entries)
              _OcptBudgetRelatedEntryRow(
                entry: entry,
                defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                currencyCode: currencyCode,
              ),
            if (_coveredEntryCount(entries) != entries.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr.budgetInspectorRelatedEntriesCoverageReadOut(
                    _coveredEntryCount(entries),
                    entries.length,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// How many of [entries] carry a readable amount — [_ocptBudgetRelatedEntryAmountCentsOf]
  /// answering something rather than null — what the coverage read-out counts against
  /// `entries.length`.
  int _coveredEntryCount(List<OcptBudgetEntry> entries) => entries
      .where(
        (entry) => _ocptBudgetRelatedEntryAmountCentsOf(
              entry,
              projectVatRateBasisPoints: defaultVatRateBasisPoints,
            ) !=
            null,
      )
      .length;

  /// One editable text field of the poste header, bound to [fieldValueOf]/[onFieldChanged] exactly
  /// as `OcptResourcesSheetField` is.
  Widget _field({
    required String targetId,
    required OcptBudgetField field,
    required String label,
    required String storedValue,
    required void Function(String, OcptBudgetField, String)? onFieldChanged,
  }) => _OcptBudgetInlineField(
    label: label,
    value: fieldValueOf(targetId, field, storedValue),
    onChanged: onFieldChanged == null ? null : (value) => onFieldChanged(targetId, field, value),
  );
}

/// The poste's own figures row: `Quote`, `Paid`, `Committed`, `Remaining`, `Consumed` — mirrors
/// `OcptBudgetCostTracking`'s own row reading.
class _OcptBudgetInspectorFiguresRow extends StatelessWidget {
  /// The poste's own quoted amount, in the header's own selected basis, in cents.
  final int quotedAmountCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The poste's own paid total, in cents, tax-inclusive.
  final int paidCents;

  /// The poste's own committed total, in cents, tax-inclusive.
  final int committedCents;

  /// Class constructor
  const _OcptBudgetInspectorFiguresRow({
    required this.quotedAmountCents,
    required this.currencyCode,
    required this.paidCents,
    required this.committedCents,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final remainingCents = ocptBudgetRemainingCents(
      quotedAmountCents: quotedAmountCents,
      paidCents: paidCents,
      committedCents: committedCents,
    );
    final consumedRatio = ocptBudgetConsumedRatioOf(
      quotedAmountCents: quotedAmountCents,
      paidCents: paidCents,
      committedCents: committedCents,
    );

    return Wrap(
      spacing: 20,
      runSpacing: 10,
      children: [
        _figure(context, tr.budgetInspectorFigureQuote, ocptBudgetAmountLabel(quotedAmountCents, currencyCode)),
        _figure(context, tr.budgetInspectorFigurePaid, ocptBudgetAmountLabel(paidCents, currencyCode)),
        _figure(
          context,
          tr.budgetInspectorFigureCommitted,
          ocptBudgetAmountLabel(committedCents, currencyCode),
        ),
        _figure(
          context,
          tr.budgetInspectorFigureRemaining,
          ocptBudgetAmountLabel(remainingCents, currencyCode),
        ),
        _figure(
          context,
          tr.budgetInspectorFigureConsumed,
          consumedRatio == null ? null : "${(consumedRatio * 100).round()} %",
        ),
      ],
    );
  }

  /// One figure of the row: a muted label over a value, or [ocptBudgetEmptyValue] while [value] is
  /// null.
  Widget _figure(BuildContext context, String label, String? value) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(value ?? ocptBudgetEmptyValue, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// [entry]'s own amount, read tax-inclusive, on whichever side actually carries money: its own
/// [OcptBudgetEntry.debitCents] when positive, its [OcptBudgetEntry.creditCents] otherwise — or
/// null when that reading is impossible ([ocptBudgetEntryDebitCentsOf]/
/// [ocptBudgetEntryCreditCentsOf] answering null together, exactly as their own doc comments
/// argue). Shared by [_OcptBudgetRelatedEntryRow] and the coverage read-out counting how many of a
/// poste's own entries carry a readable amount.
int? _ocptBudgetRelatedEntryAmountCentsOf(
  OcptBudgetEntry entry, {
  required int? projectVatRateBasisPoints,
}) => entry.debitCents > 0
    ? ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints)
    : ocptBudgetEntryCreditCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints);

/// One related-entry row: the voucher number and the date, muted, the entry's own label beside
/// them, and its own amount, read tax-inclusive, trailing — a debit painted in
/// [ColorScheme.error], a credit in [ColorScheme.primary], so the two are told apart without a
/// hard-coded colour. An entry whose amount cannot be read tax-inclusive prints
/// [ocptBudgetEmptyValue] instead, painted like any other muted figure rather than either colour.
class _OcptBudgetRelatedEntryRow extends StatelessWidget {
  /// The entry this row shows.
  final OcptBudgetEntry entry;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptBudgetRelatedEntryRow({
    required this.entry,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.yMMMd(locale).format(entry.date);
    final isDebit = entry.debitCents > 0;
    final amountCents = _ocptBudgetRelatedEntryAmountCentsOf(
      entry,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "${entry.voucherNumber} · $dateLabel",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountCents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(amountCents, currencyCode),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: amountCents == null
                  ? null
                  : (isDebit ? theme.colorScheme.error : theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// One quote line card: collapsed to a summary row, expanding in place into its own editable
/// fields.
class _OcptBudgetLineCard extends StatelessWidget {
  /// The line this card shows.
  final OcptBudgetLine line;

  /// The name of the element [line] prices, or null while [OcptBudgetLine.elementId] is itself null
  /// or names no live element any more — see [OcptBudgetPosteInspector.elementNameByElementId]'s
  /// own doc comment.
  final String? elementName;

  /// Whether this card is currently expanded.
  final bool isExpanded;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// The line's current value for a field — a pending edit, or its own stored value.
  final String Function(String targetId, OcptBudgetField field, String storedValue) fieldValueOf;

  /// Called with the line's id, which field and the raw text just typed, or null while
  /// [isReadOnly].
  final void Function(String targetId, OcptBudgetField field, String rawValue)? onFieldChanged;

  /// Called when the card's own summary row is clicked.
  final VoidCallback onExpandRequested;

  /// Called with the including/excluding-tax choice just picked, or null while [isReadOnly].
  final ValueChanged<bool>? onTaxInclusiveChanged;

  /// Called when the card's own `Inherit` action is clicked, or null while [isReadOnly].
  final VoidCallback? onVatRateInheritedRequested;

  /// Called when the card's own `Delete` action is clicked, or null while [isReadOnly].
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptBudgetLineCard({
    required this.line,
    required this.elementName,
    required this.isExpanded,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isReadOnly,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onExpandRequested,
    required this.onTaxInclusiveChanged,
    required this.onVatRateInheritedRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onExpandRequested,
          mouseCursor: ocptClickableCursor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _OcptBudgetLineSummaryRow(
              line: line,
              elementName: elementName,
              currencyCode: currencyCode,
            ),
          ),
        ),
        if (isExpanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _OcptBudgetLineFields(
              line: line,
              defaultVatRateBasisPoints: defaultVatRateBasisPoints,
              currencyCode: currencyCode,
              isReadOnly: isReadOnly,
              fieldValueOf: fieldValueOf,
              onFieldChanged: onFieldChanged,
              onTaxInclusiveChanged: onTaxInclusiveChanged,
              onVatRateInheritedRequested: onVatRateInheritedRequested,
              onDeletionRequested: onDeletionRequested,
            ),
          ),
        ],
      ],
    ),
  );
}

/// A collapsed line card's own summary row: the label and `<quantity> <unit> × <unit price>`, the
/// element's own name underneath **quietly**, in a third line, while [elementName] names one — the
/// one visible difference between a line typed from nothing and a line `+ From breakdown` minted to
/// answer a real need the breakdown already found (`OcptBudgetPosteInspector`'s own class doc
/// comment) — then the line's own total on the right.
class _OcptBudgetLineSummaryRow extends StatelessWidget {
  /// The line this row summarises.
  final OcptBudgetLine line;

  /// The name of the element [line] prices, or null — see the class doc comment.
  final String? elementName;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptBudgetLineSummaryRow({required this.line, required this.elementName, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final label = line.label.isEmpty ? tr.budgetLineUnnamed : line.label;
    final quantityText = ocptBudgetQuantityLabel(line.quantityMilli);
    final unitPriceText = ocptBudgetAmountLabel(line.unitPrice.amountCents, currencyCode);
    final elementName = this.elementName;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: line.label.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              Text(
                "$quantityText ${line.unit} × $unitPriceText",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (elementName != null)
                Text(
                  tr.budgetLineFromElementReadOut(elementName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ocptBudgetAmountLabel(ocptBudgetLineTotalCents(line), currencyCode),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// An expanded line card's own editable fields: `Label`, `Quantity`, `Unit`, `Unit price` (with the
/// including/excluding-tax choice), `VAT`, `Notes`, and `Delete`.
class _OcptBudgetLineFields extends StatelessWidget {
  /// The line this card edits.
  final OcptBudgetLine line;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// The line's current value for a field.
  final String Function(String targetId, OcptBudgetField field, String storedValue) fieldValueOf;

  /// Called with the line's id, which field and the raw text just typed, or null while
  /// [isReadOnly].
  final void Function(String targetId, OcptBudgetField field, String rawValue)? onFieldChanged;

  /// Called with the including/excluding-tax choice just picked, or null while [isReadOnly].
  final ValueChanged<bool>? onTaxInclusiveChanged;

  /// Called when `Inherit` is clicked, or null while [isReadOnly].
  final VoidCallback? onVatRateInheritedRequested;

  /// Called when `Delete` is clicked, or null while [isReadOnly].
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptBudgetLineFields({
    required this.line,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isReadOnly,
    required this.fieldValueOf,
    required this.onFieldChanged,
    required this.onTaxInclusiveChanged,
    required this.onVatRateInheritedRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    final effectiveRate = ocptEffectiveVatRateOf(
      lineVatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OcptBudgetInlineField(
          label: tr.budgetLineLabelFieldLabel,
          value: fieldValueOf(line.id, OcptBudgetField.lineLabel, line.label),
          onChanged: _onFieldChanged(OcptBudgetField.lineLabel),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OcptBudgetInlineField(
                label: tr.budgetLineQuantityFieldLabel,
                value: fieldValueOf(
                  line.id,
                  OcptBudgetField.lineQuantity,
                  ocptBudgetQuantityLabel(line.quantityMilli),
                ),
                onChanged: _onFieldChanged(OcptBudgetField.lineQuantity),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OcptBudgetInlineField(
                label: tr.budgetLineUnitFieldLabel,
                value: fieldValueOf(line.id, OcptBudgetField.lineUnit, line.unit),
                onChanged: _onFieldChanged(OcptBudgetField.lineUnit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _OcptBudgetInlineField(
          label: tr.budgetLineUnitPriceFieldLabel,
          value: fieldValueOf(
            line.id,
            OcptBudgetField.lineUnitAmount,
            ocptCostTextOf(line.unitPrice.amountCents),
          ),
          suffixText: currencySymbol,
          onChanged: _onFieldChanged(OcptBudgetField.lineUnitAmount),
        ),
        const SizedBox(height: 8),
        OcptBudgetBinaryChoice(
          value: line.unitPrice.isTaxInclusive,
          trueLabel: tr.budgetLineTaxInclusiveOption,
          falseLabel: tr.budgetLineTaxExclusiveOption,
          onChanged: onTaxInclusiveChanged,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OcptBudgetInlineField(
                label: tr.budgetLineVatRateFieldLabel,
                value: fieldValueOf(
                  line.id,
                  OcptBudgetField.lineVatRateOverride,
                  ocptVatRatePercentTextOf(line.unitPrice.vatRateBasisPoints),
                ),
                hintText: effectiveRate.basisPoints == null
                    ? null
                    : tr.budgetLineVatRateInheritedHint(
                        ocptVatRatePercentTextOf(effectiveRate.basisPoints),
                      ),
                suffixText: tr.budgetLineVatRateSuffix,
                onChanged: _onFieldChanged(OcptBudgetField.lineVatRateOverride),
              ),
            ),
            if (!isReadOnly && onVatRateInheritedRequested != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: TextButton(
                  onPressed: onVatRateInheritedRequested,
                  child: Text(tr.budgetLineVatRateInheritAction),
                ),
              ),
            ],
          ],
        ),
        if (effectiveRate.basisPoints != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              effectiveRate.isOverridden == true
                  ? tr.budgetLineVatRateOverriddenLabel(ocptVatRatePercentTextOf(effectiveRate.basisPoints))
                  : tr.budgetLineVatRateInheritedLabel(ocptVatRatePercentTextOf(effectiveRate.basisPoints)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: effectiveRate.isOverridden == true
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _OcptBudgetInlineField(
          label: tr.budgetLineNotesFieldLabel,
          value: fieldValueOf(line.id, OcptBudgetField.lineNotes, line.notes),
          multiline: true,
          onChanged: _onFieldChanged(OcptBudgetField.lineNotes),
        ),
        if (!isReadOnly && onDeletionRequested != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDeletionRequested,
              icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
              label: Text(
                tr.budgetLineDeleteAction,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Builds the `onChanged` callback of one of this card's fields, or null while [isReadOnly].
  ValueChanged<String>? _onFieldChanged(OcptBudgetField field) {
    final onFieldChanged = this.onFieldChanged;
    if (isReadOnly || onFieldChanged == null) {
      return null;
    }
    return (value) => onFieldChanged(line.id, field, value);
  }
}

/// One editable field of a line card, mirroring `OcptResourcesSheetField`'s own controller idiom
/// without depending on that mode's widget.
class _OcptBudgetInlineField extends StatefulWidget {
  /// The field's label.
  final String label;

  /// The field's current authoritative value.
  final String value;

  /// The greyed placeholder shown while the field is empty, or null.
  final String? hintText;

  /// Chrome shown after the typed text, or null.
  final String? suffixText;

  /// Whether this field is written as several lines.
  final bool multiline;

  /// Called with the field's raw text on every keystroke, or null while it may not be written to.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const _OcptBudgetInlineField({
    required this.label,
    required this.value,
    this.hintText,
    this.suffixText,
    this.multiline = false,
    required this.onChanged,
  });

  @override
  State<_OcptBudgetInlineField> createState() => _OcptBudgetInlineFieldState();
}

/// The state of [_OcptBudgetInlineField]: owns the controller, kept in sync with the widget's own
/// authoritative value exactly as `OcptResourcesSheetField` keeps its own.
class _OcptBudgetInlineFieldState extends State<_OcptBudgetInlineField> {
  /// The field's own text editing controller.
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OcptBudgetInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          readOnly: widget.onChanged == null,
          onChanged: widget.onChanged,
          maxLines: widget.multiline ? null : 1,
          minLines: widget.multiline ? 3 : 1,
          style: theme.textTheme.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            suffixText: widget.suffixText,
          ),
        ),
      ],
    );
  }
}
