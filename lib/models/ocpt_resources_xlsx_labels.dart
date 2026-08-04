// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_elements_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_locations_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_people_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_roles_xlsx_column.dart';

/// Every localized string the exported resources workbook carries, resolved by the caller.
///
/// `OcptResourcesXlsxExportService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptShotListXlsxLabels` exists for the shot list's own
/// export. The UI builds this once through `ocptResourcesXlsxLabelsOf`, which reuses the very
/// `ocpt…Label` helpers the four tabs' own widgets call, so a sheet can never name a status
/// differently from the screen.
///
/// [sceneLabels] is the one exception to "every string is a translation": `ocptSceneRefLabel`
/// lives under `lib/ui/utils/`, which the manager layer must not import, so the UI resolves a
/// scene's label for every scene id the catalogue might reference and hands the whole map over —
/// exactly the same trade `OcptShotListXlsxLabels.sequenceTitles` makes for a sequence's own
/// separator title.
///
/// Every accessor returns an empty string for a key it holds nothing for, exactly as
/// `OcptShotListXlsxLabels.headerOf`/`.labelOf` do — a missing translation is written as a blank
/// cell rather than shifting a column out of step with its header.
class OcptResourcesXlsxLabels extends Equatable {
  /// The localized suffix `OcptResourcesXlsxExportService.xlsxFileName` appends to the project
  /// name, mirroring `OcptScenarioCoverageLabels.fileNameSuffix`.
  final String fileNameSuffix;

  /// The name given to the crew & cast directory sheet.
  final String peopleSheetName;

  /// The name given to the roles sheet.
  final String rolesSheetName;

  /// The name given to the locations & sets sheet.
  final String locationsSheetName;

  /// The name given to the elements sheet.
  final String elementsSheetName;

  /// The header label of every column of the crew & cast directory sheet.
  final Map<OcptPeopleXlsxColumn, String> peopleColumnHeaders;

  /// The header label of every column of the roles sheet.
  final Map<OcptRolesXlsxColumn, String> rolesColumnHeaders;

  /// The header label of every column of the locations & sets sheet.
  final Map<OcptLocationsXlsxColumn, String> locationsColumnHeaders;

  /// The header label of every column of the elements sheet.
  final Map<OcptElementsXlsxColumn, String> elementsColumnHeaders;

  /// The display label of every stable crew position of `ocptCrewPositions`, keyed by its id.
  final Map<String, String> crewPositionLabels;

  /// The display label of every [OcptRoleKind].
  final Map<OcptRoleKind, String> roleKindLabels;

  /// The display label of every [OcptImageRightsStatus].
  final Map<OcptImageRightsStatus, String> imageRightsStatusLabels;

  /// The display label of every [OcptPermitStatus].
  final Map<OcptPermitStatus, String> permitStatusLabels;

  /// The display label of every [OcptElementCategory].
  final Map<OcptElementCategory, String> elementCategoryLabels;

  /// The display label of every [OcptElementSourceKind].
  final Map<OcptElementSourceKind, String> elementSourceKindLabels;

  /// The display label of every [OcptDayPartSlot], shared by a person's unavailabilities and a
  /// location's availability windows.
  final Map<OcptDayPartSlot, String> dayPartSlotLabels;

  /// The display label of every [OcptLocationAvailabilityKind].
  final Map<OcptLocationAvailabilityKind, String> availabilityKindLabels;

  /// The label written for an element whose three tracking flags are all unset.
  final String elementTrackingToSecureLabel;

  /// The label written for an element that is secured but not yet ready for the shoot.
  final String elementTrackingSecuredLabel;

  /// The label written for an element that is ready for the shoot but not yet returned.
  final String elementTrackingReadyLabel;

  /// The label written for an element that has been returned.
  final String elementTrackingReturnedLabel;

  /// The label describing a dated window whose weekday mask covers every day of its range.
  final String everyDayLabel;

  /// The name of every day of the week, keyed by its `DateTime.monday`…`DateTime.sunday` number:
  /// what a window narrowed to some days of its range is described with.
  ///
  /// Resolved by the caller like [sceneLabels] is, and for the same reason — but out of the
  /// locale's own calendar data rather than out of the ARB files, since a weekday name is
  /// something every locale already knows and nothing this app should be translating itself.
  final Map<int, String> weekdayLabels;

  /// The label of the scene [String] (its stable id) names, resolved by the caller through
  /// `ocptSceneRefLabel` — see the class doc comment.
  final Map<String, String> sceneLabels;

  /// Class constructor
  const OcptResourcesXlsxLabels({
    required this.fileNameSuffix,
    required this.peopleSheetName,
    required this.rolesSheetName,
    required this.locationsSheetName,
    required this.elementsSheetName,
    required this.peopleColumnHeaders,
    required this.rolesColumnHeaders,
    required this.locationsColumnHeaders,
    required this.elementsColumnHeaders,
    required this.crewPositionLabels,
    required this.roleKindLabels,
    required this.imageRightsStatusLabels,
    required this.permitStatusLabels,
    required this.elementCategoryLabels,
    required this.elementSourceKindLabels,
    required this.dayPartSlotLabels,
    required this.availabilityKindLabels,
    required this.elementTrackingToSecureLabel,
    required this.elementTrackingSecuredLabel,
    required this.elementTrackingReadyLabel,
    required this.elementTrackingReturnedLabel,
    required this.everyDayLabel,
    required this.weekdayLabels,
    required this.sceneLabels,
  });

  /// The header of [column] in the crew & cast directory sheet, or an empty string if
  /// [peopleColumnHeaders] holds none for it.
  String peopleHeaderOf(OcptPeopleXlsxColumn column) => peopleColumnHeaders[column] ?? "";

  /// The header of [column] in the roles sheet, or an empty string if [rolesColumnHeaders] holds
  /// none for it.
  String rolesHeaderOf(OcptRolesXlsxColumn column) => rolesColumnHeaders[column] ?? "";

  /// The header of [column] in the locations & sets sheet, or an empty string if
  /// [locationsColumnHeaders] holds none for it.
  String locationsHeaderOf(OcptLocationsXlsxColumn column) => locationsColumnHeaders[column] ?? "";

  /// The header of [column] in the elements sheet, or an empty string if [elementsColumnHeaders]
  /// holds none for it.
  String elementsHeaderOf(OcptElementsXlsxColumn column) => elementsColumnHeaders[column] ?? "";

  /// The label of the crew position [positionId] names, or an empty string if [crewPositionLabels]
  /// holds none for it.
  String crewPositionLabelOf(String positionId) => crewPositionLabels[positionId] ?? "";

  /// The label of [kind], or an empty string if [roleKindLabels] holds none for it.
  String roleKindLabelOf(OcptRoleKind kind) => roleKindLabels[kind] ?? "";

  /// The label of [status], or an empty string if [imageRightsStatusLabels] holds none for it.
  String imageRightsStatusLabelOf(OcptImageRightsStatus status) =>
      imageRightsStatusLabels[status] ?? "";

  /// The label of [status], or an empty string if [permitStatusLabels] holds none for it.
  String permitStatusLabelOf(OcptPermitStatus status) => permitStatusLabels[status] ?? "";

  /// The label of [category], or an empty string if [elementCategoryLabels] holds none for it.
  String elementCategoryLabelOf(OcptElementCategory category) =>
      elementCategoryLabels[category] ?? "";

  /// The label of [sourceKind], or an empty string if [elementSourceKindLabels] holds none for it.
  String elementSourceKindLabelOf(OcptElementSourceKind sourceKind) =>
      elementSourceKindLabels[sourceKind] ?? "";

  /// The label of [slot], or an empty string if [dayPartSlotLabels] holds none for it.
  String dayPartSlotLabelOf(OcptDayPartSlot slot) => dayPartSlotLabels[slot] ?? "";

  /// The label of [kind], or an empty string if [availabilityKindLabels] holds none for it.
  String availabilityKindLabelOf(OcptLocationAvailabilityKind kind) =>
      availabilityKindLabels[kind] ?? "";

  /// The name of [weekday], a `DateTime.monday`…`DateTime.sunday` number, or an empty string if
  /// [weekdayLabels] holds none for it.
  String weekdayLabelOf(int weekday) => weekdayLabels[weekday] ?? "";

  /// The label of the scene [sceneId] names, or an empty string if [sceneLabels] holds none for it
  /// (a link onto a scene the screenplay no longer has, which the loading services already filter
  /// out — see `OcptElement.sceneLinks`'s own doc comment — so this is only ever a safety net).
  String sceneLabelOf(String sceneId) => sceneLabels[sceneId] ?? "";

  /// How far along [element] is, read off its three tracking flags in the exact priority
  /// `ocptElementTrackingLabel` uses (the last one ticked wins): [elementTrackingReturnedLabel],
  /// then [elementTrackingReadyLabel], then [elementTrackingSecuredLabel], and
  /// [elementTrackingToSecureLabel] while none is set. Kept here rather than duplicated by the
  /// service, since the four labels it reads from already live on this object.
  String elementTrackingLabelOf(OcptElement element) {
    if (element.isReturned) {
      return elementTrackingReturnedLabel;
    }
    if (element.isReadyForShoot) {
      return elementTrackingReadyLabel;
    }
    if (element.isSecured) {
      return elementTrackingSecuredLabel;
    }

    return elementTrackingToSecureLabel;
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptResourcesXlsxLabels(peopleSheetName: $peopleSheetName, rolesSheetName: "
      "$rolesSheetName, locationsSheetName: $locationsSheetName, elementsSheetName: "
      "$elementsSheetName)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    peopleSheetName,
    rolesSheetName,
    locationsSheetName,
    elementsSheetName,
    peopleColumnHeaders,
    rolesColumnHeaders,
    locationsColumnHeaders,
    elementsColumnHeaders,
    crewPositionLabels,
    roleKindLabels,
    imageRightsStatusLabels,
    permitStatusLabels,
    elementCategoryLabels,
    elementSourceKindLabels,
    dayPartSlotLabels,
    availabilityKindLabels,
    elementTrackingToSecureLabel,
    elementTrackingSecuredLabel,
    elementTrackingReadyLabel,
    elementTrackingReturnedLabel,
    everyDayLabel,
    weekdayLabels,
    sceneLabels,
  ];
}
