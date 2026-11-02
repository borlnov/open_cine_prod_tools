// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_help.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';

/// The budget mode's right dock, the shell's `rightPanel`: the `Inspector`, `Versions` and `Help`
/// tabs, wired to the mode bloc.
///
/// **The `Inspector` tab is offered only where there is something to inspect**
/// (`ocptBudgetViewHasInspector`). Where it is not, a stored `Inspector` preference draws `Help`
/// instead — and is **not overwritten**, so a reader who left the quote on the inspector comes
/// back to it rather than to whatever the logistics happened to show them.
class OcptBudgetRightDockView extends StatelessWidget {
  /// The mode's state, which the stored tab and the views' own content are read from.
  final OcptBudgetState state;

  /// The tab the dock stores, which is not drawn when it is the `Inspector` of a view with nothing
  /// to inspect.
  final OcptBudgetRightDockTab storedTab;

  /// See [OcptBudgetDetailView.onLineDeletionRequested].
  final ValueChanged<String> onLineDeletionRequested;

  /// See [OcptBudgetDetailView.onLineUncommitRequested].
  final ValueChanged<String> onLineUncommitRequested;

  /// See [OcptBudgetDetailView.onCommitmentDeletionRequested].
  final ValueChanged<String> onCommitmentDeletionRequested;

  /// See [OcptBudgetDetailView.onEntryDeletionRequested].
  final ValueChanged<String> onEntryDeletionRequested;

  /// See [OcptBudgetDetailView.onResourceDeletionRequested].
  final ValueChanged<String> onResourceDeletionRequested;

  /// See [OcptBudgetDetailView.onRevenueDeletionRequested].
  final ValueChanged<String> onRevenueDeletionRequested;

  /// Class constructor
  const OcptBudgetRightDockView({
    super.key,
    required this.state,
    required this.storedTab,
    required this.onLineDeletionRequested,
    required this.onLineUncommitRequested,
    required this.onCommitmentDeletionRequested,
    required this.onEntryDeletionRequested,
    required this.onResourceDeletionRequested,
    required this.onRevenueDeletionRequested,
  });

  /// Build the budget right dock view as an [OcptBudgetRightDock].
  @override
  Widget build(BuildContext context) {
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
      inspectorChild: OcptBudgetDetailView(
        state: state,
        onLineDeletionRequested: onLineDeletionRequested,
        onLineUncommitRequested: onLineUncommitRequested,
        onCommitmentDeletionRequested: onCommitmentDeletionRequested,
        onEntryDeletionRequested: onEntryDeletionRequested,
        onResourceDeletionRequested: onResourceDeletionRequested,
        onRevenueDeletionRequested: onRevenueDeletionRequested,
      ),
      versionsChild: _OcptBudgetVersions(state: state),
      // Never withheld under a preview, since it writes nothing (`OcptBudgetHelp`'s own doc
      // comment).
      helpChild: OcptBudgetHelp(view: state.view, toolsView: state.toolsView),
      onTabSelected: (tab) =>
          context.read<OcptBudgetBloc>().add(OcptBudgetRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptBudgetBloc>().add(const OcptBudgetRightDockClosedEvent()),
    );
  }
}

/// The right dock's `Versions` tab, wired exactly as every other mode's own dock.
class _OcptBudgetVersions extends StatelessWidget {
  /// The mode's state, which the versions and their pending questions are read from.
  final OcptBudgetState state;

  /// Class constructor
  const _OcptBudgetVersions({required this.state});

  /// Build the budget versions as an [OcptProjectVersionsPanel].
  @override
  Widget build(BuildContext context) => OcptProjectVersionsPanel(
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

  /// Show the version creation dialog, then dispatch the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptBudgetBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }
}
