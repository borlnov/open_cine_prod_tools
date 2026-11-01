// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';

/// The band naming the version being previewed, the shell's `banner`, wired to the events
/// `MixinOcptProjectVersionsBloc` handles.
///
/// The mode draws none — rather than one naming nothing — in the narrow window where the previewed
/// version isn't in the list the panel was drawn from any more: the refresh ending every version
/// handler resolves it on its own, and a band that named nothing would say less than no band at
/// all.
class OcptShotListReadOnlyBanner extends StatelessWidget {
  /// The version being previewed.
  final OcptProjectVersion previewedVersion;

  /// Class constructor
  const OcptShotListReadOnlyBanner({super.key, required this.previewedVersion});

  /// Build the shot list read only banner as an [OcptWorkspaceReadOnlyBanner].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptWorkspaceReadOnlyBanner(
      version: previewedVersion,
      // `Start from this version` is a plain restore of the version being previewed:
      // `OcptProjectsManager.restoreProjectVersion` leaves the preview on its own before writing
      // anything, so the handler needs nothing beyond the same event a version's own card
      // dispatches.
      onForkRequested: () => context.read<OcptShotListBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: previewedVersion.id,
          safetyVersionName: tr.projectVersionRestoreSafetyName(previewedVersion.name),
        ),
      ),
      onExitPreview: () =>
          context.read<OcptShotListBloc>().add(const OcptProjectVersionPreviewExitRequestedEvent()),
    );
  }
}
