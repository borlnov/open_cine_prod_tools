// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_tree.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_amounts_header_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_amounts_total_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_compact_cards.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_creation_footer.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_empty_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_identity_header_cell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_identity_total_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_line_amounts_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_off_quote_amounts_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_off_quote_identity_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_poste_amounts_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_poste_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_poste_figures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_poste_identity_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_sub_amounts_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_sub_identity_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_sub_label.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_totals.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_tree_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_feed_card.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';

/// The budget mode's cost-tracking view: the expenses tree — one row per poste, opening onto its
/// own quote lines, each of those opening onto its own commitments and the entries that settle
/// them, the poste's own off-line commitments and entries drawn at a quote line's own indentation
/// once it is open — then a total row, then a `+ Poste` creation footer.
///
/// **The `N°` and `Poste` columns are pinned**, drawn in their own pane at the left edge that
/// never moves; only the six amount columns and the trailing `⋮` menu, in a second pane to their
/// right, scroll horizontally once the centre dock narrows past
/// [ocptBudgetCostTrackingPosteColumnMinWidth] — a poste nobody can name is worse than a figure nobody
/// can read yet, so a row's own identity survives the scroll even when its own numbers no longer
/// fit. The two panes share one vertical scroll, so the whole table still moves together, and, row
/// for row, the exact same height ([ocptBudgetCostTrackingRowHeight]'s and
/// [ocptBudgetCostTrackingSubRowHeight]'s own doc comments argue why).
///
/// **The tree is flattened once, top to bottom, into [_rowsOf]' own list**, and both panes then
/// walk that very same list, row for row — never two independent walks that could drift apart on
/// which rows are actually on screen.
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather
/// than a null callback per affordance, and hands its own writing affordances — the creation
/// footer, a poste row's own `⋮` menu, a commitment or an entry sub-row's own `⋮` menu, the reorder
/// they open onto — the null callbacks that withhold them under a version preview, so a control
/// added later here can't be gated in one place and forgotten in the other.
///
/// **A project with no live poste at all draws [OcptBudgetFeedCard] in place of the two-pane
/// table**, centred and width-constrained, above the very same `+ Poste` creation footer this view
/// always draws — the way through to a first poste before there is a table for it to belong to.
/// Every one of the card's own three rows is offered here, unlike `OcptBudgetRegie`'s own copy: no
/// page this empty state could be standing on names itself.
///
/// [isSimplified] switches every poste's own displayed name between [OcptBudgetPoste.simpleLabel]
/// (falling back to [OcptBudgetPoste.label] when null) and [OcptBudgetPoste.label] itself, and
/// hides the `N°` column — a display switch over the same data, never a second read.
///
/// [paidByPosteId] and [committedCentsOf] read the cash journal's own per-poste totals
/// (`OcptBudgetState.paidByPosteId`/`committedCentsOf`, backed by
/// `lib/models/rules/ocpt_budget_journal.dart`/`ocpt_budget_projection.dart`): a poste with no
/// entry or commitment against it answers **0**, honestly, rather than a stand-in for an unknown
/// figure — the journal exists and is kept, so "nothing has moved" is a fact this table can state
/// outright. `Payé`, `Engagé`, `Reste` and `Écart` therefore always print a real amount at poste
/// level. A quote line's own `Engagé`/`Payé` are read the very same honest way, through
/// [ocptBudgetLineCommittedTotalOf]/[ocptBudgetLinePaidTotalOf] — pure functions of [commitments]
/// and [entries], narrowed to the one line each row draws.
///
/// **`Coût final` reads [ocptBudgetFinalCostCents] over the resolved estimate to complete** —
/// [OcptBudgetPoste.estimateToCompleteCents] through [ocptBudgetEstimateToCompleteCents] at poste
/// level, resolved once per row, not once per cell; **always derived** at line level, since the
/// estimate a human can type is held per poste, never per line
/// (`docs/architecture/budget.md`). `Écart` keeps reading [ocptBudgetVarianceCents] exactly
/// as it always has: the two readings answer different questions and both stay on screen. Neither
/// `Estimate to complete` nor `Consumed` is drawn as its own column any more — the reading behind
/// `Coût final` survives their removal exactly as before.
///
/// **A quote line with no commitment and no entry under it draws no twisty at all** — an empty
/// expansion is worse than none. A line-nested commitment or an entry sub-row draws no twisty of
/// its own: such a commitment's own child — the entry that settled it, or, while it is still owed,
/// the muted `tr.budgetCostTrackingNoEntryHint` row — shows or hides wholesale with whichever line,
/// or poste, it sits directly under. **A poste's own off-line commitment is the exception**: with
/// no quote line to nest under, a paid one is itself an expandable node, keyed in
/// `OcptBudgetState.expandedNodeIds` by its own id, its payments drawn a level deeper only while it
/// is expanded — so a settled off-line commitment reads as one row, not as itself beside a
/// same-named payment.
///
/// **A commitment sub-row prints its own amount in `Engagé` while unsettled, in `Payé` once
/// settled, and the em dash in every other column; an entry sub-row prints its own debit in `Payé`
/// and the em dash elsewhere** — the mockup's own reading, and the reason the "no entry" hint row
/// exists at all: an unsettled commitment has nothing of its own to show under
/// [ocptBudgetEntryDebitCentsOf], so the hint says why in words instead of drawing nothing.
///
/// **`_rowsOf` folds one extra row into the tree, `Off quote`, after the last poste and before
/// the `Total` row** — the total of every debit naming no poste at all
/// (`ocptBudgetOffQuotePaidTotalOf`, `lib/models/rules/ocpt_budget_journal.dart`), which
/// [paidByPosteId] never keys at all. It is drawn only while some such debit exists and only its
/// own `Payé` cell carries a figure; it is not a poste, so it carries no `N°`, no `⋮` menu and no
/// selection of its own — see `OcptBudgetCostTrackingOffQuoteIdentityRow`'s own doc comment. **It gains
/// a twisty, opening onto the very debits it sums**, each an ordinary entry sub-row keyed by the
/// reserved [ocptBudgetCostTrackingOffQuoteNodeId] rather than by a poste or a line id, since the row
/// sums a reading over the journal and names no record of its own to key one by. An entry drawn
/// here that also settles a commitment nested under some poste is not excluded the way a poste's
/// own off-line entries are — `_rowsOf`' own doc comment argues why it legitimately appears in
/// both places. The total row's own `Payé` cell then folds [paidByPosteId] and [offQuoteTotal]
/// together ([ocptBudgetCoveredTotalsFoldOf]), since together they are what actually left the
/// account.
///
/// **A row's own `Rename` menu entry selects it and opens the `Inspector` tab rather than editing
/// its name in place.** This app has no precedent for renaming a record inline inside a plain list
/// — the two inline-answer exceptions the confirm-dialog rule already carries (the `Versions` dock
/// panel, the project dictionary dialog) exist because a list of rows there has no other way of
/// saying *which* row is being talked about, which is not this table's problem: every row already
/// opens straight onto its own poste's fields the moment it is clicked. A poste's own `Label` and
/// `Code` fields living in its inspector, exactly where a person's or an element's own name field
/// lives in the resources mode's sheets, is the reading this table follows instead. A quote line's
/// own fields live there too, so a line sub-row carries no `⋮` menu at all.
///
/// **A poste row's own menu also carries `Show this poste only`**, the gesture that narrows the
/// whole mode to it — the retired left dock card's own `⋮` entry, ported here now that picking a
/// poste to filter by has nowhere else to live. It only ever reads the project, so it draws (and
/// works) even under a read-only preview, the one entry of this menu that is never withheld.
///
/// **At a compact width (`ocptIsCompactWidth`), the two-pane table gives way to one
/// [OcptBudgetCostTrackingPosteCard] per live poste**, scrolling vertically, above the very same
/// `+ Poste` creation footer. A card draws a poste's own name, a proportion bar reading its own
/// paid/committed amounts against its quote (`OcptBudgetCostTrackingCardProportionBar`, the very colours
/// `OcptBudgetFiche`'s own poste-variant bar already uses for the same figures), and its own
/// `Engagé`/`Payé`/`Reste`/`Écart` figures — read through [OcptBudgetCostTrackingPosteFigures.of], the
/// very same calls [OcptBudgetCostTrackingPosteAmountsRow] makes for its own row, so a card never
/// disagrees with the table over the same poste. Tapping a card selects its poste exactly as
/// tapping either half of its row does — [onPosteSelected] is never withheld under
/// [isReadOnly], selecting a poste being a read, not a write. Only the tree — quote lines,
/// commitments, entries, the off-quote reading — is reduced away at this width; the table above the
/// breakpoint is unchanged.
class OcptBudgetCostTracking extends StatelessWidget {
  /// Every live poste, in display order.
  final List<OcptBudgetPoste> postes;

  /// Every live commitment of the project, settled or not — narrowed, row by row, to the one line
  /// or poste each sub-row draws.
  final List<OcptBudgetCommitment> commitments;

  /// Every live journal entry of the project — narrowed the same way [commitments] is.
  final List<OcptBudgetEntry> entries;

  /// What is currently selected for the right dock's own fiche, or null while none is.
  final OcptBudgetSelection? selection;

  /// Which nodes of the tree are currently expanded — a poste id or a quote line id, see
  /// `OcptBudgetState.expandedNodeIds`'s own doc comment.
  final Set<String> expandedNodeIds;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// What has actually been paid against each poste, keyed by its own id — see the class doc
  /// comment.
  final Map<String, OcptBudgetCoveredTotal> paidByPosteId;

  /// A poste's own committed total, in cents, tax-inclusive — see the class doc comment.
  final int Function(String posteId) committedCentsOf;

  /// A poste's own in-kind covered total, in cents — the settled bucket a counterpart quote line
  /// contributes (`OcptBudgetState.inKindCoveredCentsOf`), folded alongside [paidByPosteId] and
  /// [committedCentsOf] into `Reste`/`Écart` so a counterpart line never reads as an unspent
  /// remainder — see `lib/models/rules/ocpt_budget_totals.dart`'s own doc comments.
  final int Function(String posteId) inKindCoveredCentsOf;

  /// The total of every debit that names no poste at all — see the class doc comment.
  final OcptBudgetCoveredTotal offQuoteTotal;

  /// How many live elements a live quote line already prices — [OcptBudgetFeedCard]'s own
  /// breakdown row, drawn while [postes] is empty.
  final int breakdownPricedElementCount;

  /// How many live elements no live line prices yet — [OcptBudgetFeedCard]'s own breakdown row,
  /// beside [breakdownPricedElementCount].
  final int breakdownUnpricedElementCount;

  /// How many shooting days the schedule holds — [OcptBudgetFeedCard]'s own schedule row.
  final int shootingDayCount;

  /// How many meals the schedule's own presences produce — [OcptBudgetFeedCard]'s own catering
  /// row.
  final int mealCount;

  /// How many heads the buffet serves, from the schedule's own presences — [OcptBudgetFeedCard]'s
  /// own catering row, beside [mealCount].
  final int buffetCount;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called with a poste's id when its row is clicked, opening the `Inspector` tab on it.
  final ValueChanged<String> onPosteSelected;

  /// Called with a quote line's id when its row is clicked, opening the `Inspector` tab on the
  /// poste it belongs to.
  final ValueChanged<String> onLineSelected;

  /// Called with a commitment's id when its row is clicked, opening the `Inspector` tab on the
  /// poste it belongs to.
  final ValueChanged<String> onCommitmentSelected;

  /// Called with an entry's id when its row is clicked, opening the `Inspector` tab on the poste
  /// it belongs to.
  final ValueChanged<String> onEntrySelected;

  /// Called with a poste's or a quote line's own id when its twisty is clicked.
  final ValueChanged<String> onNodeExpansionToggled;

  /// Called when the footer's `+ Poste` action is clicked, or null while [isReadOnly].
  final VoidCallback? onPosteCreationRequested;

  /// Called with a poste's id and whether it moves up (`true`) or down (`false`), from a row's own
  /// `⋮` menu, or null while [isReadOnly]. `moveUp` is named, never positional, so a call site
  /// reads which direction it means rather than a bare `true`/`false`.
  final void Function(String posteId, {required bool moveUp})? onPosteReorderRequested;

  /// Called with a poste's id when a row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onPosteDeletionRequested;

  /// Called with a poste's id when a row's own `⋮` menu asks to narrow the mode to it — the left
  /// dock card's own gesture, ported rather than reinvented now that picking a poste to filter by
  /// lives here. It only ever reads the project, so it is **not** withheld under a read-only
  /// preview, unlike every other entry of this same menu.
  final ValueChanged<String>? onPosteFilterRequested;

  /// Called with a commitment when its sub-row's own `⋮` menu asks to edit it, or null while
  /// [isReadOnly]. Opens `OcptBudgetCommitmentDialog`.
  final ValueChanged<OcptBudgetCommitment>? onCommitmentEditRequested;

  /// Called with a commitment when its sub-row's own `⋮` menu asks to record its payment (only
  /// offered while it isn't settled yet), or null while [isReadOnly]. Opens
  /// `OcptBudgetEntryDialog` pre-filled from the commitment.
  final ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested;

  /// Called with a commitment's id when its sub-row's own `⋮` menu asks to undo its settlement
  /// (only offered while it is settled), or null while [isReadOnly].
  final ValueChanged<String>? onCommitmentUnsettleRequested;

  /// Called with a commitment's id when its sub-row's own `⋮` menu asks to delete it, or null
  /// while [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching
  /// anything.
  final ValueChanged<String>? onCommitmentDeletionRequested;

  /// Called with an entry when its sub-row's own `⋮` menu asks to edit it, or null while
  /// [isReadOnly]. Opens `OcptBudgetEntryDialog`.
  final ValueChanged<OcptBudgetEntry>? onEntryEditRequested;

  /// Called with an entry's id when its sub-row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onEntryDeletionRequested;

  /// Called when the empty state's own [OcptBudgetFeedCard] breakdown row is clicked.
  final VoidCallback onBreakdownFeedRequested;

  /// Called when the empty state's own [OcptBudgetFeedCard] schedule row is clicked.
  final VoidCallback onScheduleFeedRequested;

  /// Called when the empty state's own [OcptBudgetFeedCard] catering row is clicked.
  final VoidCallback onCateringFeedRequested;

  /// Class constructor
  const OcptBudgetCostTracking({
    super.key,
    required this.postes,
    required this.commitments,
    required this.entries,
    required this.selection,
    required this.expandedNodeIds,
    required this.isSimplified,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.paidByPosteId,
    required this.committedCentsOf,
    required this.inKindCoveredCentsOf,
    required this.offQuoteTotal,
    required this.breakdownPricedElementCount,
    required this.breakdownUnpricedElementCount,
    required this.shootingDayCount,
    required this.mealCount,
    required this.buffetCount,
    required this.isReadOnly,
    required this.onPosteSelected,
    required this.onLineSelected,
    required this.onCommitmentSelected,
    required this.onEntrySelected,
    required this.onNodeExpansionToggled,
    required this.onPosteCreationRequested,
    required this.onPosteReorderRequested,
    required this.onPosteDeletionRequested,
    required this.onPosteFilterRequested,
    required this.onCommitmentEditRequested,
    required this.onCommitmentSettleRequested,
    required this.onCommitmentUnsettleRequested,
    required this.onCommitmentDeletionRequested,
    required this.onEntryEditRequested,
    required this.onEntryDeletionRequested,
    required this.onBreakdownFeedRequested,
    required this.onScheduleFeedRequested,
    required this.onCateringFeedRequested,
  });

  /// Build the budget cost tracking as a [LayoutBuilder].
  @override
  Widget build(BuildContext context) {
    if (postes.isEmpty) {
      return OcptBudgetCostTrackingEmptyState(
        breakdownPricedElementCount: breakdownPricedElementCount,
        breakdownUnpricedElementCount: breakdownUnpricedElementCount,
        shootingDayCount: shootingDayCount,
        mealCount: mealCount,
        buffetCount: buffetCount,
        onBreakdownFeedRequested: onBreakdownFeedRequested,
        onScheduleFeedRequested: onScheduleFeedRequested,
        onCateringFeedRequested: onCateringFeedRequested,
        onPosteCreationRequested: isReadOnly ? null : onPosteCreationRequested,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (ocptIsCompactWidth(constraints.maxWidth)) {
          return OcptBudgetCostTrackingCompactCards(
            postes: postes,
            isSimplified: isSimplified,
            taxBasis: taxBasis,
            defaultVatRateBasisPoints: defaultVatRateBasisPoints,
            currencyCode: currencyCode,
            paidByPosteId: paidByPosteId,
            committedCentsOf: committedCentsOf,
            inKindCoveredCentsOf: inKindCoveredCentsOf,
            isPosteSelected: _isPosteSelected,
            onPosteSelected: onPosteSelected,
            onPosteCreationRequested: isReadOnly ? null : onPosteCreationRequested,
          );
        }

        final allLines = [for (final poste in postes) ...poste.lines];
        final total = ocptBudgetTotalOf(
          allLines,
          basis: taxBasis,
          projectVatRateBasisPoints: defaultVatRateBasisPoints,
        );
        final coveredPosteCount = ocptBudgetCostTrackingCoveredPosteCountOf(
          postes,
          taxBasis: taxBasis,
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
        );
        final paidTotal = ocptBudgetCoveredTotalsFoldOf([...paidByPosteId.values, offQuoteTotal]);
        final finalCostCents = ocptBudgetCostTrackingFinalCostTotalOf(
          postes,
          taxBasis: taxBasis,
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          paidByPosteId: paidByPosteId,
          committedCentsOf: committedCentsOf,
          inKindCoveredCentsOf: inKindCoveredCentsOf,
        );
        final rows = _rowsOf();

        final identityFixedWidth = isSimplified ? 0.0 : ocptBudgetCostTrackingNumberColumnWidth;
        // Devis, Engagé, Payé, Reste, Coût final, Écart — six amount columns.
        final amountsWidth =
            6 * ocptBudgetCostTrackingAmountColumnWidth + ocptBudgetCostTrackingMenuColumnWidth;
        final posteWidth = (constraints.maxWidth - identityFixedWidth - amountsWidth).clamp(
          ocptBudgetCostTrackingPosteColumnMinWidth,
          double.infinity,
        );
        final pinnedWidth = identityFixedWidth + posteWidth;
        final showFooter = !isReadOnly && onPosteCreationRequested != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: pinnedWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OcptBudgetCostTrackingIdentityHeaderCell(
                            isSimplified: isSimplified,
                            posteWidth: posteWidth,
                          ),
                          for (final row in rows) _identityRowOf(row, posteWidth: posteWidth),
                          OcptBudgetCostTrackingIdentityTotalRow(
                            isSimplified: isSimplified,
                            posteWidth: posteWidth,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: OcptHorizontalScrollView(
                        child: SizedBox(
                          width: amountsWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const OcptBudgetCostTrackingAmountsHeaderRow(),
                              for (final row in rows) _amountsRowOf(row),
                              OcptBudgetCostTrackingAmountsTotalRow(
                                total: total,
                                paidTotal: paidTotal,
                                finalCostCents: finalCostCents,
                                currencyCode: currencyCode,
                                posteCount: postes.length,
                                coveredPosteCount: coveredPosteCount,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showFooter) OcptBudgetCostTrackingCreationFooter(onTap: onPosteCreationRequested!),
          ],
        );
      },
    );
  }

  /// The whole tree, flattened top to bottom into one list both panes walk in lockstep — see the
  /// class doc comment.
  ///
  /// A poste draws whenever it is live, whatever [expandedNodeIds] holds; its own children —
  /// [OcptBudgetPoste.lines], then its off-line commitments and entries — draw only while its own
  /// id is in [expandedNodeIds]. A quote line's own children — its commitments, and, for each one,
  /// either every entry that has paid it so far or the muted "no entry" hint while none has — draw
  /// only while the line's own id is in [expandedNodeIds] too. **A poste's own off-line commitment
  /// that has been paid is itself an expandable node**, keyed in [expandedNodeIds] by its own id:
  /// collapsed it is one row, and its payments draw a level deeper only while it is expanded — a
  /// line-less commitment owning its payments the way a line owns its commitments.
  ///
  /// **The off-quote row follows the last poste, drawn exactly as it always was — only while
  /// [offQuoteTotal] holds something ([OcptBudgetCoveredTotal.lineCount] above zero).** Its own
  /// children — every debit naming no poste at all — draw only while
  /// [ocptBudgetCostTrackingOffQuoteNodeId] is in [expandedNodeIds] too. Unlike a poste's own off-line
  /// entries, this list is **not** narrowed by `settlingEntryIds`: a poste-less debit that also
  /// settles a commitment nested under some poste is exactly the case the off-quote total sums, and
  /// hiding it here because it is reachable elsewhere would leave the total's own children not
  /// actually adding up to the figure it prints. It legitimately draws twice — once here, once
  /// nested under the commitment it settles — and that is the honest reading of a poste-less
  /// payment that happens to also be a settlement.
  List<OcptBudgetCostTrackingTreeRow> _rowsOf() {
    final rows = <OcptBudgetCostTrackingTreeRow>[];
    // Every entry naming a commitment at all, settled or still owed — an off-line entry list must
    // never repeat one of these, since [_addCommitmentRows] already draws every one of them nested
    // under the very commitment it pays, whether that commitment is settled yet or only part-paid.
    final settlingEntryIds = {
      for (final entry in entries)
        if (entry.commitmentId != null) entry.id,
    };

    for (final poste in postes) {
      final offLineCommitments = [
        for (final commitment in commitments)
          if (commitment.posteId == poste.id && commitment.lineId == null) commitment,
      ];
      final offLineEntries = [
        for (final entry in entries)
          if (entry.posteId == poste.id && !settlingEntryIds.contains(entry.id)) entry,
      ];
      final isPosteExpandable =
          poste.lines.isNotEmpty || offLineCommitments.isNotEmpty || offLineEntries.isNotEmpty;
      final isPosteExpanded = isPosteExpandable && expandedNodeIds.contains(poste.id);

      rows.add(
        OcptBudgetCostTrackingPosteTreeRow(
          poste: poste,
          isExpandable: isPosteExpandable,
          isExpanded: isPosteExpanded,
        ),
      );
      if (!isPosteExpanded) {
        continue;
      }

      for (final line in poste.lines) {
        final lineCommitments = [
          for (final commitment in commitments)
            if (commitment.lineId == line.id) commitment,
        ];
        final isLineExpanded = lineCommitments.isNotEmpty && expandedNodeIds.contains(line.id);

        rows.add(
          OcptBudgetCostTrackingLineTreeRow(
            line: line,
            lineCommitments: lineCommitments,
            isExpanded: isLineExpanded,
          ),
        );
        if (!isLineExpanded) {
          continue;
        }

        _addCommitmentRows(rows, lineCommitments, depth: 2);
      }

      // A poste's own off-line commitment has no quote line to nest under, so it is the expandable
      // node itself: collapsed by default, it draws as one row, and its payments — drawn a level
      // deeper, unlike a line-nested commitment's own siblings — show only once it is expanded, the
      // way a quote line reveals its commitments. A commitment nobody has paid yet is not
      // expandable (its status badge already says it is still owed, so an empty expansion would say
      // nothing).
      for (final commitment in offLineCommitments) {
        final paymentEntries = [
          for (final entry in entries)
            if (entry.commitmentId == commitment.id) entry,
        ];
        final isCommitmentExpanded =
            paymentEntries.isNotEmpty && expandedNodeIds.contains(commitment.id);
        rows.add(
          OcptBudgetCostTrackingCommitmentTreeRow(
            commitment: commitment,
            depth: 1,
            isExpandable: paymentEntries.isNotEmpty,
            isExpanded: isCommitmentExpanded,
          ),
        );
        if (isCommitmentExpanded) {
          for (final entry in paymentEntries) {
            rows.add(OcptBudgetCostTrackingEntryTreeRow(entry: entry, depth: 2));
          }
        }
      }
      for (final entry in offLineEntries) {
        rows.add(OcptBudgetCostTrackingEntryTreeRow(entry: entry, depth: 1));
      }
    }

    if (offQuoteTotal.lineCount > 0) {
      // The very same predicate `ocptBudgetOffQuotePaidTotalOf` sums, so this row's own children
      // always add up to the figure it prints — see this method's own doc comment for why
      // `settlingEntryIds` is deliberately not applied here.
      final offQuoteEntries = [
        for (final entry in entries)
          if (entry.posteId == null && entry.debitCents != 0) entry,
      ];
      final isOffQuoteExpanded = expandedNodeIds.contains(ocptBudgetCostTrackingOffQuoteNodeId);
      rows.add(OcptBudgetCostTrackingOffQuoteTreeRow(isExpanded: isOffQuoteExpanded));
      if (isOffQuoteExpanded) {
        for (final entry in offQuoteEntries) {
          rows.add(OcptBudgetCostTrackingEntryTreeRow(entry: entry, depth: 1));
        }
      }
    }

    return rows;
  }

  /// Appends one row per commitment of [rowCommitments], each immediately followed by every entry
  /// that pays it (found in [entries], through `OcptBudgetEntry.commitmentId`) whenever it has been
  /// paid at all — settled or only part-paid, one row per instalment — or by the muted "no entry"
  /// hint while genuinely none has paid it yet — all at [depth], siblings of the commitment itself,
  /// never a level deeper.
  ///
  /// This is the **line-nested** path alone: a commitment shown under its own quote line, its
  /// payments its siblings under that line. A poste's own off-line commitment is drawn by
  /// [_rowsOf] directly instead, as an expandable node owning its payments a level deeper — see
  /// [OcptBudgetCostTrackingCommitmentTreeRow.isExpandable].
  void _addCommitmentRows(
    List<OcptBudgetCostTrackingTreeRow> rows,
    List<OcptBudgetCommitment> rowCommitments, {
    required int depth,
  }) {
    for (final commitment in rowCommitments) {
      rows.add(OcptBudgetCostTrackingCommitmentTreeRow(commitment: commitment, depth: depth));

      final paymentEntries = [
        for (final entry in entries)
          if (entry.commitmentId == commitment.id) entry,
      ];
      if (paymentEntries.isEmpty) {
        rows.add(OcptBudgetCostTrackingCommitmentHintTreeRow(depth: depth));
      } else {
        for (final entry in paymentEntries) {
          rows.add(OcptBudgetCostTrackingEntryTreeRow(entry: entry, depth: depth));
        }
      }
    }
  }

  /// The pinned pane's own widget for [row].
  Widget _identityRowOf(OcptBudgetCostTrackingTreeRow row, {required double posteWidth}) =>
      switch (row) {
        OcptBudgetCostTrackingPosteTreeRow() => OcptBudgetCostTrackingPosteIdentityRow(
          poste: row.poste,
          isSelected: _isPosteSelected(row.poste.id),
          isSimplified: isSimplified,
          posteWidth: posteWidth,
          isExpandable: row.isExpandable,
          isExpanded: row.isExpanded,
          onTap: () => onPosteSelected(row.poste.id),
          onTwistyTap: () => onNodeExpansionToggled(row.poste.id),
        ),
        OcptBudgetCostTrackingLineTreeRow() => OcptBudgetCostTrackingSubIdentityRow(
          depth: 1,
          isSimplified: isSimplified,
          posteWidth: posteWidth,
          isSelected: _isLineSelected(row.line.id),
          isSmall: false,
          isExpandable: row.isExpandable,
          isExpanded: row.isExpanded,
          onTwistyTap: () => onNodeExpansionToggled(row.line.id),
          onTap: () => onLineSelected(row.line.id),
          builder: (context) {
            final tr = Tr.of(context);
            final label = row.line.label;
            final isInKindCounterpart = row.line.inKindResourceId != null;
            return OcptBudgetCostTrackingSubLabel(
              label: label.isEmpty ? tr.budgetLineUnnamed : label,
              isItalic: label.isEmpty,
              badgeText: isInKindCounterpart ? tr.budgetCostTrackingInKindLineBadge : null,
              badgeColor: isInKindCounterpart ? Theme.of(context).colorScheme.primary : null,
            );
          },
        ),
        OcptBudgetCostTrackingCommitmentTreeRow() => OcptBudgetCostTrackingSubIdentityRow(
          depth: row.depth,
          isSimplified: isSimplified,
          posteWidth: posteWidth,
          isSelected: _isCommitmentSelected(row.commitment.id),
          isSmall: true,
          isExpandable: row.isExpandable,
          isExpanded: row.isExpanded,
          onTwistyTap: row.isExpandable ? () => onNodeExpansionToggled(row.commitment.id) : null,
          onTap: () => onCommitmentSelected(row.commitment.id),
          builder: (context) {
            final tr = Tr.of(context);
            final isSettled = ocptBudgetCommitmentIsSettledOf(
              row.commitment,
              entries,
              projectVatRateBasisPoints: defaultVatRateBasisPoints,
            );
            return OcptBudgetCostTrackingSubLabel(
              label: row.commitment.label,
              isMuted: true,
              dotColor: isSettled
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : ocptBudgetCommitmentStatusAccentColor(
                      Theme.of(context).colorScheme,
                      row.commitment.status,
                    ),
              badgeText: isSettled
                  ? tr.budgetCommittedStatusSettledLabel
                  : ocptBudgetCommitmentStatusLabel(tr, row.commitment.status),
              badgeColor: isSettled
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : ocptBudgetCommitmentStatusAccentColor(
                      Theme.of(context).colorScheme,
                      row.commitment.status,
                    ),
            );
          },
        ),
        OcptBudgetCostTrackingCommitmentHintTreeRow() => OcptBudgetCostTrackingSubIdentityRow(
          depth: row.depth,
          isSimplified: isSimplified,
          posteWidth: posteWidth,
          isSelected: false,
          isSmall: true,
          isExpandable: false,
          isExpanded: false,
          onTwistyTap: null,
          onTap: null,
          builder: (context) => OcptBudgetCostTrackingSubLabel(
            label: Tr.of(context).budgetCostTrackingNoEntryHint,
            isMuted: true,
            isItalic: true,
          ),
        ),
        OcptBudgetCostTrackingEntryTreeRow() => OcptBudgetCostTrackingSubIdentityRow(
          depth: row.depth,
          isSimplified: isSimplified,
          posteWidth: posteWidth,
          isSelected: _isEntrySelected(row.entry.id),
          isSmall: true,
          isExpandable: false,
          isExpanded: false,
          onTwistyTap: null,
          onTap: () => onEntrySelected(row.entry.id),
          builder: (context) => OcptBudgetCostTrackingSubLabel(
            label: row.entry.label,
            isMuted: true,
            dotColor: Theme.of(context).colorScheme.primary,
            badgeText: row.entry.voucherNumber,
            badgeColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        OcptBudgetCostTrackingOffQuoteTreeRow() => OcptBudgetCostTrackingOffQuoteIdentityRow(
          isSimplified: isSimplified,
          posteWidth: posteWidth,
          isExpanded: row.isExpanded,
          onTwistyTap: () => onNodeExpansionToggled(ocptBudgetCostTrackingOffQuoteNodeId),
        ),
      };

  /// The scrolling pane's own widget for [row].
  Widget _amountsRowOf(OcptBudgetCostTrackingTreeRow row) => switch (row) {
    OcptBudgetCostTrackingPosteTreeRow() => OcptBudgetCostTrackingPosteAmountsRow(
      poste: row.poste,
      isSelected: _isPosteSelected(row.poste.id),
      taxBasis: taxBasis,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
      paidCents: paidByPosteId[row.poste.id]?.amountCents ?? 0,
      committedCents: committedCentsOf(row.poste.id),
      inKindCoveredCents: inKindCoveredCentsOf(row.poste.id),
      onTap: () => onPosteSelected(row.poste.id),
      onRenameRequested: isReadOnly ? null : () => onPosteSelected(row.poste.id),
      onMoveUpRequested: isReadOnly
          ? null
          : () => onPosteReorderRequested?.call(row.poste.id, moveUp: true),
      onMoveDownRequested: isReadOnly
          ? null
          : () => onPosteReorderRequested?.call(row.poste.id, moveUp: false),
      onDeletionRequested: isReadOnly ? null : () => onPosteDeletionRequested?.call(row.poste.id),
      onFilterRequested: onPosteFilterRequested == null
          ? null
          : () => onPosteFilterRequested?.call(row.poste.id),
    ),
    OcptBudgetCostTrackingLineTreeRow() => OcptBudgetCostTrackingLineAmountsRow(
      line: row.line,
      lineCommitments: row.lineCommitments,
      entries: entries,
      taxBasis: taxBasis,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
      isSelected: _isLineSelected(row.line.id),
      onTap: () => onLineSelected(row.line.id),
    ),
    OcptBudgetCostTrackingCommitmentTreeRow() => _commitmentAmountsRowOf(row.commitment),
    OcptBudgetCostTrackingCommitmentHintTreeRow() => const OcptBudgetCostTrackingSubAmountsRow(
      isSelected: false,
      onTap: null,
      activeColumnIndex: null,
      activeCents: null,
      currencyCode: "",
      menuBuilder: null,
    ),
    OcptBudgetCostTrackingEntryTreeRow() => OcptBudgetCostTrackingSubAmountsRow(
      isSelected: _isEntrySelected(row.entry.id),
      onTap: () => onEntrySelected(row.entry.id),
      activeColumnIndex: 2,
      activeCents: ocptBudgetEntryDebitCentsOf(
        row.entry,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      ),
      currencyCode: currencyCode,
      menuBuilder: (context) => _entryMenuOf(context, row.entry),
    ),
    OcptBudgetCostTrackingOffQuoteTreeRow() => OcptBudgetCostTrackingOffQuoteAmountsRow(
      offQuoteTotal: offQuoteTotal,
      currencyCode: currencyCode,
    ),
  };

  /// Whether poste [posteId] is the currently selected one.
  bool _isPosteSelected(String posteId) {
    final selection = this.selection;
    return selection is OcptBudgetPosteSelection && selection.posteId == posteId;
  }

  /// Whether quote line [lineId] is the currently selected one.
  bool _isLineSelected(String lineId) {
    final selection = this.selection;
    return selection is OcptBudgetLineSelection && selection.lineId == lineId;
  }

  /// Whether commitment [commitmentId] is the currently selected one.
  bool _isCommitmentSelected(String commitmentId) {
    final selection = this.selection;
    return selection is OcptBudgetCommitmentSelection && selection.commitmentId == commitmentId;
  }

  /// Whether entry [entryId] is the currently selected one.
  bool _isEntrySelected(String entryId) {
    final selection = this.selection;
    return selection is OcptBudgetEntrySelection && selection.entryId == entryId;
  }

  /// [commitment]'s own amounts sub-row — its own cash figure in `Engagé` while unsettled, what has
  /// actually been paid against it in `Payé` once it is, read off [entries] through
  /// [ocptBudgetCommitmentIsSettledOf]/[ocptBudgetCommitmentPaidCentsOf] — see the class doc
  /// comment. Extracted out of [_amountsRowOf]'s own switch expression since settlement now needs
  /// [entries] read once rather than the plain field read `OcptBudgetCommitment.isSettled` used to
  /// be.
  Widget _commitmentAmountsRowOf(OcptBudgetCommitment commitment) {
    final isSettled = ocptBudgetCommitmentIsSettledOf(
      commitment,
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final activeCents = isSettled
        ? ocptBudgetCommitmentPaidCentsOf(
            commitment,
            entries,
            projectVatRateBasisPoints: defaultVatRateBasisPoints,
          ).amountCents
        : ocptBudgetCommitmentCashCentsOf(
            commitment,
            projectVatRateBasisPoints: defaultVatRateBasisPoints,
          );

    return OcptBudgetCostTrackingSubAmountsRow(
      isSelected: _isCommitmentSelected(commitment.id),
      onTap: () => onCommitmentSelected(commitment.id),
      activeColumnIndex: isSettled ? 2 : 1,
      activeCents: activeCents,
      currencyCode: currencyCode,
      menuBuilder: (context) => _commitmentMenuOf(context, commitment),
    );
  }

  /// [commitment]'s own `⋮` menu, or null while every one of its own entries is withheld — see the
  /// class doc comment.
  Widget? _commitmentMenuOf(BuildContext context, OcptBudgetCommitment commitment) {
    final isSettled = ocptBudgetCommitmentIsSettledOf(
      commitment,
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final onEdit = isReadOnly ? null : onCommitmentEditRequested;
    final onSettle = isReadOnly || isSettled ? null : onCommitmentSettleRequested;
    final onUnsettle = isReadOnly || !isSettled ? null : onCommitmentUnsettleRequested;
    final onDelete = isReadOnly ? null : onCommitmentDeletionRequested;
    if (onEdit == null && onSettle == null && onUnsettle == null && onDelete == null) {
      return null;
    }

    final tr = Tr.of(context);
    return PopupMenuButton<String>(
      tooltip: "",
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) => switch (value) {
        "edit" => onEdit?.call(commitment),
        "settle" => onSettle?.call(commitment),
        "unsettle" => onUnsettle?.call(commitment.id),
        "delete" => onDelete?.call(commitment.id),
        _ => null,
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem<String>(value: "edit", child: Text(tr.budgetFinancingEditAction)),
        if (onSettle != null)
          PopupMenuItem<String>(value: "settle", child: Text(tr.budgetCommittedSettleAction)),
        if (onUnsettle != null)
          PopupMenuItem<String>(value: "unsettle", child: Text(tr.budgetCommittedUnsettleAction)),
        if (onDelete != null)
          PopupMenuItem<String>(value: "delete", child: Text(tr.budgetCommittedDeleteAction)),
      ],
    );
  }

  /// [entry]'s own `⋮` menu, or null while every one of its own entries is withheld.
  Widget? _entryMenuOf(BuildContext context, OcptBudgetEntry entry) {
    final onEdit = isReadOnly ? null : onEntryEditRequested;
    final onDelete = isReadOnly ? null : onEntryDeletionRequested;
    if (onEdit == null && onDelete == null) {
      return null;
    }

    final tr = Tr.of(context);
    return PopupMenuButton<String>(
      tooltip: "",
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) => switch (value) {
        "edit" => onEdit?.call(entry),
        "delete" => onDelete?.call(entry.id),
        _ => null,
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem<String>(value: "edit", child: Text(tr.budgetFinancingEditAction)),
        if (onDelete != null)
          PopupMenuItem<String>(value: "delete", child: Text(tr.budgetEntryDeleteAction)),
      ],
    );
  }
}
