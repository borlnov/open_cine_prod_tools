// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_viewport_controller.dart';

/// The floor plans view's own tool bar, across the top of the canvas
/// (`docs/plans/storyboard.md`, §4.3).
///
/// Offers [OcptFloorPlanTool.select] and [OcptFloorPlanTool.label] (scope-free, both stay lit
/// under either focus) alongside two dimmed clusters — [OcptFloorPlanTool.setElement] (sequence-
/// scoped) and the shot-scoped foursome ([OcptFloorPlanTool.camera]/
/// [OcptFloorPlanTool.character]/[OcptFloorPlanTool.light]/[OcptFloorPlanTool.arrow]) — plus the
/// underlay import action, never a toggled tool since picking a file is a one-shot action.
///
/// **A tool that would draw into the frozen scope is dimmed, never hidden**
/// (`docs/plans/storyboard.md`, §4.3): [isShotFocusActive] says which cluster is currently frozen,
/// and [_dimHint] states why in a one-line hint next to it — set-element under a shot focus
/// (`Set elements go to a sequence layer — pick "Sequence" below`), the shot-scoped foursome under
/// the `Sequence` focus (`Pick a shot below to place cameras, characters, lights and arrows`). The
/// zoom cluster on the trailing edge reads/writes [viewportController] directly (a discrete click
/// is already a "settled" zoom, unlike the canvas's own scroll-wheel zoom — see that controller's
/// own doc comment) and stays available under [isReadOnly], since zoom only reads.
class OcptFloorPlanToolBar extends StatelessWidget {
  /// The currently active tool.
  final OcptFloorPlanTool activeTool;

  /// Whether the shot focus is currently active (`OcptShotListState.isFloorPlanShotFocusActive`) —
  /// what decides which cluster of tools is dimmed.
  final bool isShotFocusActive;

  /// The live zoom/pan controller the zoom cluster reads and writes.
  final OcptFloorPlanViewportController viewportController;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// Whether the selected set already carries an underlay — swaps the action's own label between
  /// `Import underlay` and `Replace underlay`.
  final bool hasUnderlay;

  /// Called with the tool just picked.
  final ValueChanged<OcptFloorPlanTool> onToolSelected;

  /// Called when the underlay action is clicked, or null while withheld.
  final VoidCallback? onUnderlayImportRequested;

  /// Called with the zoom just settled on by a tool bar button.
  final ValueChanged<double> onZoomSettled;

  /// Class constructor
  const OcptFloorPlanToolBar({
    super.key,
    required this.activeTool,
    required this.isShotFocusActive,
    required this.viewportController,
    required this.isReadOnly,
    required this.hasUnderlay,
    required this.onToolSelected,
    required this.onUnderlayImportRequested,
    required this.onZoomSettled,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final hint = _dimHint(tr);

    // A wide bar (the sequence-scoped and shot-scoped tool clusters, the dim hint, the underlay
    // action): the leading cluster scrolls horizontally on its own on a narrower window, while the
    // underlay action and the zoom cluster — the two controls worth always keeping in reach — stay
    // pinned at the trailing edge.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolButton(
                    context,
                    tool: OcptFloorPlanTool.select,
                    icon: Icons.near_me_outlined,
                    tooltip: tr.shotListFloorPlanToolSelectAction,
                  ),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    context,
                    tool: OcptFloorPlanTool.setElement,
                    icon: Icons.chair_outlined,
                    tooltip: tr.shotListFloorPlanToolSetElementAction,
                  ),
                  const SizedBox(width: 12),
                  VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
                  const SizedBox(width: 12),
                  _buildToolButton(
                    context,
                    tool: OcptFloorPlanTool.camera,
                    icon: Icons.videocam_outlined,
                    tooltip: tr.shotListFloorPlanToolCameraAction,
                  ),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    context,
                    tool: OcptFloorPlanTool.character,
                    icon: Icons.person_outline,
                    tooltip: tr.shotListFloorPlanToolCharacterAction,
                  ),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    context,
                    tool: OcptFloorPlanTool.light,
                    icon: Icons.wb_incandescent_outlined,
                    tooltip: tr.shotListFloorPlanToolLightAction,
                  ),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    context,
                    tool: OcptFloorPlanTool.arrow,
                    icon: Icons.north_east_outlined,
                    tooltip: tr.shotListFloorPlanToolArrowAction,
                  ),
                  const SizedBox(width: 12),
                  VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
                  const SizedBox(width: 12),
                  _buildToolButton(
                    context,
                    tool: OcptFloorPlanTool.label,
                    icon: Icons.label_outline,
                    tooltip: tr.shotListFloorPlanToolLabelAction,
                  ),
                  if (hint != null) ...[
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        hint,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onUnderlayImportRequested,
            icon: const Icon(Icons.image_outlined, size: 16),
            label: Text(
              hasUnderlay
                  ? tr.shotListFloorPlanReplaceUnderlayAction
                  : tr.shotListFloorPlanImportUnderlayAction,
            ),
          ),
          const SizedBox(width: 12),
          _buildZoomCluster(context),
        ],
      ),
    );
  }

  /// The one-line hint stated next to whichever cluster [_isDimmed] currently dims, or null while
  /// neither is (never reached: one of the two always is, the `Sequence` or a shot always being the
  /// current focus) — kept nullable so a caller adding a third focus later isn't forced to invent a
  /// hint for it.
  String? _dimHint(Tr tr) => isShotFocusActive
      ? tr.shotListFloorPlanSetElementDimmedHint
      : tr.shotListFloorPlanShotToolsDimmedHint;

  /// Whether [tool] is dimmed under the current focus — never hidden, `docs/plans/storyboard.md`,
  /// §4.3.
  bool _isDimmed(OcptFloorPlanTool tool) => switch (tool) {
    OcptFloorPlanTool.setElement => isShotFocusActive,
    OcptFloorPlanTool.camera ||
    OcptFloorPlanTool.character ||
    OcptFloorPlanTool.light ||
    OcptFloorPlanTool.arrow => !isShotFocusActive,
    OcptFloorPlanTool.select || OcptFloorPlanTool.label => false,
  };

  /// One tool bar toggle button.
  Widget _buildToolButton(
    BuildContext context, {
    required OcptFloorPlanTool tool,
    required IconData icon,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    final isActive = tool == activeTool;
    // `select` only ever reads (it picks/moves nothing by itself); every other tool writes the
    // moment it is used, so it is withheld under a read-only preview along with everything else
    // that writes (deliverable 9): a null `onPressed`, not a visually-identical no-op handler.
    // Dimmed under [_isDimmed] too — the frozen-scope rule, never hidden.
    final isWithheld = (isReadOnly && tool != OcptFloorPlanTool.select) || _isDimmed(tool);

    return Opacity(
      opacity: _isDimmed(tool) ? 0.4 : 1,
      child: Tooltip(
        message: tooltip,
        child: IconButton.filled(
          onPressed: isWithheld ? null : () => onToolSelected(tool),
          icon: Icon(icon, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                : Colors.transparent,
            foregroundColor: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            minimumSize: const Size(ocptToolbarChromeButtonSize, ocptToolbarChromeButtonSize),
          ),
        ),
      ),
    );
  }

  /// The trailing zoom out / percentage / zoom in cluster, always available (a read).
  Widget _buildZoomCluster(BuildContext context) => ListenableBuilder(
    listenable: viewportController,
    builder: (context, _) {
      final zoom = viewportController.zoom;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: Tr.of(context).shotListFloorPlanZoomOutAction,
            child: IconButton(
              onPressed: () => _applyZoom(zoom / 1.25),
              icon: const Icon(Icons.remove, size: 16),
            ),
          ),
          SizedBox(
            width: 48,
            child: Center(child: Text("${(zoom * 100).round()}%")),
          ),
          Tooltip(
            message: Tr.of(context).shotListFloorPlanZoomInAction,
            child: IconButton(
              onPressed: () => _applyZoom(zoom * 1.25),
              icon: const Icon(Icons.add, size: 16),
            ),
          ),
          Tooltip(
            message: Tr.of(context).shotListFloorPlanZoomResetAction,
            child: IconButton(
              onPressed: () => _applyZoom(1),
              icon: const Icon(Icons.center_focus_strong_outlined, size: 16),
            ),
          ),
        ],
      );
    },
  );

  /// Sets [viewportController]'s own zoom immediately (a click is already a settled gesture, no
  /// debounce needed unlike the canvas's own scroll wheel), then reports it.
  void _applyZoom(double value) {
    viewportController.setZoom(value);
    onZoomSettled(viewportController.zoom);
  }
}
