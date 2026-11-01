// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_outcome.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_view_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_wizard_flows.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The catering-and-defrayals view: the catering it computes, the defrayals it lets a production
/// type, and the band that provisions both into the quote.
///
/// The catering's own callbacks only ever report where a figure was typed — the schedule mode or
/// the project settings page — while the defrayals and the provisioning are real writes, opened
/// from here and confirmed by the mode, exactly as every other writing view of this mode is.
class OcptBudgetRegieView extends StatelessWidget {
  /// The mode's state, which the days, the defrayals and the provisioning are read from.
  final OcptBudgetState state;

  /// Opens the project settings page, where the meal and buffet prices are typed.
  final VoidCallback onProjectSettingsRequested;

  /// Asks the mode to confirm, then delete, the defrayal with this id.
  final ValueChanged<String> onAllowanceDeletionRequested;

  /// Asks the mode to confirm, then run, the provisioning of the selected poste.
  final VoidCallback onProvisionRequested;

  /// Class constructor
  const OcptBudgetRegieView({
    super.key,
    required this.state,
    required this.onProjectSettingsRequested,
    required this.onAllowanceDeletionRequested,
    required this.onProvisionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final elementLinkCounts = state.elementLinkCounts;
    // The plan is computed for the band as well as for the gesture: a provisioning that would do
    // nothing is withheld, and the band says why in its place rather than answering a click with a
    // dialog that only says "no".
    final plan = ocptBudgetRegieProvisionPlanOf(context, state);
    final wouldWrite = plan.any(
      (entry) =>
          entry.outcome == OcptBudgetProvisionOutcome.created ||
          entry.outcome == OcptBudgetProvisionOutcome.updated,
    );
    final skipped = plan
        .where((entry) => entry.outcome == OcptBudgetProvisionOutcome.skippedEdited)
        .length;

    return OcptBudgetRegie(
      days: state.regieDays,
      cateringTotals: state.regieTotals,
      decorNameByDayId: state.regieDecorNameByDayId,
      mealPriceCents: state.mealPriceCents,
      buffetPriceCents: state.buffetPriceCents,
      allowances: state.allowances,
      entries: state.entries,
      reimbursedByPersonId: state.reimbursedByPersonId,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      postes: state.postes,
      provisionPosteId: state.provisionPosteId,
      provisionedTotalCents: _provisionedTotalCentsOf(state),
      roles: state.roles,
      people: state.people,
      breakdownPricedElementCount: elementLinkCounts.pricedCount,
      breakdownUnpricedElementCount: elementLinkCounts.unpricedCount,
      currencyCode: state.currencyCode,
      isReadOnly: isReadOnly,
      expandedNodeIds: state.expandedNodeIds,
      onNodeExpansionToggled: (nodeId) =>
          bloc.add(OcptBudgetRowExpansionToggledEvent(nodeId: nodeId)),
      onScheduleOpenRequested: () => ocptBudgetOpenSchedule(context),
      onBreakdownFeedRequested: () => ocptBudgetOpenBreakdownElements(context),
      onProjectSettingsRequested: onProjectSettingsRequested,
      onPersonOpenRequested: (personId) => context.read<OcptWorkspaceBloc>().add(
        OcptWorkspaceModeSelectedEvent(
          mode: OcptWorkspaceMode.resources,
          revealRequest: OcptResourcesRevealRequest(
            tab: OcptResourcesTab.people,
            recordId: personId,
          ),
        ),
      ),
      onAllowanceEditRequested: isReadOnly
          ? null
          : (allowanceId) => unawaited(
              ocptBudgetEditAllowance(
                context,
                state,
                state.allowances.where((row) => row.id == allowanceId).firstOrNull,
              ),
            ),
      onAllowanceDeletionRequested: isReadOnly ? null : onAllowanceDeletionRequested,
      onPersonReimburseRequested: isReadOnly
          ? null
          : (personId) => unawaited(ocptBudgetReimbursePerson(context, state, personId)),
      onProvisionPosteSelected: isReadOnly
          ? null
          : (posteId) => bloc.add(OcptBudgetProvisionPosteSelectedEvent(posteId: posteId)),
      onProvisionRequested: isReadOnly || !wouldWrite ? null : onProvisionRequested,
      provisionNote: wouldWrite || state.provisionPosteId == null
          ? null
          : (skipped > 0
                ? Tr.of(context).budgetProvisionOnlyEditedMessage
                : Tr.of(context).budgetProvisionNothingToDoMessage),
    );
  }
}

/// What provisioning would do to the poste [OcptBudgetState.provisionPosteId] names, whole.
///
/// Read twice: once to draw the band — which withholds the gesture and says why when the plan
/// would change nothing — and once when the gesture is actually taken, so what the user is shown
/// and what is written come from the same computation.
List<OcptBudgetProvisionEntry> ocptBudgetRegieProvisionPlanOf(
  BuildContext context,
  OcptBudgetState state,
) {
  final poste = state.postes.where((row) => row.id == state.provisionPosteId).firstOrNull;
  if (poste == null) {
    return const [];
  }

  return ocptBudgetProvisionPlanOf(
    items: ocptBudgetProvisionItemsOf(
      mealCount: state.regieTotals.mealCount,
      snackCount: state.regieTotals.buffetCount,
      mealPriceCents: state.mealPriceCents,
      snackPriceCents: state.buffetPriceCents,
      allowances: state.allowances,
    ),
    posteLines: poste.lines,
    labels: ocptBudgetProvisionLabelsOf(Tr.of(context)),
  );
}

/// What the provisioned lines of [OcptBudgetState.provisionPosteId] currently hold, in cents —
/// the figure the régie view's own band reads back as `Quoted on this poste`.
///
/// **Only the lines the provisioning itself wrote count**, never every line of the poste: a
/// production quoting a van hire on the same poste has not thereby provisioned its catering, and
/// a band saying otherwise would report a gap closed that is still open.
int _provisionedTotalCentsOf(OcptBudgetState state) {
  final poste = state.postes.where((row) => row.id == state.provisionPosteId).firstOrNull;
  if (poste == null) {
    return 0;
  }

  return poste.lines
      .where((line) => line.provisionKey != null)
      .fold(0, (sum, line) => sum + ocptBudgetLineTotalCents(line));
}
