// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';

/// One arrow shape a floor plan sheet draws: a `floor_plan_arrows` row resolved down to the metre
/// coordinates of the two symbols it connects.
class OcptFloorPlanArrowShape extends Equatable {
  /// The id of the `floor_plan_arrows` row this shape was built from.
  final String arrowId;

  /// The shot this movement belongs to.
  final String shotId;

  /// Whether this is a movement or a camera-move arrow.
  final OcptFloorPlanArrowKind kind;

  /// The starting symbol's centre X, in metres.
  final double fromXM;

  /// The starting symbol's centre Y, in metres.
  final double fromYM;

  /// The ending symbol's centre X, in metres.
  final double toXM;

  /// The ending symbol's centre Y, in metres.
  final double toYM;

  /// The arrow's own free-text label.
  final String label;

  /// The colour this shape draws with.
  final int colorArgb;

  /// Whether this shape belongs to the previous or next shot under a shot focus. See
  /// [OcptFloorPlanSymbolShape.isGhost].
  final bool isGhost;

  /// A curved arrow's bezier control point X, in metres — null meaning a straight arrow. See
  /// `OcptFloorPlanArrow.ctrlXM`'s own doc comment; a painter draws a quadratic bezier through
  /// `(ctrlXM, ctrlYM)` when set, a straight line from `(fromXM, fromYM)` to `(toXM, toYM)`
  /// otherwise.
  final double? ctrlXM;

  /// A curved arrow's bezier control point Y, in metres. See [ctrlXM].
  final double? ctrlYM;

  /// Class constructor
  const OcptFloorPlanArrowShape({
    required this.arrowId,
    required this.shotId,
    required this.kind,
    required this.fromXM,
    required this.fromYM,
    required this.toXM,
    required this.toYM,
    required this.label,
    required this.colorArgb,
    required this.isGhost,
    required this.ctrlXM,
    required this.ctrlYM,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptFloorPlanArrowShape(arrowId: $arrowId, kind: $kind, isGhost: $isGhost)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [
    arrowId,
    shotId,
    kind,
    fromXM,
    fromYM,
    toXM,
    toYM,
    label,
    colorArgb,
    isGhost,
    ctrlXM,
    ctrlYM,
  ];
}
