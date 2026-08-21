// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_block_candidate.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// One block of a shooting day's timetable, in `sortKey` order. **This is the heart of the schedule
/// mode.**
///
/// [shotId] is non-null **iff** [kind] is [OcptShootingBlockKind.shot], and [candidates] is only
/// ever non-empty on [OcptShootingBlockKind.audition] — the candidacies this block sees, each
/// somebody read for a part. [slotId] is never null: a
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

  /// The scene a [OcptShootingBlockKind.hold] block reserves time for, or a
  /// [OcptShootingBlockKind.rehearsal] block works, or null — either because this block is of
  /// another kind, or because the sequence hasn't been settled yet. It is what says which roles a
  /// held or rehearsed sequence calls for, `label` being free text that answers nobody.
  final String? sceneId;

  /// The candidacies this [OcptShootingBlockKind.audition] block sees, in `sortKey` order — empty
  /// on every other kind, and on an audition nobody has been named on yet, which is an ordinary
  /// state exactly as a hold with no sequence is.
  ///
  /// **Several at once is the point**: two actors of two different parts are regularly read
  /// together. Read defensively: a candidacy removed under one of these rows drops out at display
  /// time rather than being cascaded away — see `OcptShootingBlockCandidatesTable`.
  final List<OcptShootingBlockCandidate> candidates;

  /// The wording of a non-shot block — a caption typed onto it, never what names which sequence a
  /// [OcptShootingBlockKind.hold] reserves: that is [sceneId]'s own job, since free text answers
  /// nobody. Free text, empty for a shot block.
  final String label;

  /// This block's own duration in minutes, or null. For a shot block, null means "use that shot's
  /// `estimatedDurationMs`"; for any other kind, null falls back to the mode's own default.
  final int? durationMinutes;

  /// The minute, from the day's own midnight, this block is pinned to start at exactly, or null
  /// while it simply follows the block before it. May exceed 1440.
  final int? anchorMinute;

  /// Free-form notes about this block. **Private, and never printed.** See [crewNote] for the
  /// sibling that does.
  final String notes;

  /// What this block's own row says to the crew when it prints. **Printed**, under the block's own
  /// row on the call sheet and in the shooting plan's day agenda — the sibling of
  /// `shooting_days.crewNote`, one block narrower.
  final String crewNote;

  /// Class constructor
  const OcptShootingDayBlock({
    required this.id,
    required this.shootingDayId,
    required this.slotId,
    required this.kind,
    required this.shotId,
    required this.sceneId,
    required this.candidates,
    required this.label,
    required this.durationMinutes,
    required this.anchorMinute,
    required this.notes,
    required this.crewNote,
  });

  /// Builds an [OcptShootingDayBlock] from its stored [row] and the live [candidates] it sees.
  factory OcptShootingDayBlock.fromRow({
    required OcptShootingDayBlockRow row,
    required List<OcptShootingBlockCandidate> candidates,
  }) => OcptShootingDayBlock(
    id: row.id,
    shootingDayId: row.shootingDayId,
    slotId: row.slotId,
    kind: row.kind,
    shotId: row.shotId,
    sceneId: row.sceneId,
    candidates: candidates,
    label: row.label,
    durationMinutes: row.durationMinutes,
    anchorMinute: row.anchorMinute,
    notes: row.notes,
    crewNote: row.crewNote,
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
    candidates,
    label,
    durationMinutes,
    anchorMinute,
    notes,
    crewNote,
  ];
}
