// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';

/// The `Date` column's own fixed width, in logical pixels.
const double _ocptCashJournalDateColumnWidth = 92;

/// The `Voucher` column's own fixed width, in logical pixels.
const double _ocptCashJournalVoucherColumnWidth = 76;

/// The `Poste` column's own fixed width, in logical pixels.
const double _ocptCashJournalPosteColumnWidth = 200;

/// The `Debit`, `Credit` and `Balance` columns' own fixed width, in logical pixels.
const double _ocptCashJournalAmountColumnWidth = 108;

/// The trailing `⋮` menu column's own fixed width, in logical pixels — matches
/// `OcptBudgetCostTracking`'s own menu column, the same affordance drawn the same size.
const double _ocptCashJournalMenuColumnWidth = 36;

/// The narrowest the entry table is ever drawn at, in logical pixels: every fixed column's own
/// width — 92 + 76 + 200 + 3 × 108 + 36 = 728 — plus the row's own 24 px inset
/// ([ocptTableRowHorizontalPadding], symmetric) and 232 for a `Label` column that can still hold a
/// wording: 728 + 24 + 232 = 984.
///
/// Below it the table **scrolls sideways inside its own frame** rather than being crushed: the
/// `Label` column is the only flexible one, so a narrower centre used to drive it to nothing and
/// the row overflowed — which is exactly what opening the right dock on a laptop screen does. No
/// column is dropped and none shrinks; the reader gets a horizontal scrollbar and keeps the whole
/// ledger, the treatment the rest of the app already gives a table too wide for its slot.
const double _ocptCashJournalMinTableWidth = 984;

/// Every entry row's own fixed height, in logical pixels.
const double _ocptCashJournalRowHeight = 44;

/// The header row's own fixed height, in logical pixels.
const double _ocptCashJournalHeaderRowHeight = 36;

/// The tools drawer's `Flux de trésorerie` page: the whole account book, in date order — **every
/// movement the project has ever recorded, debit and credit alike**, read-only. The entry table
/// closed by its own balance row, `À venir` under it closed by its own, then a note — the layout
/// mockup `4b` lays this view out as.
///
/// **This is the one place a movement naming nothing can still be reached.** A poste, a resource or
/// a revenue each has a document of its own to be found under; an entry naming none of them — a
/// till receipt for something the nomenclature never anticipated, a subsidy instalment recorded
/// before anyone got round to naming the resource it pays — lives nowhere else, so this table draws
/// **every** live entry the journal holds rather than a reading over some of them. Narrowing it to
/// one direction, the way an earlier reading of this view once did, put exactly such an entry out
/// of reach: a credit naming nothing was drawn in no view of the mode at all, and could be neither
/// selected, edited nor deleted.
///
/// **[entries] is always the whole journal, and the table draws every one of them — this page no
/// longer honours the header's own poste filter at all** (`ocptBudgetViewHonoursPosteFilter` is
/// now `OcptBudgetView.expenses` alone): a bank statement reads across the whole account, not one
/// category narrowed out of it, and mockup `4b` draws no filtered reading of this page. The closing
/// balance ([_OcptCashStatementFooterRow]) is the whole journal's, unchanged — Benoit's own ruling
/// is that this is the production's bank account, and it does not change because a view narrowed to
/// one poste.
///
/// **No capture affordance of any kind — read-only means nothing is created from a statement, not
/// that nothing can be touched.** The `+ Entry` action mockup `2a`/`3a` used to draw here is gone
/// for good; an entry spotted on the statement is corrected through the right dock's own fiche,
/// which is exactly why every row **stays selectable** and its own `⋮` menu keeps
/// `Modifier`/`Supprimer` — mockup `4b`'s own dock hint is explicit that the fiche is where an
/// entry gets corrected, never a capture affordance of this page's own. A composite panel
/// (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather than a null callback
/// per affordance, and withholds — never disables — its own `⋮` menu's `Edit`/`Delete` entries. A
/// row's own click never writes either way — it selects the entry, opening the right dock's fiche
/// on it, mirroring `OcptBudgetCostTracking`'s own row selection.
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
/// **Under the statement, `À venir` reads the account's future rather than its past** — one row
/// per unsettled commitment, in [OcptBudgetProjection.steps]' own due-date-first order, then a
/// footer naming the total falling due and the balance the account would hold once it has. It is
/// built from [commitments] and the statement's own closing balance, through `ocptBudgetProjectionOf`
/// (`lib/utils/ocpt_budget_projection.dart`) — never re-sorted here, exactly as that function's own
/// doc comment argues. **Drawn only while at least one unsettled commitment exists**, and it carries
/// no empty state of its own: a project owing nothing simply has no second card. Both sections scroll
/// **together**, as slivers of the very same [CustomScrollView], under the one fixed header row above
/// them — two independent scroll areas would let a reader scroll the statement while `À venir` stayed
/// put, which is not a statement any more.
///
/// **A due row is selectable, never a write** — it dispatches [onCommitmentSelected], opening the
/// right dock's fiche on the commitment, which is where it is edited or settled — so, unlike the
/// entry table's own `⋮` menu, it is never withheld under [isReadOnly]. `À venir` draws no `⋮` menu
/// of its own at all: `Modifier`/`Supprimer`/`Payer` on a commitment live in the fiche and only there.
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

  /// Every live poste of the project, used to resolve an entry's or a commitment's own poste name.
  final List<OcptBudgetPoste> postes;

  /// Every live voucher, keyed by the entry it evidences — an entry with no key here carries no
  /// voucher at all. Read by each row's own small marker (never a second column of text), which
  /// also says when the referenced file no longer resolves.
  final Map<String, OcptAssetRef> receiptsByEntryId;

  /// What is currently selected for the right dock's own fiche — a row reads highlighted while it
  /// is an [OcptBudgetEntrySelection] naming its own id.
  final OcptBudgetSelection? selection;

  /// Whether the header's simplified/detailed switch currently reads simplified — switches a
  /// poste's own displayed name between `simpleLabel` and `code · label`.
  final bool isSimplified;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called with an entry's id when its row is clicked — never withheld under [isReadOnly], since
  /// selecting only opens the right dock's own fiche on it, it writes nothing.
  final ValueChanged<String>? onEntrySelected;

  /// Called with an entry when its row's own `⋮` menu asks to edit it, opening the entry dialog on
  /// it, or null while [isReadOnly].
  final ValueChanged<OcptBudgetEntry>? onEntryEditRequested;

  /// Called with an entry's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onEntryDeletionRequested;

  /// Called with a commitment's id when an `À venir` row is clicked — never withheld under
  /// [isReadOnly], for the very reason [onEntrySelected] never is: selecting only opens the right
  /// dock's own fiche on it, it writes nothing.
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
    required this.postes,
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

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    final rows = ocptBudgetJournalRowsOf(entries, projectVatRateBasisPoints: defaultVatRateBasisPoints);
    final totals = ocptBudgetCashTotalsOf(entries, projectVatRateBasisPoints: defaultVatRateBasisPoints);
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
                  message: isSimplified ? tr.budgetCashJournalSimpleEmptyHint : tr.budgetCashJournalEmptyHint,
                )
              : LayoutBuilder(
                  builder: (context, constraints) => OcptHorizontalScrollView(
                    // The header and the rows scroll **together**, inside one frame: they share
                    // the same fixed column widths, so scrolling either alone would slide the
                    // figures out from under their own headings.
                    child: SizedBox(
                      width: math.max(constraints.maxWidth, _ocptCashJournalMinTableWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _OcptCashJournalHeaderRow(),
                            Expanded(
                              // A single scroll region for both sections, the statement's own
                              // entries first, `À venir` under them as slivers of its own — see the
                              // class doc comment for why the two must never scroll apart.
                              child: CustomScrollView(
                                slivers: [
                                  SliverList.builder(
                                    itemCount: rows.length,
                                    itemBuilder: (context, index) => _OcptCashJournalRow(
                                      row: rows[index],
                                      poste: _posteById(rows[index].entry.posteId),
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
                                      onDeletionRequested: isReadOnly || onEntryDeletionRequested == null
                                          ? null
                                          : () => onEntryDeletionRequested?.call(rows[index].entry.id),
                                    ),
                                  ),
                                  if (rows.isNotEmpty) ...[
                                    SliverToBoxAdapter(
                                      child: _OcptCashStatementFooterRow(
                                        closingDate: rows.last.entry.date,
                                        balanceCents: totals.balanceCents,
                                        currencyCode: currencyCode,
                                      ),
                                    ),
                                    if (shareableCents > 0)
                                      SliverToBoxAdapter(
                                        child: _OcptCashShareableReminder(
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
                                    const SliverToBoxAdapter(child: _OcptCashUpcomingHeaderRow()),
                                    SliverList.builder(
                                      itemCount: projection.steps.length,
                                      itemBuilder: (context, index) {
                                        final step = projection.steps[index];
                                        final commitment = commitmentsById[step.commitmentId]!;

                                        return _OcptCashUpcomingRow(
                                          step: step,
                                          commitment: commitment,
                                          poste: _posteById(commitment.posteId),
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
                                      child: _OcptCashUpcomingFooterRow(
                                        totalDueCents: projection.openingBalanceCents - projection.finalBalanceCents,
                                        projectedBalanceCents: projection.finalBalanceCents,
                                        currencyCode: currencyCode,
                                      ),
                                    ),
                                    if (projection.coveredCommitmentCount != projection.commitmentCount)
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

  /// Whether entry [entryId] is the currently selected one — mirrors
  /// `OcptBudgetCostTracking._isEntrySelected`.
  bool _isEntrySelected(String entryId) {
    final selection = this.selection;
    return selection is OcptBudgetEntrySelection && selection.entryId == entryId;
  }

  /// Whether commitment [commitmentId] is the currently selected one — mirrors [_isEntrySelected]
  /// for the `À venir` section's own rows.
  bool _isCommitmentSelected(String commitmentId) {
    final selection = this.selection;
    return selection is OcptBudgetCommitmentSelection && selection.commitmentId == commitmentId;
  }

  /// [postes]' own entry naming [posteId], or null while [posteId] is null or names no live poste —
  /// mirrors `OcptBudgetState.selectedPoste`'s own reading.
  OcptBudgetPoste? _posteById(String? posteId) {
    if (posteId == null) {
      return null;
    }

    for (final poste in postes) {
      if (poste.id == posteId) {
        return poste;
      }
    }

    return null;
  }
}

/// The statement's own closing row, in the very same tinted style [_OcptCashUpcomingFooterRow]
/// closes `À venir` with: the closing label past a span of the leading columns, nothing under
/// `Debit` and `Credit`, and [balanceCents] under `Balance`. Mockup `4b` draws the two footers
/// answering each other — the account's past closed here, its future closed below.
///
/// **This replaced a top band carrying the whole journal's debit, credit and balance.** Only the
/// balance survives the move, which is the mockup's own reading and the honest one: on a running
/// statement the debit and credit totals are the two halves of the very figure the last line
/// already shows, and reading all three off a band pinned above a scrolled table invited comparing
/// them against whichever rows happened to be on screen. Stated at the foot of the rows they add
/// up, they can only be read as what they are. The coverage read-out the band carried under
/// `Balance` follows the figure down, drawn under this row exactly as `À venir` draws its own.
///
/// [closingDate] is the last drawn entry's own date, never today's: a statement closes on its last
/// movement, and a production that has recorded nothing this month holds a balance as of the day it
/// last did, not as of the day somebody happened to open the page.
class _OcptCashStatementFooterRow extends StatelessWidget {
  /// The date the statement closes on — the last drawn entry's own.
  final DateTime closingDate;

  /// The whole journal's own balance (`OcptBudgetCashTotals.balanceCents`), in cents.
  final int balanceCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCashStatementFooterRow({
    required this.closingDate,
    required this.balanceCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: _ocptCashJournalRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr.budgetCashJournalClosingBalanceLabel(DateFormat.yMMMd(locale).format(closingDate)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: _ocptCashJournalAmountColumnWidth),
            const SizedBox(width: _ocptCashJournalAmountColumnWidth),
            SizedBox(
              width: _ocptCashJournalAmountColumnWidth,
              child: Text(
                ocptBudgetAmountLabel(balanceCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: _ocptCashJournalMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}

/// A quiet reminder drawn under the closing balance: how much of the account is actually shareable,
/// so the bank balance right above it is not mistaken for the amount to distribute — the two are
/// different figures ([shareableCents] is the takings less the contributions to repay, the balance
/// is cash on hand), and a production reading its account here reported taking one for the other.
///
/// **Not a subtraction of the balance, a reference beside it.** The balance and the shareable pot
/// diverge on two independent terms — production spending the balance carries and the pot ignores,
/// contributions the pot deducts whole whether or not they have gone back — so no honest arithmetic
/// turns one into the other in a line. This states the pot as its own figure, worded as *of which*,
/// and points at the view that computes it, rather than pretending to break the balance down.
///
/// Drawn only while [shareableCents] is above zero (see [OcptBudgetCashJournal.shareableCents]).
class _OcptCashShareableReminder extends StatelessWidget {
  /// The shareable pot, in cents — `OcptBudgetSharingPot.shareableCents`, always above zero here.
  final int shareableCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the `Revenue sharing` link is clicked, or null to draw the reminder without one.
  final VoidCallback? onOpenSharing;

  /// Class constructor
  const _OcptCashShareableReminder({
    required this.shareableCents,
    required this.currencyCode,
    required this.onOpenSharing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final captionStyle = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            tr.budgetCashJournalShareableReminder(ocptBudgetAmountLabel(shareableCents, currencyCode)),
            style: captionStyle,
          ),
          if (onOpenSharing != null)
            InkWell(
              key: const Key("ocptBudgetCashShareableReminderLink"),
              onTap: onOpenSharing,
              borderRadius: BorderRadius.circular(ocptRadiusSmall),
              mouseCursor: ocptClickableCursor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  tr.budgetHeaderSharingSegmentLabel,
                  style: captionStyle?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The entry table's own header row: `Date`, `Voucher`, `Poste`, `Label`, `Debit`, `Credit`,
/// `Balance`, then a blank cell over the `⋮` menu column — `Poste` ahead of `Label`, mirroring
/// `OcptBudgetCostTracking`'s own pinned `Poste` column, since both readings of the very same
/// expenses document now lead with the same identifying column.
class _OcptCashJournalHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptCashJournalHeaderRow();

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
        height: _ocptCashJournalHeaderRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: _ocptCashJournalDateColumnWidth,
              child: Text(tr.budgetCashJournalColumnDate.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: _ocptCashJournalVoucherColumnWidth,
              child: Text(tr.budgetCashJournalColumnVoucher.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: _ocptCashJournalPosteColumnWidth,
              child: Text(tr.budgetCostTrackingColumnPoste.toUpperCase(), style: labelStyle),
            ),
            Expanded(child: Text(tr.budgetCashJournalColumnLabel.toUpperCase(), style: labelStyle)),
            SizedBox(
              width: _ocptCashJournalAmountColumnWidth,
              child: Text(
                tr.budgetCashJournalColumnDebit.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            SizedBox(
              width: _ocptCashJournalAmountColumnWidth,
              child: Text(
                tr.budgetCashJournalColumnCredit.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            SizedBox(
              width: _ocptCashJournalAmountColumnWidth,
              child: Text(
                tr.budgetCashJournalColumnBalance.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: _ocptCashJournalMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}

/// One entry row: date, voucher number, poste, label, debit, credit, running balance, then its own
/// `⋮` menu — `Edit`/`Delete`, mirroring `OcptBudgetCostTracking`'s own row-menu idiom. Clicking
/// the row itself only selects it, opening the right dock's fiche on it — never a write, so never
/// withheld under a previewed version.
///
/// **Only the side money actually moved on is tinted** — a debit in [ColorScheme.error], a credit
/// in [ColorScheme.primary], each read off the entry's own raw column rather than off the row's
/// tax-inclusive figure, so the tint says which way the movement went and the figure says how much.
/// Every ordinary entry moves on one side alone, so every ordinary row carries exactly one coloured
/// cell: colouring both would paint an accent onto the untouched side's zero and leave a reader
/// with two competing signals per line, which is the opposite of what the colour is there for.
///
/// Both figures print exactly as [ocptBudgetJournalRowsOf] gives them, zero included: an entry
/// recorded entirely on one side of the account shows a real `0,00 €` on the other, never an
/// invented dash. [row]'s own null figures ([OcptBudgetJournalRow.debitCents]/`.creditCents`/
/// `.balanceAfterCents`, always null together for an entry that cannot be read tax-inclusive) print
/// [ocptBudgetEmptyValue] instead, in the ordinary muted body colour rather than either accent.
class _OcptCashJournalRow extends StatelessWidget {
  /// The row this widget draws.
  final OcptBudgetJournalRow row;

  /// The poste [row]'s own entry names, or null while it names none.
  final OcptBudgetPoste? poste;

  /// This entry's own voucher, or null while it carries none.
  final OcptAssetRef? receipt;

  /// Whether this row's own entry is the one currently selected.
  final bool isSelected;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when this row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Called when this row's own `⋮` menu asks to edit it, or null while withheld.
  final VoidCallback? onEditRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptCashJournalRow({
    required this.row,
    required this.poste,
    required this.receipt,
    required this.isSelected,
    required this.isSimplified,
    required this.currencyCode,
    required this.onTap,
    required this.onEditRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final entry = row.entry;
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.yMMMd(locale).format(entry.date);
    final debitCents = row.debitCents;
    final creditCents = row.creditCents;
    final balanceCents = row.balanceAfterCents;
    final poste = this.poste;

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? null : ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: _ocptCashJournalRowHeight,
          child: Row(
            children: [
            SizedBox(
              width: _ocptCashJournalDateColumnWidth,
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptCashJournalVoucherColumnWidth,
              child: Text(
                entry.voucherNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptCashJournalPosteColumnWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  poste == null
                      ? tr.budgetCashJournalNoPosteLabel
                      : ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: poste == null ? theme.colorScheme.onSurfaceVariant : null,
                    fontStyle: poste == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    if (receipt != null) ...[
                      _OcptCashJournalVoucherMarker(path: receipt!.path),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _amountCell(
              context,
              debitCents,
              color: (debitCents != null && entry.debitCents != 0) ? theme.colorScheme.error : null,
            ),
            _amountCell(
              context,
              creditCents,
              color: (creditCents != null && entry.creditCents != 0) ? theme.colorScheme.primary : null,
            ),
            _amountCell(context, balanceCents, bold: true),
            SizedBox(
              width: _ocptCashJournalMenuColumnWidth,
              child: onEditRequested == null && onDeletionRequested == null
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: "",
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (value) => switch (value) {
                        "edit" => onEditRequested?.call(),
                        "delete" => onDeletionRequested?.call(),
                        _ => null,
                      },
                      itemBuilder: (context) => [
                        if (onEditRequested != null)
                          PopupMenuItem<String>(
                            value: "edit",
                            child: Text(tr.budgetFinancingEditAction),
                          ),
                        if (onDeletionRequested != null)
                          PopupMenuItem<String>(value: "delete", child: Text(tr.budgetEntryDeleteAction)),
                      ],
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// One amount cell, right-aligned, printing [ocptBudgetEmptyValue] while [cents] is null.
  Widget _amountCell(BuildContext context, int? cents, {Color? color, bool bold = false}) => SizedBox(
    width: _ocptCashJournalAmountColumnWidth,
    child: Text(
      cents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(cents, currencyCode),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: color, fontWeight: bold ? FontWeight.w600 : null),
    ),
  );
}

/// The `À venir` section's own title row — one cell, unlike [_OcptCashJournalHeaderRow]'s own
/// per-column headers, since every row under it borrows the statement's fixed widths rather than
/// declaring column headings of its own (mockup `4b`'s own single-cell header).
class _OcptCashUpcomingHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptCashUpcomingHeaderRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        tr.budgetCashUpcomingSectionTitle,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One `À venir` row: a commitment falling due, still unsettled — [step]'s own cash figure, read
/// against [commitment] so the row can print its own label and poste, [step] itself carrying
/// neither. Clicking the row only selects it, opening the right dock's fiche on the commitment —
/// never a write, so never withheld under a previewed version, exactly as [_OcptCashJournalRow]'s
/// own click is never withheld.
///
/// Drawn in the very same fixed column widths [_OcptCashJournalRow] uses, so the two tables' amount
/// columns line up — the `Voucher` and `⋮` menu columns print nothing, an unsettled commitment
/// carrying neither a voucher of its own nor the entry table's `Modifier`/`Supprimer` menu (see the
/// class doc comment for why this section carries no `⋮` menu at all). `Credit` and `Balance` print
/// [ocptBudgetEmptyValue]: a commitment is a cost still owed, never a credit, and its own row
/// contributes no running balance of its own — that reading is the footer's.
class _OcptCashUpcomingRow extends StatelessWidget {
  /// The projection step this row draws.
  final OcptBudgetProjectionStep step;

  /// The commitment [step] stands for.
  final OcptBudgetCommitment commitment;

  /// [commitment]'s own poste, or null while it names none still live.
  final OcptBudgetPoste? poste;

  /// Whether this row's own commitment is the one currently selected.
  final bool isSelected;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when this row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Class constructor
  const _OcptCashUpcomingRow({
    required this.step,
    required this.commitment,
    required this.poste,
    required this.isSelected,
    required this.isSimplified,
    required this.currencyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dueDate = step.dueDate;
    final poste = this.poste;

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? null : ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: _ocptCashJournalRowHeight,
          child: Row(
            children: [
              SizedBox(
                width: _ocptCashJournalDateColumnWidth,
                child: Text(
                  dueDate == null
                      ? tr.budgetCommittedNoDueDateLabel
                      : DateFormat.yMMMd(locale).format(dueDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dueDate == null ? theme.colorScheme.onSurfaceVariant : null,
                    fontStyle: dueDate == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              const SizedBox(width: _ocptCashJournalVoucherColumnWidth),
              SizedBox(
                width: _ocptCashJournalPosteColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    poste == null
                        ? tr.budgetCashJournalNoPosteLabel
                        : ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    commitment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              SizedBox(
                width: _ocptCashJournalAmountColumnWidth,
                child: Text(
                  ocptBudgetAmountLabel(step.amountCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: _ocptCashJournalAmountColumnWidth,
                child: Text(
                  ocptBudgetEmptyValue,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: _ocptCashJournalAmountColumnWidth,
                child: Text(
                  ocptBudgetEmptyValue,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: _ocptCashJournalMenuColumnWidth),
            ],
          ),
        ),
      ),
    );
  }
}

/// The `À venir` section's own footer, in the mockup's own tinted style: [totalDueCents] under the
/// `Debit` column, past a label spanning the leading ones, and [projectedBalanceCents]
/// ([OcptBudgetProjection.finalBalanceCents]) under `Balance`, printing in [ColorScheme.error] once
/// it goes negative — the one figure of this page that reads the account's future rather than its
/// past, which is exactly why it is worth a tint of its own.
class _OcptCashUpcomingFooterRow extends StatelessWidget {
  /// The sum of every step's own [OcptBudgetProjectionStep.amountCents] — what falls due once
  /// every `À venir` row has.
  final int totalDueCents;

  /// The balance the account would hold once every `À venir` row has fallen due —
  /// [OcptBudgetProjection.finalBalanceCents].
  final int projectedBalanceCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCashUpcomingFooterRow({
    required this.totalDueCents,
    required this.projectedBalanceCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isNegative = projectedBalanceCents < 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: _ocptCashJournalRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr.budgetCashUpcomingProjectedBalanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: _ocptCashJournalAmountColumnWidth,
              child: Text(
                ocptBudgetAmountLabel(totalDueCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: _ocptCashJournalAmountColumnWidth),
            SizedBox(
              width: _ocptCashJournalAmountColumnWidth,
              child: Text(
                ocptBudgetAmountLabel(projectedBalanceCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isNegative ? theme.colorScheme.error : null,
                ),
              ),
            ),
            const SizedBox(width: _ocptCashJournalMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}

/// The small marker a row carries next to its own label when its entry carries a voucher — never a
/// second column of text, just an icon whose tooltip says whether the referenced file still
/// resolves, mirroring `OcptAssetFileLine`'s own "file not found" reading (ADR 0013).
///
/// A [StatefulWidget] (the documented RFL1 exception) for the very reason `OcptAssetFileLine` is
/// one: the answer belongs to nobody else and is worth asking once, not from `build`, which would
/// run it on every frame the journal is rebuilt for an unrelated reason.
class _OcptCashJournalVoucherMarker extends StatefulWidget {
  /// The voucher's own referenced path.
  final String path;

  /// Class constructor
  const _OcptCashJournalVoucherMarker({required this.path});

  @override
  State<_OcptCashJournalVoucherMarker> createState() => _OcptCashJournalVoucherMarkerState();
}

/// The state of [_OcptCashJournalVoucherMarker]: whether the referenced file was found, once asked.
class _OcptCashJournalVoucherMarkerState extends State<_OcptCashJournalVoucherMarker> {
  /// Whether the referenced file was there when it was last asked about.
  late bool _exists = File(widget.path).existsSync();

  @override
  void didUpdateWidget(covariant _OcptCashJournalVoucherMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _exists = File(widget.path).existsSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isMissing = !_exists;

    return Tooltip(
      message: isMissing
          ? tr.budgetCashJournalVoucherFileMissingTooltip
          : tr.budgetCashJournalVoucherAttachedTooltip,
      child: Icon(
        isMissing ? Icons.error_outline : Icons.attach_file,
        size: 14,
        color: isMissing ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
