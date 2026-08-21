// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_committed_spending.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_dashboard.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_poste_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_right_dock.dart';
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
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The budget production mode: the quote, poste by poste — the dashboard and the cost-tracking
/// table this milestone builds, `Inspector` and `Versions` in the right dock.
///
/// **There is no left dock** (the mockup shows none for this view, `docs/plans/budget-mode.md` §5,
/// M1) and **no episode selector**: one budget serves the whole production (ADR 0019), its
/// catalogue naming no episode at all, exactly the schedule mode's own reason — not for want of a
/// bloc.
///
/// **The `Export` control is wired even though this milestone prints nothing.** The panel it opens
/// (`OcptWorkspaceExportDialog<Never>`) is generic over `Never` because there is no document enum
/// yet to be generic over — `entries` is `const []`, so the panel opens onto its own standing
/// project-package card alone, which is the panel's card rather than any mode's
/// (`OcptWorkspaceExportDialog`'s own doc comment): a colleague can still receive this project as a
/// portable package before the mode prints a single PDF. The exhaustive switch in
/// `_BudgetViewState._requestExport` still has to name the case
/// `OcptWorkspaceExportDocumentPick<Never>` reaches — a `Never` payload
/// can never actually arrive, `entries` being empty, but the switch says so honestly rather than
/// falling back to a bare `default` that would silently swallow a real one the day M4 adds an enum
/// here and forgets to widen this generic.
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

  /// Opens the toolbar's `Export` panel — see the class doc comment for why it opens onto the
  /// project-package card alone.
  Future<void> _requestExport(BuildContext context, OcptBudgetState state) async {
    final tr = Tr.of(context);
    final picked = await OcptWorkspaceExportDialog.show<Never>(
      context,
      title: tr.budgetExportPanelTitle,
      message: tr.budgetExportPanelMessage,
      entries: const [],
      isPreviewingVersion: state.isPreviewingVersion,
    );
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    switch (picked) {
      case OcptWorkspaceExportDocumentPick<Never>():
        // Unreachable: `entries` is `const []`, so no card the panel drew could ever produce a
        // document pick — see the class doc comment. Named explicitly rather than folded into a
        // bare `default` all the same, so a real document enum added here later has to be handled
        // rather than silently falling through this branch.
        break;
      case OcptWorkspaceExportProjectPackagePick<Never>():
        _requestProjectPackageExport(context);
    }
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

  /// Builds the shell's `centre`: the header band, then whichever of the dashboard or the
  /// cost-tracking table [OcptBudgetState.centreView] currently names.
  Widget _buildCentre(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcptBudgetHeader(
          centreView: state.centreView,
          onCentreViewSelected: (view) => bloc.add(OcptBudgetCentreViewSelectedEvent(view: view)),
          isSimplified: state.isSimplified,
          onSimplifiedChanged: (value) =>
              bloc.add(OcptBudgetSimplifiedToggledEvent(isSimplified: value)),
          taxBasis: state.taxBasis,
          onTaxBasisChanged: (basis) => bloc.add(OcptBudgetTaxBasisChangedEvent(basis: basis)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: switch (state.centreView) {
              OcptBudgetCentreView.dashboard => _buildDashboard(context, state),
              OcptBudgetCentreView.costTracking => _buildCostTracking(context, state),
              OcptBudgetCentreView.cashJournal => _buildCashJournal(context, state),
              OcptBudgetCentreView.committed => _buildCommittedSpending(context, state),
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Builds the dashboard.
  Widget _buildDashboard(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();

    return OcptBudgetDashboard(
      postes: state.postes,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      cashTotals: state.cashTotals,
      paidByPosteId: state.paidByPosteId,
      committedByPosteId: state.committedByPosteId,
      alerts: state.alerts,
      onPosteSelected: (posteId) => bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId)),
      onPosteAlertActionRequested: (posteId) {
        bloc
          ..add(OcptBudgetPosteSelectedEvent(posteId: posteId))
          ..add(const OcptBudgetCentreViewSelectedEvent(view: OcptBudgetCentreView.costTracking));
      },
      onCashAlertActionRequested: () => bloc.add(
        const OcptBudgetCentreViewSelectedEvent(view: OcptBudgetCentreView.committed),
      ),
    );
  }

  /// Builds the cost-tracking table.
  Widget _buildCostTracking(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetCostTracking(
      postes: state.postes,
      selectedPosteId: state.selectedPosteId,
      isSimplified: state.isSimplified,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      paidCentsOf: state.paidCentsOf,
      committedCentsOf: state.committedCentsOf,
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

  /// Builds the cash journal view.
  Widget _buildCashJournal(BuildContext context, OcptBudgetState state) {
    final bloc = context.read<OcptBudgetBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetCashJournal(
      entries: state.entries,
      postes: state.postes,
      receiptsByEntryId: state.receiptsByEntryId,
      selectedPosteId: state.selectedPosteId,
      isSimplified: state.isSimplified,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      isReadOnly: isReadOnly,
      onFilterCleared: () => bloc.add(const OcptBudgetCashJournalFilterClearedEvent()),
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
      commitments: state.commitments,
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
  Widget? _buildRightDock(BuildContext context, OcptBudgetState state) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return null;
    }

    return OcptBudgetRightDock(
      activeTab: rightDockTab,
      inspectorChild: _buildInspector(context, state),
      versionsChild: _buildVersionsPanel(context, state),
      onTabSelected: (tab) =>
          context.read<OcptBudgetBloc>().add(OcptBudgetRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptBudgetBloc>().add(const OcptBudgetRightDockClosedEvent()),
    );
  }

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
      onLineExpanded: (lineId) => bloc.add(OcptBudgetLineExpandedEvent(lineId: lineId)),
      onLineTaxInclusiveChanged: isReadOnly
          ? null
          : (lineId, {required isTaxInclusive}) => bloc.add(
              OcptBudgetLineTaxInclusiveChangedEvent(lineId: lineId, isTaxInclusive: isTaxInclusive),
            ),
      onLineVatRateInheritedRequested: isReadOnly
          ? null
          : (lineId) => bloc.add(OcptBudgetLineVatRateInheritedRequestedEvent(lineId: lineId)),
      onLineDeletionRequested: isReadOnly
          ? null
          : (lineId) => unawaited(_handleLineDeletionRequested(context, lineId)),
      onLineCreationRequested: isReadOnly || selectedPoste == null
          ? null
          : () => bloc.add(OcptBudgetLineCreatedEvent(posteId: selectedPoste.id)),
    );
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
  }
}
