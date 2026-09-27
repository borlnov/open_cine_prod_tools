// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';

/// One breakdown prop of the focused sequence, for the palette's own `Sequence` group chips (R5b,
/// `docs/plans/storyboard.md`, §10.4) — a read-only projection of the *dépouillement*'s own
/// `scene_elements` link joined with the `elements` catalogue, loaded by the bloc (no `Tr` in
/// services): [quantity] is already resolved to the link's own override or the element's own
/// catalogue quantity, whichever is set, and is empty while neither carries one.
class OcptFloorPlanPropChip extends Equatable {
  /// The element's own catalogue id — what a placed prop symbol's label is filled from, never
  /// stored as a link of its own (`OcptFloorPlanSymbolsTable`'s own doc comment: a label is free
  /// text).
  final String elementId;

  /// The element's own display name — the chip's own label, and what a placed symbol's own label
  /// is set to.
  final String name;

  /// The effective quantity (the scene's own override, or the element's own catalogue quantity), a
  /// decimal stored as text, or empty while neither is set — the chip shows `<name> ×<quantity>`
  /// only while this isn't empty.
  final String quantity;

  /// Class constructor
  const OcptFloorPlanPropChip({required this.elementId, required this.name, required this.quantity});

  /// Object properties
  @override
  List<Object?> get props => [elementId, name, quantity];
}

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
  /// The selected set's own name, for the `Set · <name> — shared by every sequence` group header.
  final String setName;

  /// The focused sequence's own display number, for the `Sequence <n> — this sequence only` group
  /// header.
  final String sequenceCode;

  /// The focused shot's own display code (`12/3`), for the `Shot <code> — this shot only` group
  /// header, or null while no shot is focused yet.
  final String? shotCode;

  /// The currently active tool — which entry (if any) reads as armed.
  final OcptFloorPlanTool activeTool;

  /// The décor primitive a `setElement` click-to-arm placement carries — which of the typed
  /// entries below (wall/door/furniture/freeform) reads as armed while [activeTool] is
  /// [OcptFloorPlanTool.setElement].
  final OcptFloorPlanSetElementShape activeSetElementShape;

  /// The scope a `setElement` click-to-arm placement lands at — which of the `Set`/`Sequence`
  /// groups' own matching entry reads as armed alongside [activeSetElementShape].
  final OcptFloorPlanScope activeSetElementScope;

  /// A `prop` click-to-arm placement's own armed label — which chip (or the `Other…` chip's own
  /// typed text) reads as armed while [activeTool] is [OcptFloorPlanTool.prop].
  final String activeLabel;

  /// The focused sequence's own breakdown props (category `prop` alone), for the `Sequence`
  /// group's own chips.
  final List<OcptFloorPlanPropChip> propsChips;

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

  /// Called with the décor primitive just clicked or dropped among the typed set-element
  /// entries — click-to-arms [activeSetElementShape] alongside [OcptFloorPlanTool.setElement]
  /// itself ([onToolSelected], called first). A drop reports through the drag payload instead
  /// (`OcptFloorPlanCanvas`'s own `DragTarget<OcptFloorPlanPaletteDragPayload>`), so this callback
  /// is, like [onToolSelected], only the click-to-arm path.
  final ValueChanged<OcptFloorPlanSetElementShape> onSetElementShapeSelected;

  /// Called with the scope just clicked alongside a typed set-element entry — click-to-arms
  /// [activeSetElementScope]. Only the click-to-arm path; a drop's own payload carries its own
  /// scope directly.
  final ValueChanged<OcptFloorPlanScope> onSetElementScopeSelected;

  /// Called with a props chip's own label when it is clicked — click-to-arms [activeLabel]
  /// alongside [OcptFloorPlanTool.prop] itself ([onToolSelected], called first). Only the
  /// click-to-arm path; a drop's own payload carries its own label directly.
  final ValueChanged<String> onPropChipSelected;

  /// Called when the `Other…` chip is clicked, asking for a free-typed label before arming
  /// [OcptFloorPlanTool.prop] with it.
  final VoidCallback onOtherPropRequested;

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
    required this.sequenceCode,
    required this.shotCode,
    required this.activeTool,
    required this.activeSetElementShape,
    required this.activeSetElementScope,
    required this.activeLabel,
    required this.propsChips,
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
    required this.onSetElementScopeSelected,
    required this.onPropChipSelected,
    required this.onOtherPropRequested,
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
            sceneScope: OcptFloorPlanScope.set,
          ),
          _buildEntry(
            context,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.door_front_door_outlined,
            label: tr.shotListFloorPlanToolDoorAction,
            setElementShape: OcptFloorPlanSetElementShape.door,
            sceneScope: OcptFloorPlanScope.set,
          ),
          _buildEntry(
            context,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.chair_outlined,
            label: tr.shotListFloorPlanToolFurnitureAction,
            setElementShape: OcptFloorPlanSetElementShape.furniture,
            sceneScope: OcptFloorPlanScope.set,
          ),
          _buildEntry(
            context,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.gesture,
            label: tr.shotListFloorPlanToolFreeformAction,
            setElementShape: OcptFloorPlanSetElementShape.freeform,
            sceneScope: OcptFloorPlanScope.set,
          ),
          const Divider(height: 16),
          _buildGroupTitle(context, tr.shotListFloorPlanPaletteSequenceGroupTitle(sequenceCode)),
          _buildEntry(
            context,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.chair_outlined,
            label: tr.shotListFloorPlanToolFurnitureAction,
            setElementShape: OcptFloorPlanSetElementShape.furniture,
            sceneScope: OcptFloorPlanScope.scene,
          ),
          _buildEntry(
            context,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.gesture,
            label: tr.shotListFloorPlanToolFreeformAction,
            setElementShape: OcptFloorPlanSetElementShape.freeform,
            sceneScope: OcptFloorPlanScope.scene,
          ),
          _buildPropsChips(context, tr),
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
  /// and, for a typed set-element entry, [onSetElementShapeSelected]/[onSetElementScopeSelected]
  /// too) and offered as a drag source (`Draggable<OcptFloorPlanPaletteDragPayload>`, anchored at
  /// the pointer so `OcptFloorPlanCanvas`'s own `DragTarget` drops it exactly where released,
  /// carrying [setElementShape]/[sceneScope] on the drag itself).
  ///
  /// [setElementShape]/[sceneScope] are set for one of the palette's own typed set-element entries
  /// (wall, door, furniture, freeform — each of the last two appearing twice, once per scope) and
  /// null for every other entry (camera, character, light): together they tell every typed entry
  /// apart from the others, since they all share [OcptFloorPlanTool.setElement].
  Widget _buildEntry(
    BuildContext context, {
    required OcptFloorPlanTool tool,
    required IconData icon,
    required String label,
    OcptFloorPlanSetElementShape? setElementShape,
    OcptFloorPlanScope? sceneScope,
  }) {
    final theme = Theme.of(context);
    final isActive =
        tool == activeTool &&
        (setElementShape == null || setElementShape == activeSetElementShape) &&
        (sceneScope == null || sceneScope == activeSetElementScope);

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
        if (sceneScope != null) {
          onSetElementScopeSelected(sceneScope);
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
      data: OcptFloorPlanPaletteDragPayload(
        tool: tool,
        setElementShape: setElementShape,
        sceneScope: sceneScope,
      ),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 160, child: row),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: entry),
      child: entry,
    );
  }

  /// The `Sequence` group's own breakdown-props chips (R5b, `docs/plans/storyboard.md`, §10.4):
  /// one chip per [propsChips] entry, plus a fixed `Other…` chip for a free-typed label.
  Widget _buildPropsChips(BuildContext context, Tr tr) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final chip in propsChips) _buildPropChip(context, tr, chip),
        _buildOtherPropChip(context, tr),
      ],
    ),
  );

  /// One breakdown prop's own chip: click-to-arms [OcptFloorPlanTool.prop] with [chip]'s own name
  /// ([onToolSelected] then [onPropChipSelected]), and stays usable after a placement — two
  /// candles, two drops — since arming never consumes it. Offered as a drag source too, carrying
  /// [chip]'s own name on the drag itself. Shows `<name> ×<quantity>` while [chip] carries one.
  Widget _buildPropChip(BuildContext context, Tr tr, OcptFloorPlanPropChip chip) {
    final theme = Theme.of(context);
    final isActive = activeTool == OcptFloorPlanTool.prop && activeLabel == chip.name;
    final label = chip.quantity.isEmpty
        ? chip.name
        : tr.shotListFloorPlanPropChipWithQuantityLabel(chip.name, chip.quantity);

    final chipWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isActive ? theme.colorScheme.primary : null,
          fontWeight: isActive ? FontWeight.w700 : null,
        ),
      ),
    );

    final entry = InkWell(
      onTap: () {
        onToolSelected(OcptFloorPlanTool.prop);
        onPropChipSelected(chip.name);
      },
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: chipWidget,
    );

    if (isReadOnly) {
      return entry;
    }

    return Draggable<OcptFloorPlanPaletteDragPayload>(
      data: OcptFloorPlanPaletteDragPayload(tool: OcptFloorPlanTool.prop, label: chip.name),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(color: Colors.transparent, child: chipWidget),
      childWhenDragging: Opacity(opacity: 0.4, child: entry),
      child: entry,
    );
  }

  /// The fixed `Other…` chip: asks for a free-typed label ([onOtherPropRequested]) before arming
  /// [OcptFloorPlanTool.prop] with it — the mode reuses the character name-picker's own dialog
  /// pattern for the typing itself.
  Widget _buildOtherPropChip(BuildContext context, Tr tr) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onOtherPropRequested,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(tr.shotListFloorPlanOtherPropChipLabel, style: theme.textTheme.bodySmall),
      ),
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

  /// The metrics overlay's own toggle row, plus its own inline help paragraph — see
  /// [_OcptFloorPlanMetricsToggleRow], whose own open/closed state this stateless palette cannot
  /// hold itself.
  Widget _buildMetricsToggle(BuildContext context) => _OcptFloorPlanMetricsToggleRow(
    isMetricsShown: isMetricsShown,
    onMetricsToggled: onMetricsToggled,
  );

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

/// The metrics overlay's own toggle row: a [CheckboxListTile] plus a help button whose press shows
/// or hides an inline paragraph underneath, explaining what the overlay draws (the distance from
/// the selected object to every other visible one, or, with a camera selected, the distance to the
/// subject). A real [IconButton] rather than a [Tooltip] — a `Tooltip`'s tap trigger still needs a
/// long press once it sits inside a `CheckboxListTile`'s `secondary` slot, which never reaches a
/// touch device — and its own open/closed state is this row's own local UI state, never bloc
/// state, mirroring the editor page's own `help`/`help_outline` toggle icon
/// (`lib/ui/pages/editor/editor_page.dart`).
class _OcptFloorPlanMetricsToggleRow extends StatefulWidget {
  /// Whether the metrics overlay is shown.
  final bool isMetricsShown;

  /// Called when the metrics toggle is clicked.
  final VoidCallback onMetricsToggled;

  /// Class constructor
  const _OcptFloorPlanMetricsToggleRow({
    required this.isMetricsShown,
    required this.onMetricsToggled,
  });

  @override
  State<_OcptFloorPlanMetricsToggleRow> createState() => _OcptFloorPlanMetricsToggleRowState();
}

/// [_OcptFloorPlanMetricsToggleRow]'s own state: just whether the help paragraph is open.
class _OcptFloorPlanMetricsToggleRowState extends State<_OcptFloorPlanMetricsToggleRow> {
  bool _isHelpOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          controlAffinity: ListTileControlAffinity.leading,
          value: widget.isMetricsShown,
          onChanged: (_) => widget.onMetricsToggled(),
          title: Text(tr.shotListFloorPlanMetricsToggleLabel, style: theme.textTheme.bodySmall),
          secondary: IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: tr.shotListFloorPlanMetricsHelpAction,
            isSelected: _isHelpOpen,
            onPressed: () => setState(() => _isHelpOpen = !_isHelpOpen),
            icon: Icon(_isHelpOpen ? Icons.help : Icons.help_outline),
          ),
        ),
        if (_isHelpOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              tr.shotListFloorPlanMetricsHelpText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
