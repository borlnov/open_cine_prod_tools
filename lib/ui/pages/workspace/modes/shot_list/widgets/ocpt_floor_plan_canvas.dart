// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_case.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
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

/// The floor plans canvas: a `CustomPaint` of the `OcptFloorPlanSheet` the current focus builds
/// for [floorPlanCase], under a `GestureDetector` (`docs/plans/storyboard.md`, §4.3).
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
/// Placing a set element: pick the `setElement` tool, click → [onSymbolPlaced] into the tray's
/// active sequence layer. Dragging a symbol moves it (one [onSymbolMoved] on drag end, in metres);
/// dragging its own resize/rotate handle resizes/rotates it (one [onSymbolResized]/[onSymbolRotated]
/// on drag end). Every write is **withheld** under [isReadOnly] (a null `onSymbolPlaced`/move/
/// resize/rotate/delete/arrow/label closes the whole gesture, exactly as the board's null callbacks
/// do); zoom, pan, selecting, the metrics overlay and the tray's own visibility toggles stay
/// available, since they only read.
class OcptFloorPlanCanvas extends StatefulWidget {
  /// The case currently shown, or null while none is selected (the empty state).
  final OcptFloorPlanCase? floorPlanCase;

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

  /// Whether the case's own underlay is currently hidden.
  final bool isUnderlayHidden;

  /// The id of the currently selected symbol, or null while none is.
  final String? selectedSymbolId;

  /// The id of the symbol picked as the arrow tool's own pending first end, or null while none is.
  final String? pendingArrowAnchorSymbolId;

  /// Whether the metrics overlay is shown: the distance from the selected symbol to every other
  /// visible symbol of the case.
  final bool isMetricsShown;

  /// The canvas's own currently active tool.
  final OcptFloorPlanTool activeTool;

  /// The sequence layer a placed set element lands on.
  final OcptFloorPlanLayer activeLayer;

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
  final void Function(OcptFloorPlanLayer layer, String? shotId, double xM, double yM)?
  onSymbolPlaced;

  /// Called with a symbol's id and its new centre (metres) once a drag moving it ends, or null
  /// while withheld.
  final void Function(String symbolId, double xM, double yM)? onSymbolMoved;

  /// Called with a symbol's id and its new footprint (metres) once a drag on its own resize handle
  /// ends, or null while withheld.
  final void Function(String symbolId, double widthM, double heightM)? onSymbolResized;

  /// Called with a symbol's id and its new rotation (degrees) once a drag on its own rotate handle
  /// ends, or null while withheld.
  final void Function(String symbolId, double rotationDeg)? onSymbolRotated;

  /// Called with the selected symbol's id when its own delete action is clicked, or null while
  /// withheld. Only asks — the mode opens `OcptConfirmDialog`.
  final ValueChanged<String>? onSymbolDeleteRequested;

  /// Called with a (non-ghost) symbol's id when it is tapped while the `arrow` tool is on, or null
  /// while withheld.
  final ValueChanged<String>? onArrowSymbolTapped;

  /// Called to cancel the arrow tool's own pending anchor — `Escape` or a click on empty canvas
  /// while it is on — or null while withheld (nothing pending, or a read-only preview).
  final VoidCallback? onArrowAnchorCancelled;

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
    required this.floorPlanCase,
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
    required this.pendingArrowAnchorSymbolId,
    required this.isMetricsShown,
    required this.activeTool,
    required this.activeLayer,
    required this.viewportController,
    required this.isReadOnly,
    required this.symbolLabelValueOf,
    required this.onSymbolSelected,
    required this.onSymbolPlaced,
    required this.onSymbolMoved,
    required this.onSymbolResized,
    required this.onSymbolRotated,
    required this.onSymbolDeleteRequested,
    required this.onArrowSymbolTapped,
    required this.onArrowAnchorCancelled,
    required this.onGhostShotFocusRequested,
    required this.onSymbolLabelChanged,
    required this.onUnderlayTransformChanged,
    required this.onZoomSettled,
  });

  @override
  State<OcptFloorPlanCanvas> createState() => _OcptFloorPlanCanvasState();
}

class _OcptFloorPlanCanvasState extends State<OcptFloorPlanCanvas> {
  /// Which gesture the symbol drag currently in progress means (move, resize or rotate), or null
  /// while none is — alongside [_liveOverride], which names *which* symbol.
  _SymbolDragKind? _dragKind;

  /// The dragged symbol's live geometry, updated every frame of the drag. See
  /// [OcptFloorPlanSymbolLiveOverride].
  OcptFloorPlanSymbolLiveOverride? _liveOverride;

  /// The underlay's own live frame while it is being moved or resized, or null while it isn't.
  ({double xM, double yM, double widthM, double heightM})? _liveUnderlayFrame;

  /// Which gesture the current underlay drag means, or null alongside [_liveUnderlayFrame].
  _UnderlayDragKind? _underlayDragKind;

  /// The debounce timer settling a scroll-wheel zoom into [OcptFloorPlanCanvas.onZoomSettled].
  Timer? _wheelZoomSettleTimer;

  @override
  void dispose() {
    _wheelZoomSettleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final floorPlanCase = widget.floorPlanCase;

    if (floorPlanCase == null) {
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
            final sheet = _sheetOf(floorPlanCase);
            final barLengthM = ocptFloorPlanScaleBarLengthM(zoom: zoom);

            final selectedShape = _selectedShapeOf(sheet);

            return ClipRect(
              child: Stack(
                children: [
                  if (!widget.isUnderlayHidden && floorPlanCase.underlayAssetId != null)
                    _buildUnderlayVisual(floorPlanCase, canvasSize, zoom, pan),
                  Positioned.fill(
                    child: Listener(
                      onPointerSignal: _handlePointerSignal,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) =>
                            _handleBackgroundTap(details.localPosition, canvasSize, zoom, pan),
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
                  if (!widget.isUnderlayHidden &&
                      floorPlanCase.underlayAssetId != null &&
                      !widget.isReadOnly &&
                      widget.onUnderlayTransformChanged != null)
                    ..._buildUnderlayHandles(floorPlanCase, canvasSize, zoom, pan),
                  for (final symbol in sheet.symbols)
                    _buildSymbolHitOverlay(symbol, canvasSize, zoom, pan),
                  if (selectedShape != null)
                    ..._buildSymbolHandles(selectedShape, canvasSize, zoom, pan),
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
  OcptFloorPlanSheet _sheetOf(OcptFloorPlanCase floorPlanCase) {
    final focusShotId = widget.focusShotId;
    final full = OcptFloorPlanSheet.of(
      floorPlanCase: floorPlanCase,
      focusShotId: focusShotId,
      shotRankByShotId: widget.shotRankByShotId,
      previousShotId: widget.isOnionSkinPreviousShown ? widget.previousShotId : null,
      nextShotId: widget.isOnionSkinNextShown ? widget.nextShotId : null,
    );
    final isSequenceFocus = focusShotId == null;

    return OcptFloorPlanSheet(
      caseId: full.caseId,
      caseName: full.caseName,
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

  /// Whether [symbol] may be dragged, resized, rotated or deleted under the current focus: never a
  /// ghost, and only a symbol of the scope the current focus makes live — a sequence layer under
  /// the `Sequence` focus, [OcptFloorPlanCanvas.focusShotId]'s own shot layers under a shot focus.
  /// The frozen scope stays selectable (so its own Placements/metrics still read), just locked.
  bool _isSymbolEditable(OcptFloorPlanSymbolShape symbol) {
    if (symbol.isGhost) {
      return false;
    }
    final isSequenceFocus = widget.focusShotId == null;
    return isSequenceFocus ? symbol.layer.isSequenceScoped : !symbol.layer.isSequenceScoped;
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

  /// A click on empty canvas (no symbol, no underlay handle caught it first): places a new symbol
  /// under a placing tool (`setElement` on the tray's active sequence layer, or `camera`/
  /// `character`/`light` on [OcptFloorPlanCanvas.focusShotId]'s own shot layer — a no-op while no
  /// shot is focused, defensive only, the tool bar already dims those three under the `Sequence`
  /// focus); cancels the arrow tool's own pending anchor under `arrow`; clears the selection
  /// otherwise (`select`, `label`, or an arrow tool with nothing pending).
  void _handleBackgroundTap(Offset localPosition, Size canvasSize, double zoom, Offset pan) {
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
      onSymbolPlaced(shotLayer ?? widget.activeLayer, shotId, metres.dx, metres.dy);
      return;
    }

    if (widget.activeTool == OcptFloorPlanTool.arrow) {
      widget.onArrowAnchorCancelled?.call();
    }

    widget.onSymbolSelected(null);
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
  Rect _underlayScreenRect(OcptFloorPlanCase floorPlanCase, Size canvasSize, double zoom, Offset pan) {
    final frame = _liveUnderlayFrame;
    final xM = frame?.xM ?? floorPlanCase.underlayXM ?? 0;
    final yM = frame?.yM ?? floorPlanCase.underlayYM ?? 0;
    final widthM = frame?.widthM ?? floorPlanCase.underlayWidthM ?? 0;
    final heightM = frame?.heightM ?? floorPlanCase.underlayHeightM ?? 0;
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
  Widget _buildUnderlayVisual(OcptFloorPlanCase floorPlanCase, Size canvasSize, double zoom, Offset pan) {
    final rect = _underlayScreenRect(floorPlanCase, canvasSize, zoom, pan);
    final rotationDeg = floorPlanCase.underlayRotationDeg ?? 0;

    return IgnorePointer(
      child: Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: Transform.rotate(
          angle: rotationDeg * math.pi / 180,
          child: OcptReferencedImage(
            path: floorPlanCase.underlayPath,
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
    OcptFloorPlanCase floorPlanCase,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    final rect = _underlayScreenRect(floorPlanCase, canvasSize, zoom, pan);
    final rotationDeg = floorPlanCase.underlayRotationDeg ?? 0;

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
            onPanStart: (_) => setState(() {
              _underlayDragKind = _UnderlayDragKind.move;
              _liveUnderlayFrame = (
                xM: floorPlanCase.underlayXM ?? 0,
                yM: floorPlanCase.underlayYM ?? 0,
                widthM: floorPlanCase.underlayWidthM ?? 0,
                heightM: floorPlanCase.underlayHeightM ?? 0,
              );
            }),
            onPanUpdate: (details) => _updateUnderlayDrag(details.delta, zoom, rotationDeg),
            onPanEnd: (_) => _commitUnderlayDrag(floorPlanCase),
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
          onPanStart: (_) => setState(() {
            _underlayDragKind = _UnderlayDragKind.resize;
            _liveUnderlayFrame = (
              xM: floorPlanCase.underlayXM ?? 0,
              yM: floorPlanCase.underlayYM ?? 0,
              widthM: floorPlanCase.underlayWidthM ?? 0,
              heightM: floorPlanCase.underlayHeightM ?? 0,
            );
          }),
          onPanUpdate: (details) => _updateUnderlayDrag(details.delta, zoom, rotationDeg),
          onPanEnd: (_) => _commitUnderlayDrag(floorPlanCase),
          child: _HandleDot(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    ];
  }

  /// Updates [_liveUnderlayFrame] every frame of an underlay move/resize drag, no database write
  /// and no bloc emission until [_commitUnderlayDrag].
  void _updateUnderlayDrag(Offset screenDelta, double zoom, double rotationDeg) {
    final frame = _liveUnderlayFrame;
    if (frame == null) {
      return;
    }

    final metresDelta = ocptFloorPlanScreenVectorToMetres(screenDelta: screenDelta, zoom: zoom);

    setState(() {
      if (_underlayDragKind == _UnderlayDragKind.move) {
        _liveUnderlayFrame = (
          xM: frame.xM + metresDelta.dx,
          yM: frame.yM + metresDelta.dy,
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
  void _commitUnderlayDrag(OcptFloorPlanCase floorPlanCase) {
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
  /// shot id, focusing it.
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
          onTap: () => _handleSymbolTap(symbol),
          onDoubleTap: symbol.isGhost && shotId != null
              ? () => widget.onGhostShotFocusRequested?.call(shotId)
              : null,
          onPanStart: !canDrag
              ? null
              : (_) {
                  widget.onSymbolSelected(symbol.symbolId);
                  setState(() {
                    _dragKind = _SymbolDragKind.move;
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
  /// otherwise.
  void _handleSymbolTap(OcptFloorPlanSymbolShape symbol) {
    if (widget.activeTool == OcptFloorPlanTool.arrow) {
      if (!symbol.isGhost) {
        widget.onArrowSymbolTapped?.call(symbol.symbolId);
      }
      return;
    }
    widget.onSymbolSelected(symbol.symbolId);
  }

  /// The selected symbol's own resize + rotate handles, or an empty list while withheld under a
  /// read-only preview or while [_isSymbolEditable] locks it under the current focus.
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
            onPanUpdate: (details) =>
                _updateRotateDrag(symbol.symbolId, details.localPosition, canvasSize, zoom, pan),
            onPanEnd: (_) => _commitSymbolDrag(symbol),
            child: _HandleDot(color: theme.colorScheme.secondary),
          ),
        ),
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

  /// Updates [_liveOverride]'s own move/resize geometry every frame of a symbol drag, no database
  /// write and no bloc emission until [_commitSymbolDrag].
  void _updateSymbolDrag(String symbolId, Offset screenDelta, double zoom) {
    final override = _liveOverride;
    if (override == null || override.symbolId != symbolId) {
      return;
    }

    final metresDelta = ocptFloorPlanScreenVectorToMetres(screenDelta: screenDelta, zoom: zoom);

    setState(() {
      if (_dragKind == _SymbolDragKind.move) {
        _liveOverride = OcptFloorPlanSymbolLiveOverride(
          symbolId: symbolId,
          xM: override.xM + metresDelta.dx,
          yM: override.yM + metresDelta.dy,
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

  /// Updates [_liveOverride]'s own rotation every frame of a rotate-handle drag, from the pointer's
  /// own bearing around the symbol's centre (0° pointing up, clockwise positive — see
  /// `ocptFloorPlanRotateVector`'s own doc comment for the same screen convention read the other
  /// way).
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
    final bearingDeg = math.atan2(pointerVector.dx, -pointerVector.dy) * 180 / math.pi;

    setState(() {
      _liveOverride = OcptFloorPlanSymbolLiveOverride(
        symbolId: symbolId,
        xM: override.xM,
        yM: override.yM,
        widthM: override.widthM,
        heightM: override.heightM,
        rotationDeg: bearingDeg < 0 ? bearingDeg + 360 : bearingDeg,
      );
    });
  }

  /// Reports the dragged symbol's own settled geometry (move, resize or rotate, whichever
  /// [_dragKind] names) and clears the live drag state.
  void _commitSymbolDrag(OcptFloorPlanSymbolShape symbol) {
    final override = _liveOverride;
    final kind = _dragKind;
    setState(() {
      _dragKind = null;
      _liveOverride = null;
    });
    if (override == null || kind == null) {
      return;
    }

    switch (kind) {
      case _SymbolDragKind.move:
        widget.onSymbolMoved?.call(symbol.symbolId, override.xM, override.yM);
      case _SymbolDragKind.resize:
        widget.onSymbolResized?.call(symbol.symbolId, override.widthM, override.heightM);
      case _SymbolDragKind.rotate:
        widget.onSymbolRotated?.call(symbol.symbolId, override.rotationDeg);
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
}

/// Which gesture a symbol's own drag currently means.
enum _SymbolDragKind { move, resize, rotate }

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
