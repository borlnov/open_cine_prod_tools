// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The width, in logical pixels, under which the two columns stack instead of sitting side by
/// side — see "A stacked pane states its height" in `docs/architecture/budget.md`, raised a
/// little for the catering table's own eight columns.
const double ocptBudgetLogisticsWrapWidth = 1000;

/// The catering table's own `Day` column width, in logical pixels.
const double ocptBudgetLogisticsDayColumnWidth = 56;

/// The catering table's own `Crew`/`Cast`/`Extras` column width, in logical pixels — three narrow,
/// numeric columns.
const double ocptBudgetLogisticsCountColumnWidth = 64;

/// The catering table's own `Total` column width, in logical pixels — mirrors
/// `OcptBudgetCostTracking`'s own amount columns.
const double ocptBudgetLogisticsCateringTotalColumnWidth = 108;

/// The catering table's own `Meals`/`Craft services` column width, in logical pixels — wider than
/// [ocptBudgetLogisticsCountColumnWidth]: the `Meals` cell can read several sittings joined
/// together (`12 + 8`) and the `Craft services` header is two words.
const double ocptBudgetLogisticsWideCountColumnWidth = 96;

/// The defrayal table's own `Advanced`/`Reimbursed`/`Owed` column width, in logical pixels —
/// mirrors `OcptBudgetFinancing`'s own `_ocptResourcesAmountColumnWidth`, the three money columns
/// this table's own person tree mirrors exactly.
const double ocptBudgetLogisticsAllowanceAmountColumnWidth = 108;

/// The defrayal table's own trailing `⋮` menu column width, in logical pixels.
const double ocptBudgetLogisticsAllowanceMenuColumnWidth = 36;

/// The twisty every person group row draws, in logical pixels — mirrors `OcptBudgetFinancing`'s own
/// `_ocptResourcesTwistyWidth` exactly: 28, the theme's own floor for an icon button's own tap
/// target, its own tap target running the full height of the row it sits on
/// (`OcptBudgetLogisticsAllowanceTwisty`'s own doc comment).
const double ocptBudgetLogisticsAllowanceTwistyWidth = 28;

/// How far a sub-row indents under its own person group, in logical pixels — mirrors
/// `OcptBudgetFinancing`'s own `_ocptResourcesIndentStep`: a defrayal or a reimbursement sits one
/// step in from the person it names.
const double ocptBudgetLogisticsAllowanceIndentStep = 16;

/// A defrayal or a reimbursement sub-row's own fixed height, in logical pixels — one step shorter
/// than [ocptBudgetLogisticsAllowanceRowHeight], mirroring `OcptBudgetFinancing`'s own
/// `_ocptResourcesReceiptRowHeight`.
const double ocptBudgetLogisticsAllowanceSubRowHeight = 32;

/// The narrowest the `Person`/detail column is ever drawn, in logical pixels — past this, the table
/// scrolls sideways inside its own frame rather than crushing a person's own name or a sub-row's
/// own wording, mirroring `OcptBudgetFinancing`'s own `_ocptResourcesRessourceColumnMinWidth`.
const double ocptBudgetLogisticsAllowanceDetailColumnMinWidth = 220;

/// A reimbursement sub-row's own leading dot, in logical pixels — mirrors `OcptBudgetFinancing`'s
/// own `_ocptResourcesDotDiameter`.
const double ocptBudgetLogisticsAllowanceDotDiameter = 8;

/// Either table's own header row height, in logical pixels.
const double ocptBudgetLogisticsHeaderRowHeight = 36;

/// A catering row's own fixed height, in logical pixels — one line for the day tag, one for the
/// decor's own date underneath it.
const double ocptBudgetLogisticsCateringRowHeight = 52;

/// A defrayal row's own fixed height, in logical pixels — mirrors
/// [ocptBudgetLogisticsCateringRowHeight] for the person's own name-and-role pair.
const double ocptBudgetLogisticsAllowanceRowHeight = 52;

/// The narrowest the catering table is drawn at before it starts scrolling sideways, in logical
/// pixels: its seven fixed columns (548) plus a floor of 220 for the decor's own wording, the one
/// column sized by nothing but an `Expanded`.
///
/// The defrayal table beside it already had [ocptBudgetLogisticsAllowanceMinTableWidth] for this;
/// the catering table went without one and lost its decor column outright the moment the right dock
/// opened, exactly as the cash journal did.
const double ocptBudgetLogisticsCateringMinTableWidth = 768;

/// The narrowest the defrayal table is ever drawn at, in logical pixels: its three money columns
/// and its menu column — 3 × 108 + 36 = 360 — plus
/// [ocptBudgetLogisticsAllowanceDetailColumnMinWidth], **no** extra row inset added, unlike
/// `OcptBudgetFinancing`'s own `_ocptResourcesMinTableWidth`: this table's own rows carry no
/// `ocptTableRowHorizontalPadding` of their own, the Card's own `all(12)` padding already framing
/// the whole table once, header, rows and total alike.
///
/// Below it the table **scrolls sideways inside its own frame**, exactly as the cash journal's own
/// does and for the same reason: the `Person`/detail column is the only flexible one, and this
/// table lives in the narrower third of a two-column view, so a modest centre used to drive it to
/// nothing.
const double ocptBudgetLogisticsAllowanceMinTableWidth =
    3 * ocptBudgetLogisticsAllowanceAmountColumnWidth +
    ocptBudgetLogisticsAllowanceMenuColumnWidth +
    ocptBudgetLogisticsAllowanceDetailColumnMinWidth;

/// The gap between the two panes once they stack, in logical pixels.
const double ocptBudgetLogisticsStackGap = 24;

/// A table card's own chrome, in logical pixels: its padding, its header row, the two dividers
/// framing the rows and the total row under them — everything it draws before a single day or
/// defrayal is.
const double ocptBudgetLogisticsCardChromeHeight = 110;

/// The fewest and the most rows a table card is ever sized for once the panes stack.
///
/// **Stacked, a card is sized by its own content rather than by a share of the height.** Both panes
/// used to take an `Expanded` share of whatever the view had, which works while the view is tall
/// and fails silently once it is not: a share smaller than the heading band and
/// [ocptBudgetLogisticsCardChromeHeight] leaves the `ListView` nothing at all, so the table prints
/// its header and its total with no day between them, and the pane then spills over the defrayals
/// underneath. Sized by its rows instead, a card always shows them, the heading band always takes
/// the height it needs, and **the view scrolls** when the two together are taller than it — the
/// same answer [ocptBudgetLogisticsCateringMinTableWidth] gives sideways.
const int ocptBudgetLogisticsStackedMinRowCount = 2;

/// The most rows a stacked table card is ever sized for, past which it stops growing and its rows
/// scroll.
const int ocptBudgetLogisticsStackedMaxRowCount = 8;

/// The shortest either pane is drawn at while they sit side by side, in logical pixels — under it
/// the pair scrolls rather than being crushed, exactly as it does stacked.
const double ocptBudgetLogisticsPaneMinHeight = 320;
