// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/ocpt_budget_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/ocpt_schedule_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/ocpt_shot_list_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_mode_switcher.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_state.dart';

/// The workspace: whichever production mode is active fills the window, with the persistent
/// bottom mode switcher underneath it.
///
/// Each mode (the screenplay editor, or one of the not-yet-implemented budget/schedule/shot list
/// modes) builds its own `OcptWorkspaceShell` filling the space above the switcher; the switcher
/// itself lives here, outside every mode's shell, so a mode never has to know about it, let alone
/// thread its active value and selection callback through.
///
/// The `OcptRouterManager` workspace guard guarantees a project is open when this page is reached.
class WorkspacePage extends StatelessWidget {
  /// Creates the workspace page.
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptWorkspaceBloc(), child: const _WorkspaceView());
}

/// The content of [WorkspacePage], separated from it so [WorkspacePage] only wires the
/// [OcptWorkspaceBloc] up (RFL3).
class _WorkspaceView extends StatelessWidget {
  /// Class constructor
  const _WorkspaceView();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BlocBuilder<OcptWorkspaceBloc, OcptWorkspaceState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(child: _buildActiveMode(state.mode)),
            OcptWorkspaceModeSwitcher(
              activeMode: state.mode,
              onModeSelected: (mode) => context.read<OcptWorkspaceBloc>().add(
                OcptWorkspaceModeSelectedEvent(mode: mode),
              ),
            ),
          ],
        );
      },
    ),
  );

  /// Builds the active production mode's own page.
  Widget _buildActiveMode(OcptWorkspaceMode mode) => switch (mode) {
    OcptWorkspaceMode.screenplay => const EditorPage(),
    OcptWorkspaceMode.budget => const OcptBudgetMode(),
    OcptWorkspaceMode.schedule => const OcptScheduleMode(),
    OcptWorkspaceMode.shotList => const OcptShotListMode(),
  };
}
