// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_entries_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scenes_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';

/// Every localized string the exported breakdown workbook carries, resolved by the caller.
///
/// `OcptBreakdownXlsxExportService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptBreakdownSheetsLabels` already exists for the breakdown
/// sheets PDF beside it. The UI builds this once through `ocptBreakdownXlsxLabelsOf`, which reuses
/// the very `ocpt…Label` helpers the mode's own widgets call — and, for [groupLabelOf],
/// [ocptBreakdownGroupLabelOf] itself — so a workbook cell can never name a status, a category or a
/// group differently from the screen or from the breakdown sheets PDF.
///
/// Every accessor returns an empty string for a key it holds nothing for, exactly as
/// `OcptResourcesXlsxLabels`'s own accessors do: a missing translation is written as a blank cell
/// rather than shifting a column out of step with its header.
class OcptBreakdownXlsxLabels extends Equatable {
  /// The suffix the suggested file name is built with (`<project> - <suffix>.xlsx`).
  final String fileNameSuffix;

  /// The name given to the `Scenes` sheet.
  final String scenesSheetName;

  /// The name given to the `Breakdown` sheet.
  final String entriesSheetName;

  /// The header label of every column of the `Scenes` sheet.
  final Map<OcptBreakdownScenesXlsxColumn, String> scenesColumnHeaders;

  /// The header label of every column of the `Breakdown` sheet.
  final Map<OcptBreakdownEntriesXlsxColumn, String> entriesColumnHeaders;

  /// The display label of every [OcptBreakdownSceneStatus].
  final Map<OcptBreakdownSceneStatus, String> sceneStatusLabels;

  /// The display label of every [OcptElementStatus].
  final Map<OcptElementStatus, String> elementStatusLabels;

  /// The display label of every [OcptElementCategory] — [groupLabelOf]'s own element case.
  final Map<OcptElementCategory, String> elementCategoryLabels;

  /// The label of the group the tagged roles are written under — [groupLabelOf]'s own role case.
  final String roleGroupLabel;

  /// The label of the group the tagged sets are written under — [groupLabelOf]'s own set case.
  final String setGroupLabel;

  /// Class constructor
  const OcptBreakdownXlsxLabels({
    required this.fileNameSuffix,
    required this.scenesSheetName,
    required this.entriesSheetName,
    required this.scenesColumnHeaders,
    required this.entriesColumnHeaders,
    required this.sceneStatusLabels,
    required this.elementStatusLabels,
    required this.elementCategoryLabels,
    required this.roleGroupLabel,
    required this.setGroupLabel,
  });

  /// The header of [column] in the `Scenes` sheet, or an empty string if [scenesColumnHeaders]
  /// holds none for it.
  String scenesHeaderOf(OcptBreakdownScenesXlsxColumn column) => scenesColumnHeaders[column] ?? "";

  /// The header of [column] in the `Breakdown` sheet, or an empty string if [entriesColumnHeaders]
  /// holds none for it.
  String entriesHeaderOf(OcptBreakdownEntriesXlsxColumn column) =>
      entriesColumnHeaders[column] ?? "";

  /// The label of [status], or an empty string if [sceneStatusLabels] holds none for it.
  String sceneStatusLabelOf(OcptBreakdownSceneStatus status) => sceneStatusLabels[status] ?? "";

  /// The label of [status], or an empty string if [elementStatusLabels] holds none for it.
  String elementStatusLabelOf(OcptElementStatus status) => elementStatusLabels[status] ?? "";

  /// The label of the group a target of [kind] falling under [category] is written in: delegates to
  /// [ocptBreakdownGroupLabelOf], the single switch `OcptBreakdownSheetsLabels.groupLabelOf` itself
  /// delegates to — see that function's own doc comment.
  String groupLabelOf({required OcptBreakdownTargetKind kind, OcptElementCategory? category}) =>
      ocptBreakdownGroupLabelOf(
        kind: kind,
        category: category,
        elementCategoryLabels: elementCategoryLabels,
        roleGroupLabel: roleGroupLabel,
        setGroupLabel: setGroupLabel,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBreakdownXlsxLabels(scenesSheetName: $scenesSheetName, entriesSheetName: "
      "$entriesSheetName)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    scenesSheetName,
    entriesSheetName,
    scenesColumnHeaders,
    entriesColumnHeaders,
    sceneStatusLabels,
    elementStatusLabels,
    elementCategoryLabels,
    roleGroupLabel,
    setGroupLabel,
  ];
}
