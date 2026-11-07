// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';

/// The band naming the version being previewed, the shell's `banner`, wired to the events
/// `MixinOcptProjectVersionsBloc` handles. The mode draws none while the working copy is on screen.
class OcptResourcesReadOnlyBanner extends StatelessWidget {
  /// The version being previewed.
  final OcptProjectVersion previewedVersion;

  /// Class constructor
  const OcptResourcesReadOnlyBanner({super.key, required this.previewedVersion});

  /// Build the resources read only banner as an [OcptWorkspaceReadOnlyBanner].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptWorkspaceReadOnlyBanner(
      version: previewedVersion,
      onForkRequested: () => context.read<OcptResourcesBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: previewedVersion.id,
          safetyVersionName: tr.projectVersionRestoreSafetyName(previewedVersion.name),
        ),
      ),
      onExitPreview: () => context.read<OcptResourcesBloc>().add(
        const OcptProjectVersionPreviewExitRequestedEvent(),
      ),
    );
  }
}
