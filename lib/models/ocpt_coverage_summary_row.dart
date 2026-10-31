// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';

/// One sequence's row on the export's summary page: how much of it is covered, and by how many
/// shots.
class OcptCoverageSummaryRow extends Equatable {
  /// The id of the sequence this row is built from ([OcptShotSequence.id]).
  final String sequenceId;

  /// The sequence's display scene number, or null for the orphan group (which is no scene).
  final String? sceneNumber;

  /// The sequence's scene heading, or an empty string for the orphan group.
  final String heading;

  /// How many shots the sequence holds.
  final int shotCount;

  /// How many words the scene's text holds at all, as the coverage editor counts them
  /// ([OcptScriptWordLayout] blocks and words). Always 0 for the orphan group.
  final int wordCount;

  /// How many of those [wordCount] words at least one shot covers, counted as a union so a word
  /// covered twice still counts once.
  final int coveredWordCount;

  /// How many of the sequence's coverage ranges no longer agree with the screenplay's text.
  final int staleRangeCount;

  /// The uncovered passages of the scene, quoted short and in reading order, capped both in
  /// number and in length: the summary names what is missing, it does not reprint it.
  final List<String> uncoveredExtracts;

  /// Whether this row is the orphan group rather than a real scene.
  ///
  /// An orphan shot's scene no longer exists, so it covers nothing that can be printed: the group
  /// is listed to be named, not to be measured.
  final bool isOrphanGroup;

  /// Class constructor
  const OcptCoverageSummaryRow({
    required this.sequenceId,
    required this.sceneNumber,
    required this.heading,
    required this.shotCount,
    required this.wordCount,
    required this.coveredWordCount,
    required this.staleRangeCount,
    required this.uncoveredExtracts,
    required this.isOrphanGroup,
  });

  /// The share of the scene's words at least one shot covers, between 0 and 1; 0 when the scene
  /// holds no word at all (an empty scene is not "fully covered").
  double get coveredWordShare => wordCount == 0 ? 0 : coveredWordCount / wordCount;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptCoverageSummaryRow(sequenceId: $sequenceId, shotCount: $shotCount, "
      "covered: $coveredWordCount/$wordCount)";

  /// Object properties
  @override
  List<Object?> get props => [
    sequenceId,
    sceneNumber,
    heading,
    shotCount,
    wordCount,
    coveredWordCount,
    staleRangeCount,
    uncoveredExtracts,
    isOrphanGroup,
  ];
}
