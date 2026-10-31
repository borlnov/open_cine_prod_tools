// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';

/// The five documents the capture wizard's own step 1 groups its fifteen answers under — the
/// headings, not states of mind: each names the thing being worked on, exactly as the mode's own
/// four chips already do for the working surfaces themselves
/// (`docs/architecture/budget.md`).
///
/// [ocptBudgetGestureFamilyOf] is the only way a caller ever asks which heading an
/// [OcptBudgetGesture] sits under — nothing else in this file switches over the fifteen answers by
/// hand.
enum OcptBudgetGestureFamily {
  /// `Le devis` — what the film is going to cost, poste by poste.
  quote,

  /// `L'argent qui a bougé` — what has already entered or left the account.
  cashMovement,

  /// `Le plan de financement` — what is promised, and not yet arrived.
  financingPlan,

  /// `Les défraiements` — what the production owes the people who advanced money for it.
  allowances,

  /// `Le partage des recettes` — who touches what of what the film earns.
  revenueSharing,
}
