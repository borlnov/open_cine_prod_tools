// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';

/// The whole shot list of a screenplay, as `OcptShotListService.loadShotList` builds it and the
/// shot list bloc holds it.
///
/// [sequences] is every real scene's [OcptSceneShotSequence], in scene order, followed by the
/// single [OcptOrphanShotSequence] when the screenplay has any orphaned shot at all (omitted
/// entirely otherwise, rather than present with an empty shot list). [shotsById] is a flattening of
/// every sequence's shots, built once so the UI (selecting a shot from the table, looking one up
/// for "also covered by") never has to walk [sequences] itself.
class OcptShotListSnapshot extends Equatable {
  /// The screenplay this shot list belongs to.
  final String screenplayId;

  /// Every sequence of the shot list, in display order: real scenes first, in scene order, then
  /// the orphan group if it holds any shot.
  final List<OcptShotSequence> sequences;

  /// Every shot of [sequences], keyed by its id.
  final Map<String, OcptShot> shotsById;

  /// Class constructor
  const OcptShotListSnapshot({
    required this.screenplayId,
    required this.sequences,
    required this.shotsById,
  });

  /// Builds an [OcptShotListSnapshot] for [screenplayId] from its already-ordered [sequences],
  /// deriving [shotsById] from them.
  factory OcptShotListSnapshot.build({
    required String screenplayId,
    required List<OcptShotSequence> sequences,
  }) {
    final shotsById = <String, OcptShot>{
      for (final sequence in sequences)
        for (final shot in sequence.shots) shot.id: shot,
    };

    return OcptShotListSnapshot(
      screenplayId: screenplayId,
      sequences: sequences,
      shotsById: Map.unmodifiable(shotsById),
    );
  }

  /// The total number of shots across every sequence, orphan group included.
  int get totalShotCount => shotsById.length;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShotListSnapshot(screenplayId: $screenplayId, sequenceCount: ${sequences.length}, "
      "totalShotCount: $totalShotCount)";

  /// Object properties
  @override
  List<Object?> get props => [screenplayId, sequences, shotsById];
}
