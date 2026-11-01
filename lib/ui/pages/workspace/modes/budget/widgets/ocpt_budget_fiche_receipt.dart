// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_entry.dart';

/// The receipt variant: the entry it names, read with a `Promis — Rentré` stepper and a
/// breadcrumb through the resource or the taking it settles — the entry that
/// [OcptBudgetReceiptSelection] names may have gone, which is answered rather than left to throw.
class OcptBudgetFicheReceipt extends StatelessWidget {
  /// The fiche this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetFiche fiche;

  /// The entry the receipt names.
  final OcptBudgetEntry entry;

  /// Class constructor
  const OcptBudgetFicheReceipt({super.key, required this.fiche, required this.entry});

  @override
  Widget build(BuildContext context) {
    final resources = fiche.resources;
    final revenues = fiche.revenues;
    final tr = Tr.of(context);
    final resource = entry.resourceId == null
        ? null
        : resources.firstWhereOrNull((resource) => resource.id == entry.resourceId);
    final revenue = entry.revenueId == null
        ? null
        : revenues.firstWhereOrNull((revenue) => revenue.id == entry.revenueId);
    final ancestorLabel = resource?.label ?? revenue?.label;

    return OcptBudgetFicheEntry(
      fiche: fiche,
      entry: entry,
      stepLabelsOverride: [tr.budgetFicheStepPromisedLabel, tr.budgetFinancingColumnReceived],
      reachedCountOverride: 2,
      breadcrumbOverride: [
        if (ancestorLabel != null && ancestorLabel.isNotEmpty) ancestorLabel,
        tr.budgetFicheKindEntryLabel,
      ],
    );
  }
}
