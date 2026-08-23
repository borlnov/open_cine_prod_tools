// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_export_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_sub_page.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_allowance_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_capture_band.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_committed_spending.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_dashboard.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_element_picker_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financial_report_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_plan_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_help.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_poste_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_quote_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_match.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_provision.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The budget production mode: the quote, poste by poste — the dashboard and the cost-tracking
/// table this milestone builds, `Inspector`, `Versions` and `Help` in the right dock.
///
/// **There is no left dock** (the mockup shows none for this mode, `docs/architecture/budget.md`,
/// M1) and **no episode selector**: one budget serves the whole production (ADR 0019), its
/// catalogue naming no episode at all, exactly the schedule mode's own reason — not for want of a
/// bloc.
///
/// **The `Export` control now opens onto four real documents**: the quote, the financing plan, the
/// cash journal and the financial report (`OcptBudgetExportDocument`), each with its own card in
/// `_BudgetViewState._buildExportEntries` — the panel's standing project-package card sits under
/// them exactly as `exports.md` describes it. A card the underlying data cannot yet support is
/// greyed and inert with the reason in its own description's place, never hidden: the quote and the
/// financial report while the project holds no live poste at all, the financing plan while it holds
/// no live resource, and the cash journal while it holds no live entry — each a real, reachable
/// state (every poste can be deleted one by one, a fresh project starts with no resource and no
/// entry) rather than one invented for the sake of drawing a greyed card.
class OcptBudgetMode extends StatelessWidget {
  /// Creates the budget mode.
  const OcptBudgetMode({super.key});

  @override
  Widget build(BuildContext context) {
    // Resolved against this outer, listening-safe context and only then captured by the
    // provider's own `create` callback, whose own context may never listen to an InheritedWidget
    // (`Tr.of` does, through `Localizations.of`): that callback runs exactly once and is never
    // rebuilt, so Provider itself refuses a listening read there. The seed is otherwise resolved
    // once and handed to the bloc as a constructor argument: no bloc or service may ever see a
    // `Tr` — see `OcptBudgetBloc`'s own doc comment.
    final seed = ocptBudgetCncPosteSeeds(Tr.of(context));

    return BlocProvider(
      create: (context) => OcptBudgetBloc(seed: seed),
      child: const _BudgetView(),
    );
  }
}

/// The content of [OcptBudgetMode], separated from it so [OcptBudgetMode] only wires the
/// [OcptBudgetBloc] up (RFL3).
///
/// A StatefulWidget (the documented RFL1 exception) because it owns the dock layout controller,
/// mirroring `_ScheduleView`.
class _BudgetView extends StatefulWidget {
  /// Class constructor
  const _BudgetView();

  @override
  State<_BudgetView> createState() => _BudgetViewState();
}

/// The state of [_BudgetView]: owns the dock layout controller and keeps it in sync with the
/// fraction the bloc holds. Only the right dock is ever shown, so the controller's own
/// [OcptWorkspaceDockLayoutController.leftFraction] is never read past its constructor default.
class _BudgetViewState extends State<_BudgetView> {
  /// The live source of truth for the right dock fraction while dragging the divider.
  final OcptWorkspaceDockLayoutController _dockLayoutController = OcptWorkspaceDockLayoutController(
    leftFraction: OcptWorkspaceDock.leftDefaultFraction,
    rightFraction: OcptWorkspaceDock.rightDefaultFraction,
  );

  @override
  void deactivate() {
    // Triggering the flush here, rather than dispatching an event, is what guarantees the last
    // debounce worth of typing survives a mode switch or back navigation — see
    // `OcptBudgetBloc.flushPendingFieldEdits`'s own doc comment.
    unawaited(context.read<OcptBudgetBloc>().flushPendingFieldEdits());
    super.deactivate();
  }

  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<OcptBudgetBloc, OcptBudgetState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      return OcptWorkspaceShell(
        title: state.title,
        isDirty: false,
        isReadOnly: state.isPreviewingVersion,
        onBack: () => context.read<OcptBudgetBloc>().add(const OcptBudgetBackRequestedEvent()),
        // No episode selector: see the class doc comment.
        modeLabel: Tr.of(context).workspaceModeLabelBudget,
        onExportRequested: () => unawaited(_requestExport(context, state)),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () =>
            context.read<OcptBudgetBloc>().add(const OcptBudgetRightDockToggledEvent()),
        onProjectSettingsRequested: state.isPreviewingVersion
            ? null
            : () => unawaited(_requestProjectSettings(context)),
        // Never withheld under a preview — see `OcptWorkspaceShell.onHelpRequested`'s own doc
        // comment: a help panel only reads.
        onHelpRequested: () => context.read<OcptBudgetBloc>().add(
          const OcptBudgetRightDockTabSelectedEvent(tab: OcptBudgetRightDockTab.help),
        ),
        banner: _buildReadOnlyBanner(context, state),
        rightPanel: _buildRightDock(context, state),
        centre: _buildCentre(context, state),
        statusBar: OcptBudgetStatusBar(
          posteCount: state.posteCount,
          lineCount: state.lineCount,
          quotedTotalCents: ocptBudgetProjectQuotedTotalCents(state.postes),
          currencyCode: state.currencyCode,
        ),
        dockLayoutController: _dockLayoutController,
        onDockFractionsChanged: (fractions) {
          final right = fractions.right;
          if (right != null) {
            context.read<OcptBudgetBloc>().add(OcptBudgetRightDockFractionChangedEvent(fraction: right));
          }
        },
      );
    },
  );

  /// Builds the four entries the toolbar's `Export` button offers — see the class doc comment for
  /// which of them is greyed and inert, and why.
  List<OcptWorkspaceExportEntry<OcptBudgetExportDocument>> _buildExportEntries(
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
        unavailableReason: state.resources.isEmpty ? tr.budgetExportUnavailableNoResourceReason : null,
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
  /// alone taking none, exactly as `OcptScheduleMode._requestExport` does for its own six documents.
  Future<void> _requestExport(BuildContext context, OcptBudgetState state) async {
    final tr = Tr.of(context);
    final picked = await OcptWorkspaceExportDialog.show<OcptBudgetExportDocument>(
      context,
      title: tr.budgetExportPanelTitle,
      message: tr.budgetExportPanelMessage,
      entries: _buildExportEntries(context, state),
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
            await _requestQuoteExport(context, state);
          case OcptBudgetExportDocument.financingPlan:
            await _requestFinancingPlanExport(context, state);
          case OcptBudgetExportDocument.cashJournal:
            _requestCashJournalExport(context, state);
          case OcptBudgetExportDocument.financialReport:
            await _requestFinancialReportExport(context, state);
        }
      case OcptWorkspaceExportProjectPackagePick<OcptBudgetExportDocument>():
        _requestProjectPackageExport(context);
    }
  }

  /// Shows the quote export options dialog, then dispatches the export request if the user applied
  /// it, resolving here — the last place with a [BuildContext] — the labels, the breakdown element
  /// names and the localized string the native save dialog carries.
  Future<void> _requestQuoteExport(BuildContext context, OcptBudgetState state) async {
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
    context.read<OcptBudgetBloc>().add(
      OcptBudgetQuoteExportRequestedEvent(
        options: options,
        labels: ocptBudgetQuoteLabelsOf(context),
        elementNameById: {for (final element in state.elements) element.id: element.name},
        fileTypeLabel: tr.budgetExportFileTypeLabel,
      ),
    );
  }

  /// Shows the financing plan export options dialog, then dispatches the export request if the user
  /// applied it — mirrors [_requestQuoteExport].
  Future<void> _requestFinancingPlanExport(BuildContext context, OcptBudgetState state) async {
    final options = await OcptBudgetFinancingPlanExportDialog.show(context, current: state.pageSetup);
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    context.read<OcptBudgetBloc>().add(
      OcptBudgetFinancingPlanExportRequestedEvent(
        options: options,
        labels: ocptBudgetFinancingPlanLabelsOf(context),
        fileTypeLabel: tr.budgetExportFileTypeLabel,
      ),
    );
  }

  /// Dispatches the cash journal export request straight away — this document takes no options
  /// dialog of its own, mirroring every other options-free export in the app.
  void _requestCashJournalExport(BuildContext context, OcptBudgetState state) {
    final tr = Tr.of(context);
    context.read<OcptBudgetBloc>().add(
      OcptBudgetCashJournalExportRequestedEvent(
        labels: ocptBudgetCashJournalXlsxLabelsOf(context),
        linkLabelByEntryId: _linkLabelByEntryIdOf(state),
        fileTypeLabel: tr.budgetExportXlsxFileTypeLabel,
      ),
    );
  }

  /// What each live entry of [state] settles, keyed by its own id — a resource's, a taking's or a
  /// share's own label read straight off the entry naming it, or the label of the commitment this
  /// entry itself settles (`OcptBudgetCommitment.settledEntryId`), an entry naming none of them
  /// getting no key here at all. `OcptBudgetCashJournalXlsxExportService` resolves nothing of this
  /// itself (its own doc comment), which is what keeps it independent of `budget_revenues`/
  /// `budget_shares`.
  Map<String, String> _linkLabelByEntryIdOf(OcptBudgetState state) {
    final resourceById = {for (final resource in state.resources) resource.id: resource};
    final revenueById = {for (final revenue in state.revenues) revenue.id: revenue};
    final shareById = {for (final share in state.shares) share.id: share};
    final commitmentBySettledEntryId = {
      for (final commitment in state.commitments)
        if (commitment.settledEntryId != null) commitment.settledEntryId!: commitment,
    };

    final linkLabelByEntryId = <String, String>{};
    for (final entry in state.entries) {
      final resourceLabel = resourceById[entry.resourceId]?.label;
      final revenueLabel = revenueById[entry.revenueId]?.label;
      final shareLabel = shareById[entry.shareId]?.label;
      final settledCommitmentLabel = commitmentBySettledEntryId[entry.id]?.label;
      final label = resourceLabel ?? revenueLabel ?? shareLabel ?? settledCommitmentLabel;
      if (label != null) {
        linkLabelByEntryId[entry.id] = label;
      }
    }

    return linkLabelByEntryId;
  }

  /// Shows the financial report export options dialog, then dispatches the export request if the
  /// user applied it — mirrors [_requestFinancingPlanExport].
  Future<void> _requestFinancialReportExport(BuildContext context, OcptBudgetState state) async {
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
    context.read<OcptBudgetBloc>().add(
      OcptBudgetFinancialReportExportRequestedEvent(
        options: options,
        labels: ocptBudgetFinancialReportLabelsOf(context),
        fileTypeLabel: tr.budgetExportFileTypeLabel,
      ),
    );
  }

  /// Dispatches the project package export, resolving here — the last place with a
  /// [BuildContext] — the label the native save dialog carries. Mirrors
  /// `OcptScheduleMode._requestProjectPackageExport`.
  void _requestProjectPackageExport(BuildContext context) {
    context.read<OcptBudgetBloc>().add(
      OcptProjectPackageExportRequestedEvent(fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel),
    );
  }

  /// Asks whether to write the package even though some referenced files are gone, then dispatches
  /// the export if the user said to go on. Mirrors `OcptScheduleMode._askAboutMissingPackagedFiles`.
  Future<void> _askAboutMissingPackagedFiles(
    BuildContext context,
    OcptProjectPackagePreflight preflight,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final confirmed = await ocptAskAboutMissingPackagedFiles(context, preflight);
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptProjectPackageExportConfirmedEvent(fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel),
    );
  }

  /// Opens the project settings page, then re-reads the currency and default VAT rate if the user
  /// changed something — mirrors `OcptScheduleMode._requestProjectSettings`.
  Future<void> _requestProjectSettings(BuildContext context) async {
    final bloc = context.read<OcptBudgetBloc>();
    final workspaceBloc = context.read<OcptWorkspaceBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
    );
    if (hasChanged != true) {
      return;
    }

    bloc.add(const OcptBudgetProjectSettingsChangedEvent());
    workspaceBloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
  }

  /// Builds the shell's `centre`: the header band, then whichever widget the current route
  /// ([OcptBudgetState.document], [OcptBudgetState.reading] and [OcptBudgetState.subPage]) names —
  /// see [_buildRoute].
  Widget _buildCentre(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcptBudgetHeader(
          document: state.document,
          onDocumentSelected: (document) =>
              bloc.add(OcptBudgetDocumentSelectedEvent(document: document)),
          reading: state.reading,
          onReadingSelected: (reading) =>
              bloc.add(OcptBudgetDocumentReadingSelectedEvent(reading: reading)),
          subPage: state.subPage,
          onSubPageSelected: (subPage) => bloc.add(OcptBudgetSubPageSelectedEvent(subPage: subPage)),
          isSimplified: state.isSimplified,
          onSimplifiedChanged: (value) =>
              bloc.add(OcptBudgetSimplifiedToggledEvent(isSimplified: value)),
          taxBasis: state.taxBasis,
          onTaxBasisChanged: (basis) => bloc.add(OcptBudgetTaxBasisChangedEvent(basis: basis)),
          postes: state.postes,
          filterPosteId: state.filterPosteId,
          onPosteFilterSelected: (posteId) =>
              bloc.add(OcptBudgetPosteFilterSelectedEvent(posteId: posteId)),
          alerts: state.alerts,
          currencyCode: state.currencyCode,
          onAlertPosteActionRequested: (posteId) {
            bloc
              ..add(OcptBudgetPosteSelectedEvent(posteId: posteId))
              ..add(
                const OcptBudgetDocumentReadingSelectedEvent(
                  reading: OcptBudgetDocumentReading.byTree,
                ),
              );
          },
          onCashProjectionAlertActionRequested: () => bloc.add(
            const OcptBudgetSubPageSelectedEvent(subPage: OcptBudgetSubPage.committedSpending),
          ),
        ),
        const SizedBox(height: 12),
        if (_showsCaptureBand(state)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildCaptureBand(context, state, bloc),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildRoute(context, state),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Whether [OcptBudgetCaptureBand] is mounted at all: [OcptBudgetState.document] is `expenses`
  /// or `resources`, at its own top level ([OcptBudgetState.subPage] null) — never on `sharing`,
  /// never on a sub-page — and the project is not a previewed version, which withholds the band
  /// **whole** rather than drawing it disabled (`docs/plans/budget-mode-ux.md` M3).
  bool _showsCaptureBand(OcptBudgetState state) =>
      !state.isPreviewingVersion &&
      state.subPage == null &&
      (state.document == OcptBudgetDocument.expenses ||
          state.document == OcptBudgetDocument.resources);

  /// Builds the capture band — keyed by [OcptBudgetState.document] so switching between `expenses`
  /// and `resources` remounts it fresh, its own draft cleared and its own direction back to
  /// [OcptBudgetDocument.expenses]'s debit default or [OcptBudgetDocument.resources]'s credit one,
  /// rather than carrying a draft typed for one document's own direction into the other's.
  ///
  /// **The three callbacks are where a suggestion's own kind is turned into a domain write** — the
  /// band itself only ever reports what was typed (see `OcptBudgetCaptureBand`'s own class doc
  /// comment): [_handleCaptureBandSuggestionAccepted] is this method's own mirror of
  /// [_handleCommitmentSettleRequested] and [_handleResourceReceiptRequested], reusing the very same
  /// events, this time built from the band's own draft instead of a dialog's.
  Widget _buildCaptureBand(BuildContext context, OcptBudgetState state, OcptBudgetBloc bloc) =>
      OcptBudgetCaptureBand(
        key: ValueKey(state.document),
        initialIsDebit: state.document == OcptBudgetDocument.expenses,
        commitments: state.commitments,
        allowances: state.allowances,
        resources: state.resources,
        revenues: state.revenues,
        receivedByResourceId: state.receivedByResourceId,
        receivedByRevenueId: state.receivedByRevenueId,
        projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
        postes: state.postes,
        currencyCode: state.currencyCode,
        onEntryCaptured: (fields) =>
            bloc.add(OcptBudgetEntryCreationConfirmedEvent(fields: fields)),
        onOtherRequested: (fields) =>
            unawaited(_handleCaptureBandOtherRequested(context, state, fields)),
        onSuggestionAccepted: (suggestion, fields) =>
            _handleCaptureBandSuggestionAccepted(bloc, state, suggestion, fields),
      );

  /// `Autre chose…`: opens `OcptBudgetEntryDialog` prefilled with the capture band's own draft,
  /// then dispatches the creation if the user confirmed it — mirrors `_handleEntryCreationRequested`
  /// with [fields] standing in for an empty dialog.
  Future<void> _handleCaptureBandOtherRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetEntryFormFields fields,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final result = await OcptBudgetEntryDialog.show(
      context,
      existing: null,
      prefill: fields,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (result == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryCreationConfirmedEvent(fields: result));
  }

  /// `C'est ça`: turns the capture band's own [suggestion] and [fields] into the write its own
  /// kind calls for — see `OcptBudgetCaptureBand`'s own class doc comment for why this mapping
  /// lives here rather than in the band itself.
  ///
  /// **The commitment case is the only one adding fields the draft never carried**
  /// ([OcptBudgetCommitment.posteId], its own tax basis and its own VAT rate) — mirrors
  /// [_handleCommitmentSettleRequested]'s own prefill. The other three keep every one of [fields]'s
  /// own values, only naming the matched row (`resourceId`/`revenueId`) or, for a defrayal, adopting
  /// its own [OcptBudgetMatchSuggestion.label] in place of the draft's — the one asymmetry
  /// `OcptBudgetCaptureBand._headlineOf`'s own doc comment already argues for: nothing in the schema
  /// lets a defrayal be marked settled, so the label is the only trace this movement can leave of it.
  void _handleCaptureBandSuggestionAccepted(
    OcptBudgetBloc bloc,
    OcptBudgetState state,
    OcptBudgetMatchSuggestion suggestion,
    OcptBudgetEntryFormFields fields,
  ) {
    switch (suggestion.kind) {
      case OcptBudgetMatchCandidateKind.commitment:
        final commitment = state.commitments
            .where((candidate) => candidate.id == suggestion.candidateId)
            .firstOrNull;
        if (commitment == null) {
          return;
        }
        bloc.add(
          OcptBudgetCommitmentSettlementConfirmedEvent(
            commitmentId: commitment.id,
            fields: OcptBudgetEntryFormFields(
              date: fields.date,
              label: fields.label,
              posteId: commitment.posteId,
              resourceId: null,
              revenueId: null,
              shareId: null,
              isDebit: fields.isDebit,
              amountCents: fields.amountCents,
              isTaxInclusive: commitment.amount.isTaxInclusive,
              vatRateBasisPoints: commitment.amount.vatRateBasisPoints,
              voucherNumber: null,
              pickedReceiptPath: null,
              isReceiptDetached: false,
            ),
          ),
        );
      case OcptBudgetMatchCandidateKind.resource:
        bloc.add(
          OcptBudgetEntryCreationConfirmedEvent(
            fields: OcptBudgetEntryFormFields(
              date: fields.date,
              label: fields.label,
              posteId: null,
              resourceId: suggestion.candidateId,
              revenueId: null,
              shareId: null,
              isDebit: fields.isDebit,
              amountCents: fields.amountCents,
              isTaxInclusive: fields.isTaxInclusive,
              vatRateBasisPoints: fields.vatRateBasisPoints,
              voucherNumber: null,
              pickedReceiptPath: null,
              isReceiptDetached: false,
            ),
          ),
        );
      case OcptBudgetMatchCandidateKind.revenue:
        bloc.add(
          OcptBudgetEntryCreationConfirmedEvent(
            fields: OcptBudgetEntryFormFields(
              date: fields.date,
              label: fields.label,
              posteId: null,
              resourceId: null,
              revenueId: suggestion.candidateId,
              shareId: null,
              isDebit: fields.isDebit,
              amountCents: fields.amountCents,
              isTaxInclusive: fields.isTaxInclusive,
              vatRateBasisPoints: fields.vatRateBasisPoints,
              voucherNumber: null,
              pickedReceiptPath: null,
              isReceiptDetached: false,
            ),
          ),
        );
      case OcptBudgetMatchCandidateKind.defrayal:
        bloc.add(
          OcptBudgetEntryCreationConfirmedEvent(
            fields: OcptBudgetEntryFormFields(
              date: fields.date,
              label: suggestion.label,
              posteId: null,
              resourceId: null,
              revenueId: null,
              shareId: null,
              isDebit: fields.isDebit,
              amountCents: fields.amountCents,
              isTaxInclusive: fields.isTaxInclusive,
              vatRateBasisPoints: fields.vatRateBasisPoints,
              voucherNumber: null,
              pickedReceiptPath: null,
              isReceiptDetached: false,
            ),
          ),
        );
    }
  }

  /// Builds whichever widget the current route names — `docs/plans/budget-mode-ux.md` M2's own
  /// table, unchanged from the seven views `OcptBudgetCentreView` used to switch over: only the
  /// switch's own shape moved, from one flat enum to a document, a reading and an optional
  /// sub-page.
  Widget _buildRoute(BuildContext context, OcptBudgetState state) {
    final subPage = state.subPage;
    if (subPage != null) {
      return switch (subPage) {
        OcptBudgetSubPage.committedSpending => _buildCommittedSpending(context, state),
        OcptBudgetSubPage.regie => _buildRegie(context, state),
        OcptBudgetSubPage.dashboard => _buildDashboard(context, state),
      };
    }

    return switch (state.document) {
      OcptBudgetDocument.expenses => state.reading == OcptBudgetDocumentReading.byDate
          ? _buildCashJournal(context, state)
          : _buildCostTracking(context, state),
      OcptBudgetDocument.resources => _buildFinancing(context, state),
      OcptBudgetDocument.sharing => _buildSharing(context, state),
    };
  }

  /// Builds the dashboard.
  Widget _buildDashboard(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final elementLinkCounts = state.elementLinkCounts;

    return OcptBudgetDashboard(
      postes: state.postes,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      cashTotals: state.cashTotals,
      paidByPosteId: state.paidByPosteId,
      offQuotePaidTotal: state.offQuotePaidTotal,
      committedByPosteId: state.committedByPosteId,
      alerts: state.alerts,
      resources: state.resources,
      breakdownPricedElementCount: elementLinkCounts.pricedCount,
      breakdownUnpricedElementCount: elementLinkCounts.unpricedCount,
      shootingDayCount: state.regieDays.length,
      mealCount: state.regieTotals.mealCount,
      buffetCount: state.regieTotals.buffetCount,
      onPosteOpened: (posteId) {
        bloc
          ..add(OcptBudgetPosteSelectedEvent(posteId: posteId))
          ..add(
            const OcptBudgetDocumentReadingSelectedEvent(
              reading: OcptBudgetDocumentReading.byTree,
            ),
          );
      },
      onCashAlertActionRequested: () => bloc.add(
        const OcptBudgetSubPageSelectedEvent(subPage: OcptBudgetSubPage.committedSpending),
      ),
      onBreakdownFeedRequested: () => context.read<OcptWorkspaceBloc>().add(
        const OcptWorkspaceModeSelectedEvent(
          mode: OcptWorkspaceMode.resources,
          revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.elements),
        ),
      ),
      onScheduleFeedRequested: () => context.read<OcptWorkspaceBloc>().add(
        const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.schedule),
      ),
      onCateringFeedRequested: () =>
          bloc.add(const OcptBudgetSubPageSelectedEvent(subPage: OcptBudgetSubPage.regie)),
    );
  }

  /// Builds the cost-tracking table.
  Widget _buildCostTracking(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetCostTracking(
      // **The filter is applied here, not inside the view.** Every one of these widgets draws
      // exactly the rows it is handed and totals exactly those, so narrowing the list is the whole
      // of it: a filtered table's own `Total` reads the total of what is on screen, which is the
      // only honest thing it can say.
      postes: _filteredPostesOf(state),
      selectedPosteId: state.selectedPosteId,
      isSimplified: state.isSimplified,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      paidByPosteId: state.paidByPosteId,
      committedCentsOf: state.committedCentsOf,
      offQuoteTotal: state.offQuotePaidTotal,
      isReadOnly: isReadOnly,
      onPosteSelected: (posteId) => bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId)),
      onPosteCreationRequested: isReadOnly
          ? null
          : () => bloc.add(const OcptBudgetPosteCreatedEvent()),
      onPosteReorderRequested: isReadOnly
          ? null
          : (posteId, {required moveUp}) => bloc.add(
              OcptBudgetPosteReorderedEvent(
                posteId: posteId,
                newPosition: _posteReorderedPosition(state, posteId, moveUp),
              ),
            ),
      onPosteDeletionRequested: isReadOnly
          ? null
          : (posteId) => unawaited(_handlePosteDeletionRequested(context, posteId)),
    );
  }

  /// The 0-based position poste [posteId] moves to when its row's own `▲`/`▼` menu entry is
  /// clicked — one above or below its current position in [OcptBudgetState.postes]' own order, a
  /// poste id no longer found there (should not happen, the shell already refused to draw a stale
  /// row's menu) falling back to leaving it where it is.
  int _posteReorderedPosition(OcptBudgetState state, String posteId, bool moveUp) {
    final currentIndex = state.postes.indexWhere((poste) => poste.id == posteId);
    if (currentIndex < 0) {
      return 0;
    }

    return moveUp ? currentIndex - 1 : currentIndex + 1;
  }

  /// Asks `OcptConfirmDialog` whether poste [posteId] really is to be deleted — the message says
  /// its own quote lines go with it — then dispatches the deletion if the user answered `Delete`.
  Future<void> _handlePosteDeletionRequested(BuildContext context, String posteId) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetDeletePosteConfirmTitle,
      message: tr.budgetDeletePosteConfirmMessage,
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetDeleteConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetPosteDeletionConfirmedEvent(posteId: posteId));
  }

  /// [state]'s own postes, narrowed to the one the header's filter names — or every one of them
  /// while nothing is filtered.
  ///
  /// See `ocptBudgetCentreViewHonoursPosteFilter` for which views read this and which say they
  /// cannot.
  List<OcptBudgetPoste> _filteredPostesOf(OcptBudgetState state) {
    final filterPosteId = state.filterPosteId;

    return filterPosteId == null
        ? state.postes
        : [
            for (final poste in state.postes)
              if (poste.id == filterPosteId) poste,
          ];
  }

  /// [state]'s own commitments, narrowed to the poste the header's filter names — the mirror of
  /// [_filteredPostesOf], reading the other side of the same filter.
  ///
  /// The poste **list** handed to that view stays whole: it is what a commitment's own `Poste` cell
  /// looks its name up in, not a list of rows, and narrowing it would only make a filtered row
  /// unable to name the very poste it was filtered by.
  List<OcptBudgetCommitment> _filteredCommitmentsOf(OcptBudgetState state) {
    final filterPosteId = state.filterPosteId;

    return filterPosteId == null
        ? state.commitments
        : [
            for (final commitment in state.commitments)
              if (commitment.posteId == filterPosteId) commitment,
          ];
  }

  /// Builds the cash journal view.
  Widget _buildCashJournal(BuildContext context, OcptBudgetState state) {
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetCashJournal(
      entries: state.entries,
      postes: state.postes,
      receiptsByEntryId: state.receiptsByEntryId,
      filterPosteId: state.filterPosteId,
      isSimplified: state.isSimplified,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      isReadOnly: isReadOnly,
      onEntryCreationRequested: isReadOnly
          ? null
          : () => unawaited(_handleEntryCreationRequested(context, state)),
      onEntryTapped: isReadOnly
          ? null
          : (entry) => unawaited(_handleEntryEditRequested(context, state, entry)),
      onEntryDeletionRequested: isReadOnly
          ? null
          : (entryId) => unawaited(_handleEntryDeletionRequested(context, entryId)),
    );
  }

  /// Opens the entry dialog with nothing pre-filled, then dispatches the creation if the user
  /// confirmed it.
  Future<void> _handleEntryCreationRequested(BuildContext context, OcptBudgetState state) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptBudgetEntryDialog.show(
      context,
      existing: null,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryCreationConfirmedEvent(fields: fields));
  }

  /// Opens the entry dialog pre-filled with [entry], then dispatches the update if the user
  /// confirmed it.
  Future<void> _handleEntryEditRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetEntry entry,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptBudgetEntryDialog.show(
      context,
      existing: entry,
      existingReceipt: state.receiptsByEntryId[entry.id],
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryUpdateConfirmedEvent(entryId: entry.id, fields: fields));
  }

  /// Asks `OcptConfirmDialog` whether cash-journal entry [entryId] really is to be deleted, then
  /// dispatches the deletion if the user answered `Delete`.
  Future<void> _handleEntryDeletionRequested(BuildContext context, String entryId) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetDeleteEntryConfirmTitle,
      message: tr.budgetDeleteEntryConfirmMessage,
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetDeleteConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId));
  }

  /// Builds the committed-spending view.
  Widget _buildCommittedSpending(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetCommittedSpending(
      commitments: _filteredCommitmentsOf(state),
      postes: state.postes,
      openingBalanceCents: state.cashTotals.balanceCents,
      isSimplified: state.isSimplified,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      isReadOnly: isReadOnly,
      onCommitmentCreationRequested: isReadOnly
          ? null
          : () => unawaited(_handleCommitmentCreationRequested(context, state)),
      onCommitmentTapped: isReadOnly
          ? null
          : (commitment) => unawaited(_handleCommitmentEditRequested(context, state, commitment)),
      onCommitmentSettleRequested: isReadOnly
          ? null
          : (commitment) => unawaited(_handleCommitmentSettleRequested(context, state, commitment)),
      onCommitmentUnsettleRequested: isReadOnly
          ? null
          : (commitmentId) =>
                bloc.add(OcptBudgetCommitmentUnsettleRequestedEvent(commitmentId: commitmentId)),
      onCommitmentDeletionRequested: isReadOnly
          ? null
          : (commitmentId) => unawaited(_handleCommitmentDeletionRequested(context, commitmentId)),
    );
  }

  /// Opens the commitment dialog with nothing pre-filled, then dispatches the creation if the user
  /// confirmed it.
  Future<void> _handleCommitmentCreationRequested(BuildContext context, OcptBudgetState state) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptBudgetCommitmentDialog.show(
      context,
      existing: null,
      postes: state.postes,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetCommitmentCreationConfirmedEvent(fields: fields));
  }

  /// Opens the commitment dialog pre-filled with [commitment], then dispatches the update if the
  /// user confirmed it.
  Future<void> _handleCommitmentEditRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetCommitment commitment,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
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
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetCommitmentUpdateConfirmedEvent(commitmentId: commitment.id, fields: fields));
  }

  /// Asks `OcptConfirmDialog` whether commitment [commitmentId] really is to be deleted, then
  /// dispatches the deletion if the user answered `Delete`.
  Future<void> _handleCommitmentDeletionRequested(BuildContext context, String commitmentId) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetDeleteCommitmentConfirmTitle,
      message: tr.budgetDeleteCommitmentConfirmMessage,
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetDeleteConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetCommitmentDeletionConfirmedEvent(commitmentId: commitmentId));
  }

  /// Opens the entry dialog pre-filled from [commitment] (today's date, its own label, poste,
  /// amount, tax basis and rate, as a debit), then dispatches the settlement if the user confirmed
  /// it — see `OcptBudgetCommitmentSettlementConfirmedEvent`'s own doc comment for the combined
  /// write this produces.
  Future<void> _handleCommitmentSettleRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetCommitment commitment,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final now = DateTime.now();
    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(now.year, now.month, now.day),
      label: commitment.label,
      posteId: commitment.posteId,
      resourceId: null,
      revenueId: null,
      shareId: null,
      isDebit: true,
      amountCents: commitment.amount.amountCents,
      isTaxInclusive: commitment.amount.isTaxInclusive,
      vatRateBasisPoints: commitment.amount.vatRateBasisPoints,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    final fields = await OcptBudgetEntryDialog.show(
      context,
      existing: null,
      prefill: prefill,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptBudgetCommitmentSettlementConfirmedEvent(commitmentId: commitment.id, fields: fields),
    );
  }

  /// Builds the financing view.
  Widget _buildFinancing(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetFinancing(
      resources: state.resources,
      receivedByResourceId: state.receivedByResourceId,
      receivedCentsOf: state.receivedCentsOf,
      currencyCode: state.currencyCode,
      selectedResourceId: state.selectedResourceId,
      isReadOnly: isReadOnly,
      onResourceCreationRequested: isReadOnly
          ? null
          : (groupKind) =>
                unawaited(_handleResourceCreationRequested(context, state, groupKind)),
      onResourceSelected: (resourceId) =>
          bloc.add(OcptBudgetResourceSelectedEvent(resourceId: resourceId)),
      onResourceEditRequested: isReadOnly
          ? null
          : (resource) => unawaited(_handleResourceEditRequested(context, state, resource)),
      onResourceReceiptRequested: isReadOnly
          ? null
          : (resource) => unawaited(_handleResourceReceiptRequested(context, state, resource)),
      onResourceReceiptUndoRequested: isReadOnly
          ? null
          : (resource) => unawaited(_handleResourceReceiptUndoRequested(context, state, resource)),
      onResourceDeletionRequested: isReadOnly
          ? null
          : (resourceId) => unawaited(_handleResourceDeletionRequested(context, resourceId)),
    );
  }

  /// Opens the resource dialog with nothing pre-filled but its own [groupKind] — the kind the
  /// financing view's own three explicit creation gestures each already picked before this ever
  /// opens — then dispatches the creation if the user confirmed it.
  Future<void> _handleResourceCreationRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetResourceGroupKind groupKind,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptBudgetResourceDialog.show(
      context,
      existing: null,
      groupKind: groupKind,
      people: state.people,
      currencyCode: state.currencyCode,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetResourceCreationConfirmedEvent(fields: fields));
  }

  /// Opens the resource dialog pre-filled with [resource], then dispatches the update if the user
  /// confirmed it.
  Future<void> _handleResourceEditRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetResource resource,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptBudgetResourceDialog.show(
      context,
      existing: resource,
      groupKind: resource.groupKind,
      people: state.people,
      currencyCode: state.currencyCode,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetResourceUpdateConfirmedEvent(resourceId: resource.id, fields: fields));
  }

  /// Asks `OcptConfirmDialog` whether financing resource [resourceId] really is to be deleted, then
  /// dispatches the deletion if the user answered `Delete`.
  Future<void> _handleResourceDeletionRequested(BuildContext context, String resourceId) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetDeleteResourceConfirmTitle,
      message: tr.budgetDeleteResourceConfirmMessage,
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetDeleteConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetResourceDeletionConfirmedEvent(resourceId: resourceId));
  }

  /// Opens the entry dialog pre-filled from [resource] (today's date, its own label, as a credit,
  /// for whatever is still outstanding against it, the resource already named), then dispatches the
  /// creation if the user confirmed it — mirrors `_handleCommitmentSettleRequested`'s own gesture:
  /// see "A commitment settles by naming the entry that paid it" in `docs/architecture/budget.md`
  /// for the reading this mirrors, a receipt naming the resource that earned it instead of a
  /// commitment being paid.
  Future<void> _handleResourceReceiptRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetResource resource,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final now = DateTime.now();
    final outstandingCents = ocptBudgetResourceOutstandingCents(
      amountCents: resource.amountCents,
      receivedCents: state.receivedCentsOf(resource.id),
    );
    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(now.year, now.month, now.day),
      label: resource.label,
      posteId: null,
      resourceId: resource.id,
      revenueId: null,
      shareId: null,
      isDebit: false,
      amountCents: outstandingCents < 0 ? 0 : outstandingCents,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    final fields = await OcptBudgetEntryDialog.show(
      context,
      existing: null,
      prefill: prefill,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryCreationConfirmedEvent(fields: fields));
  }

  /// Resolves the most recently recorded live credit against [resource]
  /// (`ocptBudgetLatestReceiptEntryIdOf`, `lib/utils/ocpt_budget_financing.dart`), asks
  /// `OcptConfirmDialog` whether it really is to be undone, then dispatches its deletion — the very
  /// same `OcptBudgetEntryDeletionConfirmedEvent` the cash journal's own `Delete` already uses,
  /// tombstoning the entry rather than un-receiving the resource through any figure of its own
  /// (`budget_resources` stores none — `docs/architecture/budget.md`). `OcptBudgetFinancing`'s own
  /// `Undo the last receipt` menu entry is withheld whenever the resource has received nothing at
  /// all, so [resource] here always names one, but a defensive null check still guards a race
  /// against the entry having been deleted from elsewhere between the click and this read.
  Future<void> _handleResourceReceiptUndoRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetResource resource,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final entryId = ocptBudgetLatestReceiptEntryIdOf(state.entries, resourceId: resource.id);
    if (entryId == null) {
      return;
    }

    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetUndoReceiptConfirmTitle,
      message: tr.budgetUndoReceiptConfirmMessage,
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetDeleteConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId));
  }

  /// Builds the catering-and-defrayals view: the catering it computes, the defrayals it lets a
  /// production type, and the band that provisions both into the quote.
  ///
  /// The catering's own callbacks only ever report where a figure was typed — the schedule mode or
  /// the project settings page — while the defrayals and the provisioning are real writes, opened
  /// from here and confirmed from here, exactly as every other writing view of this mode is.
  Widget _buildRegie(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;
    // The plan is computed for the band as well as for the gesture: a provisioning that would do
    // nothing is withheld, and the band says why in its place rather than answering a click with a
    // dialog that only says "no".
    final plan = _provisionPlanOf(context, state);
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
      postes: state.postes,
      provisionPosteId: state.provisionPosteId,
      provisionedTotalCents: _provisionedTotalCentsOf(state),
      roles: state.roles,
      people: state.people,
      currencyCode: state.currencyCode,
      isReadOnly: isReadOnly,
      onScheduleOpenRequested: () => context.read<OcptWorkspaceBloc>().add(
        const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.schedule),
      ),
      onProjectSettingsRequested: () => unawaited(_requestProjectSettings(context)),
      onPersonOpenRequested: (personId) => context.read<OcptWorkspaceBloc>().add(
        OcptWorkspaceModeSelectedEvent(
          mode: OcptWorkspaceMode.resources,
          revealRequest: OcptResourcesRevealRequest(
            tab: OcptResourcesTab.people,
            recordId: personId,
          ),
        ),
      ),
      onAllowanceCreationRequested: isReadOnly
          ? null
          : () => unawaited(_handleAllowanceDialogRequested(context, state, null)),
      onAllowanceEditRequested: isReadOnly
          ? null
          : (allowanceId) => unawaited(
              _handleAllowanceDialogRequested(
                context,
                state,
                state.allowances.where((row) => row.id == allowanceId).firstOrNull,
              ),
            ),
      onAllowanceDeletionRequested: isReadOnly
          ? null
          : (allowanceId) => unawaited(_handleAllowanceDeletionRequested(context, allowanceId)),
      onProvisionPosteSelected: isReadOnly
          ? null
          : (posteId) => bloc.add(OcptBudgetProvisionPosteSelectedEvent(posteId: posteId)),
      onProvisionRequested: isReadOnly || !wouldWrite
          ? null
          : () => unawaited(_handleProvisionRequested(context, state)),
      provisionNote: wouldWrite || state.provisionPosteId == null
          ? null
          : (skipped > 0
                ? Tr.of(context).budgetProvisionOnlyEditedMessage
                : Tr.of(context).budgetProvisionNothingToDoMessage),
    );
  }

  /// What provisioning would do to the poste [OcptBudgetState.provisionPosteId] names, whole.
  ///
  /// Read twice: once to draw the band — which withholds the gesture and says why when the plan
  /// would change nothing — and once when the gesture is actually taken, so what the user is shown
  /// and what is written come from the same computation.
  List<OcptBudgetProvisionEntry> _provisionPlanOf(BuildContext context, OcptBudgetState state) {
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

  /// Opens the defrayal dialog — empty while creating, pre-filled from [existing] while editing —
  /// then dispatches the write if the user confirmed it.
  Future<void> _handleAllowanceDialogRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetAllowance? existing,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
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

    bloc.add(
      existing == null
          ? OcptBudgetAllowanceCreationConfirmedEvent(fields: fields)
          : OcptBudgetAllowanceUpdateConfirmedEvent(allowanceId: existing.id, fields: fields),
    );
  }

  /// Asks `OcptConfirmDialog` whether defrayal [allowanceId] really is to be deleted, then
  /// dispatches the deletion if the user answered `Delete`.
  Future<void> _handleAllowanceDeletionRequested(
    BuildContext context,
    String allowanceId,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetDeleteAllowanceConfirmTitle,
      message: tr.budgetDeleteAllowanceConfirmMessage,
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetDeleteConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetAllowanceDeletionConfirmedEvent(allowanceId: allowanceId));
  }

  /// Computes what provisioning would do, puts those counts in front of the user through
  /// `OcptConfirmDialog`, and dispatches it only if they agree.
  ///
  /// **The plan is computed here, whole, before anything is written**, and travels with the event:
  /// it is what the user was shown and said yes to. Its wordings are resolved here too, since no
  /// bloc and no util of this app ever sees a `Tr`.
  ///
  /// A plan that would change nothing says so and asks nothing: there is no decision to take.
  Future<void> _handleProvisionRequested(BuildContext context, OcptBudgetState state) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);
    final posteId = state.provisionPosteId;
    final poste = state.postes.where((row) => row.id == posteId).firstOrNull;
    if (posteId == null || poste == null) {
      return;
    }

    final entries = _provisionPlanOf(context, state);

    final created = entries
        .where((entry) => entry.outcome == OcptBudgetProvisionOutcome.created)
        .length;
    final updated = entries
        .where((entry) => entry.outcome == OcptBudgetProvisionOutcome.updated)
        .length;
    final skipped = entries
        .where((entry) => entry.outcome == OcptBudgetProvisionOutcome.skippedEdited)
        .length;

    // **Not destructive**, unlike every other confirmation of this mode: provisioning creates and
    // updates lines the app itself owns, and never overwrites one somebody has edited — the plan's
    // own `skippedEdited` outcome is the whole point. A red button would be telling the reader
    // something about this gesture that is not true.
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetProvisionConfirmTitle,
      message: tr.budgetProvisionConfirmMessage(created, updated, skipped),
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetRegieProvisionAction,
      isDestructive: false,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetProvisionConfirmedEvent(posteId: posteId, entries: entries));
  }

  /// Builds the revenue sharing view.
  Widget _buildSharing(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetSharing(
      revenues: state.revenues,
      shares: state.shares,
      receivedByRevenueId: state.receivedByRevenueId,
      sharingPot: state.sharingPot,
      repaymentLines: state.repaymentLines,
      shareSplits: state.shareSplits,
      people: state.people,
      currencyCode: state.currencyCode,
      selectedRevenueId: state.selectedRevenueId,
      selectedShareId: state.selectedShareId,
      isReadOnly: isReadOnly,
      onRevenueCreationRequested: isReadOnly
          ? null
          : () => unawaited(_handleRevenueCreationRequested(context, state)),
      onRevenueSelected: (revenueId) => bloc.add(OcptBudgetRevenueSelectedEvent(revenueId: revenueId)),
      onRevenueEditRequested: isReadOnly
          ? null
          : (revenue) => unawaited(_handleRevenueEditRequested(context, state, revenue)),
      onRevenueReceiptRequested: isReadOnly
          ? null
          : (revenue) => unawaited(_handleRevenueReceiptRequested(context, state, revenue)),
      onRevenueReorderRequested: isReadOnly
          ? null
          : (revenueId, {required moveUp}) => bloc.add(
              OcptBudgetRevenueReorderedEvent(
                revenueId: revenueId,
                newPosition: _revenueReorderedPosition(state, revenueId, moveUp),
              ),
            ),
      onRevenueDeletionRequested: isReadOnly
          ? null
          : (revenueId) => unawaited(_handleRevenueDeletionRequested(context, revenueId)),
      onShareCreationRequested: isReadOnly
          ? null
          : () => unawaited(_handleShareCreationRequested(context, state)),
      onShareSelected: (shareId) => bloc.add(OcptBudgetShareSelectedEvent(shareId: shareId)),
      onShareEditRequested: isReadOnly
          ? null
          : (share) => unawaited(_handleShareEditRequested(context, state, share)),
      onSharePayoutRequested: isReadOnly
          ? null
          : (share) => unawaited(_handleSharePayoutRequested(context, state, share)),
      onShareReorderRequested: isReadOnly
          ? null
          : (shareId, {required moveUp}) => bloc.add(
              OcptBudgetShareReorderedEvent(
                shareId: shareId,
                newPosition: _shareReorderedPosition(state, shareId, moveUp),
              ),
            ),
      onShareDeletionRequested: isReadOnly
          ? null
          : (shareId) => unawaited(_handleShareDeletionRequested(context, shareId)),
      onRepaymentRequested: isReadOnly
          ? null
          : (line) => unawaited(_handleRepaymentRequested(context, state, line)),
    );
  }

  /// Opens the entry dialog pre-filled to repay [line]'s own contributor (today's date, their own
  /// wording, as a debit, for whatever is still owed them, the resource already named), then
  /// dispatches the creation if the user confirmed it.
  ///
  /// **The card that says what is owed is the card that offers to pay it.** Every other figure in
  /// this mode already had the gesture that produces it within reach of where it is read; this one
  /// alone could only be watched. It is the same facilitator `Record a receipt` and `Record a
  /// payout` already are, pointing the other way.
  ///
  /// A contributor whose contributions are spread over several resources is repaid against the
  /// **first one still owed**: the card groups them into one debt on purpose, and asking which of
  /// three 100 € loans a 100 € repayment settles is a question nobody has an answer to.
  Future<void> _handleRepaymentRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetRepaymentLine line,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final now = DateTime.now();

    final resource = state.resources
        .where(
          (resource) =>
              resource.isReimbursable &&
              (line.personId == null
                  ? resource.personId == null && resource.label == line.label
                  : resource.personId == line.personId),
        )
        .firstOrNull;
    if (resource == null) {
      return;
    }

    final person = line.personId == null
        ? null
        : state.people.where((person) => person.id == line.personId).firstOrNull;
    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(now.year, now.month, now.day),
      label: person?.displayName ?? line.label,
      posteId: null,
      resourceId: resource.id,
      revenueId: null,
      shareId: null,
      isDebit: true,
      amountCents: line.outstandingCents,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    final fields = await OcptBudgetEntryDialog.show(
      context,
      existing: null,
      prefill: prefill,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryCreationConfirmedEvent(fields: fields));
  }

  /// The 0-based position revenue [revenueId] moves to when its row's own `⋮` menu `▲`/`▼` entry
  /// is clicked — mirrors `_posteReorderedPosition`.
  int _revenueReorderedPosition(OcptBudgetState state, String revenueId, bool moveUp) {
    final currentIndex = state.revenues.indexWhere((revenue) => revenue.id == revenueId);
    if (currentIndex < 0) {
      return 0;
    }

    return moveUp ? currentIndex - 1 : currentIndex + 1;
  }

  /// Opens the revenue dialog with nothing pre-filled, then dispatches the creation if the user
  /// confirmed it.
  Future<void> _handleRevenueCreationRequested(BuildContext context, OcptBudgetState state) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptBudgetRevenueDialog.show(
      context,
      existing: null,
      currencyCode: state.currencyCode,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetRevenueCreationConfirmedEvent(fields: fields));
  }

  /// Opens the revenue dialog pre-filled with [revenue], then dispatches the update if the user
  /// confirmed it.
  Future<void> _handleRevenueEditRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetRevenue revenue,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptBudgetRevenueDialog.show(
      context,
      existing: revenue,
      currencyCode: state.currencyCode,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetRevenueUpdateConfirmedEvent(revenueId: revenue.id, fields: fields));
  }

  /// Asks `OcptConfirmDialog` whether taking [revenueId] really is to be deleted, then dispatches
  /// the deletion if the user answered `Delete`.
  Future<void> _handleRevenueDeletionRequested(BuildContext context, String revenueId) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetDeleteRevenueConfirmTitle,
      message: tr.budgetDeleteRevenueConfirmMessage,
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetDeleteConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetRevenueDeletionConfirmedEvent(revenueId: revenueId));
  }

  /// Opens the entry dialog pre-filled from [revenue] (today's date, its own label, as a credit,
  /// for whatever is still outstanding against it, the taking already named), then dispatches the
  /// creation if the user confirmed it — mirrors `_handleResourceReceiptRequested`'s own gesture: a
  /// receipt can never exist as a figure with no movement behind it.
  Future<void> _handleRevenueReceiptRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetRevenue revenue,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final now = DateTime.now();
    final outstandingCents = ocptBudgetResourceOutstandingCents(
      amountCents: revenue.amountCents,
      receivedCents: state.receivedRevenueCentsOf(revenue.id),
    );
    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(now.year, now.month, now.day),
      label: revenue.label,
      posteId: null,
      resourceId: null,
      revenueId: revenue.id,
      shareId: null,
      isDebit: false,
      amountCents: outstandingCents < 0 ? 0 : outstandingCents,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    final fields = await OcptBudgetEntryDialog.show(
      context,
      existing: null,
      prefill: prefill,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryCreationConfirmedEvent(fields: fields));
  }

  /// The 0-based position share [shareId] moves to when its row's own `⋮` menu `▲`/`▼` entry is
  /// clicked — mirrors `_revenueReorderedPosition`.
  int _shareReorderedPosition(OcptBudgetState state, String shareId, bool moveUp) {
    final currentIndex = state.shares.indexWhere((share) => share.id == shareId);
    if (currentIndex < 0) {
      return 0;
    }

    return moveUp ? currentIndex - 1 : currentIndex + 1;
  }

  /// Opens the share dialog with nothing pre-filled, then dispatches the creation if the user
  /// confirmed it.
  Future<void> _handleShareCreationRequested(BuildContext context, OcptBudgetState state) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptBudgetShareDialog.show(context, existing: null, people: state.people);
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetShareCreationConfirmedEvent(fields: fields));
  }

  /// Opens the share dialog pre-filled with [share], then dispatches the update if the user
  /// confirmed it.
  Future<void> _handleShareEditRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetShare share,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptBudgetShareDialog.show(context, existing: share, people: state.people);
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetShareUpdateConfirmedEvent(shareId: share.id, fields: fields));
  }

  /// Asks `OcptConfirmDialog` whether share [shareId] really is to be deleted, then dispatches the
  /// deletion if the user answered `Delete`.
  Future<void> _handleShareDeletionRequested(BuildContext context, String shareId) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetDeleteShareConfirmTitle,
      message: tr.budgetDeleteShareConfirmMessage,
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetDeleteConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetShareDeletionConfirmedEvent(shareId: shareId));
  }

  /// Opens the entry dialog pre-filled from [share] (today's date, its own label, as a debit, for
  /// whatever the participant is still owed — its own due less what it has already been paid, the
  /// share already named), then dispatches the creation if the user confirmed it — mirrors
  /// `_handleRevenueReceiptRequested`'s own gesture: a payout can never exist as a figure with no
  /// movement behind it.
  Future<void> _handleSharePayoutRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetShare share,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final now = DateTime.now();
    final split = state.shareSplits.firstWhere(
      (split) => split.share.id == share.id,
      orElse: () => OcptBudgetShareSplit(
        share: share,
        dueCents: 0,
        paid: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
        reinvestedCents: 0,
      ),
    );
    final outstandingCents = ocptBudgetResourceOutstandingCents(
      amountCents: split.dueCents,
      receivedCents: split.paid.amountCents,
    );
    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(now.year, now.month, now.day),
      label: share.label,
      posteId: null,
      resourceId: null,
      revenueId: null,
      shareId: share.id,
      isDebit: true,
      amountCents: outstandingCents < 0 ? 0 : outstandingCents,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    final fields = await OcptBudgetEntryDialog.show(
      context,
      existing: null,
      prefill: prefill,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryCreationConfirmedEvent(fields: fields));
  }

  /// Promotes quote line [lineId] into a commitment: opens `OcptBudgetCommitmentDialog` seeded
  /// from the line, and dispatches the creation naming the line it came from.
  ///
  /// **A promotion, not a move.** The line stays in the quote, because comparing the estimate with
  /// what is actually owed is the whole use of having both — and nothing is counted twice either,
  /// the poste's `Quote` column reading its lines and its `Committed` column reading commitments.
  ///
  /// Everything a quote line holds is carried across; what is left to say is the two things a line
  /// has no room for, and which are exactly what make a debt a debt: who is owed, and when.
  Future<void> _handleLineCommitRequested(
    BuildContext context,
    OcptBudgetState state,
    String lineId,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();

    final poste = state.postes
        .where((poste) => poste.lines.any((line) => line.id == lineId))
        .firstOrNull;
    final line = poste?.lines.where((line) => line.id == lineId).firstOrNull;
    if (poste == null || line == null) {
      return;
    }

    final fields = await OcptBudgetCommitmentDialog.show(
      context,
      existing: null,
      prefill: OcptBudgetCommitmentFormFields(
        dueDate: null,
        label: line.label,
        posteId: poste.id,
        amountCents: ocptBudgetLineTotalCents(line),
        isTaxInclusive: line.unitPrice.isTaxInclusive,
        vatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
        status: OcptBudgetCommitmentStatus.quoteAccepted,
      ),
      postes: state.postes,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetCommitmentCreationConfirmedEvent(fields: fields, lineId: lineId));
  }

  /// Asks, through `OcptConfirmDialog`, before undoing line [lineId]'s own promotion — which
  /// deletes the commitment it produced, and leaves the quote line itself alone.
  Future<void> _handleLineUncommitRequested(
    BuildContext context,
    OcptBudgetState state,
    String lineId,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);

    final commitment = state.commitments
        .where((commitment) => commitment.lineId == lineId && !commitment.isSettled)
        .firstOrNull;
    if (commitment == null) {
      return;
    }

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetLineUncommitAction,
      message: tr.budgetLineUncommitConfirmMessage(
        commitment.label.isEmpty ? tr.budgetPosteUnnamed : commitment.label,
      ),
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetLineUncommitAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetCommitmentDeletionConfirmedEvent(commitmentId: commitment.id));
  }

  /// Asks `OcptConfirmDialog` whether quote line [lineId] really is to be deleted, then dispatches
  /// the deletion if the user answered `Delete`.
  Future<void> _handleLineDeletionRequested(BuildContext context, String lineId) async {
    final bloc = context.read<OcptBudgetBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.budgetDeleteLineConfirmTitle,
      message: tr.budgetDeleteLineConfirmMessage,
      cancelLabel: tr.budgetDeleteCancelAction,
      confirmLabel: tr.budgetDeleteConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetLineDeletionConfirmedEvent(lineId: lineId));
  }

  /// Builds the right dock, or null while it's closed.
  ///
  /// **The `Inspector` tab is offered only where there is something to inspect**
  /// (`ocptBudgetHasInspector`). Where it is not, a stored `Inspector` preference draws `Help`
  /// instead — and is **not overwritten**, so a reader who left the quote on the inspector comes
  /// back to it rather than to whatever the régie happened to show them.
  Widget? _buildRightDock(BuildContext context, OcptBudgetState state) {
    final storedTab = state.rightDockTab;
    if (storedTab == null) {
      return null;
    }

    final availableTabs = [
      for (final tab in OcptBudgetRightDockTab.values)
        if (tab != OcptBudgetRightDockTab.inspector ||
            ocptBudgetHasInspector(
              document: state.document,
              reading: state.reading,
              subPage: state.subPage,
            ))
          tab,
    ];
    final rightDockTab = availableTabs.contains(storedTab)
        ? storedTab
        : OcptBudgetRightDockTab.help;

    return OcptBudgetRightDock(
      activeTab: rightDockTab,
      availableTabs: availableTabs,
      inspectorChild: _buildInspector(context, state),
      versionsChild: _buildVersionsPanel(context, state),
      helpChild: _buildHelp(context, state),
      onTabSelected: (tab) =>
          context.read<OcptBudgetBloc>().add(OcptBudgetRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptBudgetBloc>().add(const OcptBudgetRightDockClosedEvent()),
    );
  }

  /// Builds the `Help` tab's own content — never withheld under a preview, since it writes
  /// nothing (`OcptBudgetHelp`'s own doc comment).
  Widget _buildHelp(BuildContext context, OcptBudgetState state) => OcptBudgetHelp(
    document: state.document,
    reading: state.reading,
    subPage: state.subPage,
    isSimplified: state.isSimplified,
  );

  /// Builds the `Inspector` tab's own content.
  ///
  /// The selected poste's own related entries are read out of [OcptBudgetState.entries] here,
  /// rather than in the widget itself: filtered down to the selected poste's own id and handed to
  /// [OcptBudgetPosteInspector] in reverse — [OcptBudgetState.entries] is chronological (the
  /// journal's own order), so reversing it once here is what puts the newest entry at the top of
  /// the inspector's own list, which never reorders what it is given.
  Widget _buildInspector(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final selectedPoste = state.selectedPoste;
    final relatedEntries = selectedPoste == null
        ? const <OcptBudgetEntry>[]
        : [
            for (final entry in state.entries.reversed)
              if (entry.posteId == selectedPoste.id) entry,
          ];
    final elementNameByElementId = {
      for (final element in state.elements) element.id: element.name,
    };

    return OcptBudgetPosteInspector(
      poste: selectedPoste,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      paidCents: selectedPoste == null ? 0 : state.paidCentsOf(selectedPoste.id),
      committedCents: selectedPoste == null ? 0 : state.committedCentsOf(selectedPoste.id),
      entries: relatedEntries,
      expandedLineId: state.expandedLineId,
      isReadOnly: isReadOnly,
      fieldValueOf: state.fieldValueOf,
      onFieldChanged: isReadOnly
          ? null
          : (targetId, field, rawValue) => bloc.add(
              OcptBudgetFieldChangedEvent(targetId: targetId, field: field, rawValue: rawValue),
            ),
      onPosteEstimateToCompleteDerivedRequested: isReadOnly
          ? null
          : (posteId) =>
                bloc.add(OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent(posteId: posteId)),
      onLineExpanded: (lineId) => bloc.add(OcptBudgetLineExpandedEvent(lineId: lineId)),
      onLineTaxInclusiveChanged: isReadOnly
          ? null
          : (lineId, {required isTaxInclusive}) => bloc.add(
              OcptBudgetLineTaxInclusiveChangedEvent(lineId: lineId, isTaxInclusive: isTaxInclusive),
            ),
      onLineVatRateInheritedRequested: isReadOnly
          ? null
          : (lineId) => bloc.add(OcptBudgetLineVatRateInheritedRequestedEvent(lineId: lineId)),
      commitmentSettledByLineId: {
        for (final commitment in state.commitments)
          if (commitment.lineId case final lineId?) lineId: commitment.isSettled,
      },
      onLineCommitRequested: isReadOnly
          ? null
          : (lineId) => unawaited(_handleLineCommitRequested(context, state, lineId)),
      onLineShowCommitmentRequested: (_) => context.read<OcptBudgetBloc>().add(
        const OcptBudgetSubPageSelectedEvent(subPage: OcptBudgetSubPage.committedSpending),
      ),
      onLineUncommitRequested: isReadOnly
          ? null
          : (lineId) => unawaited(_handleLineUncommitRequested(context, state, lineId)),
      onLineDeletionRequested: isReadOnly
          ? null
          : (lineId) => unawaited(_handleLineDeletionRequested(context, lineId)),
      onLineCreationRequested: isReadOnly || selectedPoste == null
          ? null
          : () => bloc.add(OcptBudgetLineCreatedEvent(posteId: selectedPoste.id)),
      onLineFromElementRequested: isReadOnly || selectedPoste == null
          ? null
          : () => unawaited(_handleLineFromElementRequested(context, state, selectedPoste.id)),
      elementNameByElementId: elementNameByElementId,
    );
  }

  /// Opens `OcptBudgetElementPickerDialog` over `OcptBudgetState.unpricedElements`, then dispatches
  /// the creation if the user picked one — mirrors `_handleEntryCreationRequested`'s own shape.
  Future<void> _handleLineFromElementRequested(
    BuildContext context,
    OcptBudgetState state,
    String posteId,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final element = await OcptBudgetElementPickerDialog.show(
      context,
      elements: state.unpricedElements,
      currencyCode: state.currencyCode,
    );
    if (element == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetLineCreatedFromElementEvent(posteId: posteId, elementId: element.id));
  }

  /// Builds the band naming the version being previewed, or null while the working copy is on
  /// screen. Mirrors `OcptScheduleMode._buildReadOnlyBanner`.
  Widget? _buildReadOnlyBanner(BuildContext context, OcptBudgetState state) {
    final previewedVersion = state.previewedVersion;
    if (previewedVersion == null) {
      return null;
    }

    final tr = Tr.of(context);

    return OcptWorkspaceReadOnlyBanner(
      version: previewedVersion,
      onForkRequested: () => context.read<OcptBudgetBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: previewedVersion.id,
          safetyVersionName: tr.projectVersionRestoreSafetyName(previewedVersion.name),
        ),
      ),
      onExitPreview: () =>
          context.read<OcptBudgetBloc>().add(const OcptProjectVersionPreviewExitRequestedEvent()),
    );
  }

  /// Builds the right dock's `Versions` tab, wired exactly as every other mode's own dock.
  Widget _buildVersionsPanel(BuildContext context, OcptBudgetState state) => OcptProjectVersionsPanel(
    versions: state.projectVersions,
    previewedVersionId: state.previewedVersionId,
    workingCopy: state.workingCopy,
    versionPendingDeletionId: state.versionPendingDeletionId,
    versionPendingRestoreId: state.versionPendingRestoreId,
    versionPendingRenameId: state.versionPendingRenameId,
    onCreateRequested: () => _requestVersionCreation(context),
    onPreviewRequested: (versionId) => context.read<OcptBudgetBloc>().add(
      OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
    ),
    onPreviewExitRequested: () =>
        context.read<OcptBudgetBloc>().add(const OcptProjectVersionPreviewExitRequestedEvent()),
    onRestoreRequested: (versionId) => context.read<OcptBudgetBloc>().add(
      OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
    ),
    onRestoreCancelled: () =>
        context.read<OcptBudgetBloc>().add(const OcptProjectVersionRestoreCancelledEvent()),
    onRestoreConfirmed: (version) => context.read<OcptBudgetBloc>().add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: version.id,
        safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
      ),
    ),
    onDeleteRequested: (versionId) => context.read<OcptBudgetBloc>().add(
      OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
    ),
    onDeleteCancelled: () =>
        context.read<OcptBudgetBloc>().add(const OcptProjectVersionDeletionCancelledEvent()),
    onDeleteConfirmed: (versionId) => context.read<OcptBudgetBloc>().add(
      OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
    ),
    onRenameRequested: (versionId) => context.read<OcptBudgetBloc>().add(
      OcptProjectVersionRenameRequestedEvent(versionId: versionId),
    ),
    onRenameCancelled: () =>
        context.read<OcptBudgetBloc>().add(const OcptProjectVersionRenameCancelledEvent()),
    onRenameConfirmed: (versionId, name, note) => context.read<OcptBudgetBloc>().add(
      OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
    ),
  );

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }

  /// Applies bloc-driven effects onto the page: the live dock fraction, the transient version
  /// notice SnackBar, the missing-files question and the transient package notice SnackBar —
  /// mirrors `OcptScheduleMode._onStateChanged`. There is no left fraction to sync: the controller's
  /// own left one stays at its unused default.
  void _onStateChanged(BuildContext context, OcptBudgetState state) {
    _dockLayoutController.syncFromPersisted(
      leftFraction: OcptWorkspaceDock.leftDefaultFraction,
      rightFraction: state.rightDockFraction,
    );

    final versionNotice = state.projectVersionNotice;
    if (versionNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ocptProjectVersionNoticeMessage(context, versionNotice))));
      context.read<OcptBudgetBloc>().add(const OcptProjectVersionNoticeDismissedEvent());
    }

    final packagePendingExport = state.projectPackagePendingExport;
    if (packagePendingExport != null) {
      context.read<OcptBudgetBloc>().add(const OcptProjectPackageMissingFilesAskDismissedEvent());
      unawaited(_askAboutMissingPackagedFiles(context, packagePendingExport));
    }

    final packageNotice = state.projectPackageNotice;
    if (packageNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ocptProjectPackageNoticeMessage(context, packageNotice))));
      context.read<OcptBudgetBloc>().add(const OcptProjectPackageNoticeDismissedEvent());
    }

    final ioNotice = state.ioNotice;
    if (ioNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
      context.read<OcptBudgetBloc>().add(const OcptBudgetIoNoticeDismissedEvent());
    }
  }

  /// The SnackBar text for [notice] — mirrors `OcptScheduleMode._ioNoticeMessage`.
  String _ioNoticeMessage(BuildContext context, OcptBudgetIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptBudgetIoNoticeKind.fileExportSucceeded => tr.budgetExportFileSuccessMessage(
        notice.path ?? "",
      ),
      OcptBudgetIoNoticeKind.exportFailed => tr.budgetExportError,
    };
  }
}
