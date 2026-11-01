// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_placements_group.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_placements_other_set.dart';

/// The floor plans view's group in the shot inspector: the selected shot's own placements on the
/// selected set, and one line per other set of the sequence, an [OcptFloorPlanPlacementsGroup]
/// wired to the mode bloc for what is shared and to [OcptShotListFloorPlanPlacementsBloc] for what
/// the group does with the symbols. It reads the selected symbol from the canvas bloc, which owns
/// the gesture that selected it.
///
/// Draws nothing while no shot or no set is selected (the `Sequence` focus shows no single shot's
/// own placements at all). Removing a symbol or an arrow is only *asked*, through
/// [onSymbolDeleteRequested] and [onArrowDeleteRequested]: the mode owns their confirmation
/// dialogs.
class OcptShotListPlacementsView extends StatelessWidget {
  /// The mode's state, which the shot, the set and the sheet are read from.
  final OcptShotListState state;

  /// Called with the id of the symbol the user asked to remove; the mode confirms it, then
  /// dispatches the deletion.
  final ValueChanged<String> onSymbolDeleteRequested;

  /// Called with the id of the arrow the user asked to remove; the mode confirms it, then
  /// dispatches the deletion.
  final ValueChanged<String> onArrowDeleteRequested;

  /// Class constructor
  const OcptShotListPlacementsView({
    super.key,
    required this.state,
    required this.onSymbolDeleteRequested,
    required this.onArrowDeleteRequested,
  });

  /// Build the shot list placements view as an [OcptFloorPlanPlacementsGroup].
  @override
  Widget build(BuildContext context) {
    final selectedShot = state.selectedShot;
    final selectedSet = state.selectedSet;
    if (selectedShot == null || selectedSet == null) {
      return const SizedBox.shrink();
    }

    final isReadOnly = state.isPreviewingVersion;

    final shotRankByShotId = <String, int>{
      for (final sequence in state.sequences)
        if (sequence is OcptSceneShotSequence)
          for (var i = 0; i < sequence.shots.length; i++) sequence.shots[i].id: i + 1,
    };
    final sheet = OcptFloorPlanSheet.of(
      floorPlanSet: selectedSet,
      focusSceneId: state.selectedSequenceId ?? '',
      focusShotId: selectedShot.id,
      shotRankByShotId: shotRankByShotId,
    );
    final ownSymbols = [
      for (final symbol in sheet.symbols)
        if (!symbol.isGhost && symbol.shotId == selectedShot.id) symbol,
    ];
    final ownArrows = [
      for (final arrow in sheet.arrows)
        if (!arrow.isGhost && arrow.shotId == selectedShot.id) arrow,
    ];

    final otherSets = [
      for (final otherSet in state.setsOfSelectedSequence)
        if (otherSet.id != selectedSet.id)
          OcptFloorPlanPlacementsOtherSet(
            setName: otherSet.name,
            cameraCount: otherSet.symbols
                .where(
                  (symbol) =>
                      symbol.layer == OcptFloorPlanLayer.cameras &&
                      symbol.shotId == selectedShot.id,
                )
                .length,
          ),
    ];

    // A selected override (visible or a hidden one's own ghost) may be a sequence- or a shot-scope
    // shape — checked against the whole sheet, not just this shot's own placements.
    final canvasState = context.watch<OcptShotListFloorPlanCanvasBloc>().state;
    final selectedSymbolId = canvasState.selectedFloorPlanSymbolId;
    final selectedShape = selectedSymbolId == null
        ? null
        : sheet.symbols.firstWhereOrNull((symbol) => symbol.symbolId == selectedSymbolId);
    final selectedOverrideLevel =
        selectedShape != null && (selectedShape.isOverride || selectedShape.isHiddenOverrideGhost)
        ? selectedShape.overrideLevel
        : null;

    return OcptFloorPlanPlacementsGroup(
      setName: selectedSet.name,
      selectedSymbolId: canvasState.selectedFloorPlanSymbolId,
      selectedArrowId: canvasState.selectedFloorPlanArrowId,
      cameras: ownSymbols.where((symbol) => symbol.layer == OcptFloorPlanLayer.cameras).toList(),
      characters: ownSymbols
          .where((symbol) => symbol.layer == OcptFloorPlanLayer.characters)
          .toList(),
      lights: ownSymbols.where((symbol) => symbol.layer == OcptFloorPlanLayer.lights).toList(),
      handProps: ownSymbols.where((symbol) => symbol.layer == OcptFloorPlanLayer.props).toList(),
      arrows: ownArrows,
      otherSets: otherSets,
      isReadOnly: isReadOnly,
      onSymbolDeleteRequested: isReadOnly ? null : onSymbolDeleteRequested,
      onArrowDeleteRequested: isReadOnly ? null : onArrowDeleteRequested,
      onCameraFovChanged: isReadOnly
          ? null
          : (symbolId, fovDeg) => context.read<OcptShotListFloorPlanPlacementsBloc>().add(
              OcptShotListFloorPlanSymbolFovChangedEvent(symbolId: symbolId, fovDeg: fovDeg),
            ),
      selectedOverrideLevel: selectedOverrideLevel,
      onRestoreOverrideRequested: isReadOnly || selectedSymbolId == null
          ? null
          : () => context.read<OcptShotListFloorPlanPlacementsBloc>().add(
              OcptShotListFloorPlanSymbolRestoreRequestedEvent(symbolId: selectedSymbolId),
            ),
    );
  }
}
