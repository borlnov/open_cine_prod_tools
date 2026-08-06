// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';

/// The whole shot list of a screenplay, as `OcptShotListService.loadShotList` builds it and the
/// shot list bloc holds it.
///
/// [sequences] is every real scene's [OcptSceneShotSequence], in scene order, followed by the
/// single [OcptOrphanShotSequence] when the screenplay has any orphaned shot at all (omitted
/// entirely otherwise, rather than present with an empty shot list). [shotsById] is a flattening of
/// every sequence's shots, built once so the UI (selecting a shot from the table, looking one up
/// for "also covered by") never has to walk [sequences] itself.
///
/// [placementsByShotId] is a separate join, not one `OcptShotListService.loadShotList` performs
/// itself: that service (and this class's own [OcptShotListSnapshot.build]) knows nothing about
/// the schedule, so every call site of [OcptShotListSnapshot.build] gets an empty map by default,
/// and `OcptShotListBloc` is what attaches the schedule's own read through [copyWithPlacements]
/// once it has loaded both — the same way `J3 · Tue 4 Aug` reaches the table and the metadata
/// panel reaches the export.
class OcptShotListSnapshot extends Equatable {
  /// The screenplay this shot list belongs to.
  final String screenplayId;

  /// Every sequence of the shot list, in display order: real scenes first, in scene order, then
  /// the orphan group if it holds any shot.
  final List<OcptShotSequence> sequences;

  /// Every shot of [sequences], keyed by its id.
  final Map<String, OcptShot> shotsById;

  /// Where each shot of [shotsById] sits in the schedule, keyed by shot id — see
  /// `OcptScheduleService.loadShotPlacements`. A shot with no entry here has not been placed on any
  /// day yet; empty for a project with no schedule at all.
  final Map<String, OcptShotPlacement> placementsByShotId;

  /// Class constructor
  const OcptShotListSnapshot({
    required this.screenplayId,
    required this.sequences,
    required this.shotsById,
    this.placementsByShotId = const {},
  });

  /// Builds an [OcptShotListSnapshot] for [screenplayId] from its already-ordered [sequences],
  /// deriving [shotsById] from them. [placementsByShotId] defaults to empty: the caller this
  /// factory serves (`OcptShotListService.loadShotList`) never reads the schedule, so it is left to
  /// [copyWithPlacements] to attach it afterwards.
  factory OcptShotListSnapshot.build({
    required String screenplayId,
    required List<OcptShotSequence> sequences,
    Map<String, OcptShotPlacement> placementsByShotId = const {},
  }) {
    final shotsById = <String, OcptShot>{
      for (final sequence in sequences)
        for (final shot in sequence.shots) shot.id: shot,
    };

    return OcptShotListSnapshot(
      screenplayId: screenplayId,
      sequences: sequences,
      shotsById: Map.unmodifiable(shotsById),
      placementsByShotId: placementsByShotId,
    );
  }

  /// Returns a copy of this snapshot carrying [placementsByShotId] in place of its own, [sequences]
  /// and [shotsById] left untouched — how `OcptShotListBloc` joins the schedule's own read onto the
  /// snapshot `OcptShotListService` already built.
  OcptShotListSnapshot copyWithPlacements(Map<String, OcptShotPlacement> placementsByShotId) =>
      OcptShotListSnapshot(
        screenplayId: screenplayId,
        sequences: sequences,
        shotsById: shotsById,
        placementsByShotId: placementsByShotId,
      );

  /// The total number of shots across every sequence, orphan group included.
  int get totalShotCount => shotsById.length;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShotListSnapshot(screenplayId: $screenplayId, sequenceCount: ${sequences.length}, "
      "totalShotCount: $totalShotCount)";

  /// Object properties
  @override
  List<Object?> get props => [screenplayId, sequences, shotsById, placementsByShotId];
}
