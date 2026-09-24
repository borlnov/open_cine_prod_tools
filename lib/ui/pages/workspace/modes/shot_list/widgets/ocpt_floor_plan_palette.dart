// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';

/// One live camera symbol of the set, for the palette's own `View` group cameras row — see
/// `OcptFloorPlanLayerTray.sequenceCameras`'s own doc comment, which this replaces.
class OcptFloorPlanTraySequenceCamera extends Equatable {
  /// The camera symbol's own id.
  final String symbolId;

  /// The camera's derived label (`3`, `3A`, `3B`), or `?` while its shot's rank isn't known —
  /// mirrors `OcptFloorPlanSymbolShape.cameraLabel`.
  final String label;

  /// Class constructor
  const OcptFloorPlanTraySequenceCamera({required this.symbolId, required this.label});

  /// Object properties
  @override
  List<Object?> get props => [symbolId, label];
}

/// The floor plans canvas's own two-tier **palette**, down the left of the canvas, replacing
/// `OcptFloorPlanLayerTray` (R3, the floor-plan redesign — `docs/plans/storyboard.md`, §9.1, §9.4):
/// its group headers say **where a placed element lands** — a `Set · <name> — shared` group (the
/// one merged [OcptFloorPlanLayer.set] layer, always editable) and a `Shot <code> — this shot only`
/// group (camera, character, light) — plus a `View` group absorbing the old tray's own toggles
/// (layer visibility, the underlay, onion skin, metrics, field of view).
///
/// **No tool is ever dimmed** (R2 already dropped tool dimming; this palette keeps it dropped):
/// every entry is always available, `isReadOnly` withholding the write the moment one is picked or
/// dropped, never before. An entry is **both** a click-to-arm control ([onToolSelected], the tool
/// bar's own mechanism, kept working) **and** a drag source (a plain [Draggable] anchored at the
/// pointer, so a drop lands exactly under it) that `OcptFloorPlanCanvas` accepts through its own
/// `DragTarget<OcptFloorPlanPaletteDragPayload>` and places at the drop point.
///
/// Visibility, the onion skin block, the metrics toggle, the field-of-view toggle and the
/// underlay's own visibility are **view state**: every toggle this palette reports only ever reads,
/// so — like the tray before it — it takes no `isReadOnly` flag of its own at all.
/// [onUnderlayClearRequested] is the one exception, a real project write, withheld (null) under a
/// read-only preview exactly like every other write in this milestone.
class OcptFloorPlanPalette extends StatelessWidget {
  /// The selected set's own name, for the `Set · <name> — shared` group header.
  final String setName;

  /// The focused shot's own display code (`12/3`), for the `Shot <code> — this shot only` group
  /// header, or null while no shot is focused yet.
  final String? shotCode;

  /// The currently active tool — which entry (if any) reads as armed.
  final OcptFloorPlanTool activeTool;

  /// The décor primitive a `setElement` click-to-arm placement carries — which of the four typed
  /// entries below (wall/door/furniture/freeform) reads as armed while [activeTool] is
  /// [OcptFloorPlanTool.setElement].
  final OcptFloorPlanSetElementShape activeSetElementShape;

  /// Whether the mode shows a project version being previewed read-only: every entry stays visible
  /// and clickable/draggable, but arming or dropping one is a no-op while this is true — the canvas
  /// itself is what actually withholds the write (its own `onSymbolPlaced` null), so this palette
  /// only skips offering a drag source that would go nowhere.
  final bool isReadOnly;

  /// Every layer currently hidden, sequence and shot layers alike.
  final Set<OcptFloorPlanLayer> hiddenLayers;

  /// Every live camera symbol of the sequence, for the `View` group's own expandable cameras row.
  final List<OcptFloorPlanTraySequenceCamera> sequenceCameras;

  /// The ids of [sequenceCameras] currently hidden.
  final Set<String> hiddenCameraSymbolIds;

  /// Whether the onion skin's own previous-shot ghost is shown.
  final bool isOnionSkinPreviousShown;

  /// Whether the onion skin's own next-shot ghost is shown.
  final bool isOnionSkinNextShown;

  /// The onion skin's own ghost opacity, 0..1.
  final double onionSkinOpacity;

  /// Whether the metrics overlay is shown.
  final bool isMetricsShown;

  /// Whether a camera's own field-of-view wedge is drawn.
  final bool isShowFieldOfViewShown;

  /// Whether the selected set's underlay is currently hidden.
  final bool isUnderlayHidden;

  /// Whether the selected set carries an underlay at all — the row still shows, greyed, while it
  /// doesn't.
  final bool hasUnderlay;

  /// Called with the entry's own tool when it is clicked (arming it) or successfully dropped onto
  /// the canvas (`OcptFloorPlanCanvas`'s own `DragTarget` reports the drop itself; this callback is
  /// only the click-to-arm path).
  final ValueChanged<OcptFloorPlanTool> onToolSelected;

  /// Called with the décor primitive just clicked or dropped among the four typed set-element
  /// entries — click-to-arms [activeSetElementShape] alongside [OcptFloorPlanTool.setElement]
  /// itself ([onToolSelected], called first). A drop reports through the drag payload instead
  /// (`OcptFloorPlanCanvas`'s own `DragTarget<OcptFloorPlanPaletteDragPayload>`), so this callback
  /// is, like [onToolSelected], only the click-to-arm path.
  final ValueChanged<OcptFloorPlanSetElementShape> onSetElementShapeSelected;

  /// Called with the layer whose eye was clicked.
  final ValueChanged<OcptFloorPlanLayer> onLayerVisibilityToggled;

  /// Called with a camera symbol's id whose own eye was clicked.
  final ValueChanged<String> onCameraVisibilityToggled;

  /// Called with `true` to toggle the previous-shot ghost, `false` for the next-shot one.
  final ValueChanged<bool> onOnionSkinToggled;

  /// Called with the slider's own new opacity.
  final ValueChanged<double> onOnionSkinOpacityChanged;

  /// Called when the metrics toggle is clicked.
  final VoidCallback onMetricsToggled;

  /// Called when the field-of-view toggle is clicked. Never withheld: it only flips a drawing
  /// preference on `OcptFloorPlanViewportController`.
  final VoidCallback onShowFieldOfViewToggled;

  /// Called when the underlay row's own eye is clicked.
  final VoidCallback onUnderlayVisibilityToggled;

  /// Called when the underlay row's own `Clear underlay` action is clicked, or null while withheld
  /// (no underlay to clear, or a read-only preview). Only asks — the mode opens `OcptConfirmDialog`.
  final VoidCallback? onUnderlayClearRequested;

  /// Class constructor
  const OcptFloorPlanPalette({
    super.key,
    required this.setName,
    required this.shotCode,
    required this.activeTool,
    required this.activeSetElementShape,
    required this.isReadOnly,
    required this.hiddenLayers,
    required this.sequenceCameras,
    required this.hiddenCameraSymbolIds,
    required this.isOnionSkinPreviousShown,
    required this.isOnionSkinNextShown,
    required this.onionSkinOpacity,
    required this.isMetricsShown,
    required this.isShowFieldOfViewShown,
    required this.isUnderlayHidden,
    required this.hasUnderlay,
    required this.onToolSelected,
    required this.onSetElementShapeSelected,
    required this.onLayerVisibilityToggled,
    required this.onCameraVisibilityToggled,
    required this.onOnionSkinToggled,
    required this.onOnionSkinOpacityChanged,
    required this.onMetricsToggled,
    required this.onShowFieldOfViewToggled,
    required this.onUnderlayVisibilityToggled,
    required this.onUnderlayClearRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final shotCode = this.shotCode;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildGroupTitle(context, tr.shotListFloorPlanPaletteSetGroupTitle(setName)),
          _buildEntry(
            context,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.horizontal_rule,
            label: tr.shotListFloorPlanToolWallAction,
            setElementShape: OcptFloorPlanSetElementShape.wall,
          ),
          _buildEntry(
            context,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.door_front_door_outlined,
            label: tr.shotListFloorPlanToolDoorAction,
            setElementShape: OcptFloorPlanSetElementShape.door,
          ),
          _buildEntry(
            context,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.chair_outlined,
            label: tr.shotListFloorPlanToolFurnitureAction,
            setElementShape: OcptFloorPlanSetElementShape.furniture,
          ),
          _buildEntry(
            context,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.gesture,
            label: tr.shotListFloorPlanToolFreeformAction,
            setElementShape: OcptFloorPlanSetElementShape.freeform,
          ),
          if (shotCode != null) ...[
            const Divider(height: 16),
            _buildGroupTitle(context, tr.shotListFloorPlanPaletteShotGroupTitle(shotCode)),
            _buildEntry(
              context,
              tool: OcptFloorPlanTool.camera,
              icon: Icons.videocam_outlined,
              label: tr.shotListFloorPlanToolCameraAction,
            ),
            _buildEntry(
              context,
              tool: OcptFloorPlanTool.character,
              icon: Icons.person_outline,
              label: tr.shotListFloorPlanToolCharacterAction,
            ),
            _buildEntry(
              context,
              tool: OcptFloorPlanTool.light,
              icon: Icons.wb_incandescent_outlined,
              label: tr.shotListFloorPlanToolLightAction,
            ),
          ],
          const Divider(height: 16),
          _buildGroupTitle(context, tr.shotListFloorPlanPaletteViewGroupTitle),
          _buildLayerRow(context, OcptFloorPlanLayer.set, tr.shotListFloorPlanLayerDecorLabel),
          _buildCamerasRow(context),
          _buildLayerRow(
            context,
            OcptFloorPlanLayer.characters,
            tr.shotListFloorPlanLayerCharactersLabel,
          ),
          _buildLayerRow(context, OcptFloorPlanLayer.lights, tr.shotListFloorPlanLayerLightsLabel),
          _buildLayerRow(context, OcptFloorPlanLayer.props, tr.shotListFloorPlanLayerPropsLabel),
          const Divider(height: 16),
          _buildOnionSkinBlock(context),
          const Divider(height: 16),
          _buildMetricsToggle(context),
          _buildShowFieldOfViewToggle(context),
          const Divider(height: 16),
          _buildUnderlayRow(context),
        ],
      ),
    );
  }

  /// One group's own header text.
  Widget _buildGroupTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// One placeable tool's own entry: an icon and its label, armed by a click ([onToolSelected],
  /// and, for a typed set-element entry, [onSetElementShapeSelected] too) and offered as a drag
  /// source (`Draggable<OcptFloorPlanPaletteDragPayload>`, anchored at the pointer so
  /// `OcptFloorPlanCanvas`'s own `DragTarget` drops it exactly where released, carrying
  /// [setElementShape] on the drag itself).
  ///
  /// [setElementShape] is set for one of the palette's own four typed set-element entries (wall,
  /// door, furniture, freeform) and null for every other entry (camera, character, light): it is
  /// what tells the four typed entries apart from one another, since they all share
  /// [OcptFloorPlanTool.setElement].
  Widget _buildEntry(
    BuildContext context, {
    required OcptFloorPlanTool tool,
    required IconData icon,
    required String label,
    OcptFloorPlanSetElementShape? setElementShape,
  }) {
    final theme = Theme.of(context);
    final isActive =
        tool == activeTool && (setElementShape == null || setElementShape == activeSetElementShape);

    final row = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive ? theme.colorScheme.primary : null,
                fontWeight: isActive ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );

    final entry = InkWell(
      onTap: () {
        onToolSelected(tool);
        if (setElementShape != null) {
          onSetElementShapeSelected(setElementShape);
        }
      },
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: row,
    );

    if (isReadOnly) {
      return entry;
    }

    return Draggable<OcptFloorPlanPaletteDragPayload>(
      data: OcptFloorPlanPaletteDragPayload(tool: tool, setElementShape: setElementShape),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 160, child: row),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: entry),
      child: entry,
    );
  }

  /// The cameras row, expanded into one sub-row per [sequenceCameras] entry with its own eye.
  Widget _buildCamerasRow(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color(ocptFloorPlanLayerColorArgb(OcptFloorPlanLayer.cameras)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr.shotListFloorPlanLayerCamerasLabel, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
      children: sequenceCameras.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  tr.shotListFloorPlanNoCamerasHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ]
          : [for (final camera in sequenceCameras) _buildCameraRow(context, camera)],
    );
  }

  /// One camera's own sub-row of [_buildCamerasRow]: its derived label and a trailing eye.
  Widget _buildCameraRow(BuildContext context, OcptFloorPlanTraySequenceCamera camera) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isHidden = hiddenCameraSymbolIds.contains(camera.symbolId);

    return Padding(
      padding: const EdgeInsets.only(left: 30, right: 12, top: 2, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(camera.label, style: theme.textTheme.bodySmall),
          ),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: isHidden ? tr.shotListFloorPlanShowLayerAction : tr.shotListFloorPlanHideLayerAction,
            onPressed: () => onCameraVisibilityToggled(camera.symbolId),
            icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
        ],
      ),
    );
  }

  /// The `Onion skin` block: the previous/next toggles and the opacity slider.
  Widget _buildOnionSkinBlock(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            tr.shotListFloorPlanOnionSkinGroupTitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          controlAffinity: ListTileControlAffinity.leading,
          value: isOnionSkinPreviousShown,
          onChanged: (_) => onOnionSkinToggled(true),
          title: Text(
            tr.shotListFloorPlanOnionSkinPreviousLabel,
            style: theme.textTheme.bodySmall,
          ),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          controlAffinity: ListTileControlAffinity.leading,
          value: isOnionSkinNextShown,
          onChanged: (_) => onOnionSkinToggled(false),
          title: Text(tr.shotListFloorPlanOnionSkinNextLabel, style: theme.textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(tr.shotListFloorPlanOnionSkinOpacityLabel, style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: onionSkinOpacity,
                  min: 0.05,
                  onChanged: onOnionSkinOpacityChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The metrics overlay's own toggle row, plus a small help affordance explaining what the
  /// overlay shows ([_buildMetricsHelp]) — a tap-triggered [Tooltip], never hover- or
  /// long-press-only, since a long press is the only way a touch device would otherwise reach a
  /// plain [Tooltip]'s own message.
  Widget _buildMetricsToggle(BuildContext context) => CheckboxListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    controlAffinity: ListTileControlAffinity.leading,
    value: isMetricsShown,
    onChanged: (_) => onMetricsToggled(),
    title: Text(
      Tr.of(context).shotListFloorPlanMetricsToggleLabel,
      style: Theme.of(context).textTheme.bodySmall,
    ),
    secondary: _buildMetricsHelp(context),
  );

  /// The metrics toggle's own help affordance: a small `?` icon whose [Tooltip] opens on a plain
  /// tap ([TooltipTriggerMode.tap]) rather than the default long press, so it reaches a touch
  /// device (Android) exactly as easily as a mouse hover reaches an ordinary tooltip elsewhere in
  /// this app. Explains what the metrics overlay draws: the distance from the selected object to
  /// every other visible one, or, with a camera selected, the distance to the subject.
  Widget _buildMetricsHelp(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message: Tr.of(context).shotListFloorPlanMetricsHelpText,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.help_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
          semanticLabel: Tr.of(context).shotListFloorPlanMetricsHelpAction,
        ),
      ),
    );
  }

  /// The field-of-view overlay's own toggle row: every camera's own wedge, on by default.
  Widget _buildShowFieldOfViewToggle(BuildContext context) => CheckboxListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    controlAffinity: ListTileControlAffinity.leading,
    value: isShowFieldOfViewShown,
    onChanged: (_) => onShowFieldOfViewToggled(),
    title: Text(
      Tr.of(context).shotListFloorPlanFieldOfViewToggleLabel,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );

  /// One `View` group layer row: a leading colour swatch, the label, and a trailing eye toggling
  /// its visibility. No radio dot: every remaining layer places through its own palette entry or
  /// tool, not through an "active layer" pick — the set layer having merged into one
  /// (`OcptFloorPlanLayer.set`) is the only sequence layer left, and every shot layer already has
  /// its own dedicated entry above.
  Widget _buildLayerRow(BuildContext context, OcptFloorPlanLayer layer, String label) {
    final theme = Theme.of(context);
    final isHidden = hiddenLayers.contains(layer);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color(ocptFloorPlanLayerColorArgb(layer)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: isHidden
                ? Tr.of(context).shotListFloorPlanShowLayerAction
                : Tr.of(context).shotListFloorPlanHideLayerAction,
            onPressed: () => onLayerVisibilityToggled(layer),
            icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
        ],
      ),
    );
  }

  /// The underlay's own row: its label and a trailing eye toggling its visibility.
  Widget _buildUnderlayRow(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr.shotListFloorPlanUnderlayRowLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasUnderlay ? null : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onUnderlayClearRequested != null)
            IconButton(
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: tr.shotListFloorPlanClearUnderlayAction,
              onPressed: onUnderlayClearRequested,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: isUnderlayHidden ? tr.shotListFloorPlanShowLayerAction : tr.shotListFloorPlanHideLayerAction,
            onPressed: hasUnderlay ? onUnderlayVisibilityToggled : null,
            icon: Icon(
              isUnderlayHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
