// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_coverage_bar_segment.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';

/// One shot's row on the export's legend page: what its colour means, in the shot list's own
/// terms.
class OcptCoverageLegendEntry extends Equatable {
  /// The id of the shot this row describes.
  final String shotId;

  /// The id of the sequence the shot belongs to ([OcptShotSequence.id]).
  final String sequenceId;

  /// The rank, within its sequence, the shot's colour is read at (`ocptCoverageColorAt`).
  final int colorIndex;

  /// The label the shot's bars carry, see [OcptCoverageBarSegment.label].
  final String label;

  /// The shot's [OcptShot.shotSize], free text, possibly empty.
  final String shotSize;

  /// The shot's [OcptShot.framing], free text, possibly empty.
  final String framing;

  /// The shot's [OcptShot.cameraMove], free text, possibly empty.
  final String cameraMove;

  /// Class constructor
  const OcptCoverageLegendEntry({
    required this.shotId,
    required this.sequenceId,
    required this.colorIndex,
    required this.label,
    required this.shotSize,
    required this.framing,
    required this.cameraMove,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() => "OcptCoverageLegendEntry(shotId: $shotId, label: $label)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [shotId, sequenceId, colorIndex, label, shotSize, framing, cameraMove];
}
