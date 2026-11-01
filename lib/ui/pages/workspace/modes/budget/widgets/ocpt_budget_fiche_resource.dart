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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_info_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_scaffold.dart';
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
class OcptBudgetFicheResource extends StatelessWidget {
  /// The fiche this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetFiche fiche;

  /// The financing resource this variant draws.
  final OcptBudgetResource resource;

  /// Class constructor
  const OcptBudgetFicheResource({super.key, required this.fiche, required this.resource});

  @override
  Widget build(BuildContext context) {
    final postes = fiche.postes;
    final isSimplified = fiche.isSimplified;
    final isReadOnly = fiche.isReadOnly;
    final receivedByResourceId = fiche.receivedByResourceId;
    final onResourceReceiptRequested = fiche.onResourceReceiptRequested;
    final onResourceEditRequested = fiche.onResourceEditRequested;
    final onResourceDeletionRequested = fiche.onResourceDeletionRequested;
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
        offsetsPosteBanner = OcptBudgetFicheInfoBanner(
          message: tr.budgetFicheInKindOffsetsPoste(
            "${offsetPoste.code} "
            "${ocptBudgetPosteDisplayLabel(offsetPoste, isSimplified: isSimplified)}",
          ),
        );
      }
    }

    return OcptBudgetFicheScaffold(
      breadcrumb: [
        tr.budgetHeaderResourcesSegmentLabel,
        ocptBudgetResourceGroupKindLabel(tr, resource.groupKind),
      ],
      title: resource.label.isEmpty ? tr.budgetPosteUnnamed : resource.label,
      amountText: fiche.amountLabelOf(resource.amountCents),
      hint: resource.notes.isEmpty ? null : resource.notes,
      badge: ocptBudgetResourceStatusLabel(tr, resource.groupKind, resource.status),
      badgeColor: ocptBudgetResourceStatusAccentColor(
        Theme.of(context).colorScheme,
        resource.status,
      ),
      stepLabels: readsAsUncollected
          ? const []
          : [tr.budgetFicheStepPromisedLabel, tr.budgetFinancingColumnReceived],
      reachedCount: readsAsUncollected ? 0 : (hasEntry && receivedCents > 0 ? 2 : 1),
      figures: readsAsUncollected
          ? [(tr.budgetResourceDialogValuedAtFieldLabel, fiche.amountLabelOf(resource.amountCents))]
          : [
              (tr.budgetFicheStepPromisedLabel, fiche.amountLabelOf(resource.amountCents)),
              (tr.budgetFinancingColumnReceived, fiche.amountLabelOf(receivedCents)),
            ],
      outstandingLabel: readsAsUncollected ? null : tr.budgetFinancingColumnOutstanding,
      outstandingValue: readsAsUncollected ? null : fiche.amountLabelOf(outstandingCents),
      banner: offsetsPosteBanner,
      primary: canReceive
          ? OcptBudgetFicheAction(
              label: tr.budgetFicheReceiveAction(
                fiche.amountLabelOf(outstandingCents < 0 ? 0 : outstandingCents),
              ),
              onTap: () => onResourceReceiptRequested.call(resource),
            )
          : null,
      secondaries: [
        if (!isReadOnly && onResourceEditRequested != null)
          OcptBudgetFicheAction(
            label: tr.budgetFinancingEditAction,
            onTap: () => onResourceEditRequested.call(resource),
          ),
        if (!isReadOnly && onResourceDeletionRequested != null)
          OcptBudgetFicheAction(
            label: tr.budgetCommittedDeleteAction,
            onTap: () => onResourceDeletionRequested.call(resource.id),
          ),
      ],
    );
  }
}
