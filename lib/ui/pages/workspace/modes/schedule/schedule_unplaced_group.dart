// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';

/// One group of the left dock's own "shots still to place" list: every live shot of one sequence
/// (a real scene, or the orphan group) that has no live block placing it yet, in the sequence's own
/// shot order.
///
/// [screenplayId] names the episode this group's sequence belongs to. It is not cosmetic:
/// `OcptOrphanShotSequence.sequenceId` is the constant `"orphans"`, so a project holding several
/// episodes walks several groups sharing that one [sequenceId] — the pair ([screenplayId],
/// [sequenceId]) is what actually identifies one group once there is more than one episode to mix
/// them up.
class OcptScheduleUnplacedGroup extends Equatable {
  /// The id of the episode (screenplay) this group's sequence belongs to.
  final String screenplayId;

  /// The sequence's own id (a scene id, or `OcptOrphanShotSequence.sequenceId`).
  final String sequenceId;

  /// The sequence's own display number (`4A`), or null for the orphan group.
  final String? displaySceneNumber;

  /// The sequence's own heading, or null for the orphan group.
  final String? heading;

  /// The unplaced shots of this sequence, in shot order.
  final List<OcptShot> shots;

  /// Class constructor
  const OcptScheduleUnplacedGroup({
    required this.screenplayId,
    required this.sequenceId,
    required this.displaySceneNumber,
    required this.heading,
    required this.shots,
  });

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [screenplayId, sequenceId, displaySceneNumber, heading, shots];
}
