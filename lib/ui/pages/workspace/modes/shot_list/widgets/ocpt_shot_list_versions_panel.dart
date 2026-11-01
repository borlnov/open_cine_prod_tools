// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';

/// The shot list's right dock `Versions` tab: the working copy's own card and the project's named
/// versions, the same [OcptProjectVersionsPanel] the screenplay mode's dock hosts, wired to the
/// events `MixinOcptProjectVersionsBloc` handles.
class OcptShotListVersionsPanel extends StatelessWidget {
  /// The mode's state, which the versions and the pending questions are read from.
  final OcptShotListState state;

  /// Class constructor
  const OcptShotListVersionsPanel({super.key, required this.state});

  /// Build the shot list versions panel as an [OcptProjectVersionsPanel].
  @override
  Widget build(BuildContext context) => OcptProjectVersionsPanel(
    versions: state.projectVersions,
    previewedVersionId: state.previewedVersionId,
    workingCopy: state.workingCopy,
    versionPendingDeletionId: state.versionPendingDeletionId,
    versionPendingRestoreId: state.versionPendingRestoreId,
    versionPendingRenameId: state.versionPendingRenameId,
    onCreateRequested: () => _requestVersionCreation(context),
    onPreviewRequested: (versionId) => context.read<OcptShotListBloc>().add(
      OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
    ),
    onPreviewExitRequested: () =>
        context.read<OcptShotListBloc>().add(const OcptProjectVersionPreviewExitRequestedEvent()),
    onRestoreRequested: (versionId) => context.read<OcptShotListBloc>().add(
      OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
    ),
    onRestoreCancelled: () =>
        context.read<OcptShotListBloc>().add(const OcptProjectVersionRestoreCancelledEvent()),
    onRestoreConfirmed: (version) => context.read<OcptShotListBloc>().add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: version.id,
        safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
      ),
    ),
    onDeleteRequested: (versionId) => context.read<OcptShotListBloc>().add(
      OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
    ),
    onDeleteCancelled: () =>
        context.read<OcptShotListBloc>().add(const OcptProjectVersionDeletionCancelledEvent()),
    onDeleteConfirmed: (versionId) => context.read<OcptShotListBloc>().add(
      OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
    ),
    onRenameRequested: (versionId) => context.read<OcptShotListBloc>().add(
      OcptProjectVersionRenameRequestedEvent(versionId: versionId),
    ),
    onRenameCancelled: () =>
        context.read<OcptShotListBloc>().add(const OcptProjectVersionRenameCancelledEvent()),
    onRenameConfirmed: (versionId, name, note) => context.read<OcptShotListBloc>().add(
      OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
    ),
  );

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptShotListBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }
}
