// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';

/// Get the account the logistics view's own provisioning starts out pointed at: the CNC
/// nomenclature's own
/// `Transports, défraiements, régie`, by its **stable seeded id**, when the project still has it,
/// and the first account otherwise.
///
/// **A preference among the accounts that exist, never an assumption that one of them does.** A
/// production is free to have renamed, split or deleted that account — the nomenclature is seeded,
/// not frozen — and a project with no account at all has nowhere to provision into, which the view
/// says rather than pretending otherwise.
String? ocptBudgetDefaultProvisionAccountIdOf(List<OcptBudgetAccount> accounts) {
  const logisticsAccountId = 'd75aa74c-ed99-494a-bca0-3508b166ec18';

  return accounts.any((account) => account.id == logisticsAccountId)
      ? logisticsAccountId
      : accounts.firstOrNull?.id;
}
