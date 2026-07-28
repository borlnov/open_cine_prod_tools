// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// A sequence of the shot list, together with its ordered shots and the aggregates the left dock
/// and the centre table show for it.
///
/// A sequence is either [OcptSceneShotSequence] (a real screenplay scene — a sequence is strictly
/// a scene, never a free-standing row of its own) or the single
/// [OcptOrphanShotSequence] appended after every real one, holding every shot whose scene was
/// deleted from the screenplay. Modelling the two as separate subclasses, rather than giving this
/// class a nullable `sceneId` no caller could document on sight, makes it impossible to build an
/// orphan group that also claims a heading/scene number it doesn't have.
sealed class OcptShotSequence extends Equatable {
  /// This sequence's shots, in display order.
  final List<OcptShot> shots;

  /// Class constructor
  const OcptShotSequence({required this.shots});

  /// The number of shots in this sequence.
  int get shotCount => shots.length;

  /// The mean [OcptShot.averageDifficulty] across this sequence's shots, or 0 if it has none.
  double get averageDifficulty {
    if (shots.isEmpty) {
      return 0;
    }
    return shots.map((shot) => shot.averageDifficulty).reduce((a, b) => a + b) / shots.length;
  }

  /// The number of shots in this sequence not yet marked [OcptShotStatus.shot] (a shot still
  /// [OcptShotStatus.toShoot] or awaiting an [OcptShotStatus.retake] both still need shooting).
  int get shotsLeftToShoot => shots.where((shot) => shot.status != OcptShotStatus.shot).length;
}

/// A sequence backed by a real screenplay scene.
class OcptSceneShotSequence extends OcptShotSequence {
  /// The id of the scene this sequence is built from.
  final String sceneId;

  /// The scene's normalized heading text (e.g. `INT. KITCHEN - DAY`).
  final String heading;

  /// The scene's explicit scene number (e.g. `4A`), or null if it has none of its own.
  final String? sceneNumber;

  /// The scene number every shot code of this sequence is derived from: [sceneNumber] when the
  /// scene has one, otherwise its 1-based index among the screenplay's scenes, matching what the
  /// styled screenplay editor already displays for a heading with no explicit number.
  final String displaySceneNumber;

  /// Class constructor
  const OcptSceneShotSequence({
    required this.sceneId,
    required this.heading,
    required this.sceneNumber,
    required this.displaySceneNumber,
    required super.shots,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptSceneShotSequence(sceneId: $sceneId, heading: $heading)";

  /// Object properties
  @override
  List<Object?> get props => [sceneId, heading, sceneNumber, displaySceneNumber, shots];
}

/// The single synthetic sequence holding every shot whose scene was deleted from the screenplay.
///
/// Its shots keep their own [OcptShot.orphanedHeading], so a shot still shows which scene it used
/// to belong to even though several different scenes may have been deleted over the project's
/// life; there is exactly one [OcptOrphanShotSequence] in an `OcptShotListSnapshot`, never one per
/// deleted scene. `OcptShotListService.detachShotsFromDeletedScenes` keeps the shots of the same
/// deleted scene contiguous by appending each newly orphaned batch after the existing ones, so
/// this sequence's shots, ordered by [OcptShot.position], already read grouped by
/// [OcptShot.orphanedHeading] without this class needing to do any grouping of its own.
class OcptOrphanShotSequence extends OcptShotSequence {
  /// Class constructor
  const OcptOrphanShotSequence({required super.shots});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptOrphanShotSequence(shotCount: $shotCount)";

  /// Object properties
  @override
  List<Object?> get props => [shots];
}
