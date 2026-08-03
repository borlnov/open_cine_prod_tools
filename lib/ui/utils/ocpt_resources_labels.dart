// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_half_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';

/// The placeholder shown in place of a resources field that has no value yet.
///
/// The resources mode's own instance of `ocptShotListEmptyValue`: an empty cell would read as a
/// rendering bug, an em dash reads as "nothing here yet". Shared by every widget of this mode —
/// the left dock lists and the person sheet alike — so the two never disagree on what "nothing"
/// looks like.
const ocptResourcesEmptyValue = "—";

/// The display label of the crew position [positionId] (one of `ocptCrewPositions`'
/// `OcptCrewPosition.id`s), resolved through its `labelKey`.
///
/// **A position added to `ocptCrewPositions` (`lib/constants/`) must be added here too**: the
/// catalogue itself stays free of `Tr`, so this exhaustive switch is the single place that pairs
/// every stable id with its localized label. An [positionId] this switch doesn't recognise (a
/// `person_positions` row whose `positionId` names a position retired from the catalogue, or a
/// row that was never one of these ids to begin with) falls back to [positionId] itself, so the
/// UI still shows *something* rather than going blank.
String ocptCrewPositionLabel(Tr tr, String positionId) => switch (positionId) {
  'director' => tr.resourcesCrewPositionDirector,
  'firstAssistantDirector' => tr.resourcesCrewPositionFirstAssistantDirector,
  'scriptSupervisor' => tr.resourcesCrewPositionScriptSupervisor,
  'directorOfPhotography' => tr.resourcesCrewPositionDirectorOfPhotography,
  'cameraOperator' => tr.resourcesCrewPositionCameraOperator,
  'firstAssistantCamera' => tr.resourcesCrewPositionFirstAssistantCamera,
  'gaffer' => tr.resourcesCrewPositionGaffer,
  'electrician' => tr.resourcesCrewPositionElectrician,
  'grip' => tr.resourcesCrewPositionGrip,
  'soundEngineer' => tr.resourcesCrewPositionSoundEngineer,
  'boomOperator' => tr.resourcesCrewPositionBoomOperator,
  'setDecorator' => tr.resourcesCrewPositionSetDecorator,
  'propsMaster' => tr.resourcesCrewPositionPropsMaster,
  'setDresser' => tr.resourcesCrewPositionSetDresser,
  'makeupArtist' => tr.resourcesCrewPositionMakeupArtist,
  'hairStylist' => tr.resourcesCrewPositionHairStylist,
  'costumeDesigner' => tr.resourcesCrewPositionCostumeDesigner,
  'productionManager' => tr.resourcesCrewPositionProductionManager,
  'productionAssistant' => tr.resourcesCrewPositionProductionAssistant,
  'lineProducer' => tr.resourcesCrewPositionLineProducer,
  _ => positionId,
};

/// The display label of the crew department [department], for grouping `ocptCrewPositions` in the
/// UI.
String ocptCrewDepartmentLabel(Tr tr, OcptCrewDepartment department) => switch (department) {
  OcptCrewDepartment.direction => tr.resourcesCrewDepartmentDirection,
  OcptCrewDepartment.image => tr.resourcesCrewDepartmentImage,
  OcptCrewDepartment.sound => tr.resourcesCrewDepartmentSound,
  OcptCrewDepartment.artDepartment => tr.resourcesCrewDepartmentArtDepartment,
  OcptCrewDepartment.hmc => tr.resourcesCrewDepartmentHmc,
  OcptCrewDepartment.production => tr.resourcesCrewDepartmentProduction,
};

/// The display label of [halfDay], how much of a day a `person_unavailabilities` row covers.
String ocptHalfDayLabel(Tr tr, OcptHalfDay halfDay) => switch (halfDay) {
  OcptHalfDay.full => tr.resourcesHalfDayFull,
  OcptHalfDay.morning => tr.resourcesHalfDayMorning,
  OcptHalfDay.afternoon => tr.resourcesHalfDayAfternoon,
};

/// The display label of [status], where a person's image rights release stands.
String ocptImageRightsStatusLabel(Tr tr, OcptImageRightsStatus status) => switch (status) {
  OcptImageRightsStatus.notApplicable => tr.resourcesImageRightsNotApplicable,
  OcptImageRightsStatus.toGenerate => tr.resourcesImageRightsToGenerate,
  OcptImageRightsStatus.generated => tr.resourcesImageRightsGenerated,
  OcptImageRightsStatus.signed => tr.resourcesImageRightsSigned,
};

/// The display label of the left dock tab [tab], shared by `OcptResourcesTabBar` (the tab strip
/// itself) and `OcptResourcesListPanel` (the list header title, and the placeholder line of a tab
/// with no content yet), so the two can never name the same tab differently.
String ocptResourcesTabLabel(Tr tr, OcptResourcesTab tab) => switch (tab) {
  OcptResourcesTab.people => tr.resourcesTabPeople,
  OcptResourcesTab.roles => tr.resourcesTabRoles,
  OcptResourcesTab.locations => tr.resourcesTabLocations,
  OcptResourcesTab.elements => tr.resourcesTabElements,
};
