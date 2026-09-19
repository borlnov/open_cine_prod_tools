// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_case.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_viewport_controller.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

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

/// The floor plans canvas: a `CustomPaint` of the `OcptFloorPlanSheet` the sequence focus builds
/// for [floorPlanCase], under a `GestureDetector` (`docs/plans/storyboard.md`, §4.3).
///
/// Geometry is drawn from **metres → logical pixels at [OcptFloorPlanCanvas.viewportController]'s
/// current zoom**, through `ocpt_floor_plan_geometry.dart` — never a stored pixel value. Placing a
/// set element: pick the `setElement` tool, click → [onSymbolPlaced] into the tray's active
/// sequence layer. Dragging a symbol moves it (one [onSymbolMoved] on drag end, in metres);
/// dragging its own resize/rotate handle resizes/rotates it (one [onSymbolResized]/[onSymbolRotated]
/// on drag end). Every write is **withheld** under [isReadOnly] (a null `onSymbolPlaced`/move/
/// resize/rotate/delete closes the whole gesture, exactly as the board's null callbacks do); zoom,
/// pan and the tray's own visibility toggles stay available, since they only read.
class OcptFloorPlanCanvas extends StatefulWidget {
  /// The case currently shown, or null while none is selected (the empty state).
  final OcptFloorPlanCase? floorPlanCase;

  /// Every shot of the selected sequence's own 1-based display rank, keyed by shot id — what
  /// `OcptFloorPlanSheet.of` derives a camera's number from. Always built from the sequence even
  /// though no shot-scoped symbol exists yet in this milestone, so the sheet builder never has to
  /// special-case an empty map.
  final Map<String, int> shotRankByShotId;

  /// The sequence layers currently hidden, out of the tray's own three rows.
  final Set<OcptFloorPlanLayer> hiddenLayers;

  /// Whether the case's own underlay is currently hidden.
  final bool isUnderlayHidden;

  /// The id of the currently selected symbol, or null while none is.
  final String? selectedSymbolId;

  /// The canvas's own currently active tool.
  final OcptFloorPlanTool activeTool;

  /// The sequence layer a placed set element lands on.
  final OcptFloorPlanLayer activeLayer;

  /// The live zoom/pan controller this canvas draws and drags against — see that class's own doc
  /// comment for why it lives outside the bloc.
  final OcptFloorPlanViewportController viewportController;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// Called with a symbol's id when it is selected, or null when empty canvas is clicked while the
  /// `select` tool is on (clearing the selection). Never withheld: selecting only reads.
  final ValueChanged<String?> onSymbolSelected;

  /// Called with the tray's active layer and the clicked point (metres) when empty canvas is
  /// clicked while the `setElement` tool is on, or null while withheld.
  final void Function(OcptFloorPlanLayer layer, double xM, double yM)? onSymbolPlaced;

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
    required this.hiddenLayers,
    required this.isUnderlayHidden,
    required this.selectedSymbolId,
    required this.activeTool,
    required this.activeLayer,
    required this.viewportController,
    required this.isReadOnly,
    required this.onSymbolSelected,
    required this.onSymbolPlaced,
    required this.onSymbolMoved,
    required this.onSymbolResized,
    required this.onSymbolRotated,
    required this.onSymbolDeleteRequested,
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
                            liveOverride: _liveOverride,
                            symbolBorderColor: theme.colorScheme.outline,
                            selectionColor: theme.colorScheme.primary,
                            labelTextColor: theme.colorScheme.onSurface,
                            scaleColor: theme.colorScheme.onSurfaceVariant,
                            scaleBarLabel: tr.shotListFloorPlanScaleBarLengthLabel(
                              ocptFloorPlanScaleBarLengthLabelOf(barLengthM),
                            ),
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
                  if (_selectedShapeOf(sheet) case final selected?)
                    ..._buildSymbolHandles(selected, canvasSize, zoom, pan),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// The sheet this canvas draws: the **sequence** focus (`focusShotId: null`, M5 offers no other),
  /// filtered to [OcptFloorPlanCanvas.hiddenLayers].
  OcptFloorPlanSheet _sheetOf(OcptFloorPlanCase floorPlanCase) {
    final full = OcptFloorPlanSheet.of(
      floorPlanCase: floorPlanCase,
      focusShotId: null,
      shotRankByShotId: widget.shotRankByShotId,
    );
    return OcptFloorPlanSheet(
      caseId: full.caseId,
      caseName: full.caseName,
      underlay: full.underlay,
      symbols: [
        for (final symbol in full.symbols)
          if (!widget.hiddenLayers.contains(symbol.layer)) symbol,
      ],
      arrows: full.arrows,
    );
  }

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

  /// A click on empty canvas (no symbol, no underlay handle caught it first): places a new set
  /// element under the `setElement` tool, or clears the selection under `select`.
  void _handleBackgroundTap(Offset localPosition, Size canvasSize, double zoom, Offset pan) {
    if (widget.activeTool == OcptFloorPlanTool.setElement) {
      final onSymbolPlaced = widget.onSymbolPlaced;
      if (onSymbolPlaced == null) {
        return;
      }
      final metres = ocptFloorPlanMetrePointOf(
        screenPoint: localPosition,
        canvasSize: canvasSize,
        zoom: zoom,
        pan: pan,
      );
      onSymbolPlaced(widget.activeLayer, metres.dx, metres.dy);
      return;
    }

    widget.onSymbolSelected(null);
  }

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

    return Positioned(
      left: centre.dx - widthPx / 2,
      top: centre.dy - heightPx / 2,
      width: widthPx,
      height: heightPx,
      child: Transform.rotate(
        angle: rotationDeg * math.pi / 180,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSymbolSelected(symbol.symbolId),
          onPanStart: widget.isReadOnly || widget.onSymbolMoved == null
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
          onPanUpdate: widget.isReadOnly || widget.onSymbolMoved == null
              ? null
              : (details) => _updateSymbolDrag(symbol.symbolId, details.delta, zoom),
          onPanEnd: widget.isReadOnly || widget.onSymbolMoved == null
              ? null
              : (_) => _commitSymbolDrag(symbol),
        ),
      ),
    );
  }

  /// The selected symbol's own resize + rotate handles, or an empty list while withheld under a
  /// read-only preview.
  List<Widget> _buildSymbolHandles(
    OcptFloorPlanSymbolShape symbol,
    Size canvasSize,
    double zoom,
    Offset pan,
  ) {
    if (widget.isReadOnly) {
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
