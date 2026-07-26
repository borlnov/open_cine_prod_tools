// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';

/// The shooting schedule production mode. Not implemented yet: shows the shared empty state.
class OcptScheduleMode extends StatelessWidget {
  /// Creates the schedule mode.
  const OcptScheduleMode({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final projectName = globalGetIt().get<OcptProjectsManager>().currentProject?.name ?? "";

    return OcptWorkspaceShell(
      title: projectName,
      isDirty: false,
      onBack: () => unawaited(_closeProjectAndPop()),
      centre: OcptWorkspaceEmptyMode(
        icon: Icons.calendar_month_outlined,
        message: tr.workspaceEmptyModeMessage(tr.workspaceModeSchedule),
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
