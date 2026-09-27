// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A move, rotate or resize of a **set-scope** symbol of a set linked to two or more sequences,
/// held by `OcptShotListState.pendingFloorPlanScopeDecision` while the scope bubble asks which of
/// the two the write actually means (`docs/plans/storyboard.md`, §10.4): write it onto the
/// original, shared by [sequenceCount] sequences ("Every sequence"), or onto a scene-scope
/// override of the focused sequence alone ("Only sequence n") — or `Cancel`, which simply drops
/// this without writing anything at all.
///
/// [xM]/[yM]/[widthM]/[heightM]/[rotationDeg] are each null while the triggering gesture (a move,
/// a rotate or a resize) left that particular field untouched — a move sets only [xM]/[yM], a
/// resize only [widthM]/[heightM], a rotate only [rotationDeg] — so neither outcome ever writes an
/// explicit size or rotation onto a symbol that never had one of its own.
class OcptFloorPlanScopeDecision extends Equatable {
  /// The id of the set-scope symbol being moved, rotated or resized — the original the "Every
  /// sequence" outcome writes onto directly, and the "Only sequence n" outcome's own
  /// `overridesSymbolId`.
  final String symbolId;

  /// The Resources set [symbolId] belongs to.
  final String setId;

  /// How many live sequences the symbol's own set is linked to — the scope bubble's own `Every
  /// sequence ({count})` label.
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
    required this.sequenceCount,
    this.xM,
    this.yM,
    this.widthM,
    this.heightM,
    this.rotationDeg,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanScopeDecision(symbolId: $symbolId, sequenceCount: $sequenceCount)";

  /// Object properties
  @override
  List<Object?> get props => [symbolId, setId, sequenceCount, xM, yM, widthM, heightM, rotationDeg];
}
