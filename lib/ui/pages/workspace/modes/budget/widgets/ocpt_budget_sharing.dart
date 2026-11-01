// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_repayment_line.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_share_split.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_sharing_pot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_distribution_column.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_left_column.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_metrics.dart';

/// The budget mode's revenue sharing view: two columns side by side, wrapping onto one another
/// once the centre narrows past [ocptBudgetSharingWrapWidth] — the layout the validated mockup lays
/// this view out as, mirroring `OcptBudgetRegie`'s own two-column reading.
///
/// **Every card sizes to its own content and hugs the top of its own column — never stretched to
/// fill the view's own height.** This is `OcptBudgetFinancing`'s own house style (its group cards
/// size to their content, the page simply carrying empty space below them), so each column here is
/// a plain, content-sized `Column` of cards, and it is *that* — not a card's own body — which sits
/// inside the scroll view: [OcptBudgetSharingLeftColumn]/[OcptBudgetSharingDistributionColumn] carry no
/// `Expanded` of their own, and neither does a card's own list of rows, which is a plain `Column`
/// rather than a `ListView`. Wide, each column scrolls on its own (`SingleChildScrollView`,
/// side by side in a `Row`); narrow, one scroll view carries both columns in sequence.
///
/// **Left column**: `Repaying the contributions` ([sharingPot]'s own four-line read-out, the order
/// that card exists to make legible — the reimbursable contributions come before any sharing at
/// all) — the whole of the column, the takings themselves having left for the resources document's
/// own tree. **Right column**: `Distribution`, one row per [shareSplits] — what is left is split by
/// the agreed shares, and each participant may reinvest theirs in the next production.
///
/// **No inspector**, mirroring `OcptBudgetFinancing`'s own class doc comment for the very same
/// reason: a participant carries no line of its own the right dock's existing `Inspector` tab,
/// built entirely around a poste's own quote lines, could show — a taking is answered by the fiche
/// the resources document opens on it these days. A share row's own click only ever selects it
/// ([onShareSelected]), read and written exactly as `OcptBudgetState.selectedResourceId` already
/// is; a row's own fields are read and written through `OcptBudgetShareDialog` instead, reached
/// from the row's own `⋮` menu.
///
/// **The sum of the shares is stated, never policed.** Where [ocptBudgetSharesPermilleTotal] is not
/// `1000`, the `Distribution` table says so in a line of its own, rather than refusing the write or
/// silently rescaling every participant's own figure: a plan still being negotiated legitimately
/// does not add up yet, and it is the participants' own business to settle, not this app's to
/// arbitrate. `OcptBudgetShareDialog`'s own class doc comment repeats the same argument for why its
/// own `Share` field carries no validator against the other rows' own total.
///
/// A composite panel (`docs/architecture/foundations.md`'s own idiom): takes [isReadOnly] rather
/// than a null callback per affordance, and withholds — never disables — every one of its own
/// writing affordances under it: both `+ Add` footers and every row's own `⋮` menu entries.
class OcptBudgetSharing extends StatelessWidget {
  /// Every live share, in `sortKey` order.
  final List<OcptBudgetShare> shares;

  /// What there is to share, and what stands between the takings and it — still summed from the
  /// takings, by `lib/models/rules/ocpt_budget_shares.dart`, even though this view no longer draws
  /// them.
  final OcptBudgetSharingPot sharingPot;

  /// `resources`' own reimbursable ones, grouped by lender — `ocptBudgetRepaymentLinesOf`
  /// (`lib/models/rules/ocpt_budget_shares.dart`). The `Repaying the contributions` card's own
  /// detail: who is owed what, one line per lender, rather than only [sharingPot]'s own three
  /// aggregate figures.
  final List<OcptBudgetRepaymentLine> repaymentLines;

  /// Called with a contributor's own line when `Record a repayment` is clicked, or null
  /// while [isReadOnly] — the mode opens the entry dialog on a debit already naming what
  /// is being repaid.
  final ValueChanged<OcptBudgetRepaymentLine>? onRepaymentRequested;

  /// The split of [sharingPot] across [shares], in the order they are handed in.
  final List<OcptBudgetShareSplit> shareSplits;

  /// Every live person of the project's address book — resolves a share's own
  /// [OcptBudgetShare.personId] into a display name, printed as a quiet second line under its own
  /// `Participant` cell.
  final List<OcptPerson> people;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The id of the currently selected share, or null while none is.
  final String? selectedShareId;

  /// Whether the mode shows a project version being previewed read-only — see the class doc
  /// comment.
  final bool isReadOnly;

  /// Called with a share's id when its row is clicked — selects it, and only that.
  final ValueChanged<String> onShareSelected;

  /// Called with a share when its row's own `⋮` menu asks to edit it, or null while [isReadOnly].
  /// Opens `OcptBudgetShareDialog` on it.
  final ValueChanged<OcptBudgetShare>? onShareEditRequested;

  /// Called with a share when its row's own `⋮` menu asks to record a payout against it, or null
  /// while [isReadOnly]. Opens `OcptBudgetEntryDialog` pre-filled from it, as a debit.
  final ValueChanged<OcptBudgetShare>? onSharePayoutRequested;

  /// Called with a share's id and a direction when its row's own `⋮` menu asks to move it, or null
  /// while [isReadOnly]. `moveUp` is named, never positional, mirroring
  /// `OcptBudgetCostTracking.onPosteReorderRequested`.
  final void Function(String shareId, {required bool moveUp})? onShareReorderRequested;

  /// Called with a share's id when its row's own `⋮` menu asks to delete it, or null while
  /// [isReadOnly]. The mode answers this through `OcptConfirmDialog` before dispatching anything.
  final ValueChanged<String>? onShareDeletionRequested;

  /// Class constructor
  const OcptBudgetSharing({
    super.key,
    required this.shares,
    required this.sharingPot,
    required this.repaymentLines,
    required this.onRepaymentRequested,
    required this.shareSplits,
    required this.people,
    required this.currencyCode,
    required this.selectedShareId,
    required this.isReadOnly,
    required this.onShareSelected,
    required this.onShareEditRequested,
    required this.onSharePayoutRequested,
    required this.onShareReorderRequested,
    required this.onShareDeletionRequested,
  });

  /// Build the budget sharing as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    final leftColumn = OcptBudgetSharingLeftColumn(
      sharingPot: sharingPot,
      repaymentLines: repaymentLines,
      shares: shares,
      onRepaymentRequested: onRepaymentRequested,
      people: people,
      currencyCode: currencyCode,
    );
    final rightColumn = OcptBudgetSharingDistributionColumn(
      shares: shares,
      shareSplits: shareSplits,
      sharingPot: sharingPot,
      people: people,
      currencyCode: currencyCode,
      selectedShareId: selectedShareId,
      isReadOnly: isReadOnly,
      onShareSelected: onShareSelected,
      onShareEditRequested: onShareEditRequested,
      onSharePayoutRequested: onSharePayoutRequested,
      onShareReorderRequested: onShareReorderRequested,
      onShareDeletionRequested: onShareDeletionRequested,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr.budgetSharingCaption,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= ocptBudgetSharingWrapWidth) {
                // Each column scrolls on its own, top-aligned: the cards inside size to their own
                // content, exactly as `OcptBudgetFinancing`'s own group cards do — see the class
                // doc comment for why this reads as one column stretching full height was the
                // defect a screenshot against the validated mockup caught.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SingleChildScrollView(child: leftColumn)),
                    const SizedBox(width: 16),
                    Expanded(child: SingleChildScrollView(child: rightColumn)),
                  ],
                );
              }

              // Narrow: one scroll view holding both columns in sequence, rather than splitting
              // the height between two, each independently scrolling.
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [leftColumn, const SizedBox(height: 16), rightColumn],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
