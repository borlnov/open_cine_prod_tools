// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_dashboard.dart';

/// The budget mode's dashboard: the summary of the other pages, opened by default.
///
/// **Every callback it needs is one the mode bloc already has an event for** — a dashboard alert
/// row's own account-over-quote action selects the account and switches to
/// [OcptBudgetView.expenses] in one gesture (see `OcptBudgetDashboard.onAccountOpened`'s own doc
/// comment for why a plain selection would not be enough); the cash-negative alert's own row opens
/// the tools drawer's own `Flux de trésorerie` page — the very reading it answers.
class OcptBudgetDashboardView extends StatelessWidget {
  /// The mode's state, which the dashboard's figures and alerts are read from.
  final OcptBudgetState state;

  /// Class constructor
  const OcptBudgetDashboardView({super.key, required this.state});

  /// Build the budget dashboard view as an [OcptBudgetDashboard].
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBudgetBloc>();

    return OcptBudgetDashboard(
      accounts: state.accounts,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      cashTotals: state.cashTotals,
      paidByAccountId: state.paidByAccountId,
      offQuotePaidTotal: state.offQuotePaidTotal,
      committedByAccountId: state.committedByAccountId,
      alerts: state.alerts,
      resources: state.resources,
      onAccountOpened: (accountId) => _handleAccountOpened(bloc, accountId),
      onCashAlertActionRequested: () => _handleCashAlertActionRequested(bloc),
    );
  }

  /// Handle a dashboard alert row is a link to where the account is worked on, not a selection of
  /// its own —
  /// see `OcptBudgetDashboard.onAccountOpened`'s own doc comment. Selects [accountId] and switches
  /// to [OcptBudgetView.expenses] in the same gesture.
  void _handleAccountOpened(OcptBudgetBloc bloc, String accountId) {
    bloc
      ..add(OcptBudgetAccountSelectedEvent(accountId: accountId))
      ..add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.expenses));
  }

  /// Handle the cash-projection alert's own action: the cash question it raises is exactly what the
  /// tools
  /// drawer's own `Flux de trésorerie` page answers, so it opens straight onto it, the view and the
  /// tools view both set in one gesture, mirroring [_handleAccountOpened]'s own shape.
  void _handleCashAlertActionRequested(OcptBudgetBloc bloc) {
    bloc
      ..add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.tools))
      ..add(const OcptBudgetToolsViewSelectedEvent(toolsView: OcptBudgetToolsView.cashFlow));
  }
}
