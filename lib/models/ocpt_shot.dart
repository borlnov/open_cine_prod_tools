// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// A single shot of a shot list, joined with its characters and coverage ranges, plus the two
/// values every view of the shot list needs and neither one is stored in `shots` directly.
///
/// [code] is the shot's `<scene number>/<rank>` display code, derived at read time from the
/// sequence's resolved scene number and this shot's 1-based rank within it ([position] + 1): it is
/// never stored, so it is always in step with the scene index and with insertions/deletions/
/// reorders. [averageDifficulty] is the mean of the four difficulty axes. Both are computed once,
/// by [OcptShot.fromRow], rather than recomputed by every reader.
///
/// [position] is likewise a read-time rank, not the `shots.position` column of the same name: that
/// column stopped being renumbered when `sortKey` took over the ordering
/// (`docs/adr/0010-sync-ready-data-model-prerequisites.md`), so the only rank that is true of the
/// shot list as it displays is the one the loading service counted off while ordering the group.
class OcptShot extends Equatable {
  /// The stable, unique id of this shot (a UUID).
  final String id;

  /// The screenplay this shot belongs to.
  final String screenplayId;

  /// The scene this shot belongs to, or null if it is orphaned (see [orphanedHeading]).
  final String? sceneId;

  /// The heading the scene had at the moment it was deleted, or null while [sceneId] is set.
  final String? orphanedHeading;

  /// The 0-based rank of this shot within its scene (or, once orphaned, within the orphan group),
  /// as its group's `sortKey` order counts it off. See the class doc comment.
  final int position;

  /// The shot size ("valeur de plan"), free text.
  final String shotSize;

  /// The short abbreviation of [shotSize] (`PM`, `GP`), free text, empty until deduced or typed.
  final String abbreviation;

  /// The framing and composition ("angle et composition du cadre"), free text.
  final String framing;

  /// The camera move ("mouvement d'appareil"), free text.
  final String cameraMove;

  /// The lens/focal length ("focale / objectif"), free text.
  final String lens;

  /// The recording format/frame rate (e.g. `4K · 25 fps`), free text.
  final String recordingFormat;

  /// The estimated duration of the shot, in milliseconds, rendered `m:ss`; null until estimated.
  final int? estimatedDurationMs;

  /// **Blank and unread from schema version 11 on** — see `shots.shootingDay`'s own doc comment
  /// (`OcptShotsTable`). The shot's placement in the schedule is read out of
  /// `OcptShotListSnapshot.placementsByShotId` instead; this field is kept only because the column
  /// behind it can't be dropped.
  final String? shootingDay;

  /// The number of takes planned for this shot; null until planned.
  final int? plannedTakes;

  /// Sound notes for this shot, free text.
  final String sound;

  /// The shooting status of this shot.
  final OcptShotStatus status;

  /// The difficulty of the set/location, on a 0-5 scale.
  final int difficultySet;

  /// The difficulty of the camera move, on a 0-5 scale.
  final int difficultyCamera;

  /// The difficulty of the acting, on a 0-5 scale.
  final int difficultyActing;

  /// The difficulty of the sound recording, on a 0-5 scale.
  final int difficultySound;

  /// The director's notes for this shot, free multi-line text.
  final String notes;

  /// Location scouting notes for this shot, free multi-line text.
  final String locationNotes;

  /// Whether this shot needs checking by a human before it can be trusted (see [checkReason]).
  final bool needsCheck;

  /// Why [needsCheck] is set, or null while it is false.
  final OcptShotCheckReason? checkReason;

  /// The characters attached to this shot, in display order, normalised through `fountain_kit`'s
  /// `normalizeCharacterName`.
  final List<String> characters;

  /// The scenario coverage ranges this shot has recorded.
  final List<OcptShotCoverageRange> coverageRanges;

  /// The shot's derived `<scene number>/<rank>` display code. See the class doc comment.
  final String code;

  /// The mean of [difficultySet], [difficultyCamera], [difficultyActing] and [difficultySound].
  final double averageDifficulty;

  /// Class constructor
  const OcptShot({
    required this.id,
    required this.screenplayId,
    required this.sceneId,
    required this.orphanedHeading,
    required this.position,
    required this.shotSize,
    required this.abbreviation,
    required this.framing,
    required this.cameraMove,
    required this.lens,
    required this.recordingFormat,
    required this.estimatedDurationMs,
    required this.shootingDay,
    required this.plannedTakes,
    required this.sound,
    required this.status,
    required this.difficultySet,
    required this.difficultyCamera,
    required this.difficultyActing,
    required this.difficultySound,
    required this.notes,
    required this.locationNotes,
    required this.needsCheck,
    required this.checkReason,
    required this.characters,
    required this.coverageRanges,
    required this.code,
    required this.averageDifficulty,
  });

  /// Builds an [OcptShot] from its stored [row], its 0-based [position] within its group, its
  /// attached [characters] (already in display order) and [coverageRanges], deriving [code] from
  /// [sceneDisplayNumber] (the sequence's explicit scene number, or its 1-based index among the
  /// screenplay's scenes when it has none) and [position] + 1, and [averageDifficulty] from the
  /// four difficulty columns of [row].
  ///
  /// [position] is passed in rather than read off [row]: see the class doc comment.
  factory OcptShot.fromRow({
    required OcptShotRow row,
    required int position,
    required String sceneDisplayNumber,
    required List<String> characters,
    required List<OcptShotCoverageRange> coverageRanges,
  }) => OcptShot(
    id: row.id,
    screenplayId: row.screenplayId,
    sceneId: row.sceneId,
    orphanedHeading: row.orphanedHeading,
    position: position,
    shotSize: row.shotSize,
    abbreviation: row.abbreviation,
    framing: row.framing,
    cameraMove: row.cameraMove,
    lens: row.lens,
    recordingFormat: row.recordingFormat,
    estimatedDurationMs: row.estimatedDurationMs,
    shootingDay: row.shootingDay,
    plannedTakes: row.plannedTakes,
    sound: row.sound,
    status: row.status,
    difficultySet: row.difficultySet,
    difficultyCamera: row.difficultyCamera,
    difficultyActing: row.difficultyActing,
    difficultySound: row.difficultySound,
    notes: row.notes,
    locationNotes: row.locationNotes,
    needsCheck: row.needsCheck,
    checkReason: row.checkReason,
    characters: characters,
    coverageRanges: coverageRanges,
    code: "$sceneDisplayNumber/${position + 1}",
    averageDifficulty:
        (row.difficultySet + row.difficultyCamera + row.difficultyActing + row.difficultySound) / 4,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShot(id: $id, code: $code)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    screenplayId,
    sceneId,
    orphanedHeading,
    position,
    shotSize,
    abbreviation,
    framing,
    cameraMove,
    lens,
    recordingFormat,
    estimatedDurationMs,
    shootingDay,
    plannedTakes,
    sound,
    status,
    difficultySet,
    difficultyCamera,
    difficultyActing,
    difficultySound,
    notes,
    locationNotes,
    needsCheck,
    checkReason,
    characters,
    coverageRanges,
    code,
    averageDifficulty,
  ];
}
