// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_financing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_allowance_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';

/// Opens `OcptBudgetEntryDialog` on [entry] — the one screen it has left, its nature inferred
/// silently off whichever of the entry's own links is set — then dispatches the update if the
/// user confirmed it.
Future<void> ocptBudgetEditEntry(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetEntry entry,
) async {
  final journalBloc = context.read<OcptBudgetCashJournalBloc>();
  final result = await OcptBudgetEntryDialog.show(
    context,
    existing: entry,
    existingReceipt: state.receiptsByEntryId[entry.id],
    postes: state.postes,
    resources: state.resources,
    revenues: state.revenues,
    shares: state.shares,
    people: state.people,
    currencyCode: state.currencyCode,
    defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
    isSimplified: state.isSimplified,
  );
  if (result == null) {
    return;
  }

  journalBloc.add(OcptBudgetEntryUpdateConfirmedEvent(entryId: entry.id, fields: result));
}

/// Opens the commitment dialog pre-filled with [commitment], then dispatches the update if the
/// user confirmed it.
Future<void> ocptBudgetEditCommitment(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetCommitment commitment,
) async {
  final journalBloc = context.read<OcptBudgetCashJournalBloc>();
  final fields = await OcptBudgetCommitmentDialog.show(
    context,
    existing: commitment,
    postes: state.postes,
    currencyCode: state.currencyCode,
    defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
    isSimplified: state.isSimplified,
  );
  if (fields == null) {
    return;
  }

  journalBloc.add(
    OcptBudgetCommitmentUpdateConfirmedEvent(commitmentId: commitment.id, fields: fields),
  );
}

/// Opens the resource dialog pre-filled with [resource], then dispatches the update if the user
/// confirmed it.
///
/// [OcptBudgetResourceDialog.initialPosteId] seeds the `Poste` picker from [resource]'s own
/// counterpart line, found by [ocptBudgetInKindCounterpartLineOf] — the poste an in-kind
/// contribution offsets lives on that line, not on the resource itself
/// (`OcptBudgetResourceFormFields.posteId`'s own doc comment).
Future<void> ocptBudgetEditResource(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetResource resource,
) async {
  final financingBloc = context.read<OcptBudgetFinancingBloc>();
  final fields = await OcptBudgetResourceDialog.show(
    context,
    existing: resource,
    groupKind: resource.groupKind,
    people: state.people,
    currencyCode: state.currencyCode,
    postes: state.postes,
    initialPosteId: ocptBudgetInKindCounterpartLineOf(state.postes, resource.id)?.posteId,
    isSimplified: state.isSimplified,
  );
  if (fields == null) {
    return;
  }

  financingBloc.add(
    OcptBudgetResourceUpdateConfirmedEvent(resourceId: resource.id, fields: fields),
  );
}

/// Opens the defrayal dialog — empty while creating, pre-filled from [existing] while editing —
/// then dispatches the write if the user confirmed it.
Future<void> ocptBudgetEditAllowance(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetAllowance? existing,
) async {
  final financingBloc = context.read<OcptBudgetFinancingBloc>();
  final fields = await OcptBudgetAllowanceDialog.show(
    context,
    existing: existing,
    people: state.people,
    mileageRates: state.mileageRates,
    currencyCode: state.currencyCode,
  );
  if (fields == null) {
    return;
  }

  financingBloc.add(
    existing == null
        ? OcptBudgetAllowanceCreationConfirmedEvent(fields: fields)
        : OcptBudgetAllowanceUpdateConfirmedEvent(allowanceId: existing.id, fields: fields),
  );
}

/// Opens the revenue dialog pre-filled with [revenue], then dispatches the update if the user
/// confirmed it.
Future<void> ocptBudgetEditRevenue(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetRevenue revenue,
) async {
  final sharingBloc = context.read<OcptBudgetSharingBloc>();
  final fields = await OcptBudgetRevenueDialog.show(
    context,
    existing: revenue,
    currencyCode: state.currencyCode,
  );
  if (fields == null) {
    return;
  }

  sharingBloc.add(OcptBudgetRevenueUpdateConfirmedEvent(revenueId: revenue.id, fields: fields));
}

/// Opens the share dialog pre-filled with [share], then dispatches the update if the user
/// confirmed it.
Future<void> ocptBudgetEditShare(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetShare share,
) async {
  final sharingBloc = context.read<OcptBudgetSharingBloc>();
  final fields = await OcptBudgetShareDialog.show(context, existing: share, people: state.people);
  if (fields == null) {
    return;
  }

  sharingBloc.add(OcptBudgetShareUpdateConfirmedEvent(shareId: share.id, fields: fields));
}

/// Opens the resources mode's own elements tab — `OcptBudgetFeedCard`'s own breakdown row,
/// wherever the card is drawn.
void ocptBudgetOpenBreakdownElements(BuildContext context) => context.read<OcptWorkspaceBloc>().add(
  const OcptWorkspaceModeSelectedEvent(
    mode: OcptWorkspaceMode.resources,
    revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.elements),
  ),
);

/// Opens the schedule mode — `OcptBudgetFeedCard`'s own schedule row, wherever the card is drawn.
void ocptBudgetOpenSchedule(BuildContext context) => context.read<OcptWorkspaceBloc>().add(
  const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.schedule),
);

/// Opens the catering-and-travel pass — `OcptBudgetFeedCard`'s own catering row, drawn only where
/// that pass is not itself already on screen. Sets **both** [OcptBudgetView.tools] and
/// [OcptBudgetToolsView.regie]: the first opens the drawer, the second picks which of its own
/// pages is on screen the moment it does, and neither event clears the other's own field.
void ocptBudgetOpenCatering(OcptBudgetBloc bloc) {
  bloc
    ..add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.tools))
    ..add(const OcptBudgetToolsViewSelectedEvent(toolsView: OcptBudgetToolsView.regie));
}
