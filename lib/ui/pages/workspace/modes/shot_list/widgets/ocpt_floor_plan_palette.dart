// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_palette_drag_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_prop_chip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_tray_sequence_camera.dart';

/// The floor plans canvas's own two-tier **palette**, down the left of the canvas, replacing
/// `OcptFloorPlanLayerTray`: its group headers say **where a placed element lands** — a
/// `Set · <name> — shared` group (the
/// one merged [OcptFloorPlanLayer.set] layer, always editable) and a `Shot <code> — this shot only`
/// group (camera, character, light) — plus a `View` group absorbing the old tray's own toggles
/// (layer visibility, the underlay, onion skin, metrics, field of view).
///
/// **No tool is ever dimmed**: every entry is always available, `isReadOnly` withholding the write
/// the moment one is picked or
/// dropped, never before. An entry is **both** a click-to-arm control ([onToolSelected], the tool
/// bar's own mechanism, kept working) **and** a drag source (a plain [Draggable] anchored at the
/// pointer, so a drop lands exactly under it) that `OcptFloorPlanCanvas` accepts through its own
/// `DragTarget<OcptFloorPlanPaletteDragPayload>` and places at the drop point.
///
/// Visibility, the onion skin block, the metrics toggle, the field-of-view toggle and the
/// underlay's own visibility are **view state**: every toggle this palette reports only ever reads,
/// so — like the tray before it — it takes no `isReadOnly` flag of its own at all.
/// [onUnderlayClearRequested] is the one exception, a real project write, withheld (null) under a
/// read-only preview exactly like every other write here.
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

  /// Each `View` group layer's own count of elements currently drawable for the focused
  /// sequence/shot — what the mode counts from the canvas's own drawn sheet, before the
  /// [hiddenLayers]/[hiddenCameraSymbolIds] visibility filter, so toggling a layer off never zeroes
  /// its own count back out. A layer missing from this map (never expected, defensive only) reads
  /// as `0`. No `Tr` and no counting logic live here: this palette only shows the int it is handed.
  final Map<OcptFloorPlanLayer, int> layerElementCounts;

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
  /// (no underlay to clear, or a read-only preview). Only asks — the mode opens
  /// `OcptConfirmDialog`.
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
    required this.layerElementCounts,
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

  /// Build the floor plan palette as a [Material].
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
          _GroupTitle(title: tr.shotListFloorPlanPaletteSetGroupTitle(setName)),
          _Entry(
            palette: this,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.horizontal_rule,
            label: tr.shotListFloorPlanToolWallAction,
            setElementShape: OcptFloorPlanSetElementShape.wall,
            sceneScope: OcptFloorPlanScope.set,
          ),
          _Entry(
            palette: this,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.door_front_door_outlined,
            label: tr.shotListFloorPlanToolDoorAction,
            setElementShape: OcptFloorPlanSetElementShape.door,
            sceneScope: OcptFloorPlanScope.set,
          ),
          _Entry(
            palette: this,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.chair_outlined,
            label: tr.shotListFloorPlanToolFurnitureAction,
            setElementShape: OcptFloorPlanSetElementShape.furniture,
            sceneScope: OcptFloorPlanScope.set,
          ),
          _Entry(
            palette: this,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.gesture,
            label: tr.shotListFloorPlanToolFreeformAction,
            setElementShape: OcptFloorPlanSetElementShape.freeform,
            sceneScope: OcptFloorPlanScope.set,
          ),
          const Divider(height: 16),
          _GroupTitle(title: tr.shotListFloorPlanPaletteSequenceGroupTitle(sequenceCode)),
          _Entry(
            palette: this,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.chair_outlined,
            label: tr.shotListFloorPlanToolFurnitureAction,
            setElementShape: OcptFloorPlanSetElementShape.furniture,
            sceneScope: OcptFloorPlanScope.scene,
          ),
          _Entry(
            palette: this,
            tool: OcptFloorPlanTool.setElement,
            icon: Icons.gesture,
            label: tr.shotListFloorPlanToolFreeformAction,
            setElementShape: OcptFloorPlanSetElementShape.freeform,
            sceneScope: OcptFloorPlanScope.scene,
          ),
          _PropsChips(palette: this),
          if (shotCode != null) ...[
            const Divider(height: 16),
            _GroupTitle(title: tr.shotListFloorPlanPaletteShotGroupTitle(shotCode)),
            _Entry(
              palette: this,
              tool: OcptFloorPlanTool.camera,
              icon: Icons.videocam_outlined,
              label: tr.shotListFloorPlanToolCameraAction,
            ),
            _Entry(
              palette: this,
              tool: OcptFloorPlanTool.character,
              icon: Icons.person_outline,
              label: tr.shotListFloorPlanToolCharacterAction,
            ),
            _Entry(
              palette: this,
              tool: OcptFloorPlanTool.light,
              icon: Icons.wb_incandescent_outlined,
              label: tr.shotListFloorPlanToolLightAction,
            ),
          ],
          const Divider(height: 16),
          _GroupTitle(title: tr.shotListFloorPlanPaletteViewGroupTitle),
          _LayerRow(
            palette: this,
            layer: OcptFloorPlanLayer.set,
            label: tr.shotListFloorPlanLayerSetLabel,
          ),
          _CamerasRow(palette: this),
          _LayerRow(
            palette: this,
            layer: OcptFloorPlanLayer.characters,
            label: tr.shotListFloorPlanLayerCharactersLabel,
          ),
          _LayerRow(
            palette: this,
            layer: OcptFloorPlanLayer.lights,
            label: tr.shotListFloorPlanLayerLightsLabel,
          ),
          _LayerRow(
            palette: this,
            layer: OcptFloorPlanLayer.props,
            label: tr.shotListFloorPlanLayerPropsLabel,
          ),
          const Divider(height: 16),
          _OnionSkinBlock(palette: this),
          const Divider(height: 16),
          _OcptFloorPlanMetricsToggleRow(
            isMetricsShown: isMetricsShown,
            onMetricsToggled: onMetricsToggled,
          ),
          _ShowFieldOfViewToggle(palette: this),
          const Divider(height: 16),
          _UnderlayRow(palette: this),
        ],
      ),
    );
  }
}

/// One group's own header text.
class _GroupTitle extends StatelessWidget {
  /// The title this part draws.
  final String title;

  /// Class constructor
  const _GroupTitle({required this.title});

  /// Build the group title as a [Padding].
  @override
  Widget build(BuildContext context) {
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
}

/// One placeable tool's own entry: an icon and its label, armed by a click
/// ([OcptFloorPlanPalette.onToolSelected], and, for a typed set-element entry,
/// [OcptFloorPlanPalette.onSetElementShapeSelected]/
/// [OcptFloorPlanPalette.onSetElementScopeSelected] too) and offered as a drag source
/// (`Draggable<OcptFloorPlanPaletteDragPayload>`, anchored at the pointer so
/// `OcptFloorPlanCanvas`'s own `DragTarget` drops it exactly where released, carrying
/// [setElementShape]/[sceneScope] on the drag itself).
///
/// [setElementShape]/[sceneScope] are set for one of the palette's own typed set-element entries
/// (wall, door, furniture, freeform — each of the last two appearing twice, once per scope) and
/// null for every other entry (camera, character, light): together they tell every typed entry
/// apart from the others, since they all share [OcptFloorPlanTool.setElement].
class _Entry extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// The tool this part draws.
  final OcptFloorPlanTool tool;

  /// The icon this part draws.
  final IconData icon;

  /// The label this part draws.
  final String label;

  /// The setElementShape this part draws.
  final OcptFloorPlanSetElementShape? setElementShape;

  /// The sceneScope this part draws.
  final OcptFloorPlanScope? sceneScope;

  /// Class constructor
  const _Entry({
    required this.palette,
    required this.tool,
    required this.icon,
    required this.label,
    this.setElementShape,
    this.sceneScope,
  });

  /// Build the entry as a [Draggable].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive =
        tool == palette.activeTool &&
        (setElementShape == null || setElementShape == palette.activeSetElementShape) &&
        (sceneScope == null || sceneScope == palette.activeSetElementScope);

    final row = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
            : null,
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
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
        palette.onToolSelected(tool);
        final setElementShape = this.setElementShape;
        if (setElementShape != null) {
          palette.onSetElementShapeSelected(setElementShape);
        }
        final sceneScope = this.sceneScope;
        if (sceneScope != null) {
          palette.onSetElementScopeSelected(sceneScope);
        }
      },
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: row,
    );

    if (palette.isReadOnly) {
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
}

/// The `Sequence` group's own breakdown-props chips: one chip per [OcptFloorPlanPalette.propsChips]
/// entry, plus the fixed add-prop button for a free-typed label.
class _PropsChips extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// Class constructor
  const _PropsChips({required this.palette});

  /// Build the props chips as a [Padding].
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final chip in palette.propsChips) _PropChip(palette: palette, chip: chip),
        _AddPropButton(palette: palette),
      ],
    ),
  );
}

/// One breakdown prop's own chip: click-to-arms [OcptFloorPlanTool.prop] with [chip]'s own name
/// ([OcptFloorPlanPalette.onToolSelected] then [OcptFloorPlanPalette.onPropChipSelected]), and
/// stays usable after a placement — two candles, two drops — since arming never consumes it.
/// Offered as a drag source too, carrying [chip]'s own name on the drag itself. Shows
/// `<name> ×<quantity>` while [chip] carries one.
class _PropChip extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// The chip this part draws.
  final OcptFloorPlanPropChip chip;

  /// Class constructor
  const _PropChip({required this.palette, required this.chip});

  /// Build the prop chip as a [Draggable].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final isActive =
        palette.activeTool == OcptFloorPlanTool.prop && palette.activeLabel == chip.name;
    final label = chip.quantity.isEmpty
        ? chip.name
        : tr.shotListFloorPlanPropChipWithQuantityLabel(chip.name, chip.quantity);

    final chipWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
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
        palette.onToolSelected(OcptFloorPlanTool.prop);
        palette.onPropChipSelected(chip.name);
      },
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: chipWidget,
    );

    if (palette.isReadOnly) {
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
}

/// The fixed add-prop button: asks for a free-typed label
/// ([OcptFloorPlanPalette.onOtherPropRequested]) before arming [OcptFloorPlanTool.prop] with it and
/// placing it at once — the mode reuses the character name-picker's own dialog pattern for the
/// typing itself. Reads as "add a prop to this sequence" rather than one more prop chip: a leading
/// [Icons.add] plus the word alone ([Tr.shotListFloorPlanAddPropAction]) — the icon already carries
/// the plus, so the label text never repeats it.
class _AddPropButton extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// Class constructor
  const _AddPropButton({required this.palette});

  /// Build the add prop button as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: palette.onOtherPropRequested,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(tr.shotListFloorPlanAddPropAction, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The cameras row, expanded into one sub-row per [OcptFloorPlanPalette.sequenceCameras] entry with
/// its own eye — its own title carries that list's own count, exactly like a plain layer row (each
/// entry already carries its own individual eye, so the title itself has none to withhold).
class _CamerasRow extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// Class constructor
  const _CamerasRow({required this.palette});

  /// Build the cameras row as an [ExpansionTile].
  @override
  Widget build(BuildContext context) {
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
            child: Text(
              tr.shotListFloorPlanLayerRowWithCountLabel(
                tr.shotListFloorPlanLayerCamerasLabel,
                palette.sequenceCameras.length,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
      children: palette.sequenceCameras.isEmpty
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
          : [
              for (final camera in palette.sequenceCameras)
                _CameraRow(palette: palette, camera: camera),
            ],
    );
  }
}

/// One camera's own sub-row of [_CamerasRow]: its derived label and a trailing eye.
class _CameraRow extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// The camera this part draws.
  final OcptFloorPlanTraySequenceCamera camera;

  /// Class constructor
  const _CameraRow({required this.palette, required this.camera});

  /// Build the camera row as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isHidden = palette.hiddenCameraSymbolIds.contains(camera.symbolId);

    return Padding(
      padding: const EdgeInsets.only(left: 30, right: 12, top: 2, bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(camera.label, style: theme.textTheme.bodySmall)),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: isHidden
                ? tr.shotListFloorPlanShowLayerAction
                : tr.shotListFloorPlanHideLayerAction,
            onPressed: () => palette.onCameraVisibilityToggled(camera.symbolId),
            icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
        ],
      ),
    );
  }
}

/// The `Onion skin` block: the previous/next toggles and the opacity slider.
class _OnionSkinBlock extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// Class constructor
  const _OnionSkinBlock({required this.palette});

  /// Build the onion skin block as a [Column].
  @override
  Widget build(BuildContext context) {
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
          value: palette.isOnionSkinPreviousShown,
          onChanged: (_) => palette.onOnionSkinToggled(true),
          title: Text(tr.shotListFloorPlanOnionSkinPreviousLabel, style: theme.textTheme.bodySmall),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          controlAffinity: ListTileControlAffinity.leading,
          value: palette.isOnionSkinNextShown,
          onChanged: (_) => palette.onOnionSkinToggled(false),
          title: Text(tr.shotListFloorPlanOnionSkinNextLabel, style: theme.textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(tr.shotListFloorPlanOnionSkinOpacityLabel, style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: palette.onionSkinOpacity,
                  min: 0.05,
                  onChanged: palette.onOnionSkinOpacityChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The field-of-view overlay's own toggle row: every camera's own wedge, on by default.
class _ShowFieldOfViewToggle extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// Class constructor
  const _ShowFieldOfViewToggle({required this.palette});

  /// Build the show field of view toggle as a [CheckboxListTile].
  @override
  Widget build(BuildContext context) => CheckboxListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    controlAffinity: ListTileControlAffinity.leading,
    value: palette.isShowFieldOfViewShown,
    onChanged: (_) => palette.onShowFieldOfViewToggled(),
    title: Text(
      Tr.of(context).shotListFloorPlanFieldOfViewToggleLabel,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// One `View` group layer row: a leading colour swatch, the label with its own
/// [OcptFloorPlanPalette.layerElementCounts] count, and a trailing eye toggling its visibility. No
/// radio dot: every remaining layer places through its own palette entry or tool, not through an
/// "active layer" pick — the set layer having merged into one (`OcptFloorPlanLayer.set`) is the
/// only sequence layer left, and every shot layer already has its own dedicated entry above.
///
/// The eye is withheld (disabled, not hidden) while the layer's own count is `0` and it isn't
/// already hidden — nothing to hide — but stays enabled while hidden regardless of the count, so
/// a layer hidden before its last element was removed can still be shown again.
class _LayerRow extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// The layer this part draws.
  final OcptFloorPlanLayer layer;

  /// The label this part draws.
  final String label;

  /// Class constructor
  const _LayerRow({required this.palette, required this.layer, required this.label});

  /// Build the layer row as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isHidden = palette.hiddenLayers.contains(layer);
    final count = palette.layerElementCounts[layer] ?? 0;

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
            child: Text(
              tr.shotListFloorPlanLayerRowWithCountLabel(label, count),
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: isHidden
                ? tr.shotListFloorPlanShowLayerAction
                : tr.shotListFloorPlanHideLayerAction,
            onPressed: (isHidden || count > 0)
                ? () => palette.onLayerVisibilityToggled(layer)
                : null,
            icon: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
        ],
      ),
    );
  }
}

/// The underlay's own row: its label and a trailing eye toggling its visibility.
class _UnderlayRow extends StatelessWidget {
  /// The palette this part belongs to, which supplies the armed tool, the visibility state and
  /// the callbacks.
  final OcptFloorPlanPalette palette;

  /// Class constructor
  const _UnderlayRow({required this.palette});

  /// Build the underlay row as a [Padding].
  @override
  Widget build(BuildContext context) {
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
                color: palette.hasUnderlay ? null : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (palette.onUnderlayClearRequested != null)
            IconButton(
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: tr.shotListFloorPlanClearUnderlayAction,
              onPressed: palette.onUnderlayClearRequested,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: palette.isUnderlayHidden
                ? tr.shotListFloorPlanShowLayerAction
                : tr.shotListFloorPlanHideLayerAction,
            onPressed: palette.hasUnderlay ? palette.onUnderlayVisibilityToggled : null,
            icon: Icon(
              palette.isUnderlayHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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

  /// Create the [_OcptFloorPlanMetricsToggleRowState] holding the state of the floor plan metrics
  /// toggle row.
  @override
  State<_OcptFloorPlanMetricsToggleRow> createState() => _OcptFloorPlanMetricsToggleRowState();
}

/// [_OcptFloorPlanMetricsToggleRow]'s own state: just whether the help paragraph is open.
class _OcptFloorPlanMetricsToggleRowState extends State<_OcptFloorPlanMetricsToggleRow> {
  /// Whether the help paragraph is showing.
  bool _isHelpOpen = false;

  /// Build the floor plan metrics toggle row as a [Column].
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
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
