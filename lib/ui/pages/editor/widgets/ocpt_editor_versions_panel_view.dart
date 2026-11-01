// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';

/// The right dock's `Versions` tab: the working copy's own card and the project's named versions,
/// the same panel every production mode's dock hosts, wired to the events
/// `MixinOcptProjectVersionsBloc` handles.
class OcptEditorVersionsPanelView extends StatelessWidget {
  /// The mode's state.
  final OcptEditorState state;

  /// Class constructor
  const OcptEditorVersionsPanelView({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptEditorBloc>();

    return OcptProjectVersionsPanel(
      versions: state.projectVersions,
      previewedVersionId: state.previewedVersionId,
      workingCopy: state.workingCopy,
      versionPendingDeletionId: state.versionPendingDeletionId,
      versionPendingRestoreId: state.versionPendingRestoreId,
      versionPendingRenameId: state.versionPendingRenameId,
      onCreateRequested: () => _requestCreation(context),
      onPreviewRequested: (versionId) =>
          bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId)),
      onPreviewExitRequested: () => bloc.add(const OcptProjectVersionPreviewExitRequestedEvent()),
      onRestoreRequested: (versionId) =>
          bloc.add(OcptProjectVersionRestoreRequestedEvent(versionId: versionId)),
      onRestoreCancelled: () => bloc.add(const OcptProjectVersionRestoreCancelledEvent()),
      onRestoreConfirmed: (version) => bloc.add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: version.id,
          safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
        ),
      ),
      onDeleteRequested: (versionId) =>
          bloc.add(OcptProjectVersionDeletionRequestedEvent(versionId: versionId)),
      onDeleteCancelled: () => bloc.add(const OcptProjectVersionDeletionCancelledEvent()),
      onDeleteConfirmed: (versionId) =>
          bloc.add(OcptProjectVersionDeletionConfirmedEvent(versionId: versionId)),
      onRenameRequested: (versionId) =>
          bloc.add(OcptProjectVersionRenameRequestedEvent(versionId: versionId)),
      onRenameCancelled: () => bloc.add(const OcptProjectVersionRenameCancelledEvent()),
      onRenameConfirmed: (versionId, name, note) => bloc.add(
        OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
      ),
    );
  }

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestCreation(BuildContext context) async {
    final bloc = context.read<OcptEditorBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }
}
