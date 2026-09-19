// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';

/// The floor plans canvas's own layer tray, down the left of the canvas
/// (`docs/plans/storyboard.md`, §4.3): the **`Sequence layers`** group (décor, furniture, fixed
/// props) with a visibility eye and an active-layer pick per row, plus the underlay's own row with
/// its eye. The **`Shot layers`** group, per-camera visibility and onion skin are M6 — not built
/// here at all.
///
/// Visibility, [activeLayer] and the underlay's own visibility are **view state**: every toggle
/// reported by this widget only ever reads, so this widget takes no `isReadOnly` flag of its own
/// at all — the tray keeps working under a read-only preview exactly as the deliverable requires.
/// [onUnderlayClearRequested] is the one exception, a real project write: the mode passes it null
/// under a read-only preview, exactly like every other withheld callback in this milestone.
class OcptFloorPlanLayerTray extends StatelessWidget {
  /// The sequence layers currently hidden.
  final Set<OcptFloorPlanLayer> hiddenLayers;

  /// The sequence layer a placed set element lands on.
  final OcptFloorPlanLayer activeLayer;

  /// Whether the selected case's underlay is currently hidden.
  final bool isUnderlayHidden;

  /// Whether the selected case carries an underlay at all — the row still shows, greyed, while it
  /// doesn't.
  final bool hasUnderlay;

  /// Called with the sequence layer whose eye was clicked.
  final ValueChanged<OcptFloorPlanLayer> onLayerVisibilityToggled;

  /// Called with the sequence layer just picked as the active one.
  final ValueChanged<OcptFloorPlanLayer> onActiveLayerChanged;

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
    required this.isUnderlayHidden,
    required this.hasUnderlay,
    required this.onLayerVisibilityToggled,
    required this.onActiveLayerChanged,
    required this.onUnderlayVisibilityToggled,
    required this.onUnderlayClearRequested,
  });

  /// The sequence layers offered, in tray order.
  static const _sequenceLayers = [
    OcptFloorPlanLayer.decor,
    OcptFloorPlanLayer.furniture,
    OcptFloorPlanLayer.fixedProps,
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
          _buildUnderlayRow(context),
        ],
      ),
    );
  }

  /// One sequence layer's own row: a leading colour swatch and radio dot naming the active layer,
  /// the label, and a trailing eye toggling its visibility.
  Widget _buildLayerRow(BuildContext context, OcptFloorPlanLayer layer) {
    final theme = Theme.of(context);
    final isActive = layer == activeLayer;
    final isHidden = hiddenLayers.contains(layer);

    return InkWell(
      onTap: () => onActiveLayerChanged(layer),
      mouseCursor: ocptClickableCursor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
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

  /// [layer]'s own localized label.
  String _labelOf(BuildContext context, OcptFloorPlanLayer layer) {
    final tr = Tr.of(context);
    return switch (layer) {
      OcptFloorPlanLayer.decor => tr.shotListFloorPlanLayerDecorLabel,
      OcptFloorPlanLayer.furniture => tr.shotListFloorPlanLayerFurnitureLabel,
      OcptFloorPlanLayer.fixedProps => tr.shotListFloorPlanLayerFixedPropsLabel,
      OcptFloorPlanLayer.cameras ||
      OcptFloorPlanLayer.characters ||
      OcptFloorPlanLayer.lights ||
      OcptFloorPlanLayer.handProps =>
        layer.name,
    };
  }
}
