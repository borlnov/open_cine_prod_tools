// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';

/// Every localized string the exported breakdown sheets carry, resolved by the caller.
///
/// `OcptBreakdownSheetsPdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptScenarioCoverageLabels` and `OcptResourcesXlsxLabels`
/// already exist for the two exports before it. The UI builds this once through
/// `ocptBreakdownSheetsLabelsOf`, which reuses the very `ocpt…Label` helpers the mode's own widgets
/// call, so a printed sheet can never name a status or a category differently from the screen.
///
/// [sceneTitles] is the one entry resolved scene by scene rather than formatted by the service: a
/// scene's own title takes its display number as a placeholder, exactly the trade
/// `OcptScenarioCoverageLabels.sequenceTitles` already makes. Everything else the sheets print
/// beside it — the scene's heading, its length in eighths, a target's name, a quantity — is the
/// project's own text or a bare numeral, and is never translated.
///
/// Every accessor returns an empty string for a key it holds nothing for, exactly as
/// `OcptScenarioCoverageLabels.titleOfSequence` does: a missing translation prints as a blank
/// rather than as a crash on a document a department head is waiting for.
class OcptBreakdownSheetsLabels extends Equatable {
  /// The suffix the suggested file name is built with (`<project> - <suffix>.pdf`).
  final String fileNameSuffix;

  /// The document's own name, printed small above every sheet's scene title beside the project's.
  final String documentTitle;

  /// The title of each scene's sheet, keyed by `OcptBreakdownScene.id` — see the class doc comment
  /// for why it is resolved by the caller.
  final Map<String, String> sceneTitles;

  /// The label of the scene's own breakdown status, printed in the sheet's meta band.
  final String statusLabel;

  /// The label of the scene's length, printed in the sheet's meta band beside [statusLabel]. The
  /// value itself is the eighths notation assistant directors write (`1 4/8`), a numeral this
  /// document never translates.
  final String lengthLabel;

  /// The label of the scene's own breakdown notes section.
  final String notesLabel;

  /// The heading of the section listing what the scene needs, grouped by category.
  final String targetsSectionTitle;

  /// The heading of the closing section listing what the scene still has to find.
  final String toFindSectionTitle;

  /// The header of the targets table's name column.
  final String nameHeader;

  /// The header of the targets table's status column.
  final String statusHeader;

  /// The header of the targets table's owner column.
  final String ownerHeader;

  /// The display label of every [OcptBreakdownSceneStatus].
  final Map<OcptBreakdownSceneStatus, String> sceneStatusLabels;

  /// The display label of every [OcptElementStatus].
  final Map<OcptElementStatus, String> elementStatusLabels;

  /// The display label of every [OcptElementCategory], naming an element group's own band.
  final Map<OcptElementCategory, String> elementCategoryLabels;

  /// The label of the group the tagged roles are printed under.
  final String roleGroupLabel;

  /// The label of the group the tagged sets are printed under.
  final String setGroupLabel;

  /// The note printed in place of the targets table on a scene nothing is tagged in.
  final String emptySceneNote;

  /// The note printed on the single sheet of a document no scene at all was selected for — the
  /// export run with "only the scenes marked done" on a screenplay where none is.
  final String emptyDocumentNote;

  /// Class constructor
  const OcptBreakdownSheetsLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.sceneTitles,
    required this.statusLabel,
    required this.lengthLabel,
    required this.notesLabel,
    required this.targetsSectionTitle,
    required this.toFindSectionTitle,
    required this.nameHeader,
    required this.statusHeader,
    required this.ownerHeader,
    required this.sceneStatusLabels,
    required this.elementStatusLabels,
    required this.elementCategoryLabels,
    required this.roleGroupLabel,
    required this.setGroupLabel,
    required this.emptySceneNote,
    required this.emptyDocumentNote,
  });

  /// The title of the scene [sceneId], or an empty string if [sceneTitles] holds none for it.
  String titleOfScene(String sceneId) => sceneTitles[sceneId] ?? "";

  /// The label of [status], or an empty string if [sceneStatusLabels] holds none for it.
  String sceneStatusLabelOf(OcptBreakdownSceneStatus status) => sceneStatusLabels[status] ?? "";

  /// The label of [status], or an empty string if [elementStatusLabels] holds none for it.
  String elementStatusLabelOf(OcptElementStatus status) => elementStatusLabels[status] ?? "";

  /// The label of the group a target of [kind] falling under [category] is printed in: the
  /// category's own label for an element, [roleGroupLabel] or [setGroupLabel] otherwise.
  ///
  /// The exact switch `ocptBreakdownLegendKeyLabel` makes on screen, kept here rather than in the
  /// service so the two never drift: a category with no label at all prints blank rather than
  /// throwing on a document being written out.
  String groupLabelOf({required OcptBreakdownTargetKind kind, OcptElementCategory? category}) =>
      switch (kind) {
        OcptBreakdownTargetKind.element =>
          category == null ? "" : elementCategoryLabels[category] ?? "",
        OcptBreakdownTargetKind.role => roleGroupLabel,
        OcptBreakdownTargetKind.set => setGroupLabel,
      };

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBreakdownSheetsLabels(documentTitle: $documentTitle, sceneCount: ${sceneTitles.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    sceneTitles,
    statusLabel,
    lengthLabel,
    notesLabel,
    targetsSectionTitle,
    toFindSectionTitle,
    nameHeader,
    statusHeader,
    ownerHeader,
    sceneStatusLabels,
    elementStatusLabels,
    elementCategoryLabels,
    roleGroupLabel,
    setGroupLabel,
    emptySceneNote,
    emptyDocumentNote,
  ];
}
