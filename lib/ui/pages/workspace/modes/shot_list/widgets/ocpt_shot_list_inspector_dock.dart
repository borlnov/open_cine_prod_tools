// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_placements_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_metadata_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panels_view.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

/// The shot list's tabbed right dock, the shell's `rightPanel`: the shot inspector, the shot's
/// metadata and the `Versions` tab, an [OcptShotListRightDock] drawing nothing while the dock is
/// closed.
///
/// The inspector's `leadingGroup` follows the active centre view exactly as the centre itself
/// does: `OcptStoryboardPanelsView` while the board is shown, `OcptShotListPlacementsView` on the
/// floor plans, null on the table — a compact width forces the table regardless of
/// `state.centreView`, so [isCompact] is read the same way here as the centre reads it.
///
/// Everything irreversible the views offer is only *asked*, through the `on…Requested` callbacks
/// below: the mode owns the confirmation dialogs.
class OcptShotListInspectorDock extends StatelessWidget {
  /// The mode's state, which the dock's tab, the selected shot and the active view are read from.
  final OcptShotListState state;

  /// Whether the window is at a compact width, which forces the table.
  final bool isCompact;

  /// Called with the id of the panel the user asked to delete.
  final ValueChanged<String> onPanelDeleteRequested;

  /// Called with the id of the annotation the user asked to delete.
  final ValueChanged<String> onAnnotationDeleteRequested;

  /// Called with the id of the symbol the user asked to delete.
  final ValueChanged<String> onSymbolDeleteRequested;

  /// Called with the id of the arrow the user asked to delete.
  final ValueChanged<String> onArrowDeleteRequested;

  /// Called with the shot the user asked to delete.
  final ValueChanged<OcptShot> onShotDeleteRequested;

  /// Class constructor
  const OcptShotListInspectorDock({
    super.key,
    required this.state,
    required this.isCompact,
    required this.onPanelDeleteRequested,
    required this.onAnnotationDeleteRequested,
    required this.onSymbolDeleteRequested,
    required this.onArrowDeleteRequested,
    required this.onShotDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return const SizedBox.shrink();
    }

    final selectedShot = state.selectedShot;
    final selectedSequence = state.selectedSequence;
    final sequenceDisplayNumber = ocptShotSequenceDisplayNumberOf(selectedSequence);
    final sequenceHeading = ocptShotSequenceHeadingOf(selectedSequence, selectedShot);
    final isBoardShown = !isCompact && state.centreView == OcptShotListCentreView.board;
    final isFloorPlansShown = !isCompact && state.centreView == OcptShotListCentreView.floorPlans;

    return OcptShotListRightDock(
      activeTab: rightDockTab,
      inspectorChild: OcptShotInspectorView(
        leadingGroup: isBoardShown
            ? OcptStoryboardPanelsView(
                onPanelDeleteRequested: onPanelDeleteRequested,
                onAnnotationDeleteRequested: onAnnotationDeleteRequested,
              )
            : isFloorPlansShown && selectedShot != null && state.selectedSet != null
            ? OcptShotListPlacementsView(
                state: state,
                onSymbolDeleteRequested: onSymbolDeleteRequested,
                onArrowDeleteRequested: onArrowDeleteRequested,
              )
            : null,
        onDeleteRequested: onShotDeleteRequested,
      ),
      metadataChild: OcptShotMetadataPanel(
        shot: selectedShot,
        sequenceDisplayNumber: sequenceDisplayNumber,
        sequenceHeading: sequenceHeading,
        placements: selectedShot == null
            ? const []
            : state.snapshot?.placementsByShotId[selectedShot.id] ?? const [],
      ),
      versionsChild: OcptShotListVersionsPanel(state: state),
      onTabSelected: (tab) =>
          context.read<OcptShotListBloc>().add(OcptShotListRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptShotListBloc>().add(const OcptShotListRightDockClosedEvent()),
    );
  }
}
