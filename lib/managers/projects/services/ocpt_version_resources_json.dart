// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_production_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_reader.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// The JSON shape of the people, roles, locations, sets, elements, assets, casting candidates,
/// dictionary words and field version rows in a version's payload: one serializer and one parser
/// per table, mirroring its columns.
abstract final class OcptVersionResourcesJson {
  /// Serialize one `people` row.
  static Map<String, dynamic> personToJson(OcptPersonRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonKeys.firstNameKey: row.firstName,
    OcptVersionJsonKeys.lastNameKey: row.lastName,
    OcptVersionJsonKeys.emailKey: row.email,
    OcptVersionJsonKeys.phoneKey: row.phone,
    OcptVersionJsonKeys.addressLine1Key: row.addressLine1,
    OcptVersionJsonKeys.addressLine2Key: row.addressLine2,
    OcptVersionJsonKeys.postalCodeKey: row.postalCode,
    OcptVersionJsonKeys.cityKey: row.city,
    OcptVersionJsonKeys.regionKey: row.region,
    OcptVersionJsonKeys.countryKey: row.country,
    OcptVersionJsonKeys.colorIndexKey: row.colorIndex,
    OcptVersionJsonKeys.birthDateKey: row.birthDate?.toIso8601String(),
    OcptVersionJsonKeys.minorNotesKey: row.minorNotes,
    OcptVersionJsonKeys.maxDailyPresenceMinutesKey: row.maxDailyPresenceMinutes,
    OcptVersionJsonKeys.isTransportAutonomousKey: row.isTransportAutonomous,
    OcptVersionJsonKeys.accommodationNotesKey: row.accommodationNotes,
    OcptVersionJsonKeys.travelNotesKey: row.travelNotes,
    OcptVersionJsonKeys.dietaryNotesKey: row.dietaryNotes,
    OcptVersionJsonKeys.allergiesKey: row.allergies,
    OcptVersionJsonKeys.measurementHeightKey: row.measurementHeight,
    OcptVersionJsonKeys.measurementChestKey: row.measurementChest,
    OcptVersionJsonKeys.measurementWaistKey: row.measurementWaist,
    OcptVersionJsonKeys.measurementHipsKey: row.measurementHips,
    OcptVersionJsonKeys.sizeTopKey: row.sizeTop,
    OcptVersionJsonKeys.sizeBottomKey: row.sizeBottom,
    OcptVersionJsonKeys.sizeShoesKey: row.sizeShoes,
    OcptVersionJsonKeys.hmcNotesKey: row.hmcNotes,
    OcptVersionJsonKeys.imageRightsStatusKey: row.imageRightsStatus.name,
    OcptVersionJsonKeys.imageRightsDateKey: row.imageRightsDate?.toIso8601String(),
    OcptVersionJsonKeys.imageRightsAssetIdKey: row.imageRightsAssetId,
    OcptVersionJsonKeys.photoAssetIdKey: row.photoAssetId,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonProductionKeys.commuteKmMilliKey: row.commuteKmMilli,
    OcptVersionJsonProductionKeys.mileageRateIdKey: row.mileageRateId,
  };

  /// Parse one `people` row.
  static OcptPersonRow personFromJson(Map<String, dynamic> json) => OcptPersonRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
    firstName: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.firstNameKey),
    lastName: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.lastNameKey),
    email: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.emailKey),
    phone: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.phoneKey),
    addressLine1: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.addressLine1Key),
    addressLine2: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.addressLine2Key),
    postalCode: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.postalCodeKey),
    city: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.cityKey),
    region: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.regionKey),
    country: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.countryKey),
    colorIndex: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.colorIndexKey),
    birthDate: OcptVersionJsonReader.readNullableDateTime(json, OcptVersionJsonKeys.birthDateKey),
    minorNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.minorNotesKey),
    maxDailyPresenceMinutes: OcptVersionJsonReader.readNullableInt(
      json,
      OcptVersionJsonKeys.maxDailyPresenceMinutesKey,
    ),
    isTransportAutonomous: OcptVersionJsonReader.readNullableBool(
      json,
      OcptVersionJsonKeys.isTransportAutonomousKey,
    ),
    accommodationNotes: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonKeys.accommodationNotesKey,
    ),
    travelNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.travelNotesKey),
    dietaryNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.dietaryNotesKey),
    allergies: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.allergiesKey),
    measurementHeight: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonKeys.measurementHeightKey,
    ),
    measurementChest: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonKeys.measurementChestKey,
    ),
    measurementWaist: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonKeys.measurementWaistKey,
    ),
    measurementHips: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.measurementHipsKey),
    sizeTop: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sizeTopKey),
    sizeBottom: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sizeBottomKey),
    sizeShoes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sizeShoesKey),
    hmcNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.hmcNotesKey),
    imageRightsStatus: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonKeys.imageRightsStatusKey,
      OcptImageRightsStatus.values.asNameMap(),
    ),
    imageRightsDate: OcptVersionJsonReader.readNullableDateTime(
      json,
      OcptVersionJsonKeys.imageRightsDateKey,
    ),
    imageRightsAssetId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonKeys.imageRightsAssetIdKey,
    ),
    photoAssetId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonKeys.photoAssetIdKey,
    ),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
    commuteKmMilli: OcptVersionJsonReader.readNullableInt(
      json,
      OcptVersionJsonProductionKeys.commuteKmMilliKey,
    ),
    mileageRateId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.mileageRateIdKey,
    ),
  );

  /// Serialize one `person_positions` row.
  static Map<String, dynamic> personPositionToJson(OcptPersonPositionRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.positionIdKey: row.positionId,
    OcptVersionJsonKeys.customLabelKey: row.customLabel,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `person_positions` row.
  static OcptPersonPositionRow personPositionFromJson(Map<String, dynamic> json) =>
      OcptPersonPositionRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        personId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.personIdKey),
        positionId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.positionIdKey),
        customLabel: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.customLabelKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `person_skills` row.
  static Map<String, dynamic> personSkillToJson(OcptPersonSkillRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `person_skills` row.
  static OcptPersonSkillRow personSkillFromJson(Map<String, dynamic> json) => OcptPersonSkillRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    personId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.personIdKey),
    label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `person_unavailabilities` row.
  static Map<String, dynamic> personUnavailabilityToJson(OcptPersonUnavailabilityRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.startDateKey: row.startDate.toIso8601String(),
    OcptVersionJsonKeys.endDateKey: row.endDate.toIso8601String(),
    OcptVersionJsonKeys.slotKey: row.slot.name,
    OcptVersionJsonKeys.startMinuteKey: row.startMinute,
    OcptVersionJsonKeys.endMinuteKey: row.endMinute,
    OcptVersionJsonKeys.reasonKey: row.reason,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `person_unavailabilities` row.
  static OcptPersonUnavailabilityRow personUnavailabilityFromJson(Map<String, dynamic> json) =>
      OcptPersonUnavailabilityRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        personId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.personIdKey),
        startDate: OcptVersionJsonReader.readDateTime(json, OcptVersionJsonKeys.startDateKey),
        endDate: OcptVersionJsonReader.readDateTime(json, OcptVersionJsonKeys.endDateKey),
        slot: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.slotKey,
          OcptDayPartSlot.values.asNameMap(),
        ),
        startMinute: OcptVersionJsonReader.readNullableInt(
          json,
          OcptVersionJsonKeys.startMinuteKey,
        ),
        endMinute: OcptVersionJsonReader.readNullableInt(json, OcptVersionJsonKeys.endMinuteKey),
        reason: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.reasonKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `roles` row.
  static Map<String, dynamic> roleToJson(OcptRoleRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.nameKey: row.name,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.kindKey: row.kind.name,
    OcptVersionJsonKeys.isFromScreenplayKey: row.isFromScreenplay,
    OcptVersionJsonKeys.orphanedNameKey: row.orphanedName,
    OcptVersionJsonKeys.castingNotesKey: row.castingNotes,
  };

  /// Parse one `roles` row.
  static OcptRoleRow roleFromJson(Map<String, dynamic> json) => OcptRoleRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    name: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.nameKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
    personId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.personIdKey),
    kind: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonKeys.kindKey,
      OcptRoleKind.values.asNameMap(),
    ),
    isFromScreenplay: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isFromScreenplayKey),
    orphanedName: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonKeys.orphanedNameKey,
    ),
    castingNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.castingNotesKey),
  );

  /// Serialize one `role_episodes` row: the same shape of link row `scene_sets` is
  /// ([sceneSetToJson]) — id, two foreign keys, tombstone, no `sortKey`, since which episodes name
  /// a role is an unordered set of answers rather than a list the user reorders
  /// (`OcptRoleEpisodesTable`'s own doc comment).
  static Map<String, dynamic> roleEpisodeToJson(OcptRoleEpisodeRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.roleIdKey: row.roleId,
    OcptVersionJsonKeys.screenplayIdKey: row.screenplayId,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `role_episodes` row.
  static OcptRoleEpisodeRow roleEpisodeFromJson(Map<String, dynamic> json) => OcptRoleEpisodeRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    roleId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.roleIdKey),
    screenplayId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.screenplayIdKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `project_dictionary_words` row: id, the word as it was typed, tombstone — no
  /// `sortKey`, for the reason `OcptProjectDictionaryWordsTable`'s own doc comment gives (an
  /// unordered set a writer builds up, not a list they arrange).
  static Map<String, dynamic> projectDictionaryWordToJson(OcptProjectDictionaryWordRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.wordKey: row.word,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `project_dictionary_words` row.
  static OcptProjectDictionaryWordRow projectDictionaryWordFromJson(Map<String, dynamic> json) =>
      OcptProjectDictionaryWordRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        word: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.wordKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `locations` row.
  static Map<String, dynamic> locationToJson(OcptLocationRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.nameKey: row.name,
    OcptVersionJsonKeys.colorIndexKey: row.colorIndex,
    OcptVersionJsonKeys.addressLine1Key: row.addressLine1,
    OcptVersionJsonKeys.addressLine2Key: row.addressLine2,
    OcptVersionJsonKeys.postalCodeKey: row.postalCode,
    OcptVersionJsonKeys.cityKey: row.city,
    OcptVersionJsonKeys.regionKey: row.region,
    OcptVersionJsonKeys.countryKey: row.country,
    OcptVersionJsonKeys.latitudeKey: row.latitude,
    OcptVersionJsonKeys.longitudeKey: row.longitude,
    OcptVersionJsonKeys.contactPersonIdKey: row.contactPersonId,
    OcptVersionJsonKeys.contactNotesKey: row.contactNotes,
    OcptVersionJsonKeys.permitStatusKey: row.permitStatus.name,
    OcptVersionJsonKeys.permitLabelKey: row.permitLabel,
    OcptVersionJsonKeys.permitDateKey: row.permitDate?.toIso8601String(),
    OcptVersionJsonKeys.permitAssetIdKey: row.permitAssetId,
    OcptVersionJsonKeys.parkingNotesKey: row.parkingNotes,
    OcptVersionJsonKeys.powerNotesKey: row.powerNotes,
    OcptVersionJsonKeys.facilitiesNotesKey: row.facilitiesNotes,
    OcptVersionJsonKeys.constraintsNotesKey: row.constraintsNotes,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `locations` row.
  static OcptLocationRow locationFromJson(Map<String, dynamic> json) => OcptLocationRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    name: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.nameKey),
    colorIndex: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.colorIndexKey),
    addressLine1: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.addressLine1Key),
    addressLine2: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.addressLine2Key),
    postalCode: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.postalCodeKey),
    city: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.cityKey),
    region: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.regionKey),
    country: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.countryKey),
    latitude: OcptVersionJsonReader.readNullableDouble(json, OcptVersionJsonKeys.latitudeKey),
    longitude: OcptVersionJsonReader.readNullableDouble(json, OcptVersionJsonKeys.longitudeKey),
    contactPersonId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonKeys.contactPersonIdKey,
    ),
    contactNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.contactNotesKey),
    permitStatus: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonKeys.permitStatusKey,
      OcptPermitStatus.values.asNameMap(),
    ),
    permitLabel: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.permitLabelKey),
    permitDate: OcptVersionJsonReader.readNullableDateTime(json, OcptVersionJsonKeys.permitDateKey),
    permitAssetId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonKeys.permitAssetIdKey,
    ),
    parkingNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.parkingNotesKey),
    powerNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.powerNotesKey),
    facilitiesNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.facilitiesNotesKey),
    constraintsNotes: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonKeys.constraintsNotesKey,
    ),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `location_availabilities` row.
  static Map<String, dynamic> locationAvailabilityToJson(OcptLocationAvailabilityRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.locationIdKey: row.locationId,
    OcptVersionJsonKeys.startDateKey: row.startDate.toIso8601String(),
    OcptVersionJsonKeys.endDateKey: row.endDate.toIso8601String(),
    OcptVersionJsonKeys.weekdaysKey: row.weekdays,
    OcptVersionJsonKeys.slotKey: row.slot.name,
    OcptVersionJsonKeys.startMinuteKey: row.startMinute,
    OcptVersionJsonKeys.endMinuteKey: row.endMinute,
    OcptVersionJsonKeys.kindKey: row.kind.name,
    OcptVersionJsonKeys.noteKey: row.note,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `location_availabilities` row.
  static OcptLocationAvailabilityRow locationAvailabilityFromJson(Map<String, dynamic> json) =>
      OcptLocationAvailabilityRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        locationId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.locationIdKey),
        startDate: OcptVersionJsonReader.readDateTime(json, OcptVersionJsonKeys.startDateKey),
        endDate: OcptVersionJsonReader.readDateTime(json, OcptVersionJsonKeys.endDateKey),
        weekdays: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.weekdaysKey),
        slot: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.slotKey,
          OcptDayPartSlot.values.asNameMap(),
        ),
        startMinute: OcptVersionJsonReader.readNullableInt(
          json,
          OcptVersionJsonKeys.startMinuteKey,
        ),
        endMinute: OcptVersionJsonReader.readNullableInt(json, OcptVersionJsonKeys.endMinuteKey),
        kind: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.kindKey,
          OcptLocationAvailabilityKind.values.asNameMap(),
        ),
        note: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.noteKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `sets` row.
  static Map<String, dynamic> setToJson(OcptSetRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.locationIdKey: row.locationId,
    OcptVersionJsonKeys.codeKey: row.code,
    OcptVersionJsonKeys.nameKey: row.name,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `sets` row.
  static OcptSetRow setFromJson(Map<String, dynamic> json) => OcptSetRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    locationId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.locationIdKey),
    code: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.codeKey),
    name: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.nameKey),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `scene_sets` row.
  static Map<String, dynamic> sceneSetToJson(OcptSceneSetRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sceneIdKey: row.sceneId,
    OcptVersionJsonProductionKeys.setIdKey: row.setId,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `scene_sets` row.
  static OcptSceneSetRow sceneSetFromJson(Map<String, dynamic> json) => OcptSceneSetRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    sceneId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sceneIdKey),
    setId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.setIdKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `elements` row.
  static Map<String, dynamic> elementToJson(OcptElementRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonProductionKeys.categoryKey: row.category.name,
    OcptVersionJsonProductionKeys.subCategoryKey: row.subCategory,
    OcptVersionJsonKeys.nameKey: row.name,
    OcptVersionJsonKeys.codeKey: row.code,
    OcptVersionJsonProductionKeys.quantityKey: row.quantity,
    OcptVersionJsonProductionKeys.sourceKindKey: row.sourceKind.name,
    OcptVersionJsonProductionKeys.ownerPersonIdKey: row.ownerPersonId,
    OcptVersionJsonProductionKeys.ownerNotesKey: row.ownerNotes,
    OcptVersionJsonProductionKeys.broughtByPersonIdKey: row.broughtByPersonId,
    OcptVersionJsonProductionKeys.storageNotesKey: row.storageNotes,
    OcptVersionJsonKeys.statusKey: row.status.name,
    OcptVersionJsonProductionKeys.isSecuredKey: row.isSecured,
    OcptVersionJsonProductionKeys.isReadyForShootKey: row.isReadyForShoot,
    OcptVersionJsonProductionKeys.isReturnedKey: row.isReturned,
    OcptVersionJsonProductionKeys.costKey: row.cost,
    OcptVersionJsonProductionKeys.purposeNotesKey: row.purposeNotes,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.photoAssetIdKey: row.photoAssetId,
  };

  /// Parse one `elements` row.
  static OcptElementRow elementFromJson(Map<String, dynamic> json) => OcptElementRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
    category: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonProductionKeys.categoryKey,
      OcptElementCategory.values.asNameMap(),
    ),
    subCategory: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonProductionKeys.subCategoryKey,
    ),
    name: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.nameKey),
    code: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.codeKey),
    quantity: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.quantityKey),
    sourceKind: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonProductionKeys.sourceKindKey,
      OcptElementSourceKind.values.asNameMap(),
    ),
    ownerPersonId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.ownerPersonIdKey,
    ),
    ownerNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.ownerNotesKey),
    broughtByPersonId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.broughtByPersonIdKey,
    ),
    storageNotes: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonProductionKeys.storageNotesKey,
    ),
    status: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonKeys.statusKey,
      OcptElementStatus.values.asNameMap(),
    ),
    isSecured: OcptVersionJsonReader.readBool(json, OcptVersionJsonProductionKeys.isSecuredKey),
    isReadyForShoot: OcptVersionJsonReader.readBool(
      json,
      OcptVersionJsonProductionKeys.isReadyForShootKey,
    ),
    isReturned: OcptVersionJsonReader.readBool(json, OcptVersionJsonProductionKeys.isReturnedKey),
    cost: OcptVersionJsonReader.readNullableInt(json, OcptVersionJsonProductionKeys.costKey),
    purposeNotes: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonProductionKeys.purposeNotesKey,
    ),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
    photoAssetId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonKeys.photoAssetIdKey,
    ),
  );

  /// Serialize one `scene_elements` row.
  static Map<String, dynamic> sceneElementToJson(OcptSceneElementRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sceneIdKey: row.sceneId,
    OcptVersionJsonProductionKeys.elementIdKey: row.elementId,
    OcptVersionJsonProductionKeys.quantityKey: row.quantity,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `scene_elements` row.
  static OcptSceneElementRow sceneElementFromJson(Map<String, dynamic> json) => OcptSceneElementRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    sceneId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sceneIdKey),
    elementId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.elementIdKey),
    quantity: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.quantityKey),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `role_elements` row.
  static Map<String, dynamic> roleElementToJson(OcptRoleElementRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.roleIdKey: row.roleId,
    OcptVersionJsonProductionKeys.elementIdKey: row.elementId,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `role_elements` row.
  static OcptRoleElementRow roleElementFromJson(Map<String, dynamic> json) => OcptRoleElementRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    roleId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.roleIdKey),
    elementId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.elementIdKey),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `role_candidates` row.
  static Map<String, dynamic> roleCandidateToJson(OcptRoleCandidateRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.roleIdKey: row.roleId,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.statusKey: row.status.name,
    OcptVersionJsonKeys.auditionedOnKey: row.auditionedOn?.toIso8601String(),
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `role_candidates` row.
  static OcptRoleCandidateRow roleCandidateFromJson(Map<String, dynamic> json) =>
      OcptRoleCandidateRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        roleId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.roleIdKey),
        personId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.personIdKey),
        status: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.statusKey,
          OcptRoleCandidateStatus.values.asNameMap(),
        ),
        auditionedOn: OcptVersionJsonReader.readNullableDateTime(
          json,
          OcptVersionJsonKeys.auditionedOnKey,
        ),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `assets` row.
  static Map<String, dynamic> assetToJson(OcptAssetRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.kindKey: row.kind.name,
    OcptVersionJsonProductionKeys.pathKey: row.path,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.addedAtKey: row.addedAt.toIso8601String(),
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.locationIdKey: row.locationId,
    OcptVersionJsonProductionKeys.elementIdKey: row.elementId,
    OcptVersionJsonProductionKeys.budgetEntryIdKey: row.budgetEntryId,
    OcptVersionJsonProductionKeys.validFromKey: row.validFrom?.toIso8601String(),
    OcptVersionJsonProductionKeys.validUntilKey: row.validUntil?.toIso8601String(),
  };

  /// Parse one `assets` row.
  static OcptAssetRow assetFromJson(Map<String, dynamic> json) => OcptAssetRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    kind: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonKeys.kindKey,
      OcptAssetKind.values.asNameMap(),
    ),
    path: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.pathKey),
    label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
    addedAt: OcptVersionJsonReader.readDateTime(json, OcptVersionJsonProductionKeys.addedAtKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
    personId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.personIdKey),
    locationId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.locationIdKey),
    elementId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.elementIdKey,
    ),
    budgetEntryId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.budgetEntryIdKey,
    ),
    validFrom: OcptVersionJsonReader.readNullableDateTime(
      json,
      OcptVersionJsonProductionKeys.validFromKey,
    ),
    validUntil: OcptVersionJsonReader.readNullableDateTime(
      json,
      OcptVersionJsonProductionKeys.validUntilKey,
    ),
  );

  /// Serialize one `row_field_versions` row.
  static Map<String, dynamic> rowFieldVersionToJson(OcptRowFieldVersionRow row) => {
    OcptVersionJsonProductionKeys.tableNameKey: row.targetTableName,
    OcptVersionJsonProductionKeys.rowIdKey: row.rowId,
    OcptVersionJsonProductionKeys.columnNameKey: row.columnName,
    OcptVersionJsonProductionKeys.versionKey: row.version,
    OcptVersionJsonProductionKeys.deviceIdKey: row.deviceId,
  };

  /// Parse one `row_field_versions` row.
  static OcptRowFieldVersionRow rowFieldVersionFromJson(Map<String, dynamic> json) =>
      OcptRowFieldVersionRow(
        targetTableName: OcptVersionJsonReader.readString(
          json,
          OcptVersionJsonProductionKeys.tableNameKey,
        ),
        rowId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.rowIdKey),
        columnName: OcptVersionJsonReader.readString(
          json,
          OcptVersionJsonProductionKeys.columnNameKey,
        ),
        version: OcptVersionJsonReader.readInt(json, OcptVersionJsonProductionKeys.versionKey),
        deviceId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.deviceIdKey),
      );
}
