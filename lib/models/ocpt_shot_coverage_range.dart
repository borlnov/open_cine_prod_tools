// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// A range of a scene's text that a shot covers, as the shot list holds it once the corresponding
/// `shot_coverages` row is joined with whatever freshness check the caller ran against it.
///
/// [startOffset] and [endOffset] are character offsets relative to the scene's `charStart`, not to
/// the whole document, exactly as `OcptShotCoveragesTable` stores them: see that table's doc
/// comment for why the offsets are scene-relative.
class OcptShotCoverageRange extends Equatable {
  /// The stable, unique id of this coverage range (a UUID).
  final String id;

  /// The scene this range belongs to. [startOffset]/[endOffset] are relative to this scene's
  /// `charStart`.
  final String sceneId;

  /// The character offset, relative to the scene's `charStart`, at which this range starts.
  final int startOffset;

  /// The character offset, relative to the scene's `charStart`, one past the last character of
  /// this range.
  final int endOffset;

  /// A digest of the exact substring this range covered when it was last recorded or confirmed.
  final String coveredTextDigest;

  /// Whether this range currently disagrees with the screenplay's text: either the substring it
  /// covers changed since [coveredTextDigest] was recorded, or the range no longer fits inside its
  /// scene at all. `OcptShotCoverageService.refreshStaleness` is what decides this, on every save;
  /// this flag is this range's share of the owning shot's `needsCheck`/`checkReason`, not a column
  /// of its own in `shot_coverages` (see that table's doc comment: staleness is stored once, per
  /// shot, not per range).
  final bool isStale;

  /// Class constructor
  const OcptShotCoverageRange({
    required this.id,
    required this.sceneId,
    required this.startOffset,
    required this.endOffset,
    required this.coveredTextDigest,
    required this.isStale,
  });

  /// Builds an [OcptShotCoverageRange] from its stored [row], paired with whether the caller has
  /// determined it [isStale].
  factory OcptShotCoverageRange.fromRow({required OcptShotCoverageRow row, required bool isStale}) =>
      OcptShotCoverageRange(
        id: row.id,
        sceneId: row.sceneId,
        startOffset: row.startOffset,
        endOffset: row.endOffset,
        coveredTextDigest: row.coveredTextDigest,
        isStale: isStale,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShotCoverageRange(id: $id, sceneId: $sceneId, startOffset: $startOffset, "
      "endOffset: $endOffset, isStale: $isStale)";

  /// Object properties
  @override
  List<Object?> get props => [id, sceneId, startOffset, endOffset, coveredTextDigest, isStale];
}
