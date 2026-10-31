// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_panel.dart';

/// The sequence tree, the shell's `leftPanel`: an [OcptShotListSequencePanel] wired to the mode
/// bloc, which the mode only draws while the panel is visible.
///
/// `+ Shot` is wired only when the selected sequence is a real screenplay scene: the orphan
/// group is where shots land when their scene disappears, never where new ones are authored.
/// Neither it nor the orphan group's delete buttons are wired at all while a version is being
/// previewed: the tree is then a way of reading that version, not of changing it. Deleting an
/// orphaned shot is only *asked*, through [onOrphanedShotDeleteRequested]: the mode owns the
/// confirmation dialog.
class OcptShotListSequenceDock extends StatelessWidget {
  /// The mode's state, which the sequences and the selections are read from.
  final OcptShotListState state;

  /// Called with the id of the orphaned shot the user asked to delete.
  final ValueChanged<String> onOrphanedShotDeleteRequested;

  /// Class constructor
  const OcptShotListSequenceDock({
    super.key,
    required this.state,
    required this.onOrphanedShotDeleteRequested,
  });

  @override
  Widget build(BuildContext context) => OcptShotListSequencePanel(
    sequences: state.sequences,
    totalShotCount: state.totalShotCount,
    selectedSequenceId: state.selectedSequenceId,
    selectedShotId: state.selectedShotId,
    onSequenceSelected: (sequenceId) => context.read<OcptShotListBloc>().add(
      OcptShotListSequenceSelectedEvent(sequenceId: sequenceId),
    ),
    onShotSelected: (shotId) =>
        context.read<OcptShotListBloc>().add(OcptShotListShotSelectedEvent(shotId: shotId)),
    onShotCreated: state.selectedSequence is OcptSceneShotSequence && !state.isPreviewingVersion
        ? () => context.read<OcptShotListBloc>().add(const OcptShotListShotCreationRequestedEvent())
        : null,
    onOrphanedShotDeleted: state.isPreviewingVersion ? null : onOrphanedShotDeleteRequested,
  );
}
