// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListBloc` about creating and deleting shots.
sealed class OcptShotListShotEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListShotEvent();
}

/// Request creating a new shot at the end of the selected sequence, then selecting it.
///
/// Does nothing while no sequence is selected, or while the selected one is the orphan group: a
/// shot only ever exists inside a real screenplay scene, and the orphan group is where shots go
/// when their scene disappears, never where new ones are authored.
class OcptShotListShotCreationRequestedEvent extends OcptShotListShotEvent {
  /// Class constructor
  const OcptShotListShotCreationRequestedEvent();
}

/// Request deleting shot [shotId], dispatched once the inspector's own confirmation dialog has
/// already confirmed it. Renumbers the remaining shots of its group and clears the selection if
/// [shotId] was the selected shot (the sequence stays selected).
class OcptShotListShotDeletionRequestedEvent extends OcptShotListShotEvent {
  /// The id of the shot to delete.
  final String shotId;

  /// Class constructor
  const OcptShotListShotDeletionRequestedEvent({required this.shotId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId];
}
