// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_board.dart';

/// The storyboard view of the shot list mode: the selected sequence's shots as
/// [OcptStoryboardBoard] rows, wired to the mode bloc for what is shared (the shots, the selected
/// shot, the roles) and to [OcptShotListStoryboardBloc] for what the board does with its panels.
///
/// Every write is withheld (a null callback) under a version preview, which this reads from the
/// mode bloc: the view bloc has nothing to know about it. Deleting a panel is only *asked*, through
/// [onPanelDeleteRequested]: the mode owns the confirmation dialog.
class OcptStoryboardView extends StatelessWidget {
  /// The selected sequence, whose shots the board lists.
  final OcptShotSequence sequence;

  /// Called with the id of the panel the user asked to delete, once and only if deleting is
  /// allowed; the mode confirms it, then dispatches the deletion.
  final ValueChanged<String> onPanelDeleteRequested;

  /// Class constructor
  const OcptStoryboardView({
    super.key,
    required this.sequence,
    required this.onPanelDeleteRequested,
  });

  /// Build the storyboard view as an [OcptStoryboardBoard].
  @override
  Widget build(BuildContext context) {
    final modeBloc = context.read<OcptShotListBloc>();
    final storyboardBloc = context.read<OcptShotListStoryboardBloc>();
    final mode = context.watch<OcptShotListBloc>().state;
    final board = context.watch<OcptShotListStoryboardBloc>().state;
    final isReadOnly = mode.isPreviewingVersion;
    final tr = Tr.of(context);

    return OcptStoryboardBoard(
      shots: sequence.shots,
      roles: mode.roles,
      panelsByShotId: mode.storyboardSnapshot?.panelsByShotId ?? const {},
      panelSize: board.boardPanelSize,
      selectedShotId: mode.selectedShotId,
      selectedPanelId: board.selectedPanelId,
      isReadOnly: isReadOnly,
      onShotSelected: (shotId) => modeBloc.add(OcptShotListShotSelectedEvent(shotId: shotId)),
      onPanelSelected: (panelId) =>
          storyboardBloc.add(OcptShotListPanelSelectedEvent(panelId: panelId)),
      onImportRequested: isReadOnly
          ? null
          : (shotId) => storyboardBloc.add(
              OcptShotListPanelImportRequestedEvent(
                shotId: shotId,
                fileTypeLabel: tr.shotListBoardImageFileTypeLabel,
              ),
            ),
      onReplaceRequested: isReadOnly
          ? null
          : (panelId) => storyboardBloc.add(
              OcptShotListPanelReplaceRequestedEvent(
                panelId: panelId,
                fileTypeLabel: tr.shotListBoardImageFileTypeLabel,
              ),
            ),
      onDeleteRequested: isReadOnly ? null : onPanelDeleteRequested,
      onPanelReordered: isReadOnly
          ? null
          : (shotId, panelId, newPosition) => storyboardBloc.add(
              OcptShotListPanelReorderedEvent(
                shotId: shotId,
                panelId: panelId,
                newPosition: newPosition,
              ),
            ),
      activeAnnotationTool: board.activeAnnotationTool,
      selectedAnnotationId: board.selectedAnnotationId,
      onAnnotationDrawn: isReadOnly
          ? null
          : (panelId, kind, x1, y1, x2, y2) => storyboardBloc.add(
              OcptShotListAnnotationDrawnEvent(
                panelId: panelId,
                kind: kind,
                x1: x1,
                y1: y1,
                x2: x2,
                y2: y2,
              ),
            ),
      onLabelPlaced: isReadOnly
          ? null
          : (panelId, x, y) => storyboardBloc.add(
              OcptShotListAnnotationPlacedEvent(panelId: panelId, x1: x, y1: y),
            ),
      onAnnotationSelected: (annotationId) =>
          storyboardBloc.add(OcptShotListAnnotationSelectedEvent(annotationId: annotationId)),
    );
  }
}
