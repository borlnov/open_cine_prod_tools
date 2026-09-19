// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';

/// One live camera symbol of the sequence, for the tray's own expandable cameras row under the
/// `Sequence` focus — [OcptFloorPlanLayerTray.sequenceCameras]' own entries.
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

/// The floor plans canvas's own layer tray, down the left of the canvas
/// (`docs/plans/storyboard.md`, §4.3): the **`Sequence layers`** group (décor, furniture, fixed
/// props) with a visibility eye and an active-layer pick per row, the **`Shot layers`** group
/// (cameras, characters, lights, hand props) with a visibility eye each, the cameras row's own
/// expandable per-camera visibility under the `Sequence` focus, the **`Onion skin`** block
/// (previous, next, one opacity), the metrics toggle, and the underlay's own row with its eye.
///
/// Visibility, [activeLayer], [hiddenCameraSymbolIds], the onion skin block, the metrics toggle
/// and the underlay's own visibility are **view state**: every toggle reported by this widget only
/// ever reads, so this widget takes no `isReadOnly` flag of its own at all — the tray keeps
/// working under a read-only preview exactly as the deliverable requires. [onUnderlayClearRequested]
/// is the one exception, a real project write: the mode passes it null under a read-only preview,
/// exactly like every other withheld callback in this milestone.
class OcptFloorPlanLayerTray extends StatelessWidget {
  /// Every layer currently hidden, sequence and shot layers alike.
  final Set<OcptFloorPlanLayer> hiddenLayers;

  /// The sequence layer a placed set element lands on.
  final OcptFloorPlanLayer activeLayer;

  /// Whether the shot focus is currently active
  /// (`OcptShotListState.isFloorPlanShotFocusActive`) — the cameras row only expands into
  /// [sequenceCameras] under the `Sequence` focus, where every shot's camera draws at once.
  final bool isShotFocusActive;

  /// Every live camera symbol of the sequence, for the cameras row's own expandable per-camera
  /// visibility list — empty (and the row stays collapsed) under a shot focus.
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

  /// Whether the selected case's underlay is currently hidden.
  final bool isUnderlayHidden;

  /// Whether the selected case carries an underlay at all — the row still shows, greyed, while it
  /// doesn't.
  final bool hasUnderlay;

  /// Called with the layer whose eye was clicked, sequence or shot.
  final ValueChanged<OcptFloorPlanLayer> onLayerVisibilityToggled;

  /// Called with the sequence layer just picked as the active one.
  final ValueChanged<OcptFloorPlanLayer> onActiveLayerChanged;

  /// Called with a camera symbol's id whose own eye was clicked.
  final ValueChanged<String> onCameraVisibilityToggled;

  /// Called with `true` to toggle the previous-shot ghost, `false` for the next-shot one.
  final ValueChanged<bool> onOnionSkinToggled;

  /// Called with the slider's own new opacity.
  final ValueChanged<double> onOnionSkinOpacityChanged;

  /// Called when the metrics toggle is clicked.
  final VoidCallback onMetricsToggled;

  /// Called when the underlay row's own eye is clicked.
  final VoidCallback onUnderlayVisibilityToggled;

  /// Called when the underlay row's own `Clear underlay` action is clicked, or null while
  /// withheld (no underlay to clear, or a read-only preview). Only asks — the mode opens
  /// `OcptConfirmDialog`.
  final VoidCallback? onUnderlayClearRequested;

  /// Class constructor
  const OcptFloorPlanLayerTray({
    super.key,
    required this.hiddenLayers,
    required this.activeLayer,
    required this.isShotFocusActive,
    required this.sequenceCameras,
    required this.hiddenCameraSymbolIds,
    required this.isOnionSkinPreviousShown,
    required this.isOnionSkinNextShown,
    required this.onionSkinOpacity,
    required this.isMetricsShown,
    required this.isUnderlayHidden,
    required this.hasUnderlay,
    required this.onLayerVisibilityToggled,
    required this.onActiveLayerChanged,
    required this.onCameraVisibilityToggled,
    required this.onOnionSkinToggled,
    required this.onOnionSkinOpacityChanged,
    required this.onMetricsToggled,
    required this.onUnderlayVisibilityToggled,
    required this.onUnderlayClearRequested,
  });

  /// The sequence layers offered, in tray order.
  static const _sequenceLayers = [
    OcptFloorPlanLayer.decor,
    OcptFloorPlanLayer.furniture,
    OcptFloorPlanLayer.fixedProps,
  ];

  /// The shot layers offered, in tray order.
  static const _shotLayers = [
    OcptFloorPlanLayer.cameras,
    OcptFloorPlanLayer.characters,
    OcptFloorPlanLayer.lights,
    OcptFloorPlanLayer.handProps,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              tr.shotListFloorPlanSequenceLayersGroupTitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final layer in _sequenceLayers) _buildLayerRow(context, layer),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              tr.shotListFloorPlanShotLayersGroupTitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final layer in _shotLayers)
            layer == OcptFloorPlanLayer.cameras && !isShotFocusActive
                ? _buildCamerasRow(context)
                : _buildLayerRow(context, layer, isRadioSelectable: false),
          const Divider(height: 16),
          _buildOnionSkinBlock(context),
          const Divider(height: 16),
          _buildMetricsToggle(context),
          const Divider(height: 16),
          _buildUnderlayRow(context),
        ],
      ),
    );
  }

  /// The cameras row, expanded into one sub-row per [sequenceCameras] entry with its own eye —
  /// only reached under the `Sequence` focus, where every shot's camera draws numbered.
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
            child: Text(
              tr.shotListFloorPlanLayerCamerasLabel,
              style: theme.textTheme.bodySmall,
            ),
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

  /// The metrics overlay's own toggle row.
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
  );

  /// One layer's own row: a leading colour swatch (and, for a sequence layer, a radio dot naming
  /// the active one — [isRadioSelectable] is false for a shot layer, which has no "active layer"
  /// concept of its own, each of its four tools placing on its own fixed layer instead), the
  /// label, and a trailing eye toggling its visibility.
  Widget _buildLayerRow(
    BuildContext context,
    OcptFloorPlanLayer layer, {
    bool isRadioSelectable = true,
  }) {
    final theme = Theme.of(context);
    final isActive = layer == activeLayer;
    final isHidden = hiddenLayers.contains(layer);

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          if (isRadioSelectable) ...[
            Icon(
              isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
          ],
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
            child: Text(_labelOf(context, layer), style: theme.textTheme.bodySmall),
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

    return isRadioSelectable
        ? InkWell(onTap: () => onActiveLayerChanged(layer), mouseCursor: ocptClickableCursor, child: row)
        : row;
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

  /// [layer]'s own localized label.
  String _labelOf(BuildContext context, OcptFloorPlanLayer layer) {
    final tr = Tr.of(context);
    return switch (layer) {
      OcptFloorPlanLayer.decor => tr.shotListFloorPlanLayerDecorLabel,
      OcptFloorPlanLayer.furniture => tr.shotListFloorPlanLayerFurnitureLabel,
      OcptFloorPlanLayer.fixedProps => tr.shotListFloorPlanLayerFixedPropsLabel,
      OcptFloorPlanLayer.cameras => tr.shotListFloorPlanLayerCamerasLabel,
      OcptFloorPlanLayer.characters => tr.shotListFloorPlanLayerCharactersLabel,
      OcptFloorPlanLayer.lights => tr.shotListFloorPlanLayerLightsLabel,
      OcptFloorPlanLayer.handProps => tr.shotListFloorPlanLayerHandPropsLabel,
    };
  }
}
