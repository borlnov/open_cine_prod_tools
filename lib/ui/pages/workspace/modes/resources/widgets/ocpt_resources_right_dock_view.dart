// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';

/// The resources mode's right dock, the shell's `rightPanel`: an [OcptResourcesRightDock] hosting
/// the shared `Versions` panel, wired to the events `MixinOcptProjectVersionsBloc` handles.
///
/// Capturing a version is only *asked*, through [onVersionCreationRequested]: the mode owns the
/// dialog that names it.
class OcptResourcesRightDockView extends StatelessWidget {
  /// The mode's state, which the versions and the pending questions are read from.
  final OcptResourcesState state;

  /// Called when the user asked to capture the working copy as a new version.
  final VoidCallback onVersionCreationRequested;

  /// Class constructor
  const OcptResourcesRightDockView({
    super.key,
    required this.state,
    required this.onVersionCreationRequested,
  });

  @override
  Widget build(BuildContext context) => OcptResourcesRightDock(
    versionsChild: OcptProjectVersionsPanel(
      versions: state.projectVersions,
      previewedVersionId: state.previewedVersionId,
      workingCopy: state.workingCopy,
      versionPendingDeletionId: state.versionPendingDeletionId,
      versionPendingRestoreId: state.versionPendingRestoreId,
      versionPendingRenameId: state.versionPendingRenameId,
      onCreateRequested: onVersionCreationRequested,
      onPreviewRequested: (versionId) => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
      ),
      onPreviewExitRequested: () => context.read<OcptResourcesBloc>().add(
        const OcptProjectVersionPreviewExitRequestedEvent(),
      ),
      onRestoreRequested: (versionId) => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
      ),
      onRestoreCancelled: () =>
          context.read<OcptResourcesBloc>().add(const OcptProjectVersionRestoreCancelledEvent()),
      onRestoreConfirmed: (version) => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: version.id,
          safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
        ),
      ),
      onDeleteRequested: (versionId) => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
      ),
      onDeleteCancelled: () =>
          context.read<OcptResourcesBloc>().add(const OcptProjectVersionDeletionCancelledEvent()),
      onDeleteConfirmed: (versionId) => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
      ),
      onRenameRequested: (versionId) => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionRenameRequestedEvent(versionId: versionId),
      ),
      onRenameCancelled: () =>
          context.read<OcptResourcesBloc>().add(const OcptProjectVersionRenameCancelledEvent()),
      onRenameConfirmed: (versionId, name, note) => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
      ),
    ),
    onClose: () => context.read<OcptResourcesBloc>().add(const OcptResourcesRightDockClosedEvent()),
  );
}
