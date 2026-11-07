// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_glyph_kind.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_camera_label.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_character_colour.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';

/// One symbol shape a floor plan sheet draws: a frozen, ready-to-paint copy of a
/// `floor_plan_symbols` row, carrying the colour it draws with and, for a camera, the label
/// [ocptFloorPlanCameraLabelOf] derives.
class OcptFloorPlanSymbolShape extends Equatable {
  /// The id of the `floor_plan_symbols` row this shape was built from.
  final String symbolId;

  /// The shot this symbol belongs to, or null on a sequence layer.
  final String? shotId;

  /// Which layer this symbol is drawn on.
  final OcptFloorPlanLayer layer;

  /// The symbol's centre X, in metres.
  final double xM;

  /// The symbol's centre Y, in metres.
  final double yM;

  /// The symbol's rotation, in degrees.
  final double rotationDeg;

  /// The symbol's footprint width, in metres — its own `widthM`, or the layer's default footprint
  /// when it has none of its own.
  final double widthM;

  /// The symbol's footprint height, in metres. See [widthM].
  final double heightM;

  /// A camera's field-of-view wedge, in degrees, or null for every other layer (or a camera left at
  /// the drawing default). The symbol's own raw stored value — see [cameraFovWedgeDeg] for the
  /// resolved angle a painter actually draws the wedge at.
  final double? fovDeg;

  /// A camera's field-of-view wedge reach, in metres — its own axial height/depth, from the lens to
  /// the wedge's own far chord, never the length of either angled edge — or null for every other
  /// layer (or a camera left at the drawing default). The symbol's own raw stored value — see
  /// [cameraFovWedgeReachM] for the resolved reach a painter actually draws the wedge at.
  final double? fovReachM;

  /// The symbol's own free-text label.
  final String label;

  /// The colour this shape draws with: [ocptFloorPlanLayerColorArgb] for every layer but
  /// [OcptFloorPlanLayer.characters], whose own colour [ocptFloorPlanCharacterColourOf] derives
  /// from [label] instead — the one colour both renderers read rather than re-deriving.
  final int colorArgb;

  /// A camera symbol's derived letter/number label (`3`, `3A`, `3B`), or null for every other
  /// layer, or for a camera whose shot has no known rank yet.
  final String? cameraLabel;

  /// Whether this shape belongs to the previous or next shot under a shot focus — drawn as an onion
  /// skin the renderer draws at reduced opacity, never as a claim about the current shot.
  final bool isGhost;

  /// Which glyph this shape draws as — see [OcptFloorPlanSymbolGlyphKind].
  final OcptFloorPlanSymbolGlyphKind glyphKind;

  /// A camera symbol's own field-of-view wedge angle, in degrees, already resolved to
  /// [ocptFloorPlanDefaultCameraFovDeg] when the symbol carries no [fovDeg] of its own — null
  /// whenever no wedge should be drawn at all: every non-camera symbol, and a camera symbol while
  /// the sheet was built with `showFieldOfView: false` (`OcptFloorPlanSheet.of`'s own parameter). A
  /// painter draws the wedge exactly when this is non-null, with no default of its own to apply.
  final double? cameraFovWedgeDeg;

  /// A camera symbol's own field-of-view wedge reach, in metres — its own axial height/depth,
  /// already resolved to [ocptFloorPlanCameraFovWedgeLengthM] when the symbol carries no
  /// [fovReachM] of its own — null under the very same condition as [cameraFovWedgeDeg], which it
  /// always accompanies.
  final double? cameraFovWedgeReachM;

  /// A set-element symbol's own drawn primitive, resolved to
  /// [OcptFloorPlanSetElementShape.freeform] when the symbol carries none of its own — null for
  /// every symbol whose [glyphKind] isn't [OcptFloorPlanSymbolGlyphKind.setElement].
  final OcptFloorPlanSetElementShape? setElementShape;

  /// Whether this shape is a **live, visible** override of an original one level up (a scene-scope
  /// override of a set-scope original, or a shot-scope override of a scene-scope symbol) —
  /// drawn with a dashed outline and a small pin badge, still fully editable within its own
  /// sequence or shot. Mutually exclusive with [isOverriddenOriginalGhost] and
  /// [isHiddenOverrideGhost]. See [overrideLevel] for which of the two levels this is.
  final bool isOverride;

  /// Whether this shape is the **faint, non-interactive** ghost of an original replaced, for this
  /// sequence or shot, by a live *visible* override — drawn at the original's own geometry,
  /// [symbolId] naming the **original** (never selectable: `OcptFloorPlanCanvas` excludes it from
  /// hit-testing entirely). See [isOverride].
  final bool isOverriddenOriginalGhost;

  /// Whether this shape is the **faint, selectable** ghost of an original masked, for this
  /// sequence or shot, by a **hidden** override — drawn at the original's own geometry, but
  /// [symbolId] naming the **override** itself (not the original), so selecting it lets the
  /// inspector offer `Restore`. See [isOverride].
  final bool isHiddenOverrideGhost;

  /// Which level [isOverride]/[isOverriddenOriginalGhost]/[isHiddenOverrideGhost] belongs to, or
  /// null while none of the three is set — see [OcptFloorPlanOverrideLevel]'s own doc comment.
  final OcptFloorPlanOverrideLevel? overrideLevel;

  /// Class constructor
  const OcptFloorPlanSymbolShape({
    required this.symbolId,
    required this.shotId,
    required this.layer,
    required this.xM,
    required this.yM,
    required this.rotationDeg,
    required this.widthM,
    required this.heightM,
    required this.fovDeg,
    required this.fovReachM,
    required this.label,
    required this.colorArgb,
    required this.cameraLabel,
    required this.isGhost,
    required this.glyphKind,
    required this.cameraFovWedgeDeg,
    required this.cameraFovWedgeReachM,
    required this.setElementShape,
    this.isOverride = false,
    this.isOverriddenOriginalGhost = false,
    this.isHiddenOverrideGhost = false,
    this.overrideLevel,
  });

  /// Return a copy of this shape with [symbolId], the three override-marking flags and
  /// [overrideLevel] overridden — the only fields `OcptFloorPlanSheet.of` ever needs to adjust
  /// after the fact, since every other field is already resolved by [OcptFloorPlanSheet._shapeOf].
  OcptFloorPlanSymbolShape copyWith({
    String? symbolId,
    bool? isOverride,
    bool? isOverriddenOriginalGhost,
    bool? isHiddenOverrideGhost,
    OcptFloorPlanOverrideLevel? overrideLevel,
    bool forceOverrideLevelValue = false,
  }) => OcptFloorPlanSymbolShape(
    symbolId: symbolId ?? this.symbolId,
    shotId: shotId,
    layer: layer,
    xM: xM,
    yM: yM,
    rotationDeg: rotationDeg,
    widthM: widthM,
    heightM: heightM,
    fovDeg: fovDeg,
    fovReachM: fovReachM,
    label: label,
    colorArgb: colorArgb,
    cameraLabel: cameraLabel,
    isGhost: isGhost,
    glyphKind: glyphKind,
    cameraFovWedgeDeg: cameraFovWedgeDeg,
    cameraFovWedgeReachM: cameraFovWedgeReachM,
    setElementShape: setElementShape,
    isOverride: isOverride ?? this.isOverride,
    isOverriddenOriginalGhost: isOverriddenOriginalGhost ?? this.isOverriddenOriginalGhost,
    isHiddenOverrideGhost: isHiddenOverrideGhost ?? this.isHiddenOverrideGhost,
    overrideLevel: overrideLevel ?? (forceOverrideLevelValue ? null : this.overrideLevel),
  );

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanSymbolShape(symbolId: $symbolId, layer: $layer, isGhost: $isGhost)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [
    symbolId,
    shotId,
    layer,
    xM,
    yM,
    rotationDeg,
    widthM,
    heightM,
    fovDeg,
    fovReachM,
    label,
    colorArgb,
    cameraLabel,
    isGhost,
    glyphKind,
    cameraFovWedgeDeg,
    cameraFovWedgeReachM,
    setElementShape,
    isOverride,
    isOverriddenOriginalGhost,
    isHiddenOverrideGhost,
    overrideLevel,
  ];
}
