// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_plan_xlsx_column.dart';

/// Every localized string the exported shooting plan workbook carries, resolved by the caller.
///
/// `OcptShootingPlanXlsxExportService` runs in the manager layer, where there is no `BuildContext`
/// and therefore no `Tr`: the same reason `OcptShootingPlanLabels` already exists for the shooting
/// plan PDF beside it. The UI builds this once through `ocptShootingPlanXlsxLabelsOf`, which reuses
/// the very `ocpt…Label` helpers `ocptShootingPlanLabelsOf` already calls — the day tag, the
/// presence mark, the `Perso.`/sequence-row words, the crew position and element category labels —
/// so a workbook cell can never name a day, a position or a category differently from the printed
/// plan. [blockKindLabels] is its one map with no counterpart there: it carries all eight
/// [OcptShootingBlockKind] values, [OcptShootingBlockKind.shot] included, where
/// `OcptShootingPlanLabels.blockKindLabels` deliberately carries only the seven milestone kinds a
/// printed caption ever falls back to.
///
/// Every accessor returns an empty string for a key it holds nothing for, exactly as
/// `OcptShootingPlanLabels`'s own accessors do: a missing translation is written as a blank cell
/// rather than shifting a column out of step with its header.
class OcptShootingPlanXlsxLabels extends Equatable {
  /// The suffix the suggested file name is built with (`<project> - <suffix>.xlsx`).
  final String fileNameSuffix;

  /// The name given to the `Locations` sheet.
  final String locationsSheetName;

  /// The name given to the `Sequences` sheet.
  final String sequencesSheetName;

  /// The name given to the `Crew and cast` sheet.
  final String peopleSheetName;

  /// The name given to the `Elements` sheet.
  final String elementsSheetName;

  /// The name given to the `Chronology` sheet.
  final String chronologySheetName;

  /// The corner header of the locations sheet's own row-label column.
  final String locationsRowHeader;

  /// The corner header of the sequences sheet's own row-label column.
  final String sequencesRowHeader;

  /// The corner header of the crew and cast sheet's own row-label column.
  final String peopleRowHeader;

  /// The corner header of the elements sheet's own row-label column.
  final String elementsRowHeader;

  /// The header label of every column of the `Chronology` sheet.
  final Map<OcptShootingPlanXlsxColumn, String> chronologyColumnHeaders;

  /// The day tag's own letter (`D`/`J`), printed beside a day's rank in every sheet that carries
  /// one — the same word `OcptShootingPlanLabels.dayTagPrefix` already carries.
  final String dayTagPrefix;

  /// The mark a crew-and-cast or an elements cell prints for an uncast role, or an element needed
  /// that day, present with nobody or nothing named — the same word `OcptShootingPlanLabels
  /// .presenceMark` already carries.
  final String presenceMark;

  /// The word `Perso.`, reused both as the locations sheet's own nested row and, were it ever
  /// needed, a shot table's own characters column — the same word `OcptShootingPlanLabels.persoLabel`
  /// already carries.
  final String persoLabel;

  /// The prefix a sequences sheet's own row label is built with (`Séq. 2`) — the same word
  /// `OcptShootingPlanLabels.sequenceRowPrefix` already carries.
  final String sequenceRowPrefix;

  /// The display label of every catalogued crew position (`ocptCrewPositions`), keyed by its stable
  /// id — the same map `OcptShootingPlanLabels.crewPositionLabels` already carries.
  final Map<String, String> crewPositionLabels;

  /// The display label of every [OcptElementCategory] — the same map `OcptShootingPlanLabels
  /// .elementCategoryLabels` already carries.
  final Map<OcptElementCategory, String> elementCategoryLabels;

  /// The display label of every [OcptShootingBlockKind], [OcptShootingBlockKind.shot] included —
  /// see the class doc comment for why this map has no counterpart on `OcptShootingPlanLabels`.
  final Map<OcptShootingBlockKind, String> blockKindLabels;

  /// Class constructor
  const OcptShootingPlanXlsxLabels({
    required this.fileNameSuffix,
    required this.locationsSheetName,
    required this.sequencesSheetName,
    required this.peopleSheetName,
    required this.elementsSheetName,
    required this.chronologySheetName,
    required this.locationsRowHeader,
    required this.sequencesRowHeader,
    required this.peopleRowHeader,
    required this.elementsRowHeader,
    required this.chronologyColumnHeaders,
    required this.dayTagPrefix,
    required this.presenceMark,
    required this.persoLabel,
    required this.sequenceRowPrefix,
    required this.crewPositionLabels,
    required this.elementCategoryLabels,
    required this.blockKindLabels,
  });

  /// The header of [column] in the `Chronology` sheet, or an empty string if
  /// [chronologyColumnHeaders] holds none for it.
  String chronologyHeaderOf(OcptShootingPlanXlsxColumn column) => chronologyColumnHeaders[column] ?? "";

  /// The label of the crew position [positionId] names, or an empty string if [crewPositionLabels]
  /// holds none for it.
  String crewPositionLabelOf(String positionId) => crewPositionLabels[positionId] ?? "";

  /// The label of [category], or an empty string if [elementCategoryLabels] holds none for it.
  String elementCategoryLabelOf(OcptElementCategory category) => elementCategoryLabels[category] ?? "";

  /// The label of [kind], or an empty string if [blockKindLabels] holds none for it.
  String blockKindLabelOf(OcptShootingBlockKind kind) => blockKindLabels[kind] ?? "";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingPlanXlsxLabels(locationsSheetName: $locationsSheetName, chronologySheetName: "
      "$chronologySheetName)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    locationsSheetName,
    sequencesSheetName,
    peopleSheetName,
    elementsSheetName,
    chronologySheetName,
    locationsRowHeader,
    sequencesRowHeader,
    peopleRowHeader,
    elementsRowHeader,
    chronologyColumnHeaders,
    dayTagPrefix,
    presenceMark,
    persoLabel,
    sequenceRowPrefix,
    crewPositionLabels,
    elementCategoryLabels,
    blockKindLabels,
  ];
}
