// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';

/// The band naming the version the budget mode is previewing, the shell's `banner`: forking it
/// restores it, leaving it brings the working copy back. Mirrors `OcptScheduleMode`'s own banner.
class OcptBudgetReadOnlyBanner extends StatelessWidget {
  /// The version being previewed.
  final OcptProjectVersion previewedVersion;

  /// Class constructor
  const OcptBudgetReadOnlyBanner({super.key, required this.previewedVersion});

  /// Build the budget read only banner as an [OcptWorkspaceReadOnlyBanner].
  @override
  Widget build(BuildContext context) => OcptWorkspaceReadOnlyBanner(
    version: previewedVersion,
    onForkRequested: () => context.read<OcptBudgetBloc>().add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: previewedVersion.id,
        safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(previewedVersion.name),
      ),
    ),
    onExitPreview: () =>
        context.read<OcptBudgetBloc>().add(const OcptProjectVersionPreviewExitRequestedEvent()),
  );
}
