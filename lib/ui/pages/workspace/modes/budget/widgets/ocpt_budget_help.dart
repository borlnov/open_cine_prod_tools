// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';

/// The right dock's own `Help` tab: the mode's explanation of itself, contextual to whichever
/// route is currently on screen.
///
/// It answers a real defect rather than a missing feature — a production that had used the mode
/// still could not say what told `financing`, `cashJournal` and `committed` apart. That defect used
/// to be answered by a two-by-two matrix crossing what is only promised against what has actually
/// moved; the matrix answered a navigation of six sibling pages that no longer exists. What a
/// view's own rows actually do is pass through a small **chain of states** — an estimate
/// becomes a commitment becomes a payment, a promise becomes a receipt — so every view but
/// [OcptBudgetView.regie] now opens on that chain ([_OcptBudgetHelpChain]) instead: one cell per
/// state, left to right, each carrying the state's own word and, under it, a short caption naming
/// where that figure comes from. The régie draws no chain — it is not a stage of anything, and its
/// own first paragraph says so. Under the chain, one sentence says how a step
/// becomes the next; the page below it is the detail. **This widget writes nothing** — like
/// `OcptBudgetRegie` (`docs/architecture/budget.md`), it carries no `isReadOnly` flag at all, and
/// is offered identically under a previewed version.
class OcptBudgetHelp extends StatelessWidget {
  /// Which view the help follows.
  final OcptBudgetView view;

  /// Class constructor
  const OcptBudgetHelp({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final steps = _chainStepsOf(tr);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps.isNotEmpty) ...[
            _OcptBudgetHelpChain(
              steps: steps,
              highlightedIndex: _highlightedStepIndexOf(),
              currentStepBadge: tr.budgetHelpChainCurrentStepBadge,
            ),
            const SizedBox(height: 8),
            Text(
              _chainSentenceOf(tr)!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
          ],
          Text(_titleOf(tr), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            _subtitleOf(tr),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final paragraph in _bodyOf(tr)) ...[
            Text(paragraph, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// The chain [_OcptBudgetHelpChain] draws for the current view, or empty on
  /// [OcptBudgetView.regie] — see the class doc comment for why the régie draws none.
  ///
  /// [OcptBudgetView.committed] reads the very same chain as [OcptBudgetView.costTracking] and
  /// [OcptBudgetView.cashJournal]: it is that document's own middle state, seen on its own page,
  /// never a chain of its own. **[OcptBudgetView.dashboard] reads it too, for the same reason**:
  /// its KPI tiles are that very chain's own figures, read at the whole-project level rather than
  /// poste by poste, so the chain that explains them is the very one that already explains the
  /// other three.
  List<(String label, String caption)> _chainStepsOf(Tr tr) => switch (view) {
    OcptBudgetView.regie => const [],
    OcptBudgetView.dashboard ||
    OcptBudgetView.costTracking ||
    OcptBudgetView.cashJournal ||
    OcptBudgetView.committed => _expensesChainSteps(tr),
    OcptBudgetView.financing => _resourcesChainSteps(tr),
    OcptBudgetView.sharing => _sharingChainSteps(tr),
  };

  /// The expenses chain: a quote line, resolved as [Tr.budgetFicheStepEstimatedLabel] — the very
  /// word the fiche's own stepper already shows for it — becomes a commitment
  /// ([Tr.budgetInspectorFigureCommitted]), settled by an entry ([Tr.budgetInspectorFigurePaid]).
  List<(String, String)> _expensesChainSteps(Tr tr) => [
    (tr.budgetFicheStepEstimatedLabel, tr.budgetHelpChainExpensesEstimatedCaption),
    (tr.budgetInspectorFigureCommitted, tr.budgetHelpChainExpensesCommittedCaption),
    (tr.budgetInspectorFigurePaid, tr.budgetHelpChainExpensesPaidCaption),
  ];

  /// [OcptBudgetView.financing]'s own chain: a resource or a taking is promised
  /// ([Tr.budgetFicheStepPromisedLabel]), and becomes received ([Tr.budgetFinancingColumnReceived])
  /// the moment a journal entry names it — no hand-typed step in between, unlike the expenses
  /// chain's own commitment.
  List<(String, String)> _resourcesChainSteps(Tr tr) => [
    (tr.budgetFicheStepPromisedLabel, tr.budgetHelpChainResourcesPromisedCaption),
    (tr.budgetFinancingColumnReceived, tr.budgetHelpChainResourcesReceivedCaption),
  ];

  /// [OcptBudgetView.sharing]'s own chain: the takings received ([Tr.budgetFinancingColumnReceived]
  /// — read from [OcptBudgetView.financing], not typed here) become what has already been repaid
  /// ([Tr.budgetSharingRepaidLabel]) and what is left to share ([Tr.budgetSharingLeftToShareLabel]).
  List<(String, String)> _sharingChainSteps(Tr tr) => [
    (tr.budgetFinancingColumnReceived, tr.budgetHelpChainSharingReceivedCaption),
    (tr.budgetSharingRepaidLabel, tr.budgetHelpChainSharingRepaidCaption),
    (tr.budgetSharingLeftToShareLabel, tr.budgetHelpChainSharingLeftToShareCaption),
  ];

  /// The sentence printed under the chain, or null on [OcptBudgetView.regie] where [_chainStepsOf]
  /// is already empty and nothing is printed at all.
  String? _chainSentenceOf(Tr tr) => switch (view) {
    OcptBudgetView.regie => null,
    OcptBudgetView.dashboard ||
    OcptBudgetView.costTracking ||
    OcptBudgetView.cashJournal ||
    OcptBudgetView.committed => tr.budgetHelpChainExpensesSentence,
    OcptBudgetView.financing => tr.budgetHelpChainResourcesSentence,
    OcptBudgetView.sharing => tr.budgetHelpChainSharingSentence,
  };

  /// Which of [_chainStepsOf]'s own steps is the current view's own — "you are here" — or null
  /// where none stands for it in particular.
  ///
  /// **[OcptBudgetView.costTracking] and [OcptBudgetView.financing] both highlight nothing.** Each
  /// reads every one of its own columns at once — the cost report a poste's estimate, commitment
  /// and payment side by side, the resources tree a row's promise and its receipt side by side — so
  /// no single step of the chain is the one it stands in, unlike [OcptBudgetView.cashJournal] (a
  /// payment, the chain's own `Paid` step) or [OcptBudgetView.committed] (a commitment,
  /// `Committed`). Saying so a second time under the chain would only restate what "nothing
  /// highlighted" already says; the sentence there is left to state how a step becomes the next
  /// instead, exactly as every other view's does. [OcptBudgetView.sharing] highlights nothing for
  /// the same reason: it reads its three states together, in one card and one table, rather than
  /// opening on one of them. [OcptBudgetView.dashboard] highlights nothing for the very same
  /// reason as [OcptBudgetView.costTracking]: its KPI tiles read the quoted, paid and committed
  /// figures side by side, not one step of the chain in particular.
  int? _highlightedStepIndexOf() => switch (view) {
    OcptBudgetView.cashJournal => 2,
    OcptBudgetView.committed => 1,
    OcptBudgetView.dashboard ||
    OcptBudgetView.costTracking ||
    OcptBudgetView.financing ||
    OcptBudgetView.regie ||
    OcptBudgetView.sharing => null,
  };

  /// The current view's own heading — the very word its band shows above the centre, so the
  /// reader finds the same name here as on screen (`OcptBudgetHeader._titleOf`'s own reasoning,
  /// reimplemented here rather than shared, since that method is private to that widget).
  String _titleOf(Tr tr) => switch (view) {
    OcptBudgetView.dashboard => tr.budgetHeaderDashboardTitle,
    OcptBudgetView.costTracking => tr.budgetHeaderTitle,
    OcptBudgetView.cashJournal => tr.budgetHeaderCashJournalTitle,
    OcptBudgetView.committed => tr.budgetCommittedSectionTitle,
    OcptBudgetView.financing => tr.budgetHeaderResourcesTitle,
    OcptBudgetView.regie => tr.budgetHeaderRegieTitle,
    OcptBudgetView.sharing => tr.budgetHeaderSharingTitle,
  };

  /// The current view's own one-line subtitle, exactly as the header band prints it.
  String _subtitleOf(Tr tr) => switch (view) {
    OcptBudgetView.dashboard => tr.budgetHeaderDashboardSubtitle,
    OcptBudgetView.costTracking => tr.budgetHeaderSubtitle,
    OcptBudgetView.cashJournal => tr.budgetHeaderCashJournalSubtitle,
    OcptBudgetView.committed => tr.budgetHeaderCommittedSubtitle,
    OcptBudgetView.financing => tr.budgetHeaderFinancingSubtitle,
    OcptBudgetView.regie => tr.budgetHeaderRegieSubtitle,
    OcptBudgetView.sharing => tr.budgetHeaderSharingSubtitle,
  };

  /// The current view's own explanation, one short paragraph per entry — the substance
  /// `docs/architecture/budget.md` states, in plain language, with every cross-reference to a
  /// figure or another view worded exactly as its own label or chip already reads.
  ///
  /// [OcptBudgetView.costTracking], [OcptBudgetView.cashJournal] and [OcptBudgetView.financing]
  /// all open on the capture band's own paragraph: the band is mounted above every one of them, at
  /// their own top level, and is the daily gesture the mode exists for
  /// (`OcptBudgetCaptureBand`'s own class doc comment).
  ///
  /// **[OcptBudgetView.dashboard] prints none.** It carries no capture band of its own
  /// (`OcptBudgetMode._captureBandDirectionOf`), so the paragraph every other body opens with would
  /// be describing a control this page does not draw; the chain above and its own sentence already
  /// say what its KPI tiles read and where each one comes from.
  List<String> _bodyOf(Tr tr) => switch (view) {
    OcptBudgetView.dashboard => const [],
    OcptBudgetView.committed => [
      tr.budgetHelpCommittedBody1,
      tr.budgetHelpCommittedBody2(tr.budgetCommittedStatusSettledLabel, tr.budgetCommittedSettleAction),
      tr.budgetHelpCommittedBody3(tr.budgetCommittedProjectionTitle),
    ],
    OcptBudgetView.regie => [
      tr.budgetHelpRegieBody1,
      tr.budgetHelpRegieBody2,
      tr.budgetHelpRegieBody3,
      tr.budgetHelpRegieBody4,
      tr.budgetHelpRegieBody5(tr.budgetHeaderCostTrackingSegmentLabel),
    ],
    OcptBudgetView.cashJournal => [
      _captureBandBody(tr),
      tr.budgetHelpCashJournalIntro(tr.budgetHeaderCostTrackingSegmentLabel),
      tr.budgetHelpCashJournalBody1(tr.budgetCashJournalDebitLabel, tr.budgetCashJournalCreditLabel),
      tr.budgetHelpCashJournalBody2(tr.budgetCostTrackingOffQuoteLabel),
      tr.budgetHelpCashJournalBody3(tr.budgetCashJournalBalanceLabel),
      tr.budgetHelpCashJournalBody4,
    ],
    OcptBudgetView.costTracking => [
      _captureBandBody(tr),
      tr.budgetHelpCostTrackingBody1(tr.budgetCostTrackingColumnQuote),
      tr.budgetHelpCostTrackingBody2(tr.budgetCostTrackingColumnPaid, tr.budgetCostTrackingColumnCommitted),
      tr.budgetHelpCostTrackingBody3(tr.budgetCostTrackingOffQuoteLabel, tr.budgetCostTrackingColumnPaid),
      tr.budgetHelpCostTrackingBody4,
      tr.budgetHelpCostTrackingBody5(
        tr.budgetCostTrackingColumnFinalCost,
        tr.budgetCostTrackingColumnPaid,
        tr.budgetCostTrackingColumnCommitted,
        // The fiche's own field label, not the table's retired column of the same name: the
        // estimate to complete is typed there and nowhere else.
        tr.budgetInspectorPosteEstimateToCompleteFieldLabel,
        tr.budgetInspectorPosteEstimateToCompleteDeriveAction,
      ),
      tr.budgetHelpCostTrackingBody6(
        tr.budgetCostTrackingColumnVariance,
        tr.budgetCostTrackingColumnPaid,
        tr.budgetCostTrackingColumnCommitted,
        tr.budgetCostTrackingColumnFinalCost,
      ),
    ],
    OcptBudgetView.financing => [
      _captureBandBody(tr),
      tr.budgetHelpFinancingBody1,
      tr.budgetHelpFinancingBody2(tr.budgetFinancingColumnDossier, tr.budgetFinancingRecordReceiptAction),
      tr.budgetHelpFinancingBody3,
      tr.budgetHelpFinancingBody4(
        tr.budgetResourceDialogReimbursableFieldLabel,
        tr.budgetHeaderSharingSegmentLabel,
      ),
      tr.budgetHelpFinancingBody5(
        tr.budgetFinancingColumnReceived,
        tr.budgetFicheStepPromisedLabel,
      ),
    ],
    OcptBudgetView.sharing => [
      tr.budgetHelpSharingBody1(tr.budgetHeaderFinancingSegmentLabel),
      tr.budgetHelpSharingBody2,
      tr.budgetHelpSharingBody3,
    ],
  };

  /// The capture band's own paragraph — worded against its own labels
  /// (`OcptBudgetCaptureBand`'s `budgetCaptureBandTitle`/`budgetCaptureBandAcceptAction`/
  /// `budgetCaptureBandOtherAction`) rather than the util it calls, exactly as every other
  /// cross-reference here points at a label rather than at the rule behind it.
  String _captureBandBody(Tr tr) => tr.budgetHelpCaptureBandBody(
    tr.budgetCaptureBandTitle,
    tr.budgetCaptureBandAcceptAction,
    tr.budgetCaptureBandOtherAction,
  );
}

/// The chain every view but [OcptBudgetView.regie] opens with: the states the current view's own
/// rows pass through, left to right.
class _OcptBudgetHelpChain extends StatelessWidget {
  /// The chain's own steps, each a (word, caption) pair, in order.
  final List<(String label, String caption)> steps;

  /// Which of [steps] is "you are here", or null while none is.
  final int? highlightedIndex;

  /// What the highlighted step announces beside its own word — spoken, never drawn, mirroring
  /// [_OcptBudgetHelpChainCell]'s own reasoning.
  final String currentStepBadge;

  /// Class constructor
  const _OcptBudgetHelpChain({
    required this.steps,
    required this.highlightedIndex,
    required this.currentStepBadge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Table(
      border: TableBorder.all(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      children: [
        TableRow(
          children: [
            for (var index = 0; index < steps.length; index++)
              _OcptBudgetHelpChainCell(
                label: steps[index].$1,
                caption: steps[index].$2,
                isHighlighted: index == highlightedIndex,
                currentStepBadge: currentStepBadge,
              ),
          ],
        ),
      ],
    );
  }
}

/// One cell of [_OcptBudgetHelpChain] — a state's own word, its caption underneath, filled with the
/// accent wash and set in bold once [isHighlighted] says this is the step the reader is currently
/// standing in.
///
/// **The current cell wears no extra words of its own**, only the wash and the weight — the very
/// two signals the header's own chips already use for the same fact, and a three- or four-cell
/// table is not improved by a sentence repeating what its own highlight says. [currentStepBadge] is
/// therefore announced rather than drawn: it rides the cell's [Semantics] label, so a screen reader
/// still hears which step the reader stands on, and the wash never has to carry the meaning alone —
/// colour by itself would say nothing in high contrast, nothing to a colour-blind reader and nothing
/// at all to a screen reader (`_OcptBudgetHelpMapDataCell`'s own reasoning before this milestone,
/// carried over unchanged).
class _OcptBudgetHelpChainCell extends StatelessWidget {
  /// The step's own word — the very ARB key the screen itself draws for it.
  final String label;

  /// The short caption under [label], naming where that figure comes from.
  final String caption;

  /// Whether this step is the current route's own.
  final bool isHighlighted;

  /// What this cell announces, beside [label], while [isHighlighted] — spoken, never drawn.
  final String currentStepBadge;

  /// Class constructor
  const _OcptBudgetHelpChainCell({
    required this.label,
    required this.caption,
    required this.isHighlighted,
    required this.currentStepBadge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: isHighlighted ? "$label, $currentStepBadge" : label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        color: isHighlighted
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isHighlighted ? theme.colorScheme.primary : null,
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
