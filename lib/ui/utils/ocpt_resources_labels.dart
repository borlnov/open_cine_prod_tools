// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

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

/// The crew department of position [positionId] (one of `ocptCrewPositions`' ids), or null when
/// [positionId] is empty (a free-label assignment, which belongs to no department) or names a
/// position retired from the catalogue.
///
/// Used by the person sheet's positions card to show a `person_positions` row's muted department
/// column, derived rather than stored: `ocptCrewPositions` is the one place a position's
/// department is recorded.
OcptCrewDepartment? ocptCrewPositionDepartmentOf(String positionId) {
  for (final position in ocptCrewPositions) {
    if (position.id == positionId) {
      return position.department;
    }
  }
  return null;
}

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

/// The display label of [kind], what a location's availability window allows.
String ocptLocationAvailabilityKindLabel(Tr tr, OcptLocationAvailabilityKind kind) =>
    switch (kind) {
      OcptLocationAvailabilityKind.available => tr.resourcesAvailabilityKindAvailable,
      OcptLocationAvailabilityKind.conditional => tr.resourcesAvailabilityKindConditional,
    };

/// The display label of [slot], which part of each covered day a dated window takes — a person's
/// unavailability as much as a location's availability.
String ocptDayPartSlotLabel(Tr tr, OcptDayPartSlot slot) => switch (slot) {
  OcptDayPartSlot.fullDay => tr.resourcesSlotFullDay,
  OcptDayPartSlot.morning => tr.resourcesSlotMorning,
  OcptDayPartSlot.afternoon => tr.resourcesSlotAfternoon,
  OcptDayPartSlot.custom => tr.resourcesSlotCustom,
};

/// The display label of [status], where a person's image rights release stands.
String ocptImageRightsStatusLabel(Tr tr, OcptImageRightsStatus status) => switch (status) {
  OcptImageRightsStatus.notApplicable => tr.resourcesImageRightsNotApplicable,
  OcptImageRightsStatus.toGenerate => tr.resourcesImageRightsToGenerate,
  OcptImageRightsStatus.generated => tr.resourcesImageRightsGenerated,
  OcptImageRightsStatus.signed => tr.resourcesImageRightsSigned,
};

/// The display label of [status], where a location's filming permit stands.
String ocptPermitStatusLabel(Tr tr, OcptPermitStatus status) => switch (status) {
  OcptPermitStatus.notNeeded => tr.resourcesPermitNotNeeded,
  OcptPermitStatus.toRequest => tr.resourcesPermitToRequest,
  OcptPermitStatus.requested => tr.resourcesPermitRequested,
  OcptPermitStatus.granted => tr.resourcesPermitGranted,
  OcptPermitStatus.refused => tr.resourcesPermitRefused,
};

/// The colour the permit status [status] is painted with, in the left dock's list and on the
/// location sheet's own badge alike — a location is read at a glance by whether it may be shot at.
///
/// Follows the image rights card's own scale, for the same reason it does: `notNeeded` is the
/// neutral one and reads through `onSurfaceVariant`, a permit still to request or awaiting an
/// answer is the workspace's warning colour, a granted one is the "already shot" green, and a
/// refused one is the one genuine error of the five — the location cannot be used as planned.
Color ocptPermitStatusColor(BuildContext context, OcptPermitStatus status) {
  final theme = Theme.of(context);

  return switch (status) {
    OcptPermitStatus.notNeeded => theme.colorScheme.onSurfaceVariant,
    OcptPermitStatus.toRequest || OcptPermitStatus.requested => ocptWarningColor(context),
    OcptPermitStatus.granted =>
      theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary,
    OcptPermitStatus.refused => theme.colorScheme.error,
  };
}

/// The display label of the left dock tab [tab], shared by `OcptResourcesTabBar` (the tab strip
/// itself) and `OcptResourcesListPanel` (the list header title, and the placeholder line of a tab
/// with no content yet), so the two can never name the same tab differently.
String ocptResourcesTabLabel(Tr tr, OcptResourcesTab tab) => switch (tab) {
  OcptResourcesTab.people => tr.resourcesTabPeople,
  OcptResourcesTab.roles => tr.resourcesTabRoles,
  OcptResourcesTab.locations => tr.resourcesTabLocations,
  OcptResourcesTab.elements => tr.resourcesTabElements,
};

/// The display label of [kind], what kind of character a role is.
String ocptRoleKindLabel(Tr tr, OcptRoleKind kind) => switch (kind) {
  OcptRoleKind.speaking => tr.resourcesRoleKindSpeaking,
  OcptRoleKind.silent => tr.resourcesRoleKindSilent,
  OcptRoleKind.extra => tr.resourcesRoleKindExtra,
};
