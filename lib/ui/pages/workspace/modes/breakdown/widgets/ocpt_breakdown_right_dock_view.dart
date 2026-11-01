// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_inspector_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';

/// The breakdown mode's right dock, the shell's `rightPanel`: an [OcptBreakdownRightDock] hosting
/// the `Inspector` tab ([OcptBreakdownInspectorView]) and the shared `Versions` panel, wired to the
/// events `MixinOcptProjectVersionsBloc` handles.
///
/// Removing a target's tags and capturing a version are only *asked*, through
/// [onTagRemovalRequested] and [onVersionCreationRequested]: the mode owns the dialogs.
class OcptBreakdownRightDockView extends StatelessWidget {
  /// The mode's state, which the selection, the catalogues and the versions are read from.
  final OcptBreakdownState state;

  /// The right dock's active tab.
  final OcptBreakdownRightDockTab activeTab;

  /// Called when the user asked to remove the selected target's tags from the selected scene.
  final VoidCallback onTagRemovalRequested;

  /// Called when the user asked to capture the working copy as a new version.
  final VoidCallback onVersionCreationRequested;

  /// Class constructor
  const OcptBreakdownRightDockView({
    super.key,
    required this.state,
    required this.activeTab,
    required this.onTagRemovalRequested,
    required this.onVersionCreationRequested,
  });

  @override
  Widget build(BuildContext context) => OcptBreakdownRightDock(
    activeTab: activeTab,
    inspectorChild: OcptBreakdownInspectorView(
      state: state,
      onTagRemovalRequested: onTagRemovalRequested,
    ),
    versionsChild: OcptProjectVersionsPanel(
      versions: state.projectVersions,
      previewedVersionId: state.previewedVersionId,
      workingCopy: state.workingCopy,
      versionPendingDeletionId: state.versionPendingDeletionId,
      versionPendingRestoreId: state.versionPendingRestoreId,
      versionPendingRenameId: state.versionPendingRenameId,
      onCreateRequested: onVersionCreationRequested,
      onPreviewRequested: (versionId) => context.read<OcptBreakdownBloc>().add(
        OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
      ),
      onPreviewExitRequested: () => context.read<OcptBreakdownBloc>().add(
        const OcptProjectVersionPreviewExitRequestedEvent(),
      ),
      onRestoreRequested: (versionId) => context.read<OcptBreakdownBloc>().add(
        OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
      ),
      onRestoreCancelled: () =>
          context.read<OcptBreakdownBloc>().add(const OcptProjectVersionRestoreCancelledEvent()),
      onRestoreConfirmed: (version) => context.read<OcptBreakdownBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: version.id,
          safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
        ),
      ),
      onDeleteRequested: (versionId) => context.read<OcptBreakdownBloc>().add(
        OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
      ),
      onDeleteCancelled: () =>
          context.read<OcptBreakdownBloc>().add(const OcptProjectVersionDeletionCancelledEvent()),
      onDeleteConfirmed: (versionId) => context.read<OcptBreakdownBloc>().add(
        OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
      ),
      onRenameRequested: (versionId) => context.read<OcptBreakdownBloc>().add(
        OcptProjectVersionRenameRequestedEvent(versionId: versionId),
      ),
      onRenameCancelled: () =>
          context.read<OcptBreakdownBloc>().add(const OcptProjectVersionRenameCancelledEvent()),
      onRenameConfirmed: (versionId, name, note) => context.read<OcptBreakdownBloc>().add(
        OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
      ),
    ),
    onTabSelected: (tab) =>
        context.read<OcptBreakdownBloc>().add(OcptBreakdownRightDockTabSelectedEvent(tab: tab)),
    onClose: () => context.read<OcptBreakdownBloc>().add(const OcptBreakdownRightDockClosedEvent()),
  );
}
