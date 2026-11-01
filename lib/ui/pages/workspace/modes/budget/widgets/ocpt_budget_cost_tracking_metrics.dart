// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The `N°` column's own fixed width, in logical pixels — detailed header only.
const double ocptBudgetCostTrackingNumberColumnWidth = 44;

/// The `Devis`, `Engagé`, `Payé`, `Reste`, `Coût final` and `Écart` columns' own fixed width, in
/// logical pixels.
const double ocptBudgetCostTrackingAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels.
const double ocptBudgetCostTrackingMenuColumnWidth = 36;

/// The narrowest the `Poste` column is ever drawn, in logical pixels — past this, the scrolling
/// pane (the amount columns) scrolls horizontally under the pinned identity pane rather than
/// crushing the poste names, mirroring `OcptBreakdownRecapTable`'s own
/// `_ocptRecapElementColumnMinWidth`.
const double ocptBudgetCostTrackingPosteColumnMinWidth = 220;

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
const double ocptBudgetCostTrackingRowHeight = 48;

/// A line, a commitment, an entry or the muted "no entry" hint's own fixed height, in logical
/// pixels — one step shorter than `ocptBudgetCostTrackingRowHeight`, the mockup's own reading for a
/// sub-row, and, for the very same reason that constant argues, a **named** height rather than one
/// sized to a sub-row's own content: the identity pane draws a sub-row's indentation and its own
/// label while the amounts pane draws its figures, and the two have to agree on a height with
/// nothing shared to agree through but this constant.
const double ocptBudgetCostTrackingSubRowHeight = 36;

/// The header row's own fixed height, in logical pixels — see `ocptBudgetCostTrackingRowHeight`'s own
/// doc comment for why the two panes need every row, the header included, to claim a named height
/// rather than size to its own single-line content.
const double ocptBudgetCostTrackingHeaderRowHeight = 36;

/// The total row's own fixed height, in logical pixels — tall enough for
/// `tr.budgetCostTrackingCoverageReadOut`'s own two lines, printed here in place of the plain
/// amount while the excluding-tax total does not yet cover every poste; see
/// `ocptBudgetCostTrackingRowHeight`'s own doc comment for why a named height, not the tallest cell's
/// own, is what keeps this row's two panes aligned.
const double ocptBudgetCostTrackingTotalRowHeight = 48;

/// How far a sub-row indents for every step of tree depth, in logical pixels — a quote line sits
/// one step in from its own poste, a commitment or an entry two.
const double ocptBudgetCostTrackingIndentStep = 16;

/// The twisty's own fixed width, in logical pixels, whether it draws an arrow or sits blank —
/// reserved on every row a twisty could appear on (a poste, a quote line) so a poste or line with
/// nothing to expand still lines its own label up with a sibling that does. 28, the theme's own
/// floor for an icon button's own tap target, not the 20 an earlier pass under-sized it at
/// (`docs/architecture/budget.md`) — its own tap target runs the
/// **full height** of whichever row it sits on rather than squaring off at this same figure, see
/// `OcptBudgetCostTrackingTwisty`'s own doc comment.
const double ocptBudgetCostTrackingTwistyWidth = 28;

/// The diameter of a commitment or an entry sub-row's own coloured dot, in logical pixels.
const double ocptBudgetCostTrackingDotDiameter = 8;

/// The widest a commitment or an entry sub-row's own trailing badge is ever drawn, in logical
/// pixels — capped so a long status word never overflows the row it sits in, see
/// `OcptBudgetCostTrackingSubLabel`'s own build method.
const double ocptBudgetCostTrackingBadgeMaxWidth = 84;

/// The widest the empty state's own `OcptWorkspaceEmptyMode`/`OcptBudgetFeedCard` pair is ever
/// drawn, in logical pixels — centred rather than run the width of the screen.
const double ocptBudgetCostTrackingEmptyStateMaxWidth = 480;

/// A poste card's own proportion bar's own height, in logical pixels — matches
/// `OcptBudgetFiche`'s own poste-variant proportion bar, the mode's own established reading of the
/// same paid/committed/overrun figures.
const double ocptBudgetCostTrackingCardProportionBarHeight = 8;

/// The gap, in logical pixels, between one poste card and the next in the compact list.
const double ocptBudgetCostTrackingCardSpacing = 12;

/// The off-quote row's own reserved id in `OcptBudgetState.expandedNodeIds` — no poste, quote line,
/// resource or revenue can ever collide with it, since every one of those mints a UUID and this
/// string is not one. The off-quote row sums a reading over the journal rather than naming a record
/// of its own, so it has no id to key its own expansion by except one this file reserves for it.
const String ocptBudgetCostTrackingOffQuoteNodeId = "off-quote";
