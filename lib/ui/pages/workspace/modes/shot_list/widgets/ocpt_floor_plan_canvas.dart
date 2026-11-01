// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow_shape.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_palette_drag_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_symbol_drag_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_underlay_drag_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_arrow_handles.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_drag_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_gestures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_scope_bubble.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_handles.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_hit_overlay.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_label_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_restore_handle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_underlay_move_handle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_underlay_resize_handle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_underlay_visual.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_viewport_controller.dart';

/// The delay after the last scroll-wheel tick before its own settled zoom reaches
/// [OcptFloorPlanCanvas.onZoomSettled] — see `OcptFloorPlanViewportController`'s own doc comment
/// for why a wheel gesture, unlike the tool bar's zoom buttons, needs a debounce of its own.
const Duration _wheelZoomSettleDelay = Duration(milliseconds: 300);

/// How much one scroll-wheel notch multiplies the zoom by.
const double _wheelZoomStep = 0.08;

/// The floor plans canvas: a `CustomPaint` of the `OcptFloorPlanSheet` the current focus builds
/// for [floorPlanSet], under a `GestureDetector`.
///
/// Geometry is drawn from **metres → logical pixels at [OcptFloorPlanCanvas.viewportController]'s
/// current zoom**, through `ocpt_floor_plan_geometry.dart` — never a stored pixel value.
///
/// **The focus** is [focusShotId] — **always a real shot in practice** (the bloc guarantees a
/// current shot the moment the sequence holds one), never null except defensively (no shot placed
/// yet): it draws every sequence layer plus [focusShotId]'s own shot layers, plus
/// [previousShotId]'s/[nextShotId]'s own shot layers as onion-skin ghosts, gated by
/// [isOnionSkinPreviousShown]/[isOnionSkinNextShown]. [hiddenCameraSymbolIds] hides a camera
/// symbol regardless of which of those two groups it belongs to — the focused shot's own or an
/// onion-skin ghost's. **The scope
/// invariant a tool respects**: [OcptFloorPlanTool.setElement] places on the tray's active
/// *sequence* layer (never scoped to a shot); [OcptFloorPlanTool.camera]/
/// [OcptFloorPlanTool.character]/[OcptFloorPlanTool.light] each place their own fixed shot layer on
/// [focusShotId] and do nothing at all while it is null, defensive only. A symbol is only ever
/// **editable** (selectable for drag, resizable, rotatable, deletable) when it belongs to the scope
/// the current focus makes live — a sequence layer, or [focusShotId]'s own shot layers — and never
/// when it is a ghost: the frozen scope is drawn, never hidden, but locked.
///
/// **Arrows**: [OcptFloorPlanTool.arrow] takes two clicks on two (non-ghost) symbols —
/// [onArrowSymbolTapped] reports each tap, the bloc holds the pending anchor and completes the
/// arrow on the second — cancelled by `Escape` (the view's own keyboard shortcut) or a click on
/// empty canvas ([onArrowAnchorCancelled]). **Labels**: [OcptFloorPlanTool.label] shows an inline
/// text field over the selected symbol, its value [symbolLabelValueOf], writes through
/// [onSymbolLabelChanged]. **Double-clicking a ghost** calls [onGhostShotFocusRequested] with its
/// own shot's id, focusing it.
///
/// Placing a set element: pick the `setElement` tool (one of the palette's own four typed entries —
/// wall/door/furniture/freeform — arms both [activeTool] and [activeSetElementShape]), click →
/// [onSymbolPlaced] onto the set layer, carrying that shape. Dragging a symbol moves it (one
/// [onSymbolMoved] on drag end, in metres); dragging its own resize handle resizes it (one
/// [onSymbolResized] on drag end); dragging its own **aim handle** points it (one [onSymbolRotated]
/// on drag end, the pointer's own bearing around the symbol's centre computed in **canvas space**
/// through `RenderBox.globalToLocal` — never the handle's own local position, which reads it
/// relative to the handle's tiny hit box instead — holding `Shift` snaps it to
/// [ocptFloorPlanRotateSnapStepDeg]° steps). A selected camera also draws two edge handles on its own
/// field-of-view wedge; dragging either narrows or widens it (one [onSymbolFovChanged] on drag end,
/// in degrees). `Ctrl+D` on the selected symbol, or an `Alt`-drag of any symbol (the drag preview
/// follows the pointer exactly like a plain move, but on release the *source* symbol is left
/// untouched and a new, independent copy is placed at the release point instead —
/// [onSymbolDuplicateDragged]), duplicates it: never a link.
///
/// Every write is **withheld** under [isReadOnly] (a null `onSymbolPlaced`/move/resize/rotate/fov/
/// delete/arrow/label/duplicate closes the whole gesture, exactly as the board's null callbacks
/// do); zoom, pan, selecting, the metrics overlay and the tray's own visibility toggles stay
/// available, since they only read.
///
/// **Arrow selection**: a click under `select` that lands within `ocptFloorPlanArrowHitTolerancePx` of a
/// (non-ghost) arrow's own shaft (straight or curved, `ocptFloorPlanArrowHitAt`) selects it
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

  /// The selected sequence's own scene id — `OcptFloorPlanSheet.of`'s own `focusSceneId`, so a
  /// scene-scope symbol/override only ever draws under the sequence it belongs to.
  final String focusSceneId;

  /// The id of the currently focused shot — see the class doc comment. Null only defensively (no
  /// shot placed yet); `OcptShotListState.isFloorPlanShotFocusActive`'s own reading of
  /// `selectedShotId`.
  final String? focusShotId;

  /// The shot immediately before [focusShotId] in the sequence, or null while there is none — the
  /// onion skin's own previous-shot ghost.
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
  /// applied to every camera shape this canvas draws, whether it is [focusShotId]'s own or an
  /// onion-skin ghost's.
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

  /// The scope a `setElement` tool click-to-arm placement lands at — the `Set` group's own
  /// four entries arm [OcptFloorPlanScope.set], the `Sequence` group's own furniture/freeform pair
  /// arm [OcptFloorPlanScope.scene]. See [activeSetElementShape]'s own doc comment for why a drag
  /// reads its own payload instead (`OcptFloorPlanPaletteDragPayload.sceneScope`).
  final OcptFloorPlanScope activeSetElementScope;

  /// A `prop` tool click-to-arm placement's own label — which breakdown-prop chip, or the `Other…`
  /// chip's own typed-in text, was armed last. See [activeSetElementShape]'s own doc comment for
  /// why a drag reads its own payload instead (`OcptFloorPlanPaletteDragPayload.label`).
  final String activeLabel;

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

  /// Called with the layer, the shot id (null on a sequence/set-scope symbol, [focusShotId] on a
  /// shot layer), the scene id (null on a set-scope or shot-scope symbol, [focusSceneId] on a
  /// scene-scope one — a `set`-layer placement at [OcptFloorPlanScope.scene], or any `props`
  /// placement) and the clicked point (metres), or null while withheld. `setElementShape`
  /// carries the décor primitive when the layer is [OcptFloorPlanLayer.set] — null otherwise.
  /// `label` carries a `prop` placement's own armed label — `""` otherwise.
  final void Function(
    OcptFloorPlanLayer layer,
    String? shotId,
    String? sceneId,
    double xM,
    double yM, {
    OcptFloorPlanSetElementShape? setElementShape,
    String label,
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

  /// Called with the selected override's own id (a visible override's own shape, or a hidden
  /// override's own ghost — both name the override, never the original) when its own `Restore`
  /// handle is tapped, or null while withheld. Reversible (tombstones the override, the original
  /// reappears) — never asks, unlike [onSymbolDeleteRequested].
  final ValueChanged<String>? onSymbolRestoreRequested;

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

  /// A set-scope move, rotate or resize awaiting the scope bubble's own answer, or null while
  /// nothing is pending — the symbol it names draws (and
  /// hit-tests) at this geometry instead of its own stored one, exactly like a drag still in
  /// progress, and is locked against further editing until it resolves. Merged with the drag
  /// currently in progress (if any) the same way: at most one of the two is ever live for a given
  /// symbol.
  final OcptFloorPlanSymbolLiveOverride? pendingScopeLiveOverride;

  /// The scope bubble's own broader-scope label — `Every sequence (n)` at
  /// [OcptFloorPlanOverrideLevel.sequence], `The whole sequence` at
  /// [OcptFloorPlanOverrideLevel.shot] — shown while [pendingScopeLiveOverride] is set; null
  /// only when withheld altogether (defensive: the mode never leaves one field null without the
  /// other two). The mode already resolves which level's wording this is — the bubble itself reads
  /// three plain strings, never a level of its own.
  final String? scopeBubbleEveryLabel;

  /// The scope bubble's own narrower-scope label — `Only sequence n` or `Only shot n`. See
  /// [scopeBubbleEveryLabel].
  final String? scopeBubbleOnlyLabel;

  /// The scope bubble's own `Cancel` label. See [scopeBubbleEveryLabel].
  final String? scopeBubbleCancelLabel;

  /// Called when the scope bubble's own broader-scope button is tapped.
  final VoidCallback? onScopeBubbleEveryRequested;

  /// Called when the scope bubble's own narrower-scope button is tapped.
  final VoidCallback? onScopeBubbleOnlyRequested;

  /// Called when the scope bubble's own `Cancel` button is tapped, or a click lands on empty
  /// canvas while it is showing — dismissing it any other way means the same thing.
  final VoidCallback? onScopeBubbleCancelRequested;

  /// Class constructor
  const OcptFloorPlanCanvas({
    super.key,
    required this.floorPlanSet,
    required this.shotRankByShotId,
    required this.focusSceneId,
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
    required this.activeTool,
    required this.activeLayer,
    required this.activeSetElementShape,
    required this.activeSetElementScope,
    required this.activeLabel,
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
    required this.onSymbolRestoreRequested,
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
    this.pendingScopeLiveOverride,
    this.scopeBubbleEveryLabel,
    this.scopeBubbleOnlyLabel,
    this.scopeBubbleCancelLabel,
    this.onScopeBubbleEveryRequested,
    this.onScopeBubbleOnlyRequested,
    this.onScopeBubbleCancelRequested,
  });

  /// Create the [_OcptFloorPlanCanvasState] holding the state of the floor plan canvas.
  @override
  State<OcptFloorPlanCanvas> createState() => _OcptFloorPlanCanvasState();
}

/// State of [OcptFloorPlanCanvas]: owns the drag controller and the wheel-zoom settle timer.
class _OcptFloorPlanCanvasState extends State<OcptFloorPlanCanvas> {
  /// The live state of the symbol, underlay and arrow drags in progress.
  final OcptFloorPlanCanvasDragController _drag = OcptFloorPlanCanvasDragController();

  /// The debounce timer settling a scroll-wheel zoom into [OcptFloorPlanCanvas.onZoomSettled].
  Timer? _wheelZoomSettleTimer;

  /// The key of the `Stack` filling this canvas's own local coordinate space (the same origin
  /// [ocptFloorPlanScreenPointOf]/[ocptFloorPlanMetrePointOf] already agree on) — what
  /// [_resolveLocalPosition] converts a gesture's own **global** position through, since a handle's
  /// own `details.localPosition` is relative to that tiny handle's own hit box, not to the canvas.
  final GlobalKey _canvasStackKey = GlobalKey();

  /// Register [_onDragChanged] as a listener of [_drag].
  @override
  void initState() {
    super.initState();
    _drag.addListener(_onDragChanged);
  }

  /// Build the floor plan canvas as a [LayoutBuilder].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final floorPlanSet = widget.floorPlanSet;

    // Defensive only: the mode never builds `OcptFloorPlanView`/this canvas at all while the
    // selected sequence has no linked set — `OcptFloorPlanSetGallery` fills the centre instead.
    // A blank canvas is a safer fallback here than a stale
    // hint string this branch has no real caller left to word for.
    if (floorPlanSet == null) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = constraints.biggest;

        return ListenableBuilder(
          listenable: widget.viewportController,
          builder: (context, _) {
            final zoom = widget.viewportController.zoom;
            final pan = widget.viewportController.pan;
            final sheet = ocptFloorPlanVisibleSheetOf(
              floorPlanSet: floorPlanSet,
              focusSceneId: widget.focusSceneId,
              focusShotId: widget.focusShotId,
              shotRankByShotId: widget.shotRankByShotId,
              previousShotId: widget.previousShotId,
              nextShotId: widget.nextShotId,
              isOnionSkinPreviousShown: widget.isOnionSkinPreviousShown,
              isOnionSkinNextShown: widget.isOnionSkinNextShown,
              showFieldOfView: widget.viewportController.showFieldOfView,
              hiddenLayers: widget.hiddenLayers,
              hiddenCameraSymbolIds: widget.hiddenCameraSymbolIds,
            );
            final barLengthM = ocptFloorPlanScaleBarLengthM(zoom: zoom);

            final selectedShape = ocptFloorPlanSymbolOf(sheet, widget.selectedSymbolId);
            final selectedArrow = ocptFloorPlanArrowOf(sheet, widget.selectedArrowId);
            final pendingScopeLiveOverride = widget.pendingScopeLiveOverride;

            return ClipRect(
              child: Stack(
                key: _canvasStackKey,
                children: [
                  if (!widget.isUnderlayHidden && floorPlanSet.underlayAssetId != null)
                    OcptFloorPlanUnderlayVisual(
                      floorPlanSet: floorPlanSet,
                      rect: ocptFloorPlanUnderlayScreenRect(
                        floorPlanSet: floorPlanSet,
                        frame: _drag.liveUnderlayFrame,
                        canvasSize: canvasSize,
                        zoom: zoom,
                        pan: pan,
                      ),
                    ),
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
                          // Its own layer: the plan repaints on every pan, zoom and drag frame, and the
                          // widgets stacked over it do not repaint with it.
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: canvasSize,
                              painter: OcptFloorPlanCanvasPainter(
                                sheet: sheet,
                                zoom: zoom,
                                pan: pan,
                                selectedSymbolId: widget.selectedSymbolId,
                                arrowAnchorSymbolId: widget.pendingArrowAnchorSymbolId,
                                liveOverride: _drag.liveOverride ?? pendingScopeLiveOverride,
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
                                metricLines: ocptFloorPlanMetricLinesOf(
                                  sheet: sheet,
                                  selected: selectedShape,
                                  isMetricsShown: widget.isMetricsShown,
                                  tr: tr,
                                ),
                                metricLineColor: theme.colorScheme.tertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The underlay's own invisible move + resize handles, drawn after the symbol
                  // overlays are laid out but positioned first in this return list so a click
                  // landing on a symbol drawn over the underlay hits that symbol first.
                  if (!widget.isUnderlayHidden &&
                      floorPlanSet.underlayAssetId != null &&
                      !widget.isReadOnly &&
                      widget.onUnderlayTransformChanged != null) ...[
                    OcptFloorPlanUnderlayMoveHandle(
                      floorPlanSet: floorPlanSet,
                      rect: ocptFloorPlanUnderlayScreenRect(
                        floorPlanSet: floorPlanSet,
                        frame: _drag.liveUnderlayFrame,
                        canvasSize: canvasSize,
                        zoom: zoom,
                        pan: pan,
                      ),
                      onDragStarted: () =>
                          _drag.beginUnderlayDrag(OcptFloorPlanUnderlayDragKind.move, floorPlanSet),
                      onDragUpdated: (delta) => _drag.updateUnderlayDrag(
                        delta,
                        zoom,
                        floorPlanSet.underlayRotationDeg ?? 0,
                      ),
                      onDragEnded: _commitUnderlayDrag,
                    ),
                    OcptFloorPlanUnderlayResizeHandle(
                      rect: ocptFloorPlanUnderlayScreenRect(
                        floorPlanSet: floorPlanSet,
                        frame: _drag.liveUnderlayFrame,
                        canvasSize: canvasSize,
                        zoom: zoom,
                        pan: pan,
                      ),
                      onDragStarted: () => _drag.beginUnderlayDrag(
                        OcptFloorPlanUnderlayDragKind.resize,
                        floorPlanSet,
                      ),
                      onDragUpdated: (delta) => _drag.updateUnderlayDrag(
                        delta,
                        zoom,
                        floorPlanSet.underlayRotationDeg ?? 0,
                      ),
                      onDragEnded: _commitUnderlayDrag,
                    ),
                  ],
                  for (final symbol in sheet.symbols)
                    if (!symbol.isOverriddenOriginalGhost)
                      OcptFloorPlanSymbolHitOverlay(
                        symbol: symbol,
                        canvasSize: canvasSize,
                        zoom: zoom,
                        pan: pan,
                        liveOverride: _drag.liveOverride ?? pendingScopeLiveOverride,
                        canDrag:
                            !widget.isReadOnly &&
                            widget.onSymbolMoved != null &&
                            _isSymbolEditable(symbol),
                        onTap: () => _handleSymbolTap(symbol),
                        onGhostShotFocusRequested: widget.onGhostShotFocusRequested,
                        onDragStarted: () => _beginSymbolMove(symbol),
                        onDragUpdated: (delta) =>
                            _drag.updateSymbolDrag(symbol.symbolId, delta, zoom),
                        onDragEnded: () => _commitSymbolDrag(symbol),
                      ),
                  if (selectedShape != null &&
                      !widget.isReadOnly &&
                      _isSymbolEditable(selectedShape))
                    OcptFloorPlanSymbolHandles(
                      symbol: selectedShape,
                      canvasSize: canvasSize,
                      zoom: zoom,
                      pan: pan,
                      drag: _drag,
                      resolveLocalPosition: _resolveLocalPosition,
                      isSnapping: () => HardwareKeyboard.instance.isShiftPressed,
                      canResize:
                          widget.onSymbolResized != null &&
                          selectedShape.layer != OcptFloorPlanLayer.cameras,
                      canRotate: widget.onSymbolRotated != null,
                      canChangeFov:
                          widget.onSymbolFovChanged != null &&
                          selectedShape.cameraFovWedgeDeg != null,
                      canChangeFovReach:
                          widget.onSymbolFovReachChanged != null &&
                          selectedShape.cameraFovWedgeDeg != null,
                      onDeleteRequested: widget.onSymbolDeleteRequested == null
                          ? null
                          : () => widget.onSymbolDeleteRequested!(selectedShape.symbolId),
                      onDragEnded: () => _commitSymbolDrag(selectedShape),
                    ),
                  if (selectedShape != null &&
                      (selectedShape.isOverride || selectedShape.isHiddenOverrideGhost) &&
                      widget.onSymbolRestoreRequested != null)
                    OcptFloorPlanSymbolRestoreHandle(
                      symbol: selectedShape,
                      canvasSize: canvasSize,
                      zoom: zoom,
                      pan: pan,
                      onRestoreRequested: () =>
                          widget.onSymbolRestoreRequested!(selectedShape.symbolId),
                    ),
                  if (selectedArrow != null &&
                      !widget.isReadOnly &&
                      !selectedArrow.isGhost &&
                      widget.onArrowCurveChanged != null)
                    OcptFloorPlanArrowHandles(
                      arrow: selectedArrow,
                      canvasSize: canvasSize,
                      zoom: zoom,
                      pan: pan,
                      drag: _drag,
                      onDragEnded: () => _commitArrowCurveDrag(selectedArrow),
                      onStraightenRequested: () =>
                          widget.onArrowCurveChanged!(selectedArrow.arrowId, null, null),
                    ),
                  if (widget.activeTool == OcptFloorPlanTool.label &&
                      selectedShape != null &&
                      !selectedShape.isGhost)
                    OcptFloorPlanSymbolLabelEditor(
                      symbol: selectedShape,
                      canvasSize: canvasSize,
                      zoom: zoom,
                      pan: pan,
                      value: widget.symbolLabelValueOf(selectedShape.symbolId),
                      onChanged: widget.isReadOnly || widget.onSymbolLabelChanged == null
                          ? null
                          : (value) => widget.onSymbolLabelChanged!(selectedShape.symbolId, value),
                    ),
                  if (pendingScopeLiveOverride != null)
                    OcptFloorPlanScopeBubble(
                      liveOverride: pendingScopeLiveOverride,
                      canvasSize: canvasSize,
                      zoom: zoom,
                      pan: pan,
                      everyLabel: widget.scopeBubbleEveryLabel ?? "",
                      onlyLabel: widget.scopeBubbleOnlyLabel ?? "",
                      cancelLabel: widget.scopeBubbleCancelLabel ?? "",
                      onEveryRequested: widget.onScopeBubbleEveryRequested,
                      onOnlyRequested: widget.onScopeBubbleOnlyRequested,
                      onCancelRequested: widget.onScopeBubbleCancelRequested,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Redraws the canvas whenever a drag moves its live geometry.
  void _onDragChanged() => setState(() {});

  /// [globalPosition] converted into this canvas's own local coordinate space, through
  /// [_canvasStackKey]'s `RenderBox` — the fix for a handle drag's own `onPanUpdate`, whose
  /// `details.localPosition` is relative to the handle's own tiny hit box rather than to the
  /// canvas. Falls back to [globalPosition] unchanged on the one frame the render object isn't
  /// resolvable yet (defensive only).
  Offset _resolveLocalPosition(Offset globalPosition) {
    final renderObject = _canvasStackKey.currentContext?.findRenderObject();
    return renderObject is RenderBox ? renderObject.globalToLocal(globalPosition) : globalPosition;
  }

  /// Whether [symbol] may be dragged, resized, rotated, given a field of view or deleted: never a
  /// ghost — the onion-skin kind ([OcptFloorPlanSymbolShape.isGhost]) or an override-marking one
  /// ([OcptFloorPlanSymbolShape.isOverriddenOriginalGhost]/[OcptFloorPlanSymbolShape
  /// .isHiddenOverrideGhost]) — since none of the three ever represents this sequence's own
  /// live geometry to drag; **the set and scene scopes are always editable** — a scene-scope
  /// symbol this sheet draws already belongs to the sequence
  /// being shown); a shot-scope symbol is editable only while it belongs to
  /// [OcptFloorPlanCanvas.focusShotId], the one shot everything "live" lands on. A ghosted
  /// neighbour's own placements stay selectable (so their own Placements/metrics still read), just
  /// locked — and so does a hidden override's own ghost, so the inspector can still offer
  /// `Restore` on it (the canvas's own build is what excludes
  /// [OcptFloorPlanSymbolShape.isOverriddenOriginalGhost] from selection entirely).
  bool _isSymbolEditable(OcptFloorPlanSymbolShape symbol) {
    if (symbol.isGhost || symbol.isOverriddenOriginalGhost || symbol.isHiddenOverrideGhost) {
      return false;
    }
    if (symbol.symbolId == widget.pendingScopeLiveOverride?.symbolId) {
      return false; // Locked while the scope bubble is showing.
    }
    return symbol.shotId == null || symbol.shotId == widget.focusShotId;
  }

  /// A palette entry dropped onto this canvas (drag-from-palette placement): places a symbol of
  /// `details.data`'s own tool exactly at the
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
    if (tool != OcptFloorPlanTool.setElement && tool != OcptFloorPlanTool.prop) {
      final fixedLayer = ocptFloorPlanFixedLayerOf(tool);
      if (fixedLayer == null) {
        return;
      }
    }

    final layer = tool == OcptFloorPlanTool.setElement
        ? OcptFloorPlanLayer.set
        : (ocptFloorPlanFixedLayerOf(tool) ?? OcptFloorPlanLayer.props);
    final isShotScoped =
        layer == OcptFloorPlanLayer.cameras ||
        layer == OcptFloorPlanLayer.characters ||
        layer == OcptFloorPlanLayer.lights;
    final shotId = isShotScoped ? widget.focusShotId : null;
    if (isShotScoped && shotId == null) {
      return;
    }
    final sceneId = _sceneIdFor(layer, details.data.sceneScope);

    final localPosition = _resolveLocalPosition(details.offset);
    final metres = ocptFloorPlanMetrePointOf(
      screenPoint: localPosition,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    onSymbolPlaced(
      layer,
      shotId,
      sceneId,
      metres.dx,
      metres.dy,
      setElementShape: tool == OcptFloorPlanTool.setElement ? details.data.setElementShape : null,
      label: tool == OcptFloorPlanTool.prop ? (details.data.label ?? "") : "",
    );
  }

  /// The scene id a symbol placed on [layer] carries — [OcptFloorPlanCanvas.focusSceneId] for a
  /// `props` placement (always scene-scoped) or a `set`-layer placement whose own [sceneScope]
  /// is [OcptFloorPlanScope.scene] (the palette's `Sequence` group), null otherwise (the `Set`
  /// group, or any shot-scoped layer).
  String? _sceneIdFor(OcptFloorPlanLayer layer, OcptFloorPlanScope? sceneScope) {
    if (layer == OcptFloorPlanLayer.props) {
      return widget.focusSceneId;
    }
    if (layer == OcptFloorPlanLayer.set && sceneScope == OcptFloorPlanScope.scene) {
      return widget.focusSceneId;
    }
    return null;
  }

  /// A click on empty canvas (no symbol, no underlay handle caught it first): places a new symbol
  /// under a placing tool (`setElement` at [OcptFloorPlanCanvas.activeSetElementScope]'s own scope,
  /// `prop` on [OcptFloorPlanCanvas.focusSceneId] with [OcptFloorPlanCanvas.activeLabel], or
  /// `camera`/`character`/`light` on [OcptFloorPlanCanvas.focusShotId]'s own shot layer — a no-op
  /// while no shot is focused, defensive only); under `select`, selects the arrow it lands near
  /// ([ocptFloorPlanArrowHitAt]) instead of clearing, when one is close enough; cancels the arrow tool's own
  /// pending anchor under `arrow`; clears both selections otherwise (`label`, an arrow tool with
  /// nothing pending, or `select` finding no arrow close enough).
  void _handleBackgroundTap(
    Offset localPosition,
    Size canvasSize,
    double zoom,
    Offset pan,
    OcptFloorPlanSheet sheet,
  ) {
    if (widget.pendingScopeLiveOverride != null) {
      // Dismissing the scope bubble by clicking elsewhere means Cancel.
      widget.onScopeBubbleCancelRequested?.call();
      return;
    }

    final tool = widget.activeTool;
    if (tool == OcptFloorPlanTool.setElement || tool == OcptFloorPlanTool.prop) {
      final onSymbolPlaced = widget.onSymbolPlaced;
      if (onSymbolPlaced == null) {
        return;
      }
      final layer = tool == OcptFloorPlanTool.setElement
          ? OcptFloorPlanLayer.set
          : OcptFloorPlanLayer.props;
      final sceneId = _sceneIdFor(layer, widget.activeSetElementScope);
      final metres = ocptFloorPlanMetrePointOf(
        screenPoint: localPosition,
        canvasSize: canvasSize,
        zoom: zoom,
        pan: pan,
      );
      onSymbolPlaced(
        layer,
        null,
        sceneId,
        metres.dx,
        metres.dy,
        setElementShape: tool == OcptFloorPlanTool.setElement ? widget.activeSetElementShape : null,
        label: tool == OcptFloorPlanTool.prop ? widget.activeLabel : "",
      );
      return;
    }

    final shotLayer = ocptFloorPlanFixedLayerOf(tool);
    if (shotLayer != null) {
      final onSymbolPlaced = widget.onSymbolPlaced;
      final shotId = widget.focusShotId;
      if (onSymbolPlaced == null || shotId == null) {
        return;
      }
      final metres = ocptFloorPlanMetrePointOf(
        screenPoint: localPosition,
        canvasSize: canvasSize,
        zoom: zoom,
        pan: pan,
      );
      onSymbolPlaced(shotLayer, shotId, null, metres.dx, metres.dy);
      return;
    }

    if (widget.activeTool == OcptFloorPlanTool.select) {
      final metres = ocptFloorPlanMetrePointOf(
        screenPoint: localPosition,
        canvasSize: canvasSize,
        zoom: zoom,
        pan: pan,
      );
      final arrowId = ocptFloorPlanArrowHitAt(sheet, metres.dx, metres.dy, zoom);
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

  /// A tap on [symbol]: reports it to [OcptFloorPlanCanvas.onArrowSymbolTapped] under the `arrow`
  /// tool (ignored on a ghost, see [OcptFloorPlanSymbolHitOverlay]'s own doc comment), selects it
  /// otherwise (clearing any arrow selection, the two being mutually exclusive).
  void _handleSymbolTap(OcptFloorPlanSymbolShape symbol) {
    if (widget.activeTool == OcptFloorPlanTool.arrow) {
      if (!symbol.isGhost) {
        widget.onArrowSymbolTapped?.call(symbol.symbolId);
      }
      return;
    }

    widget.onArrowSelected(null);
    widget.onSymbolSelected(symbol.symbolId);
  }

  /// Starts a move drag on [symbol]: selects it (clearing any arrow selection, the two being
  /// mutually exclusive) and arms the live preview at its own stored geometry. Starting the drag
  /// with `Alt` held (and [OcptFloorPlanCanvas.onSymbolDuplicateDragged] not withheld) makes it a
  /// duplicate: the live preview still tracks the pointer exactly like a plain move, but
  /// [_commitSymbolDrag] reports it as a duplicate instead, leaving this very symbol at its own
  /// original position.
  void _beginSymbolMove(OcptFloorPlanSymbolShape symbol) {
    widget.onArrowSelected(null);
    widget.onSymbolSelected(symbol.symbolId);
    _drag.beginSymbolMove(
      symbol,
      isDuplicating:
          HardwareKeyboard.instance.isAltPressed && widget.onSymbolDuplicateDragged != null,
    );
  }

  /// Reports the dragged symbol's own settled geometry (move, resize, aim or field of view,
  /// whichever gesture it was) and clears the live drag state. A move drag that was an `Alt`-drag
  /// duplicate reports through [OcptFloorPlanCanvas.onSymbolDuplicateDragged] instead of
  /// [OcptFloorPlanCanvas.onSymbolMoved]: [symbol] itself is left untouched at its own original
  /// position, a new, independent copy placed at the drag's own settled point instead.
  void _commitSymbolDrag(OcptFloorPlanSymbolShape symbol) {
    final settled = _drag.endSymbolDrag();
    if (settled == null) {
      return;
    }
    final override = settled.override;

    switch (settled.kind) {
      case OcptFloorPlanSymbolDragKind.move:
        if (settled.wasDuplicating) {
          widget.onSymbolDuplicateDragged?.call(symbol.symbolId, override.xM, override.yM);
        } else {
          widget.onSymbolMoved?.call(symbol.symbolId, override.xM, override.yM);
        }
      case OcptFloorPlanSymbolDragKind.resize:
        widget.onSymbolResized?.call(symbol.symbolId, override.widthM, override.heightM);
      case OcptFloorPlanSymbolDragKind.rotate:
        widget.onSymbolRotated?.call(symbol.symbolId, override.rotationDeg);
      case OcptFloorPlanSymbolDragKind.fov:
        final fovDeg = override.fovDeg;
        if (fovDeg != null) {
          widget.onSymbolFovChanged?.call(symbol.symbolId, fovDeg);
        }
      case OcptFloorPlanSymbolDragKind.fovReach:
        final fovReachM = override.fovReachM;
        if (fovReachM != null) {
          widget.onSymbolFovReachChanged?.call(symbol.symbolId, fovReachM);
        }
    }
  }

  /// Reports the underlay's own settled frame and clears the live drag state.
  void _commitUnderlayDrag() {
    final frame = _drag.endUnderlayDrag();
    if (frame == null) {
      return;
    }
    widget.onUnderlayTransformChanged?.call(frame.xM, frame.yM, frame.widthM, frame.heightM);
  }

  /// Reports the dragged arrow's own settled control point and clears the live drag state — unless
  /// it landed close enough to the straight from-to line ([ocptFloorPlanArrowStraightenToleranceM]),
  /// in which case it straightens the arrow back out instead.
  void _commitArrowCurveDrag(OcptFloorPlanArrowShape arrow) {
    final live = _drag.endArrowCurveDrag();

    final onArrowCurveChanged = widget.onArrowCurveChanged;
    if (live == null || onArrowCurveChanged == null) {
      return;
    }

    final distanceToStraightM = ocptFloorPlanDistanceToSegmentM(
      live.xM,
      live.yM,
      arrow.fromXM,
      arrow.fromYM,
      arrow.toXM,
      arrow.toYM,
    );
    if (distanceToStraightM <= ocptFloorPlanArrowStraightenToleranceM) {
      onArrowCurveChanged(arrow.arrowId, null, null);
      return;
    }

    onArrowCurveChanged(arrow.arrowId, live.xM, live.yM);
  }

  /// Cancel [_wheelZoomSettleTimer], detach [_onDragChanged] from [_drag], then dispose [_drag].
  @override
  void dispose() {
    _wheelZoomSettleTimer?.cancel();
    _drag
      ..removeListener(_onDragChanged)
      ..dispose();
    super.dispose();
  }
}
