// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_wizard_flows.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_dashboard_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_floating_add_button.dart';

/// The shell's `centre`: the header band, then whichever widget the current
/// [OcptBudgetState.view] names ([OcptBudgetState.toolsView] deciding which of the tools drawer's
/// own three pages draws while [OcptBudgetView.tools] is on screen), overlaid at a compact width
/// [isCompact] with the same floating `+ New` affordance the header band's own trailing button
/// already fires — the very pair [_newButtonOf] built for it, reused whole rather than resolved
/// twice, so the floating button can never drift from the desktop one. The two affordances are
/// mutually exclusive: at a wide width [OcptBudgetHeader] carries the capture button and the
/// floating one stays hidden ([OcptWorkspaceFloatingAddButton]'s own `isVisible: isCompact`
/// withholds it); at a compact width the header's own button is withheld instead
/// (`captureLabel`/`onCaptureRequested` null) and the floating one — icon-only, see
/// [OcptWorkspaceFloatingAddButton.iconOnly] — takes over, so the user is never shown both at
/// once.
///
/// Every route is the very widget the retired seven-chip header used to switch over: only the
/// switch's own shape moved, save the cash journal, which is now read-only in its new home. The
/// confirmations the routes ask for are the mode's, handed in as callbacks.
class OcptBudgetCentre extends StatelessWidget {
  /// The mode's state, which the header and the route are read from.
  final OcptBudgetState state;

  /// Whether the centre is laid out at a compact width.
  final bool isCompact;

  /// Opens the project settings page, where the meal and buffet prices are typed.
  final VoidCallback onProjectSettingsRequested;

  /// Asks the mode to confirm, then delete, the poste with this id.
  final ValueChanged<String> onPosteDeletionRequested;

  /// Asks the mode to confirm, then delete, the cash-journal entry with this id.
  final ValueChanged<String> onEntryDeletionRequested;

  /// Asks the mode to confirm, then delete, the commitment with this id.
  final ValueChanged<String> onCommitmentDeletionRequested;

  /// Asks the mode to confirm, then delete, the financing resource with this id.
  final ValueChanged<String> onResourceDeletionRequested;

  /// Asks the mode to confirm, then undo, the last receipt recorded against this resource.
  final ValueChanged<OcptBudgetResource> onResourceReceiptUndoRequested;

  /// Asks the mode to confirm, then delete, the taking with this id.
  final ValueChanged<String> onRevenueDeletionRequested;

  /// Asks the mode to confirm, then delete, the defrayal with this id.
  final ValueChanged<String> onAllowanceDeletionRequested;

  /// Asks the mode to confirm, then run, the provisioning of the selected poste.
  final VoidCallback onProvisionRequested;

  /// Asks the mode to confirm, then delete, the share with this id.
  final ValueChanged<String> onShareDeletionRequested;

  /// Class constructor
  const OcptBudgetCentre({
    super.key,
    required this.state,
    required this.isCompact,
    required this.onProjectSettingsRequested,
    required this.onPosteDeletionRequested,
    required this.onEntryDeletionRequested,
    required this.onCommitmentDeletionRequested,
    required this.onResourceDeletionRequested,
    required this.onResourceReceiptUndoRequested,
    required this.onRevenueDeletionRequested,
    required this.onAllowanceDeletionRequested,
    required this.onProvisionRequested,
    required this.onShareDeletionRequested,
  });

  /// Build the budget centre as an [OcptWorkspaceFloatingAddButton].
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBudgetBloc>();
    // Read once, here: null is "a previewed version takes it away" — the same label and gesture on
    // every route now, so there is nothing left for a route to withhold on its own account.
    // `OcptBudgetHeader` draws nothing at all when it is null — withheld whole, never disabled, the
    // standing rule.
    final newButton = state.isPreviewingVersion ? null : _newButtonOf(context);

    return OcptWorkspaceFloatingAddButton(
      isVisible: isCompact,
      iconOnly: true,
      icon: Icons.add,
      label: Tr.of(context).budgetHeaderNewAction,
      onPressed: newButton?.$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcptBudgetHeader(
            view: state.view,
            // The header's own chips leave one document for another, so the fiche's own selection —
            // an object that belonged to the view being left — is dropped, greeting the new view
            // empty. Every gesture that switches the view *and* selects keeps `clearSelection`
            // false.
            onViewSelected: (view) =>
                bloc.add(OcptBudgetViewSelectedEvent(view: view, clearSelection: true)),
            toolsView: state.toolsView,
            onToolsViewSelected: (toolsView) => bloc.add(
              OcptBudgetToolsViewSelectedEvent(toolsView: toolsView, clearSelection: true),
            ),
            isSimplified: state.isSimplified,
            onSimplifiedChanged: (value) =>
                bloc.add(OcptBudgetSimplifiedToggledEvent(isSimplified: value)),
            taxBasis: state.taxBasis,
            onTaxBasisChanged: (basis) => bloc.add(OcptBudgetTaxBasisChangedEvent(basis: basis)),
            postes: state.postes,
            filterPosteId: state.filterPosteId,
            onPosteFilterCleared: () =>
                bloc.add(const OcptBudgetPosteFilterSelectedEvent(posteId: null)),
            alertCount: state.alerts.length,
            // Withheld at a compact width: the floating button above takes over there, and showing
            // both would duplicate the affordance.
            captureLabel: isCompact ? null : newButton?.$1,
            onCaptureRequested: isCompact ? null : newButton?.$2,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: switch (state.view) {
                OcptBudgetView.dashboard => OcptBudgetDashboardView(state: state),
                OcptBudgetView.expenses => OcptBudgetCostTrackingView(
                  state: state,
                  onPosteDeletionRequested: onPosteDeletionRequested,
                  onCommitmentDeletionRequested: onCommitmentDeletionRequested,
                  onEntryDeletionRequested: onEntryDeletionRequested,
                ),
                OcptBudgetView.resources => OcptBudgetFinancingView(
                  state: state,
                  onResourceDeletionRequested: onResourceDeletionRequested,
                  onResourceReceiptUndoRequested: onResourceReceiptUndoRequested,
                  onRevenueDeletionRequested: onRevenueDeletionRequested,
                ),
                OcptBudgetView.tools => switch (state.toolsView) {
                  OcptBudgetToolsView.cashFlow => OcptBudgetCashJournalView(
                    state: state,
                    onEntryDeletionRequested: onEntryDeletionRequested,
                  ),
                  OcptBudgetToolsView.regie => OcptBudgetRegieView(
                    state: state,
                    onProjectSettingsRequested: onProjectSettingsRequested,
                    onAllowanceDeletionRequested: onAllowanceDeletionRequested,
                    onProvisionRequested: onProvisionRequested,
                  ),
                  OcptBudgetToolsView.sharing => OcptBudgetSharingView(
                    state: state,
                    onShareDeletionRequested: onShareDeletionRequested,
                  ),
                },
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Get the header band's own trailing button, `+ Nouveau` — offered on all five routes, including
  /// [OcptBudgetView.dashboard] and `tools › cashFlow`. Opens the capture wizard's own step 1, the
  /// current route's own document promoted to the top of the list with its first answer
  /// pre-selected — never on [OcptBudgetView.dashboard], which works on no single document, so
  /// pre-answering for it would be a guess: nothing is selected there, and `Continuer` stays
  /// withheld until a card is picked, the very rule the wizard's own step 1 already applies
  /// whenever nothing is known yet.
  (String, VoidCallback) _newButtonOf(BuildContext context) {
    final tr = Tr.of(context);
    return (tr.budgetHeaderNewAction, () => unawaited(ocptBudgetOpenNewWizard(context, state)));
  }
}
