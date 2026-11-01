// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panels_group.dart';

/// The inspector's board-only `leadingGroup`: the selected shot's own panels, each with its
/// comment field, the reorder affordance and a `Delete panel` action, followed by the selected
/// panel's own annotation section (the `Annotate` tool picker and its marks list).
///
/// Reads the panels from the mode bloc and everything the board does with them from
/// [OcptShotListStoryboardBloc], whose pending comments take the stored ones' place while typed.
/// Every write is withheld (a null callback) under a version preview. A deletion is only *asked*,
/// through [onPanelDeleteRequested] and [onAnnotationDeleteRequested]: the mode owns both
/// confirmation dialogs.
class OcptStoryboardPanelsView extends StatelessWidget {
  /// Called with the id of the panel the user asked to delete; the mode confirms it.
  final ValueChanged<String> onPanelDeleteRequested;

  /// Called with the id of the mark the user asked to delete; the mode confirms it.
  final ValueChanged<String> onAnnotationDeleteRequested;

  /// Class constructor
  const OcptStoryboardPanelsView({
    super.key,
    required this.onPanelDeleteRequested,
    required this.onAnnotationDeleteRequested,
  });

  /// Build the storyboard panels view as an [OcptStoryboardPanelsGroup].
  @override
  Widget build(BuildContext context) {
    final storyboardBloc = context.read<OcptShotListStoryboardBloc>();
    final mode = context.watch<OcptShotListBloc>().state;
    final board = context.watch<OcptShotListStoryboardBloc>().state;
    final selectedShot = mode.selectedShot;
    final isReadOnly = mode.isPreviewingVersion;

    return OcptStoryboardPanelsGroup(
      panels: mode.panelsOfSelectedShot,
      commentValueOf: (panelId) => _panelCommentValueOf(mode, board, panelId),
      isReadOnly: isReadOnly,
      onCommentChanged: isReadOnly
          ? null
          : (panelId, rawValue) => storyboardBloc.add(
              OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: rawValue),
            ),
      onReordered: isReadOnly || selectedShot == null
          ? null
          : (panelId, newPosition) => storyboardBloc.add(
              OcptShotListPanelReorderedEvent(
                shotId: selectedShot.id,
                panelId: panelId,
                newPosition: newPosition,
              ),
            ),
      onDeleteRequested: isReadOnly ? null : onPanelDeleteRequested,
      selectedPanelId: board.selectedPanelId,
      annotations: board.selectedPanelIn(mode)?.annotations ?? const <OcptStoryboardAnnotation>[],
      selectedAnnotationId: board.selectedAnnotationId,
      activeAnnotationTool: board.activeAnnotationTool,
      onToolChanged: isReadOnly
          ? null
          : (tool) => storyboardBloc.add(OcptShotListAnnotationToolSelectedEvent(tool: tool)),
      annotationTextValueOf: (annotationId) => _annotationTextValueOf(mode, board, annotationId),
      onAnnotationSelected: (annotationId) =>
          storyboardBloc.add(OcptShotListAnnotationSelectedEvent(annotationId: annotationId)),
      onAnnotationTextChanged: isReadOnly
          ? null
          : (annotationId, rawValue) => storyboardBloc.add(
              OcptShotListAnnotationTextChangedEvent(
                annotationId: annotationId,
                rawValue: rawValue,
              ),
            ),
      onAnnotationDeleteRequested: isReadOnly ? null : onAnnotationDeleteRequested,
    );
  }

  /// Get [panelId]'s current comment value: a pending edit still in the board's debounce, or the
  /// panel's own stored value.
  String _panelCommentValueOf(
    OcptShotListState mode,
    OcptShotListStoryboardState board,
    String panelId,
  ) {
    final pending = board.pendingFieldEdits[OcptShotListPanelCommentEditKey(panelId: panelId)];
    if (pending != null) {
      return pending;
    }

    for (final panel in mode.panelsOfSelectedShot) {
      if (panel.id == panelId) {
        return panel.comment;
      }
    }
    return "";
  }

  /// Get [annotationId]'s current text value: a pending edit still in the board's debounce, or the
  /// mark's own stored text — the annotation section's equivalent of [_panelCommentValueOf].
  String _annotationTextValueOf(
    OcptShotListState mode,
    OcptShotListStoryboardState board,
    String annotationId,
  ) {
    final pending =
        board.pendingFieldEdits[OcptShotListAnnotationTextEditKey(annotationId: annotationId)];
    if (pending != null) {
      return pending;
    }

    for (final annotation
        in board.selectedPanelIn(mode)?.annotations ?? const <OcptStoryboardAnnotation>[]) {
      if (annotation.id == annotationId) {
        return annotation.text;
      }
    }
    return "";
  }
}
