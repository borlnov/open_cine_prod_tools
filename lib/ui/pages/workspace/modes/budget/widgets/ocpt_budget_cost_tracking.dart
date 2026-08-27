// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_feed_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_tree.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';

/// The `N°` column's own fixed width, in logical pixels — detailed header only.
const double _ocptCostTrackingNumberColumnWidth = 44;

/// The `Devis`, `Engagé`, `Payé`, `Reste`, `Coût final` and `Écart` columns' own fixed width, in
/// logical pixels.
const double _ocptCostTrackingAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels.
const double _ocptCostTrackingMenuColumnWidth = 36;

/// The narrowest the `Poste` column is ever drawn, in logical pixels — past this, the scrolling
/// pane (the amount columns) scrolls horizontally under the pinned identity pane rather than
/// crushing the poste names, mirroring `OcptBreakdownRecapTable`'s own
/// `_ocptRecapElementColumnMinWidth`.
const double _ocptCostTrackingPosteColumnMinWidth = 220;

/// Every poste row's own fixed height, in logical pixels — tall enough for the `Devis` cell's own
/// two stacked lines (the headline figure, then the other tax basis and, when a poste's lines all
/// share one, the rate underneath it).
///
/// The table draws as two independently laid-out panes side by side — the pinned `N°`/`Poste`
/// columns, the scrolling amount columns — each its own plain `Column`, sharing no `RenderObject`
/// with the other. A row sized to its own content, the ordinary Flutter way, would let a poste
/// whose lines carry a priced second basis (a taller `Devis` cell) sit a few pixels taller than a
/// neighbour with none — and since the `Devis` cell lives in the *scrolling* pane while the poste
/// name lives in the *pinned* one, the two panes would drift out of step by exactly that many
/// pixels, row after row. Claiming this one named height, whatever a particular row actually holds,
/// is what keeps a poste's own name level with its own figures with neither `IntrinsicHeight` nor a
/// `ScrollController` shared between the panes' two `SingleChildScrollView`s.
const double _ocptCostTrackingRowHeight = 48;

/// A line, a commitment, an entry or the muted "no entry" hint's own fixed height, in logical
/// pixels — one step shorter than [_ocptCostTrackingRowHeight], the mockup's own reading for a
/// sub-row, and, for the very same reason that constant argues, a **named** height rather than one
/// sized to a sub-row's own content: the identity pane draws a sub-row's indentation and its own
/// label while the amounts pane draws its figures, and the two have to agree on a height with
/// nothing shared to agree through but this constant.
const double _ocptCostTrackingSubRowHeight = 36;

/// The header row's own fixed height, in logical pixels — see [_ocptCostTrackingRowHeight]'s own
/// doc comment for why the two panes need every row, the header included, to claim a named height
/// rather than size to its own single-line content.
const double _ocptCostTrackingHeaderRowHeight = 36;

/// The total row's own fixed height, in logical pixels — tall enough for
/// `tr.budgetCostTrackingCoverageReadOut`'s own two lines, printed here in place of the plain
/// amount while the excluding-tax total does not yet cover every poste; see
/// [_ocptCostTrackingRowHeight]'s own doc comment for why a named height, not the tallest cell's
/// own, is what keeps this row's two panes aligned.
const double _ocptCostTrackingTotalRowHeight = 48;

/// How far a sub-row indents for every step of tree depth, in logical pixels — a quote line sits
/// one step in from its own poste, a commitment or an entry two.
const double _ocptCostTrackingIndentStep = 16;

/// The twisty's own fixed width, in logical pixels, whether it draws an arrow or sits blank —
/// reserved on every row a twisty could appear on (a poste, a quote line) so a poste or line with
/// nothing to expand still lines its own label up with a sibling that does. 28, the theme's own
/// floor for an icon button's own tap target, not the 20 an earlier pass under-sized it at
/// (`docs/architecture/budget.md`) — its own tap target runs the
/// **full height** of whichever row it sits on rather than squaring off at this same figure, see
/// [_OcptCostTrackingTwisty]'s own doc comment.
const double _ocptCostTrackingTwistyWidth = 28;

/// The diameter of a commitment or an entry sub-row's own coloured dot, in logical pixels.
const double _ocptCostTrackingDotDiameter = 8;

/// The widest a commitment or an entry sub-row's own trailing badge is ever drawn, in logical
/// pixels — capped so a long status word never overflows the row it sits in, see
/// [_OcptCostTrackingSubLabel]'s own build method.
const double _ocptCostTrackingBadgeMaxWidth = 84;

/// The widest the empty state's own [OcptWorkspaceEmptyMode]/[OcptBudgetFeedCard] pair is ever
/// drawn, in logical pixels — centred rather than run the width of the screen.
const double _ocptCostTrackingEmptyStateMaxWidth = 480;

/// The off-quote row's own reserved id in `OcptBudgetState.expandedNodeIds` — no poste, quote line,
/// resource or revenue can ever collide with it, since every one of those mints a UUID and this
/// string is not one. The off-quote row sums a reading over the journal rather than naming a record
/// of its own, so it has no id to key its own expansion by except one this file reserves for it.
const String _ocptCostTrackingOffQuoteNodeId = "off-quote";

/// The budget mode's cost-tracking view: the expenses tree — one row per poste, opening onto its
/// own quote lines, each of those opening onto its own commitments and the entries that settle
/// them, the poste's own off-line commitments and entries drawn at a quote line's own indentation
/// once it is open — then a total row, then a `+ Poste` creation footer.
///
/// **The `N°` and `Poste` columns are pinned**, drawn in their own pane at the left edge that
/// never moves; only the six amount columns and the trailing `⋮` menu, in a second pane to their
/// right, scroll horizontally once the centre dock narrows past
/// [_ocptCostTrackingPosteColumnMinWidth] — a poste nobody can name is worse than a figure nobody
/// can read yet, so a row's own identity survives the scroll even when its own numbers no longer
/// fit. The two panes share one vertical scroll, so the whole table still moves together, and, row
/// for row, the exact same height ([_ocptCostTrackingRowHeight]'s and
/// [_ocptCostTrackingSubRowHeight]'s own doc comments argue why).
///
/// **The tree is flattened once, top to bottom, into [_buildRows]' own list**, and both panes then
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
/// `lib/utils/ocpt_budget_journal.dart`/`ocpt_budget_projection.dart`): a poste with no entry or
/// commitment against it answers **0**, honestly, rather than a stand-in for an unknown figure —
/// the journal exists and is kept, so "nothing has moved" is a fact this table can state outright.
/// `Payé`, `Engagé`, `Reste` and `Écart` therefore always print a real amount at poste level. A
/// quote line's own `Engagé`/`Payé` are read the very same honest way, through
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
/// expansion is worse than none. A commitment or an entry sub-row draws no twisty of its own:
/// `OcptBudgetState.expandedNodeIds` is keyed by poste and line ids alone, so a commitment's own
/// child — the entry that settled it, or, while it is still owed, the muted
/// `tr.budgetCostTrackingNoEntryHint` row — shows or hides wholesale with whichever line, or
/// poste, it sits directly under.
///
/// **A commitment sub-row prints its own amount in `Engagé` while unsettled, in `Payé` once
/// settled, and the em dash in every other column; an entry sub-row prints its own debit in `Payé`
/// and the em dash elsewhere** — the mockup's own reading, and the reason the "no entry" hint row
/// exists at all: an unsettled commitment has nothing of its own to show under
/// [ocptBudgetEntryDebitCentsOf], so the hint says why in words instead of drawing nothing.
///
/// **`_buildRows` folds one extra row into the tree, `Off quote`, after the last poste and before
/// the `Total` row** — the total of every debit naming no poste at all
/// (`ocptBudgetOffQuotePaidTotalOf`, `lib/utils/ocpt_budget_journal.dart`), which
/// [paidByPosteId] never keys at all. It is drawn only while some such debit exists and only its
/// own `Payé` cell carries a figure; it is not a poste, so it carries no `N°`, no `⋮` menu and no
/// selection of its own — see `_OcptCostTrackingOffQuoteIdentityRow`'s own doc comment. **It gains
/// a twisty, opening onto the very debits it sums**, each an ordinary entry sub-row keyed by the
/// reserved [_ocptCostTrackingOffQuoteNodeId] rather than by a poste or a line id, since the row
/// sums a reading over the journal and names no record of its own to key one by. An entry drawn
/// here that also settles a commitment nested under some poste is not excluded the way a poste's
/// own off-line entries are — `_buildRows`' own doc comment argues why it legitimately appears in
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

  @override
  Widget build(BuildContext context) {
    if (postes.isEmpty) {
      return _buildEmptyState(context);
    }

    final allLines = [for (final poste in postes) ...poste.lines];
    final total = ocptBudgetTotalOf(
      allLines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final coveredPosteCount = _coveredPosteCountOf();
    final paidTotal = ocptBudgetCoveredTotalsFoldOf([...paidByPosteId.values, offQuoteTotal]);
    final finalCostCents = _finalCostTotalOf();
    final rows = _buildRows();

    return LayoutBuilder(
      builder: (context, constraints) {
        final identityFixedWidth = isSimplified ? 0.0 : _ocptCostTrackingNumberColumnWidth;
        // Devis, Engagé, Payé, Reste, Coût final, Écart — six amount columns.
        final amountsWidth = 6 * _ocptCostTrackingAmountColumnWidth + _ocptCostTrackingMenuColumnWidth;
        final posteWidth = (constraints.maxWidth - identityFixedWidth - amountsWidth).clamp(
          _ocptCostTrackingPosteColumnMinWidth,
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
                          _OcptCostTrackingIdentityHeaderCell(
                            isSimplified: isSimplified,
                            posteWidth: posteWidth,
                          ),
                          for (final row in rows)
                            _identityRowOf(row, posteWidth: posteWidth),
                          _OcptCostTrackingIdentityTotalRow(
                            isSimplified: isSimplified,
                            posteWidth: posteWidth,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: amountsWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _OcptCostTrackingAmountsHeaderRow(),
                              for (final row in rows) _amountsRowOf(row),
                              _OcptCostTrackingAmountsTotalRow(
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
            if (showFooter) _OcptCostTrackingCreationFooter(onTap: onPosteCreationRequested!),
          ],
        );
      },
    );
  }

  /// The empty state drawn in place of the two-pane table while [postes] is empty — see the class
  /// doc comment. The creation footer is kept, exactly as it is drawn today, so the way to create
  /// the first poste never disappears.
  Widget _buildEmptyState(BuildContext context) {
    final tr = Tr.of(context);
    final showFooter = !isReadOnly && onPosteCreationRequested != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _ocptCostTrackingEmptyStateMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OcptWorkspaceEmptyMode(
                    icon: Icons.payments_outlined,
                    message: tr.budgetDashboardEmptyHint,
                  ),
                  const SizedBox(height: 16),
                  OcptBudgetFeedCard(
                    breakdownPricedElementCount: breakdownPricedElementCount,
                    breakdownUnpricedElementCount: breakdownUnpricedElementCount,
                    shootingDayCount: shootingDayCount,
                    mealCount: mealCount,
                    buffetCount: buffetCount,
                    onBreakdownFeedRequested: onBreakdownFeedRequested,
                    onScheduleFeedRequested: onScheduleFeedRequested,
                    onCateringFeedRequested: onCateringFeedRequested,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showFooter) _OcptCostTrackingCreationFooter(onTap: onPosteCreationRequested!),
      ],
    );
  }

  /// The whole tree, flattened top to bottom into one list both panes walk in lockstep — see the
  /// class doc comment.
  ///
  /// A poste draws whenever it is live, whatever [expandedNodeIds] holds; its own children —
  /// [OcptBudgetPoste.lines], then its off-line commitments and entries — draw only while its own
  /// id is in [expandedNodeIds]. A quote line's own children — its commitments, and, for each one,
  /// either every entry that has paid it so far or the muted "no entry" hint while none has —
  /// draw only while the line's own id is in [expandedNodeIds] too.
  ///
  /// **The off-quote row follows the last poste, drawn exactly as it always was — only while
  /// [offQuoteTotal] holds something ([OcptBudgetCoveredTotal.lineCount] above zero).** Its own
  /// children — every debit naming no poste at all — draw only while
  /// [_ocptCostTrackingOffQuoteNodeId] is in [expandedNodeIds] too. Unlike a poste's own off-line
  /// entries, this list is **not** narrowed by `settlingEntryIds`: a poste-less debit that also
  /// settles a commitment nested under some poste is exactly the case the off-quote total sums, and
  /// hiding it here because it is reachable elsewhere would leave the total's own children not
  /// actually adding up to the figure it prints. It legitimately draws twice — once here, once
  /// nested under the commitment it settles — and that is the honest reading of a poste-less
  /// payment that happens to also be a settlement.
  List<_OcptTreeRow> _buildRows() {
    final rows = <_OcptTreeRow>[];
    // Every entry naming a commitment at all, settled or still owed — an off-line entry list must
    // never repeat one of these, since [_addCommitmentRows] already draws every one of them nested
    // under the very commitment it pays, whether that commitment is settled yet or only part-paid.
    final settlingEntryIds = {for (final entry in entries) if (entry.commitmentId != null) entry.id};

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
        _OcptPosteTreeRow(poste: poste, isExpandable: isPosteExpandable, isExpanded: isPosteExpanded),
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
          _OcptLineTreeRow(line: line, lineCommitments: lineCommitments, isExpanded: isLineExpanded),
        );
        if (!isLineExpanded) {
          continue;
        }

        _addCommitmentRows(rows, lineCommitments, depth: 2);
      }

      _addCommitmentRows(rows, offLineCommitments, depth: 1);
      for (final entry in offLineEntries) {
        rows.add(_OcptEntryTreeRow(entry: entry, depth: 1));
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
      final isOffQuoteExpanded = expandedNodeIds.contains(_ocptCostTrackingOffQuoteNodeId);
      rows.add(_OcptOffQuoteTreeRow(isExpanded: isOffQuoteExpanded));
      if (isOffQuoteExpanded) {
        for (final entry in offQuoteEntries) {
          rows.add(_OcptEntryTreeRow(entry: entry, depth: 1));
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
  void _addCommitmentRows(
    List<_OcptTreeRow> rows,
    List<OcptBudgetCommitment> rowCommitments, {
    required int depth,
  }) {
    for (final commitment in rowCommitments) {
      rows.add(_OcptCommitmentTreeRow(commitment: commitment, depth: depth));

      final paymentEntries = [
        for (final entry in entries)
          if (entry.commitmentId == commitment.id) entry,
      ];
      if (paymentEntries.isEmpty) {
        rows.add(_OcptCommitmentHintTreeRow(depth: depth));
      } else {
        for (final entry in paymentEntries) {
          rows.add(_OcptEntryTreeRow(entry: entry, depth: depth));
        }
      }
    }
  }

  /// The pinned pane's own widget for [row].
  Widget _identityRowOf(_OcptTreeRow row, {required double posteWidth}) => switch (row) {
    _OcptPosteTreeRow() => _OcptCostTrackingPosteIdentityRow(
      poste: row.poste,
      isSelected: _isPosteSelected(row.poste.id),
      isSimplified: isSimplified,
      posteWidth: posteWidth,
      isExpandable: row.isExpandable,
      isExpanded: row.isExpanded,
      onTap: () => onPosteSelected(row.poste.id),
      onTwistyTap: () => onNodeExpansionToggled(row.poste.id),
    ),
    _OcptLineTreeRow() => _OcptCostTrackingSubIdentityRow(
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
        return _OcptCostTrackingSubLabel(
          label: label.isEmpty ? tr.budgetLineUnnamed : label,
          isItalic: label.isEmpty,
        );
      },
    ),
    _OcptCommitmentTreeRow() => _OcptCostTrackingSubIdentityRow(
      depth: row.depth,
      isSimplified: isSimplified,
      posteWidth: posteWidth,
      isSelected: _isCommitmentSelected(row.commitment.id),
      isSmall: true,
      isExpandable: false,
      isExpanded: false,
      onTwistyTap: null,
      onTap: () => onCommitmentSelected(row.commitment.id),
      builder: (context) {
        final tr = Tr.of(context);
        final isSettled = ocptBudgetCommitmentIsSettledOf(
          row.commitment,
          entries,
          projectVatRateBasisPoints: defaultVatRateBasisPoints,
        );
        return _OcptCostTrackingSubLabel(
          label: row.commitment.label,
          isMuted: true,
          dotColor: isSettled
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : ocptBudgetCommitmentStatusAccentColor(Theme.of(context).colorScheme, row.commitment.status),
          badgeText: isSettled
              ? tr.budgetCommittedStatusSettledLabel
              : ocptBudgetCommitmentStatusLabel(tr, row.commitment.status),
          badgeColor: isSettled
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : ocptBudgetCommitmentStatusAccentColor(Theme.of(context).colorScheme, row.commitment.status),
        );
      },
    ),
    _OcptCommitmentHintTreeRow() => _OcptCostTrackingSubIdentityRow(
      depth: row.depth,
      isSimplified: isSimplified,
      posteWidth: posteWidth,
      isSelected: false,
      isSmall: true,
      isExpandable: false,
      isExpanded: false,
      onTwistyTap: null,
      onTap: null,
      builder: (context) => _OcptCostTrackingSubLabel(
        label: Tr.of(context).budgetCostTrackingNoEntryHint,
        isMuted: true,
        isItalic: true,
      ),
    ),
    _OcptEntryTreeRow() => _OcptCostTrackingSubIdentityRow(
      depth: row.depth,
      isSimplified: isSimplified,
      posteWidth: posteWidth,
      isSelected: _isEntrySelected(row.entry.id),
      isSmall: true,
      isExpandable: false,
      isExpanded: false,
      onTwistyTap: null,
      onTap: () => onEntrySelected(row.entry.id),
      builder: (context) => _OcptCostTrackingSubLabel(
        label: row.entry.label,
        isMuted: true,
        dotColor: Theme.of(context).colorScheme.primary,
        badgeText: row.entry.voucherNumber,
        badgeColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
    _OcptOffQuoteTreeRow() => _OcptCostTrackingOffQuoteIdentityRow(
      isSimplified: isSimplified,
      posteWidth: posteWidth,
      isExpanded: row.isExpanded,
      onTwistyTap: () => onNodeExpansionToggled(_ocptCostTrackingOffQuoteNodeId),
    ),
  };

  /// The scrolling pane's own widget for [row].
  Widget _amountsRowOf(_OcptTreeRow row) => switch (row) {
    _OcptPosteTreeRow() => _OcptCostTrackingPosteAmountsRow(
      poste: row.poste,
      isSelected: _isPosteSelected(row.poste.id),
      taxBasis: taxBasis,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
      paidCents: paidByPosteId[row.poste.id]?.amountCents ?? 0,
      committedCents: committedCentsOf(row.poste.id),
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
    _OcptLineTreeRow() => _OcptCostTrackingLineAmountsRow(
      line: row.line,
      lineCommitments: row.lineCommitments,
      entries: entries,
      taxBasis: taxBasis,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
      isSelected: _isLineSelected(row.line.id),
      onTap: () => onLineSelected(row.line.id),
    ),
    _OcptCommitmentTreeRow() => _commitmentAmountsRowOf(row.commitment),
    _OcptCommitmentHintTreeRow() => const _OcptCostTrackingSubAmountsRow(
      isSelected: false,
      onTap: null,
      activeColumnIndex: null,
      activeCents: null,
      currencyCode: "",
      menuBuilder: null,
    ),
    _OcptEntryTreeRow() => _OcptCostTrackingSubAmountsRow(
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
    _OcptOffQuoteTreeRow() => _OcptCostTrackingOffQuoteAmountsRow(
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
        : ocptBudgetCommitmentCashCentsOf(commitment, projectVatRateBasisPoints: defaultVatRateBasisPoints);

    return _OcptCostTrackingSubAmountsRow(
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

  /// How many postes count as covered under [taxBasis] — "every one of its own lines does"
  /// (`docs/architecture/budget.md`) — what the total row's own coverage read-out counts
  /// against `postes.length`.
  int _coveredPosteCountOf() {
    var count = 0;
    for (final poste in postes) {
      final posteTotal = ocptBudgetTotalOf(
        poste.lines,
        basis: taxBasis,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      );
      if (posteTotal.isComplete) {
        count++;
      }
    }
    return count;
  }

  /// The grand `Coût final` total, summed **poste by poste**
  /// (`ocpt_budget_totals.dart`'s own "row by row, then summed" doctrine) rather than re-derived
  /// from the grand `Devis`/`Payé`/`Engagé` totals: a typed estimate to complete on one poste
  /// cannot be reconstructed from any project-wide figure, and [ocptBudgetEstimateToCompleteCents]'s
  /// own `max(0, …)` clamp does not commute with a sum — summing the clamped, per-poste figures is
  /// not the same amount as clamping the sum.
  int _finalCostTotalOf() {
    var finalCostCents = 0;

    for (final poste in postes) {
      final quoted = ocptBudgetTotalOf(
        poste.lines,
        basis: taxBasis,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      );
      final paidCents = paidByPosteId[poste.id]?.amountCents ?? 0;
      final committedCents = committedCentsOf(poste.id);
      final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
        quotedAmountCents: quoted.amountCents,
        paidCents: paidCents,
        committedCents: committedCents,
        typedEstimateToCompleteCents: poste.estimateToCompleteCents,
      );

      finalCostCents += ocptBudgetFinalCostCents(
        paidCents: paidCents,
        committedCents: committedCents,
        estimateToCompleteCents: estimateToCompleteCents,
      );
    }

    return finalCostCents;
  }
}

/// One flattened row of the expenses tree — see [OcptBudgetCostTracking._buildRows]'s own doc
/// comment for how the list this sealed class populates is built.
sealed class _OcptTreeRow {
  const _OcptTreeRow();
}

/// A poste row — the tree's own top level.
class _OcptPosteTreeRow extends _OcptTreeRow {
  /// The poste this row draws.
  final OcptBudgetPoste poste;

  /// Whether this poste has anything at all to expand onto.
  final bool isExpandable;

  /// Whether this poste is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const _OcptPosteTreeRow({required this.poste, required this.isExpandable, required this.isExpanded});
}

/// A quote line row — one step under its own poste.
class _OcptLineTreeRow extends _OcptTreeRow {
  /// The line this row draws.
  final OcptBudgetLine line;

  /// This line's own commitments, settled or not, in the order [OcptBudgetCostTracking.commitments]
  /// gives them.
  final List<OcptBudgetCommitment> lineCommitments;

  /// Whether this line is currently expanded.
  final bool isExpanded;

  /// Whether this line has anything at all to expand onto.
  bool get isExpandable => lineCommitments.isNotEmpty;

  /// Class constructor
  const _OcptLineTreeRow({required this.line, required this.lineCommitments, required this.isExpanded});
}

/// A commitment row — two steps under its own poste while it names a line, one step while it does
/// not (the poste's own off-line commitments).
class _OcptCommitmentTreeRow extends _OcptTreeRow {
  /// The commitment this row draws.
  final OcptBudgetCommitment commitment;

  /// This row's own indentation, in steps from the poste.
  final int depth;

  /// Class constructor
  const _OcptCommitmentTreeRow({required this.commitment, required this.depth});
}

/// The muted "no entry" hint drawn under an unsettled commitment, at the very same indentation as
/// that commitment — see [OcptBudgetCostTracking]'s own class doc comment.
class _OcptCommitmentHintTreeRow extends _OcptTreeRow {
  /// This row's own indentation, in steps from the poste — always the same as the commitment it
  /// sits under.
  final int depth;

  /// Class constructor
  const _OcptCommitmentHintTreeRow({required this.depth});
}

/// An entry row — either the entry that settled a commitment, at that commitment's own
/// indentation, or one of the poste's own off-line entries, one step under it, or one of the
/// off-quote total's own children, also one step under it (see [_OcptOffQuoteTreeRow]).
class _OcptEntryTreeRow extends _OcptTreeRow {
  /// The entry this row draws.
  final OcptBudgetEntry entry;

  /// This row's own indentation, in steps from the poste.
  final int depth;

  /// Class constructor
  const _OcptEntryTreeRow({required this.entry, required this.depth});
}

/// The off-quote total row — the tree's own last row before `Total`, naming no poste and no line.
/// See [OcptBudgetCostTracking._buildRows]'s own doc comment for which entries draw under it once
/// expanded.
class _OcptOffQuoteTreeRow extends _OcptTreeRow {
  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const _OcptOffQuoteTreeRow({required this.isExpanded});
}

/// The pinned pane's own header cell: the `N°` and `Poste` column headings.
class _OcptCostTrackingIdentityHeaderCell extends StatelessWidget {
  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Class constructor
  const _OcptCostTrackingIdentityHeaderCell({required this.isSimplified, required this.posteWidth});

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
        height: _ocptCostTrackingHeaderRowHeight,
        child: Row(
          children: [
            if (!isSimplified)
              SizedBox(
                width: _ocptCostTrackingNumberColumnWidth,
                child: Text(
                  tr.budgetCostTrackingColumnNumber.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ),
            SizedBox(
              width: posteWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(tr.budgetCostTrackingColumnPoste.toUpperCase(), style: labelStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrolling pane's own header row: the six amount column headings, then a blank cell over
/// the `⋮` menu column.
class _OcptCostTrackingAmountsHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptCostTrackingAmountsHeaderRow();

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
        height: _ocptCostTrackingHeaderRowHeight,
        child: Row(
          children: [
            _headerCell(tr.budgetCostTrackingColumnQuote, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnCommitted, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnPaid, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnRemaining, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnFinalCost, labelStyle),
            _headerCell(tr.budgetCostTrackingColumnVariance, labelStyle),
            const SizedBox(width: _ocptCostTrackingMenuColumnWidth),
          ],
        ),
      ),
    );
  }

  /// One amount column's own header cell, right-aligned like the figures underneath it.
  Widget _headerCell(String label, TextStyle? style) => SizedBox(
    width: _ocptCostTrackingAmountColumnWidth,
    child: Text(
      label.toUpperCase(),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}

/// The pinned pane's own row: one poste's `N°` and `Poste` cells, with a leading twisty while it
/// has anything at all to expand onto.
///
/// **This row is one half of the poste's own row** — [_OcptCostTrackingPosteAmountsRow] draws the
/// other, in the scrolling pane, for the very same [poste]. The two share [isSelected], so they
/// paint the very same background, and each carries its own tap target calling the very same
/// [onTap], so a click on either half selects the poste: together they read as one row to the
/// user even though they are two separate widgets with no `RenderObject` in common.
class _OcptCostTrackingPosteIdentityRow extends StatelessWidget {
  /// The poste this row shows.
  final OcptBudgetPoste poste;

  /// Whether this poste is the currently selected one.
  final bool isSelected;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Whether this poste has anything at all to expand onto.
  final bool isExpandable;

  /// Whether this poste is currently expanded.
  final bool isExpanded;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Called when this row's own twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback onTwistyTap;

  /// Class constructor
  const _OcptCostTrackingPosteIdentityRow({
    required this.poste,
    required this.isSelected,
    required this.isSimplified,
    required this.posteWidth,
    required this.isExpandable,
    required this.isExpanded,
    required this.onTap,
    required this.onTwistyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final label = ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: _ocptCostTrackingRowHeight,
          child: Row(
            children: [
              if (!isSimplified)
                SizedBox(
                  width: _ocptCostTrackingNumberColumnWidth,
                  child: Text(
                    poste.code,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                width: posteWidth,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Row(
                    children: [
                      _OcptCostTrackingTwisty(
                        isExpandable: isExpandable,
                        isExpanded: isExpanded,
                        onTap: onTwistyTap,
                        rowHeight: _ocptCostTrackingRowHeight,
                      ),
                      Expanded(
                        child: Text(
                          label.isEmpty ? tr.budgetPosteUnnamed : label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: label.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The twisty every poste and quote line row draws — an arrow while [isExpandable], nothing but
/// its own reserved width otherwise, so a row with nothing to expand still lines its own label up
/// with a sibling that does.
///
/// **Its own tap target is [_ocptCostTrackingTwistyWidth] wide over the whole of [rowHeight]**,
/// not a square of the twisty's own width: the theme's own floor for an icon button already
/// exceeds a column this narrow, so the row's own height, whichever fixed figure the row it sits on
/// draws at, is what the tap target claims instead (`docs/architecture/budget.md`). The 18 px arrow itself stays centred in that taller target — `Icon` centres
/// its own glyph inside whatever box its surrounding layout hands it.
class _OcptCostTrackingTwisty extends StatelessWidget {
  /// Whether this row has anything at all to expand onto.
  final bool isExpandable;

  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Called when this twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback? onTap;

  /// The row this twisty sits on own fixed height, in logical pixels — its own tap target fills it
  /// edge to edge.
  final double rowHeight;

  /// Class constructor
  const _OcptCostTrackingTwisty({
    required this.isExpandable,
    required this.isExpanded,
    this.onTap,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpandable) {
      return const SizedBox(width: _ocptCostTrackingTwistyWidth);
    }

    return SizedBox(
      width: _ocptCostTrackingTwistyWidth,
      height: rowHeight,
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        child: Icon(
          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The scrolling pane's own row: one poste's six amount cells and its own `⋮` menu — see
/// [_OcptCostTrackingPosteIdentityRow]'s own doc comment for why it shares [isSelected] and
/// [onTap] with the pinned half of the very same row.
class _OcptCostTrackingPosteAmountsRow extends StatelessWidget {
  /// The poste this row shows.
  final OcptBudgetPoste poste;

  /// Whether this poste is the currently selected one.
  final bool isSelected;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// This poste's own paid total, in cents.
  final int paidCents;

  /// This poste's own committed total, in cents.
  final int committedCents;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Called when the row's own `⋮` menu asks to rename this poste, or null while withheld.
  final VoidCallback? onRenameRequested;

  /// Called when the row's own `⋮` menu asks to move this poste up, or null while withheld.
  final VoidCallback? onMoveUpRequested;

  /// Called when the row's own `⋮` menu asks to move this poste down, or null while withheld.
  final VoidCallback? onMoveDownRequested;

  /// Called when the row's own `⋮` menu asks to delete this poste, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Called when the row's own `⋮` menu asks to narrow the mode to this poste, or null while
  /// withheld — never gated on a read-only preview, unlike every other callback here (see
  /// `OcptBudgetCostTracking.onPosteFilterRequested`'s own doc comment).
  final VoidCallback? onFilterRequested;

  /// Class constructor
  const _OcptCostTrackingPosteAmountsRow({
    required this.poste,
    required this.isSelected,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.paidCents,
    required this.committedCents,
    required this.onTap,
    required this.onRenameRequested,
    required this.onMoveUpRequested,
    required this.onMoveDownRequested,
    required this.onDeletionRequested,
    required this.onFilterRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final secondaryBasis = taxBasis == OcptBudgetTaxBasis.includingTax
        ? OcptBudgetTaxBasis.excludingTax
        : OcptBudgetTaxBasis.includingTax;
    final secondary = ocptBudgetTotalOf(
      poste.lines,
      basis: secondaryBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final uniformRate = ocptBudgetPosteUniformVatRateOf(
      poste.lines,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    // Resolved once per row, not once per cell, so no two cells reading the resolved estimate to
    // complete can ever disagree about which figure — derived or typed — they are both reading.
    final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      typedEstimateToCompleteCents: poste.estimateToCompleteCents,
    );
    final finalCostCents = ocptBudgetFinalCostCents(
      paidCents: paidCents,
      committedCents: committedCents,
      estimateToCompleteCents: estimateToCompleteCents,
    );

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: _ocptCostTrackingRowHeight,
          child: Row(
            children: [
              SizedBox(
                width: _ocptCostTrackingAmountColumnWidth,
                child: _OcptCostTrackingQuoteCell(
                  primaryCents: quoted.amountCents,
                  secondaryCents: secondary.coveredLineCount == 0 ? null : secondary.amountCents,
                  uniformRate: uniformRate,
                  currencyCode: currencyCode,
                ),
              ),
              _amountCell(context, ocptBudgetAmountLabel(committedCents, currencyCode)),
              _amountCell(context, ocptBudgetAmountLabel(paidCents, currencyCode)),
              _amountCell(
                context,
                ocptBudgetAmountLabel(
                  ocptBudgetRemainingCents(
                    quotedAmountCents: quoted.amountCents,
                    paidCents: paidCents,
                    committedCents: committedCents,
                  ),
                  currencyCode,
                ),
              ),
              _amountCell(context, ocptBudgetAmountLabel(finalCostCents, currencyCode)),
              _amountCell(
                context,
                ocptBudgetAmountLabel(
                  ocptBudgetVarianceCents(
                    quotedAmountCents: quoted.amountCents,
                    paidCents: paidCents,
                    committedCents: committedCents,
                  ),
                  currencyCode,
                ),
              ),
              SizedBox(
                width: _ocptCostTrackingMenuColumnWidth,
                child: (onRenameRequested == null &&
                        onMoveUpRequested == null &&
                        onMoveDownRequested == null &&
                        onDeletionRequested == null &&
                        onFilterRequested == null)
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: "",
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (value) => switch (value) {
                          "rename" => onRenameRequested?.call(),
                          "up" => onMoveUpRequested?.call(),
                          "down" => onMoveDownRequested?.call(),
                          "delete" => onDeletionRequested?.call(),
                          "filter" => onFilterRequested?.call(),
                          _ => null,
                        },
                        itemBuilder: (context) => [
                          if (onRenameRequested != null)
                            PopupMenuItem<String>(
                              value: "rename",
                              child: Text(tr.budgetPosteRenameAction),
                            ),
                          if (onMoveUpRequested != null)
                            PopupMenuItem<String>(value: "up", child: Text(tr.budgetPosteMoveUpAction)),
                          if (onMoveDownRequested != null)
                            PopupMenuItem<String>(
                              value: "down",
                              child: Text(tr.budgetPosteMoveDownAction),
                            ),
                          if (onFilterRequested != null)
                            PopupMenuItem<String>(
                              value: "filter",
                              child: Text(tr.budgetCostTrackingFilterOnlyAction),
                            ),
                          if (onDeletionRequested != null)
                            PopupMenuItem<String>(
                              value: "delete",
                              child: Text(tr.budgetPosteDeleteAction),
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

  /// One amount cell, right-aligned.
  Widget _amountCell(BuildContext context, String text) => SizedBox(
    width: _ocptCostTrackingAmountColumnWidth,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// One line of a sub-row's own identity label: an optional coloured dot, the label itself, and an
/// optional trailing badge pill — [_OcptCostTrackingSubIdentityRow]'s own `builder` hands one of
/// these back for every sub-row kind.
class _OcptCostTrackingSubLabel extends StatelessWidget {
  /// The text shown.
  final String label;

  /// Whether [label] prints in the muted, one-step-smaller ink the mockup draws every sub-row in.
  final bool isMuted;

  /// Whether [label] prints in italics — an unnamed line, or the "no entry" hint.
  final bool isItalic;

  /// The colour of the leading dot, or null while this row draws none.
  final Color? dotColor;

  /// The trailing badge's own text, or null while this row draws none.
  final String? badgeText;

  /// The trailing badge's own colour, read together with [badgeText].
  final Color? badgeColor;

  /// Class constructor
  const _OcptCostTrackingSubLabel({
    required this.label,
    this.isMuted = false,
    this.isItalic = false,
    this.dotColor,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: isMuted ? theme.colorScheme.onSurfaceVariant : null,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
    );
    final dotColor = this.dotColor;
    final badgeText = this.badgeText;

    return Row(
      children: [
        if (dotColor != null) ...[
          Container(
            width: _ocptCostTrackingDotDiameter,
            height: _ocptCostTrackingDotDiameter,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
        if (badgeText != null && badgeText.isNotEmpty) ...[
          const SizedBox(width: 6),
          // Capped, never left to its own natural width: at the pinned pane's own narrowest
          // ([_ocptCostTrackingPosteColumnMinWidth]), a long status word ("Quote accepted") would
          // otherwise overflow the row outright rather than sharing the little room there is with
          // the label beside it.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _ocptCostTrackingBadgeMaxWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (badgeColor ?? theme.colorScheme.onSurfaceVariant).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(ocptRadiusSmall),
              ),
              child: Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: badgeColor ?? theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The pinned pane's own generic sub-row: a quote line, a commitment, an entry or the muted "no
/// entry" hint — every one but the line one step smaller and muted, indented [depth] steps, a
/// twisty reserved only for a quote line. [builder] draws the row's own content (label, dot,
/// badge) — see [_OcptCostTrackingSubLabel].
class _OcptCostTrackingSubIdentityRow extends StatelessWidget {
  /// This row's own indentation, in steps from the poste.
  final int depth;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Whether this row is the currently selected one.
  final bool isSelected;

  /// Whether this row prints one step smaller than a line row — every commitment, entry and hint
  /// row does; a line row does not.
  final bool isSmall;

  /// Whether this row has anything at all to expand onto — a quote line alone.
  final bool isExpandable;

  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked, or null while it draws none.
  final VoidCallback? onTwistyTap;

  /// Called when this row is clicked, or null while it draws no selection at all (the hint row).
  final VoidCallback? onTap;

  /// Builds this row's own content.
  final WidgetBuilder builder;

  /// Class constructor
  const _OcptCostTrackingSubIdentityRow({
    required this.depth,
    required this.isSimplified,
    required this.posteWidth,
    required this.isSelected,
    required this.isSmall,
    required this.isExpandable,
    required this.isExpanded,
    required this.onTwistyTap,
    required this.onTap,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onTap = this.onTap;

    final content = SizedBox(
      width: posteWidth,
      child: Padding(
        padding: EdgeInsets.only(left: 12 + depth * _ocptCostTrackingIndentStep, right: 8),
        child: Row(
          children: [
            if (isExpandable || !isSmall)
              _OcptCostTrackingTwisty(
                isExpandable: isExpandable,
                isExpanded: isExpanded,
                onTap: onTwistyTap,
                rowHeight: isSmall ? _ocptCostTrackingSubRowHeight : _ocptCostTrackingRowHeight,
              ),
            Expanded(child: builder(context)),
          ],
        ),
      ),
    );

    return SizedBox(
      height: isSmall ? _ocptCostTrackingSubRowHeight : _ocptCostTrackingRowHeight,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: onTap == null
            ? Row(
                children: [
                  if (!isSimplified) const SizedBox(width: _ocptCostTrackingNumberColumnWidth),
                  content,
                ],
              )
            : InkWell(
                onTap: onTap,
                mouseCursor: ocptClickableCursor,
                child: Row(
                  children: [
                    if (!isSimplified) const SizedBox(width: _ocptCostTrackingNumberColumnWidth),
                    content,
                  ],
                ),
              ),
      ),
    );
  }
}

/// A quote line's own six amount cells — [OcptBudgetCostTracking]'s own class doc comment argues
/// why `Engagé`/`Payé` are read through [ocptBudgetLineCommittedTotalOf]/[ocptBudgetLinePaidTotalOf]
/// and why the estimate to complete behind `Coût final` is always derived here.
class _OcptCostTrackingLineAmountsRow extends StatelessWidget {
  /// The line this row shows.
  final OcptBudgetLine line;

  /// This line's own commitments, settled or not.
  final List<OcptBudgetCommitment> lineCommitments;

  /// Every live entry of the project — searched for the one settling each of [lineCommitments]'
  /// own settled commitments.
  final List<OcptBudgetEntry> entries;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this line is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptCostTrackingLineAmountsRow({
    required this.line,
    required this.lineCommitments,
    required this.entries,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quoted = ocptBudgetTotalOf(
      [line],
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final committed = ocptBudgetLineCommittedTotalOf(
      lineCommitments,
      entries: entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paid = ocptBudgetLinePaidTotalOf(
      lineCommitments,
      entries: entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    // A line carries no estimate to complete of its own — always derived, never typed
    // (`docs/architecture/budget.md`).
    final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paid.amountCents,
      committedCents: committed.amountCents,
      typedEstimateToCompleteCents: null,
    );
    final finalCostCents = ocptBudgetFinalCostCents(
      paidCents: paid.amountCents,
      committedCents: committed.amountCents,
      estimateToCompleteCents: estimateToCompleteCents,
    );
    final remainingCents = ocptBudgetRemainingCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paid.amountCents,
      committedCents: committed.amountCents,
    );
    final varianceCents = ocptBudgetVarianceCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paid.amountCents,
      committedCents: committed.amountCents,
    );

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          // A quote line is a full-height row, not a sub-row: the pinned pane draws its own half
          // at [_ocptCostTrackingRowHeight] (`isSmall: false`), and the two panes have to agree
          // row for row or every row below an expanded poste drifts out of step with its own
          // figures — see this widget's own class doc comment.
          height: _ocptCostTrackingRowHeight,
          child: Row(
            children: [
              _cell(context, ocptBudgetAmountLabel(quoted.amountCents, currencyCode)),
              _cell(context, ocptBudgetAmountLabel(committed.amountCents, currencyCode)),
              _cell(context, ocptBudgetAmountLabel(paid.amountCents, currencyCode)),
              _cell(context, ocptBudgetAmountLabel(remainingCents, currencyCode)),
              _cell(context, ocptBudgetAmountLabel(finalCostCents, currencyCode)),
              _cell(context, ocptBudgetAmountLabel(varianceCents, currencyCode)),
              const SizedBox(width: _ocptCostTrackingMenuColumnWidth),
            ],
          ),
        ),
      ),
    );
  }

  /// One amount cell, right-aligned, one step smaller than a poste row's own.
  Widget _cell(BuildContext context, String text) => SizedBox(
    width: _ocptCostTrackingAmountColumnWidth,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

/// The scrolling pane's own generic sub-row: a commitment or an entry, printing exactly one figure
/// — at [activeColumnIndex], or the em dash there while [activeCents] is null — and the em dash in
/// every other one of the six columns, then an optional `⋮` menu. The "no entry" hint row reuses
/// this same widget with [activeColumnIndex] null, so every one of its own six cells reads the em
/// dash and it carries no menu at all.
class _OcptCostTrackingSubAmountsRow extends StatelessWidget {
  /// Whether this row is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked, or null while it draws no selection at all (the hint row).
  final VoidCallback? onTap;

  /// Which of the six columns (`0` `Devis` … `5` `Écart`) carries [activeCents], or null while this
  /// row has no figure of its own at all.
  final int? activeColumnIndex;

  /// The one figure this row prints, in cents, at [activeColumnIndex] — or null while it cannot be
  /// read, in which case that column reads the em dash too.
  final int? activeCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Builds this row's own `⋮` menu, or null while it carries none — and may itself answer null
  /// too, once every one of its own entries is withheld, see
  /// [OcptBudgetCostTracking._commitmentMenuOf]/[OcptBudgetCostTracking._entryMenuOf].
  final Widget? Function(BuildContext context)? menuBuilder;

  /// Class constructor
  const _OcptCostTrackingSubAmountsRow({
    required this.isSelected,
    required this.onTap,
    required this.activeColumnIndex,
    required this.activeCents,
    required this.currencyCode,
    required this.menuBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCents = this.activeCents;
    final activeText = activeCents == null ? null : ocptBudgetAmountLabel(activeCents, currencyCode);
    final onTap = this.onTap;

    final row = Row(
      children: [
        for (var index = 0; index < 6; index++)
          _cell(context, index == activeColumnIndex ? activeText : null),
        SizedBox(width: _ocptCostTrackingMenuColumnWidth, child: menuBuilder?.call(context)),
      ],
    );

    return SizedBox(
      height: _ocptCostTrackingSubRowHeight,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: onTap == null
            ? row
            : InkWell(onTap: onTap, mouseCursor: ocptClickableCursor, child: row),
      ),
    );
  }

  /// One amount cell, right-aligned, reading [ocptBudgetEmptyValue] while [text] is null.
  Widget _cell(BuildContext context, String? text) => SizedBox(
    width: _ocptCostTrackingAmountColumnWidth,
    child: Text(
      text ?? ocptBudgetEmptyValue,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

/// The pinned pane's own off-quote row: a twisty, then the `Off quote` label, in the `Poste`
/// column's own place — the identity half of the very same row
/// [_OcptCostTrackingOffQuoteAmountsRow] draws the other half of, exactly the way
/// [_OcptCostTrackingPosteIdentityRow] and [_OcptCostTrackingPosteAmountsRow] split an ordinary
/// poste's row.
///
/// **This row is not a poste, and draws nothing else that would let it pass for one**: no `N°`, no
/// selection highlight and — [_OcptCostTrackingOffQuoteAmountsRow]'s own doc comment argues why —
/// no `⋮` menu either. Neither half carries an `onTap` of its own at all: it is a reading over the
/// journal, not a record anybody can rename, reorder or delete, so clicking the label does nothing
/// rather than quietly calling [OcptBudgetCostTracking.onPosteSelected] with nothing to select.
///
/// **The twisty is the one thing this row can do**: `OcptBudgetCostTracking._buildRows` draws it
/// only while the total holds at least one debit, so it is always expandable the moment it is
/// drawn at all, and opens onto exactly the debits that make the total up — a reader who lands on
/// the aggregate can reach what it sums without knowing another view of the journal exists.
class _OcptCostTrackingOffQuoteIdentityRow extends StatelessWidget {
  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked.
  final VoidCallback onTwistyTap;

  /// Class constructor
  const _OcptCostTrackingOffQuoteIdentityRow({
    required this.isSimplified,
    required this.posteWidth,
    required this.isExpanded,
    required this.onTwistyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return SizedBox(
      height: _ocptCostTrackingRowHeight,
      child: Row(
        children: [
          // Never a poste code, whatever the width — this row is not a poste.
          if (!isSimplified) const SizedBox(width: _ocptCostTrackingNumberColumnWidth),
          SizedBox(
            width: posteWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                children: [
                  _OcptCostTrackingTwisty(
                    isExpandable: true,
                    isExpanded: isExpanded,
                    onTap: onTwistyTap,
                    rowHeight: _ocptCostTrackingRowHeight,
                  ),
                  Expanded(
                    child: Text(
                      tr.budgetCostTrackingOffQuoteLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrolling pane's own off-quote row: only the `Payé` cell carries a figure —
/// [offQuoteTotal]'s own tax-inclusive amount, plain, exactly as an ordinary poste row's own `Payé`
/// cell is. `Devis`, `Engagé`, `Reste`, `Coût final` and `Écart` all print [ocptBudgetEmptyValue]:
/// there is no quote behind this row to measure any of them against, the same silence
/// `docs/architecture/budget.md` already keeps for a figure with nothing to divide by.
///
/// **No `⋮` menu column, unlike an ordinary poste's own amounts row.** Every one of that menu's
/// entries — rename, move, delete — acts on a poste, and this row is not one: it is a reading over
/// the journal's own poste-less debits, with no record of its own to rename, reorder or delete.
class _OcptCostTrackingOffQuoteAmountsRow extends StatelessWidget {
  /// The total of every debit naming no poste at all — this row's own `Payé` figure.
  final OcptBudgetCoveredTotal offQuoteTotal;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCostTrackingOffQuoteAmountsRow({required this.offQuoteTotal, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: _ocptCostTrackingRowHeight,
      child: Row(
        children: [
          _emptyCell(theme), // Devis
          _emptyCell(theme), // Engagé
          _amountCell(theme, ocptBudgetAmountLabel(offQuoteTotal.amountCents, currencyCode)), // Payé
          _emptyCell(theme), // Reste
          _emptyCell(theme), // Coût final
          _emptyCell(theme), // Écart
          const SizedBox(width: _ocptCostTrackingMenuColumnWidth), // no ⋮ menu at all
        ],
      ),
    );
  }

  /// One amount cell, right-aligned, printing [text] as typed.
  Widget _amountCell(ThemeData theme, String text) => SizedBox(
    width: _ocptCostTrackingAmountColumnWidth,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall,
    ),
  );

  /// One amount cell reading [ocptBudgetEmptyValue] — every column this row has no reading for.
  Widget _emptyCell(ThemeData theme) => SizedBox(
    width: _ocptCostTrackingAmountColumnWidth,
    child: Text(ocptBudgetEmptyValue, textAlign: TextAlign.right, style: theme.textTheme.bodySmall),
  );
}

/// The `Devis` column's own cell: the primary figure, then, in small type, the other basis' own
/// figure and — only when the poste's lines all share one — the rate it reads under.
class _OcptCostTrackingQuoteCell extends StatelessWidget {
  /// The amount shown as the headline figure, in the header's own selected basis.
  final int primaryCents;

  /// The amount shown underneath, in the other basis, or null while no line of this poste covers
  /// it at all — "it carries nothing" (`docs/architecture/budget.md`).
  final int? secondaryCents;

  /// The one rate every line of this poste shares, or null while they don't (or none is known) —
  /// see `ocptBudgetPosteUniformVatRateOf`'s own doc comment.
  final OcptBudgetEffectiveVatRate? uniformRate;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCostTrackingQuoteCell({
    required this.primaryCents,
    required this.secondaryCents,
    required this.uniformRate,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryCents = this.secondaryCents;
    final uniformRate = this.uniformRate;

    final secondaryText = secondaryCents == null
        ? null
        : uniformRate == null
        ? ocptBudgetAmountLabel(secondaryCents, currencyCode)
        : "${ocptBudgetAmountLabel(secondaryCents, currencyCode)} · "
              "${ocptVatRatePercentTextOf(uniformRate.basisPoints)} %";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ocptBudgetAmountLabel(primaryCents, currencyCode),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        if (secondaryText != null)
          Text(
            secondaryText,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: uniformRate?.isOverridden == true
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// The pinned pane's own total row: just the `Total` label, spanning the `N°`/`Poste` cells' own
/// width so it lines up with [_OcptCostTrackingAmountsTotalRow], the other half of the very same
/// row, in the scrolling pane.
class _OcptCostTrackingIdentityTotalRow extends StatelessWidget {
  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Class constructor
  const _OcptCostTrackingIdentityTotalRow({required this.isSimplified, required this.posteWidth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: _ocptCostTrackingTotalRowHeight,
        child: Row(
          children: [
            if (!isSimplified) const SizedBox(width: _ocptCostTrackingNumberColumnWidth),
            SizedBox(
              width: posteWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  tr.budgetCostTrackingTotalRowLabel,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrolling pane's own total row: the grand `Devis` total (with its own coverage read-out) and
/// the grand `Payé` total — [paidTotal], [ocptBudgetCoveredTotalsFoldOf]'s own fold of every
/// poste's own paid total and the off-quote total (`OcptBudgetCostTracking`'s own class doc
/// comment), so this column adds up to what has actually left the account, off-quote spending
/// included. `Engagé`, `Reste` and `Écart` are left blank: summing `committedCentsOf` across every
/// poste is not a reduction this table has a reading for (a commitment is always against a poste,
/// so there is no off-quote committed total to fold in), and `Reste`/`Écart` are each read against
/// a poste's own quote, which a grand total has none of.
///
/// `Coût final` is the exception: [finalCostCents] **is** a grand total, computed by
/// `OcptBudgetCostTracking._finalCostTotalOf` poste by poste and only then summed — a typed
/// estimate to complete on one poste is a fact this widget cannot reconstruct from any of the
/// other grand totals it already holds, so the caller resolves it row by row rather than this row
/// re-deriving it from `total`/`paidTotal`. See [_OcptCostTrackingIdentityTotalRow]'s own doc
/// comment for the pinned half of the very same row.
class _OcptCostTrackingAmountsTotalRow extends StatelessWidget {
  /// The grand total, in the header's own selected basis, and how many lines it covers.
  final OcptBudgetCoveredTotal total;

  /// The grand `Payé` total — every poste's own paid total folded with the off-quote total.
  final OcptBudgetCoveredTotal paidTotal;

  /// The grand `Coût final` total — see the class doc comment for why this is summed poste by
  /// poste rather than derived from [total]/[paidTotal].
  final int finalCostCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The total number of live postes.
  final int posteCount;

  /// How many of them count as covered — every one of their own lines is.
  final int coveredPosteCount;

  /// Class constructor
  const _OcptCostTrackingAmountsTotalRow({
    required this.total,
    required this.paidTotal,
    required this.finalCostCents,
    required this.currencyCode,
    required this.posteCount,
    required this.coveredPosteCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final amountText = ocptBudgetAmountLabel(total.amountCents, currencyCode);
    final coverageText = total.isComplete
        ? null
        : tr.budgetCostTrackingCoverageReadOut(amountText, coveredPosteCount, posteCount);
    final paidAmountText = ocptBudgetAmountLabel(paidTotal.amountCents, currencyCode);
    final paidCoverageText = paidTotal.isComplete
        ? null
        : tr.budgetCostTrackingPaidCoverageReadOut(
            paidAmountText,
            paidTotal.coveredLineCount,
            paidTotal.lineCount,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: _ocptCostTrackingTotalRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: _ocptCostTrackingAmountColumnWidth,
              child: Text(
                coverageText ?? amountText,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: _ocptCostTrackingAmountColumnWidth,
              child: Text(
                ocptBudgetEmptyValue,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ), // Engagé
            SizedBox(
              width: _ocptCostTrackingAmountColumnWidth,
              child: Text(
                paidCoverageText ?? paidAmountText,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: _ocptCostTrackingAmountColumnWidth,
              child: Text(
                ocptBudgetEmptyValue,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ), // Reste
            SizedBox(
              width: _ocptCostTrackingAmountColumnWidth,
              child: Text(
                ocptBudgetAmountLabel(finalCostCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: _ocptCostTrackingAmountColumnWidth,
              child: Text(
                ocptBudgetEmptyValue,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ), // Écart
            const SizedBox(width: _ocptCostTrackingMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}

/// The table's own `+ Poste` creation footer, drawn below the table rather than as one of its own
/// scrolling rows — left-aligned like the pinned pane above it, and, unlike it, never scrolled
/// away by either the table's own vertical or horizontal scroll.
class _OcptCostTrackingCreationFooter extends StatelessWidget {
  /// Called when this footer is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptCostTrackingCreationFooter({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              tr.budgetPosteCreationAction,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
