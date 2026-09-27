// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';

/// A move, rotate or resize awaiting the scope bubble's own answer, held by
/// `OcptShotListState.pendingFloorPlanScopeDecision` (`docs/plans/storyboard.md`, §10.4, extended
/// to a second level by §10.5) — which of two levels [level] says:
///
/// - [OcptFloorPlanOverrideLevel.sequence]: a **set-scope** symbol of a set linked to two or more
///   sequences. `Every sequence` writes onto [symbolId] directly; `Only sequence n` writes a
///   scene-scope override of the focused sequence alone.
/// - [OcptFloorPlanOverrideLevel.shot]: a **scene-scope** symbol (a prop, the sequence's own
///   furniture, or itself a sequence-scope override) of a sequence with two or more shots. `The
///   whole sequence` writes onto [symbolId] directly; `Only shot n` writes a shot-scope override
///   of the focused shot alone.
///
/// Either way, `Cancel` simply drops this without writing anything at all — the element snaps
/// back.
///
/// [xM]/[yM]/[widthM]/[heightM]/[rotationDeg] are each null while the triggering gesture (a move,
/// a rotate or a resize) left that particular field untouched — a move sets only [xM]/[yM], a
/// resize only [widthM]/[heightM], a rotate only [rotationDeg] — so neither outcome ever writes an
/// explicit size or rotation onto a symbol that never had one of its own.
class OcptFloorPlanScopeDecision extends Equatable {
  /// The id of the symbol being moved, rotated or resized — the original the broader outcome
  /// (`Every sequence`/`The whole sequence`) writes onto directly, and the narrower one's
  /// (`Only sequence n`/`Only shot n`) own `overridesSymbolId`.
  final String symbolId;

  /// The Resources set [symbolId] belongs to.
  final String setId;

  /// Which of the two levels this decision is at. See this class's own doc comment.
  final OcptFloorPlanOverrideLevel level;

  /// How many live sequences the symbol's own set is linked to — the scope bubble's own `Every
  /// sequence ({count})` label. Meaningless (0) at [OcptFloorPlanOverrideLevel.shot], whose own
  /// broader outcome carries no count of its own (`The whole sequence`).
  final int sequenceCount;

  /// The symbol's own new centre X, in metres — null unless a move triggered this decision.
  final double? xM;

  /// The symbol's own new centre Y, in metres. See [xM].
  final double? yM;

  /// The symbol's own new footprint width, in metres — null unless a resize triggered this
  /// decision.
  final double? widthM;

  /// The symbol's own new footprint height, in metres. See [widthM].
  final double? heightM;

  /// The symbol's own new rotation, in degrees — null unless a rotate triggered this decision.
  final double? rotationDeg;

  /// Class constructor
  const OcptFloorPlanScopeDecision({
    required this.symbolId,
    required this.setId,
    required this.level,
    this.sequenceCount = 0,
    this.xM,
    this.yM,
    this.widthM,
    this.heightM,
    this.rotationDeg,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptFloorPlanScopeDecision(symbolId: $symbolId, level: $level)";

  /// Object properties
  @override
  List<Object?> get props => [
    symbolId,
    setId,
    level,
    sequenceCount,
    xM,
    yM,
    widthM,
    heightM,
    rotationDeg,
  ];
}
