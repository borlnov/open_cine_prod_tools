// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';

/// A movement or camera-move arrow drawn between two symbols of the same floor plan set, as
/// `OcptFloorPlanService.loadFloorPlans` builds it from its stored row.
///
/// [shotId] is always set — see `OcptFloorPlanArrowsTable`'s own doc comment: an arrow is a
/// movement, and a movement belongs to a shot even when either symbol it connects is
/// sequence-scoped.
class OcptFloorPlanArrow extends Equatable {
  /// The stable, unique id of this arrow (a UUID).
  final String id;

  /// The set this arrow is drawn on.
  final String setId;

  /// The shot this movement belongs to.
  final String shotId;

  /// Whether this arrow is a movement between two symbols or a camera move.
  final OcptFloorPlanArrowKind kind;

  /// The symbol this arrow starts from.
  final String fromSymbolId;

  /// The symbol this arrow points to.
  final String toSymbolId;

  /// The arrow's own text label, free text.
  final String label;

  /// A curved arrow's bezier control point X, in metres — null meaning a straight arrow. See
  /// `OcptFloorPlanArrowsTable.ctrlXM`'s own doc comment.
  final double? ctrlXM;

  /// A curved arrow's bezier control point Y, in metres. See [ctrlXM].
  final double? ctrlYM;

  /// Class constructor
  const OcptFloorPlanArrow({
    required this.id,
    required this.setId,
    required this.shotId,
    required this.kind,
    required this.fromSymbolId,
    required this.toSymbolId,
    required this.label,
    required this.ctrlXM,
    required this.ctrlYM,
  });

  /// Builds an [OcptFloorPlanArrow] from its stored [row].
  factory OcptFloorPlanArrow.fromRow(OcptFloorPlanArrowRow row) => OcptFloorPlanArrow(
    id: row.id,
    setId: row.setId,
    shotId: row.shotId,
    kind: row.kind,
    fromSymbolId: row.fromSymbolId,
    toSymbolId: row.toSymbolId,
    label: row.label,
    ctrlXM: row.ctrlXM,
    ctrlYM: row.ctrlYM,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptFloorPlanArrow(id: $id, setId: $setId, shotId: $shotId, kind: $kind)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    setId,
    shotId,
    kind,
    fromSymbolId,
    toSymbolId,
    label,
    ctrlXM,
    ctrlYM,
  ];
}
