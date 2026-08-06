// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// How many minutes each `±` tap changes a block's own duration by.
const int _ocptTimetableDurationStep = 5;

/// The value the "no sequence yet" entry of a hold row's own sequence picker menu carries, distinct
/// from every scene id — a [PopupMenuButton] cannot carry a null value for an entry that must still
/// be selectable, the same convention `OcptScheduleSlotCard`'s own `_noLocationOption`/
/// `_noGroupOption` already use.
const String _noSequenceOption = "";

/// The payload a row's own cross-slot drag carries: which block, and the id of the slot it
/// currently belongs to. The second half is what lets a slot card's own [DragTarget] refuse a block
/// dropped back onto its own timetable — that gesture is what in-slot reordering already does, and
/// letting a self-drop through here would fight it rather than merely duplicate it.
class _OcptScheduleDraggedBlock {
  /// Builds a drag payload.
  const _OcptScheduleDraggedBlock({required this.blockId, required this.sourceSlotId});

  /// The id of the block being dragged.
  final String blockId;

  /// The id of the slot the block belongs to at the moment the drag starts.
  final String sourceSlotId;
}

/// One slot's own timetable: its chained blocks in `sortKey` order, each with its computed start
/// time (ADR 0015, amended per `docs/plans/schedule-slots-and-computed-convocations.md`), its
/// title, its duration and the controls `docs/plans/schedule-mode.md` §8 and Benoit's own M1
/// decision #2 ask for — `±` duration, drag-to-reorder within the slot, a cross-slot drag (or the
/// row's own `Move to…` menu for the keyboard path), the anchor pin, a shot block's own status
/// control, and a delete/add-block pair (`design.html` lines 311-335).
///
/// A day used to carry one shared timetable, drawn once beneath every slot card; it no longer does
/// (M2') — every slot now draws its own copy of this widget, over its own [blocks] alone, chained
/// by its own [timeline].
///
/// A **hold** row carries one further control the others don't: a picker naming the sequence it
/// reserves time for ([onHoldSequenceChanged]), writing `shooting_day_blocks.sceneId` — which is
/// what says which roles a held sequence calls for, its free-text label never having been able to.
/// It offers every one of [sequences] plus a "no sequence yet" entry, [sequences] itself never
/// carrying the shot list's own orphan group: an orphan names no `scenes` row, so `sceneId` could
/// never point at it.
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed: [onReordered], [onDurationChanged], [onAnchorChanged], [onShotStatusChanged],
/// [onHoldSequenceChanged], [onDeletionRequested], [onBlockAdded] and [onBlockMovedToSlot] — the
/// last of which also turns every row undraggable and this timetable's own drop area inert, rather
/// than merely disabled. Selecting a row ([onBlockSelected]) only ever reads, so it is never
/// withheld.
class OcptScheduleTimetable extends StatelessWidget {
  /// The id of the slot this timetable belongs to: what a block dropped from another slot's own
  /// timetable lands on, and what a dragged row's own [_OcptScheduleDraggedBlock.sourceSlotId] is
  /// compared against to refuse a drop back onto the slot the block already belongs to.
  final String slotId;

  /// This slot's own live blocks, in `sortKey` order.
  final List<OcptShootingDayBlock> blocks;

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

  /// Called with a block's id when its own remove control is clicked, or null while withheld.
  final ValueChanged<String>? onDeletionRequested;

  /// Called with the kind just picked from the `+ Block` menu — the new block lands at the end of
  /// **this** slot's own timetable — or null while withheld (which also hides the menu). Never
  /// called with [OcptShootingBlockKind.shot] — a shot is placed through the left dock's own
  /// *placing* gesture.
  final ValueChanged<OcptShootingBlockKind>? onBlockAdded;

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
    required this.onDeletionRequested,
    required this.onBlockAdded,
    required this.onBlockMovedToSlot,
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
        _buildBlocksArea(context, tr, entryByBlockId, overrunBlockIds),
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

  /// The blocks list itself (or the empty hint), wrapped in a drop target for a block dragged out of
  /// another slot's own timetable. The drop target exists only while [onBlockMovedToSlot] isn't
  /// withheld, so a read-only preview accepts nothing here at all — there is no such thing as a
  /// [DragTarget] that merely looks disabled.
  Widget _buildBlocksArea(
    BuildContext context,
    Tr tr,
    Map<String, OcptShootingTimelineEntry> entryByBlockId,
    Set<String> overrunBlockIds,
  ) {
    final content = blocks.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              tr.scheduleTimetableEmptyHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        : (onReordered == null
              ? Column(
                  children: [
                    for (final block in blocks)
                      _buildRow(context, block, entryByBlockId[block.id], overrunBlockIds.contains(block.id)),
                  ],
                )
              : ReorderableListView(
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
                ));

    final onBlockMovedToSlot = this.onBlockMovedToSlot;
    if (onBlockMovedToSlot == null) {
      return content;
    }

    return DragTarget<_OcptScheduleDraggedBlock>(
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
            border: Border.all(color: isHovering ? theme.colorScheme.primary : Colors.transparent, width: 2),
            color: isHovering ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha) : null,
          ),
          child: content,
        );
      },
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
    sequences: sequences,
    otherSlots: otherSlots,
    onSelected: () => onBlockSelected(block.id),
    onDurationChanged: onDurationChanged == null
        ? null
        : (durationMinutes) => onDurationChanged!(block.id, durationMinutes),
    onAnchorChanged: onAnchorChanged == null
        ? null
        : (anchorMinute) => onAnchorChanged!(block.id, anchorMinute),
    onShotStatusChanged: onShotStatusChanged == null || block.shotId == null
        ? null
        : (status) => onShotStatusChanged!(block.shotId!, status),
    onSequenceChanged: onHoldSequenceChanged == null
        ? null
        : (sceneId) => onHoldSequenceChanged!(block.id, sceneId),
    onDeletionRequested: onDeletionRequested == null ? null : () => onDeletionRequested!(block.id),
    onMovedToSlot: onBlockMovedToSlot == null
        ? null
        : (targetSlotId) => onBlockMovedToSlot!(block.id, targetSlotId),
  );
}

/// One block's own row of the timetable.
class _OcptScheduleTimetableRow extends StatelessWidget {
  /// The block this row shows.
  final OcptShootingDayBlock block;

  /// This block's own computed timeline entry, or null while the slot has no timeline yet.
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

  /// Every real scene of the screenplay's shot list — see [OcptScheduleTimetable.sequences]. Only
  /// read when [block]'s own kind is [OcptShootingBlockKind.hold].
  final List<OcptSceneShotSequence> sequences;

  /// The day's own other live slots, by id and by raw label — see [OcptScheduleTimetable.otherSlots].
  final List<(String, String)> otherSlots;

  /// Called when this row is clicked.
  final VoidCallback onSelected;

  /// Called with the new duration once a `±` control is tapped, or null while withheld (which also
  /// hides the controls).
  final ValueChanged<int>? onDurationChanged;

  /// Called with the new anchor once the pin is toggled or the pinned minute is retyped, or null
  /// while withheld (which also hides both).
  final ValueChanged<int?>? onAnchorChanged;

  /// Called with the status just picked, or null while withheld or this isn't a shot block.
  final ValueChanged<OcptShotStatus>? onShotStatusChanged;

  /// Called with the scene just picked from this row's own sequence picker (null for "no sequence
  /// yet"), or null while withheld or [block]'s own kind isn't [OcptShootingBlockKind.hold].
  final ValueChanged<String?>? onSequenceChanged;

  /// Called when this row's own remove control is clicked, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Called with the id of the slot picked from this row's own `Move to…` menu, or null while
  /// withheld — which also makes this row undraggable, [otherSlots] having nowhere left to matter.
  final ValueChanged<String>? onMovedToSlot;

  /// Class constructor
  const _OcptScheduleTimetableRow({
    super.key,
    required this.block,
    required this.entry,
    required this.isOverrun,
    required this.shot,
    required this.isSelected,
    required this.reorderIndex,
    required this.sequences,
    required this.otherSlots,
    required this.onSelected,
    required this.onDurationChanged,
    required this.onAnchorChanged,
    required this.onShotStatusChanged,
    required this.onSequenceChanged,
    required this.onDeletionRequested,
    required this.onMovedToSlot,
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
    final canMove = onMovedToSlot != null && otherSlots.isNotEmpty;

    // Everything but the drag handle below: kept as its own widget so it — and only it — can be
    // wrapped in a cross-slot [Draggable] without that drag ever competing with the handle's own
    // [ReorderableDragStartListener] for the same pointer. The two sit on disjoint areas of the
    // row, so the gesture arena never has to arbitrate between them.
    final rowTail = Row(
      children: [
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
        if (block.kind == OcptShootingBlockKind.hold)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildSequencePicker(context, tr, theme),
          ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        // A pinned block's own minute is typed here rather than only captured from the chain:
        // the moments an anchor exists for — a meal break's legal start, a flight, a location
        // lost at dusk (ADR 0015) — are named times, and pinning a block wherever the chain
        // happened to put it could never express one of them.
        if (block.anchorMinute != null && onAnchorChanged != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: OcptScheduleMinuteField(
              minute: block.anchorMinute,
              isClearable: false,
              emptyHint: "—",
              onChanged: onAnchorChanged,
            ),
          ),
        if (onAnchorChanged != null)
          IconButton(
            icon: Icon(
              block.anchorMinute != null ? Icons.push_pin : Icons.push_pin_outlined,
              size: 15,
            ),
            tooltip: tr.scheduleAnchorPinTooltip,
            visualDensity: VisualDensity.compact,
            color: block.anchorMinute != null ? theme.colorScheme.primary : null,
            onPressed: () => onAnchorChanged!(block.anchorMinute != null ? null : entry?.startMinute),
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
        if (canMove) _buildMoveToMenu(context, tr),
        if (onDeletionRequested != null)
          IconButton(
            icon: const Icon(Icons.close, size: 15),
            tooltip: tr.scheduleRemoveBlockTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: onDeletionRequested,
          ),
      ],
    );

    final rowBody = canMove
        ? Draggable<_OcptScheduleDraggedBlock>(
            data: _OcptScheduleDraggedBlock(blockId: block.id, sourceSlotId: block.slotId),
            feedback: _buildDragFeedback(theme, title),
            childWhenDragging: Opacity(opacity: 0.35, child: rowTail),
            child: rowTail,
          )
        : rowTail;

    return Padding(
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
              Expanded(child: rowBody),
            ],
          ),
        ),
      ),
    );
  }

  /// The floating preview shown while this row is being dragged onto another slot's own timetable —
  /// just its own title, since a drop target only cares about which block it received.
  Widget _buildDragFeedback(ThemeData theme, String title) => Material(
    elevation: 3,
    borderRadius: BorderRadius.circular(ocptRadiusMedium),
    color: theme.colorScheme.surfaceContainerHighest,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
    ),
  );

  /// This **hold** row's own sequence picker: [block]'s own `sceneId` read out as
  /// [Tr.scheduleUnplacedSequenceLabel] (the same "SEQ 4A" tag the left dock's own unplaced-shots
  /// list already prints) or [Tr.scheduleHoldSequencePickerNoSequenceOption] while it names none,
  /// opening onto every one of [sequences] plus that same "no sequence" entry when [onSequenceChanged]
  /// is given, or plain read-only text while it is withheld.
  ///
  /// A `sceneId` naming a scene [sequences] no longer carries — deleted from the screenplay since it
  /// was picked — reads the same as "no sequence yet" rather than crashing on a lookup that found
  /// nothing: the picker still lets the user pick a live one in its place.
  Widget _buildSequencePicker(BuildContext context, Tr tr, ThemeData theme) {
    final onSequenceChanged = this.onSequenceChanged;
    final sceneId = block.sceneId;
    OcptSceneShotSequence? currentSequence;
    for (final sequence in sequences) {
      if (sequence.sceneId == sceneId) {
        currentSequence = sequence;
        break;
      }
    }
    final currentLabel = currentSequence == null
        ? tr.scheduleHoldSequencePickerNoSequenceOption
        : tr.scheduleUnplacedSequenceLabel(currentSequence.displaySceneNumber);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    if (onSequenceChanged == null) {
      return Text(currentLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle);
    }

    return PopupMenuButton<String>(
      tooltip: "",
      padding: EdgeInsets.zero,
      onSelected: (value) => onSequenceChanged(value == _noSequenceOption ? null : value),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: _noSequenceOption,
          child: Text(tr.scheduleHoldSequencePickerNoSequenceOption),
        ),
        const PopupMenuDivider(),
        for (final sequence in sequences)
          PopupMenuItem<String>(
            value: sequence.sceneId,
            child: Text(
              "${tr.scheduleUnplacedSequenceLabel(sequence.displaySceneNumber)} · ${sequence.heading}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(currentLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
          Icon(Icons.arrow_drop_down, size: 14, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  /// This row's own `Move to…` menu — every one of [otherSlots], by label (an empty one read out as
  /// [Tr.scheduleInspectorUnnamedSlot]) — the keyboard/no-pointer path onto [onMovedToSlot], beside
  /// the row's own cross-slot drag.
  Widget _buildMoveToMenu(BuildContext context, Tr tr) => PopupMenuButton<String>(
    tooltip: tr.scheduleMoveBlockTooltip,
    icon: const Icon(Icons.drive_file_move_outline, size: 15),
    padding: EdgeInsets.zero,
    onSelected: onMovedToSlot,
    itemBuilder: (context) => [
      PopupMenuItem<String>(enabled: false, child: Text(tr.scheduleMoveBlockMenuTitle)),
      for (final (id, label) in otherSlots)
        PopupMenuItem<String>(value: id, child: Text(label.isEmpty ? tr.scheduleInspectorUnnamedSlot : label)),
    ],
  );
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
