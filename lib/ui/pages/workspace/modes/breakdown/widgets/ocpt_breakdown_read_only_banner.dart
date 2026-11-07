// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';

/// The band naming the version the breakdown mode is previewing, the shell's `banner`: forking it
/// restores it, leaving it brings the working copy back.
class OcptBreakdownReadOnlyBanner extends StatelessWidget {
  /// The version being previewed.
  final OcptProjectVersion previewedVersion;

  /// Class constructor
  const OcptBreakdownReadOnlyBanner({super.key, required this.previewedVersion});

  /// Build the breakdown read only banner as an [OcptWorkspaceReadOnlyBanner].
  @override
  Widget build(BuildContext context) => OcptWorkspaceReadOnlyBanner(
    version: previewedVersion,
    onForkRequested: () => context.read<OcptBreakdownBloc>().add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: previewedVersion.id,
        safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(previewedVersion.name),
      ),
    ),
    onExitPreview: () =>
        context.read<OcptBreakdownBloc>().add(const OcptProjectVersionPreviewExitRequestedEvent()),
  );
}
