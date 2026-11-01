// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_scene_bars.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_panel.dart';

/// The breakdown mode's left dock, the shell's `leftPanel`: the scene list and, under it, the
/// category legend, wired to the mode bloc.
///
/// Selecting a scene from the list is the quiet [OcptBreakdownSceneSelectedEvent], which leaves the
/// selected target and the right dock alone; tapping a scene's warning mark is the louder
/// [OcptBreakdownSceneHeadingSelectedEvent], which shows the scene's own sheet.
class OcptBreakdownLeftDockView extends StatelessWidget {
  /// The mode's state, which the scenes, the targets and the legend are read from.
  final OcptBreakdownState state;

  /// Class constructor
  const OcptBreakdownLeftDockView({super.key, required this.state});

  @override
  Widget build(BuildContext context) => OcptBreakdownScenePanel(
    scenes: state.scenes,
    targetById: ocptBreakdownTargetsById(state.targets),
    selectedSceneId: state.selectedSceneId,
    onSceneSelected: (sceneId) =>
        context.read<OcptBreakdownBloc>().add(OcptBreakdownSceneSelectedEvent(sceneId: sceneId)),
    onWarningTapped: (sceneId) => context.read<OcptBreakdownBloc>().add(
      OcptBreakdownSceneHeadingSelectedEvent(sceneId: sceneId),
    ),
    legendEntries: ocptBreakdownLegendEntriesOf(state.targets),
    hiddenLegendKeys: state.hiddenLegendKeys,
    onLegendEntryToggled: (key) =>
        context.read<OcptBreakdownBloc>().add(OcptBreakdownLegendEntryToggledEvent(key: key)),
    onShowAllLegendKeysRequested: () =>
        context.read<OcptBreakdownBloc>().add(const OcptBreakdownLegendShowAllRequestedEvent()),
  );
}
