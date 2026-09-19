// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';

/// A camera, a character, a light, a set element or any other placed symbol of a floor plan case,
/// as `OcptFloorPlanService.loadFloorPlans` builds it from its stored row.
///
/// [shotId] is null exactly when [layer] is sequence-scoped
/// (`OcptFloorPlanLayerScope.isSequenceScoped`) — the invariant `OcptFloorPlanService` enforces at
/// every write; see `OcptFloorPlanSymbolsTable`'s own doc comment. A camera symbol's letter and a
/// shot layer's shot number are never stored on this model either: both are derived at read time,
/// by `ocptFloorPlanCameraLabelOf` and by the loaded shot's own rank.
class OcptFloorPlanSymbol extends Equatable {
  /// The stable, unique id of this symbol (a UUID).
  final String id;

  /// The case this symbol is placed on.
  final String caseId;

  /// The shot this symbol belongs to — null on a sequence layer, set on a shot layer.
  final String? shotId;

  /// Which layer this symbol is drawn on.
  final OcptFloorPlanLayer layer;

  /// The draw order, and — for a [OcptFloorPlanLayer.cameras] symbol — the rank its letter is
  /// derived from.
  final String sortKey;

  /// The symbol's centre X, in metres.
  final double xM;

  /// The symbol's centre Y, in metres.
  final double yM;

  /// The symbol's rotation, in degrees.
  final double rotationDeg;

  /// A set element's footprint width, in metres — null on every other layer in v1.
  final double? widthM;

  /// A set element's footprint height, in metres. See [widthM].
  final double? heightM;

  /// A camera's field-of-view wedge, in degrees — null meaning the drawing's own default.
  final double? fovDeg;

  /// The text label this symbol carries.
  final String label;

  /// Class constructor
  const OcptFloorPlanSymbol({
    required this.id,
    required this.caseId,
    required this.shotId,
    required this.layer,
    required this.sortKey,
    required this.xM,
    required this.yM,
    required this.rotationDeg,
    required this.widthM,
    required this.heightM,
    required this.fovDeg,
    required this.label,
  });

  /// Builds an [OcptFloorPlanSymbol] from its stored [row].
  factory OcptFloorPlanSymbol.fromRow(OcptFloorPlanSymbolRow row) => OcptFloorPlanSymbol(
    id: row.id,
    caseId: row.caseId,
    shotId: row.shotId,
    layer: row.layer,
    sortKey: row.sortKey,
    xM: row.xM,
    yM: row.yM,
    rotationDeg: row.rotationDeg,
    widthM: row.widthM,
    heightM: row.heightM,
    fovDeg: row.fovDeg,
    label: row.label,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanSymbol(id: $id, caseId: $caseId, shotId: $shotId, layer: $layer)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    caseId,
    shotId,
    layer,
    sortKey,
    xM,
    yM,
    rotationDeg,
    widthM,
    heightM,
    fovDeg,
    label,
  ];
}
