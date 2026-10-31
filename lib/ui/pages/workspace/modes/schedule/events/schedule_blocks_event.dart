// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/events/schedule_base_event.dart';

/// The events about a slot's blocks and the shots they place.
sealed class OcptScheduleBlocksEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleBlocksEvent();
}

/// Names candidacy [roleCandidateId] on **audition** block [blockId], dispatched by that row's own
/// `+` picker — the one convocation in this app read off a block rather than off a slot (ADR 0024),
/// because a candidate is expected at twenty past ten rather than "on the unit today".
///
/// It names a **candidacy**, never a person: the convocation is about somebody being seen *for a
/// part*, and one person read for two parts on one day is two convocations. Several on one block is
/// ordinary — two actors of two different parts read together.
class OcptScheduleBlockCandidateAddedEvent extends OcptScheduleBlocksEvent {
  /// The id of the audition block the candidate is seen at.
  final String blockId;

  /// The id of the candidacy named — who, for which part.
  final String roleCandidateId;

  /// Class constructor
  const OcptScheduleBlockCandidateAddedEvent({
    required this.blockId,
    required this.roleCandidateId,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, roleCandidateId];
}

/// Removes candidate convocation [blockCandidateId] for good, dispatched by its own chip's remove
/// control.
///
/// **Touches neither the block nor the candidacy**: the audition stays exactly where it is and the
/// `role_candidates` row outlives it — see `OcptScheduleService.removeBlockCandidate`.
class OcptScheduleBlockCandidateRemovedEvent extends OcptScheduleBlocksEvent {
  /// The id of the candidate convocation to remove.
  final String blockCandidateId;

  /// Class constructor
  const OcptScheduleBlockCandidateRemovedEvent({required this.blockCandidateId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockCandidateId];
}

/// Writes a new shooting status onto shot [shotId] immediately — the very column the shot list
/// mode's own inspector edits (`OcptShotListService.updateShot`'s `status`) — dispatched by that
/// shot's own block row's status control, in whichever slot card places it.
class OcptScheduleShotStatusChangedEvent extends OcptScheduleBlocksEvent {
  /// The id of the shot whose status changed.
  final String shotId;

  /// The status just picked.
  final OcptShotStatus status;

  /// Class constructor
  const OcptScheduleShotStatusChangedEvent({required this.shotId, required this.status});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shotId, status];
}

/// Creates a new non-shot block (a milestone or a `hold`) inside slot [slotId], appended at the end
/// of that slot's own timetable, dispatched by that slot card's own `+ Block` control — the gesture
/// names the slot it sits on directly.
class OcptScheduleBlockCreatedEvent extends OcptScheduleBlocksEvent {
  /// The id of the slot the new block belongs to.
  final String slotId;

  /// The kind of block to create. Never [OcptShootingBlockKind.shot] — placing a shot goes through
  /// [OcptScheduleShotBlockCreatedEvent] instead, which is what carries its own `shotId`.
  final OcptShootingBlockKind kind;

  /// Class constructor
  const OcptScheduleBlockCreatedEvent({required this.slotId, required this.kind});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, kind];
}

/// Creates a new **shot** block inside slot [slotId], appended at the end of that slot's own
/// timetable, dispatched once the mode's own shot picker dialog — opened by that slot card's own
/// `+ Block` menu's `Shot` entry — resolves to a pick.
///
/// A **second event** rather than a `shotId` added to [OcptScheduleBlockCreatedEvent]: that event's
/// own [OcptScheduleBlockCreatedEvent.kind] can never be [OcptShootingBlockKind.shot] (see its own
/// doc comment), and giving it an optional `shotId` field that only ever accompanies that one kind
/// would let a caller build an event naming a kind and a shot id that disagree with each other — a
/// shape this event rules out by construction rather than one a handler would have to reject.
/// `OcptScheduleService.placeShot` always creates, never moves: a shot may legitimately be placed
/// more than once (interrupted by the meal break and resumed after it).
class OcptScheduleShotBlockCreatedEvent extends OcptScheduleBlocksEvent {
  /// The id of the slot the new block belongs to.
  final String slotId;

  /// The id of the shot being placed.
  final String shotId;

  /// Class constructor
  const OcptScheduleShotBlockCreatedEvent({required this.slotId, required this.shotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, slotId, shotId];
}

/// Writes a new duration onto block [blockId] immediately, dispatched by its own slot card's own ±
/// duration controls.
class OcptScheduleBlockDurationChangedEvent extends OcptScheduleBlocksEvent {
  /// The id of the block being edited.
  final String blockId;

  /// The block's own new duration, in minutes, or null to fall back to a shot's own estimate (or
  /// the mode's own default).
  final int? durationMinutes;

  /// Class constructor
  const OcptScheduleBlockDurationChangedEvent({
    required this.blockId,
    required this.durationMinutes,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, durationMinutes];
}

/// Writes a new anchor onto block [blockId] immediately, dispatched by its own slot card's own
/// anchor pin.
class OcptScheduleBlockAnchorChangedEvent extends OcptScheduleBlocksEvent {
  /// The id of the block being edited.
  final String blockId;

  /// The minute, from the day's own midnight, the block is now pinned to, or null to unpin it.
  final int? anchorMinute;

  /// Class constructor
  const OcptScheduleBlockAnchorChangedEvent({required this.blockId, required this.anchorMinute});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, anchorMinute];
}

/// Writes a new sequence onto **hold** block [blockId] immediately, dispatched by its own timetable
/// row's sequence picker — the control that finally fills `shooting_day_blocks.sceneId`, which says
/// which roles a held sequence calls for (its free-text label never could).
class OcptScheduleBlockSequenceChangedEvent extends OcptScheduleBlocksEvent {
  /// The id of the hold block being edited.
  final String blockId;

  /// The id of the scene just picked, or null to clear it back to "no sequence yet".
  final String? sceneId;

  /// Class constructor
  const OcptScheduleBlockSequenceChangedEvent({required this.blockId, required this.sceneId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, sceneId];
}

/// Moves block [blockId] to [newPosition] (0-based) within its own slot's timetable, dispatched by
/// a drag-to-reorder gesture on that slot card's own timetable. The block's own slot is read off
/// its own row (`OcptScheduleService.reorderBlock`), so no slot or day id travels with this event.
class OcptScheduleBlockReorderedEvent extends OcptScheduleBlocksEvent {
  /// The id of the block to reorder.
  final String blockId;

  /// The 0-based position the block is moved to.
  final int newPosition;

  /// Class constructor
  const OcptScheduleBlockReorderedEvent({required this.blockId, required this.newPosition});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, newPosition];
}

/// Moves block [blockId] to slot [targetSlotId], appended at the end of that slot's own timetable,
/// dispatched either by dragging a row out of one slot card's own timetable onto another's, or by
/// picking an entry of the block's own `Move to…` menu.
class OcptScheduleBlockMovedToSlotEvent extends OcptScheduleBlocksEvent {
  /// The id of the block to move.
  final String blockId;

  /// The id of the slot it is moved to.
  final String targetSlotId;

  /// Class constructor
  const OcptScheduleBlockMovedToSlotEvent({required this.blockId, required this.targetSlotId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId, targetSlotId];
}

/// Deletes block [blockId] for good, whatever its kind, dispatched by the mode once its
/// `OcptConfirmDialog` has already been answered.
class OcptScheduleBlockDeletionConfirmedEvent extends OcptScheduleBlocksEvent {
  /// The id of the block to delete.
  final String blockId;

  /// Class constructor
  const OcptScheduleBlockDeletionConfirmedEvent({required this.blockId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, blockId];
}
