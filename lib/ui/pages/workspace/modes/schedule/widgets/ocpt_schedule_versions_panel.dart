// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';

/// The schedule's right dock `Versions` tab: the working copy's own card and the project's named
/// versions, the same [OcptProjectVersionsPanel] every mode's dock hosts, wired to the events
/// `MixinOcptProjectVersionsBloc` handles.
class OcptScheduleVersionsPanel extends StatelessWidget {
  /// The mode's state, which the versions and the pending questions are read from.
  final OcptScheduleState state;

  /// Class constructor
  const OcptScheduleVersionsPanel({super.key, required this.state});

  /// Build the schedule versions panel as an [OcptProjectVersionsPanel].
  @override
  Widget build(BuildContext context) => OcptProjectVersionsPanel(
    versions: state.projectVersions,
    previewedVersionId: state.previewedVersionId,
    workingCopy: state.workingCopy,
    versionPendingDeletionId: state.versionPendingDeletionId,
    versionPendingRestoreId: state.versionPendingRestoreId,
    versionPendingRenameId: state.versionPendingRenameId,
    onCreateRequested: () => _requestVersionCreation(context),
    onPreviewRequested: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
    ),
    onPreviewExitRequested: () =>
        context.read<OcptScheduleBloc>().add(const OcptProjectVersionPreviewExitRequestedEvent()),
    onRestoreRequested: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
    ),
    onRestoreCancelled: () =>
        context.read<OcptScheduleBloc>().add(const OcptProjectVersionRestoreCancelledEvent()),
    onRestoreConfirmed: (version) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: version.id,
        safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
      ),
    ),
    onDeleteRequested: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
    ),
    onDeleteCancelled: () =>
        context.read<OcptScheduleBloc>().add(const OcptProjectVersionDeletionCancelledEvent()),
    onDeleteConfirmed: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
    ),
    onRenameRequested: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionRenameRequestedEvent(versionId: versionId),
    ),
    onRenameCancelled: () =>
        context.read<OcptScheduleBloc>().add(const OcptProjectVersionRenameCancelledEvent()),
    onRenameConfirmed: (versionId, name, note) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
    ),
  );

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptScheduleBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }
}
