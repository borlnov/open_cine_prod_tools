// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_sub_page.dart';

/// Which of the pre-M2 pages the current route corresponds to, for [OcptBudgetHelp] alone.
///
/// The help panel's own two-by-two matrix still describes the pages `OcptBudgetCentreView` used to
/// name one by one — `docs/plans/budget-mode-ux.md` M8 owns rewriting it, once the mode's shape has
/// actually settled around three documents rather than mid-migration. Until then this private
/// mirror of that retired type is the smallest change that keeps every one of its pages compiling
/// against the new (document, reading, sub-page) route: [OcptBudgetHelp] resolves it once, from its
/// own three parameters, and every method below reads exactly as it always has.
enum _OcptBudgetHelpPage { costTracking, cashJournal, committed, financing, regie, sharing }

/// The right dock's own `Help` tab: the mode's explanation of itself, contextual to whichever
/// route is currently on screen.
///
/// It answers a real defect rather than a missing feature — a production that had used the mode
/// still could not say what told `financing`, `cashJournal` and `committed` apart. Every page
/// therefore opens on the same small map ([_OcptBudgetHelpMap]) before its own substance: the map
/// is the answer, and the page below it is the detail. **This widget writes nothing** — like
/// `OcptBudgetRegie` (`docs/architecture/budget.md`), it carries no `isReadOnly` flag at all, and
/// is offered identically under a previewed version.
class OcptBudgetHelp extends StatelessWidget {
  /// Which document the help follows.
  final OcptBudgetDocument document;

  /// Which order [document]'s own rows are currently read in.
  final OcptBudgetDocumentReading reading;

  /// The sub-page of [document] currently shown, or null at its own top level.
  final OcptBudgetSubPage? subPage;

  /// Whether the header's simplified/detailed switch currently reads simplified, so a page heading
  /// or a cross-reference to another view reads exactly as that view's own chip currently does —
  /// `Cash journal`/`Committed` are the only two chips that switch wording
  /// (`OcptBudgetHeader`'s own doc comment).
  final bool isSimplified;

  /// Class constructor
  const OcptBudgetHelp({
    super.key,
    required this.document,
    required this.reading,
    required this.subPage,
    required this.isSimplified,
  });

  /// The pre-M2 page this route corresponds to — see [_OcptBudgetHelpPage]'s own doc comment.
  _OcptBudgetHelpPage get _page => switch (subPage) {
    OcptBudgetSubPage.committedSpending => _OcptBudgetHelpPage.committed,
    OcptBudgetSubPage.regie => _OcptBudgetHelpPage.regie,
    null => switch (document) {
      OcptBudgetDocument.expenses => reading == OcptBudgetDocumentReading.byDate
          ? _OcptBudgetHelpPage.cashJournal
          : _OcptBudgetHelpPage.costTracking,
      OcptBudgetDocument.resources => _OcptBudgetHelpPage.financing,
      OcptBudgetDocument.sharing => _OcptBudgetHelpPage.sharing,
    },
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final page = _page;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr.budgetHelpMapIntro, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          _OcptBudgetHelpMap(highlighted: _highlightedCellsOf(page)),
          const SizedBox(height: 8),
          Text(
            tr.budgetHelpMapQuoteNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(_titleOf(tr, page), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            _subtitleOf(tr, page),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final paragraph in _bodyOf(tr, page, isSimplified)) ...[
            Text(paragraph, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// The current page's own heading — the very word its band shows above the centre, so the
  /// reader finds the same name here as on screen (`OcptBudgetHeader._titleOf`'s own reasoning,
  /// reimplemented here rather than shared, since that method is private to that widget).
  String _titleOf(Tr tr, _OcptBudgetHelpPage page) => switch (page) {
    _OcptBudgetHelpPage.costTracking => tr.budgetHeaderTitle,
    _OcptBudgetHelpPage.cashJournal => tr.budgetHeaderCashJournalTitle,
    _OcptBudgetHelpPage.committed => tr.budgetCommittedSectionTitle,
    _OcptBudgetHelpPage.financing => tr.budgetHeaderResourcesTitle,
    _OcptBudgetHelpPage.regie => tr.budgetHeaderRegieTitle,
    _OcptBudgetHelpPage.sharing => tr.budgetHeaderSharingTitle,
  };

  /// The current page's own one-line subtitle, exactly as the header band prints it.
  String _subtitleOf(Tr tr, _OcptBudgetHelpPage page) => switch (page) {
    _OcptBudgetHelpPage.costTracking => tr.budgetHeaderSubtitle,
    _OcptBudgetHelpPage.cashJournal => tr.budgetHeaderCashJournalSubtitle,
    _OcptBudgetHelpPage.committed => tr.budgetHeaderCommittedSubtitle,
    _OcptBudgetHelpPage.financing => tr.budgetHeaderFinancingSubtitle,
    _OcptBudgetHelpPage.regie => tr.budgetHeaderRegieSubtitle,
    _OcptBudgetHelpPage.sharing => tr.budgetHeaderSharingSubtitle,
  };

  /// The current page's own explanation, one short paragraph per entry — the substance
  /// `docs/architecture/budget.md` states, in plain language, with every cross-reference to a
  /// figure or another view worded exactly as its own label or chip already reads.
  List<String> _bodyOf(Tr tr, _OcptBudgetHelpPage page, bool isSimplified) => switch (page) {
    _OcptBudgetHelpPage.costTracking => [
      tr.budgetHelpCostTrackingBody1(tr.budgetCostTrackingColumnQuote),
      tr.budgetHelpCostTrackingBody2(
        tr.budgetCostTrackingColumnPaid,
        tr.budgetCostTrackingColumnCommitted,
      ),
      tr.budgetHelpCostTrackingBody3(
        tr.budgetCostTrackingOffQuoteLabel,
        tr.budgetCostTrackingColumnPaid,
      ),
      tr.budgetHelpCostTrackingBody4,
    ],
    _OcptBudgetHelpPage.cashJournal => [
      tr.budgetHelpCashJournalBody1(tr.budgetCashJournalDebitLabel, tr.budgetCashJournalCreditLabel),
      tr.budgetHelpCashJournalBody2(tr.budgetCostTrackingOffQuoteLabel),
      tr.budgetHelpCashJournalBody3(tr.budgetCashJournalBalanceLabel),
      tr.budgetHelpCashJournalBody4,
    ],
    _OcptBudgetHelpPage.committed => [
      tr.budgetHelpCommittedBody1,
      tr.budgetHelpCommittedBody2(
        tr.budgetCommittedStatusSettledLabel,
        tr.budgetCommittedSettleAction,
      ),
      tr.budgetHelpCommittedBody3(tr.budgetCommittedProjectionTitle),
    ],
    _OcptBudgetHelpPage.financing => [
      tr.budgetHelpFinancingBody1,
      tr.budgetHelpFinancingBody2(
        tr.budgetFinancingColumnDossier,
        tr.budgetFinancingRecordReceiptAction,
      ),
      tr.budgetHelpFinancingBody3,
      tr.budgetHelpFinancingBody4(
        tr.budgetResourceDialogReimbursableFieldLabel,
        tr.budgetHeaderDocumentSharingSegmentLabel,
      ),
    ],
    _OcptBudgetHelpPage.regie => [
      tr.budgetHelpRegieBody1,
      tr.budgetHelpRegieBody2,
      tr.budgetHelpRegieBody3,
      tr.budgetHelpRegieBody4,
    ],
    _OcptBudgetHelpPage.sharing => [
      tr.budgetHelpSharingBody1,
      tr.budgetHelpSharingBody2,
      tr.budgetHelpSharingBody3,
    ],
  };

  /// Which cell(s) of [_OcptBudgetHelpMap] [page] occupies, so the map can highlight where the
  /// reader currently stands.
  ///
  /// `cashJournal` occupies both cells of the "has moved" column at once — the journal is where
  /// both a credit and a debit are read. `costTracking` (the quote, stated as sitting outside the
  /// map), `regie` and `sharing` occupy none of the four: each reads across the whole map, or a
  /// different figure entirely, rather than standing in one cell of it.
  Set<_OcptBudgetHelpMapCell> _highlightedCellsOf(_OcptBudgetHelpPage page) => switch (page) {
    _OcptBudgetHelpPage.financing => const {_OcptBudgetHelpMapCell.financing},
    _OcptBudgetHelpPage.committed => const {_OcptBudgetHelpMapCell.committed},
    _OcptBudgetHelpPage.cashJournal => const {
      _OcptBudgetHelpMapCell.cashCredits,
      _OcptBudgetHelpMapCell.cashDebits,
    },
    _OcptBudgetHelpPage.costTracking ||
    _OcptBudgetHelpPage.regie ||
    _OcptBudgetHelpPage.sharing => const {},
  };
}

/// The four cells [_OcptBudgetHelpMap] draws.
enum _OcptBudgetHelpMapCell { financing, committed, cashCredits, cashDebits }

/// The map every help page opens with: what is only promised against what has actually moved,
/// crossed with money coming in against money going out. `OcptBudgetCentreView.financing` and
/// `.committed` are each one cell of it; `.cashJournal` is the whole "has moved" column, since the
/// journal is where both a credit and a debit are read.
class _OcptBudgetHelpMap extends StatelessWidget {
  /// Which cell(s) to highlight as "you are here".
  final Set<_OcptBudgetHelpMapCell> highlighted;

  /// Class constructor
  const _OcptBudgetHelpMap({required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final borderColor = theme.colorScheme.outlineVariant;

    return Table(
      border: TableBorder.all(color: borderColor, borderRadius: BorderRadius.circular(ocptRadiusSmall)),
      columnWidths: const {0: FixedColumnWidth(64)},
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            _OcptBudgetHelpMapHeaderCell(label: tr.budgetHelpMapColumnPromisedLabel),
            _OcptBudgetHelpMapHeaderCell(label: tr.budgetHelpMapColumnMovedLabel),
          ],
        ),
        TableRow(
          children: [
            _OcptBudgetHelpMapHeaderCell(label: tr.budgetHelpMapRowComingInLabel),
            _OcptBudgetHelpMapDataCell(
              label: tr.budgetHeaderPlannedSegmentLabel,
              isHighlighted: highlighted.contains(_OcptBudgetHelpMapCell.financing),
              currentLabel: tr.budgetHelpMapCurrentViewBadge,
            ),
            _OcptBudgetHelpMapDataCell(
              label: tr.budgetHelpMapCellCreditsLabel,
              isHighlighted: highlighted.contains(_OcptBudgetHelpMapCell.cashCredits),
              currentLabel: tr.budgetHelpMapCurrentViewBadge,
            ),
          ],
        ),
        TableRow(
          children: [
            _OcptBudgetHelpMapHeaderCell(label: tr.budgetHelpMapRowGoingOutLabel),
            _OcptBudgetHelpMapDataCell(
              label: tr.budgetHeaderPlannedSegmentLabel,
              isHighlighted: highlighted.contains(_OcptBudgetHelpMapCell.committed),
              currentLabel: tr.budgetHelpMapCurrentViewBadge,
            ),
            _OcptBudgetHelpMapDataCell(
              label: tr.budgetHelpMapCellDebitsLabel,
              isHighlighted: highlighted.contains(_OcptBudgetHelpMapCell.cashDebits),
              currentLabel: tr.budgetHelpMapCurrentViewBadge,
            ),
          ],
        ),
      ],
    );
  }
}

/// One header cell of [_OcptBudgetHelpMap] — a row or column label, muted and centred.
class _OcptBudgetHelpMapHeaderCell extends StatelessWidget {
  /// The header's own text.
  final String label;

  /// Class constructor
  const _OcptBudgetHelpMapHeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// One data cell of [_OcptBudgetHelpMap] — naming the view (or the journal side) that fills it,
/// filled with the accent wash and set in bold once [isHighlighted] says this is the cell the
/// reader is currently standing in.
///
/// **The current cell wears no words of its own**, only the wash and the weight — the very two
/// signals the header's own view chips already use for the same fact, and a four-cell table is not
/// improved by a sentence repeating what its own highlight says. [currentLabel] is therefore
/// announced rather than drawn: it rides the cell's [Semantics] label, so a screen reader still
/// hears which cell the reader stands in, and the wash never has to carry the meaning alone —
/// colour by itself would say nothing in high contrast, nothing to a colour-blind reader and
/// nothing at all to a screen reader.
class _OcptBudgetHelpMapDataCell extends StatelessWidget {
  /// The cell's own label.
  final String label;

  /// Whether this cell is the current centre view's own.
  final bool isHighlighted;

  /// What this cell announces, beside [label], while [isHighlighted] — spoken, never drawn.
  final String currentLabel;

  /// Class constructor
  const _OcptBudgetHelpMapDataCell({
    required this.label,
    required this.isHighlighted,
    required this.currentLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: isHighlighted ? "$label, $currentLabel" : label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        color: isHighlighted
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : null,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isHighlighted ? theme.colorScheme.primary : null,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
