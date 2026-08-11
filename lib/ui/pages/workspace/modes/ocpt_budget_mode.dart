// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';

/// The budget tracker production mode. Not implemented yet: shows the shared empty state.
///
/// The project settings action is already wired, unlike everything else here: it opens
/// [OcptRoute.projectSettings] directly, since this mode owns no bloc of its own to reload once
/// the page comes back — currency is exactly the kind of project setting this mode will eventually
/// read itself. It still tells `OcptWorkspaceBloc` to reload its episodes when the settings page
/// reports a change, exactly as every other mode's own `_requestProjectSettings` does: the
/// `Episodes` card can add or delete one, which the workspace bloc otherwise only learns about
/// from `OcptProjectsManager.currentProjectStream`, an event the episode CRUD does not fire.
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
      onProjectSettingsRequested: () => unawaited(_requestProjectSettings(context)),
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

  /// Opens the project settings page, then tells `OcptWorkspaceBloc` to reload its episodes if the
  /// user changed anything there. See the class doc comment for why this mode, alone, has nothing
  /// of its own to reload.
  Future<void> _requestProjectSettings(BuildContext context) async {
    final workspaceBloc = context.read<OcptWorkspaceBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
    );
    if (hasChanged != true) {
      return;
    }

    workspaceBloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
  }
}
