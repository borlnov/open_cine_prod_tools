// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_focus_strip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_palette.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_tool_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_viewport_controller.dart';

/// The floor plans view's own frame, filling the centre while `OcptShotListCentreView.floorPlans`
/// is shown (`docs/plans/storyboard.md`, §4.3): the tool bar across the top, the layer tray down
/// the left of the canvas, the canvas itself, and the focus strip along the bottom.
///
/// **A `StatefulWidget` (the documented RFL1 exception)**, the very reason `_ShotListViewState`
/// (`shot_list_mode.dart`) is one: this view owns an `OcptFloorPlanViewportController`, whose zoom
/// and pan are mutated per frame during a gesture with no bloc emission — see that controller's own
/// doc comment. It is created once, seeded from [initialZoom] (`OcptShotListState.floorPlanZoom`,
/// the last value the bloc saw settled), and disposed when this view unmounts (switching away from
/// the floor plans centre view, or leaving the mode): a set tab switch keeps it, since only the
/// centre view switch remounts this widget.
///
/// **`←`/`→` walk the sequence's shots** ([onShotWalkRequested]) and `Escape` cancels the arrow
/// tool's own pending anchor ([onArrowAnchorCancelled]): both live on a `Focus` wrapping the whole
/// view, auto-focused once on mount, so either shortcut works from anywhere in the view — the
/// strip, the canvas, the tray — except while a descendant text field (the inline label editor)
/// has its own focus and consumes the key first.
class OcptFloorPlanView extends StatefulWidget {
  /// The selected sequence's own sets, for the sheet the canvas builds.
  final OcptFloorPlanSet? floorPlanSet;

  /// The selected sequence's own shots, in order — the focus strip's own chips.
  final List<OcptShot> shots;

  /// Every shot of the selected sequence's own 1-based display rank, keyed by shot id — see
  /// `OcptFloorPlanCanvas.shotRankByShotId`'s own doc comment.
  final Map<String, int> shotRankByShotId;

  /// The id of the currently focused shot, or null for the `Sequence` focus. Derived by the mode
  /// from `OcptShotListState.selectedShotId` — see `OcptShotListState.isFloorPlanShotFocusActive`.
  final String? focusShotId;

  /// The shot immediately before [focusShotId], or null while there is none.
  final String? previousShotId;

  /// The shot immediately after [focusShotId]. See [previousShotId].
  final String? nextShotId;

  /// Whether each of [shots] has a live camera symbol on [floorPlanSet], keyed by shot id — the
  /// focus strip's own filled/hollow dots.
  final Map<String, bool> hasCameraOnSetOf;

  /// Every live camera symbol of the sequence, for the tray's own expandable cameras row.
  final List<OcptFloorPlanTraySequenceCamera> sequenceCameras;

  /// The last zoom the bloc saw settled — what this view's own controller is created at.
  final double initialZoom;

  /// The sequence and shot layers currently hidden.
  final Set<OcptFloorPlanLayer> hiddenLayers;

  /// The ids of every camera symbol currently hidden.
  final Set<String> hiddenCameraSymbolIds;

  /// Whether the selected set's underlay is currently hidden.
  final bool isUnderlayHidden;

  /// Whether the onion skin's own previous-shot ghost is shown.
  final bool isOnionSkinPreviousShown;

  /// Whether the onion skin's own next-shot ghost is shown.
  final bool isOnionSkinNextShown;

  /// The onion skin's own ghost opacity, 0..1.
  final double onionSkinOpacity;

  /// Whether the metrics overlay is shown.
  final bool isMetricsShown;

  /// Whether the "All cameras" strip toggle is on: every shot's own camera of the selected set
  /// draws as a ghost alongside the focused shot's own (R3, `docs/plans/storyboard.md`, §9.4) — a
  /// display toggle only, never a state that gates a tool.
  final bool isAllCamerasShown;

  /// The id of the currently selected symbol, or null while none is.
  final String? selectedSymbolId;

  /// The id of the currently selected arrow, or null while none is.
  final String? selectedArrowId;

  /// The id of the symbol picked as the arrow tool's own pending first end, or null while none is.
  final String? pendingArrowAnchorSymbolId;

  /// The canvas's own currently active tool.
  final OcptFloorPlanTool activeTool;

  /// The sequence layer a placed set element lands on.
  final OcptFloorPlanLayer activeLayer;

  /// The décor primitive a `setElement` click-to-arm placement carries — see
  /// `OcptFloorPlanCanvas.activeSetElementShape`'s own doc comment.
  final OcptFloorPlanSetElementShape activeSetElementShape;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// A symbol's current label value, for the inline label editor.
  final String Function(String symbolId) symbolLabelValueOf;

  /// Called with the tool just picked.
  final ValueChanged<OcptFloorPlanTool> onToolSelected;

  /// Called with the layer whose eye was clicked.
  final ValueChanged<OcptFloorPlanLayer> onLayerVisibilityToggled;

  /// Called with the sequence layer just picked as the active one.
  final ValueChanged<OcptFloorPlanLayer> onActiveLayerChanged;

  /// Called with the décor primitive just picked among the palette's own four typed set-element
  /// entries — click-to-arms [activeSetElementShape] alongside [OcptFloorPlanTool.setElement]
  /// itself.
  final ValueChanged<OcptFloorPlanSetElementShape> onSetElementShapeSelected;

  /// Called with a camera symbol's id whose own eye was clicked.
  final ValueChanged<String> onCameraVisibilityToggled;

  /// Called with `true` to toggle the previous-shot ghost, `false` for the next-shot one.
  final ValueChanged<bool> onOnionSkinToggled;

  /// Called with the slider's own new opacity.
  final ValueChanged<double> onOnionSkinOpacityChanged;

  /// Called when the metrics toggle is clicked.
  final VoidCallback onMetricsToggled;

  /// Called when the "All cameras" strip toggle is clicked.
  final VoidCallback onAllCamerasToggled;

  /// Called when the underlay row's own eye is clicked.
  final VoidCallback onUnderlayVisibilityToggled;

  /// Called when the tool bar's own underlay action is clicked, or null while withheld.
  final VoidCallback? onUnderlayImportRequested;

  /// Called when the tray's own `Clear underlay` action is clicked, or null while withheld.
  final VoidCallback? onUnderlayClearRequested;

  /// Called with a symbol's id when it is selected, or null to clear the selection.
  final ValueChanged<String?> onSymbolSelected;

  /// Called with the layer, the shot id and the clicked point (metres), or null while withheld.
  /// See `OcptFloorPlanCanvas.onSymbolPlaced`'s own doc comment for `setElementShape`.
  final void Function(
    OcptFloorPlanLayer layer,
    String? shotId,
    double xM,
    double yM, {
    OcptFloorPlanSetElementShape? setElementShape,
  })?
  onSymbolPlaced;

  /// Called with a symbol's id and its new centre (metres), or null while withheld.
  final void Function(String symbolId, double xM, double yM)? onSymbolMoved;

  /// Called with a symbol's id and its new footprint (metres), or null while withheld.
  final void Function(String symbolId, double widthM, double heightM)? onSymbolResized;

  /// Called with a symbol's id and its new rotation (degrees), or null while withheld.
  final void Function(String symbolId, double rotationDeg)? onSymbolRotated;

  /// Called with a camera symbol's id and its new field-of-view wedge angle (degrees), or null
  /// while withheld.
  final void Function(String symbolId, double fovDeg)? onSymbolFovChanged;

  /// Called with a camera symbol's id and its new field-of-view wedge reach (metres), or null
  /// while withheld.
  final void Function(String symbolId, double fovReachM)? onSymbolFovReachChanged;

  /// Called with the selected symbol's id when its own delete action is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onSymbolDeleteRequested;

  /// Called with a symbol's id when it is tapped while the `arrow` tool is on, or null while
  /// withheld.
  final ValueChanged<String>? onArrowSymbolTapped;

  /// Called to cancel the arrow tool's own pending anchor, or null while withheld.
  final VoidCallback? onArrowAnchorCancelled;

  /// Called with an arrow's id when it is selected, or null to clear the selection. Never withheld.
  final ValueChanged<String?> onArrowSelected;

  /// Called with an arrow's id and its new bezier control point (metres), or both null to
  /// straighten it, or null while withheld.
  final void Function(String arrowId, double? ctrlXM, double? ctrlYM)? onArrowCurveChanged;

  /// Called with the selected symbol's id when `Ctrl+D` is pressed, or null while withheld. See
  /// [onSymbolDuplicateDragged] for the `Alt`-drag variant.
  final ValueChanged<String>? onSymbolDuplicateRequested;

  /// Called with a symbol's id and the release point (metres) of an `Alt`-drag on it, or null while
  /// withheld.
  final void Function(String symbolId, double xM, double yM)? onSymbolDuplicateDragged;

  /// Called with a ghost symbol's own shot id when it is double-clicked. Never withheld.
  final ValueChanged<String>? onGhostShotFocusRequested;

  /// Called with a symbol's id and its raw label text on every keystroke, or null while withheld.
  final void Function(String symbolId, String rawValue)? onSymbolLabelChanged;

  /// Called with the underlay's new frame (metres), or null while withheld.
  final void Function(double xM, double yM, double widthM, double heightM)?
  onUnderlayTransformChanged;

  /// Called with the zoom just settled on, whichever gesture settled it.
  final ValueChanged<double> onZoomSettled;

  /// Called with a shot's id when its own chip is clicked, or `←`/`→` walks to it.
  final ValueChanged<String> onShotChipSelected;

  /// Called with `-1`/`1` when `←`/`→` is pressed.
  final ValueChanged<int> onShotWalkRequested;

  /// Class constructor
  const OcptFloorPlanView({
    super.key,
    required this.floorPlanSet,
    required this.shots,
    required this.shotRankByShotId,
    required this.focusShotId,
    required this.previousShotId,
    required this.nextShotId,
    required this.hasCameraOnSetOf,
    required this.sequenceCameras,
    required this.initialZoom,
    required this.hiddenLayers,
    required this.hiddenCameraSymbolIds,
    required this.isUnderlayHidden,
    required this.isOnionSkinPreviousShown,
    required this.isOnionSkinNextShown,
    required this.onionSkinOpacity,
    required this.isMetricsShown,
    required this.isAllCamerasShown,
    required this.selectedSymbolId,
    required this.selectedArrowId,
    required this.pendingArrowAnchorSymbolId,
    required this.activeTool,
    required this.activeLayer,
    required this.activeSetElementShape,
    required this.isReadOnly,
    required this.symbolLabelValueOf,
    required this.onToolSelected,
    required this.onLayerVisibilityToggled,
    required this.onActiveLayerChanged,
    required this.onSetElementShapeSelected,
    required this.onCameraVisibilityToggled,
    required this.onOnionSkinToggled,
    required this.onOnionSkinOpacityChanged,
    required this.onMetricsToggled,
    required this.onAllCamerasToggled,
    required this.onUnderlayVisibilityToggled,
    required this.onUnderlayImportRequested,
    required this.onUnderlayClearRequested,
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
    required this.onShotChipSelected,
    required this.onShotWalkRequested,
  });

  @override
  State<OcptFloorPlanView> createState() => _OcptFloorPlanViewState();
}

class _OcptFloorPlanViewState extends State<OcptFloorPlanView> {
  /// The live zoom/pan source of truth for as long as this view stays mounted — see the class doc
  /// comment.
  late final OcptFloorPlanViewportController _viewportController = OcptFloorPlanViewportController(
    zoom: widget.initialZoom,
  );

  /// The keyboard focus node the whole view claims once, so `←`/`→` and `Escape` work from
  /// anywhere in it — see the class doc comment.
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: "OcptFloorPlanView");

  @override
  void didUpdateWidget(covariant OcptFloorPlanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A no-op the moment this very controller's own settled-zoom report is what changed
    // `initialZoom` (the bloc echoing back what it was just told), exactly as
    // `OcptWorkspaceDockLayoutController.syncFromPersisted` never bounces a drag's own committed
    // value.
    _viewportController.syncZoomFromPersisted(widget.initialZoom);
  }

  @override
  void dispose() {
    _viewportController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcptFloorPlanToolBar(
            activeTool: widget.activeTool,
            viewportController: _viewportController,
            isReadOnly: widget.isReadOnly,
            hasUnderlay: widget.floorPlanSet?.underlayAssetId != null,
            onToolSelected: widget.onToolSelected,
            onUnderlayImportRequested: widget.onUnderlayImportRequested,
            onZoomSettled: widget.onZoomSettled,
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 220,
                  // Listens to `_viewportController` for the sole row this session concern
                  // (`showFieldOfView`) drives — every other row in this palette reads a plain
                  // widget field instead.
                  child: ListenableBuilder(
                    listenable: _viewportController,
                    builder: (context, _) => OcptFloorPlanPalette(
                      setName: widget.floorPlanSet?.name ?? "",
                      shotCode: _focusShotCode,
                      activeTool: widget.activeTool,
                      activeSetElementShape: widget.activeSetElementShape,
                      isReadOnly: widget.isReadOnly,
                      hiddenLayers: widget.hiddenLayers,
                      sequenceCameras: widget.sequenceCameras,
                      hiddenCameraSymbolIds: widget.hiddenCameraSymbolIds,
                      isOnionSkinPreviousShown: widget.isOnionSkinPreviousShown,
                      isOnionSkinNextShown: widget.isOnionSkinNextShown,
                      onionSkinOpacity: widget.onionSkinOpacity,
                      isMetricsShown: widget.isMetricsShown,
                      isShowFieldOfViewShown: _viewportController.showFieldOfView,
                      isUnderlayHidden: widget.isUnderlayHidden,
                      hasUnderlay: widget.floorPlanSet?.underlayAssetId != null,
                      onToolSelected: widget.onToolSelected,
                      onSetElementShapeSelected: widget.onSetElementShapeSelected,
                      onLayerVisibilityToggled: widget.onLayerVisibilityToggled,
                      onCameraVisibilityToggled: widget.onCameraVisibilityToggled,
                      onOnionSkinToggled: widget.onOnionSkinToggled,
                      onOnionSkinOpacityChanged: widget.onOnionSkinOpacityChanged,
                      onMetricsToggled: widget.onMetricsToggled,
                      onShowFieldOfViewToggled: () => _viewportController.setShowFieldOfView(
                        value: !_viewportController.showFieldOfView,
                      ),
                      onUnderlayVisibilityToggled: widget.onUnderlayVisibilityToggled,
                      onUnderlayClearRequested: widget.onUnderlayClearRequested,
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: OcptFloorPlanCanvas(
                    floorPlanSet: widget.floorPlanSet,
                    shotRankByShotId: widget.shotRankByShotId,
                    focusShotId: widget.focusShotId,
                    previousShotId: widget.previousShotId,
                    nextShotId: widget.nextShotId,
                    isOnionSkinPreviousShown: widget.isOnionSkinPreviousShown,
                    isOnionSkinNextShown: widget.isOnionSkinNextShown,
                    onionSkinOpacity: widget.onionSkinOpacity,
                    hiddenLayers: widget.hiddenLayers,
                    hiddenCameraSymbolIds: widget.hiddenCameraSymbolIds,
                    isUnderlayHidden: widget.isUnderlayHidden,
                    selectedSymbolId: widget.selectedSymbolId,
                    selectedArrowId: widget.selectedArrowId,
                    pendingArrowAnchorSymbolId: widget.pendingArrowAnchorSymbolId,
                    isMetricsShown: widget.isMetricsShown,
                    isAllCamerasShown: widget.isAllCamerasShown,
                    activeTool: widget.activeTool,
                    activeLayer: widget.activeLayer,
                    activeSetElementShape: widget.activeSetElementShape,
                    viewportController: _viewportController,
                    isReadOnly: widget.isReadOnly,
                    symbolLabelValueOf: widget.symbolLabelValueOf,
                    onSymbolSelected: widget.onSymbolSelected,
                    onSymbolPlaced: widget.onSymbolPlaced,
                    onSymbolMoved: widget.onSymbolMoved,
                    onSymbolResized: widget.onSymbolResized,
                    onSymbolRotated: widget.onSymbolRotated,
                    onSymbolFovChanged: widget.onSymbolFovChanged,
                    onSymbolFovReachChanged: widget.onSymbolFovReachChanged,
                    onSymbolDeleteRequested: widget.onSymbolDeleteRequested,
                    onArrowSymbolTapped: widget.onArrowSymbolTapped,
                    onArrowAnchorCancelled: widget.onArrowAnchorCancelled,
                    onArrowSelected: widget.onArrowSelected,
                    onArrowCurveChanged: widget.onArrowCurveChanged,
                    onSymbolDuplicateRequested: widget.onSymbolDuplicateRequested,
                    onSymbolDuplicateDragged: widget.onSymbolDuplicateDragged,
                    onGhostShotFocusRequested: widget.onGhostShotFocusRequested,
                    onSymbolLabelChanged: widget.onSymbolLabelChanged,
                    onUnderlayTransformChanged: widget.onUnderlayTransformChanged,
                    onZoomSettled: widget.onZoomSettled,
                  ),
                ),
              ],
            ),
          ),
          OcptFloorPlanFocusStrip(
            shots: widget.shots,
            hasCameraOnSetOf: widget.hasCameraOnSetOf,
            selectedShotId: widget.focusShotId,
            previousShotId: widget.previousShotId,
            nextShotId: widget.nextShotId,
            isAllCamerasShown: widget.isAllCamerasShown,
            onShotChipSelected: widget.onShotChipSelected,
            onAllCamerasToggled: widget.onAllCamerasToggled,
          ),
        ],
      ),
    );
  }

  /// [OcptFloorPlanView.focusShotId]'s own display code (`12/3`) among
  /// [OcptFloorPlanView.shots], or null while no shot is focused — the palette's own `Shot <code> —
  /// this shot only` group header.
  String? get _focusShotCode {
    final focusShotId = widget.focusShotId;
    if (focusShotId == null) {
      return null;
    }
    for (final shot in widget.shots) {
      if (shot.id == focusShotId) {
        return shot.code;
      }
    }
    return null;
  }

  /// `←`/`→` walk the sequence's shots; `Escape` cancels the arrow tool's own pending anchor while
  /// one is pending; `Ctrl+D` duplicates the selected symbol (R2) — see the class doc comment.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onShotWalkRequested(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onShotWalkRequested(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        widget.pendingArrowAnchorSymbolId != null) {
      widget.onArrowAnchorCancelled?.call();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyD &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      final selectedSymbolId = widget.selectedSymbolId;
      if (selectedSymbolId != null) {
        widget.onSymbolDuplicateRequested?.call(selectedSymbolId);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}
