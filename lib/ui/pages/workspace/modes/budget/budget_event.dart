// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The events of the budget mode, one sealed hierarchy per domain, all extending the abstract
/// `OcptBudgetEvent`.
library;

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_base_event.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_cash_journal_event.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_expenses_event.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_export_event.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_financing_event.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_selection_event.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_sharing_event.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_workspace_event.dart';
