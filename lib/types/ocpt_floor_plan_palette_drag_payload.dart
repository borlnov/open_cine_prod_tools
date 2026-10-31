// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';

/// One palette entry's own drag-and-drop payload (the typed set tools): which [tool] a drop
/// places, and — for one of the typed [OcptFloorPlanTool.setElement] entries
/// (wall/door/furniture/freeform) — which [setElementShape] it places, which [sceneScope] it
/// places at (the `Set` group's own four entries carry [OcptFloorPlanScope.set], the `Sequence`
/// group's own furniture/freeform pair carry [OcptFloorPlanScope.scene]), or — for a
/// [OcptFloorPlanTool.prop] chip — which [label] it places.
/// Carried on the drag itself rather than read back from a click-to-arm state, since a drag never
/// taps its source first: `OcptFloorPlanPalette`'s `Draggable<OcptFloorPlanPaletteDragPayload>` and
/// `OcptFloorPlanCanvas`'s own `DragTarget` of the same type are what carry it end to end.
class OcptFloorPlanPaletteDragPayload extends Equatable {
  /// The tool a drop of this payload places.
  final OcptFloorPlanTool tool;

  /// The set-element shape a drop of this payload places, or null for every entry but the typed
  /// set-element ones.
  final OcptFloorPlanSetElementShape? setElementShape;

  /// The scope a [OcptFloorPlanTool.setElement] drop places at ([OcptFloorPlanScope.set] or
  /// [OcptFloorPlanScope.scene]) — null for every entry but the typed set-element ones, which
  /// always set it.
  final OcptFloorPlanScope? sceneScope;

  /// A [OcptFloorPlanTool.prop] chip's own label — null for every other entry.
  final String? label;

  /// Class constructor
  const OcptFloorPlanPaletteDragPayload({
    required this.tool,
    this.setElementShape,
    this.sceneScope,
    this.label,
  });

  /// Object properties
  @override
  List<Object?> get props => [tool, setElementShape, sceneScope, label];
}
