// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// The `Dossier` column's own fixed width, in logical pixels — matches
/// `OcptBudgetCostTracking`'s own status-shaped columns.
const double ocptBudgetFinancingDossierColumnWidth = 132;

/// The `Promis`, `Rentré` and `Reste à venir` columns' own fixed width, in logical pixels.
const double ocptBudgetFinancingAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels — matches every other table
/// of this mode's own menu column.
const double ocptBudgetFinancingMenuColumnWidth = 36;

/// The narrowest the `Ressource` column is ever drawn, in logical pixels — past this, the table
/// scrolls sideways inside its own frame rather than crushing a resource's or a taking's own name,
/// mirroring `OcptBudgetCostTracking`'s own `_ocptCostTrackingAccountColumnMinWidth`.
const double ocptBudgetFinancingResourceColumnMinWidth = 220;

/// The narrowest the whole table is ever drawn at, in logical pixels — every fixed column's own
/// width plus `ocptBudgetFinancingResourceColumnMinWidth` and the row's own 24 px inset
/// (`ocptTableRowHorizontalPadding`, symmetric). Mirrors `OcptBudgetCashJournal`'s own
/// `_ocptCashJournalMinTableWidth`, and "The journal scrolls rather than losing a column" in
/// `docs/architecture/budget.md`.
const double ocptBudgetFinancingMinTableWidth =
    ocptBudgetFinancingDossierColumnWidth +
    3 * ocptBudgetFinancingAmountColumnWidth +
    ocptBudgetFinancingMenuColumnWidth +
    ocptBudgetFinancingResourceColumnMinWidth +
    2 * ocpt_theme.ocptTableRowHorizontalPadding;

/// A family, a resource or a revenue row's own fixed height, in logical pixels.
const double ocptBudgetFinancingRowHeight = 44;

/// A receipt sub-row's own fixed height, in logical pixels — one step shorter than
/// `ocptBudgetFinancingRowHeight`, mirroring `OcptBudgetCostTracking`'s own
/// `_ocptCostTrackingSubRowHeight`.
const double ocptBudgetFinancingReceiptRowHeight = 32;

/// The header row's own fixed height, in logical pixels.
const double ocptBudgetFinancingHeaderRowHeight = 36;

/// The total row's own fixed height, in logical pixels — tall enough for the `Dossier` column's
/// own two-line valued caption.
const double ocptBudgetFinancingTotalRowHeight = 44;

/// How far a row indents for every step of tree depth, in logical pixels — a resource or a taking
/// sits one step in from its own family, a receipt two, mirroring
/// `OcptBudgetCostTracking`'s own `_ocptCostTrackingIndentStep`.
const double ocptBudgetFinancingIndentStep = 16;

/// The twisty's own fixed width, in logical pixels, whether it draws an arrow or sits blank. 28,
/// the theme's own floor for an icon button's own tap target, not the 20 an earlier pass
/// under-sized it at (`docs/architecture/budget.md`) — its own
/// tap target runs the full height of the row it sits on, see `OcptBudgetFinancingTwisty`'s own doc
/// comment.
const double ocptBudgetFinancingTwistyWidth = 28;

/// A receipt sub-row's own leading dot, in logical pixels.
const double ocptBudgetFinancingDotDiameter = 8;

/// The coverage band's own leading column width, in logical pixels — what the film costs, stated
/// at a width of its own so a long coverage read-out wraps inside it rather than pushing the bar
/// beside it off the card.
const double ocptBudgetFinancingCoverageNeedsColumnWidth = 200;

/// The two-tone coverage bar's own height, in logical pixels.
const double ocptBudgetFinancingCoverageBarHeight = 8;
