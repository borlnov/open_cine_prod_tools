// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';

/// Get the poste the logistics view's own provisioning starts out pointed at: the CNC
/// nomenclature's own
/// `Transports, défraiements, régie`, by its **stable seeded id**, when the project still has it,
/// and the first poste otherwise.
///
/// **A preference among the postes that exist, never an assumption that one of them does.** A
/// production is free to have renamed, split or deleted that poste — the nomenclature is seeded,
/// not frozen — and a project with no poste at all has nowhere to provision into, which the view
/// says rather than pretending otherwise.
String? ocptBudgetDefaultProvisionPosteIdOf(List<OcptBudgetPoste> postes) {
  const logisticsPosteId = 'd75aa74c-ed99-494a-bca0-3508b166ec18';

  return postes.any((poste) => poste.id == logisticsPosteId)
      ? logisticsPosteId
      : postes.firstOrNull?.id;
}
