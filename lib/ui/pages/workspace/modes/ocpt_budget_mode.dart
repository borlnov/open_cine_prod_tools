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

/// The budget tracker production mode. Not implemented yet: shows the shared empty state.
///
/// The project settings action is already wired, unlike everything else here: it opens
/// [OcptRoute.projectSettings] directly, since this mode owns no bloc to reload once the page comes
/// back — currency is exactly the kind of project setting this mode will eventually read itself.
///
/// `onEpisodeSelected` is left explicitly null too: the mode is still an empty state, and nothing
/// on its screen belongs to an episode.
class OcptBudgetMode extends StatelessWidget {
  /// Creates the budget mode.
  const OcptBudgetMode({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final projectName = globalGetIt().get<OcptProjectsManager>().currentProject?.name ?? "";

    return OcptWorkspaceShell(
      title: projectName,
      isDirty: false,
      onBack: () => unawaited(_closeProjectAndPop()),
      // No episode selector either, left at its default null: see the class doc comment.
      modeLabel: tr.workspaceModeLabelBudget,
      onProjectSettingsRequested: () =>
          unawaited(globalGetIt().get<OcptRouterManager>().push(OcptRoute.projectSettings)),
      centre: OcptWorkspaceEmptyMode(
        icon: Icons.payments_outlined,
        message: tr.workspaceEmptyModeMessage(tr.workspaceModeBudget),
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
