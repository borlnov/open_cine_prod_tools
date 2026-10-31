// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';

/// The floor plans view's own focus strip, along the bottom of the canvas: one chip per shot of
/// the sequence — always at least one active once the sequence holds a shot at all; a sequence
/// holding none shows an empty strip, since there is no current shot to name a chip for.
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
            for (final shot in shots) ...[
              if (shot != shots.first) const SizedBox(width: 6),
              _ShotChip(
                shot: shot,
                isActive: shot.id == selectedShotId,
                hasCamera: hasCameraOnSetOf[shot.id] ?? false,
                tag: shot.id == previousShotId
                    ? tr.shotListFloorPlanFocusPreviousChipTag
                    : shot.id == nextShotId
                    ? tr.shotListFloorPlanFocusNextChipTag
                    : null,
                onTap: () => onShotChipSelected(shot.id),
              ),
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
}

/// One shot's own chip: its code, a filled/hollow dot for whether it has a camera on the set
/// shown, and a `prev`/`next` tag while it is the neighbour the onion skin ghosts.
class _ShotChip extends StatelessWidget {
  /// The shot this chip names.
  final OcptShot shot;

  /// Whether this is the selected (focused) shot.
  final bool isActive;

  /// Whether the shot has a live camera symbol on the set currently shown.
  final bool hasCamera;

  /// The `prev`/`next` tag, or null while the shot is neither neighbour.
  final String? tag;

  /// Called when the chip is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _ShotChip({
    required this.shot,
    required this.isActive,
    required this.hasCamera,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = this.tag;

    return _Chip(
      isActive: isActive,
      onTap: onTap,
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
}

/// One chip's own chrome.
class _Chip extends StatelessWidget {
  /// The chip's label.
  final String label;

  /// Whether the chip is the selected one.
  final bool isActive;

  /// Called when the chip is clicked.
  final VoidCallback onTap;

  /// What is drawn before the label, if anything.
  final Widget? leading;

  /// What is drawn after the label, if anything.
  final Widget? trailing;

  /// Class constructor
  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leading = this.leading;
    final trailing = this.trailing;

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
