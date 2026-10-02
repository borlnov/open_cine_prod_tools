// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Every localized string the exported storyboard document carries, resolved by the caller.
///
/// `OcptStoryboardPdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr` — the same reason `OcptScenarioCoverageLabels` already exists for the
/// scenario coverage PDF. Every field here reuses an existing on-screen string wherever one names
/// the same thing (`ocptStoryboardLabelsOf`'s own doc comment says which), so the document never
/// names a shot's field differently than the table, the inspector or the board already do.
class OcptStoryboardLabels extends Equatable {
  /// The suffix the suggested file name is built with (`<project> - <suffix>.pdf`).
  final String fileNameSuffix;

  /// The document's own name, printed on the running head of every page.
  final String documentTitle;

  /// The key-information block's header naming a shot's shot size.
  final String shotSizeLabel;

  /// The key-information block's header naming a shot's framing.
  final String framingLabel;

  /// The key-information block's header naming a shot's camera move.
  final String cameraMoveLabel;

  /// The key-information block's header naming a shot's lens.
  final String lensLabel;

  /// The key-information block's header naming a shot's recording format.
  final String recordingFormatLabel;

  /// The key-information block's header naming a shot's attached cast.
  final String castLabel;

  /// The display label of every [OcptShotStatus], exactly as the shot status pill shows it.
  final Map<OcptShotStatus, String> statusLabels;

  /// The note printed in place of a shot's frames when it holds no panel at all.
  final String noPanelNote;

  /// The note printed over the placeholder frame of a panel whose image file could not be read —
  /// missing, or moved since the reference was recorded (ADR 0013, on paper).
  final String fileNotFoundNote;

  /// The title of each sequence, keyed by `OcptShotSequence.id`, printed as every sequence's own
  /// header band — the sibling of `OcptScenarioCoverageLabels.sequenceTitles`.
  final Map<String, String> sequenceTitles;

  /// Class constructor
  const OcptStoryboardLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.shotSizeLabel,
    required this.framingLabel,
    required this.cameraMoveLabel,
    required this.lensLabel,
    required this.recordingFormatLabel,
    required this.castLabel,
    required this.statusLabels,
    required this.noPanelNote,
    required this.fileNotFoundNote,
    required this.sequenceTitles,
  });

  /// The title of the sequence [sequenceId], or an empty string if [sequenceTitles] holds none for
  /// it.
  String titleOfSequence(String sequenceId) => sequenceTitles[sequenceId] ?? "";

  /// The display label of [status], or the status's own name as a last resort — a status
  /// [statusLabels] holds nothing for is a labels object built incompletely in a test, never a
  /// real one.
  String labelOfStatus(OcptShotStatus status) => statusLabels[status] ?? status.name;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptStoryboardLabels(documentTitle: $documentTitle)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    shotSizeLabel,
    framingLabel,
    cameraMoveLabel,
    lensLabel,
    recordingFormatLabel,
    castLabel,
    statusLabels,
    noPanelNote,
    fileNotFoundNote,
    sequenceTitles,
  ];
}
