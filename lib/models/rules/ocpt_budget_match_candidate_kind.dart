// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_match_suggestion.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_match.dart';

/// What kind of object an [OcptBudgetMatchSuggestion] points at — which of the four ledgers the
/// matched row lives in, so the caller knows which id to write and which wording to offer.
///
/// **What this file is for.** The entry wizard's own form carries a direction, an amount, a date
/// and free-typed wording, and [ocptBudgetMatchSuggestionsOf] says what that draft could be for —
/// the commitments still owed, the defrayals still unpaid, the resources still to come or the
/// revenues still expected, whichever the direction makes eligible — and *why* each one was
/// offered, so the reconciliation strip can word the offer ("même montant, même fournisseur")
/// without this file ever knowing a word of it. Pure: no database, no `Tr`, no formatted string.
///
/// **The defrayals are the one kind this file has to be careful with.** Nothing in the schema
/// records that a defrayal has been paid — there is no `settledEntryId` on `budget_allowances` and
/// no link from a `budget_entries` row to one, and none has ever been added. So every live defrayal
/// is a candidate, unlike a commitment or a resource, which are pre-filtered to the ones still owed
/// or still short. What keeps that honest is the very ranking [ocptBudgetMatchSuggestionsOf]
/// applies: a defrayal only ever survives its own filter, and is only ever offered, when its own
/// figure actually agrees with the draft on amount, date or wording — never because it is merely
/// unpaid, since this file has no way to know that.
///
/// Every list [ocptBudgetMatchSuggestionsOf] reads is assumed **already live** — every synchronised
/// table's own tombstones are filtered back out at the very read that loaded the list
/// (`OcptBudgetJournalService.loadCommitments`, `OcptBudgetAllowancesService.loadAllowances`,
/// `OcptBudgetFinancingService.loadResources`, `OcptBudgetSharingService.loadRevenues`), exactly
/// the assumption every other util under `lib/models/rules/ocpt_budget_*.dart` already makes of the
/// lists it is handed rather than re-checking `isDeleted` itself.
enum OcptBudgetMatchCandidateKind {
  /// An [OcptBudgetCommitment] still owed — offered only against a debit.
  commitment,

  /// An [OcptBudgetAllowance] defrayal — offered only against a debit. See the file's own doc
  /// comment for why every live one is a candidate, never pre-filtered as "unpaid".
  defrayal,

  /// An [OcptBudgetResource] still short of what it is meant to bring in — offered only against a
  /// credit.
  resource,

  /// An [OcptBudgetRevenue] still short of what it is expected to bring in — offered only against a
  /// credit.
  revenue,
}
