// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_elements_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_locations_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_people_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_roles_xlsx_column.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_set_suggestion.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

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

/// The display label of [status], where one person stands in the casting of one part.
String ocptRoleCandidateStatusLabel(Tr tr, OcptRoleCandidateStatus status) => switch (status) {
  OcptRoleCandidateStatus.spotted => tr.resourcesRoleCandidateStatusSpotted,
  OcptRoleCandidateStatus.toMeet => tr.resourcesRoleCandidateStatusToMeet,
  OcptRoleCandidateStatus.seen => tr.resourcesRoleCandidateStatusSeen,
  OcptRoleCandidateStatus.shortlisted => tr.resourcesRoleCandidateStatusShortlisted,
  OcptRoleCandidateStatus.retained => tr.resourcesRoleCandidateStatusRetained,
  OcptRoleCandidateStatus.notRetained => tr.resourcesRoleCandidateStatusNotRetained,
  OcptRoleCandidateStatus.declined => tr.resourcesRoleCandidateStatusDeclined,
  OcptRoleCandidateStatus.unavailable => tr.resourcesRoleCandidateStatusUnavailable,
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

/// The display label of [category], the top-level grouping the elements list is organised by.
String ocptElementCategoryLabel(Tr tr, OcptElementCategory category) => switch (category) {
  OcptElementCategory.prop => tr.resourcesElementCategoryProp,
  OcptElementCategory.setDressing => tr.resourcesElementCategorySetDressing,
  OcptElementCategory.costume => tr.resourcesElementCategoryCostume,
  OcptElementCategory.makeup => tr.resourcesElementCategoryMakeup,
  OcptElementCategory.vehicle => tr.resourcesElementCategoryVehicle,
  OcptElementCategory.animal => tr.resourcesElementCategoryAnimal,
  OcptElementCategory.specialEquipment => tr.resourcesElementCategorySpecialEquipment,
  OcptElementCategory.camera => tr.resourcesElementCategoryCamera,
  OcptElementCategory.lighting => tr.resourcesElementCategoryLighting,
  OcptElementCategory.sound => tr.resourcesElementCategorySound,
  OcptElementCategory.production => tr.resourcesElementCategoryProduction,
  OcptElementCategory.catering => tr.resourcesElementCategoryCatering,
  OcptElementCategory.extras => tr.resourcesElementCategoryExtras,
  OcptElementCategory.other => tr.resourcesElementCategoryOther,
};

/// The display label of [sourceKind], where an element comes from or is going to.
String ocptElementSourceKindLabel(Tr tr, OcptElementSourceKind sourceKind) => switch (sourceKind) {
  OcptElementSourceKind.owned => tr.resourcesElementSourceOwned,
  OcptElementSourceKind.borrowed => tr.resourcesElementSourceBorrowed,
  OcptElementSourceKind.rented => tr.resourcesElementSourceRented,
  OcptElementSourceKind.toBuy => tr.resourcesElementSourceToBuy,
  OcptElementSourceKind.toMake => tr.resourcesElementSourceToMake,
  OcptElementSourceKind.alreadyOnSet => tr.resourcesElementSourceAlreadyOnSet,
};

/// How far along [element] is, read off its three tracking flags: the one thing about an item that
/// decides whether it is still a problem.
///
/// Derived rather than stored, exactly as a person's age is: the flags are the answers the user
/// gives, and this is the sentence they add up to. They are read **in the order the shoot goes
/// through them** and the last one ticked wins, so an item that came back reads as returned rather
/// than as ready, whatever the earlier boxes still say.
String ocptElementTrackingLabel(Tr tr, OcptElement element) {
  if (element.isReturned) {
    return tr.resourcesElementTrackingReturned;
  }
  if (element.isReadyForShoot) {
    return tr.resourcesElementTrackingReady;
  }
  if (element.isSecured) {
    return tr.resourcesElementTrackingSecured;
  }

  return tr.resourcesElementTrackingToSecure;
}

/// The colour [ocptElementTrackingLabel]'s answer is painted with, in the left dock's list and on
/// the element sheet's own badge alike.
///
/// Follows the permit status' own scale, for the same reason it does: an item still to secure is
/// the workspace's warning colour — it is the one that loses a shooting day — a ready one is the
/// "already shot" green, and the two states either side of them are neutral. Nothing here is an
/// error: an element the production simply has not found yet is an ordinary Tuesday.
Color ocptElementTrackingColor(BuildContext context, OcptElement element) {
  final theme = Theme.of(context);

  if (element.isReturned) {
    return theme.colorScheme.onSurfaceVariant;
  }
  if (element.isReadyForShoot) {
    return theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary;
  }
  if (element.isSecured) {
    return theme.colorScheme.onSurfaceVariant;
  }

  return ocptWarningColor(context);
}

/// How [scene] reads wherever the resources mode names one outside the screenplay — on a set's
/// chips, on an element's own scene rows, and in the pickers adding either: its number, then the
/// place its heading names.
///
/// The interior/exterior prefix and the time of day are left out: neither says *where*, and a chip
/// has room for one of the three. A heading that names no place at all (a bare `INT.`) keeps its
/// own text rather than reading as a number alone.
String ocptSceneRefLabel(OcptSceneRef scene) {
  final place = ocptSceneHeadingPlaceOf(scene.heading);
  return "${scene.displayNumber} · ${place.isEmpty ? scene.heading : place}";
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

/// The header label of the exported crew & cast directory sheet's column [column].
String ocptPeopleXlsxColumnLabel(Tr tr, OcptPeopleXlsxColumn column) => switch (column) {
  OcptPeopleXlsxColumn.name => tr.resourcesXlsxColumnName,
  OcptPeopleXlsxColumn.positions => tr.resourcesXlsxColumnPositions,
  OcptPeopleXlsxColumn.roles => tr.resourcesXlsxColumnRoles,
  OcptPeopleXlsxColumn.email => tr.resourcesXlsxColumnEmail,
  OcptPeopleXlsxColumn.phone => tr.resourcesXlsxColumnPhone,
  OcptPeopleXlsxColumn.addressLine1 => tr.resourcesXlsxColumnAddressLine1,
  OcptPeopleXlsxColumn.addressLine2 => tr.resourcesXlsxColumnAddressLine2,
  OcptPeopleXlsxColumn.postalCode => tr.resourcesXlsxColumnPostalCode,
  OcptPeopleXlsxColumn.city => tr.resourcesXlsxColumnCity,
  OcptPeopleXlsxColumn.region => tr.resourcesXlsxColumnRegion,
  OcptPeopleXlsxColumn.country => tr.resourcesXlsxColumnCountry,
  OcptPeopleXlsxColumn.birthDate => tr.resourcesXlsxColumnBirthDate,
  OcptPeopleXlsxColumn.age => tr.resourcesXlsxColumnAge,
  OcptPeopleXlsxColumn.minorNotes => tr.resourcesXlsxColumnMinorNotes,
  OcptPeopleXlsxColumn.transportAutonomy => tr.resourcesXlsxColumnTransportAutonomy,
  OcptPeopleXlsxColumn.accommodationNotes => tr.resourcesXlsxColumnAccommodationNotes,
  OcptPeopleXlsxColumn.travelNotes => tr.resourcesXlsxColumnTravelNotes,
  OcptPeopleXlsxColumn.dietaryNotes => tr.resourcesXlsxColumnDietaryNotes,
  OcptPeopleXlsxColumn.allergies => tr.resourcesXlsxColumnAllergies,
  OcptPeopleXlsxColumn.skills => tr.resourcesXlsxColumnSkills,
  OcptPeopleXlsxColumn.height => tr.resourcesXlsxColumnHeight,
  OcptPeopleXlsxColumn.chest => tr.resourcesXlsxColumnChest,
  OcptPeopleXlsxColumn.waist => tr.resourcesXlsxColumnWaist,
  OcptPeopleXlsxColumn.hips => tr.resourcesXlsxColumnHips,
  OcptPeopleXlsxColumn.topSize => tr.resourcesXlsxColumnTopSize,
  OcptPeopleXlsxColumn.bottomSize => tr.resourcesXlsxColumnBottomSize,
  OcptPeopleXlsxColumn.shoeSize => tr.resourcesXlsxColumnShoeSize,
  OcptPeopleXlsxColumn.hmcNotes => tr.resourcesXlsxColumnHmcNotes,
  OcptPeopleXlsxColumn.imageRightsStatus => tr.resourcesXlsxColumnImageRightsStatus,
  OcptPeopleXlsxColumn.imageRightsDate => tr.resourcesXlsxColumnImageRightsDate,
  OcptPeopleXlsxColumn.unavailabilities => tr.resourcesXlsxColumnUnavailabilities,
  OcptPeopleXlsxColumn.notes => tr.resourcesXlsxColumnNotes,
};

/// The header label of the exported roles sheet's column [column].
String ocptRolesXlsxColumnLabel(Tr tr, OcptRolesXlsxColumn column) => switch (column) {
  OcptRolesXlsxColumn.number => tr.resourcesXlsxColumnNumber,
  OcptRolesXlsxColumn.name => tr.resourcesXlsxColumnName,
  OcptRolesXlsxColumn.kind => tr.resourcesXlsxColumnKind,
  OcptRolesXlsxColumn.castMember => tr.resourcesXlsxColumnCastMember,
  OcptRolesXlsxColumn.fromScreenplay => tr.resourcesXlsxColumnFromScreenplay,
  OcptRolesXlsxColumn.removedFromScreenplay => tr.resourcesXlsxColumnRemovedFromScreenplay,
  OcptRolesXlsxColumn.castingNotes => tr.resourcesXlsxColumnCastingNotes,
};

/// The header label of the exported locations & sets sheet's column [column].
String ocptLocationsXlsxColumnLabel(Tr tr, OcptLocationsXlsxColumn column) => switch (column) {
  OcptLocationsXlsxColumn.locationName => tr.resourcesXlsxColumnLocationName,
  OcptLocationsXlsxColumn.setCode => tr.resourcesXlsxColumnSetCode,
  OcptLocationsXlsxColumn.setName => tr.resourcesXlsxColumnSetName,
  OcptLocationsXlsxColumn.setScenes => tr.resourcesXlsxColumnScenes,
  OcptLocationsXlsxColumn.addressLine1 => tr.resourcesXlsxColumnAddressLine1,
  OcptLocationsXlsxColumn.addressLine2 => tr.resourcesXlsxColumnAddressLine2,
  OcptLocationsXlsxColumn.postalCode => tr.resourcesXlsxColumnPostalCode,
  OcptLocationsXlsxColumn.city => tr.resourcesXlsxColumnCity,
  OcptLocationsXlsxColumn.region => tr.resourcesXlsxColumnRegion,
  OcptLocationsXlsxColumn.country => tr.resourcesXlsxColumnCountry,
  OcptLocationsXlsxColumn.latitude => tr.resourcesXlsxColumnLatitude,
  OcptLocationsXlsxColumn.longitude => tr.resourcesXlsxColumnLongitude,
  OcptLocationsXlsxColumn.contact => tr.resourcesXlsxColumnContact,
  OcptLocationsXlsxColumn.contactNotes => tr.resourcesXlsxColumnContactNotes,
  OcptLocationsXlsxColumn.permitStatus => tr.resourcesXlsxColumnPermitStatus,
  OcptLocationsXlsxColumn.permitLabel => tr.resourcesXlsxColumnPermitLabel,
  OcptLocationsXlsxColumn.permitDate => tr.resourcesXlsxColumnPermitDate,
  OcptLocationsXlsxColumn.availabilityWindows => tr.resourcesXlsxColumnAvailabilityWindows,
  OcptLocationsXlsxColumn.parkingNotes => tr.resourcesXlsxColumnParkingNotes,
  OcptLocationsXlsxColumn.powerNotes => tr.resourcesXlsxColumnPowerNotes,
  OcptLocationsXlsxColumn.facilitiesNotes => tr.resourcesXlsxColumnFacilitiesNotes,
  OcptLocationsXlsxColumn.constraintsNotes => tr.resourcesXlsxColumnConstraintsNotes,
  OcptLocationsXlsxColumn.notes => tr.resourcesXlsxColumnNotes,
};

/// The header label of the exported elements sheet's column [column].
///
/// [currencyCode] is only read by [OcptElementsXlsxColumn.cost], whose header names the project's
/// currency (`Cost (EUR)`) so the workbook reads correctly once it has left the app that produced
/// it.
String ocptElementsXlsxColumnLabel(
  Tr tr,
  OcptElementsXlsxColumn column, {
  required String currencyCode,
}) => switch (column) {
  OcptElementsXlsxColumn.category => tr.resourcesXlsxColumnCategory,
  OcptElementsXlsxColumn.subCategory => tr.resourcesXlsxColumnSubCategory,
  OcptElementsXlsxColumn.code => tr.resourcesXlsxColumnCode,
  OcptElementsXlsxColumn.name => tr.resourcesXlsxColumnName,
  OcptElementsXlsxColumn.quantity => tr.resourcesXlsxColumnQuantity,
  OcptElementsXlsxColumn.sourceKind => tr.resourcesXlsxColumnSourceKind,
  OcptElementsXlsxColumn.owner => tr.resourcesXlsxColumnOwner,
  OcptElementsXlsxColumn.ownerNotes => tr.resourcesXlsxColumnOwnerNotes,
  OcptElementsXlsxColumn.broughtBy => tr.resourcesXlsxColumnBroughtBy,
  OcptElementsXlsxColumn.storageNotes => tr.resourcesXlsxColumnStorageNotes,
  OcptElementsXlsxColumn.secured => tr.resourcesXlsxColumnSecured,
  OcptElementsXlsxColumn.ready => tr.resourcesXlsxColumnReady,
  OcptElementsXlsxColumn.returned => tr.resourcesXlsxColumnReturned,
  OcptElementsXlsxColumn.trackingStatus => tr.resourcesXlsxColumnTrackingStatus,
  OcptElementsXlsxColumn.cost => tr.resourcesXlsxColumnCost(currencyCode),
  OcptElementsXlsxColumn.scenes => tr.resourcesXlsxColumnScenes,
  OcptElementsXlsxColumn.purposeNotes => tr.resourcesXlsxColumnPurposeNotes,
  OcptElementsXlsxColumn.notes => tr.resourcesXlsxColumnNotes,
};

/// Builds every localized string the exported resources workbook carries, for the [scenes] a set's
/// or an element's own scene column names.
///
/// This is the single bridge between the UI's `Tr` and `OcptResourcesXlsxExportService`, which runs
/// in the manager layer and has no `BuildContext` to resolve anything of its own — mirroring
/// `ocptShotListXlsxLabelsOf`. Every enum label map reuses the very `ocpt…Label` helpers this file
/// already exposes to the four tabs' own widgets, so the workbook can never name a status
/// differently from the screen. [scenes] is resolved into [OcptResourcesXlsxLabels.sceneLabels]
/// through `ocptSceneRefLabel`, since that helper lives here rather than under `lib/managers/`.
///
/// Takes the [context] rather than a `Tr` alone, unlike its shot list sibling: the weekday names an
/// availability window is described with come from the locale's own calendar data through
/// [DateFormat], the way the dated-window controls already format a date, rather than from seven
/// ARB keys translating what every locale already knows.
///
/// [currencyCode] is the project's own currency, an ISO 4217 code read off `OcptResourcesState`:
/// resolving it is this function's job precisely so `OcptResourcesXlsxExportService` never has to
/// learn what a currency is beyond the header string it is handed.
OcptResourcesXlsxLabels ocptResourcesXlsxLabelsOf(
  BuildContext context,
  List<OcptSceneRef> scenes, {
  required String currencyCode,
}) {
  final tr = Tr.of(context);

  return OcptResourcesXlsxLabels(
    fileNameSuffix: tr.resourcesExportXlsxFileNameSuffix,
    peopleSheetName: tr.resourcesExportXlsxPeopleSheetName,
    rolesSheetName: tr.resourcesExportXlsxRolesSheetName,
    locationsSheetName: tr.resourcesExportXlsxLocationsSheetName,
    elementsSheetName: tr.resourcesExportXlsxElementsSheetName,
    peopleColumnHeaders: {
      for (final column in OcptPeopleXlsxColumn.values)
        column: ocptPeopleXlsxColumnLabel(tr, column),
    },
    rolesColumnHeaders: {
      for (final column in OcptRolesXlsxColumn.values)
        column: ocptRolesXlsxColumnLabel(tr, column),
    },
    locationsColumnHeaders: {
      for (final column in OcptLocationsXlsxColumn.values)
        column: ocptLocationsXlsxColumnLabel(tr, column),
    },
    elementsColumnHeaders: {
      for (final column in OcptElementsXlsxColumn.values)
        column: ocptElementsXlsxColumnLabel(tr, column, currencyCode: currencyCode),
    },
    crewPositionLabels: {
      for (final position in ocptCrewPositions)
        position.id: ocptCrewPositionLabel(tr, position.id),
    },
    roleKindLabels: {for (final kind in OcptRoleKind.values) kind: ocptRoleKindLabel(tr, kind)},
    imageRightsStatusLabels: {
      for (final status in OcptImageRightsStatus.values)
        status: ocptImageRightsStatusLabel(tr, status),
    },
    permitStatusLabels: {
      for (final status in OcptPermitStatus.values) status: ocptPermitStatusLabel(tr, status),
    },
    elementCategoryLabels: {
      for (final category in OcptElementCategory.values)
        category: ocptElementCategoryLabel(tr, category),
    },
    elementSourceKindLabels: {
      for (final sourceKind in OcptElementSourceKind.values)
        sourceKind: ocptElementSourceKindLabel(tr, sourceKind),
    },
    dayPartSlotLabels: {
      for (final slot in OcptDayPartSlot.values) slot: ocptDayPartSlotLabel(tr, slot),
    },
    availabilityKindLabels: {
      for (final kind in OcptLocationAvailabilityKind.values)
        kind: ocptLocationAvailabilityKindLabel(tr, kind),
    },
    elementTrackingToSecureLabel: tr.resourcesElementTrackingToSecure,
    elementTrackingSecuredLabel: tr.resourcesElementTrackingSecured,
    elementTrackingReadyLabel: tr.resourcesElementTrackingReady,
    elementTrackingReturnedLabel: tr.resourcesElementTrackingReturned,
    everyDayLabel: tr.resourcesXlsxAvailabilityEveryDay,
    weekdayLabels: _weekdayLabelsOf(context),
    sceneLabels: {for (final scene in scenes) scene.id: ocptSceneRefLabel(scene)},
  );
}

/// Builds every localized string the exported contact list carries.
///
/// This is the single bridge between the UI's `Tr` and `OcptContactListPdfService`, which runs in
/// the manager layer and has no `BuildContext` to resolve anything of its own — mirroring
/// `ocptResourcesXlsxLabelsOf`. Its department and position maps reuse the very
/// `ocptCrewDepartmentLabel`/`ocptCrewPositionLabel` helpers this file already exposes to the
/// person sheet's own positions card, so the printed list can never name either differently from
/// the screen.
OcptContactListLabels ocptContactListLabelsOf(BuildContext context) {
  final tr = Tr.of(context);

  return OcptContactListLabels(
    fileNameSuffix: tr.resourcesExportContactListFileNameSuffix,
    documentTitle: tr.resourcesExportContactListDocumentTitle,
    versionLabel: tr.resourcesExportContactListVersionLabel,
    crewSectionTitle: tr.resourcesExportContactListCrewSectionTitle,
    castSectionTitle: tr.resourcesExportContactListCastSectionTitle,
    nameHeader: tr.resourcesExportContactListNameHeader,
    positionHeader: tr.resourcesExportContactListPositionHeader,
    phoneHeader: tr.resourcesExportContactListPhoneHeader,
    emailHeader: tr.resourcesExportContactListEmailHeader,
    crewDepartmentLabels: {
      for (final department in OcptCrewDepartment.values)
        department: ocptCrewDepartmentLabel(tr, department),
    },
    crewPositionLabels: {
      for (final position in ocptCrewPositions) position.id: ocptCrewPositionLabel(tr, position.id),
    },
    unassignedDepartmentLabel: tr.resourcesExportContactListUnassignedDepartmentLabel,
    emptyDocumentNote: tr.resourcesExportContactListEmptyDocumentNote,
  );
}

/// The name of every day of the week in [context]'s own locale, keyed by its
/// `DateTime.monday`…`DateTime.sunday` number.
///
/// Formatted off a reference week (2024-01-01 was a Monday) rather than off today, so the seven
/// names are always the seven weekdays whatever day this runs on. The short form is what a
/// spreadsheet cell listing several of them has room for, and it stays unambiguous where
/// `MaterialLocalizations.narrowWeekdays`' single letters would not.
Map<int, String> _weekdayLabelsOf(BuildContext context) {
  final format = DateFormat.E(Localizations.localeOf(context).toString());
  final firstMonday = DateTime(2024);

  return {
    for (final weekday in ocptWeekdays)
      weekday: format.format(firstMonday.add(Duration(days: weekday - DateTime.monday))),
  };
}
