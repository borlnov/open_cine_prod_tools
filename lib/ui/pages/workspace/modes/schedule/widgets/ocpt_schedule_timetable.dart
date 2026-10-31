// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_overrun.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_dragged_block.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable_row.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_schedule_labels.dart';

/// One slot's own timetable: its chained blocks in `sortKey` order, each with its computed start
/// time (ADR 0015, as amended), its
/// title, its duration and the controls the mode asks for — `±` duration, drag-to-reorder within
/// the slot, a cross-slot drag (or the
/// row's own `Move to…` menu for the keyboard path), the anchor pin, a shot block's own status
/// control, and a delete/add-block pair (`design.html` lines 311-335).
///
/// Every slot draws its own copy of this widget, over its own [blocks] alone, chained by its own
/// [timeline].
///
/// A **hold** row carries one further control the others don't: a picker naming the sequence it
/// reserves time for ([onHoldSequenceChanged]), writing `shooting_day_blocks.sceneId` — which is
/// what says which roles a held sequence calls for, its free-text label never having been able to.
/// A **rehearsal** row carries the very same picker, naming the sequence being worked: what is
/// rehearsed is a sequence, which is exactly what a hold already names. It offers every one of
/// [sequences] plus a "no sequence yet" entry, [sequences] itself never carrying the shot list's
/// own orphan group: an orphan names no `scenes` row, so `sceneId` could never point at it.
///
/// An **audition** row carries something else again: a strip of **candidacy chips** under it, one
/// per `shooting_block_candidates` row it names — the person and the part they are being seen for —
/// each with its own remove control ([onCandidateRemoved]), and a `+` picker ([onCandidateAdded])
/// offering every candidacy of the project grouped by role, minus the ones this block already
/// names. The block *is* the hour somebody is expected at (ADR 0024), so this is where they are
/// named; several chips on one row is ordinary, two actors of two different parts being regularly
/// read together, and a row naming nobody yet is as ordinary as a hold with no sequence.
///
/// The picker **picks an existing candidacy and never creates one**: a candidate is recorded on the
/// role sheet, where the casting is decided, and a timetable that could invent one would be a
/// second place saying who is seen for a part.
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed: [onReordered], [onDurationChanged], [onAnchorChanged], [onShotStatusChanged],
/// [onHoldSequenceChanged], [onCandidateAdded], [onCandidateRemoved], [onDeletionRequested],
/// [onBlockAdded],
/// [onShotBlockRequested] and
/// [onBlockMovedToSlot] — the last of which also turns every row undraggable and this timetable's
/// own drop area inert, rather than merely disabled. Selecting a row ([onBlockSelected]) only ever
/// reads, so it is never withheld.
class OcptScheduleTimetable extends StatelessWidget {
  /// The id of the slot this timetable belongs to: what a block dropped from another slot's own
  /// timetable lands on, and what a dragged row's own [OcptScheduleDraggedBlock.sourceSlotId] is
  /// compared against to refuse a drop back onto the slot the block already belongs to.
  final String slotId;

  /// This slot's own live blocks, in `sortKey` order.
  final List<OcptShootingDayBlock> blocks;

  /// The whole cast, in its own order — what an **audition** row's own candidacy chips and picker
  /// read a part's name off, and what groups that picker's own entries.
  final List<OcptRole> roles;

  /// Every live candidacy of the project, keyed by id — what an **audition** row's own chips
  /// resolve their `roleCandidateId` through, and what its picker offers. A chip whose candidacy
  /// this map no longer holds is left out: the link points at nobody, and drawing a nameless chip
  /// would be worse than drawing nothing (no cascade removes it — see
  /// `OcptShootingBlockCandidatesTable`).
  final Map<String, OcptRoleCandidate> roleCandidateById;

  /// This slot's own computed timeline, or null while it has nothing placed yet.
  final OcptShootingSlotTimeline? timeline;

  /// Resolves a shot id to the shot it names.
  final OcptShot? Function(String shotId) shotOf;

  /// The id of the currently selected block, or null while none is.
  final String? selectedBlockId;

  /// Every real scene of the screenplay's shot list — what a **hold** row's own sequence picker
  /// offers, alongside the "no sequence yet" entry this widget adds itself. Never carries the
  /// orphan group; see the class doc comment.
  final List<OcptSceneShotSequence> sequences;

  /// The day's own other live slots, by id and by their raw label (substituted for
  /// [Tr.scheduleInspectorUnnamedSlot] by this widget itself when empty, exactly as a slot card's
  /// own header does) — what a row's own `Move to…` menu offers. A block cannot be dragged or moved
  /// anywhere while this is empty: there is nowhere else on this day to send it.
  final List<(String, String)> otherSlots;

  /// Called with a block's id when its row is clicked.
  final ValueChanged<String> onBlockSelected;

  /// Called with a block's id and its 0-based new position once a drag-to-reorder gesture ends
  /// within this slot, or null while withheld (which also turns the list back into a plain,
  /// undraggable one).
  final void Function(String blockId, int newPosition)? onReordered;

  /// Called with a block's id and its own new duration once a `±` control is tapped, or null while
  /// withheld.
  final void Function(String blockId, int durationMinutes)? onDurationChanged;

  /// Called with a block's id and its own new anchor once the pin is toggled, or null while
  /// withheld.
  final void Function(String blockId, int? anchorMinute)? onAnchorChanged;

  /// Called with a shot block's own shot id and the status just picked, or null while withheld.
  final void Function(String shotId, OcptShotStatus status)? onShotStatusChanged;

  /// Called with a **hold** block's id and the scene just picked from its own sequence picker (null
  /// for "no sequence yet"), or null while withheld — which also turns the picker into plain
  /// read-only text.
  final void Function(String blockId, String? sceneId)? onHoldSequenceChanged;

  /// Called with an **audition** block's id and the id of the candidacy just picked from its own
  /// `+` picker, or null while withheld — which also hides that picker.
  final void Function(String blockId, String roleCandidateId)? onCandidateAdded;

  /// Called with a candidacy convocation's own id (`shooting_block_candidates.id`) when its chip's
  /// remove control is clicked, or null while withheld — which also hides every chip's own control.
  final ValueChanged<String>? onCandidateRemoved;

  /// Called with a block's id when its own remove control is clicked, or null while withheld.
  final ValueChanged<String>? onDeletionRequested;

  /// Called with the kind just picked from the `+ Block` menu — the new block lands at the end of
  /// **this** slot's own timetable — or null while withheld (which also hides the menu). Never
  /// called with [OcptShootingBlockKind.shot] — placing a shot goes through [onShotBlockRequested]
  /// instead, which the menu's own `Shot` entry calls.
  final ValueChanged<OcptShootingBlockKind>? onBlockAdded;

  /// Called when the `+ Block` menu's own `Shot` entry is picked — the mode itself opens the shot
  /// picker dialog and, on a pick, dispatches the event that actually creates the block — or null
  /// while withheld, which also hides the entry.
  final VoidCallback? onShotBlockRequested;

  /// Called with a block's id and the id of the slot it is moved to — dispatched either by dropping
  /// a row dragged out of another slot's own timetable onto this one, or by picking an entry of a
  /// row's own `Move to…` menu — or null while withheld, which also makes every row of this
  /// timetable undraggable and its own drop area accept nothing.
  final void Function(String blockId, String targetSlotId)? onBlockMovedToSlot;

  /// Class constructor
  const OcptScheduleTimetable({
    super.key,
    required this.slotId,
    required this.blocks,
    required this.roles,
    required this.roleCandidateById,
    required this.timeline,
    required this.shotOf,
    required this.selectedBlockId,
    required this.sequences,
    required this.otherSlots,
    required this.onBlockSelected,
    required this.onReordered,
    required this.onDurationChanged,
    required this.onAnchorChanged,
    required this.onShotStatusChanged,
    required this.onHoldSequenceChanged,
    required this.onCandidateAdded,
    required this.onCandidateRemoved,
    required this.onDeletionRequested,
    required this.onBlockAdded,
    required this.onShotBlockRequested,
    required this.onBlockMovedToSlot,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final entryByBlockId = {
      for (final entry in timeline?.entries ?? const <OcptShootingTimelineEntry>[])
        entry.blockId: entry,
    };
    final overrunBlockIds = {
      for (final overrun in timeline?.overruns ?? const <OcptTimelineOverrun>[]) overrun.blockId,
    };
    // The `Shot` entry sits first — it is the one a user reaches for most — with a divider setting
    // it apart from the kinds below it, shown only while there is something to separate it from.
    // Every other kind is offered on every day: what a day is for is what its blocks say, so
    // nothing here narrows the list.
    final menuKinds = [
      if (onShotBlockRequested != null) OcptShootingBlockKind.shot,
      if (onBlockAdded != null)
        for (final kind in OcptShootingBlockKind.values)
          if (kind != OcptShootingBlockKind.shot) kind,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OcptScheduleBlocksArea(
          slotId: slotId,
          blocks: blocks,
          roles: roles,
          roleCandidateById: roleCandidateById,
          entryByBlockId: entryByBlockId,
          overrunBlockIds: overrunBlockIds,
          shotOf: shotOf,
          selectedBlockId: selectedBlockId,
          sequences: sequences,
          otherSlots: otherSlots,
          onBlockSelected: onBlockSelected,
          onReordered: onReordered,
          onDurationChanged: onDurationChanged,
          onAnchorChanged: onAnchorChanged,
          onShotStatusChanged: onShotStatusChanged,
          onHoldSequenceChanged: onHoldSequenceChanged,
          onCandidateAdded: onCandidateAdded,
          onCandidateRemoved: onCandidateRemoved,
          onDeletionRequested: onDeletionRequested,
          onBlockMovedToSlot: onBlockMovedToSlot,
        ),
        if (onBlockAdded != null || onShotBlockRequested != null) ...[
          const SizedBox(height: 6),
          PopupMenuButton<OcptShootingBlockKind>(
            tooltip: "",
            onSelected: (kind) => kind == OcptShootingBlockKind.shot
                ? onShotBlockRequested?.call()
                : onBlockAdded?.call(kind),
            itemBuilder: (context) => [
              for (final kind in menuKinds) ...[
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
                if (kind == OcptShootingBlockKind.shot && onBlockAdded != null)
                  const PopupMenuDivider(),
              ],
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
}

/// The blocks list itself (or the empty hint) of an [OcptScheduleTimetable], wrapped in a drop
/// target for a block dragged out of another slot's own timetable. The drop target exists only
/// while [onBlockMovedToSlot] isn't withheld, so a read-only preview accepts nothing here at all —
/// there is no such thing as a [DragTarget] that merely looks disabled.
///
/// Each row is an [OcptScheduleTimetableRow] carrying a `Key`, required whether it sits in a plain
/// [Column] or a [ReorderableListView].
class _OcptScheduleBlocksArea extends StatelessWidget {
  /// See [OcptScheduleTimetable.slotId].
  final String slotId;

  /// See [OcptScheduleTimetable.blocks].
  final List<OcptShootingDayBlock> blocks;

  /// See [OcptScheduleTimetable.roles].
  final List<OcptRole> roles;

  /// See [OcptScheduleTimetable.roleCandidateById].
  final Map<String, OcptRoleCandidate> roleCandidateById;

  /// The slot's own computed timeline entries, by the id of the block each one places.
  final Map<String, OcptShootingTimelineEntry> entryByBlockId;

  /// The ids of the blocks whose pinned anchor could not be honoured.
  final Set<String> overrunBlockIds;

  /// See [OcptScheduleTimetable.shotOf].
  final OcptShot? Function(String shotId) shotOf;

  /// See [OcptScheduleTimetable.selectedBlockId].
  final String? selectedBlockId;

  /// See [OcptScheduleTimetable.sequences].
  final List<OcptSceneShotSequence> sequences;

  /// See [OcptScheduleTimetable.otherSlots].
  final List<(String, String)> otherSlots;

  /// See [OcptScheduleTimetable.onBlockSelected].
  final ValueChanged<String> onBlockSelected;

  /// See [OcptScheduleTimetable.onReordered].
  final void Function(String blockId, int newPosition)? onReordered;

  /// See [OcptScheduleTimetable.onDurationChanged].
  final void Function(String blockId, int durationMinutes)? onDurationChanged;

  /// See [OcptScheduleTimetable.onAnchorChanged].
  final void Function(String blockId, int? anchorMinute)? onAnchorChanged;

  /// See [OcptScheduleTimetable.onShotStatusChanged].
  final void Function(String shotId, OcptShotStatus status)? onShotStatusChanged;

  /// See [OcptScheduleTimetable.onHoldSequenceChanged].
  final void Function(String blockId, String? sceneId)? onHoldSequenceChanged;

  /// See [OcptScheduleTimetable.onCandidateAdded].
  final void Function(String blockId, String roleCandidateId)? onCandidateAdded;

  /// See [OcptScheduleTimetable.onCandidateRemoved].
  final ValueChanged<String>? onCandidateRemoved;

  /// See [OcptScheduleTimetable.onDeletionRequested].
  final ValueChanged<String>? onDeletionRequested;

  /// See [OcptScheduleTimetable.onBlockMovedToSlot].
  final void Function(String blockId, String targetSlotId)? onBlockMovedToSlot;

  /// Class constructor
  const _OcptScheduleBlocksArea({
    required this.slotId,
    required this.blocks,
    required this.roles,
    required this.roleCandidateById,
    required this.entryByBlockId,
    required this.overrunBlockIds,
    required this.shotOf,
    required this.selectedBlockId,
    required this.sequences,
    required this.otherSlots,
    required this.onBlockSelected,
    required this.onReordered,
    required this.onDurationChanged,
    required this.onAnchorChanged,
    required this.onShotStatusChanged,
    required this.onHoldSequenceChanged,
    required this.onCandidateAdded,
    required this.onCandidateRemoved,
    required this.onDeletionRequested,
    required this.onBlockMovedToSlot,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final content = blocks.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              tr.scheduleTimetableEmptyHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : (onReordered == null
              ? Column(
                  children: [
                    for (final block in blocks)
                      _OcptScheduleBlockRow(key: ValueKey(block.id), timetable: this, block: block),
                  ],
                )
              : ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (oldIndex, newIndex) =>
                      onReordered!(blocks[oldIndex].id, newIndex),
                  children: [
                    for (var index = 0; index < blocks.length; index++)
                      _OcptScheduleBlockRow(
                        key: ValueKey(blocks[index].id),
                        timetable: this,
                        block: blocks[index],
                        reorderIndex: index,
                      ),
                  ],
                ));

    final onBlockMovedToSlot = this.onBlockMovedToSlot;
    if (onBlockMovedToSlot == null) {
      return content;
    }

    return DragTarget<OcptScheduleDraggedBlock>(
      onWillAcceptWithDetails: (details) => details.data.sourceSlotId != slotId,
      onAcceptWithDetails: (details) => onBlockMovedToSlot(details.data.blockId, slotId),
      builder: (context, candidateData, rejectedData) {
        final theme = Theme.of(context);
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          // An empty slot's own hint is one short line — without a floor, its drop area would
          // shrink to that line's own height, too thin a target to aim a drag at with any
          // confidence.
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ocptRadiusMedium),
            border: Border.all(
              color: isHovering ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
            color: isHovering
                ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                : null,
          ),
          child: content,
        );
      },
    );
  }
}

/// One row of an [OcptScheduleTimetable] for [block]: its [OcptScheduleTimetableRow], given what
/// the timetable holds for it. The timetable keys it by the block's id, which is what the
/// reorderable list and the row's own state follow.
class _OcptScheduleBlockRow extends StatelessWidget {
  /// The blocks area this row belongs to.
  final _OcptScheduleBlocksArea timetable;

  /// The block this row shows.
  final OcptShootingDayBlock block;

  /// The row's index in the reorderable list, or null while the timetable is not reorderable.
  final int? reorderIndex;

  /// Class constructor
  const _OcptScheduleBlockRow({
    super.key,
    required this.timetable,
    required this.block,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) => OcptScheduleTimetableRow(
    block: block,
    entry: timetable.entryByBlockId[block.id],
    isOverrun: timetable.overrunBlockIds.contains(block.id),
    shot: block.kind == OcptShootingBlockKind.shot && block.shotId != null
        ? timetable.shotOf(block.shotId!)
        : null,
    roles: timetable.roles,
    roleCandidateById: timetable.roleCandidateById,
    isSelected: block.id == timetable.selectedBlockId,
    reorderIndex: reorderIndex,
    sequences: timetable.sequences,
    otherSlots: timetable.otherSlots,
    onSelected: () => timetable.onBlockSelected(block.id),
    onDurationChanged: timetable.onDurationChanged == null
        ? null
        : (durationMinutes) => timetable.onDurationChanged!(block.id, durationMinutes),
    onAnchorChanged: timetable.onAnchorChanged == null
        ? null
        : (anchorMinute) => timetable.onAnchorChanged!(block.id, anchorMinute),
    onShotStatusChanged: timetable.onShotStatusChanged == null || block.shotId == null
        ? null
        : (status) => timetable.onShotStatusChanged!(block.shotId!, status),
    onSequenceChanged: timetable.onHoldSequenceChanged == null
        ? null
        : (sceneId) => timetable.onHoldSequenceChanged!(block.id, sceneId),
    onCandidateAdded: timetable.onCandidateAdded == null
        ? null
        : (roleCandidateId) => timetable.onCandidateAdded!(block.id, roleCandidateId),
    onCandidateRemoved: timetable.onCandidateRemoved,
    onDeletionRequested: timetable.onDeletionRequested == null
        ? null
        : () => timetable.onDeletionRequested!(block.id),
    onMovedToSlot: timetable.onBlockMovedToSlot == null
        ? null
        : (targetSlotId) => timetable.onBlockMovedToSlot!(block.id, targetSlotId),
  );
}
