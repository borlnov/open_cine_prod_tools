// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';

/// The floor plans view's own focus strip, along the bottom of the canvas
/// (`docs/plans/storyboard.md`, §4.3): one chip per shot of the sequence — always at least one
/// active once the sequence holds a shot at all (R2, "always a current shot"; a sequence holding
/// none shows an empty strip, since there is no current shot to name a chip for).
///
/// **The chip selection is the mode's shot selection** — `OcptShotListState.selectedShotId`,
/// [selectedShotId] here — so a chip dispatches the very same event the table's own rows do
/// ([onShotChipSelected] → `OcptShotListShotSelectedEvent`). A shot chip shows a **filled dot**
/// when [hasCameraOnSetOf] says the shot has a camera on the set currently shown, a **hollow** one
/// otherwise — a gap in the sequence's own numbers is a shot still to place, and this is the one
/// place that says which. The neighbour ghosted by the onion skin ([previousShotId]/[nextShotId])
/// carries a small `prev`/`next` tag.
class OcptFloorPlanFocusStrip extends StatelessWidget {
  /// The selected sequence's own shots, in order.
  final List<OcptShot> shots;

  /// Whether each of [shots] has a live camera symbol on the set currently shown, keyed by shot
  /// id — a shot missing from this map reads as having none.
  final Map<String, bool> hasCameraOnSetOf;

  /// The id of the currently selected (focused) shot, or null while the sequence holds none.
  final String? selectedShotId;

  /// The shot immediately before [selectedShotId], or null while there is none — ghosted by the
  /// onion skin, carries the `prev` tag.
  final String? previousShotId;

  /// The shot immediately after [selectedShotId]. See [previousShotId].
  final String? nextShotId;

  /// Whether the "All cameras" toggle is on: every shot's own camera of the set currently shown
  /// draws as a ghost alongside the focused shot's own (R3, `docs/plans/storyboard.md`, §9.4) — a
  /// display toggle only, never a state that gates a tool. Single-clicking one of those ghosts on
  /// the canvas jumps straight to its own shot.
  final bool isAllCamerasShown;

  /// Called with a shot's id when its own chip is clicked.
  final ValueChanged<String> onShotChipSelected;

  /// Called when the "All cameras" toggle is clicked. Never withheld: it only reads.
  final VoidCallback onAllCamerasToggled;

  /// Class constructor
  const OcptFloorPlanFocusStrip({
    super.key,
    required this.shots,
    required this.hasCameraOnSetOf,
    required this.selectedShotId,
    required this.previousShotId,
    required this.nextShotId,
    required this.isAllCamerasShown,
    required this.onShotChipSelected,
    required this.onAllCamerasToggled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildAllCamerasToggleChip(context),
            const SizedBox(width: 12),
            for (final shot in shots) ...[
              if (shot != shots.first) const SizedBox(width: 6),
              _buildShotChip(context, shot),
            ],
            if (shots.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                tr.shotListFloorPlanFocusWalkHint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The "All cameras" toggle chip, leading the strip — see [isAllCamerasShown]'s own doc comment.
  Widget _buildAllCamerasToggleChip(BuildContext context) {
    final theme = Theme.of(context);

    return _buildChip(
      context,
      isActive: isAllCamerasShown,
      onTap: onAllCamerasToggled,
      label: Tr.of(context).shotListFloorPlanAllCamerasToggleLabel,
      leading: Icon(
        isAllCamerasShown ? Icons.videocam : Icons.videocam_outlined,
        size: 14,
        color: isAllCamerasShown ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// One shot's own chip: its code, a filled/hollow dot for [hasCameraOnSetOf], and a `prev`/
  /// `next` tag while it is [previousShotId]/[nextShotId].
  Widget _buildShotChip(BuildContext context, OcptShot shot) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isActive = shot.id == selectedShotId;
    final hasCamera = hasCameraOnSetOf[shot.id] ?? false;
    final tag = shot.id == previousShotId
        ? tr.shotListFloorPlanFocusPreviousChipTag
        : shot.id == nextShotId
        ? tr.shotListFloorPlanFocusNextChipTag
        : null;

    return _buildChip(
      context,
      isActive: isActive,
      onTap: () => onShotChipSelected(shot.id),
      label: shot.code,
      leading: Icon(
        hasCamera ? Icons.circle : Icons.circle_outlined,
        size: 8,
        color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      ),
      trailing: tag == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                tag,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
    );
  }

  /// One chip's own chrome, shared by the `Sequence` chip and every shot chip.
  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Widget? leading,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ocptRadiusMedium),
      mouseCursor: ocptClickableCursor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : null,
          borderRadius: BorderRadius.circular(ocptRadiusMedium),
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 6)],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive ? theme.colorScheme.primary : null,
                fontWeight: isActive ? FontWeight.w700 : null,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
