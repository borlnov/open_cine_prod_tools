// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The shot list's left dock: the sequence tree, and the `+ Shot` action under it.
///
/// One entry per sequence — a screenplay scene, or the single orphan group holding the shots
/// whose scene was deleted — showing its number in the accent colour, its heading, and a muted
/// summary line. The selected sequence expands to list its shots, each with its Courier Prime
/// code, a ⚠ when it needs checking, its ellipsised shot size and a status dot.
///
/// Width-agnostic, like the screenplay's own scene panel: it fills whatever width its parent
/// `OcptWorkspaceDock` gives it and owns no background of its own.
class OcptShotListSequencePanel extends StatelessWidget {
  /// The sequences to list, in display order.
  final List<OcptShotSequence> sequences;

  /// The total number of shots across [sequences], shown next to the panel title.
  final int totalShotCount;

  /// The `OcptShotSequence.id` of the selected (expanded) sequence, or null if none is.
  final String? selectedSequenceId;

  /// The id of the selected shot, or null if none is.
  final String? selectedShotId;

  /// Called with a sequence's id when its entry is clicked.
  final ValueChanged<String> onSequenceSelected;

  /// Called with a shot's id when its entry is clicked.
  final ValueChanged<String> onShotSelected;

  /// Called when the footer's `+ Shot` button is clicked, or null while no shot can be created
  /// (no sequence selected, or the orphan group selected) — the button is then disabled.
  final VoidCallback? onShotCreated;

  /// Class constructor
  const OcptShotListSequencePanel({
    super.key,
    required this.sequences,
    required this.totalShotCount,
    required this.selectedSequenceId,
    required this.selectedShotId,
    required this.onSequenceSelected,
    required this.onShotSelected,
    required this.onShotCreated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(tr.shotListSequencesPanelTitle, style: theme.textTheme.titleSmall),
              ),
              Text(
                tr.shotListShotsCount(totalShotCount),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sequences.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr.shotListSequencesEmptyHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: sequences.length,
                  itemBuilder: (context, index) => _SequenceEntry(
                    sequence: sequences[index],
                    isSelected: sequences[index].id == selectedSequenceId,
                    selectedShotId: selectedShotId,
                    onSelected: () => onSequenceSelected(sequences[index].id),
                    onShotSelected: onShotSelected,
                  ),
                ),
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.all(10),
          child: FilledButton(onPressed: onShotCreated, child: Text(tr.shotListAddShotAction)),
        ),
      ],
    );
  }
}

/// One sequence of the tree: its own clickable row, followed by its shots while it is selected.
class _SequenceEntry extends StatelessWidget {
  /// The sequence this entry shows.
  final OcptShotSequence sequence;

  /// Whether this sequence is the selected (and therefore expanded) one.
  final bool isSelected;

  /// The id of the selected shot, or null if none is.
  final String? selectedShotId;

  /// Called when the sequence's own row is clicked.
  final VoidCallback onSelected;

  /// Called with a shot's id when one of this sequence's shot rows is clicked.
  final ValueChanged<String> onShotSelected;

  /// Class constructor
  const _SequenceEntry({
    required this.sequence,
    required this.isSelected,
    required this.selectedShotId,
    required this.onSelected,
    required this.onShotSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final sequence = this.sequence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onSelected,
          child: ColoredBox(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      switch (sequence) {
                        OcptSceneShotSequence() => sequence.displaySceneNumber,
                        OcptOrphanShotSequence() => ocptShotListEmptyValue,
                      },
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (sequence) {
                            OcptSceneShotSequence() => sequence.heading,
                            OcptOrphanShotSequence() => tr.shotListOrphanSequenceTitle,
                          },
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${tr.shotListShotsCount(sequence.shotCount)} · "
                          "${tr.shotListAverageDifficulty(
                            ocptFormatShotDifficulty(context, sequence.averageDifficulty),
                          )}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isSelected)
          for (final shot in sequence.shots)
            _ShotEntry(
              shot: shot,
              isSelected: shot.id == selectedShotId,
              onTap: () => onShotSelected(shot.id),
            ),
      ],
    );
  }
}

/// One shot row of an expanded sequence: its code, a ⚠ when it needs checking, its shot size and
/// a status dot.
class _ShotEntry extends StatelessWidget {
  /// The shot this row shows.
  final OcptShot shot;

  /// Whether this shot is the selected one.
  final bool isSelected;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _ShotEntry({required this.shot, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(34, 6, 16, 6),
          child: Row(
            children: [
              Text(
                shot.code,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFamily: ocptMonospaceFontFamily,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (shot.needsCheck)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Tooltip(
                    message: tr.shotListNeedsCheckTooltip,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: ocptShotListWarningColor(context),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ocptShotFieldOrDash(shot.shotSize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ocptShotStatusColor(context, shot.status),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
