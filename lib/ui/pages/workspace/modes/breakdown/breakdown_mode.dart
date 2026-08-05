// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';

/// The breakdown production mode (dépouillement du scénario): reading the script once and tagging
/// what the shoot must provide.
///
/// Reachable and remembered like every other mode, but its own content — the scene panel, the
/// script view and the shared `Versions` dock — is not built yet: it shows the shared empty state,
/// mirroring `OcptBudgetMode`/`OcptScheduleMode` while it does. Unlike those two, this mode *is*
/// [OcptWorkspaceMode.isImplemented]: the empty state here is a scaffolding step rather than "not
/// implemented", and is expected to be replaced by the mode's own bloc and panels.
///
/// The project settings action is already wired, unlike everything else here: it opens
/// [OcptRoute.projectSettings] directly, since this mode owns no bloc yet to reload once the page
/// comes back.
class OcptBreakdownMode extends StatelessWidget {
  /// Creates the breakdown mode.
  const OcptBreakdownMode({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final projectName = globalGetIt().get<OcptProjectsManager>().currentProject?.name ?? "";

    return OcptWorkspaceShell(
      title: projectName,
      isDirty: false,
      onBack: () => unawaited(_closeProjectAndPop()),
      modeLabel: tr.workspaceModeLabelBreakdown,
      onProjectSettingsRequested: () =>
          unawaited(globalGetIt().get<OcptRouterManager>().push(OcptRoute.projectSettings)),
      centre: OcptWorkspaceEmptyMode(
        icon: Icons.fact_check_outlined,
        message: tr.workspaceEmptyModeMessage(tr.workspaceModeBreakdown),
      ),
    );
  }

  /// Closes the open project and navigates back to the home page, exactly like the screenplay
  /// mode's own back action.
  Future<void> _closeProjectAndPop() async {
    await globalGetIt().get<OcptProjectsManager>().closeCurrentProject();
    globalGetIt().get<OcptRouterManager>().pop();
  }
}
