// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_viewport_controller.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

/// The width, in logical pixels, the inline symbol label editor's own text box is drawn at.
const double _labelEditorWidth = 130;

/// The height, in logical pixels, the inline symbol label editor's own text box is drawn at.
const double _labelEditorHeight = 30;

/// The side, in logical pixels, of a selected symbol's own resize handle hit box.
const double _handleHitSize = 18;

/// The gap, in metres, between a selected symbol's own top edge and its rotate handle.
const double _rotateHandleGapM = 0.3;

/// The smallest footprint, in metres, a resize may shrink a set element to.
const double _minSymbolFootprintM = 0.2;

/// The delay after the last scroll-wheel tick before its own settled zoom reaches
/// [OcptFloorPlanCanvas.onZoomSettled] — see `OcptFloorPlanViewportController`'s own doc comment
/// for why a wheel gesture, unlike the tool bar's zoom buttons, needs a debounce of its own.
const Duration _wheelZoomSettleDelay = Duration(milliseconds: 300);

/// How much one scroll-wheel notch multiplies the zoom by.
const double _wheelZoomStep = 0.08;

/// How close, in logical pixels, a click has to land to an arrow's own shaft (straight or curved)
/// to select it under the `select` tool.
const double _arrowHitTolerancePx = 10;

/// How close, in metres, a bent arrow's own control point has to end up to the straight from-to
/// line for a drag on its midpoint handle to straighten it back out instead of writing a curve.
const double _arrowStraightenToleranceM = 0.08;

/// How many segments a curved arrow's own quadratic bezier is subdivided into for
/// [_OcptFloorPlanCanvasState._distanceToArrowM]'s own hit test — coarse enough to stay cheap on
/// every tap, fine enough that the sampled polyline never visibly diverges from the drawn curve.
const int _arrowCurveHitTestSamples = 12;

/// The angle, in degrees, a rotate-handle drag snaps to while `Shift` is held.
const double _rotateSnapStepDeg = 15;

/// The floor plans canvas: a `CustomPaint` of the `OcptFloorPlanSheet` the current focus builds
/// for [floorPlanSet], under a `GestureDetector` (`docs/plans/storyboard.md`, §4.3).
///
/// Geometry is drawn from **metres → logical pixels at [OcptFloorPlanCanvas.viewportController]'s
/// current zoom**, through `ocpt_floor_plan_geometry.dart` — never a stored pixel value.
///
/// **The focus** is [focusShotId]: null draws the `Sequence` focus (every sequence layer, plus
/// every live camera of every shot, numbered, each hideable through [hiddenCameraSymbolIds]); set,
/// it draws the shot focus (every sequence layer, plus [focusShotId]'s own shot layers, plus
/// [previousShotId]'s/[nextShotId]'s own shot layers as onion-skin ghosts, gated by
/// [isOnionSkinPreviousShown]/[isOnionSkinNextShown]). **The scope invariant a tool respects**:
/// [OcptFloorPlanTool.setElement] places on the tray's active *sequence* layer (never scoped to a
/// shot); [OcptFloorPlanTool.camera]/[OcptFloorPlanTool.character]/[OcptFloorPlanTool.light] each
/// place their own fixed shot layer on [focusShotId] and do nothing at all while it is null (the
/// tool bar dims them under the `Sequence` focus, so this is a defensive no-op, never reached in
/// practice). A symbol is only ever **editable** (selectable for drag, resizable, rotatable,
/// deletable) when it belongs to the scope the current focus makes live — a sequence layer under
/// the `Sequence` focus, [focusShotId]'s own shot layers under a shot focus — and never when it is
/// a ghost: the frozen scope is drawn, never hidden, but locked.
///
/// **Arrows**: [OcptFloorPlanTool.arrow] takes two clicks on two (non-ghost) symbols —
/// [onArrowSymbolTapped] reports each tap, the bloc holds the pending anchor and completes the
/// arrow on the second — cancelled by `Escape` (the view's own keyboard shortcut) or a click on
/// empty canvas ([onArrowAnchorCancelled]). **Labels**: [OcptFloorPlanTool.label] shows an inline
/// text field over the selected symbol, its value [symbolLabelValueOf], writes through
/// [onSymbolLabelChanged]. **Double-clicking a ghost** calls [onGhostShotFocusRequested] with its
/// own shot's id, focusing it.
///
/// Placing a set element: pick the `setElement` tool (one of the palette's own four typed entries
/// — wall/door/furniture/freeform — arms both [activeTool] and [activeSetElementShape]), click →
/// [onSymbolPlaced] onto the set layer, carrying that shape. Dragging a symbol moves it (one
/// [onSymbolMoved] on drag end, in metres);
/// dragging its own resize handle resizes it (one [onSymbolResized] on drag end); dragging its own
/// **aim handle** points it (one [onSymbolRotated] on drag end, the pointer's own bearing around
/// the symbol's centre computed in **canvas space** through `RenderBox.globalToLocal` — never the
/// handle's own local position, which reads it relative to the handle's tiny hit box instead —
/// holding `Shift` snaps it to [_rotateSnapStepDeg]° steps). A selected camera also draws two edge
/// handles on its own field-of-view wedge; dragging either narrows or widens it (one
/// [onSymbolFovChanged] on drag end, in degrees). `Ctrl+D` on the selected symbol, or an `Alt`-drag
/// of any symbol (the drag preview follows the pointer exactly like a plain move, but on release the
/// *source* symbol is left untouched and a new, independent copy is placed at the release point
/// instead — [onSymbolDuplicateDragged]), duplicates it: never a link.
///
/// Every write is **withheld** under [isReadOnly] (a null `onSymbolPlaced`/move/resize/rotate/fov/
/// delete/arrow/label/duplicate closes the whole gesture, exactly as the board's null callbacks do);
/// zoom, pan, selecting, the metrics overlay and the tray's own visibility toggles stay available,
/// since they only read.
///
/// **Arrow selection**: a click under `select` that lands within `_arrowHitTolerancePx` of a
/// (non-ghost) arrow's own shaft (straight or curved, `_arrowHitAt`) selects it
/// ([onArrowSelected]) instead of clearing the selection — mutually exclusive with a symbol's own
/// selection. The selected arrow draws its own midpoint handle: dragging it bends the arrow through
/// a live bezier control point (one [onArrowCurveChanged] on drag end), dropping it back onto the
/// straight from-to line straightens it out again, and so does its own neighbouring straighten
/// button once it already carries a curve.
class OcptFloorPlanCanvas extends StatefulWidget {
  /// The set currently shown, or null while none is selected (the empty state).
  final OcptFloorPlanSet? floorPlanSet;

  /// Every shot of the selected sequence's own 1-based display rank, keyed by shot id — what
  /// `OcptFloorPlanSheet.of` derives a camera's number from.
  final Map<String, int> shotRankByShotId;

  /// The id of the currently focused shot, or null for the `Sequence` focus — see the class doc
  /// comment. `OcptShotListState.isFloorPlanShotFocusActive`'s own reading of `selectedShotId`.
  final String? focusShotId;

  /// The shot immediately before [focusShotId] in the sequence, or null while there is none (or
  /// the `Sequence` focus is showing) — the onion skin's own previous-shot ghost.
  final String? previousShotId;

  /// The shot immediately after [focusShotId]. See [previousShotId].
  final String? nextShotId;

  /// Whether the onion skin's own previous-shot ghost is drawn.
  final bool isOnionSkinPreviousShown;

  /// Whether the onion skin's own next-shot ghost is drawn.
  final bool isOnionSkinNextShown;

  /// The onion skin's own ghost opacity, 0..1.
  final double onionSkinOpacity;

  /// The sequence layers currently hidden, out of the tray's own rows.
  final Set<OcptFloorPlanLayer> hiddenLayers;

  /// The ids of every camera symbol currently hidden, out of every live camera of the sequence —
  /// only relevant under the `Sequence` focus, where every shot's cameras draw at once.
  final Set<String> hiddenCameraSymbolIds;

  /// Whether the set's own underlay is currently hidden.
  final bool isUnderlayHidden;

  /// The id of the currently selected symbol, or null while none is.
  final String? selectedSymbolId;

  /// The id of the currently selected arrow, or null while none is — its own midpoint handle only
  /// draws while this names a live, non-ghost arrow of the sheet currently shown.
  final String? selectedArrowId;

  /// The id of the symbol picked as the arrow tool's own pending first end, or null while none is.
  final String? pendingArrowAnchorSymbolId;

  /// Whether the metrics overlay is shown: the distance from the selected symbol to every other
  /// visible symbol of the set.
  final bool isMetricsShown;

  /// Whether the "All cameras" strip toggle is on (R3): every shot's own camera symbol of this set
  /// draws as a ghost alongside [focusShotId]'s own — a display toggle only. A single tap on one of
  /// these extra ghosts calls [onGhostShotFocusRequested] with its own shot id (jumping straight to
  /// it), rather than selecting it the way every other ghost's single tap does — see the state's
  /// own symbol-tap handler.
  final bool isAllCamerasShown;

  /// The canvas's own currently active tool.
  final OcptFloorPlanTool activeTool;

  /// The sequence layer a placed set element lands on.
  final OcptFloorPlanLayer activeLayer;

  /// The décor primitive a `setElement` tool click-to-arm placement carries — which of the
  /// palette's own four typed entries (wall/door/furniture/freeform) was armed last. A drag-and-
  /// drop placement instead carries its own shape on the drag itself
  /// (`OcptFloorPlanPaletteDragPayload.setElementShape`), never reading this field, since a drag
  /// never taps its source first.
  final OcptFloorPlanSetElementShape activeSetElementShape;

  /// The live zoom/pan controller this canvas draws and drags against — see that class's own doc
  /// comment for why it lives outside the bloc.
  final OcptFloorPlanViewportController viewportController;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// A symbol's current label value: a pending edit still in the mode's debounce, or the
  /// symbol's own stored label — the inline label editor's equivalent of the inspector's own
  /// `fieldValueOf`.
  final String Function(String symbolId) symbolLabelValueOf;

  /// Called with a symbol's id when it is selected, or null when empty canvas is clicked while the
  /// `select` or `label` tool is on (clearing the selection). Never withheld: selecting only reads.
  final ValueChanged<String?> onSymbolSelected;

  /// Called with the layer and the shot id (null on a sequence layer, [focusShotId] on a shot
  /// layer) a new symbol is placed on, and the clicked point (metres), or null while withheld.
  /// `setElementShape` carries the décor primitive when the layer is
  /// [OcptFloorPlanLayer.set] and the placing tool was one of the four typed set-element entries —
  /// null otherwise (every other layer, and a generic `setElement` placement with none armed).
  final void Function(
    OcptFloorPlanLayer layer,
    String? shotId,
    double xM,
    double yM, {
    OcptFloorPlanSetElementShape? setElementShape,
  })?
  onSymbolPlaced;

  /// Called with a symbol's id and its new centre (metres) once a drag moving it ends, or null
  /// while withheld.
  final void Function(String symbolId, double xM, double yM)? onSymbolMoved;

  /// Called with a symbol's id and its new footprint (metres) once a drag on its own resize handle
  /// ends, or null while withheld.
  final void Function(String symbolId, double widthM, double heightM)? onSymbolResized;

  /// Called with a symbol's id and its new rotation (degrees, bearing, 0° = up) once a drag on its
  /// own aim handle ends, or null while withheld.
  final void Function(String symbolId, double rotationDeg)? onSymbolRotated;

  /// Called with a camera symbol's id and its new field-of-view wedge angle (degrees) once a drag
  /// on one of its own edge handles ends, or null while withheld.
  final void Function(String symbolId, double fovDeg)? onSymbolFovChanged;

  /// Called with a camera symbol's id and its new field-of-view wedge reach (metres) once a drag
  /// on its own tip handle ends, or null while withheld.
  final void Function(String symbolId, double fovReachM)? onSymbolFovReachChanged;

  /// Called with the selected symbol's id when its own delete action is clicked, or null while
  /// withheld. Only asks — the mode opens `OcptConfirmDialog`.
  final ValueChanged<String>? onSymbolDeleteRequested;

  /// Called with a (non-ghost) symbol's id when it is tapped while the `arrow` tool is on, or null
  /// while withheld.
  final ValueChanged<String>? onArrowSymbolTapped;

  /// Called to cancel the arrow tool's own pending anchor — `Escape` or a click on empty canvas
  /// while it is on — or null while withheld (nothing pending, or a read-only preview).
  final VoidCallback? onArrowAnchorCancelled;

  /// Called with an arrow's id when it is selected (a click near its own shaft under the `select`
  /// tool), or null to clear the selection (a click on empty canvas, or on a symbol). Never
  /// withheld: selecting only reads.
  final ValueChanged<String?> onArrowSelected;

  /// Called with an arrow's id and its new bezier control point (metres), or both null to
  /// straighten it back out, once a drag on its own midpoint handle ends (or its own straighten
  /// button is tapped) — or null while withheld.
  final void Function(String arrowId, double? ctrlXM, double? ctrlYM)? onArrowCurveChanged;

  /// Called with the selected symbol's id when `Ctrl+D` is pressed, duplicating it at a default
  /// offset from its own source — or null while withheld. See [onSymbolDuplicateDragged] for the
  /// `Alt`-drag variant, which reports an explicit position instead.
  final ValueChanged<String>? onSymbolDuplicateRequested;

  /// Called with a symbol's id and the release point (metres) of an `Alt`-drag on it, placing an
  /// independent copy there and leaving the source symbol untouched at its own original position —
  /// or null while withheld.
  final void Function(String symbolId, double xM, double yM)? onSymbolDuplicateDragged;

  /// Called with a ghost symbol's own shot id when it is double-clicked, focusing it. Never
  /// withheld: focusing a shot only reads.
  final ValueChanged<String>? onGhostShotFocusRequested;

  /// Called with a symbol's id and its raw label text on every keystroke of the inline label
  /// editor, or null while withheld.
  final void Function(String symbolId, String rawValue)? onSymbolLabelChanged;

  /// Called with the underlay's new frame (metres) once a drag moving or resizing it ends, or null
  /// while withheld.
  final void Function(double xM, double yM, double widthM, double heightM)?
  onUnderlayTransformChanged;

  /// Called with the zoom the scroll wheel just settled on (debounced), or null while withheld.
  /// Never gated by [isReadOnly]: zoom only reads.
  final ValueChanged<double>? onZoomSettled;

  /// Class constructor
  const OcptFloorPlanCanvas({
    super.key,
    required this.floorPlanSet,
    required this.shotRankByShotId,
    required this.focusShotId,
    required this.previousShotId,
    required this.nextShotId,
    required this.isOnionSkinPreviousShown,
    required this.isOnionSkinNextShown,
    required this.onionSkinOpacity,
    required this.hiddenLayers,
    required this.hiddenCameraSymbolIds,
    required this.isUnderlayHidden,
    required this.selectedSymbolId,
    required this.selectedArrowId,
    required this.pendingArrowAnchorSymbolId,
    required this.isMetricsShown,
    required this.isAllCamerasShown,
    required this.activeTool,
    required this.activeLayer,
    required this.activeSetElementShape,
    required this.viewportController,
    required this.isReadOnly,
    required this.symbolLabelValueOf,
    required this.onSymbolSelected,
    required this.onSymbolPlaced,
    required this.onSymbolMoved,
    required this.onSymbolResized,
    required this.onSymbolRotated,
    required this.onSymbolFovChanged,
    required this.onSymbolFovReachChanged,
    required this.onSymbolDeleteRequested,
    required this.onArrowSymbolTapped,
    required this.onArrowAnchorCancelled,
    required this.onArrowSelected,
    required this.onArrowCurveChanged,
    required this.onSymbolDuplicateRequested,
    required this.onSymbolDuplicateDragged,
    required this.onGhostShotFocusRequested,
    required this.onSymbolLabelChanged,
    required this.onUnderlayTransformChanged,
    required this.onZoomSettled,
  });

  @override
  State<OcptFloorPlanCanvas> createState() => _OcptFloorPlanCanvasState();
}

class _OcptFloorPlanCanvasState extends State<OcptFloorPlanCanvas> {
  /// Which gesture the symbol drag currently in progress means (move, resize, aim or field of
  /// view), or null while none is — alongside [_liveOverride], which names *which* symbol.
  _SymbolDragKind? _dragKind;

  /// Whether the drag currently in progress (always a [_SymbolDragKind.move] one) is an `Alt`-drag
  /// duplicate: the live preview tracks the pointer exactly like a plain move, but
  /// [_commitSymbolDrag] reports it through [OcptFloorPlanCanvas.onSymbolDuplicateDragged] instead
  /// of [OcptFloorPlanCanvas.onSymbolMoved], leaving the source symbol at its own original position.
  bool _isDuplicatingDrag = false;

  /// The dragged symbol's live geometry, updated every frame of the drag. See
  /// [OcptFloorPlanSymbolLiveOverride].
  OcptFloorPlanSymbolLiveOverride? _liveOverride;

  /// The underlay's own live frame while it is being moved or resized, or null while it isn't.
  ({double xM, double yM, double widthM, double heightM})? _liveUnderlayFrame;

  /// Which gesture the current underlay drag means, or null alongside [_liveUnderlayFrame].
  _UnderlayDragKind? _underlayDragKind;

  /// The id of the arrow whose own midpoint handle is currently being dragged, or null while none
  /// is — alongside [_liveArrowCtrl], which carries its live control point.
  String? _draggedArrowId;

  /// The dragged arrow's own live bezier control point (metres), updated every frame of the drag.
  ({double xM, double yM})? _liveArrowCtrl;

  /// The debounce timer settling a scroll-wheel zoom into [OcptFloorPlanCanvas.onZoomSettled].
  Timer? _wheelZoomSettleTimer;

  /// The key of the `Stack` filling this canvas's own local coordinate space (the same origin
  /// [ocptFloorPlanScreenPointOf]/[ocptFloorPlanMetrePointOf] already agree on) — what
  /// [_resolveLocalPosition] converts a gesture's own **global** position through, since a handle's
  /// own `details.localPosition` is relative to that tiny handle's own hit box, not to the canvas
  /// (the rotation bug this milestone fixes).
  final GlobalKey _canvasStackKey = GlobalKey();

  @override
  void dispose() {
    _wheelZoomSettleTimer?.cancel();
    super.dispose();
  }

  /// [globalPosition] converted into this canvas's own local coordinate space, through
  /// [_canvasStackKey]'s `RenderBox` — the fix for a handle drag's own `onPanUpdate`, whose
  /// `details.localPosition` is relative to the handle's own tiny hit box rather than to the
  /// canvas. Falls back to [globalPosition] unchanged on the one frame the render object isn't
  /// resolvable yet (defensive only).
  Offset _resolveLocalPosition(Offset globalPosition) {
    final renderObject = _canvasStackKey.currentContext?.findRenderObject();
    return renderObject is RenderBox
        ? renderObject.globalToLocal(globalPosition)
        : globalPosition;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final floorPlanSet = widget.floorPlanSet;

    if (floorPlanSet == null) {
      return Center(
        child: Text(
          tr.shotListFloorPlanNoCaseHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = constraints.biggest;

        return ListenableBuilder(
          listenable: widget.viewportController,
          builder: (context, _) {
            final zoom = widget.viewportController.zoom;
            final pan = widget.viewportController.pan;
            final sheet = _sheetOf(floorPlanSet);
            final barLengthM = ocptFloorPlanScaleBarLengthM(zoom: zoom);

            final selectedShape = _selectedShapeOf(sheet);
            final selectedArrow = _selectedArrowShapeOf(sheet);

            return ClipRect(
              child: Stack(
                key: _canvasStackKey,
                children: [
                  if (!widget.isUnderlayHidden && floorPlanSet.underlayAssetId != null)
                    _buildUnderlayVisual(floorPlanSet, canvasSize, zoom, pan),
                  Positioned.fill(
                    child: DragTarget<OcptFloorPlanPaletteDragPayload>(
                      onWillAcceptWithDetails: (details) =>
                          !widget.isReadOnly && widget.onSymbolPlaced != null,
                      onAcceptWithDetails: (details) =>
                          _handlePaletteDrop(details, canvasSize, zoom, pan),
                      builder: (context, candidateData, rejectedData) => Listener(
                      onPointerSignal: _handlePointerSignal,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _handleBackgroundTap(
                          details.localPosition,
                          canvasSize,
                          zoom,
                          pan,
                          sheet,
                        ),
                        onPanUpdate: (details) => widget.viewportController.panBy(details.delta),
                        child: CustomPaint(
                          size: canvasSize,
                          painter: OcptFloorPlanCanvasPainter(
                            sheet: sheet,
                            zoom: zoom,
                            pan: pan,
                            selectedSymbolId: widget.selectedSymbolId,
                            arrowAnchorSymbolId: widget.pendingArrowAnchorSymbolId,
                            liveOverride: _liveOverride,
                            symbolBorderColor: theme.colorScheme.outline,
                            selectionColor: theme.colorScheme.primary,
                            arrowAnchorColor: theme.colorScheme.secondary,
                            arrowColor: theme.colorScheme.onSurface,
                            labelTextColor: theme.colorScheme.onSurface,
                            scaleColor: theme.colorScheme.onSurfaceVariant,
                            scaleBarLabel: tr.shotListFloorPlanScaleBarLengthLabel(
                              ocptFloorPlanScaleBarLengthLabelOf(barLengthM),
                            ),
                            onionSkinOpacity: widget.onionSkinOpacity,
                            metricLines: _metricLinesOf(sheet, selectedShape, tr),
                            metricLineColor: theme.colorScheme.tertiary,
                          ),
                        ),
                      ),
                      ),
                    ),
                  ),
                  if (!widget.isUnderlayHidden &&
                      floorPlanSet.underlayAssetId != null &&
                      !widget.isReadOnly &&
                      widget.onUnderlayTransformChanged != null)
                    ..._buildUnderlayHandles(floorPlanSet, canvasSize, zoom, pan),
                  for (final symbol in sheet.symbols)
                    _buildSymbolHitOverlay(symbol, canvasSize, zoom, pan),
                  if (selectedShape != null)
                    ..._buildSymbolHandles(selectedShape, canvasSize, zoom, pan),
                  if (selectedArrow != null)
                    ..._buildArrowHandle(selectedArrow, canvasSize, zoom, pan),
                  if (widget.activeTool == OcptFloorPlanTool.label &&
                      selectedShape != null &&
                      !selectedShape.isGhost)
                    _buildLabelEditor(selectedShape, canvasSize, zoom, pan),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// The sheet this canvas draws, under [OcptFloorPlanCanvas.focusShotId]'s own focus, filtered to
  /// [OcptFloorPlanCanvas.hiddenLayers] and — under the `Sequence` focus only —
  /// [OcptFloorPlanCanvas.hiddenCameraSymbolIds]. The onion skin's own ghost shots
  /// ([OcptFloorPlanCanvas.previousShotId]/[OcptFloorPlanCanvas.nextShotId]) are passed to
  /// `OcptFloorPlanSheet.of` only while their own tray toggle is on, so a hidden neighbour draws
  /// nothing at all rather than a ghost this canvas then has to filter back out.
  OcptFloorPlanSheet _sheetOf(OcptFloorPlanSet floorPlanSet) {
    final focusShotId = widget.focusShotId;
    final full = OcptFloorPlanSheet.of(
      floorPlanSet: floorPlanSet,
      focusShotId: focusShotId,
      shotRankByShotId: widget.shotRankByShotId,
      previousShotId: widget.isOnionSkinPreviousShown ? widget.previousShotId : null,
      nextShotId: widget.isOnionSkinNextShown ? widget.nextShotId : null,
      showFieldOfView: widget.viewportController.showFieldOfView,
      showAllCameras: widget.isAllCamerasShown,
    );
    final isSequenceFocus = focusShotId == null;

    return OcptFloorPlanSheet(
      setId: full.setId,
      setName: full.setName,
      underlay: full.underlay,
      symbols: [
        for (final symbol in full.symbols)
          if (!widget.hiddenLayers.contains(symbol.layer) &&
              !(isSequenceFocus &&
                  symbol.layer == OcptFloorPlanLayer.cameras &&
                  widget.hiddenCameraSymbolIds.contains(symbol.symbolId)))
            symbol,
      ],
      arrows: full.arrows,
    );
  }

  /// Whether [symbol] may be dragged, resized, rotated, given a field of view or deleted: never a
  /// ghost; the **set layer is always editable** (R2, "the set is always editable"); a shot layer
  /// symbol is editable only while it belongs to [OcptFloorPlanCanvas.focusShotId], the one shot
  /// everything "live" lands on. A ghosted neighbour's own placements stay selectable (so their
  /// own Placements/metrics still read), just locked.
  bool _isSymbolEditable(OcptFloorPlanSymbolShape symbol) {
    if (symbol.isGhost) {
      return false;
    }
    return symbol.layer.isSequenceScoped || symbol.shotId == widget.focusShotId;
  }

  /// The metrics overlay's own lines, from the selected symbol to every other symbol [sheet] draws
  /// — empty while the overlay is off or nothing is selected.
  List<OcptFloorPlanMetricLine> _metricLinesOf(
    OcptFloorPlanSheet sheet,
    OcptFloorPlanSymbolShape? selected,
    Tr tr,
  ) {
    if (!widget.isMetricsShown || selected == null) {
      return const [];
    }

    return [
      for (final other in sheet.symbols)
        if (other.symbolId != selected.symbolId)
          OcptFloorPlanMetricLine(
            fromXM: selected.xM,
            fromYM: selected.yM,
            toXM: other.xM,
            toYM: other.yM,
            label: tr.shotListFloorPlanScaleBarLengthLabel(
              ocptFloorPlanScaleBarLengthLabelOf(
                _roundToOneDecimetre(
                  ocptFloorPlanDistanceM(
                    x1M: selected.xM,
                    y1M: selected.yM,
                    x2M: other.xM,
                    y2M: other.yM,
                  ),
                ),
              ),
            ),
          ),
    ];
  }

  /// [metres] rounded to the nearest tenth, for the metrics overlay's own labels — the distance
  /// rule ([ocptFloorPlanDistanceM]) is exact, but a floor plan is never measured that precisely.
  double _roundToOneDecimetre(double metres) => (metres * 10).round() / 10;

  /// The selected symbol's own shape out of [sheet], or null while none is selected or it isn't
  /// (currently) visible.
  OcptFloorPlanSymbolShape? _selectedShapeOf(OcptFloorPlanSheet sheet) {
    final selectedSymbolId = widget.selectedSymbolId;
    if (selectedSymbolId == null) {
      return null;
    }
    for (final symbol in sheet.symbols) {
      if (symbol.symbolId == selectedSymbolId) {
        return symbol;
      }
    }
    return null;
  }

  /// The selected arrow's own shape out of [sheet], or null while none is selected or it isn't
  /// (currently) visible — [OcptFloorPlanCanvas.selectedArrowId]'s own equivalent of
  /// [_selectedShapeOf].
  OcptFloorPlanArrowShape? _selectedArrowShapeOf(OcptFloorPlanSheet sheet) {
    final selectedArrowId = widget.selectedArrowId;
    if (selectedArrowId == null) {
      return null;
    }
    for (final arrow in sheet.arrows) {
      if (arrow.arrowId == selectedArrowId) {
        return arrow;
      }
    }
    return null;
  }

  /// A palette entry dropped onto this canvas (R3, drag-from-palette placement,
  /// `docs/plans/storyboard.md`, §9.4): places a symbol of `details.data`'s own tool exactly at the
  /// drop point, the drag-and-drop sibling of [_handleBackgroundTap]'s own click-to-arm-then-click
  /// path. A no-op for [OcptFloorPlanTool.select], [OcptFloorPlanTool.arrow] and
  /// [OcptFloorPlanTool.label] — the palette never offers those as drag sources in the first
  /// place — or for a shot-scoped tool while no shot is focused, defensive only.
  void _handlePaletteDrop(
    DragTargetDetails<OcptFloorPlanPaletteDragPayload> details,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final onSymbolPlaced = widget.onSymbolPlaced;
    if (onSymbolPlaced == null) {
      return;
    }

    final tool = details.data.tool;
    final shotLayer = _shotLayerOf(tool);
    if (tool != OcptFloorPlanTool.setElement && shotLayer == null) {
      return;
    }
    final shotId = shotLayer == null ? null : widget.focusShotId;
    if (shotLayer != null && shotId == null) {
      return;
    }

    final localPosition = _resolveLocalPosition(details.offset);
    final metres = ocptFloorPlanMetrePointOf(
      screenPoint: localPosition,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    onSymbolPlaced(
      shotLayer ?? widget.activeLayer,
      shotId,
      metres.dx,
      metres.dy,
      setElementShape: tool == OcptFloorPlanTool.setElement ? details.data.setElementShape : null,
    );
  }

  /// A click on empty canvas (no symbol, no underlay handle caught it first): places a new symbol
  /// under a placing tool (`setElement` on the tray's active sequence layer, or `camera`/
  /// `character`/`light` on [OcptFloorPlanCanvas.focusShotId]'s own shot layer — a no-op while no
  /// shot is focused, defensive only); under `select`, selects the arrow it lands near
  /// ([_arrowHitAt]) instead of clearing, when one is close enough; cancels the arrow tool's own
  /// pending anchor under `arrow`; clears both selections otherwise (`label`, an arrow tool with
  /// nothing pending, or `select` finding no arrow close enough).
  void _handleBackgroundTap(
    Offset localPosition,
    Size canvasSize,
    double zoom,
    Offset pan,
    OcptFloorPlanSheet sheet,
  ) {
    final shotLayer = _shotLayerOf(widget.activeTool);
    if (widget.activeTool == OcptFloorPlanTool.setElement || shotLayer != null) {
      final onSymbolPlaced = widget.onSymbolPlaced;
      final shotId = shotLayer == null ? null : widget.focusShotId;
      if (onSymbolPlaced == null || (shotLayer != null && shotId == null)) {
        return;
      }
      final metres = ocptFloorPlanMetrePointOf(
        screenPoint: localPosition,
        canvasSize: canvasSize,
        zoom: zoom,
        pan: pan,
      );
      onSymbolPlaced(
        shotLayer ?? widget.activeLayer,
        shotId,
        metres.dx,
        metres.dy,
        setElementShape: widget.activeTool == OcptFloorPlanTool.setElement
            ? widget.activeSetElementShape
            : null,
      );
      return;
    }

    if (widget.activeTool == OcptFloorPlanTool.select) {
      final metres = ocptFloorPlanMetrePointOf(
        screenPoint: localPosition,
        canvasSize: canvasSize,
        zoom: zoom,
        pan: pan,
      );
      final arrowId = _arrowHitAt(sheet, metres.dx, metres.dy, zoom);
      if (arrowId != null) {
        widget.onSymbolSelected(null);
        widget.onArrowSelected(arrowId);
        return;
      }
    }

    if (widget.activeTool == OcptFloorPlanTool.arrow) {
      widget.onArrowAnchorCancelled?.call();
    }

    widget.onArrowSelected(null);
    widget.onSymbolSelected(null);
  }

  /// The id of the closest editable (non-ghost) arrow of [sheet] whose own shaft (straight or
  /// curved) comes within [_arrowHitTolerancePx] of the point [xM]/[yM] (case metres), or null
  /// while none does.
  String? _arrowHitAt(OcptFloorPlanSheet sheet, double xM, double yM, double zoom) {
    final thresholdM = ocptFloorPlanPixelsToMetres(pixels: _arrowHitTolerancePx, zoom: zoom);
    String? bestId;
    var bestDistanceM = thresholdM;

    for (final arrow in sheet.arrows) {
      if (arrow.isGhost) {
        continue;
      }
      final distanceM = _distanceToArrowM(arrow, xM, yM);
      if (distanceM <= bestDistanceM) {
        bestDistanceM = distanceM;
        bestId = arrow.arrowId;
      }
    }

    return bestId;
  }

  /// The shortest distance, in metres, from point [xM]/[yM] to [arrow]'s own shaft: a straight
  /// point-to-segment distance while it carries no control point, otherwise the smallest
  /// point-to-segment distance over [_arrowCurveHitTestSamples] chords approximating its own
  /// quadratic bezier — the same curve `OcptFloorPlanCanvasPainter._paintArrow` draws.
  double _distanceToArrowM(OcptFloorPlanArrowShape arrow, double xM, double yM) {
    if (arrow.ctrlXM == null || arrow.ctrlYM == null) {
      return _distanceToSegmentM(xM, yM, arrow.fromXM, arrow.fromYM, arrow.toXM, arrow.toYM);
    }

    var previous = Offset(arrow.fromXM, arrow.fromYM);
    var minDistanceM = double.infinity;
    for (var i = 1; i <= _arrowCurveHitTestSamples; i++) {
      final point = _quadraticBezierPointM(arrow, i / _arrowCurveHitTestSamples);
      final distanceM = _distanceToSegmentM(xM, yM, previous.dx, previous.dy, point.dx, point.dy);
      if (distanceM < minDistanceM) {
        minDistanceM = distanceM;
      }
      previous = point;
    }
    return minDistanceM;
  }

  /// [arrow]'s own quadratic bezier point at parameter [t] (0 = [OcptFloorPlanArrowShape.fromXM]/
  /// `.fromYM`, 1 = `.toXM`/`.toYM`), through its own control point — requires
  /// [OcptFloorPlanArrowShape.ctrlXM]/`.ctrlYM` to be set.
  Offset _quadraticBezierPointM(OcptFloorPlanArrowShape arrow, double t) {
    final oneMinusT = 1 - t;
    final ctrlXM = arrow.ctrlXM!;
    final ctrlYM = arrow.ctrlYM!;
    return Offset(
      oneMinusT * oneMinusT * arrow.fromXM + 2 * oneMinusT * t * ctrlXM + t * t * arrow.toXM,
      oneMinusT * oneMinusT * arrow.fromYM + 2 * oneMinusT * t * ctrlYM + t * t * arrow.toYM,
    );
  }

  /// The shortest distance from point [px]/[py] to the segment `(x1, y1)`–`(x2, y2)`, all in the
  /// same unit (metres throughout this file).
  double _distanceToSegmentM(double px, double py, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return math.sqrt(math.pow(px - x1, 2) + math.pow(py - y1, 2));
    }

    final t = (((px - x1) * dx + (py - y1) * dy) / lengthSquared).clamp(0.0, 1.0);
    final projectedX = x1 + t * dx;
    final projectedY = y1 + t * dy;
    return math.sqrt(math.pow(px - projectedX, 2) + math.pow(py - projectedY, 2));
  }

  /// The fixed shot layer [tool] always places on, or null for a tool that doesn't place a
  /// shot-scoped symbol at all ([OcptFloorPlanTool.setElement] places a sequence layer instead,
  /// every other tool places nothing).
  OcptFloorPlanLayer? _shotLayerOf(OcptFloorPlanTool tool) => switch (tool) {
    OcptFloorPlanTool.camera => OcptFloorPlanLayer.cameras,
    OcptFloorPlanTool.character => OcptFloorPlanLayer.characters,
    OcptFloorPlanTool.light => OcptFloorPlanLayer.lights,
    OcptFloorPlanTool.select ||
    OcptFloorPlanTool.setElement ||
    OcptFloorPlanTool.arrow ||
    OcptFloorPlanTool.label => null,
  };

  /// Zooms in/out one [_wheelZoomStep] per scroll-wheel notch, live on
  /// [OcptFloorPlanCanvas.viewportController] with no bloc emission, then (re)starts the debounce
  /// that eventually settles it into [OcptFloorPlanCanvas.onZoomSettled] — see
  /// `OcptFloorPlanViewportController`'s own doc comment.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final factor = event.scrollDelta.dy > 0 ? (1 - _wheelZoomStep) : (1 + _wheelZoomStep);
    widget.viewportController.setZoom(widget.viewportController.zoom * factor);

    final onZoomSettled = widget.onZoomSettled;
    if (onZoomSettled == null) {
      return;
    }
    _wheelZoomSettleTimer?.cancel();
    _wheelZoomSettleTimer = Timer(_wheelZoomSettleDelay, () {
      if (mounted) {
        onZoomSettled(widget.viewportController.zoom);
      }
    });
  }

  /// The underlay's own screen rect, un-rotated (its rotation is applied by a `Transform.rotate`
  /// wrapping whichever widget this sizes).
  Rect _underlayScreenRect(OcptFloorPlanSet floorPlanSet, Size canvasSize, double zoom, Offset pan) {
    final frame = _liveUnderlayFrame;
    final xM = frame?.xM ?? floorPlanSet.underlayXM ?? 0;
    final yM = frame?.yM ?? floorPlanSet.underlayYM ?? 0;
    final widthM = frame?.widthM ?? floorPlanSet.underlayWidthM ?? 0;
    final heightM = frame?.heightM ?? floorPlanSet.underlayHeightM ?? 0;
    final centre = ocptFloorPlanScreenPointOf(xM: xM, yM: yM, canvasSize: canvasSize, zoom: zoom, pan: pan);
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final widthPx = widthM * pixelsPerMetre;
    final heightPx = heightM * pixelsPerMetre;
    return Rect.fromCenter(center: centre, width: widthPx, height: heightPx);
  }

  /// The underlay's own visual: a real `OcptReferencedImage`, positioned and rotated to its current
  /// frame, drawn behind the `CustomPaint` (so symbols draw over it) and taking no pointer of its
  /// own — a separate invisible overlay ([_buildUnderlayHandles]) handles its interaction, decoupling
  /// visual draw order from hit-test order.
  Widget _buildUnderlayVisual(OcptFloorPlanSet floorPlanSet, Size canvasSize, double zoom, Offset pan) {
    final rect = _underlayScreenRect(floorPlanSet, canvasSize, zoom, pan);
    final rotationDeg = floorPlanSet.underlayRotationDeg ?? 0;

    return IgnorePointer(
      child: Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: Transform.rotate(
          angle: rotationDeg * math.pi / 180,
          child: OcptReferencedImage(
            path: floorPlanSet.underlayPath,
            fit: BoxFit.fill,
            fallbackBuilder: (context) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ),
    );
  }

  /// The underlay's own invisible move + resize handles, drawn after the symbol overlays are laid
  /// out but positioned first in this build's own return list (see [build]) so a click landing on
  /// a symbol drawn over the underlay hits that symbol first.
  List<Widget> _buildUnderlayHandles(
    OcptFloorPlanSet floorPlanSet,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final rect = _underlayScreenRect(floorPlanSet, canvasSize, zoom, pan);
    final rotationDeg = floorPlanSet.underlayRotationDeg ?? 0;

    return [
      Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: Transform.rotate(
          angle: rotationDeg * math.pi / 180,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: (_) => setState(() {
              _underlayDragKind = _UnderlayDragKind.move;
              _liveUnderlayFrame = (
                xM: floorPlanSet.underlayXM ?? 0,
                yM: floorPlanSet.underlayYM ?? 0,
                widthM: floorPlanSet.underlayWidthM ?? 0,
                heightM: floorPlanSet.underlayHeightM ?? 0,
              );
            }),
            onPanUpdate: (details) => _updateUnderlayDrag(details.delta, zoom, rotationDeg),
            onPanEnd: (_) => _commitUnderlayDrag(floorPlanSet),
          ),
        ),
      ),
      Positioned(
        left: rect.right - _handleHitSize / 2,
        top: rect.bottom - _handleHitSize / 2,
        width: _handleHitSize,
        height: _handleHitSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (_) => setState(() {
            _underlayDragKind = _UnderlayDragKind.resize;
            _liveUnderlayFrame = (
              xM: floorPlanSet.underlayXM ?? 0,
              yM: floorPlanSet.underlayYM ?? 0,
              widthM: floorPlanSet.underlayWidthM ?? 0,
              heightM: floorPlanSet.underlayHeightM ?? 0,
            );
          }),
          onPanUpdate: (details) => _updateUnderlayDrag(details.delta, zoom, rotationDeg),
          onPanEnd: (_) => _commitUnderlayDrag(floorPlanSet),
          child: _HandleDot(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    ];
  }

  /// Updates [_liveUnderlayFrame] every frame of an underlay move/resize drag, no database write
  /// and no bloc emission until [_commitUnderlayDrag]. See [_updateSymbolDrag]'s own doc comment
  /// for why the move branch turns [screenDelta] back into the world frame with `+rotationDeg`
  /// before adding it — the move handle is wrapped in the same `Transform.rotate` (see
  /// [_buildUnderlayHandles]), so Flutter's own delta arrives already in that rotated local frame.
  void _updateUnderlayDrag(Offset screenDelta, double zoom, double rotationDeg) {
    final frame = _liveUnderlayFrame;
    if (frame == null) {
      return;
    }

    final metresDelta = ocptFloorPlanScreenVectorToMetres(screenDelta: screenDelta, zoom: zoom);

    setState(() {
      if (_underlayDragKind == _UnderlayDragKind.move) {
        final worldDelta = ocptFloorPlanRotateVector(metresDelta, rotationDeg);
        _liveUnderlayFrame = (
          xM: frame.xM + worldDelta.dx,
          yM: frame.yM + worldDelta.dy,
          widthM: frame.widthM,
          heightM: frame.heightM,
        );
        return;
      }

      final local = ocptFloorPlanRotateVector(metresDelta, -rotationDeg);
      _liveUnderlayFrame = (
        xM: frame.xM,
        yM: frame.yM,
        widthM: math.max(_minSymbolFootprintM, frame.widthM + 2 * local.dx),
        heightM: math.max(_minSymbolFootprintM, frame.heightM + 2 * local.dy),
      );
    });
  }

  /// Reports the underlay's own settled frame and clears the live drag state.
  void _commitUnderlayDrag(OcptFloorPlanSet floorPlanSet) {
    final frame = _liveUnderlayFrame;
    setState(() {
      _liveUnderlayFrame = null;
      _underlayDragKind = null;
    });
    if (frame == null) {
      return;
    }
    widget.onUnderlayTransformChanged?.call(frame.xM, frame.yM, frame.widthM, frame.heightM);
  }

  /// One symbol's own invisible move + select overlay, rotated to match its own drawn shape.
  ///
  /// A tap under the `arrow` tool reports to [OcptFloorPlanCanvas.onArrowSymbolTapped] instead of
  /// selecting (a ghost is excluded — an arrow always belongs to the focused shot, never crosses
  /// into a neighbour's own placements); every other tool selects as before. Dragging is withheld
  /// whenever [_isSymbolEditable] says the symbol is locked under the current focus, on top of the
  /// existing [OcptFloorPlanCanvas.isReadOnly]/[OcptFloorPlanCanvas.onSymbolMoved] gates.
  /// Double-clicking a ghost calls [OcptFloorPlanCanvas.onGhostShotFocusRequested] with its own
  /// shot id, focusing it. Starting the drag with `Alt` held (and
  /// [OcptFloorPlanCanvas.onSymbolDuplicateDragged] not withheld) arms [_isDuplicatingDrag]: the
  /// live preview still tracks the pointer exactly like a plain move, but [_commitSymbolDrag]
  /// reports it as a duplicate instead, leaving this very symbol at its own original position.
  Widget _buildSymbolHitOverlay(
    OcptFloorPlanSymbolShape symbol,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final override = _liveOverride;
    final isDragged = override != null && override.symbolId == symbol.symbolId;
    final xM = isDragged ? override.xM : symbol.xM;
    final yM = isDragged ? override.yM : symbol.yM;
    final widthM = isDragged ? override.widthM : symbol.widthM;
    final heightM = isDragged ? override.heightM : symbol.heightM;
    final rotationDeg = isDragged ? override.rotationDeg : symbol.rotationDeg;

    final centre = ocptFloorPlanScreenPointOf(xM: xM, yM: yM, canvasSize: canvasSize, zoom: zoom, pan: pan);
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final widthPx = widthM * pixelsPerMetre;
    final heightPx = heightM * pixelsPerMetre;
    final canDrag = !widget.isReadOnly && widget.onSymbolMoved != null && _isSymbolEditable(symbol);
    final shotId = symbol.shotId;

    return Positioned(
      left: centre.dx - widthPx / 2,
      top: centre.dy - heightPx / 2,
      width: widthPx,
      height: heightPx,
      child: Transform.rotate(
        angle: rotationDeg * math.pi / 180,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: () => _handleSymbolTap(symbol),
          onDoubleTap: symbol.isGhost && shotId != null
              ? () => widget.onGhostShotFocusRequested?.call(shotId)
              : null,
          onPanStart: !canDrag
              ? null
              : (_) {
                  widget.onArrowSelected(null);
                  widget.onSymbolSelected(symbol.symbolId);
                  setState(() {
                    _dragKind = _SymbolDragKind.move;
                    _isDuplicatingDrag =
                        HardwareKeyboard.instance.isAltPressed &&
                        widget.onSymbolDuplicateDragged != null;
                    _liveOverride = OcptFloorPlanSymbolLiveOverride(
                      symbolId: symbol.symbolId,
                      xM: symbol.xM,
                      yM: symbol.yM,
                      widthM: symbol.widthM,
                      heightM: symbol.heightM,
                      rotationDeg: symbol.rotationDeg,
                    );
                  });
                },
          onPanUpdate: !canDrag
              ? null
              : (details) => _updateSymbolDrag(symbol.symbolId, details.delta, zoom),
          onPanEnd: !canDrag ? null : (_) => _commitSymbolDrag(symbol),
        ),
      ),
    );
  }

  /// A tap on [symbol]: reports it to [OcptFloorPlanCanvas.onArrowSymbolTapped] under the `arrow`
  /// tool (ignored on a ghost, see [_buildSymbolHitOverlay]'s own doc comment), selects it
  /// otherwise (clearing any arrow selection, the two being mutually exclusive).
  void _handleSymbolTap(OcptFloorPlanSymbolShape symbol) {
    if (widget.activeTool == OcptFloorPlanTool.arrow) {
      if (!symbol.isGhost) {
        widget.onArrowSymbolTapped?.call(symbol.symbolId);
      }
      return;
    }

    // The "All cameras" strip toggle (R3): a single click on one of its own ghost cameras jumps
    // straight to that camera's shot, rather than selecting the ghost — browsing cameras is the
    // whole point of the toggle, and a jump reads the ghost the same way a click already reads a
    // shot chip. The onion skin's own ghosts keep their double-click-to-jump/single-click-to-select
    // split (see [_buildSymbolHitOverlay]'s own doc comment) whenever the toggle is off.
    final shotId = symbol.shotId;
    if (widget.isAllCamerasShown &&
        symbol.isGhost &&
        symbol.layer == OcptFloorPlanLayer.cameras &&
        shotId != null) {
      widget.onGhostShotFocusRequested?.call(shotId);
      return;
    }

    widget.onArrowSelected(null);
    widget.onSymbolSelected(symbol.symbolId);
  }

  /// The selected symbol's own resize, aim (rotate) and — for a camera whose own field-of-view
  /// wedge is drawn — edge handles, or an empty list while withheld under a read-only preview or
  /// while [_isSymbolEditable] locks it under the current focus.
  List<Widget> _buildSymbolHandles(
    OcptFloorPlanSymbolShape symbol,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    if (widget.isReadOnly || !_isSymbolEditable(symbol)) {
      return const [];
    }

    final override = _liveOverride;
    final isDragged = override != null && override.symbolId == symbol.symbolId;
    final xM = isDragged ? override.xM : symbol.xM;
    final yM = isDragged ? override.yM : symbol.yM;
    final widthM = isDragged ? override.widthM : symbol.widthM;
    final heightM = isDragged ? override.heightM : symbol.heightM;
    final rotationDeg = isDragged ? override.rotationDeg : symbol.rotationDeg;

    final centre = ocptFloorPlanScreenPointOf(xM: xM, yM: yM, canvasSize: canvasSize, zoom: zoom, pan: pan);
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);

    final resizeLocal = Offset(widthM / 2, heightM / 2);
    final resizeScreen = centre + ocptFloorPlanRotateVector(resizeLocal * pixelsPerMetre, rotationDeg);

    final rotateLocalM = Offset(0, -(heightM / 2 + _rotateHandleGapM));
    final rotateScreen =
        centre + ocptFloorPlanRotateVector(rotateLocalM * pixelsPerMetre, rotationDeg);

    final theme = Theme.of(context);

    return [
      if (widget.onSymbolResized != null)
        Positioned(
          left: resizeScreen.dx - _handleHitSize / 2,
          top: resizeScreen.dy - _handleHitSize / 2,
          width: _handleHitSize,
          height: _handleHitSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: (_) => setState(() {
              _dragKind = _SymbolDragKind.resize;
              _liveOverride = OcptFloorPlanSymbolLiveOverride(
                symbolId: symbol.symbolId,
                xM: symbol.xM,
                yM: symbol.yM,
                widthM: symbol.widthM,
                heightM: symbol.heightM,
                rotationDeg: symbol.rotationDeg,
              );
            }),
            onPanUpdate: (details) => _updateSymbolDrag(symbol.symbolId, details.delta, zoom),
            onPanEnd: (_) => _commitSymbolDrag(symbol),
            child: _HandleDot(color: theme.colorScheme.primary),
          ),
        ),
      if (widget.onSymbolRotated != null)
        Positioned(
          left: rotateScreen.dx - _handleHitSize / 2,
          top: rotateScreen.dy - _handleHitSize / 2,
          width: _handleHitSize,
          height: _handleHitSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() {
              _dragKind = _SymbolDragKind.rotate;
              _liveOverride = OcptFloorPlanSymbolLiveOverride(
                symbolId: symbol.symbolId,
                xM: symbol.xM,
                yM: symbol.yM,
                widthM: symbol.widthM,
                heightM: symbol.heightM,
                rotationDeg: symbol.rotationDeg,
              );
            }),
            onPanUpdate: (details) => _updateRotateDrag(
              symbol.symbolId,
              _resolveLocalPosition(details.globalPosition),
              canvasSize,
              zoom,
              pan,
            ),
            onPanEnd: (_) => _commitSymbolDrag(symbol),
            child: _HandleDot(color: theme.colorScheme.secondary),
          ),
        ),
      if (widget.onSymbolFovChanged != null && symbol.cameraFovWedgeDeg != null)
        ..._buildFovHandles(symbol, centre, rotationDeg, pixelsPerMetre, canvasSize, zoom, pan),
      if (widget.onSymbolFovReachChanged != null && symbol.cameraFovWedgeDeg != null)
        _buildFovReachHandle(symbol, centre, rotationDeg, pixelsPerMetre, canvasSize, zoom, pan),
      if (widget.onSymbolDeleteRequested != null)
        Positioned(
          left: resizeScreen.dx + _handleHitSize,
          top: centre.dy - heightM / 2 * pixelsPerMetre - _handleHitSize,
          child: _DeleteHandle(
            tooltip: Tr.of(context).shotListFloorPlanDeleteSymbolAction,
            onTap: () => widget.onSymbolDeleteRequested!(symbol.symbolId),
          ),
        ),
    ];
  }

  /// A camera symbol's own two field-of-view edge handles, one on each side of its wedge (drawn by
  /// `OcptFloorPlanCanvasPainter._paintCameraGlyph`, `ocptFloorPlanCameraFovWedgeLengthM` from the
  /// lens): dragging either narrows or widens [OcptFloorPlanSymbolShape.cameraFovWedgeDeg] — the
  /// wedge stays symmetric around the symbol's own heading, so both handles always sit the same
  /// distance from it.
  List<Widget> _buildFovHandles(
    OcptFloorPlanSymbolShape symbol,
    Offset centre,
    double rotationDeg,
    double pixelsPerMetre,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final override = _liveOverride;
    final fovDeg =
        (override != null && override.symbolId == symbol.symbolId ? override.fovDeg : null) ??
        symbol.cameraFovWedgeDeg!;
    final halfAngleRad = fovDeg * math.pi / 180 / 2;
    final wedgeLengthPx = ocptFloorPlanCameraFovWedgeLengthM * pixelsPerMetre;
    final tipLocalPx = Offset(0, -symbol.heightM / 2 * pixelsPerMetre);

    Widget buildHandle(double sign) {
      final localPx =
          tipLocalPx + Offset(sign * math.sin(halfAngleRad), -math.cos(halfAngleRad)) * wedgeLengthPx;
      final screen = centre + ocptFloorPlanRotateVector(localPx, rotationDeg);

      return Positioned(
        left: screen.dx - _handleHitSize / 2,
        top: screen.dy - _handleHitSize / 2,
        width: _handleHitSize,
        height: _handleHitSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (_) => setState(() {
            _dragKind = _SymbolDragKind.fov;
            _liveOverride = OcptFloorPlanSymbolLiveOverride(
              symbolId: symbol.symbolId,
              xM: symbol.xM,
              yM: symbol.yM,
              widthM: symbol.widthM,
              heightM: symbol.heightM,
              rotationDeg: symbol.rotationDeg,
              fovDeg: fovDeg,
            );
          }),
          onPanUpdate: (details) => _updateFovDrag(
            symbol.symbolId,
            _resolveLocalPosition(details.globalPosition),
            canvasSize,
            zoom,
            pan,
          ),
          onPanEnd: (_) => _commitSymbolDrag(symbol),
          child: _HandleDot(color: Theme.of(context).colorScheme.tertiary),
        ),
      );
    }

    return [buildHandle(-1), buildHandle(1)];
  }

  /// A camera symbol's own field-of-view **tip** handle, straight ahead of its lens at the wedge's
  /// own reach (`OcptFloorPlanSymbolShape.cameraFovWedgeReachM`) — dragging it changes how far the
  /// wedge reaches, never its angle (the two edge handles' own job, [_buildFovHandles]).
  Widget _buildFovReachHandle(
    OcptFloorPlanSymbolShape symbol,
    Offset centre,
    double rotationDeg,
    double pixelsPerMetre,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final override = _liveOverride;
    final fovReachM =
        (override != null && override.symbolId == symbol.symbolId ? override.fovReachM : null) ??
        symbol.cameraFovWedgeReachM!;
    final tipLocalPx = Offset(0, -symbol.heightM / 2 * pixelsPerMetre);
    final localPx = tipLocalPx + Offset(0, -fovReachM * pixelsPerMetre);
    final screen = centre + ocptFloorPlanRotateVector(localPx, rotationDeg);

    return Positioned(
      left: screen.dx - _handleHitSize / 2,
      top: screen.dy - _handleHitSize / 2,
      width: _handleHitSize,
      height: _handleHitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => setState(() {
          _dragKind = _SymbolDragKind.fovReach;
          _liveOverride = OcptFloorPlanSymbolLiveOverride(
            symbolId: symbol.symbolId,
            xM: symbol.xM,
            yM: symbol.yM,
            widthM: symbol.widthM,
            heightM: symbol.heightM,
            rotationDeg: symbol.rotationDeg,
            fovReachM: fovReachM,
          );
        }),
        onPanUpdate: (details) => _updateFovReachDrag(
          symbol.symbolId,
          _resolveLocalPosition(details.globalPosition),
          canvasSize,
          zoom,
          pan,
        ),
        onPanEnd: (_) => _commitSymbolDrag(symbol),
        child: _HandleDot(color: Theme.of(context).colorScheme.tertiary),
      ),
    );
  }

  /// Updates [_liveOverride]'s own field-of-view reach every frame of a tip-handle drag: the
  /// pointer's own distance from the symbol's centre, projected onto its own heading vector (so a
  /// pointer straying sideways still reads as a forward/backward reach rather than snapping), in
  /// **canvas space** (through [_resolveLocalPosition], the same fix [_updateRotateDrag] needs),
  /// minus the half-footprint already between the centre and the lens — clamped to
  /// [ocptFloorPlanMinCameraFovReachM]..[ocptFloorPlanMaxCameraFovReachM].
  void _updateFovReachDrag(
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

    final centreScreen = ocptFloorPlanScreenPointOf(
      xM: override.xM,
      yM: override.yM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final pointerVector = localPosition - centreScreen;
    final headingRad = override.rotationDeg * math.pi / 180;
    final headingVector = Offset(math.sin(headingRad), -math.cos(headingRad));
    final forwardPx = pointerVector.dx * headingVector.dx + pointerVector.dy * headingVector.dy;
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final fovReachM = (forwardPx / pixelsPerMetre - override.heightM / 2).clamp(
      ocptFloorPlanMinCameraFovReachM,
      ocptFloorPlanMaxCameraFovReachM,
    );

    setState(() {
      _liveOverride = OcptFloorPlanSymbolLiveOverride(
        symbolId: symbolId,
        xM: override.xM,
        yM: override.yM,
        widthM: override.widthM,
        heightM: override.heightM,
        rotationDeg: override.rotationDeg,
        fovReachM: fovReachM,
      );
    });
  }

  /// Updates [_liveOverride]'s own field-of-view angle every frame of an edge-handle drag: the
  /// pointer's own bearing around the symbol's centre, in **canvas space** (through
  /// [_resolveLocalPosition], the same fix [_updateRotateDrag] needs), turned into the symbol's own
  /// **local** frame (`-rotationDeg`, undoing its own heading) so `0°` always means "straight
  /// ahead" whichever way the camera itself is aimed — the wedge's own half-angle is simply that
  /// local bearing's absolute value, doubled and clamped.
  void _updateFovDrag(
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

    final centreScreen = ocptFloorPlanScreenPointOf(
      xM: override.xM,
      yM: override.yM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final pointerVector = localPosition - centreScreen;
    final worldBearingRad = math.atan2(pointerVector.dx, -pointerVector.dy);
    final localBearingRad = worldBearingRad - override.rotationDeg * math.pi / 180;
    final halfAngleDeg = (localBearingRad * 180 / math.pi).abs() % 360;
    final fovDeg = (2 * halfAngleDeg).clamp(
      ocptFloorPlanMinCameraFovDeg,
      ocptFloorPlanMaxCameraFovDeg,
    );

    setState(() {
      _liveOverride = OcptFloorPlanSymbolLiveOverride(
        symbolId: symbolId,
        xM: override.xM,
        yM: override.yM,
        widthM: override.widthM,
        heightM: override.heightM,
        rotationDeg: override.rotationDeg,
        fovDeg: fovDeg,
      );
    });
  }

  /// Updates [_liveOverride]'s own move/resize geometry every frame of a symbol drag, no database
  /// write and no bloc emission until [_commitSymbolDrag].
  ///
  /// The move handle's own `GestureDetector` is wrapped in a `Transform.rotate` (see
  /// [_buildSymbolHitOverlay]), so Flutter hands [screenDelta] already expressed in that rotated
  /// **local** frame (the hit-test transform a drag's own `onPanUpdate` reads is the one captured
  /// at `onPanStart`, and stays the rotated one for the whole gesture) — it has to be turned back
  /// into the **world** frame [OcptFloorPlanCanvas.onSymbolMoved] stores `xM`/`yM` in before it is
  /// added, by [ocptFloorPlanRotateVector]'s own forward convention (`+rotationDeg`, local → world;
  /// the resize branch below instead turns a genuinely world-frame delta *into* the symbol's own
  /// local width/height axes, hence its own `-rotationDeg`). At `rotationDeg == 0` the two frames
  /// coincide, which is why an unrotated symbol never showed the drift. See every drag handle's own
  /// `dragStartBehavior: DragStartBehavior.down` for the other half of the fix: left at its default
  /// (`.start`), the pointer movement spent recognising the gesture as a drag at all (crossing the
  /// touch slop) is silently dropped from ever reaching an `onPanUpdate`, so the dragged point
  /// permanently trails the pointer by that amount — the "slight offset" on every drag alike,
  /// unrelated to rotation.
  void _updateSymbolDrag(String symbolId, Offset screenDelta, double zoom) {
    final override = _liveOverride;
    if (override == null || override.symbolId != symbolId) {
      return;
    }

    final metresDelta = ocptFloorPlanScreenVectorToMetres(screenDelta: screenDelta, zoom: zoom);

    setState(() {
      if (_dragKind == _SymbolDragKind.move) {
        final worldDelta = ocptFloorPlanRotateVector(metresDelta, override.rotationDeg);
        _liveOverride = OcptFloorPlanSymbolLiveOverride(
          symbolId: symbolId,
          xM: override.xM + worldDelta.dx,
          yM: override.yM + worldDelta.dy,
          widthM: override.widthM,
          heightM: override.heightM,
          rotationDeg: override.rotationDeg,
        );
        return;
      }

      if (_dragKind == _SymbolDragKind.resize) {
        final local = ocptFloorPlanRotateVector(metresDelta, -override.rotationDeg);
        _liveOverride = OcptFloorPlanSymbolLiveOverride(
          symbolId: symbolId,
          xM: override.xM,
          yM: override.yM,
          widthM: math.max(_minSymbolFootprintM, override.widthM + 2 * local.dx),
          heightM: math.max(_minSymbolFootprintM, override.heightM + 2 * local.dy),
          rotationDeg: override.rotationDeg,
        );
      }
    });
  }

  /// Updates [_liveOverride]'s own rotation (bearing) every frame of an aim-handle drag, from the
  /// pointer's own bearing around the symbol's centre (0° pointing up, clockwise positive — see
  /// `ocptFloorPlanRotateVector`'s own doc comment for the same screen convention read the other
  /// way), **[localPosition] already converted to canvas space** by [_resolveLocalPosition] — the
  /// rotation bug this milestone fixes was reading the handle's own local position instead, which
  /// is relative to that tiny hit box rather than to the canvas the symbol's own centre is placed
  /// in, so the computed bearing bore no relation to where the pointer actually was. Holding `Shift`
  /// snaps the result to [_rotateSnapStepDeg]° steps.
  void _updateRotateDrag(
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

    final centreScreen = ocptFloorPlanScreenPointOf(
      xM: override.xM,
      yM: override.yM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final pointerVector = localPosition - centreScreen;
    var bearingDeg = math.atan2(pointerVector.dx, -pointerVector.dy) * 180 / math.pi;
    bearingDeg = bearingDeg < 0 ? bearingDeg + 360 : bearingDeg;
    if (HardwareKeyboard.instance.isShiftPressed) {
      bearingDeg = (bearingDeg / _rotateSnapStepDeg).round() * _rotateSnapStepDeg % 360;
    }

    setState(() {
      _liveOverride = OcptFloorPlanSymbolLiveOverride(
        symbolId: symbolId,
        xM: override.xM,
        yM: override.yM,
        widthM: override.widthM,
        heightM: override.heightM,
        rotationDeg: bearingDeg,
      );
    });
  }

  /// Reports the dragged symbol's own settled geometry (move, resize, aim or field of view,
  /// whichever [_dragKind] names) and clears the live drag state. A move drag armed as
  /// [_isDuplicatingDrag] (`Alt` held at its own `onPanStart`) reports through
  /// [OcptFloorPlanCanvas.onSymbolDuplicateDragged] instead of [OcptFloorPlanCanvas.onSymbolMoved]:
  /// [symbol] itself is left untouched at its own original position, a new, independent copy placed
  /// at the drag's own settled point instead.
  void _commitSymbolDrag(OcptFloorPlanSymbolShape symbol) {
    final override = _liveOverride;
    final kind = _dragKind;
    final wasDuplicating = _isDuplicatingDrag;
    setState(() {
      _dragKind = null;
      _liveOverride = null;
      _isDuplicatingDrag = false;
    });
    if (override == null || kind == null) {
      return;
    }

    switch (kind) {
      case _SymbolDragKind.move:
        if (wasDuplicating) {
          widget.onSymbolDuplicateDragged?.call(symbol.symbolId, override.xM, override.yM);
        } else {
          widget.onSymbolMoved?.call(symbol.symbolId, override.xM, override.yM);
        }
      case _SymbolDragKind.resize:
        widget.onSymbolResized?.call(symbol.symbolId, override.widthM, override.heightM);
      case _SymbolDragKind.rotate:
        widget.onSymbolRotated?.call(symbol.symbolId, override.rotationDeg);
      case _SymbolDragKind.fov:
        final fovDeg = override.fovDeg;
        if (fovDeg != null) {
          widget.onSymbolFovChanged?.call(symbol.symbolId, fovDeg);
        }
      case _SymbolDragKind.fovReach:
        final fovReachM = override.fovReachM;
        if (fovReachM != null) {
          widget.onSymbolFovReachChanged?.call(symbol.symbolId, fovReachM);
        }
    }
  }

  /// The `label` tool's own inline text box, centred under [symbol]'s own footprint (where its
  /// drawn label already sits, see `OcptFloorPlanCanvasPainter._paintLabel`), editing its label in
  /// place.
  Widget _buildLabelEditor(
    OcptFloorPlanSymbolShape symbol,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final centre = ocptFloorPlanScreenPointOf(
      xM: symbol.xM,
      yM: symbol.yM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final heightPx = symbol.heightM * pixelsPerMetre;

    return Positioned(
      left: centre.dx - _labelEditorWidth / 2,
      top: centre.dy + heightPx / 2 + 20,
      width: _labelEditorWidth,
      height: _labelEditorHeight,
      child: _OcptFloorPlanSymbolLabelField(
        symbolId: symbol.symbolId,
        value: widget.symbolLabelValueOf(symbol.symbolId),
        onChanged: widget.isReadOnly || widget.onSymbolLabelChanged == null
            ? null
            : (value) => widget.onSymbolLabelChanged!(symbol.symbolId, value),
      ),
    );
  }

  /// The selected arrow's own midpoint handle (drag to bend, drop to write one row) and, while it
  /// already carries a curve, its neighbouring straighten button — an empty list while withheld
  /// under a read-only preview, a ghost or [OcptFloorPlanCanvas.onArrowCurveChanged] being null.
  List<Widget> _buildArrowHandle(
    OcptFloorPlanArrowShape arrow,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final onArrowCurveChanged = widget.onArrowCurveChanged;
    if (widget.isReadOnly || arrow.isGhost || onArrowCurveChanged == null) {
      return const [];
    }

    final live = _liveArrowCtrl;
    final isDragged = live != null && _draggedArrowId == arrow.arrowId;
    final ctrlXM = isDragged ? live.xM : (arrow.ctrlXM ?? (arrow.fromXM + arrow.toXM) / 2);
    final ctrlYM = isDragged ? live.yM : (arrow.ctrlYM ?? (arrow.fromYM + arrow.toYM) / 2);
    final handleScreen = ocptFloorPlanScreenPointOf(
      xM: ctrlXM,
      yM: ctrlYM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final theme = Theme.of(context);

    final widgets = <Widget>[
      Positioned(
        left: handleScreen.dx - _handleHitSize / 2,
        top: handleScreen.dy - _handleHitSize / 2,
        width: _handleHitSize,
        height: _handleHitSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (_) => setState(() {
            _draggedArrowId = arrow.arrowId;
            _liveArrowCtrl = (xM: ctrlXM, yM: ctrlYM);
          }),
          onPanUpdate: (details) => _updateArrowCurveDrag(arrow.arrowId, details.delta, zoom),
          onPanEnd: (_) => _commitArrowCurveDrag(arrow),
          child: _HandleDot(color: theme.colorScheme.tertiary),
        ),
      ),
    ];

    if (arrow.ctrlXM != null && !isDragged) {
      widgets.add(
        Positioned(
          left: handleScreen.dx + _handleHitSize,
          top: handleScreen.dy - _handleHitSize,
          child: _StraightenHandle(
            tooltip: Tr.of(context).shotListFloorPlanStraightenArrowAction,
            onTap: () => onArrowCurveChanged(arrow.arrowId, null, null),
          ),
        ),
      );
    }

    return widgets;
  }

  /// Updates [_liveArrowCtrl] every frame of an arrow midpoint drag, no database write and no bloc
  /// emission until [_commitArrowCurveDrag] — mirrors [_updateSymbolDrag]'s own live-override
  /// pattern, with no rotation to undo since an arrow's own control point is a plain world-frame
  /// point.
  void _updateArrowCurveDrag(String arrowId, Offset screenDelta, double zoom) {
    final live = _liveArrowCtrl;
    if (live == null || _draggedArrowId != arrowId) {
      return;
    }

    final metresDelta = ocptFloorPlanScreenVectorToMetres(screenDelta: screenDelta, zoom: zoom);
    setState(() {
      _liveArrowCtrl = (xM: live.xM + metresDelta.dx, yM: live.yM + metresDelta.dy);
    });
  }

  /// Reports the dragged arrow's own settled control point and clears the live drag state — unless
  /// it landed close enough to the straight from-to line ([_arrowStraightenToleranceM]), in which
  /// case it straightens the arrow back out instead.
  void _commitArrowCurveDrag(OcptFloorPlanArrowShape arrow) {
    final live = _liveArrowCtrl;
    setState(() {
      _liveArrowCtrl = null;
      _draggedArrowId = null;
    });

    final onArrowCurveChanged = widget.onArrowCurveChanged;
    if (live == null || onArrowCurveChanged == null) {
      return;
    }

    final distanceToStraightM = _distanceToSegmentM(
      live.xM,
      live.yM,
      arrow.fromXM,
      arrow.fromYM,
      arrow.toXM,
      arrow.toYM,
    );
    if (distanceToStraightM <= _arrowStraightenToleranceM) {
      onArrowCurveChanged(arrow.arrowId, null, null);
      return;
    }

    onArrowCurveChanged(arrow.arrowId, live.xM, live.yM);
  }
}

/// Which gesture a symbol's own drag currently means.
enum _SymbolDragKind { move, resize, rotate, fov, fovReach }

/// Which gesture the underlay's own drag currently means.
enum _UnderlayDragKind { move, resize }

/// A small filled circle marking a draggable handle.
class _HandleDot extends StatelessWidget {
  /// The handle's own colour.
  final Color color;

  /// Class constructor
  const _HandleDot({required this.color});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    ),
  );
}

/// The selected symbol's own small delete button.
class _DeleteHandle extends StatelessWidget {
  /// The button's own tooltip.
  final String tooltip;

  /// Called when tapped.
  final VoidCallback onTap;

  /// Class constructor
  const _DeleteHandle({required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _handleHitSize,
          height: _handleHitSize,
          decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
          child: Icon(Icons.close, size: 12, color: theme.colorScheme.onError),
        ),
      ),
    );
  }
}

/// The selected arrow's own small straighten button, drawn next to its midpoint handle while it
/// already carries a curve — alongside dragging the handle back onto the straight line.
class _StraightenHandle extends StatelessWidget {
  /// The button's own tooltip.
  final String tooltip;

  /// Called when tapped.
  final VoidCallback onTap;

  /// Class constructor
  const _StraightenHandle({required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _handleHitSize,
          height: _handleHitSize,
          decoration: BoxDecoration(color: theme.colorScheme.secondary, shape: BoxShape.circle),
          child: Icon(Icons.straighten, size: 12, color: theme.colorScheme.onSecondary),
        ),
      ),
    );
  }
}

/// The `label` tool's own compact inline text box, floating over the canvas at the selected
/// symbol's own position (`OcptFloorPlanCanvas._buildLabelEditor`).
///
/// [onChanged] is null while withheld (a read-only preview), which is what makes the field read
/// its value out instead of accepting one, mirroring `OcptShotInspectorField`'s own reading. The
/// internal controller is only ever reset to [value] when [symbolId] changes (a different symbol
/// is now selected) or [value] genuinely differs from what the controller already holds (an edit
/// landed, or a reload changed the underlying data) — see `OcptShotInspectorField`'s own doc
/// comment for why a rebuild for an unrelated reason must never touch the controller, or the caret
/// jumps mid-typing.
class _OcptFloorPlanSymbolLabelField extends StatefulWidget {
  /// The id of the symbol this field edits, used only to detect a symbol switch.
  final String symbolId;

  /// The field's current authoritative value.
  final String value;

  /// Called with the field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const _OcptFloorPlanSymbolLabelField({
    required this.symbolId,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_OcptFloorPlanSymbolLabelField> createState() => _OcptFloorPlanSymbolLabelFieldState();
}

class _OcptFloorPlanSymbolLabelFieldState extends State<_OcptFloorPlanSymbolLabelField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OcptFloorPlanSymbolLabelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.symbolId != oldWidget.symbolId || widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: TextField(
        controller: _controller,
        enabled: widget.onChanged != null,
        onChanged: widget.onChanged,
        style: theme.textTheme.bodySmall,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ocptRadiusSmall)),
          hintText: Tr.of(context).shotListFloorPlanSymbolLabelFieldHint,
        ),
      ),
    );
  }
}
