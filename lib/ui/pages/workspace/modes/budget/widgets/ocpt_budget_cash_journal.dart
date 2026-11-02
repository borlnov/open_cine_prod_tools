// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_header_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_shareable_reminder.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_statement_footer_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_upcoming_footer_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_upcoming_header_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_upcoming_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';

/// The tools drawer's `Flux de trésorerie` page: the whole account book, in date order — **every
/// movement the project has ever recorded, debit and credit alike**, read-only. The entry table
/// closed by its own balance row, `À venir` under it closed by its own, then a note — the layout
/// mockup `4b` lays this view out as.
///
/// **This is the one place a movement naming nothing can still be reached.** An account, a resource
/// or a revenue each has a document of its own to be found under; an entry naming none of them — a
/// till receipt for something the nomenclature never anticipated, a subsidy instalment recorded
/// before anyone got round to naming the resource it pays — lives nowhere else, so this table draws
/// **every** live entry the journal holds rather than a reading over some of them. Narrowing it to
/// one direction, the way an earlier reading of this view once did, put exactly such an entry out
/// of reach: a credit naming nothing was drawn in no view of the mode at all, and could be neither
/// selected, edited nor deleted.
///
/// **[entries] is always the whole journal, and the table draws every one of them — this page no
/// longer honours the header's own account filter at all** (`ocptBudgetViewHonoursAccountFilter` is
/// now `OcptBudgetView.expenses` alone): a bank statement reads across the whole account, not one
/// category narrowed out of it, and mockup `4b` draws no filtered reading of this page. The closing
/// balance ([OcptBudgetCashStatementFooterRow]) is the whole journal's, unchanged — Benoit's own
/// ruling is that this is the production's bank account, and it does not change because a view
/// narrowed to one account.
///
/// **No capture affordance of any kind — read-only means nothing is created from a statement, not
/// that nothing can be touched.** The `+ Entry` action mockup `2a`/`3a` used to draw here is gone
/// for good; an entry spotted on the statement is corrected through the right dock's own detail
/// panel, which is exactly why every row **stays selectable** and its own `⋮` menu keeps
/// `Modifier`/`Supprimer` — mockup `4b`'s own dock hint is explicit that the detail panel is where
/// an entry gets corrected, never a capture affordance of this page's own. A composite panel
/// (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather than a null callback
/// per affordance, and withholds — never disables — its own `⋮` menu's `Edit`/`Delete` entries. A
/// row's own click never writes either way — it selects the entry, opening the right dock's detail
/// panel on it, mirroring `OcptBudgetCostTracking`'s own row selection.
///
/// Empty state: [OcptWorkspaceEmptyMode] draws **in the table's place** whenever the page has
/// nothing at all to read — no live entry *and* no unsettled
/// commitment. A project that has committed spending before paying anything is the ordinary state
/// of an early production, and it is precisely the one that needs `À venir`: hiding the whole page
/// behind "no movement yet" would put its own commitments out of reach on the very page built to
/// list them.
///
/// A read-only view can return the empty state as its whole body because it writes nothing at
/// all; this view cannot.
///
/// **Under the statement, `À venir` reads the account's future rather than its past** — one row per
/// unsettled commitment, in [OcptBudgetProjection.steps]' own due-date-first order, then a footer
/// naming the total falling due and the balance the account would hold once it has. It is built
/// from [commitments] and the statement's own closing balance, through `ocptBudgetProjectionOf`
/// (`lib/models/rules/ocpt_budget_projection.dart`) — never re-sorted here, exactly as that
/// function's own doc comment argues. **Drawn only while at least one unsettled commitment
/// exists**, and it carries no empty state of its own: a project owing nothing simply has no second
/// card. Both sections scroll **together**, as slivers of the very same [CustomScrollView], under
/// the one fixed header row above them — two independent scroll areas would let a reader scroll the
/// statement while `À venir` stayed put, which is not a statement any more.
///
/// **A due row is selectable, never a write** — it dispatches [onCommitmentSelected], opening the
/// right dock's detail panel on the commitment, which is where it is edited or settled — so, unlike
/// the entry table's own `⋮` menu, it is never withheld under [isReadOnly]. `À venir` draws no `⋮`
/// menu of its own at all: `Modifier`/`Supprimer`/`Payer` on a commitment live in the detail panel
/// and only there.
class OcptBudgetCashJournal extends StatelessWidget {
  /// Every live entry of the whole journal, in the chronological order
  /// `OcptBudgetJournalService.loadEntries` already gives them — never reordered by the caller,
  /// and drawn whole, this page honouring no filter of its own (see the class doc comment).
  final List<OcptBudgetEntry> entries;

  /// Every live commitment of the project, settled ones included — **never pre-filtered to the
  /// unsettled ones**: `ocptBudgetProjectionOf` excludes a settled commitment itself, and its own
  /// doc comment argues why that exclusion belongs there rather than in a caller (see the class doc
  /// comment's own `À venir` paragraph).
  final List<OcptBudgetCommitment> commitments;

  /// Every live account of the project, used to resolve an entry's or a commitment's own account
  /// name.
  final List<OcptBudgetAccount> accounts;

  /// Every live voucher, keyed by the entry it evidences — an entry with no key here carries no
  /// voucher at all. Read by each row's own small marker (never a second column of text), which
  /// also says when the referenced file no longer resolves.
  final Map<String, OcptAssetRef> receiptsByEntryId;

  /// What is currently selected for the right dock's own detail panel — a row reads highlighted
  /// while it is an [OcptBudgetEntrySelection] naming its own id.
  final OcptBudgetSelection? selection;

  /// Whether the header's simplified/detailed switch currently reads simplified — switches an
  /// account's own displayed name between `simpleLabel` and `code · label`.
  final bool isSimplified;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called with an entry's id when its row is clicked — never withheld under [isReadOnly], since
  /// selecting only opens the right dock's own detail panel on it, it writes nothing.
  final ValueChanged<String>? onEntrySelected;

  /// Called with an entry when its row's own `⋮` menu asks to edit it, opening the entry dialog on
  /// it, or null while [isReadOnly].
  final ValueChanged<OcptBudgetEntry>? onEntryEditRequested;

  /// Called with an entry's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onEntryDeletionRequested;

  /// Called with a commitment's id when an `À venir` row is clicked — never withheld under
  /// [isReadOnly], for the very reason [onEntrySelected] never is: selecting only opens the right
  /// dock's own detail panel on it, it writes nothing.
  final ValueChanged<String>? onCommitmentSelected;

  /// What the revenue sharing has to distribute, in cents — `OcptBudgetSharingPot.shareableCents`.
  /// Drawn as a quiet reminder under the closing balance **only while it is above zero**, so a
  /// reader does not mistake the bank balance for it: the two are computed differently (the balance
  /// is cash on hand, the shareable pot is the takings less the contributions to repay), and a
  /// production reading its account here reported taking the whole balance for what there was to
  /// share. Nothing to share yet means nothing to clarify, so the line is withheld.
  final int shareableCents;

  /// Called when the shareable reminder's own link to the revenue-sharing view is clicked — never
  /// withheld under [isReadOnly], since it only switches view and writes nothing. Null draws the
  /// reminder without a link.
  final VoidCallback? onOpenSharing;

  /// Class constructor
  const OcptBudgetCashJournal({
    super.key,
    required this.entries,
    required this.commitments,
    required this.accounts,
    required this.receiptsByEntryId,
    required this.selection,
    required this.isSimplified,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isReadOnly,
    required this.onEntrySelected,
    required this.onEntryEditRequested,
    required this.onEntryDeletionRequested,
    required this.onCommitmentSelected,
    required this.shareableCents,
    required this.onOpenSharing,
  });

  /// Build the budget cash journal as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    final rows = ocptBudgetJournalRowsOf(
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final totals = ocptBudgetCashTotalsOf(
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final projection = ocptBudgetProjectionOf(
      openingBalanceCents: totals.balanceCents,
      commitments: commitments,
      entries: entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final showsUpcoming = projection.commitmentCount > 0;
    final commitmentsById = {for (final commitment in commitments) commitment.id: commitment};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: entries.isEmpty && !showsUpcoming
              ? OcptWorkspaceEmptyMode(
                  icon: Icons.account_balance_wallet_outlined,
                  // The detailed wording names this ledger by its trade word, which is exactly
                  // what the simplified reading is set to spare a crew — and the empty state is
                  // the one sentence somebody who has never opened this view will read.
                  message: isSimplified
                      ? tr.budgetCashJournalSimpleEmptyHint
                      : tr.budgetCashJournalEmptyHint,
                )
              : LayoutBuilder(
                  builder: (context, constraints) => OcptHorizontalScrollView(
                    // The header and the rows scroll **together**, inside one frame: they share
                    // the same fixed column widths, so scrolling either alone would slide the
                    // figures out from under their own headings.
                    child: SizedBox(
                      width: math.max(constraints.maxWidth, ocptBudgetCashJournalMinTableWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ocpt_theme.ocptTableRowHorizontalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const OcptBudgetCashJournalHeaderRow(),
                            Expanded(
                              // A single scroll region for both sections, the statement's own
                              // entries first, `À venir` under them as slivers of its own — see the
                              // class doc comment for why the two must never scroll apart.
                              child: CustomScrollView(
                                slivers: [
                                  SliverList.builder(
                                    itemCount: rows.length,
                                    itemBuilder: (context, index) => OcptBudgetCashJournalRow(
                                      row: rows[index],
                                      account: _accountById(rows[index].entry.accountId),
                                      receipt: receiptsByEntryId[rows[index].entry.id],
                                      isSelected: _isEntrySelected(rows[index].entry.id),
                                      isSimplified: isSimplified,
                                      currencyCode: currencyCode,
                                      onTap: onEntrySelected == null
                                          ? null
                                          : () => onEntrySelected?.call(rows[index].entry.id),
                                      onEditRequested: isReadOnly || onEntryEditRequested == null
                                          ? null
                                          : () => onEntryEditRequested?.call(rows[index].entry),
                                      onDeletionRequested:
                                          isReadOnly || onEntryDeletionRequested == null
                                          ? null
                                          : () => onEntryDeletionRequested?.call(
                                              rows[index].entry.id,
                                            ),
                                    ),
                                  ),
                                  if (rows.isNotEmpty) ...[
                                    SliverToBoxAdapter(
                                      child: OcptBudgetCashStatementFooterRow(
                                        closingDate: rows.last.entry.date,
                                        balanceCents: totals.balanceCents,
                                        currencyCode: currencyCode,
                                      ),
                                    ),
                                    if (shareableCents > 0)
                                      SliverToBoxAdapter(
                                        child: OcptBudgetCashShareableReminder(
                                          shareableCents: shareableCents,
                                          currencyCode: currencyCode,
                                          onOpenSharing: onOpenSharing,
                                        ),
                                      ),
                                    if (!totals.isComplete)
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Text(
                                            tr.budgetCashJournalCoverageReadOut(
                                              totals.coveredEntryCount,
                                              totals.entryCount,
                                            ),
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                  if (showsUpcoming) ...[
                                    const SliverToBoxAdapter(
                                      child: OcptBudgetCashUpcomingHeaderRow(),
                                    ),
                                    SliverList.builder(
                                      itemCount: projection.steps.length,
                                      itemBuilder: (context, index) {
                                        final step = projection.steps[index];
                                        final commitment = commitmentsById[step.commitmentId]!;

                                        return OcptBudgetCashUpcomingRow(
                                          step: step,
                                          commitment: commitment,
                                          account: _accountById(commitment.accountId),
                                          isSelected: _isCommitmentSelected(commitment.id),
                                          isSimplified: isSimplified,
                                          currencyCode: currencyCode,
                                          onTap: onCommitmentSelected == null
                                              ? null
                                              : () => onCommitmentSelected?.call(commitment.id),
                                        );
                                      },
                                    ),
                                    SliverToBoxAdapter(
                                      child: OcptBudgetCashUpcomingFooterRow(
                                        totalDueCents:
                                            projection.openingBalanceCents -
                                            projection.finalBalanceCents,
                                        projectedBalanceCents: projection.finalBalanceCents,
                                        currencyCode: currencyCode,
                                      ),
                                    ),
                                    if (projection.coveredCommitmentCount !=
                                        projection.commitmentCount)
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Text(
                                            tr.budgetCashUpcomingCoverageReadOut(
                                              projection.coveredCommitmentCount,
                                              projection.commitmentCount,
                                            ),
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          tr.budgetCashJournalWholeJournalNote,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// Tell whether entry [entryId] is the currently selected one — mirrors
  /// `OcptBudgetCostTracking._isEntrySelected`.
  bool _isEntrySelected(String entryId) {
    final selection = this.selection;
    return selection is OcptBudgetEntrySelection && selection.entryId == entryId;
  }

  /// Tell whether commitment [commitmentId] is the currently selected one — mirrors
  /// [_isEntrySelected]
  /// for the `À venir` section's own rows.
  bool _isCommitmentSelected(String commitmentId) {
    final selection = this.selection;
    return selection is OcptBudgetCommitmentSelection && selection.commitmentId == commitmentId;
  }

  /// Get [accounts]' own entry naming [accountId], or null while [accountId] is null or names no
  /// live account —
  /// mirrors `OcptBudgetState.selectedAccount`'s own reading.
  OcptBudgetAccount? _accountById(String? accountId) {
    if (accountId == null) {
      return null;
    }

    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }

    return null;
  }
}
