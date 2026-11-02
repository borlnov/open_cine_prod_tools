// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_info_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_scaffold.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The resource variant: breadcrumb through the resources document and its own group, the
/// `Dossier` status badge, and — for a subsidy, a cash contribution, or an in-kind resource a
/// journal entry has actually named — the `Promis — Rentré` stepper with its
/// `Promised`/`Received` figures, plus `Receive`/`Edit`/`Delete`. **A valued in-kind resource no
/// entry names yet (`readsAsUncollected`) drops that money stepper entirely**, for a single
/// `Valued at` reading — a valuation runs through no collection lifecycle — mirroring its own
/// counterpart quote line on the expenses side (`docs/architecture/budget.md`, "An in-kind
/// contribution is valued, not collected", "A balanced in-kind contribution"). `Receive` stays
/// withheld for in-kind, and the app never hides a real movement: an in-kind resource an entry
/// does name keeps the stepper and its received figure.
///
/// **An in-kind resource names the poste its own counterpart quote line offsets**, resolved
/// through [ocptBudgetInKindCounterpartLineOf] rather than a field of its own — "No new column
/// on `budget_resources`" (`docs/architecture/budget.md`). Nothing draws while no counterpart
/// line has been minted for it yet.
class OcptBudgetDetailResource extends StatelessWidget {
  /// The detail panel this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetDetail detail;

  /// The financing resource this variant draws.
  final OcptBudgetResource resource;

  /// Class constructor
  const OcptBudgetDetailResource({super.key, required this.detail, required this.resource});

  /// Build the budget detail panel resource as an [OcptBudgetDetailScaffold].
  @override
  Widget build(BuildContext context) {
    final postes = detail.postes;
    final isSimplified = detail.isSimplified;
    final isReadOnly = detail.isReadOnly;
    final receivedByResourceId = detail.receivedByResourceId;
    final onResourceReceiptRequested = detail.onResourceReceiptRequested;
    final onResourceEditRequested = detail.onResourceEditRequested;
    final onResourceDeletionRequested = detail.onResourceDeletionRequested;
    final tr = Tr.of(context);

    final received = receivedByResourceId[resource.id];
    final hasEntry = received != null;
    final receivedCents = received?.amountCents ?? 0;
    final isInKind = resource.groupKind == OcptBudgetResourceGroupKind.inKind;
    final readsAsUncollected = isInKind && !hasEntry;
    final outstandingCents = ocptBudgetResourceOutstandingCents(
      amountCents: resource.amountCents,
      receivedCents: receivedCents,
    );
    final canReceive =
        !isReadOnly && !isInKind && outstandingCents > 0 && onResourceReceiptRequested != null;

    Widget? offsetsPosteBanner;
    if (isInKind) {
      final counterpartLine = ocptBudgetInKindCounterpartLineOf(postes, resource.id);
      final offsetPoste = counterpartLine == null
          ? null
          : postes.firstWhereOrNull((poste) => poste.id == counterpartLine.posteId);
      if (offsetPoste != null) {
        offsetsPosteBanner = OcptBudgetDetailInfoBanner(
          message: tr.budgetDetailInKindOffsetsPoste(
            "${offsetPoste.code} "
            "${ocptBudgetPosteDisplayLabel(offsetPoste, isSimplified: isSimplified)}",
          ),
        );
      }
    }

    return OcptBudgetDetailScaffold(
      breadcrumb: [
        tr.budgetHeaderResourcesSegmentLabel,
        ocptBudgetResourceGroupKindLabel(tr, resource.groupKind),
      ],
      title: resource.label.isEmpty ? tr.budgetPosteUnnamed : resource.label,
      amountText: detail.amountLabelOf(resource.amountCents),
      hint: resource.notes.isEmpty ? null : resource.notes,
      badge: ocptBudgetResourceStatusLabel(tr, resource.groupKind, resource.status),
      badgeColor: ocptBudgetResourceStatusAccentColor(
        Theme.of(context).colorScheme,
        resource.status,
      ),
      stepLabels: readsAsUncollected
          ? const []
          : [tr.budgetDetailStepPromisedLabel, tr.budgetFinancingColumnReceived],
      reachedCount: readsAsUncollected ? 0 : (hasEntry && receivedCents > 0 ? 2 : 1),
      figures: readsAsUncollected
          ? [
              (
                tr.budgetResourceDialogValuedAtFieldLabel,
                detail.amountLabelOf(resource.amountCents),
              ),
            ]
          : [
              (tr.budgetDetailStepPromisedLabel, detail.amountLabelOf(resource.amountCents)),
              (tr.budgetFinancingColumnReceived, detail.amountLabelOf(receivedCents)),
            ],
      outstandingLabel: readsAsUncollected ? null : tr.budgetFinancingColumnOutstanding,
      outstandingValue: readsAsUncollected ? null : detail.amountLabelOf(outstandingCents),
      banner: offsetsPosteBanner,
      primary: canReceive
          ? OcptBudgetDetailAction(
              label: tr.budgetDetailReceiveAction(
                detail.amountLabelOf(outstandingCents < 0 ? 0 : outstandingCents),
              ),
              onTap: () => onResourceReceiptRequested.call(resource),
            )
          : null,
      secondaries: [
        if (!isReadOnly && onResourceEditRequested != null)
          OcptBudgetDetailAction(
            label: tr.budgetFinancingEditAction,
            onTap: () => onResourceEditRequested.call(resource),
          ),
        if (!isReadOnly && onResourceDeletionRequested != null)
          OcptBudgetDetailAction(
            label: tr.budgetCommittedDeleteAction,
            onTap: () => onResourceDeletionRequested.call(resource.id),
          ),
      ],
    );
  }
}
