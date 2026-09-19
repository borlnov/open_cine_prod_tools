// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_case.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_focus_strip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_layer_tray.dart';
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
/// the floor plans centre view, or leaving the mode): a case tab switch keeps it, since only the
/// centre view switch remounts this widget.
class OcptFloorPlanView extends StatefulWidget {
  /// The selected sequence's own cases, for the sheet the canvas builds.
  final OcptFloorPlanCase? floorPlanCase;

  /// Every shot of the selected sequence's own 1-based display rank, keyed by shot id — see
  /// `OcptFloorPlanCanvas.shotRankByShotId`'s own doc comment.
  final Map<String, int> shotRankByShotId;

  /// The last zoom the bloc saw settled — what this view's own controller is created at.
  final double initialZoom;

  /// The sequence layers currently hidden.
  final Set<OcptFloorPlanLayer> hiddenLayers;

  /// Whether the selected case's underlay is currently hidden.
  final bool isUnderlayHidden;

  /// The id of the currently selected symbol, or null while none is.
  final String? selectedSymbolId;

  /// The canvas's own currently active tool.
  final OcptFloorPlanTool activeTool;

  /// The sequence layer a placed set element lands on.
  final OcptFloorPlanLayer activeLayer;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// Called with the tool just picked.
  final ValueChanged<OcptFloorPlanTool> onToolSelected;

  /// Called with the sequence layer whose eye was clicked.
  final ValueChanged<OcptFloorPlanLayer> onLayerVisibilityToggled;

  /// Called with the sequence layer just picked as the active one.
  final ValueChanged<OcptFloorPlanLayer> onActiveLayerChanged;

  /// Called when the underlay row's own eye is clicked.
  final VoidCallback onUnderlayVisibilityToggled;

  /// Called when the tool bar's own underlay action is clicked, or null while withheld.
  final VoidCallback? onUnderlayImportRequested;

  /// Called when the tray's own `Clear underlay` action is clicked, or null while withheld.
  final VoidCallback? onUnderlayClearRequested;

  /// Called with a symbol's id when it is selected, or null to clear the selection.
  final ValueChanged<String?> onSymbolSelected;

  /// Called with the tray's active layer and the clicked point (metres), or null while withheld.
  final void Function(OcptFloorPlanLayer layer, double xM, double yM)? onSymbolPlaced;

  /// Called with a symbol's id and its new centre (metres), or null while withheld.
  final void Function(String symbolId, double xM, double yM)? onSymbolMoved;

  /// Called with a symbol's id and its new footprint (metres), or null while withheld.
  final void Function(String symbolId, double widthM, double heightM)? onSymbolResized;

  /// Called with a symbol's id and its new rotation (degrees), or null while withheld.
  final void Function(String symbolId, double rotationDeg)? onSymbolRotated;

  /// Called with the selected symbol's id when its own delete action is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onSymbolDeleteRequested;

  /// Called with the underlay's new frame (metres), or null while withheld.
  final void Function(double xM, double yM, double widthM, double heightM)?
  onUnderlayTransformChanged;

  /// Called with the zoom just settled on, whichever gesture settled it.
  final ValueChanged<double> onZoomSettled;

  /// Class constructor
  const OcptFloorPlanView({
    super.key,
    required this.floorPlanCase,
    required this.shotRankByShotId,
    required this.initialZoom,
    required this.hiddenLayers,
    required this.isUnderlayHidden,
    required this.selectedSymbolId,
    required this.activeTool,
    required this.activeLayer,
    required this.isReadOnly,
    required this.onToolSelected,
    required this.onLayerVisibilityToggled,
    required this.onActiveLayerChanged,
    required this.onUnderlayVisibilityToggled,
    required this.onUnderlayImportRequested,
    required this.onUnderlayClearRequested,
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
  State<OcptFloorPlanView> createState() => _OcptFloorPlanViewState();
}

class _OcptFloorPlanViewState extends State<OcptFloorPlanView> {
  /// The live zoom/pan source of truth for as long as this view stays mounted — see the class doc
  /// comment.
  late final OcptFloorPlanViewportController _viewportController = OcptFloorPlanViewportController(
    zoom: widget.initialZoom,
  );

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcptFloorPlanToolBar(
          activeTool: widget.activeTool,
          viewportController: _viewportController,
          isReadOnly: widget.isReadOnly,
          hasUnderlay: widget.floorPlanCase?.underlayAssetId != null,
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
                width: 200,
                child: OcptFloorPlanLayerTray(
                  hiddenLayers: widget.hiddenLayers,
                  activeLayer: widget.activeLayer,
                  isUnderlayHidden: widget.isUnderlayHidden,
                  hasUnderlay: widget.floorPlanCase?.underlayAssetId != null,
                  onLayerVisibilityToggled: widget.onLayerVisibilityToggled,
                  onActiveLayerChanged: widget.onActiveLayerChanged,
                  onUnderlayVisibilityToggled: widget.onUnderlayVisibilityToggled,
                  onUnderlayClearRequested: widget.onUnderlayClearRequested,
                ),
              ),
              VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
              Expanded(
                child: OcptFloorPlanCanvas(
                  floorPlanCase: widget.floorPlanCase,
                  shotRankByShotId: widget.shotRankByShotId,
                  hiddenLayers: widget.hiddenLayers,
                  isUnderlayHidden: widget.isUnderlayHidden,
                  selectedSymbolId: widget.selectedSymbolId,
                  activeTool: widget.activeTool,
                  activeLayer: widget.activeLayer,
                  viewportController: _viewportController,
                  isReadOnly: widget.isReadOnly,
                  onSymbolSelected: widget.onSymbolSelected,
                  onSymbolPlaced: widget.onSymbolPlaced,
                  onSymbolMoved: widget.onSymbolMoved,
                  onSymbolResized: widget.onSymbolResized,
                  onSymbolRotated: widget.onSymbolRotated,
                  onSymbolDeleteRequested: widget.onSymbolDeleteRequested,
                  onUnderlayTransformChanged: widget.onUnderlayTransformChanged,
                  onZoomSettled: widget.onZoomSettled,
                ),
              ),
            ],
          ),
        ),
        const OcptFloorPlanFocusStrip(),
      ],
    );
  }
}
