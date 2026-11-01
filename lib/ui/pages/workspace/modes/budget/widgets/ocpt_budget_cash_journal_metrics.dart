// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// The `Date` column's own fixed width, in logical pixels.
const double ocptBudgetCashJournalDateColumnWidth = 92;

/// The `Voucher` column's own fixed width, in logical pixels.
const double ocptBudgetCashJournalVoucherColumnWidth = 76;

/// The `Poste` column's own fixed width, in logical pixels.
const double ocptBudgetCashJournalPosteColumnWidth = 200;

/// The `Debit`, `Credit` and `Balance` columns' own fixed width, in logical pixels.
const double ocptBudgetCashJournalAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels — matches
/// `OcptBudgetCostTracking`'s own menu column, the same affordance drawn the same size.
const double ocptBudgetCashJournalMenuColumnWidth = 36;

/// The narrowest the entry table is ever drawn at, in logical pixels: every fixed column's own
/// width — 92 + 76 + 200 + 3 × 108 + 36 = 728 — plus the row's own 24 px inset
/// ([ocpt_theme.ocptTableRowHorizontalPadding], symmetric) and 232 for a `Label` column that can still hold a
/// wording: 728 + 24 + 232 = 984.
///
/// Below it the table **scrolls sideways inside its own frame** rather than being crushed: the
/// `Label` column is the only flexible one, so a narrower centre used to drive it to nothing and
/// the row overflowed — which is exactly what opening the right dock on a laptop screen does. No
/// column is dropped and none shrinks; the reader gets a horizontal scrollbar and keeps the whole
/// ledger, the treatment the rest of the app already gives a table too wide for its slot.
const double ocptBudgetCashJournalMinTableWidth = 984;

/// Every entry row's own fixed height, in logical pixels.
const double ocptBudgetCashJournalRowHeight = 44;

/// The header row's own fixed height, in logical pixels.
const double ocptBudgetCashJournalHeaderRowHeight = 36;
