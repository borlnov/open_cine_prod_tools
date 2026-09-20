// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Every localized string the exported floor plans document carries, resolved by the caller.
///
/// `OcptFloorPlanPdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr` — the sibling of `OcptStoryboardLabels` for the other document M7 adds. Every
/// field reuses an existing on-screen string wherever one names the same thing
/// (`ocptFloorPlanLabelsOf`'s own doc comment says which).
class OcptFloorPlanLabels extends Equatable {
  /// The suffix the suggested file name is built with (`<project> - <suffix>.pdf`).
  final String fileNameSuffix;

  /// The document's own name, printed on the running head of every page.
  final String documentTitle;

  /// The page header's own field naming a shot's shot size.
  final String shotSizeLabel;

  /// The page header's own field naming a shot's framing.
  final String framingLabel;

  /// The page header's own field naming a shot's camera move.
  final String cameraMoveLabel;

  /// The page header's own field naming a shot's lens.
  final String lensLabel;

  /// The page header's own field naming a shot's recording format.
  final String recordingFormatLabel;

  /// The page header's own field naming a shot's attached cast.
  final String castLabel;

  /// The display label of every [OcptShotStatus], exactly as the shot status pill shows it.
  final Map<OcptShotStatus, String> statusLabels;

  /// The title of each sequence, keyed by `OcptShotSequence.id`, printed on every page's own
  /// header — the sibling of `OcptScenarioCoverageLabels.sequenceTitles`.
  final Map<String, String> sequenceTitles;

  /// The note printed on a case's own bare-décor page: no shot of the sequence has a camera
  /// placed on it. Reused from the floor plans view's own Placements group, so the document says
  /// the very same thing the inspector already does.
  final String noCameraNote;

  /// The unit suffix appended to a scale bar's own length (`2 m`), reused from
  /// `shotListFloorPlanScaleBarLengthLabel`'s own `{length} m` pattern — see
  /// `ocptFloorPlanLabelsOf`'s own doc comment.
  final String scaleBarUnitLabel;

  /// Class constructor
  const OcptFloorPlanLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.shotSizeLabel,
    required this.framingLabel,
    required this.cameraMoveLabel,
    required this.lensLabel,
    required this.recordingFormatLabel,
    required this.castLabel,
    required this.statusLabels,
    required this.sequenceTitles,
    required this.noCameraNote,
    required this.scaleBarUnitLabel,
  });

  /// The title of the sequence [sequenceId], or an empty string if [sequenceTitles] holds none for
  /// it.
  String titleOfSequence(String sequenceId) => sequenceTitles[sequenceId] ?? "";

  /// The display label of [status], or the status's own name as a last resort — see
  /// `OcptStoryboardLabels.labelOfStatus`'s own doc comment.
  String labelOfStatus(OcptShotStatus status) => statusLabels[status] ?? status.name;

  /// The scale bar's own printed text, [lengthText] (`ocptFloorPlanScaleBarLengthLabelOf`'s own
  /// plain number) followed by [scaleBarUnitLabel].
  String scaleBarLabelOf(String lengthText) => "$lengthText $scaleBarUnitLabel";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptFloorPlanLabels(documentTitle: $documentTitle)";

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
    sequenceTitles,
    noCameraNote,
    scaleBarUnitLabel,
  ];
}
