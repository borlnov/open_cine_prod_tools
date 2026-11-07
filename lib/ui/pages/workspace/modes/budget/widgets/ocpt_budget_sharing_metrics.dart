// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The width, in logical pixels, under which the two columns stack instead of sitting side by
/// side — mirrors `OcptBudgetLogistics`'s own `_ocptLogisticsWrapWidth`.
const double ocptBudgetSharingWrapWidth = 1000;

/// The `Share`/`Due`/`Paid`/`Reinvested` columns' own fixed width, in logical pixels — matches
/// `OcptBudgetFinancing`'s own amount columns.
const double ocptBudgetSharingAmountColumnWidth = 108;

/// The `Share` column's own fixed width, in logical pixels — narrower than an amount column, a
/// percentage never running as wide as a currency figure.
const double ocptBudgetSharingPercentColumnWidth = 72;

/// The `Repaying the contributions` card's own `Contributed`/`Repaid`/`Owed` columns' own fixed
/// width, in logical pixels — narrower than [ocptBudgetSharingAmountColumnWidth], the card carrying
/// three of them side by side rather than one.
const double ocptBudgetSharingRepaymentAmountColumnWidth = 84;

/// The width of the contributor rows' own `⋮` menu column, in logical pixels — kept blank in the
/// header above them so the four amount columns stay under their own headings.
const double ocptBudgetSharingRepaymentMenuColumnWidth = 36;

/// The trailing `⋮` menu column's own fixed width, in logical pixels — matches every other table
/// of this mode's own menu column.
const double ocptBudgetSharingMenuColumnWidth = 36;
