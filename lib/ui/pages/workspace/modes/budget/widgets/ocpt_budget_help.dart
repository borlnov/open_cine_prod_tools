// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';

/// The right dock's own `Help` tab: the mode's explanation of itself, contextual to whichever
/// route is currently on screen.
///
/// It answers a real defect rather than a missing feature — a production that had used the mode
/// still could not say what told several of the old sibling pages apart. That defect used to be
/// answered by a two-by-two matrix crossing what is only promised against what has actually moved;
/// the matrix answered a navigation of sibling pages that no longer exists. What a route's own
/// rows actually do is pass through a small **chain of states** — an estimate becomes a
/// commitment becomes a payment, a promise becomes a receipt — so every route but the tools
/// drawer's own `Régie` page now opens on that chain ([_OcptBudgetHelpChain]) instead: one cell per
/// state, left to right, each carrying the state's own word and, under it, a short caption naming
/// where that figure comes from. `Régie` draws no chain — it is not a stage of anything, and its
/// own first paragraph says so. Under the chain, one sentence says how a step
/// becomes the next; the page below it is the detail. **This widget writes nothing** — like
/// `OcptBudgetRegie` (`docs/architecture/budget.md`), it carries no `isReadOnly` flag at all, and
/// is offered identically under a previewed version.
///
/// **M1 only re-keys this panel to the four-chip shape** — [view] and [toolsView] together answer
/// every question this file used to ask of the retired seven-view `OcptBudgetView` alone, reusing
/// the very same title/subtitle/body strings each route already read before the rework: `dashboard`,
/// `expenses` and `tools › cashFlow` read the expenses chain exactly as `dashboard`/`costTracking`/
/// `cashJournal` did; `resources` reads the resources chain exactly as `financing` did; `tools ›
/// sharing` reads the sharing chain exactly as `sharing` did; `tools › regie` draws no chain, exactly
/// as `regie` did. The wording itself is M5's to rewrite.
class OcptBudgetHelp extends StatelessWidget {
  /// Which of the mode's four chips the help follows.
  final OcptBudgetView view;

  /// Which of the tools drawer's own three pages the help follows, while [view] is
  /// [OcptBudgetView.tools] — read even while it is not, but then ignored by every switch below.
  final OcptBudgetToolsView toolsView;

  /// Class constructor
  const OcptBudgetHelp({super.key, required this.view, required this.toolsView});

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

  /// The chain [_OcptBudgetHelpChain] draws for the current route, or empty on `tools › regie` —
  /// see the class doc comment for why régie draws none.
  ///
  /// `tools › cashFlow` reads the very same chain as `expenses`: it is that document's own middle
  /// state, seen on its own page, never a chain of its own. **[OcptBudgetView.dashboard] reads it
  /// too, for the same reason**: its KPI tiles are that very chain's own figures, read at the
  /// whole-project level rather than poste by poste, so the chain that explains them is the very
  /// one that already explains the other two.
  List<(String label, String caption)> _chainStepsOf(Tr tr) => switch ((view, toolsView)) {
    (OcptBudgetView.tools, OcptBudgetToolsView.regie) => const [],
    (OcptBudgetView.dashboard, _) || (OcptBudgetView.expenses, _) => _expensesChainSteps(tr),
    (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => _expensesChainSteps(tr),
    (OcptBudgetView.resources, _) => _resourcesChainSteps(tr),
    (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => _sharingChainSteps(tr),
  };

  /// The expenses chain: a quote line, resolved as [Tr.budgetFicheStepEstimatedLabel] — the very
  /// word the fiche's own stepper already shows for it — becomes a commitment
  /// ([Tr.budgetInspectorFigureCommitted]), settled by an entry ([Tr.budgetInspectorFigurePaid]).
  List<(String, String)> _expensesChainSteps(Tr tr) => [
    (tr.budgetFicheStepEstimatedLabel, tr.budgetHelpChainExpensesEstimatedCaption),
    (tr.budgetInspectorFigureCommitted, tr.budgetHelpChainExpensesCommittedCaption),
    (tr.budgetInspectorFigurePaid, tr.budgetHelpChainExpensesPaidCaption),
  ];

  /// [OcptBudgetView.resources]' own chain: a resource or a taking is promised
  /// ([Tr.budgetFicheStepPromisedLabel]), and becomes received ([Tr.budgetFinancingColumnReceived])
  /// the moment a journal entry names it — no hand-typed step in between, unlike the expenses
  /// chain's own commitment.
  List<(String, String)> _resourcesChainSteps(Tr tr) => [
    (tr.budgetFicheStepPromisedLabel, tr.budgetHelpChainResourcesPromisedCaption),
    (tr.budgetFinancingColumnReceived, tr.budgetHelpChainResourcesReceivedCaption),
  ];

  /// `tools › sharing`'s own chain: the takings received ([Tr.budgetFinancingColumnReceived]
  /// — read from [OcptBudgetView.resources], not typed here) become what has already been repaid
  /// ([Tr.budgetSharingRepaidLabel]) and what is left to share ([Tr.budgetSharingLeftToShareLabel]).
  List<(String, String)> _sharingChainSteps(Tr tr) => [
    (tr.budgetFinancingColumnReceived, tr.budgetHelpChainSharingReceivedCaption),
    (tr.budgetSharingRepaidLabel, tr.budgetHelpChainSharingRepaidCaption),
    (tr.budgetSharingLeftToShareLabel, tr.budgetHelpChainSharingLeftToShareCaption),
  ];

  /// The sentence printed under the chain, or null on `tools › regie` where [_chainStepsOf] is
  /// already empty and nothing is printed at all.
  String? _chainSentenceOf(Tr tr) => switch ((view, toolsView)) {
    (OcptBudgetView.tools, OcptBudgetToolsView.regie) => null,
    (OcptBudgetView.dashboard, _) || (OcptBudgetView.expenses, _) => tr.budgetHelpChainExpensesSentence,
    (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => tr.budgetHelpChainExpensesSentence,
    (OcptBudgetView.resources, _) => tr.budgetHelpChainResourcesSentence,
    (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => tr.budgetHelpChainSharingSentence,
  };

  /// Which of [_chainStepsOf]'s own steps is the current route's own — "you are here" — or null
  /// where none stands for it in particular.
  ///
  /// **`expenses` and [OcptBudgetView.resources] both highlight nothing.** Each reads every one of
  /// its own columns at once — the cost report a poste's estimate, commitment and payment side by
  /// side, the resources tree a row's promise and its receipt side by side — so no single step of
  /// the chain is the one it stands in, unlike `tools › cashFlow` (a payment, the chain's own
  /// `Paid` step). Saying so a second time under the chain would only restate what "nothing
  /// highlighted" already says; the sentence there is left to state how a step becomes the next
  /// instead, exactly as every other route's does. `tools › sharing` highlights nothing for the
  /// same reason: it reads its three states together, in one card and one table, rather than
  /// opening on one of them. [OcptBudgetView.dashboard] highlights nothing for the very same
  /// reason as `expenses`: its KPI tiles read the quoted, paid and committed figures side by side,
  /// not one step of the chain in particular.
  int? _highlightedStepIndexOf() => switch ((view, toolsView)) {
    (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => 2,
    (OcptBudgetView.dashboard, _) ||
    (OcptBudgetView.expenses, _) ||
    (OcptBudgetView.resources, _) ||
    (OcptBudgetView.tools, OcptBudgetToolsView.regie) ||
    (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => null,
  };

  /// The current route's own heading — the very word its band shows above the centre, so the
  /// reader finds the same name here as on screen (`OcptBudgetHeader._titleOf`'s own reasoning,
  /// reimplemented here rather than shared, since that method is private to that widget).
  String _titleOf(Tr tr) => switch ((view, toolsView)) {
    (OcptBudgetView.dashboard, _) => tr.budgetHeaderDashboardTitle,
    (OcptBudgetView.expenses, _) => tr.budgetHeaderTitle,
    (OcptBudgetView.resources, _) => tr.budgetHeaderResourcesTitle,
    (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => tr.budgetHeaderCashJournalTitle,
    (OcptBudgetView.tools, OcptBudgetToolsView.regie) => tr.budgetHeaderRegieTitle,
    (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => tr.budgetHeaderSharingTitle,
  };

  /// The current route's own one-line subtitle, exactly as the header band prints it.
  String _subtitleOf(Tr tr) => switch ((view, toolsView)) {
    (OcptBudgetView.dashboard, _) => tr.budgetHeaderDashboardSubtitle,
    (OcptBudgetView.expenses, _) => tr.budgetHeaderSubtitle,
    (OcptBudgetView.resources, _) => tr.budgetHeaderFinancingSubtitle,
    (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => tr.budgetHeaderCashJournalSubtitle,
    (OcptBudgetView.tools, OcptBudgetToolsView.regie) => tr.budgetHeaderRegieSubtitle,
    (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => tr.budgetHeaderSharingSubtitle,
  };

  /// The current route's own explanation, one short paragraph per entry — the substance
  /// `docs/architecture/budget.md` states, in plain language, with every cross-reference to a
  /// figure or another route worded exactly as its own label or chip already reads.
  ///
  /// **No route opens on a shared capture-band paragraph any more.** `OcptBudgetCaptureBand` is
  /// gone: `expenses` and `resources` now carry their own header button opening the entry wizard,
  /// `tools › cashFlow` carries none at all, and each of the three describes what it draws through
  /// its own paragraphs rather than a shared opening line about a control only two of them still
  /// have. [OcptBudgetView.dashboard]'s own four paragraphs work through what the chain above
  /// already introduces — the tiles, the needs/resources balance band and the standing alerts, each
  /// in the order they draw. There is no fifth paragraph for a feed card any more: the dashboard
  /// summarises the other pages and nothing else, and a card that only ever navigated elsewhere
  /// left with it.
  List<String> _bodyOf(Tr tr) => switch ((view, toolsView)) {
    (OcptBudgetView.dashboard, _) => [
      tr.budgetHelpDashboardBody1,
      tr.budgetHelpDashboardBody2(tr.budgetHeaderExpensesSegmentLabel),
      tr.budgetHelpDashboardBody3,
      tr.budgetHelpDashboardBody4(tr.budgetHeaderDashboardSegmentLabel),
    ],
    (OcptBudgetView.tools, OcptBudgetToolsView.regie) => [
      tr.budgetHelpRegieBody1,
      tr.budgetHelpRegieBody2,
      tr.budgetHelpRegieBody3,
      tr.budgetHelpRegieBody4,
      tr.budgetHelpRegieBody5(tr.budgetHeaderExpensesSegmentLabel),
    ],
    (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => [
      tr.budgetHelpCashJournalIntro(tr.budgetHeaderExpensesSegmentLabel),
      tr.budgetHelpCashJournalBody1(tr.budgetCashJournalColumnDebit, tr.budgetCashJournalColumnCredit),
      tr.budgetHelpCashJournalBody2(tr.budgetCostTrackingOffQuoteLabel),
      tr.budgetHelpCashJournalBody3(tr.budgetCashJournalColumnBalance),
      tr.budgetHelpCashJournalBody4,
    ],
    (OcptBudgetView.expenses, _) => [
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
    (OcptBudgetView.resources, _) => [
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
    (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => [
      tr.budgetHelpSharingBody1(tr.budgetHeaderResourcesSegmentLabel),
      tr.budgetHelpSharingBody2,
      tr.budgetHelpSharingBody3,
    ],
  };
}

/// The chain every route but `tools › regie` opens with: the states the current route's own
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
