// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_centre_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_columns_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_floor_plan_centre.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_floor_plan_set_tabs_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panel_size_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_export_share_anchor.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

/// What the shot list's centre shows under the role alert banners: the header (the view switch,
/// the sequence's own title/summary and whatever the active view needs), then the table, the board
/// or the floor plans, or the empty state while no sequence is selected.
///
/// A compact width ([isCompact]) shows the table regardless of `state.centreView`: the board and
/// the floor plans are large-screen views in v1, so the switch itself offers the table only and
/// this stays in lock-step with it rather than reading a second predicate.
///
/// Everything irreversible the views offer is only *asked*, through the `on…Requested` callbacks
/// below: the mode owns the confirmation dialogs and the export request, and hands each its answer
/// back as an event.
class OcptShotListSequenceBody extends StatelessWidget {
  /// The mode's state, which the selected sequence and the active view are read from.
  final OcptShotListState state;

  /// Whether the window is at a compact width, which forces the table.
  final bool isCompact;

  /// Called with the id of the panel the user asked to delete.
  final ValueChanged<String> onPanelDeleteRequested;

  /// Called with the id of the symbol the user asked to delete.
  final ValueChanged<String> onSymbolDeleteRequested;

  /// Called with the id of the set whose underlay the user asked to clear.
  final ValueChanged<String> onUnderlayClearRequested;

  /// Called with the id of the set the user asked to copy a shot's blocking onto.
  final ValueChanged<String> onCopyBlockingRequested;

  /// Called with the id of the set the user asked to unlink.
  final ValueChanged<String> onSetDeleteRequested;

  /// Called with the screen rectangle of the table's `Export XLSX` button, to anchor the share
  /// sheet to it.
  final ValueChanged<Rect?> onXlsxExportRequested;

  /// Class constructor
  const OcptShotListSequenceBody({
    super.key,
    required this.state,
    required this.isCompact,
    required this.onPanelDeleteRequested,
    required this.onSymbolDeleteRequested,
    required this.onUnderlayClearRequested,
    required this.onCopyBlockingRequested,
    required this.onSetDeleteRequested,
    required this.onXlsxExportRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final sequence = state.selectedSequence;

    if (sequence == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.movie_filter_outlined,
        message: tr.shotListNoSequenceSelectedHint,
      );
    }

    final isBoardShown = !isCompact && state.centreView == OcptShotListCentreView.board;
    final isFloorPlansShown = !isCompact && state.centreView == OcptShotListCentreView.floorPlans;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: OcptShotListCentreHeader(
            sequence: sequence,
            centreView: state.centreView,
            isBoardAvailable: !isCompact,
            isFloorPlansAvailable: !isCompact,
            boardPanelCount: state.boardPanelCountOfSelectedSequence,
            onCentreViewSelected: (view) => context.read<OcptShotListBloc>().add(
              OcptShotListCentreViewSelectedEvent(view: view),
            ),
            trailing: switch ((isBoardShown, isFloorPlansShown)) {
              (true, _) => BlocBuilder<OcptShotListStoryboardBloc, OcptShotListStoryboardState>(
                builder: (context, board) => OcptStoryboardPanelSizeMenu(
                  value: board.boardPanelSize,
                  onChanged: (size) => context.read<OcptShotListStoryboardBloc>().add(
                    OcptShotListPanelSizeChangedEvent(size: size),
                  ),
                ),
              ),
              (_, true) => OcptShotListFloorPlanSetTabsView(
                state: state,
                sequence: sequence,
                onCopyBlockingRequested: onCopyBlockingRequested,
                onSetDeleteRequested: onSetDeleteRequested,
              ),
              _ => _TableTrailingControls(
                state: state,
                onXlsxExportRequested: onXlsxExportRequested,
              ),
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
            child: switch ((isBoardShown, isFloorPlansShown)) {
              (true, _) => OcptStoryboardView(
                sequence: sequence,
                onPanelDeleteRequested: onPanelDeleteRequested,
              ),
              (_, true) => OcptShotListFloorPlanCentre(
                state: state,
                sequence: sequence,
                onSymbolDeleteRequested: onSymbolDeleteRequested,
                onUnderlayClearRequested: onUnderlayClearRequested,
              ),
              _ => OcptShotListTable(
                shots: sequence.shots,
                sequenceHeading: switch (sequence) {
                  OcptSceneShotSequence() => sequence.heading,
                  OcptOrphanShotSequence() => ocptShotListEmptyValue,
                },
                visibleColumns: state.visibleColumns,
                selectedShotId: state.selectedShotId,
                placementsByShotId: state.snapshot?.placementsByShotId ?? const {},
                onShotSelected: (shotId) => context.read<OcptShotListBloc>().add(
                  OcptShotListShotSelectedEvent(shotId: shotId),
                ),
              ),
            },
          ),
        ),
      ],
    );
  }
}

/// The table view's own trailing controls, unchanged from what `_SequenceHeader`'s row used to
/// build beside it: the `Columns ▾` menu and the `Export XLSX` button.
class _TableTrailingControls extends StatelessWidget {
  /// The mode's state, which the visible columns and the shot count are read from.
  final OcptShotListState state;

  /// See [OcptShotListSequenceBody.onXlsxExportRequested].
  final ValueChanged<Rect?> onXlsxExportRequested;

  /// Class constructor
  const _TableTrailingControls({required this.state, required this.onXlsxExportRequested});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OcptShotListColumnsMenu(
          visibleColumns: state.visibleColumns,
          onColumnToggled: (column) =>
              context.read<OcptShotListBloc>().add(OcptShotListColumnToggledEvent(column: column)),
        ),
        const SizedBox(width: 8),
        // Exports the whole shot list, not the sequence this header names: the button sits here
        // because the mock-up puts it next to the columns menu, not because it is scoped to what
        // the table below currently shows. Wrapped in its own Builder so the anchor handed to the
        // export is this button's own screen Rect, not some ancestor's.
        Builder(
          builder: (buttonContext) => OutlinedButton.icon(
            onPressed: state.totalShotCount > 0
                ? () => onXlsxExportRequested(ocptExportShareAnchorOf(buttonContext))
                : null,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(tr.shotListExportXlsxAction),
          ),
        ),
      ],
    );
  }
}
