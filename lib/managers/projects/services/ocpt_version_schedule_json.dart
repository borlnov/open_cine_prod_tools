// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_production_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_reader.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// The JSON shape of the breakdown and shooting schedule rows in a version's payload: one
/// serializer and one parser per table, mirroring its columns.
abstract final class OcptVersionScheduleJson {
  /// Serialize one `breakdown_tags` row.
  static Map<String, dynamic> breakdownTagToJson(OcptBreakdownTagRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sceneIdKey: row.sceneId,
    OcptVersionJsonKeys.targetKindKey: row.targetKind.name,
    OcptVersionJsonProductionKeys.elementIdKey: row.elementId,
    OcptVersionJsonProductionKeys.roleIdKey: row.roleId,
    OcptVersionJsonProductionKeys.setIdKey: row.setId,
    OcptVersionJsonProductionKeys.startOffsetKey: row.startOffset,
    OcptVersionJsonProductionKeys.endOffsetKey: row.endOffset,
    OcptVersionJsonProductionKeys.taggedTextKey: row.taggedText,
    OcptVersionJsonKeys.needsCheckKey: row.needsCheck,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `breakdown_tags` row.
  static OcptBreakdownTagRow breakdownTagFromJson(Map<String, dynamic> json) => OcptBreakdownTagRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    sceneId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sceneIdKey),
    targetKind: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonKeys.targetKindKey,
      OcptBreakdownTargetKind.values.asNameMap(),
    ),
    elementId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.elementIdKey,
    ),
    roleId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonProductionKeys.roleIdKey),
    setId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonProductionKeys.setIdKey),
    startOffset: OcptVersionJsonReader.readInt(json, OcptVersionJsonProductionKeys.startOffsetKey),
    endOffset: OcptVersionJsonReader.readInt(json, OcptVersionJsonProductionKeys.endOffsetKey),
    taggedText: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.taggedTextKey),
    needsCheck: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.needsCheckKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `scene_breakdowns` row.
  static Map<String, dynamic> sceneBreakdownToJson(OcptSceneBreakdownRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.sceneIdKey: row.sceneId,
    OcptVersionJsonKeys.statusKey: row.status.name,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `scene_breakdowns` row.
  static OcptSceneBreakdownRow sceneBreakdownFromJson(Map<String, dynamic> json) =>
      OcptSceneBreakdownRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        sceneId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sceneIdKey),
        status: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.statusKey,
          OcptBreakdownSceneStatus.values.asNameMap(),
        ),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `shooting_days` row.
  static Map<String, dynamic> shootingDayToJson(OcptShootingDayRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.dateKey: row.date.toIso8601String(),
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.statusKey: row.status.name,
    OcptVersionJsonProductionKeys.crewNoteKey: row.crewNote,
    OcptVersionJsonProductionKeys.weatherNoteKey: row.weatherNote,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shooting_days` row.
  static OcptShootingDayRow shootingDayFromJson(Map<String, dynamic> json) => OcptShootingDayRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    date: OcptVersionJsonReader.readDateTime(json, OcptVersionJsonProductionKeys.dateKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    status: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonKeys.statusKey,
      OcptShootingDayStatus.values.asNameMap(),
    ),
    crewNote: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.crewNoteKey),
    weatherNote: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonProductionKeys.weatherNoteKey,
    ),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `shooting_slots` row.
  static Map<String, dynamic> shootingSlotToJson(OcptShootingSlotRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.shootingDayIdKey: row.shootingDayId,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonKeys.locationIdKey: row.locationId,
    OcptVersionJsonProductionKeys.setIdKey: row.setId,
    OcptVersionJsonProductionKeys.anchorEdgeKey: row.anchorEdge.name,
    OcptVersionJsonProductionKeys.anchorMinuteKey: row.anchorMinute,
    OcptVersionJsonProductionKeys.anchorSlotIdKey: row.anchorSlotId,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shooting_slots` row.
  static OcptShootingSlotRow shootingSlotFromJson(Map<String, dynamic> json) => OcptShootingSlotRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    shootingDayId: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonProductionKeys.shootingDayIdKey,
    ),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
    locationId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.locationIdKey),
    setId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonProductionKeys.setIdKey),
    anchorEdge: OcptShootingSlotAnchorEdge.values.byName(
      OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.anchorEdgeKey),
    ),
    anchorMinute: OcptVersionJsonReader.readNullableInt(
      json,
      OcptVersionJsonProductionKeys.anchorMinuteKey,
    ),
    anchorSlotId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.anchorSlotIdKey,
    ),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `shooting_slot_crew` row.
  static Map<String, dynamic> shootingSlotCrewToJson(OcptShootingSlotCrewRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.slotIdKey: row.slotId,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.positionIdKey: row.positionId,
    OcptVersionJsonKeys.customLabelKey: row.customLabel,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shooting_slot_crew` row.
  static OcptShootingSlotCrewRow shootingSlotCrewFromJson(Map<String, dynamic> json) =>
      OcptShootingSlotCrewRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        slotId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.slotIdKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        personId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.personIdKey),
        positionId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.positionIdKey),
        customLabel: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.customLabelKey),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `shooting_slot_cast` row.
  static Map<String, dynamic> shootingSlotCastToJson(OcptShootingSlotCastRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.slotIdKey: row.slotId,
    OcptVersionJsonProductionKeys.roleIdKey: row.roleId,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shooting_slot_cast` row.
  static OcptShootingSlotCastRow shootingSlotCastFromJson(Map<String, dynamic> json) =>
      OcptShootingSlotCastRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        slotId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.slotIdKey),
        roleId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.roleIdKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `shooting_day_blocks` row.
  static Map<String, dynamic> shootingDayBlockToJson(OcptShootingDayBlockRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.shootingDayIdKey: row.shootingDayId,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonProductionKeys.slotIdKey: row.slotId,
    OcptVersionJsonKeys.kindKey: row.kind.name,
    OcptVersionJsonKeys.shotIdKey: row.shotId,
    OcptVersionJsonKeys.sceneIdKey: row.sceneId,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.durationMinutesKey: row.durationMinutes,
    OcptVersionJsonProductionKeys.anchorMinuteKey: row.anchorMinute,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonProductionKeys.crewNoteKey: row.crewNote,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shooting_day_blocks` row.
  static OcptShootingDayBlockRow shootingDayBlockFromJson(Map<String, dynamic> json) =>
      OcptShootingDayBlockRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        shootingDayId: OcptVersionJsonReader.readString(
          json,
          OcptVersionJsonProductionKeys.shootingDayIdKey,
        ),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        slotId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.slotIdKey),
        kind: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.kindKey,
          OcptShootingBlockKind.values.asNameMap(),
        ),
        shotId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.shotIdKey),
        sceneId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.sceneIdKey),
        label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
        durationMinutes: OcptVersionJsonReader.readNullableInt(
          json,
          OcptVersionJsonProductionKeys.durationMinutesKey,
        ),
        anchorMinute: OcptVersionJsonReader.readNullableInt(
          json,
          OcptVersionJsonProductionKeys.anchorMinuteKey,
        ),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
        crewNote: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.crewNoteKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `shooting_block_candidates` row.
  static Map<String, dynamic> shootingBlockCandidateToJson(OcptShootingBlockCandidateRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.blockIdKey: row.blockId,
    OcptVersionJsonKeys.roleCandidateIdKey: row.roleCandidateId,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shooting_block_candidates` row.
  static OcptShootingBlockCandidateRow shootingBlockCandidateFromJson(Map<String, dynamic> json) =>
      OcptShootingBlockCandidateRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        blockId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.blockIdKey),
        roleCandidateId: OcptVersionJsonReader.readString(
          json,
          OcptVersionJsonKeys.roleCandidateIdKey,
        ),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `shooting_slot_guests` row.
  static Map<String, dynamic> shootingSlotGuestToJson(OcptShootingSlotGuestRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.slotIdKey: row.slotId,
    OcptVersionJsonKeys.personIdKey: row.personId,
    OcptVersionJsonKeys.freeNameKey: row.freeName,
    OcptVersionJsonKeys.reasonKey: row.reason,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shooting_slot_guests` row.
  static OcptShootingSlotGuestRow shootingSlotGuestFromJson(Map<String, dynamic> json) =>
      OcptShootingSlotGuestRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        slotId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.slotIdKey),
        personId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.personIdKey),
        freeName: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.freeNameKey),
        reason: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.reasonKey),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `shooting_day_events` row.
  static Map<String, dynamic> shootingDayEventToJson(OcptShootingDayEventRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.shootingDayIdKey: row.shootingDayId,
    OcptVersionJsonProductionKeys.minuteKey: row.minute,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shooting_day_events` row.
  static OcptShootingDayEventRow shootingDayEventFromJson(Map<String, dynamic> json) =>
      OcptShootingDayEventRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        shootingDayId: OcptVersionJsonReader.readString(
          json,
          OcptVersionJsonProductionKeys.shootingDayIdKey,
        ),
        minute: OcptVersionJsonReader.readInt(json, OcptVersionJsonProductionKeys.minuteKey),
        label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
        notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );
}
