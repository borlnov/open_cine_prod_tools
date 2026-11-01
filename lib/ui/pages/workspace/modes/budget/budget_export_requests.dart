// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_export_document.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financial_report_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_plan_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_quote_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// Builds the four entries the toolbar's `Export` button offers — see the class doc comment for
/// which of them is greyed and inert, and why.
List<OcptWorkspaceExportEntry<OcptBudgetExportDocument>> _exportEntriesOf(
  BuildContext context,
  OcptBudgetState state,
) {
  final tr = Tr.of(context);
  final noPosteReason = state.postes.isEmpty ? tr.budgetExportUnavailableNoPosteReason : null;

  return [
    OcptWorkspaceExportEntry<OcptBudgetExportDocument>(
      value: OcptBudgetExportDocument.quote,
      title: tr.budgetExportQuoteTitle,
      description: tr.budgetExportQuoteDescription,
      formatLabel: "PDF",
      unavailableReason: noPosteReason,
    ),
    OcptWorkspaceExportEntry<OcptBudgetExportDocument>(
      value: OcptBudgetExportDocument.financingPlan,
      title: tr.budgetExportFinancingPlanTitle,
      description: tr.budgetExportFinancingPlanDescription,
      formatLabel: "PDF",
      unavailableReason: state.resources.isEmpty
          ? tr.budgetExportUnavailableNoResourceReason
          : null,
    ),
    OcptWorkspaceExportEntry<OcptBudgetExportDocument>(
      value: OcptBudgetExportDocument.cashJournal,
      title: tr.budgetExportCashJournalTitle,
      description: tr.budgetExportCashJournalDescription,
      formatLabel: "XLSX",
      unavailableReason: state.entries.isEmpty ? tr.budgetExportUnavailableNoEntryReason : null,
    ),
    OcptWorkspaceExportEntry<OcptBudgetExportDocument>(
      value: OcptBudgetExportDocument.financialReport,
      title: tr.budgetExportFinancialReportTitle,
      description: tr.budgetExportFinancialReportDescription,
      formatLabel: "PDF",
      unavailableReason: noPosteReason,
    ),
  ];
}

/// Opens the toolbar's `Export` panel, then dispatches the picked document's own request onto its
/// own `_request…Export` method — each one opens its own options dialog first, the cash journal
/// alone taking none, exactly as `OcptScheduleMode._requestExport` does for its own six
/// documents.
Future<void> ocptBudgetRequestExport(
  BuildContext context,
  OcptBudgetState state,
  Rect? shareAnchor,
) async {
  final tr = Tr.of(context);
  final picked = await OcptWorkspaceExportDialog.show<OcptBudgetExportDocument>(
    context,
    title: tr.budgetExportPanelTitle,
    message: tr.budgetExportPanelMessage,
    entries: _exportEntriesOf(context, state),
    isPreviewingVersion: state.isPreviewingVersion,
  );
  if (picked == null) {
    return;
  }
  if (!context.mounted) {
    return;
  }

  switch (picked) {
    case OcptWorkspaceExportDocumentPick<OcptBudgetExportDocument>(:final document):
      switch (document) {
        case OcptBudgetExportDocument.quote:
          await _requestQuoteExport(context, state, shareAnchor);
        case OcptBudgetExportDocument.financingPlan:
          await _requestFinancingPlanExport(context, state, shareAnchor);
        case OcptBudgetExportDocument.cashJournal:
          _requestCashJournalExport(context, state, shareAnchor);
        case OcptBudgetExportDocument.financialReport:
          await _requestFinancialReportExport(context, state, shareAnchor);
      }
    case OcptWorkspaceExportProjectPackagePick<OcptBudgetExportDocument>():
      _requestProjectPackageExport(context);
  }
}

/// Shows the quote export options dialog, then dispatches the export request if the user applied
/// it, resolving here — the last place with a [BuildContext] — the labels, the breakdown element
/// names and the localized string the native save dialog carries.
Future<void> _requestQuoteExport(
  BuildContext context,
  OcptBudgetState state,
  Rect? shareAnchor,
) async {
  final options = await OcptBudgetQuoteExportDialog.show(
    context,
    current: state.pageSetup,
    taxBasis: state.taxBasis,
  );
  if (options == null) {
    return;
  }
  if (!context.mounted) {
    return;
  }

  final tr = Tr.of(context);
  context.read<OcptBudgetExportBloc>().add(
    OcptBudgetQuoteExportRequestedEvent(
      options: options,
      labels: ocptBudgetQuoteLabelsOf(context),
      elementNameById: {for (final element in state.elements) element.id: element.name},
      fileTypeLabel: tr.budgetExportFileTypeLabel,
      shareAnchor: shareAnchor,
    ),
  );
}

/// Shows the financing plan export options dialog, then dispatches the export request if the user
/// applied it — mirrors [_requestQuoteExport].
Future<void> _requestFinancingPlanExport(
  BuildContext context,
  OcptBudgetState state,
  Rect? shareAnchor,
) async {
  final options = await OcptBudgetFinancingPlanExportDialog.show(context, current: state.pageSetup);
  if (options == null) {
    return;
  }
  if (!context.mounted) {
    return;
  }

  final tr = Tr.of(context);
  context.read<OcptBudgetExportBloc>().add(
    OcptBudgetFinancingPlanExportRequestedEvent(
      options: options,
      labels: ocptBudgetFinancingPlanLabelsOf(context),
      fileTypeLabel: tr.budgetExportFileTypeLabel,
      shareAnchor: shareAnchor,
    ),
  );
}

/// Dispatches the cash journal export request straight away — this document takes no options
/// dialog of its own, mirroring every other options-free export in the app.
void _requestCashJournalExport(BuildContext context, OcptBudgetState state, Rect? shareAnchor) {
  final tr = Tr.of(context);
  context.read<OcptBudgetExportBloc>().add(
    OcptBudgetCashJournalExportRequestedEvent(
      labels: ocptBudgetCashJournalXlsxLabelsOf(context),
      linkLabelByEntryId: _linkLabelByEntryIdOf(state),
      fileTypeLabel: tr.budgetExportXlsxFileTypeLabel,
      shareAnchor: shareAnchor,
    ),
  );
}

/// What each live entry of [state] settles, keyed by its own id — a resource's, a taking's or a
/// share's own label read straight off the entry naming it, or the label of the commitment this
/// entry itself pays (`OcptBudgetEntry.commitmentId`), an entry naming none of them getting no
/// key here at all. `OcptBudgetCashJournalXlsxExportService` resolves nothing of this itself (its
/// own doc comment), which is what keeps it independent of `budget_revenues`/`budget_shares`.
Map<String, String> _linkLabelByEntryIdOf(OcptBudgetState state) {
  final resourceById = {for (final resource in state.resources) resource.id: resource};
  final revenueById = {for (final revenue in state.revenues) revenue.id: revenue};
  final shareById = {for (final share in state.shares) share.id: share};
  final commitmentById = {for (final commitment in state.commitments) commitment.id: commitment};

  final linkLabelByEntryId = <String, String>{};
  for (final entry in state.entries) {
    final resourceLabel = resourceById[entry.resourceId]?.label;
    final revenueLabel = revenueById[entry.revenueId]?.label;
    final shareLabel = shareById[entry.shareId]?.label;
    final paidCommitmentLabel = commitmentById[entry.commitmentId]?.label;
    final label = resourceLabel ?? revenueLabel ?? shareLabel ?? paidCommitmentLabel;
    if (label != null) {
      linkLabelByEntryId[entry.id] = label;
    }
  }

  return linkLabelByEntryId;
}

/// Shows the financial report export options dialog, then dispatches the export request if the
/// user applied it — mirrors [_requestFinancingPlanExport].
Future<void> _requestFinancialReportExport(
  BuildContext context,
  OcptBudgetState state,
  Rect? shareAnchor,
) async {
  final options = await OcptBudgetFinancialReportExportDialog.show(
    context,
    current: state.pageSetup,
  );
  if (options == null) {
    return;
  }
  if (!context.mounted) {
    return;
  }

  final tr = Tr.of(context);
  context.read<OcptBudgetExportBloc>().add(
    OcptBudgetFinancialReportExportRequestedEvent(
      options: options,
      labels: ocptBudgetFinancialReportLabelsOf(context),
      fileTypeLabel: tr.budgetExportFileTypeLabel,
      shareAnchor: shareAnchor,
    ),
  );
}

/// Dispatches the project package export, resolving here — the last place with a
/// [BuildContext] — the label the native save dialog carries. Mirrors
/// `OcptScheduleMode._requestProjectPackageExport`.
void _requestProjectPackageExport(BuildContext context) {
  context.read<OcptBudgetBloc>().add(
    OcptProjectPackageExportRequestedEvent(
      fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
    ),
  );
}
