// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// How many minutes each `±` tap changes a block's own duration by.
const int _ocptTimetableDurationStep = 5;

/// The day's own timetable: the chained blocks in order, each with its computed start time
/// (ADR 0015), its title, its duration and the controls `docs/plans/schedule-mode.md` §8 and
/// Benoit's own M1 decision #2 ask for — `±` duration, drag-to-reorder, the anchor pin, a shot
/// block's own status control, and a delete/add-block pair (`design.html` lines 311-335).
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed: [onReordered], [onDurationChanged], [onAnchorToggled], [onShotStatusChanged],
/// [onDeletionRequested] and [onBlockAdded]. Selecting a row ([onBlockSelected]) only ever reads,
/// so it is never withheld.
class OcptScheduleTimetable extends StatelessWidget {
  /// The day's own live blocks, in `sortKey` order.
  final List<OcptShootingDayBlock> blocks;

  /// The day's own computed timetable, or null while it has nothing placed yet.
  final OcptShootingDayTimeline? timeline;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// The id of the currently selected block, or null while none is.
  final String? selectedBlockId;

  /// Called with a block's id when its row is clicked.
  final ValueChanged<String> onBlockSelected;

  /// Called with a block's id and its 0-based new position once a drag-to-reorder gesture ends, or
  /// null while withheld (which also turns the list back into a plain, undraggable one).
  final void Function(String blockId, int newPosition)? onReordered;

  /// Called with a block's id and its own new duration once a `±` control is tapped, or null while
  /// withheld.
  final void Function(String blockId, int durationMinutes)? onDurationChanged;

  /// Called with a block's id and its own new anchor once the pin is toggled, or null while
  /// withheld.
  final void Function(String blockId, int? anchorMinute)? onAnchorToggled;

  /// Called with a shot block's own shot id and the status just picked, or null while withheld.
  final void Function(String shotId, OcptShotStatus status)? onShotStatusChanged;

  /// Called with a block's id when its own remove control is clicked, or null while withheld.
  final ValueChanged<String>? onDeletionRequested;

  /// Called with the kind just picked from the `+ Block` menu, or null while withheld (which also
  /// hides the menu). Never called with [OcptShootingBlockKind.shot] — a shot is placed through the
  /// left dock's own *placing* gesture.
  final ValueChanged<OcptShootingBlockKind>? onBlockAdded;

  /// Class constructor
  const OcptScheduleTimetable({
    super.key,
    required this.blocks,
    required this.timeline,
    required this.shotOf,
    required this.selectedBlockId,
    required this.onBlockSelected,
    required this.onReordered,
    required this.onDurationChanged,
    required this.onAnchorToggled,
    required this.onShotStatusChanged,
    required this.onDeletionRequested,
    required this.onBlockAdded,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final entryByBlockId = {
      for (final entry in timeline?.entries ?? const <OcptShootingTimelineEntry>[]) entry.blockId: entry,
    };
    final overrunBlockIds = {
      for (final overrun in timeline?.overruns ?? const <OcptTimelineOverrun>[]) overrun.blockId,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              tr.scheduleTimetableEmptyHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else if (onReordered == null)
          Column(
            children: [
              for (final block in blocks)
                _buildRow(context, block, entryByBlockId[block.id], overrunBlockIds.contains(block.id)),
            ],
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) => onReordered!(blocks[oldIndex].id, newIndex),
            children: [
              for (var index = 0; index < blocks.length; index++)
                _buildRow(
                  context,
                  blocks[index],
                  entryByBlockId[blocks[index].id],
                  overrunBlockIds.contains(blocks[index].id),
                  reorderIndex: index,
                ),
            ],
          ),
        if (onBlockAdded != null) ...[
          const SizedBox(height: 6),
          PopupMenuButton<OcptShootingBlockKind>(
            tooltip: "",
            onSelected: onBlockAdded,
            itemBuilder: (context) => [
              for (final kind in OcptShootingBlockKind.values)
                if (kind != OcptShootingBlockKind.shot)
                  PopupMenuItem<OcptShootingBlockKind>(
                    value: kind,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ocptShootingBlockKindIcon(kind), size: 16),
                        const SizedBox(width: 8),
                        Text(ocptShootingBlockKindLabel(tr, kind)),
                      ],
                    ),
                  ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(ocptRadiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 14),
                  const SizedBox(width: 4),
                  Text(tr.scheduleAddBlockAction, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// One row of the timetable — a [_OcptScheduleTimetableRow] carrying a `Key`, required whether it
  /// sits in a plain [Column] or a [ReorderableListView].
  Widget _buildRow(
    BuildContext context,
    OcptShootingDayBlock block,
    OcptShootingTimelineEntry? entry,
    bool isOverrun, {
    int? reorderIndex,
  }) => _OcptScheduleTimetableRow(
    key: ValueKey(block.id),
    block: block,
    entry: entry,
    isOverrun: isOverrun,
    shot: block.kind == OcptShootingBlockKind.shot && block.shotId != null ? shotOf(block.shotId!) : null,
    isSelected: block.id == selectedBlockId,
    reorderIndex: reorderIndex,
    onSelected: () => onBlockSelected(block.id),
    onDurationChanged: onDurationChanged == null
        ? null
        : (durationMinutes) => onDurationChanged!(block.id, durationMinutes),
    onAnchorToggled: onAnchorToggled == null
        ? null
        : (anchorMinute) => onAnchorToggled!(block.id, anchorMinute),
    onShotStatusChanged: onShotStatusChanged == null || block.shotId == null
        ? null
        : (status) => onShotStatusChanged!(block.shotId!, status),
    onDeletionRequested: onDeletionRequested == null ? null : () => onDeletionRequested!(block.id),
  );
}

/// One block's own row of the timetable.
class _OcptScheduleTimetableRow extends StatelessWidget {
  /// The block this row shows.
  final OcptShootingDayBlock block;

  /// This block's own computed timeline entry, or null while the day has no timeline yet.
  final OcptShootingTimelineEntry? entry;

  /// Whether this block's own pinned anchor could not be honoured (ADR 0015 rule 4).
  final bool isOverrun;

  /// The shot [block] places, when [block]'s own kind is [OcptShootingBlockKind.shot].
  final OcptShot? shot;

  /// Whether this is the currently selected block.
  final bool isSelected;

  /// This row's own index, when it sits inside a [ReorderableListView] (`onReordered` is not
  /// withheld) — [ReorderableListView] requires every child to carry one.
  final int? reorderIndex;

  /// Called when this row is clicked.
  final VoidCallback onSelected;

  /// Called with the new duration once a `±` control is tapped, or null while withheld (which also
  /// hides the controls).
  final ValueChanged<int>? onDurationChanged;

  /// Called with the new anchor once the pin is toggled, or null while withheld (which also hides
  /// the pin).
  final ValueChanged<int?>? onAnchorToggled;

  /// Called with the status just picked, or null while withheld or this isn't a shot block.
  final ValueChanged<OcptShotStatus>? onShotStatusChanged;

  /// Called when this row's own remove control is clicked, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptScheduleTimetableRow({
    super.key,
    required this.block,
    required this.entry,
    required this.isOverrun,
    required this.shot,
    required this.isSelected,
    required this.reorderIndex,
    required this.onSelected,
    required this.onDurationChanged,
    required this.onAnchorToggled,
    required this.onShotStatusChanged,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final entry = this.entry;
    final isShot = block.kind == OcptShootingBlockKind.shot;
    final shot = this.shot;
    final timeColor = isOverrun ? theme.colorScheme.error : theme.colorScheme.onSurface;
    final title = isShot
        ? (shot == null ? "" : "${shot.code} · ${shot.shotSize}")
        : (block.label.isEmpty ? ocptShootingBlockKindLabel(tr, block.kind) : block.label);

    final content = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onSelected,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                : theme.colorScheme.surfaceContainer,
            border: Border.all(
              color: isOverrun
                  ? theme.colorScheme.error
                  : (isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
            ),
            borderRadius: BorderRadius.circular(ocptRadiusMedium),
          ),
          child: Row(
            children: [
              if (reorderIndex != null)
                ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.drag_indicator, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              SizedBox(
                width: 92,
                child: Text(
                  entry == null
                      ? "—"
                      : "${ocptFormatDayMinute(entry.startMinute)} → ${ocptFormatDayMinute(entry.endMinute)}",
                  style: theme.textTheme.labelSmall?.copyWith(color: timeColor, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(ocptShootingBlockKindIcon(block.kind), size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (onAnchorToggled != null)
                IconButton(
                  icon: Icon(
                    block.anchorMinute != null ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 15,
                  ),
                  tooltip: tr.scheduleAnchorPinTooltip,
                  visualDensity: VisualDensity.compact,
                  color: block.anchorMinute != null ? theme.colorScheme.primary : null,
                  onPressed: () => onAnchorToggled!(block.anchorMinute != null ? null : entry?.startMinute),
                ),
              if (isShot && shot != null && onShotStatusChanged != null)
                PopupMenuButton<OcptShotStatus>(
                  tooltip: "",
                  onSelected: onShotStatusChanged,
                  itemBuilder: (context) => [
                    for (final status in OcptShotStatus.values)
                      PopupMenuItem<OcptShotStatus>(value: status, child: Text(ocptShotStatusLabel(tr, status))),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ocptShotStatusLabel(tr, shot.status),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ocptShotStatusColor(context, shot.status),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 14),
                    ],
                  ),
                )
              else if (isShot && shot != null)
                Text(
                  ocptShotStatusLabel(tr, shot.status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ocptShotStatusColor(context, shot.status),
                  ),
                ),
              if (onDurationChanged != null && entry != null) ...[
                const SizedBox(width: 4),
                _OcptScheduleDurationStepper(
                  durationMinutes: entry.durationMinutes,
                  onChanged: onDurationChanged!,
                ),
              ] else if (entry != null) ...[
                const SizedBox(width: 4),
                Text(
                  ocptFormatMinuteDuration(entry.durationMinutes),
                  style: theme.textTheme.labelSmall,
                ),
              ],
              if (onDeletionRequested != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 15),
                  tooltip: tr.scheduleRemoveBlockTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDeletionRequested,
                ),
            ],
          ),
        ),
      ),
    );

    return content;
  }
}

/// The `±` duration controls, over the block's own currently resolved duration.
class _OcptScheduleDurationStepper extends StatelessWidget {
  /// The block's own currently resolved duration, in minutes.
  final int durationMinutes;

  /// Called with the new duration once `±` is tapped.
  final ValueChanged<int> onChanged;

  /// Class constructor
  const _OcptScheduleDurationStepper({required this.durationMinutes, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 13),
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(
            (durationMinutes - _ocptTimetableDurationStep).clamp(0, 1440 * 2),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            ocptFormatMinuteDuration(durationMinutes),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 13),
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(durationMinutes + _ocptTimetableDurationStep),
        ),
      ],
    );
  }
}
