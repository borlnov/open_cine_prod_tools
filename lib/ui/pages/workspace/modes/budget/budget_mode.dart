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
import 'package:open_cine_prod_tools/models/ocpt_budget_new_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_export_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_allowance_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_dashboard.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financial_report_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_plan_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_help.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_dialog.dart';
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
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_provision.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_reimbursements.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The budget production mode: four chips — `Tableau de bord`, `Dépenses`, `Ressources`, `Outils`
/// — and `Inspector`, `Versions` and `Help` in the right dock. **No left dock**: the mockup draws
/// none, and the poste list that used to live there is retired with it (its filtering gesture
/// moved to the expenses table's own row menu).
///
/// **No episode selector**: one budget serves the whole production (ADR 0019), its catalogue
/// naming no episode at all, exactly the schedule mode's own reason — not for want of a bloc.
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

/// The state of [_BudgetView]: owns the dock layout controller and keeps its right fraction in
/// sync with the one the bloc holds. **This mode carries no left dock at all**, so
/// [OcptWorkspaceDockLayoutController.leftFraction] is constructed once, at its own default, and
/// never synced afterwards — there is no divider to drag it from.
class _BudgetViewState extends State<_BudgetView> {
  /// The live source of truth for both dock fractions while a divider is being dragged. The left
  /// one is fixed at its own default for the mode's whole lifetime — see the class doc comment.
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
        // Only the right divider can ever report a drag here — the mode carries no left dock, so
        // `fractions.left` is always null (see the class doc comment).
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
  /// entry itself pays (`OcptBudgetEntry.commitmentId`), an entry naming none of them getting no key
  /// here at all. `OcptBudgetCashJournalXlsxExportService` resolves nothing of this itself (its own
  /// doc comment), which is what keeps it independent of `budget_revenues`/`budget_shares`.
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

  /// Builds the shell's `centre`: the header band, then whichever widget the current
  /// [OcptBudgetState.view] names — see [_buildRoute].
  Widget _buildCentre(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    // Read once, here: null is "a previewed version takes it away" — the same label and gesture on
    // every route now, so there is nothing left for a route to withhold on its own account.
    // `OcptBudgetHeader` draws nothing at all when it is null — withheld whole, never disabled, the
    // standing rule.
    final newButton = state.isPreviewingVersion ? null : _newButtonOf(context, state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcptBudgetHeader(
          view: state.view,
          onViewSelected: (view) => bloc.add(OcptBudgetViewSelectedEvent(view: view)),
          toolsView: state.toolsView,
          onToolsViewSelected: (toolsView) =>
              bloc.add(OcptBudgetToolsViewSelectedEvent(toolsView: toolsView)),
          isSimplified: state.isSimplified,
          onSimplifiedChanged: (value) =>
              bloc.add(OcptBudgetSimplifiedToggledEvent(isSimplified: value)),
          taxBasis: state.taxBasis,
          onTaxBasisChanged: (basis) => bloc.add(OcptBudgetTaxBasisChangedEvent(basis: basis)),
          postes: state.postes,
          filterPosteId: state.filterPosteId,
          onPosteFilterCleared: () => bloc.add(const OcptBudgetPosteFilterSelectedEvent(posteId: null)),
          alertCount: state.alerts.length,
          captureLabel: newButton?.$1,
          onCaptureRequested: newButton?.$2,
        ),
        const SizedBox(height: 12),
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

  /// The header band's own trailing button, `+ Nouveau` — offered on all five routes now, including
  /// [OcptBudgetView.dashboard] and `tools › cashFlow`, which carried none before this milestone.
  /// Opens the capture wizard's own step 1, the current route's own document promoted to the top of
  /// the list with its first answer pre-selected (`_promotedGestureFamilyOf`) — never on
  /// [OcptBudgetView.dashboard], which works on no single document, so pre-answering for it would be
  /// a guess: nothing is selected there, and `Continuer` stays withheld until a card is picked, the
  /// very rule the wizard's own step 1 already applies whenever nothing is known yet.
  (String, VoidCallback) _newButtonOf(BuildContext context, OcptBudgetState state) {
    final tr = Tr.of(context);
    return (tr.budgetHeaderNewAction, () => unawaited(_handleNewRequested(context, state)));
  }

  /// Which [OcptBudgetGestureFamily] the current route promotes to the top of step 1 — the group
  /// whose document the route works on — or null for [OcptBudgetView.dashboard], which works on no
  /// single document.
  OcptBudgetGestureFamily? _promotedGestureFamilyOf(OcptBudgetState state) =>
      switch ((state.view, state.toolsView)) {
        (OcptBudgetView.expenses, _) => OcptBudgetGestureFamily.quote,
        (OcptBudgetView.resources, _) => OcptBudgetGestureFamily.financingPlan,
        (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => OcptBudgetGestureFamily.cashMovement,
        (OcptBudgetView.tools, OcptBudgetToolsView.regie) => OcptBudgetGestureFamily.allowances,
        (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => OcptBudgetGestureFamily.revenueSharing,
        (OcptBudgetView.dashboard, _) => null,
      };

  /// [family]'s own first answer, in [OcptBudgetGesture]'s own declared order — the promoted
  /// group's own first card, which arrives pre-selected so the frequent gesture is one click.
  OcptBudgetGesture _firstGestureOf(OcptBudgetGestureFamily family) =>
      OcptBudgetGesture.values.firstWhere((gesture) => ocptBudgetGestureFamilyOf(gesture) == family);

  /// Which gestures the `+ New` wizard offers when opened from the current route — a semantic filter
  /// by the direction money moves (`ocptBudgetGestureFlowsOf`), **transverse to the families**: the
  /// expenses route offers everything that spends, the resources route everything that brings money
  /// in, the drawer's cash-flow page its own movements, régie its defrayal. Sharing offers its own
  /// participants **and `Le film a rapporté de l'argent`** (`recordTakingReceipt`): the split is of
  /// what the film earns, so recording a taking belongs where that money is divided up.
  /// Null for the dashboard, which works on no document and filters nothing. The reader lifts it
  /// from inside the wizard (`Show all`).
  Set<OcptBudgetGesture>? _wizardGesturesForView(OcptBudgetState state) {
    Set<OcptBudgetGesture> spending(OcptBudgetGestureFlow flow) => {
      for (final gesture in OcptBudgetGesture.values)
        if (ocptBudgetGestureFlowsOf(gesture).contains(flow)) gesture,
    };
    Set<OcptBudgetGesture> ofFamily(OcptBudgetGestureFamily family) => {
      for (final gesture in OcptBudgetGesture.values)
        if (ocptBudgetGestureFamilyOf(gesture) == family) gesture,
    };

    return switch ((state.view, state.toolsView)) {
      (OcptBudgetView.dashboard, _) => null,
      (OcptBudgetView.expenses, _) => spending(OcptBudgetGestureFlow.spends),
      (OcptBudgetView.resources, _) => spending(OcptBudgetGestureFlow.brings),
      (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) =>
        ofFamily(OcptBudgetGestureFamily.cashMovement),
      (OcptBudgetView.tools, OcptBudgetToolsView.regie) =>
        ofFamily(OcptBudgetGestureFamily.allowances),
      (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => {
        ...ofFamily(OcptBudgetGestureFamily.revenueSharing),
        OcptBudgetGesture.recordTakingReceipt,
      },
    };
  }

  /// The word the wizard's own filter tag names the current filter by — the route's own header
  /// segment label. Read only where [_wizardGesturesForView] is non-null.
  String _wizardFilterLabelOf(Tr tr, OcptBudgetState state) => switch ((state.view, state.toolsView)) {
    (OcptBudgetView.expenses, _) => tr.budgetHeaderExpensesSegmentLabel,
    (OcptBudgetView.resources, _) => tr.budgetHeaderResourcesSegmentLabel,
    (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => tr.budgetHeaderCashFlowSegmentLabel,
    (OcptBudgetView.tools, OcptBudgetToolsView.regie) => tr.budgetHeaderRegieSegmentLabel,
    (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => tr.budgetHeaderSharingSegmentLabel,
    (OcptBudgetView.dashboard, _) => "",
  };

  /// Opens the capture wizard fresh — no step already answered — promoted and pre-selected per the
  /// current route, exactly as [_newButtonOf]'s own doc comment describes. Dispatches whatever
  /// [_handleNewOutcome] says once the wizard closes with something.
  Future<void> _handleNewRequested(BuildContext context, OcptBudgetState state) async {
    final bloc = context.read<OcptBudgetBloc>();
    final promotedFamily = _promotedGestureFamilyOf(state);
    final allowedGestures = _wizardGesturesForView(state);
    final outcome = await OcptBudgetNewDialog.show(
      context,
      promotedFamily: promotedFamily,
      allowedGestures: allowedGestures,
      filterLabel: allowedGestures == null ? null : _wizardFilterLabelOf(Tr.of(context), state),
      initialGesture: promotedFamily == null ? null : _firstGestureOf(promotedFamily),
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      people: state.people,
      unpricedElements: state.unpricedElements,
      commitments: state.commitments,
      entries: state.entries,
      allowances: state.allowances,
      mileageRates: state.mileageRates,
      receivedByResourceId: state.receivedByResourceId,
      receivedByRevenueId: state.receivedByRevenueId,
      reimbursedByPersonId: state.reimbursedByPersonId,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (outcome == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    _handleNewOutcome(bloc, state, outcome);
  }

  /// Turns a fresh [OcptBudgetNewOutcome] into a write — every door that **creates** something
  /// through the wizard converges here, one variant per [OcptBudgetGesture], each dispatching the
  /// event that already exists for it. Nothing here writes to the project itself.
  ///
  /// [OcptBudgetEntryWizardResult]'s own [OcptBudgetEntryWizardResult.acceptedSuggestion] null: an
  /// ordinary [OcptBudgetEntryCreationConfirmedEvent]. Non-null: [_handleEntryWizardSuggestionAccepted]
  /// turns its own draft and the accepted suggestion into whichever of the two events its own kind
  /// calls for — see that method's own doc comment for the mapping, carried over from the capture
  /// band the wizard replaced in an earlier milestone.
  void _handleNewOutcome(OcptBudgetBloc bloc, OcptBudgetState state, OcptBudgetNewOutcome outcome) {
    switch (outcome) {
      case OcptBudgetEntryWizardResult(:final fields, :final acceptedSuggestion):
        if (acceptedSuggestion == null) {
          bloc.add(OcptBudgetEntryCreationConfirmedEvent(fields: fields));
        } else {
          _handleEntryWizardSuggestionAccepted(bloc, state, acceptedSuggestion, fields);
        }
      case OcptBudgetNewLineOutcome(:final posteId, :final fields):
        bloc.add(OcptBudgetLineCreatedEvent(posteId: posteId, fields: fields));
      case OcptBudgetNewLinesFromBreakdownOutcome(:final lines):
        for (final line in lines) {
          bloc.add(
            OcptBudgetLineCreatedFromElementEvent(
              posteId: line.posteId,
              elementId: line.elementId,
              quantityMilli: line.quantityMilli,
            ),
          );
        }
      case OcptBudgetNewCommitmentOutcome(:final fields, :final lineId):
        bloc.add(OcptBudgetCommitmentCreationConfirmedEvent(fields: fields, lineId: lineId));
      case OcptBudgetNewResourceOutcome(:final fields):
        bloc.add(OcptBudgetResourceCreationConfirmedEvent(fields: fields));
      case OcptBudgetNewRevenueOutcome(:final fields):
        bloc.add(OcptBudgetRevenueCreationConfirmedEvent(fields: fields));
      case OcptBudgetNewAllowanceOutcome(:final fields):
        bloc.add(OcptBudgetAllowanceCreationConfirmedEvent(fields: fields));
      case OcptBudgetNewShareOutcome(:final fields):
        bloc.add(OcptBudgetShareCreationConfirmedEvent(fields: fields));
    }
  }

  /// Opens the capture wizard's own step 3 directly, on [gesture], pre-filled with [prefill] — steps
  /// 1 and 2 both already answered — then dispatches whatever [_handleNewOutcome] says once it
  /// closes with something. The one shared shape behind every contextual shortcut that pre-fills an
  /// ordinary movement: a resource's or a taking's own `Receive`, a participant's own payout, a
  /// contribution's own repayment — every one of them an [OcptBudgetEntryCreationConfirmedEvent] with
  /// nothing further to decide, unlike [_handleCommitmentSettleRequested], which dispatches a
  /// settlement instead of a plain creation and so builds its own call to `OcptBudgetNewDialog.show`
  /// rather than sharing this one.
  ///
  /// **The lettrage strip is withheld here** (`offersLettrage: false`), exactly as
  /// [_handleCommitmentSettleRequested] and [_handleLinePayDirectlyRequested] withhold it: the
  /// movement already belongs to the resource, taking, person or share [prefill] names, so every
  /// candidate the strip could rank is a *different* object, and offering to reroute onto one only
  /// invites a rapprochement the reader never meant. The strip stays on in the generic `+` capture
  /// alone, where the movement is free-typed.
  Future<void> _handleWizardEntryShortcut(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetGesture gesture,
    OcptBudgetEntryFormFields prefill,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final outcome = await OcptBudgetNewDialog.show(
      context,
      initialGesture: gesture,
      entryPrefill: prefill,
      offersLettrage: false,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      people: state.people,
      unpricedElements: state.unpricedElements,
      commitments: state.commitments,
      entries: state.entries,
      allowances: state.allowances,
      mileageRates: state.mileageRates,
      receivedByResourceId: state.receivedByResourceId,
      receivedByRevenueId: state.receivedByRevenueId,
      reimbursedByPersonId: state.reimbursedByPersonId,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (outcome == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    _handleNewOutcome(bloc, state, outcome);
  }

  /// `C'est ça`: turns the wizard's own accepted [suggestion] and its plain [fields] into the write
  /// its own kind calls for. **This mapping is carried over unchanged from the quick-capture card
  /// this wizard replaces**, whose own version of it first argued every line below: read it before
  /// touching it.
  ///
  /// **The commitment case is the only one adding fields the draft never carried**
  /// ([OcptBudgetCommitment.posteId], its own tax basis and its own VAT rate) — mirrors
  /// [_handleCommitmentSettleRequested]'s own prefill. The other three keep every one of [fields]'s
  /// own values, only naming the matched row (`resourceId`/`revenueId`) or, for a defrayal, adopting
  /// its own [OcptBudgetMatchSuggestion.label] in place of the draft's — the one asymmetry that
  /// `OcptBudgetEntryDialog._headlineOf`'s own doc comment argues for: nothing in the schema lets a
  /// defrayal be marked settled, so the label is the only trace this movement can leave of it.
  void _handleEntryWizardSuggestionAccepted(
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

  /// Builds whichever widget [OcptBudgetState.view] names — [OcptBudgetState.toolsView] deciding
  /// which of the tools drawer's own three pages draws while [OcptBudgetView.tools] is on screen.
  /// Every one of these is the very widget the retired seven-chip header used to switch over:
  /// only the switch's own shape moved, save the cash journal, which is now read-only in its new
  /// home (see [_buildCashJournal]'s own doc comment).
  Widget _buildRoute(BuildContext context, OcptBudgetState state) => switch (state.view) {
    OcptBudgetView.dashboard => _buildDashboard(context, state),
    OcptBudgetView.expenses => _buildCostTracking(context, state),
    OcptBudgetView.resources => _buildFinancing(context, state),
    OcptBudgetView.tools => switch (state.toolsView) {
      OcptBudgetToolsView.cashFlow => _buildCashJournal(context, state),
      OcptBudgetToolsView.regie => _buildRegie(context, state),
      OcptBudgetToolsView.sharing => _buildSharing(context, state),
    },
  };

  /// Opens the resources mode's own elements tab — `OcptBudgetFeedCard`'s own breakdown row,
  /// wherever the card is drawn.
  void _handleBreakdownFeedRequested(BuildContext context) => context.read<OcptWorkspaceBloc>().add(
    const OcptWorkspaceModeSelectedEvent(
      mode: OcptWorkspaceMode.resources,
      revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.elements),
    ),
  );

  /// Opens the schedule mode — `OcptBudgetFeedCard`'s own schedule row, wherever the card is drawn.
  void _handleScheduleFeedRequested(BuildContext context) => context.read<OcptWorkspaceBloc>().add(
    const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.schedule),
  );

  /// Opens the catering-and-travel pass — `OcptBudgetFeedCard`'s own catering row, drawn only where
  /// that pass is not itself already on screen. Sets **both** [OcptBudgetView.tools] and
  /// [OcptBudgetToolsView.regie]: the first opens the drawer, the second picks which of its own
  /// pages is on screen the moment it does, and neither event clears the other's own field.
  void _handleCateringFeedRequested(OcptBudgetBloc bloc) {
    bloc
      ..add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.tools))
      ..add(const OcptBudgetToolsViewSelectedEvent(toolsView: OcptBudgetToolsView.regie));
  }

  /// Builds the dashboard: the summary of the other pages, opened by default.
  ///
  /// **Every callback it needs is one this file already has a handler for** — a dashboard alert
  /// row's own poste-over-quote action reuses [_handleDashboardPosteOpened], which selects the
  /// poste and switches to [OcptBudgetView.expenses] in one gesture (see
  /// `OcptBudgetDashboard.onPosteOpened`'s own doc comment for why a plain selection would not be
  /// enough); the cash-negative alert's own row reuses [_handleCashAlertActionRequested], opening
  /// the tools drawer's own `Flux de trésorerie` page — the very reading it answers.
  Widget _buildDashboard(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();

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
      onPosteOpened: (posteId) => _handleDashboardPosteOpened(bloc, posteId),
      onCashAlertActionRequested: () => _handleCashAlertActionRequested(bloc),
    );
  }

  /// A dashboard alert row is a link to where the poste is worked on, not a selection of its own —
  /// see `OcptBudgetDashboard.onPosteOpened`'s own doc comment. Selects [posteId] and switches to
  /// [OcptBudgetView.expenses] in the same gesture.
  void _handleDashboardPosteOpened(OcptBudgetBloc bloc, String posteId) {
    bloc
      ..add(OcptBudgetPosteSelectedEvent(posteId: posteId))
      ..add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.expenses));
  }

  /// The cash-projection alert's own action: the cash question it raises is exactly what the tools
  /// drawer's own `Flux de trésorerie` page answers, so it opens straight onto it, the view and the
  /// tools view both set in one gesture, mirroring [_handleDashboardPosteOpened]'s own shape.
  void _handleCashAlertActionRequested(OcptBudgetBloc bloc) {
    bloc
      ..add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.tools))
      ..add(const OcptBudgetToolsViewSelectedEvent(toolsView: OcptBudgetToolsView.cashFlow));
  }

  /// Builds the cost-tracking table.
  Widget _buildCostTracking(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final elementLinkCounts = state.elementLinkCounts;

    return OcptBudgetCostTracking(
      // **The filter is applied here, not inside the view.** Every one of these widgets draws
      // exactly the rows it is handed and totals exactly those, so narrowing the list is the whole
      // of it: a filtered table's own `Total` reads the total of what is on screen, which is the
      // only honest thing it can say. The commitments and entries the tree reads its own sub-rows
      // from are handed in whole — a poste already outside the filter draws no row at all, so its
      // own commitments and entries never reach the screen either.
      postes: _filteredPostesOf(state),
      commitments: state.commitments,
      entries: state.entries,
      selection: state.selection,
      expandedNodeIds: state.expandedNodeIds,
      isSimplified: state.isSimplified,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      paidByPosteId: state.paidByPosteId,
      committedCentsOf: state.committedCentsOf,
      offQuoteTotal: state.offQuotePaidTotal,
      breakdownPricedElementCount: elementLinkCounts.pricedCount,
      breakdownUnpricedElementCount: elementLinkCounts.unpricedCount,
      shootingDayCount: state.regieDays.length,
      mealCount: state.regieTotals.mealCount,
      buffetCount: state.regieTotals.buffetCount,
      isReadOnly: isReadOnly,
      onPosteSelected: (posteId) => bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId)),
      onLineSelected: (lineId) => bloc.add(OcptBudgetLineSelectedEvent(lineId: lineId)),
      onCommitmentSelected: (commitmentId) =>
          bloc.add(OcptBudgetCommitmentSelectedEvent(commitmentId: commitmentId)),
      onEntrySelected: (entryId) => bloc.add(OcptBudgetEntrySelectedEvent(entryId: entryId)),
      onNodeExpansionToggled: (nodeId) =>
          bloc.add(OcptBudgetRowExpansionToggledEvent(nodeId: nodeId)),
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
      // Never withheld under a preview: it only ever reads the project — see
      // `OcptBudgetCostTracking.onPosteFilterRequested`'s own doc comment.
      onPosteFilterRequested: (posteId) => bloc.add(OcptBudgetPosteFilterSelectedEvent(posteId: posteId)),
      onCommitmentEditRequested: isReadOnly
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
      onEntryEditRequested: isReadOnly
          ? null
          : (entry) => unawaited(_handleEntryEditRequested(context, state, entry)),
      onEntryDeletionRequested: isReadOnly
          ? null
          : (entryId) => unawaited(_handleEntryDeletionRequested(context, entryId)),
      onBreakdownFeedRequested: () => _handleBreakdownFeedRequested(context),
      onScheduleFeedRequested: () => _handleScheduleFeedRequested(context),
      onCateringFeedRequested: () => _handleCateringFeedRequested(bloc),
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
  /// See `ocptBudgetViewHonoursPosteFilter` for which views read this and which say they cannot.
  List<OcptBudgetPoste> _filteredPostesOf(OcptBudgetState state) {
    final filterPosteId = state.filterPosteId;

    return filterPosteId == null
        ? state.postes
        : [
            for (final poste in state.postes)
              if (poste.id == filterPosteId) poste,
          ];
  }

  /// Builds the tools drawer's own `Flux de trésorerie` page — read-only, and honouring no poste
  /// filter at all, `OcptBudgetCashJournal`'s own class doc comment arguing why.
  Widget _buildCashJournal(BuildContext context, OcptBudgetState state) {
    final isReadOnly = state.isPreviewingVersion;
    final bloc = context.read<OcptBudgetBloc>();

    return OcptBudgetCashJournal(
      entries: state.entries,
      commitments: state.commitments,
      postes: state.postes,
      receiptsByEntryId: state.receiptsByEntryId,
      selection: state.selection,
      isSimplified: state.isSimplified,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      isReadOnly: isReadOnly,
      onEntrySelected: (entryId) => bloc.add(OcptBudgetEntrySelectedEvent(entryId: entryId)),
      onEntryEditRequested: isReadOnly
          ? null
          : (entry) => unawaited(_handleEntryEditRequested(context, state, entry)),
      onEntryDeletionRequested: isReadOnly
          ? null
          : (entryId) => unawaited(_handleEntryDeletionRequested(context, entryId)),
      // Never withheld under a preview: selecting only opens the right dock's own fiche, it writes
      // nothing.
      onCommitmentSelected: (commitmentId) =>
          bloc.add(OcptBudgetCommitmentSelectedEvent(commitmentId: commitmentId)),
      shareableCents: state.sharingPot.shareableCents,
      // Switching the drawer to the sharing page writes nothing, so it stands under a preview too.
      onOpenSharing: () =>
          bloc.add(const OcptBudgetToolsViewSelectedEvent(toolsView: OcptBudgetToolsView.sharing)),
    );
  }

  /// Opens `OcptBudgetEntryDialog` on [entry] — the one screen it has left, its nature inferred
  /// silently off whichever of the entry's own links is set — then dispatches the update if the
  /// user confirmed it.
  Future<void> _handleEntryEditRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetEntry entry,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
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
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptBudgetEntryUpdateConfirmedEvent(entryId: entry.id, fields: result));
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

  /// Opens the capture wizard's own step 3 directly, on [OcptBudgetGesture.recordExpense], pre-filled
  /// from [commitment] (today's date, its own label, poste, amount, tax basis and rate, as a debit)
  /// — steps 1 and 2 both already answered, exactly as `OcptBudgetEntryDialog`'s own prefill used to
  /// skip them — then dispatches the settlement if the user confirmed it — see
  /// `OcptBudgetCommitmentSettlementConfirmedEvent`'s own doc comment for the combined write this
  /// produces.
  Future<void> _handleCommitmentSettleRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetCommitment commitment,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final now = DateTime.now();
    // Offer what is still owed rather than the full commitment, expressed in the commitment's own
    // tax basis and rate so the payment entry carries the very VAT reading the commitment does. The
    // outstanding is read as a tax-inclusive cash figure, so it is scaled back into the commitment's
    // basis by the fraction it is of the commitment's own cash — the whole typed amount when nothing
    // has been paid, proportional once it has. A commitment whose cash cannot be read (unknown rate)
    // keeps its full typed amount; an overpaid one offers nothing.
    final commitmentCashCents = ocptBudgetCommitmentCashCentsOf(
      commitment,
      projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
    );
    final outstandingCashCents = ocptBudgetCommitmentOutstandingCentsOf(
      commitment,
      state.entries,
      projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
    );
    final int prefillAmountCents;
    if (commitmentCashCents == null || outstandingCashCents == null || commitmentCashCents <= 0) {
      prefillAmountCents = commitment.amount.amountCents;
    } else if (outstandingCashCents <= 0) {
      prefillAmountCents = 0;
    } else {
      prefillAmountCents =
          (commitment.amount.amountCents * outstandingCashCents / commitmentCashCents).round();
    }
    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(now.year, now.month, now.day),
      label: commitment.label,
      posteId: commitment.posteId,
      resourceId: null,
      revenueId: null,
      shareId: null,
      isDebit: true,
      amountCents: prefillAmountCents,
      isTaxInclusive: commitment.amount.isTaxInclusive,
      vatRateBasisPoints: commitment.amount.vatRateBasisPoints,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    final outcome = await OcptBudgetNewDialog.show(
      context,
      initialGesture: OcptBudgetGesture.recordExpense,
      entryPrefill: prefill,
      // The commitment being paid is explicitly designated, and the entry settles it below whatever
      // the reader does — so every lettrage candidate the strip could rank is a *different* object,
      // and offering to reroute the payment onto one only invites a rapprochement they never meant.
      // The strip stays on in the generic `+` capture, where the movement is free-typed.
      offersLettrage: false,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      people: state.people,
      unpricedElements: state.unpricedElements,
      commitments: state.commitments,
      entries: state.entries,
      allowances: state.allowances,
      mileageRates: state.mileageRates,
      receivedByResourceId: state.receivedByResourceId,
      receivedByRevenueId: state.receivedByRevenueId,
      reimbursedByPersonId: state.reimbursedByPersonId,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (outcome is! OcptBudgetEntryWizardResult) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    // With the strip withheld the wizard can accept no suggestion, so settling this very commitment
    // is the only outcome left — no `acceptedSuggestion` branch is reachable here.
    bloc.add(
      OcptBudgetCommitmentSettlementConfirmedEvent(
        commitmentId: commitment.id,
        fields: outcome.fields,
      ),
    );
  }

  /// Builds the resources view: the nesting tree of subsidies, contributions and takings, and its
  /// own coverage band. Every revenue callback — `_handleRevenueEditRequested`,
  /// `_handleRevenueReceiptRequested`, `_revenueReorderedPosition`,
  /// `_handleRevenueDeletionRequested` — is this tree's own, the sharing view having lost its own
  /// copy of the takings.
  Widget _buildFinancing(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetFinancing(
      resources: state.resources,
      revenues: state.revenues,
      entries: state.entries,
      postes: state.postes,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      receivedByResourceId: state.receivedByResourceId,
      receivedCentsOf: state.receivedCentsOf,
      receivedByRevenueId: state.receivedByRevenueId,
      currencyCode: state.currencyCode,
      selection: state.selection,
      expandedNodeIds: state.expandedNodeIds,
      isReadOnly: isReadOnly,
      onNodeExpansionToggled: (nodeId) => bloc.add(OcptBudgetRowExpansionToggledEvent(nodeId: nodeId)),
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
      onReceiptSelected: (receiptId) => bloc.add(OcptBudgetReceiptSelectedEvent(receiptId: receiptId)),
      onExpensesRequested: () =>
          bloc.add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.expenses)),
    );
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

  /// Opens the capture wizard's own step 3 directly, on [OcptBudgetGesture.recordFinancingReceipt],
  /// pre-filled from [resource] (today's date, its own label, as a credit, for whatever is still
  /// outstanding against it, the resource already named) — mirrors
  /// `_handleCommitmentSettleRequested`'s own gesture: see "A commitment settles by naming the entry
  /// that paid it" in `docs/architecture/budget.md` for the reading this mirrors, a receipt naming
  /// the resource that earned it instead of a commitment being paid.
  Future<void> _handleResourceReceiptRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetResource resource,
  ) async {
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

    await _handleWizardEntryShortcut(
      context,
      state,
      OcptBudgetGesture.recordFinancingReceipt,
      prefill,
    );
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
    final elementLinkCounts = state.elementLinkCounts;
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
      onNodeExpansionToggled: (nodeId) => bloc.add(OcptBudgetRowExpansionToggledEvent(nodeId: nodeId)),
      onScheduleOpenRequested: () => _handleScheduleFeedRequested(context),
      onBreakdownFeedRequested: () => _handleBreakdownFeedRequested(context),
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
      onPersonReimburseRequested: isReadOnly
          ? null
          : (personId) => unawaited(_handlePersonReimburseRequested(context, state, personId)),
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

  /// Opens the capture wizard's own step 3 directly, on [OcptBudgetGesture.reimbursePerson],
  /// pre-filled from [personId] (today's date, the person's own display name, as a debit, for
  /// whatever is still owed them, the person already named) — mirrors
  /// `_handleResourceReceiptRequested`'s own gesture: a reimbursement can never exist as a figure
  /// with no movement behind it.
  Future<void> _handlePersonReimburseRequested(
    BuildContext context,
    OcptBudgetState state,
    String personId,
  ) async {
    final person = state.people.where((row) => row.id == personId).firstOrNull;
    final now = DateTime.now();
    final advancedCents = ocptBudgetPersonAdvancedCents(personId, state.allowances);
    final reimbursedCents = state.reimbursedByPersonId[personId]?.amountCents ?? 0;
    final outstandingCents = ocptBudgetPersonOutstandingCents(
      advancedCents: advancedCents,
      reimbursedCents: reimbursedCents,
    );
    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(now.year, now.month, now.day),
      label: person?.displayName ?? "",
      posteId: null,
      resourceId: null,
      revenueId: null,
      shareId: null,
      personId: personId,
      isDebit: true,
      amountCents: outstandingCents < 0 ? 0 : outstandingCents,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    await _handleWizardEntryShortcut(context, state, OcptBudgetGesture.reimbursePerson, prefill);
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
      shares: state.shares,
      sharingPot: state.sharingPot,
      repaymentLines: state.repaymentLines,
      shareSplits: state.shareSplits,
      people: state.people,
      currencyCode: state.currencyCode,
      selectedShareId: state.selectedShareId,
      isReadOnly: isReadOnly,
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

    await _handleWizardEntryShortcut(context, state, OcptBudgetGesture.repayContribution, prefill);
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

  /// Opens the capture wizard's own step 3 directly, on [OcptBudgetGesture.recordTakingReceipt],
  /// pre-filled from [revenue] (today's date, its own label, as a credit, for whatever is still
  /// outstanding against it, the taking already named) — mirrors
  /// `_handleResourceReceiptRequested`'s own gesture: a receipt can never exist as a figure with no
  /// movement behind it.
  Future<void> _handleRevenueReceiptRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetRevenue revenue,
  ) async {
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

    await _handleWizardEntryShortcut(context, state, OcptBudgetGesture.recordTakingReceipt, prefill);
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

  /// Opens the capture wizard's own step 3 directly, on [OcptBudgetGesture.payParticipantShare],
  /// pre-filled from [share] (today's date, its own label, as a debit, for whatever the participant
  /// is still owed — its own due less what it has already been paid, the share already named) —
  /// mirrors `_handleRevenueReceiptRequested`'s own gesture: a payout can never exist as a figure
  /// with no movement behind it.
  Future<void> _handleSharePayoutRequested(
    BuildContext context,
    OcptBudgetState state,
    OcptBudgetShare share,
  ) async {
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

    await _handleWizardEntryShortcut(context, state, OcptBudgetGesture.payParticipantShare, prefill);
  }

  /// Promotes quote line [lineId] into a commitment: opens the capture wizard's own step 3 directly,
  /// on [OcptBudgetGesture.commitSpend], seeded from the line — steps 1 and 2 both already answered
  /// — and dispatches the creation naming the line it came from.
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

    final outcome = await OcptBudgetNewDialog.show(
      context,
      commitmentPrefill: OcptBudgetCommitmentFormFields(
        dueDate: null,
        label: line.label,
        posteId: poste.id,
        amountCents: ocptBudgetLineTotalCents(line),
        isTaxInclusive: line.unitPrice.isTaxInclusive,
        vatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
        status: OcptBudgetCommitmentStatus.quoteAccepted,
      ),
      commitmentPrefillLineId: lineId,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      people: state.people,
      unpricedElements: state.unpricedElements,
      commitments: state.commitments,
      entries: state.entries,
      allowances: state.allowances,
      mileageRates: state.mileageRates,
      receivedByResourceId: state.receivedByResourceId,
      receivedByRevenueId: state.receivedByRevenueId,
      reimbursedByPersonId: state.reimbursedByPersonId,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (outcome == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    _handleNewOutcome(bloc, state, outcome);
  }

  /// Opens the capture wizard to pay quote line [lineId] directly — its own `Pay` action, pre-filled
  /// from the line (its full quoted total, in the line's own tax basis and rate, as today's debit) —
  /// and, on confirm, dispatches [OcptBudgetLinePaidDirectlyEvent], which creates the commitment
  /// behind the payment so the reader only ever quoted and paid. The lettrage strip is withheld
  /// here, exactly as [_handleCommitmentSettleRequested] withholds it: the payment belongs to this
  /// very line, so rerouting it onto a different object is a rapprochement the reader never meant.
  Future<void> _handleLinePayDirectlyRequested(
    BuildContext context,
    OcptBudgetState state,
    String lineId,
  ) async {
    final bloc = context.read<OcptBudgetBloc>();
    final now = DateTime.now();

    final poste = state.postes
        .where((poste) => poste.lines.any((line) => line.id == lineId))
        .firstOrNull;
    final line = poste?.lines.where((line) => line.id == lineId).firstOrNull;
    if (poste == null || line == null) {
      return;
    }

    final prefill = OcptBudgetEntryFormFields(
      date: DateTime(now.year, now.month, now.day),
      label: line.label,
      posteId: poste.id,
      resourceId: null,
      revenueId: null,
      shareId: null,
      isDebit: true,
      amountCents: ocptBudgetLineTotalCents(line),
      isTaxInclusive: line.unitPrice.isTaxInclusive,
      vatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
      voucherNumber: null,
      pickedReceiptPath: null,
      isReceiptDetached: false,
    );

    final outcome = await OcptBudgetNewDialog.show(
      context,
      initialGesture: OcptBudgetGesture.recordExpense,
      entryPrefill: prefill,
      // The line has not been promoted, so every lettrage candidate would be a different object —
      // rerouting the payment onto one is exactly the confusion this direct pay avoids. The strip
      // stays on in the generic `+` capture, where the movement is free-typed.
      offersLettrage: false,
      postes: state.postes,
      resources: state.resources,
      revenues: state.revenues,
      shares: state.shares,
      people: state.people,
      unpricedElements: state.unpricedElements,
      commitments: state.commitments,
      entries: state.entries,
      allowances: state.allowances,
      mileageRates: state.mileageRates,
      receivedByResourceId: state.receivedByResourceId,
      receivedByRevenueId: state.receivedByRevenueId,
      reimbursedByPersonId: state.reimbursedByPersonId,
      currencyCode: state.currencyCode,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      isSimplified: state.isSimplified,
    );
    if (outcome is! OcptBudgetEntryWizardResult) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    // With the strip withheld the wizard can accept no suggestion, so the direct pay is the only
    // outcome left — no `acceptedSuggestion` branch is reachable here.
    bloc.add(OcptBudgetLinePaidDirectlyEvent(lineId: lineId, fields: outcome.fields));
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
        .where(
          (commitment) =>
              commitment.lineId == lineId &&
              !ocptBudgetCommitmentIsSettledOf(
                commitment,
                state.entries,
                projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
              ),
        )
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
  /// (`ocptBudgetViewHasInspector`). Where it is not, a stored `Inspector` preference draws `Help`
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
            ocptBudgetViewHasInspector(state.view, state.toolsView))
          tab,
    ];
    final rightDockTab = availableTabs.contains(storedTab)
        ? storedTab
        : OcptBudgetRightDockTab.help;

    return OcptBudgetRightDock(
      activeTab: rightDockTab,
      availableTabs: availableTabs,
      inspectorChild: _buildFiche(context, state),
      versionsChild: _buildVersionsPanel(context, state),
      helpChild: _buildHelp(context, state),
      onTabSelected: (tab) =>
          context.read<OcptBudgetBloc>().add(OcptBudgetRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptBudgetBloc>().add(const OcptBudgetRightDockClosedEvent()),
    );
  }

  /// Builds the `Help` tab's own content — never withheld under a preview, since it writes
  /// nothing (`OcptBudgetHelp`'s own doc comment).
  Widget _buildHelp(BuildContext context, OcptBudgetState state) =>
      OcptBudgetHelp(view: state.view, toolsView: state.toolsView);

  /// Builds the `Inspector` tab's own content: the polymorphic fiche, wired to every handler its
  /// own selection variant might need — every one of them already exists, reused rather than
  /// duplicated.
  ///
  /// **`onLineShowCommitmentRequested` opens the tools drawer's own `Flux de trésorerie` page and
  /// selects the line's own commitment there**, under its own `À venir` section — the very reading
  /// [_handleCateringFeedRequested]'s own two-event idiom already gives the régie's feed row,
  /// plus the selection event `OcptBudgetCostTracking.onCommitmentSelected` already dispatches.
  Widget _buildFiche(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final elementNameByElementId = {
      for (final element in state.elements) element.id: element.name,
    };
    // The off-line-debit banner's own two actions read the very same entry a receipt's own fiche
    // shares with an ordinary entry's — `OcptBudgetReceiptSelection` names the same `budget_entries`
    // row as `OcptBudgetEntrySelection`, only through a different field.
    final selectedEntryId = switch (state.selection) {
      OcptBudgetEntrySelection(:final entryId) => entryId,
      OcptBudgetReceiptSelection(:final receiptId) => receiptId,
      _ => null,
    };
    final selectedCommitmentId = switch (state.selection) {
      OcptBudgetCommitmentSelection(:final commitmentId) => commitmentId,
      _ => null,
    };

    return OcptBudgetFiche(
      selection: state.selection,
      postes: state.postes,
      commitments: state.commitments,
      entries: state.entries,
      resources: state.resources,
      revenues: state.revenues,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      isSimplified: state.isSimplified,
      isReadOnly: isReadOnly,
      elementNameByElementId: elementNameByElementId,
      receiptsByEntryId: state.receiptsByEntryId,
      receivedByResourceId: state.receivedByResourceId,
      receivedByRevenueId: state.receivedByRevenueId,
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
      onLineTaxInclusiveChanged: isReadOnly
          ? null
          : (lineId, {required isTaxInclusive}) => bloc.add(
              OcptBudgetLineTaxInclusiveChangedEvent(lineId: lineId, isTaxInclusive: isTaxInclusive),
            ),
      onLineVatRateInheritedRequested: isReadOnly
          ? null
          : (lineId) => bloc.add(OcptBudgetLineVatRateInheritedRequestedEvent(lineId: lineId)),
      onLineCommitRequested: isReadOnly
          ? null
          : (lineId) => unawaited(_handleLineCommitRequested(context, state, lineId)),
      onLinePayDirectlyRequested: isReadOnly
          ? null
          : (lineId) => unawaited(_handleLinePayDirectlyRequested(context, state, lineId)),
      onLineSettleRequested: isReadOnly
          ? null
          : (lineId) => unawaited(_handleLineSettleRequested(context, state, lineId)),
      onLineShowCommitmentRequested: (lineId) => _handleLineShowCommitmentRequested(bloc, state, lineId),
      onLineUncommitRequested: isReadOnly
          ? null
          : (lineId) => unawaited(_handleLineUncommitRequested(context, state, lineId)),
      onLineDeletionRequested: isReadOnly
          ? null
          : (lineId) => unawaited(_handleLineDeletionRequested(context, lineId)),
      onCommitmentSettleRequested: isReadOnly
          ? null
          : (commitment) => unawaited(_handleCommitmentSettleRequested(context, state, commitment)),
      onCommitmentEditRequested: isReadOnly
          ? null
          : (commitment) => unawaited(_handleCommitmentEditRequested(context, state, commitment)),
      onCommitmentDeletionRequested: isReadOnly
          ? null
          : (commitmentId) => unawaited(_handleCommitmentDeletionRequested(context, commitmentId)),
      onCommitmentPromoteToQuoteRequested: isReadOnly || selectedCommitmentId == null
          ? null
          : () => bloc.add(
              OcptBudgetCommitmentPromotedToQuoteEvent(commitmentId: selectedCommitmentId),
            ),
      onEntryEditRequested: isReadOnly
          ? null
          : (entry) => unawaited(_handleEntryEditRequested(context, state, entry)),
      onEntryDeletionRequested: isReadOnly
          ? null
          : (entryId) => unawaited(_handleEntryDeletionRequested(context, entryId)),
      onEntryPromoteToQuoteRequested: isReadOnly || selectedEntryId == null
          ? null
          : () => bloc.add(OcptBudgetEntryPromotedToQuoteEvent(entryId: selectedEntryId)),
      onEntryMoveOffQuoteRequested: isReadOnly || selectedEntryId == null
          ? null
          : () => bloc.add(OcptBudgetEntryMovedOffQuoteEvent(entryId: selectedEntryId)),
      onResourceReceiptRequested: isReadOnly
          ? null
          : (resource) => unawaited(_handleResourceReceiptRequested(context, state, resource)),
      onResourceEditRequested: isReadOnly
          ? null
          : (resource) => unawaited(_handleResourceEditRequested(context, state, resource)),
      onResourceDeletionRequested: isReadOnly
          ? null
          : (resourceId) => unawaited(_handleResourceDeletionRequested(context, resourceId)),
      onRevenueReceiptRequested: isReadOnly
          ? null
          : (revenue) => unawaited(_handleRevenueReceiptRequested(context, state, revenue)),
      onRevenueEditRequested: isReadOnly
          ? null
          : (revenue) => unawaited(_handleRevenueEditRequested(context, state, revenue)),
      onRevenueDeletionRequested: isReadOnly
          ? null
          : (revenueId) => unawaited(_handleRevenueDeletionRequested(context, revenueId)),
    );
  }

  /// Opens the entry dialog pre-filled from the commitment quote line [lineId] was promoted into
  /// (today's date, its own label, poste, amount, tax basis and rate, as a debit), then dispatches
  /// the settlement if the user confirmed it — the quote line's own fiche reaches the very same
  /// gesture a commitment's own `Pay` action does, once it is promoted and unsettled.
  Future<void> _handleLineSettleRequested(
    BuildContext context,
    OcptBudgetState state,
    String lineId,
  ) async {
    final commitment = state.commitments
        .where(
          (commitment) =>
              commitment.lineId == lineId &&
              !ocptBudgetCommitmentIsSettledOf(
                commitment,
                state.entries,
                projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
              ),
        )
        .firstOrNull;
    if (commitment == null) {
      return;
    }

    await _handleCommitmentSettleRequested(context, state, commitment);
  }

  /// Opens the tools drawer's own `Flux de trésorerie` page and selects [lineId]'s own commitment
  /// there, under its own `À venir` section — never withheld under a preview, since it only moves
  /// the reader. Resolving the commitment is [_handleLineSettleRequested]'s own reading: the line's
  /// own unsettled commitment, `À venir` holding no other kind.
  void _handleLineShowCommitmentRequested(OcptBudgetBloc bloc, OcptBudgetState state, String lineId) {
    final commitment = state.commitments
        .where(
          (commitment) =>
              commitment.lineId == lineId &&
              !ocptBudgetCommitmentIsSettledOf(
                commitment,
                state.entries,
                projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
              ),
        )
        .firstOrNull;
    if (commitment == null) {
      return;
    }

    bloc
      ..add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.tools))
      ..add(const OcptBudgetToolsViewSelectedEvent(toolsView: OcptBudgetToolsView.cashFlow))
      ..add(OcptBudgetCommitmentSelectedEvent(commitmentId: commitment.id));
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

  /// Applies bloc-driven effects onto the page: the live right dock fraction, the transient version
  /// notice SnackBar, the missing-files question and the transient package notice SnackBar —
  /// mirrors `OcptScheduleMode._onStateChanged`.
  void _onStateChanged(BuildContext context, OcptBudgetState state) {
    // The left fraction is fixed at its own default for the mode's whole lifetime — see
    // `_BudgetViewState`'s own class doc comment for why there is nothing to sync it from.
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
