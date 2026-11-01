// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_symbol_drag_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_underlay_drag_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_gestures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';

/// The live state of the drags in progress on a floor plan canvas: the dragged symbol's geometry,
/// the underlay's frame and the dragged arrow's control point, updated every frame of a drag with
/// no database write and no bloc emission until the drag ends.
///
/// Like `OcptFloorPlanViewportController`, it is owned by the canvas widget and notifies it on
/// every change, so a drag redraws the canvas alone. The `end…` methods clear the drag and hand the
/// settled values back: what they mean (move, duplicate, resize…) is for the canvas to report.
class OcptFloorPlanCanvasDragController extends ChangeNotifier {
  /// The kind of symbol drag in progress, or null while none is.
  OcptFloorPlanSymbolDragKind? _dragKind;

  /// Whether the symbol drag in progress duplicates the symbol instead of moving it.
  bool _isDuplicatingDrag;

  /// The dragged symbol's live geometry, exposed through [liveOverride].
  OcptFloorPlanSymbolLiveOverride? _liveOverride;

  /// The kind of underlay drag in progress, or null while none is.
  OcptFloorPlanUnderlayDragKind? _underlayDragKind;

  /// The underlay's live frame, exposed through [liveUnderlayFrame].
  ({double xM, double yM, double widthM, double heightM})? _liveUnderlayFrame;

  /// The id of the arrow whose handle is dragged, exposed through [draggedArrowId].
  String? _draggedArrowId;

  /// The dragged arrow's live control point, exposed through [liveArrowCtrl].
  ({double xM, double yM})? _liveArrowCtrl;

  /// The dragged symbol's live geometry, updated every frame of the drag, or null while no symbol
  /// is being dragged. See [OcptFloorPlanSymbolLiveOverride].
  OcptFloorPlanSymbolLiveOverride? get liveOverride => _liveOverride;

  /// The underlay's own live frame while it is being moved or resized, or null while it isn't.
  ({double xM, double yM, double widthM, double heightM})? get liveUnderlayFrame =>
      _liveUnderlayFrame;

  /// The id of the arrow whose own midpoint handle is currently being dragged, or null while none
  /// is — alongside [liveArrowCtrl], which carries its live control point.
  String? get draggedArrowId => _draggedArrowId;

  /// The dragged arrow's own live bezier control point (metres), updated every frame of the drag.
  ({double xM, double yM})? get liveArrowCtrl => _liveArrowCtrl;

  /// Class constructor
  OcptFloorPlanCanvasDragController() : _isDuplicatingDrag = false;

  /// Starts a move drag on [symbol], arming the live preview at its own stored geometry.
  /// [isDuplicating] (`Alt` held at the start) makes it an `Alt`-drag duplicate: the live preview
  /// tracks the pointer exactly like a plain move, but [endSymbolDrag] reports it as a duplicate,
  /// leaving the source symbol at its own original position.
  void beginSymbolMove(OcptFloorPlanSymbolShape symbol, {required bool isDuplicating}) {
    _dragKind = OcptFloorPlanSymbolDragKind.move;
    _isDuplicatingDrag = isDuplicating;
    _liveOverride = OcptFloorPlanSymbolLiveOverride(
      symbolId: symbol.symbolId,
      xM: symbol.xM,
      yM: symbol.yM,
      widthM: symbol.widthM,
      heightM: symbol.heightM,
      rotationDeg: symbol.rotationDeg,
    );
    notifyListeners();
  }

  /// Starts a [kind] drag (resize, aim or field of view) on [symbol], arming the live preview at
  /// its own stored geometry, carrying the wedge's current [fovDeg] or [fovReachM] for the two
  /// field-of-view gestures.
  void beginSymbolDrag(
    OcptFloorPlanSymbolDragKind kind,
    OcptFloorPlanSymbolShape symbol, {
    double? fovDeg,
    double? fovReachM,
  }) {
    _dragKind = kind;
    _liveOverride = OcptFloorPlanSymbolLiveOverride(
      symbolId: symbol.symbolId,
      xM: symbol.xM,
      yM: symbol.yM,
      widthM: symbol.widthM,
      heightM: symbol.heightM,
      rotationDeg: symbol.rotationDeg,
      fovDeg: fovDeg,
      fovReachM: fovReachM,
    );
    notifyListeners();
  }

  /// Updates the live override's own move/resize geometry every frame of a symbol drag. See
  /// [ocptFloorPlanSymbolDraggedBy] for the frames [screenDelta] is expressed in.
  void updateSymbolDrag(String symbolId, Offset screenDelta, double zoom) {
    final override = _liveOverride;
    final kind = _dragKind;
    if (override == null || kind == null || override.symbolId != symbolId) {
      return;
    }

    final next = ocptFloorPlanSymbolDraggedBy(
      override: override,
      kind: kind,
      screenDelta: screenDelta,
      zoom: zoom,
    );
    if (next != null) {
      _liveOverride = next;
    }
    notifyListeners();
  }

  /// Updates the live override's own rotation (bearing) every frame of an aim-handle drag, **with
  /// [localPosition] already converted to canvas space**. [isSnapping] (`Shift` held) snaps the
  /// result to [ocptFloorPlanRotateSnapStepDeg]° steps.
  void updateRotateDrag(
    String symbolId,
    Offset localPosition,
    Size canvasSize,
    double zoom,
    Offset pan, {
    required bool isSnapping,
  }) {
    final override = _liveOverride;
    if (override == null || override.symbolId != symbolId) {
      return;
    }

    _liveOverride = ocptFloorPlanSymbolAimedAt(
      override: override,
      localPosition: localPosition,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
      isSnapping: isSnapping,
    );
    notifyListeners();
  }

  /// Updates the live override's own field-of-view angle every frame of an edge-handle drag. See
  /// [ocptFloorPlanSymbolFovDraggedTo].
  void updateFovDrag(
    String symbolId,
    Offset localPosition,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final override = _liveOverride;
    if (override == null || override.symbolId != symbolId) {
      return;
    }

    _liveOverride = ocptFloorPlanSymbolFovDraggedTo(
      override: override,
      localPosition: localPosition,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    notifyListeners();
  }

  /// Updates the live override's own field-of-view reach every frame of a tip-handle drag. See
  /// [ocptFloorPlanSymbolFovReachDraggedTo].
  void updateFovReachDrag(
    String symbolId,
    Offset localPosition,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final override = _liveOverride;
    if (override == null || override.symbolId != symbolId) {
      return;
    }

    _liveOverride = ocptFloorPlanSymbolFovReachDraggedTo(
      override: override,
      localPosition: localPosition,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    notifyListeners();
  }

  /// Clears the symbol drag in progress and returns what it settled on, or null when there was
  /// none: the gesture, the live geometry and whether it was an `Alt`-drag duplicate.
  ({
    OcptFloorPlanSymbolDragKind kind,
    OcptFloorPlanSymbolLiveOverride override,
    bool wasDuplicating,
  })?
  endSymbolDrag() {
    final override = _liveOverride;
    final kind = _dragKind;
    final wasDuplicating = _isDuplicatingDrag;
    _dragKind = null;
    _liveOverride = null;
    _isDuplicatingDrag = false;
    notifyListeners();

    if (override == null || kind == null) {
      return null;
    }
    return (kind: kind, override: override, wasDuplicating: wasDuplicating);
  }

  /// Starts an underlay [kind] drag at [floorPlanSet]'s own stored frame.
  void beginUnderlayDrag(OcptFloorPlanUnderlayDragKind kind, OcptFloorPlanSet floorPlanSet) {
    _underlayDragKind = kind;
    _liveUnderlayFrame = (
      xM: floorPlanSet.underlayXM ?? 0,
      yM: floorPlanSet.underlayYM ?? 0,
      widthM: floorPlanSet.underlayWidthM ?? 0,
      heightM: floorPlanSet.underlayHeightM ?? 0,
    );
    notifyListeners();
  }

  /// Updates the live underlay frame every frame of an underlay move/resize drag. See
  /// [ocptFloorPlanSymbolDraggedBy] for why the move branch turns [screenDelta] back into the world
  /// frame with `+rotationDeg` before adding it — the move handle is wrapped in the same
  /// `Transform.rotate`, so Flutter's own delta arrives already in that rotated local frame.
  void updateUnderlayDrag(Offset screenDelta, double zoom, double rotationDeg) {
    final frame = _liveUnderlayFrame;
    if (frame == null) {
      return;
    }

    final metresDelta = ocptFloorPlanScreenVectorToMetres(screenDelta: screenDelta, zoom: zoom);

    if (_underlayDragKind == OcptFloorPlanUnderlayDragKind.move) {
      final worldDelta = ocptFloorPlanRotateVector(metresDelta, rotationDeg);
      _liveUnderlayFrame = (
        xM: frame.xM + worldDelta.dx,
        yM: frame.yM + worldDelta.dy,
        widthM: frame.widthM,
        heightM: frame.heightM,
      );
    } else {
      final local = ocptFloorPlanRotateVector(metresDelta, -rotationDeg);
      _liveUnderlayFrame = (
        xM: frame.xM,
        yM: frame.yM,
        widthM: math.max(ocptFloorPlanMinSymbolFootprintM, frame.widthM + 2 * local.dx),
        heightM: math.max(ocptFloorPlanMinSymbolFootprintM, frame.heightM + 2 * local.dy),
      );
    }
    notifyListeners();
  }

  /// Clears the underlay drag in progress and returns its settled frame, or null when there was
  /// none.
  ({double xM, double yM, double widthM, double heightM})? endUnderlayDrag() {
    final frame = _liveUnderlayFrame;
    _liveUnderlayFrame = null;
    _underlayDragKind = null;
    notifyListeners();
    return frame;
  }

  /// Starts a midpoint drag on the arrow [arrowId], at its handle's current control point.
  void beginArrowCurveDrag(String arrowId, double ctrlXM, double ctrlYM) {
    _draggedArrowId = arrowId;
    _liveArrowCtrl = (xM: ctrlXM, yM: ctrlYM);
    notifyListeners();
  }

  /// Updates the live control point every frame of an arrow midpoint drag — mirrors
  /// [updateSymbolDrag]'s own live-override pattern, with no rotation to undo since an arrow's own
  /// control point is a plain world-frame point.
  void updateArrowCurveDrag(String arrowId, Offset screenDelta, double zoom) {
    final live = _liveArrowCtrl;
    if (live == null || _draggedArrowId != arrowId) {
      return;
    }

    final metresDelta = ocptFloorPlanScreenVectorToMetres(screenDelta: screenDelta, zoom: zoom);
    _liveArrowCtrl = (xM: live.xM + metresDelta.dx, yM: live.yM + metresDelta.dy);
    notifyListeners();
  }

  /// Clears the arrow midpoint drag in progress and returns its settled control point, or null when
  /// there was none.
  ({double xM, double yM})? endArrowCurveDrag() {
    final live = _liveArrowCtrl;
    _liveArrowCtrl = null;
    _draggedArrowId = null;
    notifyListeners();
    return live;
  }
}
