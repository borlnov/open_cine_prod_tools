// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';

/// The floor plans view's own focus strip, along the bottom of the canvas
/// (`docs/plans/storyboard.md`, §4.3): the `Sequence` chip, then one chip per shot of the
/// sequence.
///
/// **The chip selection is the mode's shot selection** — `OcptShotListState.selectedShotId`,
/// [selectedShotId] here — so a chip dispatches the very same event the table's own rows do
/// ([onShotChipSelected] → `OcptShotListShotSelectedEvent`); the `Sequence` chip dispatches the
/// deselection instead ([onSequenceChipSelected] → `OcptShotListShotDeselectedEvent`). A shot chip
/// shows a **filled dot** when [hasCameraOnSetOf] says the shot has a camera on the set currently
/// shown, a **hollow** one otherwise — a gap in the sequence's own numbers is a shot still to
/// place, and this is the one place that says which. The neighbour ghosted by the onion skin under
/// a shot focus ([previousShotId]/[nextShotId]) carries a small `prev`/`next` tag.
class OcptFloorPlanFocusStrip extends StatelessWidget {
  /// The selected sequence's own shots, in order.
  final List<OcptShot> shots;

  /// Whether each of [shots] has a live camera symbol on the set currently shown, keyed by shot
  /// id — a shot missing from this map reads as having none.
  final Map<String, bool> hasCameraOnSetOf;

  /// The id of the currently selected (focused) shot, or null for the `Sequence` focus.
  final String? selectedShotId;

  /// The shot immediately before [selectedShotId], or null while there is none — ghosted by the
  /// onion skin, carries the `prev` tag.
  final String? previousShotId;

  /// The shot immediately after [selectedShotId]. See [previousShotId].
  final String? nextShotId;

  /// Called when the `Sequence` chip is clicked.
  final VoidCallback onSequenceChipSelected;

  /// Called with a shot's id when its own chip is clicked.
  final ValueChanged<String> onShotChipSelected;

  /// Class constructor
  const OcptFloorPlanFocusStrip({
    super.key,
    required this.shots,
    required this.hasCameraOnSetOf,
    required this.selectedShotId,
    required this.previousShotId,
    required this.nextShotId,
    required this.onSequenceChipSelected,
    required this.onShotChipSelected,
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
            _buildChip(
              context,
              label: tr.shotListFloorPlanFocusSequenceChipLabel,
              isActive: selectedShotId == null,
              onTap: onSequenceChipSelected,
            ),
            for (final shot in shots) ...[
              const SizedBox(width: 6),
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
