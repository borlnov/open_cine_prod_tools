// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_link_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_account_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_person_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_resource_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_revenue_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_share_field.dart';

/// The one link field [nature] picks — [OcptBudgetEntryLinkKind] says which.
class OcptBudgetEntryLinkField extends StatelessWidget {
  /// The entry's nature, which fixes the link field drawn.
  final OcptBudgetEntryNature nature;

  /// Every live account.
  final List<OcptBudgetAccount> accounts;

  /// Every live financing resource.
  final List<OcptBudgetResource> resources;

  /// Every live taking.
  final List<OcptBudgetRevenue> revenues;

  /// Every live share.
  final List<OcptBudgetShare> shares;

  /// Every person.
  final List<OcptPerson> people;

  /// Whether the simplified naming applies to the account labels.
  final bool isSimplified;

  /// The account currently picked, or null.
  final String? accountId;

  /// The financing resource currently picked, or null.
  final String? resourceId;

  /// The taking currently picked, or null.
  final String? revenueId;

  /// The taking the `New taking…` entry just collected, or null.
  final OcptBudgetRevenueFormFields? newRevenue;

  /// The share currently picked, or null.
  final String? shareId;

  /// The person currently picked, or null.
  final String? personId;

  /// Called with the account just picked.
  final ValueChanged<String?> onAccountChanged;

  /// Called with the financing resource just picked.
  final ValueChanged<String?> onResourceChanged;

  /// Called with the taking just picked, or with the `New taking…` sentinel.
  final ValueChanged<String?> onRevenueChanged;

  /// Called with the share just picked.
  final ValueChanged<String?> onShareChanged;

  /// Called with the person just picked.
  final ValueChanged<String?> onPersonChanged;

  /// Class constructor
  const OcptBudgetEntryLinkField({
    super.key,
    required this.nature,
    required this.accounts,
    required this.resources,
    required this.revenues,
    required this.shares,
    required this.people,
    required this.isSimplified,
    required this.accountId,
    required this.resourceId,
    required this.revenueId,
    required this.newRevenue,
    required this.shareId,
    required this.personId,
    required this.onAccountChanged,
    required this.onResourceChanged,
    required this.onRevenueChanged,
    required this.onShareChanged,
    required this.onPersonChanged,
  });

  /// Build the budget entry link field.
  @override
  Widget build(BuildContext context) => switch (ocptBudgetEntryNatureLinkKindOf(nature)) {
    OcptBudgetEntryLinkKind.account => OcptBudgetEntryAccountField(
      accounts: accounts,
      isSimplified: isSimplified,
      accountId: accountId,
      onChanged: onAccountChanged,
    ),
    OcptBudgetEntryLinkKind.financingResource => OcptBudgetEntryResourceField(
      resources: resources,
      resourceId: resourceId,
      onChanged: onResourceChanged,
    ),
    OcptBudgetEntryLinkKind.taking => OcptBudgetEntryRevenueField(
      revenues: revenues,
      revenueId: revenueId,
      newRevenue: newRevenue,
      onChanged: onRevenueChanged,
    ),
    OcptBudgetEntryLinkKind.participant => OcptBudgetEntryShareField(
      shares: shares,
      shareId: shareId,
      onChanged: onShareChanged,
    ),
    OcptBudgetEntryLinkKind.person => OcptBudgetEntryPersonField(
      people: people,
      personId: personId,
      onChanged: onPersonChanged,
    ),
  };
}
