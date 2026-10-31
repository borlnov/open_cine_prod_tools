// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart'
    show OcptFloorPlanCanvasPainter;

/// A live, in-progress edit of one symbol's geometry — the drag preview `OcptFloorPlanCanvas` feeds
/// into [OcptFloorPlanCanvasPainter] so the shape being dragged redraws every frame without a
/// database write, or a bloc emission, per frame.
class OcptFloorPlanSymbolLiveOverride {
  /// The id of the symbol being edited.
  final String symbolId;

  /// The symbol's live centre X, in metres.
  final double xM;

  /// The symbol's live centre Y, in metres.
  final double yM;

  /// The symbol's live footprint width, in metres.
  final double widthM;

  /// The symbol's live footprint height, in metres.
  final double heightM;

  /// The symbol's live rotation, in degrees.
  final double rotationDeg;

  /// The symbol's live field-of-view wedge angle, in degrees, while its own edge handle is being
  /// dragged — null for every other kind of drag (move, resize, rotate, tip), in which case the
  /// painter keeps reading the symbol's own already-resolved `cameraFovWedgeDeg`.
  final double? fovDeg;

  /// The symbol's live field-of-view wedge reach, in metres, while its own tip handle is being
  /// dragged — null for every other kind of drag, in which case the painter keeps reading the
  /// symbol's own already-resolved `cameraFovWedgeReachM`.
  final double? fovReachM;

  /// Class constructor
  const OcptFloorPlanSymbolLiveOverride({
    required this.symbolId,
    required this.xM,
    required this.yM,
    required this.widthM,
    required this.heightM,
    required this.rotationDeg,
    this.fovDeg,
    this.fovReachM,
  });
}
