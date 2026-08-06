// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// One block of a shooting day's timetable, in `sortKey` order. **This is the heart of the schedule
/// mode.**
///
/// [shotId] is non-null **iff** [kind] is [OcptShootingBlockKind.shot]. [slotId] is never null: a
/// block belongs to exactly one slot, and its own chain of blocks is that slot's own. How a slot's
/// blocks chain into actual clock times is stated once and implemented once, in
/// `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015, amended) — nothing here re-derives it,
/// this model only carries the columns that function reads.
class OcptShootingDayBlock extends Equatable {
  /// The stable, unique id of this block (a UUID).
  final String id;

  /// The day this block belongs to.
  final String shootingDayId;

  /// Which convocation window this block sits in. Never null — see the class doc comment.
  final String slotId;

  /// What this block is for.
  final OcptShootingBlockKind kind;

  /// The shot this block places, non-null iff [kind] is [OcptShootingBlockKind.shot].
  final String? shotId;

  /// The scene a [OcptShootingBlockKind.hold] block reserves time for, or null — either because
  /// this block is of another kind, or because the sequence hasn't been settled yet. It is what
  /// says which roles a held sequence calls for, `label` being free text that answers nobody.
  final String? sceneId;

  /// The wording of a non-shot block; for [OcptShootingBlockKind.hold], what sequence is being
  /// reserved time for. Free text, empty for a shot block.
  final String label;

  /// This block's own duration in minutes, or null. For a shot block, null means "use that shot's
  /// `estimatedDurationMs`"; for any other kind, null falls back to the mode's own default.
  final int? durationMinutes;

  /// The minute, from the day's own midnight, this block is pinned to start at exactly, or null
  /// while it simply follows the block before it. May exceed 1440.
  final int? anchorMinute;

  /// Free-form notes about this block.
  final String notes;

  /// Class constructor
  const OcptShootingDayBlock({
    required this.id,
    required this.shootingDayId,
    required this.slotId,
    required this.kind,
    required this.shotId,
    required this.sceneId,
    required this.label,
    required this.durationMinutes,
    required this.anchorMinute,
    required this.notes,
  });

  /// Builds an [OcptShootingDayBlock] from its stored [row].
  factory OcptShootingDayBlock.fromRow(OcptShootingDayBlockRow row) => OcptShootingDayBlock(
    id: row.id,
    shootingDayId: row.shootingDayId,
    slotId: row.slotId,
    kind: row.kind,
    shotId: row.shotId,
    sceneId: row.sceneId,
    label: row.label,
    durationMinutes: row.durationMinutes,
    anchorMinute: row.anchorMinute,
    notes: row.notes,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingDayBlock(id: $id, shootingDayId: $shootingDayId, kind: $kind)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    shootingDayId,
    slotId,
    kind,
    shotId,
    sceneId,
    label,
    durationMinutes,
    anchorMinute,
    notes,
  ];
}
