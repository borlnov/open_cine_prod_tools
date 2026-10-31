// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/events/breakdown_base_event.dart';

/// The events that move the mode's shared selection: the selected scene and the selected target.
sealed class OcptBreakdownSelectionEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownSelectionEvent();
}

/// Selects scene [sceneId], dispatched by a row of `OcptBreakdownScenePanel` — the left dock's own
/// list, which selects a scene without touching the right dock.
///
/// A scene id that no longer exists in the current snapshot (a stale click on a list rebuilt
/// underneath) is ignored rather than selecting nothing.
class OcptBreakdownSceneSelectedEvent extends OcptBreakdownSelectionEvent {
  /// The id of the scene to select.
  final String sceneId;

  /// Class constructor
  const OcptBreakdownSceneSelectedEvent({required this.sceneId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId];
}

/// Selects scene [sceneId] **and shows its own breakdown sheet**, dispatched by a click on one of
/// `OcptBreakdownScriptView`'s own heading rows.
///
/// The centre views' own convention, which [OcptBreakdownTargetSelectedEvent] already follows for a
/// tagged word and the recap table for a row: a click in the script lands the user on the sheet of
/// whatever they clicked, without a second gesture. So this additionally drops the selected target
/// — the scene's sheet is what the inspector shows precisely while no target is selected — and
/// opens the right dock on its `Inspector` tab. The left dock's own list deliberately does neither
/// (see [OcptBreakdownSceneSelectedEvent]): browsing scenes there is reading, not asking for a
/// sheet.
class OcptBreakdownSceneHeadingSelectedEvent extends OcptBreakdownSelectionEvent {
  /// The id of the scene whose heading was clicked.
  final String sceneId;

  /// Class constructor
  const OcptBreakdownSceneHeadingSelectedEvent({required this.sceneId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId];
}

/// Selects target [targetKind]/[targetId] in the inspector, dispatched by a click on one of its
/// tagged words in `OcptBreakdownScriptView` — [sceneId] is the scene that click happened in, which
/// this event also selects, so the left dock and the sheet stay in step. Opens the right dock on
/// the `Inspector` tab.
///
/// Selecting writes nothing to the project database, so this is never withheld for a previewed
/// version's sake.
class OcptBreakdownTargetSelectedEvent extends OcptBreakdownSelectionEvent {
  /// The kind of the target to select.
  final OcptBreakdownTargetKind targetKind;

  /// The id of the target to select.
  final String targetId;

  /// The id of the scene the click happened in.
  final String sceneId;

  /// Class constructor
  const OcptBreakdownTargetSelectedEvent({
    required this.targetKind,
    required this.targetId,
    required this.sceneId,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, targetKind, targetId, sceneId];
}

/// Clears the currently selected target, dispatched by `OcptBreakdownTargetInspector`'s own
/// "back to the scene" affordance.
class OcptBreakdownTargetSelectionClearedEvent extends OcptBreakdownSelectionEvent {
  /// Class constructor
  const OcptBreakdownTargetSelectionClearedEvent();
}

/// Selects the scene of one of the selected target's occurrences, dispatched by a row of
/// `OcptBreakdownTargetInspector`'s own occurrences section.
class OcptBreakdownOccurrenceSelectedEvent extends OcptBreakdownSelectionEvent {
  /// The id of the occurrence's own scene.
  final String sceneId;

  /// Class constructor
  const OcptBreakdownOccurrenceSelectedEvent({required this.sceneId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId];
}
