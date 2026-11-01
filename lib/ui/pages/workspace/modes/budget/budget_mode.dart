// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_outcome.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_export_requests.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_financing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_centre.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_right_dock_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_view_effects.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

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
/// `ocptBudgetRequestExport` — the panel's standing project-package card sits under
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

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => OcptBudgetBloc(seed: seed)),
        BlocProvider(
          lazy: false,
          create: (context) => OcptBudgetExportBloc(modeBloc: context.read<OcptBudgetBloc>()),
        ),
        BlocProvider(
          lazy: false,
          create: (context) => OcptBudgetExpensesBloc(modeBloc: context.read<OcptBudgetBloc>()),
        ),
        BlocProvider(
          lazy: false,
          create: (context) => OcptBudgetSharingBloc(modeBloc: context.read<OcptBudgetBloc>()),
        ),
        BlocProvider(
          lazy: false,
          create: (context) => OcptBudgetFinancingBloc(modeBloc: context.read<OcptBudgetBloc>()),
        ),
        BlocProvider(
          lazy: false,
          create: (context) => OcptBudgetCashJournalBloc(modeBloc: context.read<OcptBudgetBloc>()),
        ),
      ],
      child: const OcptBudgetViewEffects(child: _BudgetView()),
    );
  }
}

/// The content of [OcptBudgetMode], separated from it so [OcptBudgetMode] only wires the
/// [OcptBudgetBloc] up.
///
/// A StatefulWidget (the documented exception) because it owns the dock layout controller,
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
  @override
  Widget build(BuildContext context) => BlocConsumer<OcptBudgetBloc, OcptBudgetState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      final previewedVersion = state.previewedVersion;
      final rightDockTab = state.rightDockTab;

      return LayoutBuilder(
        builder: (context, constraints) => OcptWorkspaceShell(
          title: state.title,
          isDirty: false,
          isReadOnly: state.isPreviewingVersion,
          onBack: () => context.read<OcptBudgetBloc>().add(const OcptBudgetBackRequestedEvent()),
          // No episode selector: see the class doc comment.
          modeLabel: Tr.of(context).workspaceModeLabelBudget,
          onExportRequested: (anchor) => unawaited(ocptBudgetRequestExport(context, state, anchor)),
          isRightDockOpen: rightDockTab != null,
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
          banner: previewedVersion == null
              ? null
              : OcptBudgetReadOnlyBanner(previewedVersion: previewedVersion),
          rightPanel: rightDockTab == null
              ? null
              : OcptBudgetRightDockView(
                  state: state,
                  storedTab: rightDockTab,
                  onLineDeletionRequested: (lineId) =>
                      unawaited(_handleLineDeletionRequested(context, lineId)),
                  onLineUncommitRequested: (lineId) =>
                      unawaited(_handleLineUncommitRequested(context, state, lineId)),
                  onCommitmentDeletionRequested: (commitmentId) =>
                      unawaited(_handleCommitmentDeletionRequested(context, commitmentId)),
                  onEntryDeletionRequested: (entryId) =>
                      unawaited(_handleEntryDeletionRequested(context, entryId)),
                  onResourceDeletionRequested: (resourceId) =>
                      unawaited(_handleResourceDeletionRequested(context, resourceId)),
                  onRevenueDeletionRequested: (revenueId) =>
                      unawaited(_handleRevenueDeletionRequested(context, revenueId)),
                ),
          centre: OcptBudgetCentre(
            state: state,
            isCompact: ocptIsCompactWidth(constraints.maxWidth),
            onProjectSettingsRequested: () => unawaited(_requestProjectSettings(context)),
            onPosteDeletionRequested: (posteId) =>
                unawaited(_handlePosteDeletionRequested(context, posteId)),
            onEntryDeletionRequested: (entryId) =>
                unawaited(_handleEntryDeletionRequested(context, entryId)),
            onCommitmentDeletionRequested: (commitmentId) =>
                unawaited(_handleCommitmentDeletionRequested(context, commitmentId)),
            onResourceDeletionRequested: (resourceId) =>
                unawaited(_handleResourceDeletionRequested(context, resourceId)),
            onResourceReceiptUndoRequested: (resource) =>
                unawaited(_handleResourceReceiptUndoRequested(context, state, resource)),
            onRevenueDeletionRequested: (revenueId) =>
                unawaited(_handleRevenueDeletionRequested(context, revenueId)),
            onAllowanceDeletionRequested: (allowanceId) =>
                unawaited(_handleAllowanceDeletionRequested(context, allowanceId)),
            onProvisionRequested: () => unawaited(_handleProvisionRequested(context, state)),
            onShareDeletionRequested: (shareId) =>
                unawaited(_handleShareDeletionRequested(context, shareId)),
          ),
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
              context.read<OcptBudgetBloc>().add(
                OcptBudgetRightDockFractionChangedEvent(fraction: right),
              );
            }
          },
        ),
      );
    },
  );

  /// Asks whether to write the package even though some referenced files are gone, then dispatches
  /// the export if the user said to go on. Mirrors
  /// `OcptScheduleMode._askAboutMissingPackagedFiles`.
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
      OcptProjectPackageExportConfirmedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
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

  /// Asks `OcptConfirmDialog` whether poste [posteId] really is to be deleted — the message says
  /// its own quote lines go with it — then dispatches the deletion if the user answered `Delete`.
  Future<void> _handlePosteDeletionRequested(BuildContext context, String posteId) async {
    final expensesBloc = context.read<OcptBudgetExpensesBloc>();
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

    expensesBloc.add(OcptBudgetPosteDeletionConfirmedEvent(posteId: posteId));
  }

  /// Asks `OcptConfirmDialog` whether cash-journal entry [entryId] really is to be deleted, then
  /// dispatches the deletion if the user answered `Delete`.
  Future<void> _handleEntryDeletionRequested(BuildContext context, String entryId) async {
    final journalBloc = context.read<OcptBudgetCashJournalBloc>();
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

    journalBloc.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId));
  }

  /// Asks `OcptConfirmDialog` whether commitment [commitmentId] really is to be deleted, then
  /// dispatches the deletion if the user answered `Delete`.
  Future<void> _handleCommitmentDeletionRequested(BuildContext context, String commitmentId) async {
    final journalBloc = context.read<OcptBudgetCashJournalBloc>();
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

    journalBloc.add(OcptBudgetCommitmentDeletionConfirmedEvent(commitmentId: commitmentId));
  }

  /// Asks `OcptConfirmDialog` whether financing resource [resourceId] really is to be deleted, then
  /// dispatches the deletion if the user answered `Delete`.
  Future<void> _handleResourceDeletionRequested(BuildContext context, String resourceId) async {
    final financingBloc = context.read<OcptBudgetFinancingBloc>();
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

    financingBloc.add(OcptBudgetResourceDeletionConfirmedEvent(resourceId: resourceId));
  }

  /// Resolves the most recently recorded live credit against [resource]
  /// (`ocptBudgetLatestReceiptEntryIdOf`, `lib/models/rules/ocpt_budget_financing.dart`), asks
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
    final journalBloc = context.read<OcptBudgetCashJournalBloc>();
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

    journalBloc.add(OcptBudgetEntryDeletionConfirmedEvent(entryId: entryId));
  }

  /// Asks `OcptConfirmDialog` whether defrayal [allowanceId] really is to be deleted, then
  /// dispatches the deletion if the user answered `Delete`.
  Future<void> _handleAllowanceDeletionRequested(BuildContext context, String allowanceId) async {
    final financingBloc = context.read<OcptBudgetFinancingBloc>();
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

    financingBloc.add(OcptBudgetAllowanceDeletionConfirmedEvent(allowanceId: allowanceId));
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
    final financingBloc = context.read<OcptBudgetFinancingBloc>();
    final tr = Tr.of(context);
    final posteId = state.provisionPosteId;
    final poste = state.postes.where((row) => row.id == posteId).firstOrNull;
    if (posteId == null || poste == null) {
      return;
    }

    final entries = ocptBudgetRegieProvisionPlanOf(context, state);

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

    financingBloc.add(OcptBudgetProvisionConfirmedEvent(posteId: posteId, entries: entries));
  }

  /// Asks `OcptConfirmDialog` whether taking [revenueId] really is to be deleted, then dispatches
  /// the deletion if the user answered `Delete`.
  Future<void> _handleRevenueDeletionRequested(BuildContext context, String revenueId) async {
    final sharingBloc = context.read<OcptBudgetSharingBloc>();
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

    sharingBloc.add(OcptBudgetRevenueDeletionConfirmedEvent(revenueId: revenueId));
  }

  /// Asks `OcptConfirmDialog` whether share [shareId] really is to be deleted, then dispatches the
  /// deletion if the user answered `Delete`.
  Future<void> _handleShareDeletionRequested(BuildContext context, String shareId) async {
    final sharingBloc = context.read<OcptBudgetSharingBloc>();
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

    sharingBloc.add(OcptBudgetShareDeletionConfirmedEvent(shareId: shareId));
  }

  /// Asks, through `OcptConfirmDialog`, before undoing line [lineId]'s own promotion — which
  /// deletes the commitment it produced, and leaves the quote line itself alone.
  Future<void> _handleLineUncommitRequested(
    BuildContext context,
    OcptBudgetState state,
    String lineId,
  ) async {
    final journalBloc = context.read<OcptBudgetCashJournalBloc>();
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

    journalBloc.add(OcptBudgetCommitmentDeletionConfirmedEvent(commitmentId: commitment.id));
  }

  /// Asks `OcptConfirmDialog` whether quote line [lineId] really is to be deleted, then dispatches
  /// the deletion if the user answered `Delete`.
  Future<void> _handleLineDeletionRequested(BuildContext context, String lineId) async {
    final expensesBloc = context.read<OcptBudgetExpensesBloc>();
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

    expensesBloc.add(OcptBudgetLineDeletionConfirmedEvent(lineId: lineId));
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
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectVersionNoticeMessage(context, versionNotice))),
        );
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
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectPackageNoticeMessage(context, packageNotice))),
        );
      context.read<OcptBudgetBloc>().add(const OcptProjectPackageNoticeDismissedEvent());
    }
  }

  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }
}
