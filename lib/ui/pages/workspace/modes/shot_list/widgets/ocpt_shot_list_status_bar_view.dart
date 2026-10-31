// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_status_bar.dart';

/// The shot list mode's status bar: the counters of the whole shot list, and the hint the active
/// centre view adds, an [OcptShotListStatusBar].
///
/// It watches [OcptShotListStoryboardBloc] itself, since the board's selected panel is part of the
/// hint, so a change of the board's own state redraws this bar and nothing around it.
class OcptShotListStatusBarView extends StatelessWidget {
  /// The mode's state, which the counters and the selections are read from.
  final OcptShotListState state;

  /// Whether the window is at a compact width, which forces the table and so no hint.
  final bool isCompact;

  /// Class constructor
  const OcptShotListStatusBarView({super.key, required this.state, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final storyboardState = context.watch<OcptShotListStoryboardBloc>().state;

    return OcptShotListStatusBar(
      sequenceCount: state.sequenceCount,
      shotCount: state.totalShotCount,
      filmedShotCount: state.filmedShotCount,
      shotsToCheckCount: state.shotsToCheckCount,
      hint: _statusBarHint(context, state, storyboardState, isCompact),
    );
  }

  /// The status bar's own trailing hint for the active centre view: the board's `Panel 2 of 3
  /// selected · drag to reorder` while it is shown and a panel is selected, the floor plans'
  /// `Kitchen · 5 cameras on 4 shots · 12/5 has no camera yet` (the last segment only while a shot
  /// of the sequence still has none) while a set is selected, or null otherwise (the table, and
  /// either view with nothing of its own selected, have nothing to add).
  String? _statusBarHint(
    BuildContext context,
    OcptShotListState state,
    OcptShotListStoryboardState storyboardState,
    bool isCompact,
  ) {
    final isBoardShown = !isCompact && state.centreView == OcptShotListCentreView.board;
    final isFloorPlansShown = !isCompact && state.centreView == OcptShotListCentreView.floorPlans;

    if (isFloorPlansShown) {
      final selectedSet = state.selectedSet;
      final sequence = state.selectedSequence;
      if (selectedSet == null || sequence == null) {
        return null;
      }

      final cameraCount = selectedSet.symbols
          .where((symbol) => symbol.layer == OcptFloorPlanLayer.cameras)
          .length;
      final shotIdsWithCamera = {
        for (final symbol in selectedSet.symbols)
          if (symbol.layer == OcptFloorPlanLayer.cameras && symbol.shotId != null) symbol.shotId!,
      };
      final shotCountWithCamera = sequence.shots
          .where((shot) => shotIdsWithCamera.contains(shot.id))
          .length;
      final unplacedShot = sequence.shots.firstWhereOrNull(
        (shot) => !shotIdsWithCamera.contains(shot.id),
      );

      final base = Tr.of(
        context,
      ).shotListFloorPlanCameraStatusHint(selectedSet.name, cameraCount, shotCountWithCamera);
      return unplacedShot == null
          ? base
          : "$base · "
                "${Tr.of(context).shotListFloorPlanCameraStatusUnplacedHint(unplacedShot.code)}";
    }

    if (!isBoardShown) {
      return null;
    }

    final panels = state.panelsOfSelectedShot;
    final selectedPanel = storyboardState.selectedPanelIn(state);
    if (selectedPanel == null || panels.isEmpty) {
      return null;
    }

    final rank = panels.indexWhere((panel) => panel.id == selectedPanel.id) + 1;
    return Tr.of(context).shotListBoardPanelSelectedHint(rank, panels.length);
  }
}
