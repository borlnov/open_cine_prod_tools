// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_production_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_reader.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

/// The JSON shape of the screenplay, scene, shot, storyboard and floor plan rows in a version's
/// payload: one serializer and one parser per table, mirroring its columns.
abstract final class OcptVersionShotListJson {
  /// Serialize one `screenplays` row.
  static Map<String, dynamic> screenplayToJson(OcptScreenplayRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.titleKey: row.title,
    OcptVersionJsonKeys.fountainTextKey: row.fountainText,
    OcptVersionJsonKeys.updatedAtKey: row.updatedAt.toIso8601String(),
    OcptVersionJsonKeys.numberKey: row.number,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `screenplays` row.
  static OcptScreenplayRow screenplayFromJson(Map<String, dynamic> json) => OcptScreenplayRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    title: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.titleKey),
    fountainText: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.fountainTextKey),
    updatedAt: OcptVersionJsonReader.readDateTime(json, OcptVersionJsonKeys.updatedAtKey),
    number: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.numberKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `scenes` row.
  static Map<String, dynamic> sceneToJson(OcptSceneRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.screenplayIdKey: row.screenplayId,
    OcptVersionJsonKeys.positionKey: row.position,
    OcptVersionJsonKeys.headingKey: row.heading,
    OcptVersionJsonKeys.sceneNumberKey: row.sceneNumber,
    OcptVersionJsonKeys.charStartKey: row.charStart,
    OcptVersionJsonKeys.charEndKey: row.charEnd,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `scenes` row.
  static OcptSceneRow sceneFromJson(Map<String, dynamic> json) => OcptSceneRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    screenplayId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.screenplayIdKey),
    position: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.positionKey),
    heading: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.headingKey),
    sceneNumber: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.sceneNumberKey),
    charStart: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.charStartKey),
    charEnd: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.charEndKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `shots` row.
  static Map<String, dynamic> shotToJson(OcptShotRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.screenplayIdKey: row.screenplayId,
    OcptVersionJsonKeys.sceneIdKey: row.sceneId,
    OcptVersionJsonKeys.orphanedHeadingKey: row.orphanedHeading,
    OcptVersionJsonKeys.positionKey: row.position,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.shotSizeKey: row.shotSize,
    OcptVersionJsonKeys.abbreviationKey: row.abbreviation,
    OcptVersionJsonKeys.framingKey: row.framing,
    OcptVersionJsonKeys.cameraMoveKey: row.cameraMove,
    OcptVersionJsonKeys.lensKey: row.lens,
    OcptVersionJsonKeys.recordingFormatKey: row.recordingFormat,
    OcptVersionJsonKeys.estimatedDurationMsKey: row.estimatedDurationMs,
    OcptVersionJsonKeys.shootingDayKey: row.shootingDay,
    OcptVersionJsonKeys.plannedTakesKey: row.plannedTakes,
    OcptVersionJsonKeys.soundKey: row.sound,
    OcptVersionJsonKeys.statusKey: row.status.name,
    OcptVersionJsonKeys.difficultySetKey: row.difficultySet,
    OcptVersionJsonKeys.difficultyCameraKey: row.difficultyCamera,
    OcptVersionJsonKeys.difficultyActingKey: row.difficultyActing,
    OcptVersionJsonKeys.difficultySoundKey: row.difficultySound,
    OcptVersionJsonKeys.notesKey: row.notes,
    OcptVersionJsonKeys.locationNotesKey: row.locationNotes,
    OcptVersionJsonKeys.needsCheckKey: row.needsCheck,
    OcptVersionJsonKeys.checkReasonKey: row.checkReason?.name,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shots` row.
  static OcptShotRow shotFromJson(Map<String, dynamic> json) => OcptShotRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    screenplayId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.screenplayIdKey),
    sceneId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.sceneIdKey),
    orphanedHeading: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonKeys.orphanedHeadingKey,
    ),
    position: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.positionKey),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    shotSize: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.shotSizeKey),
    abbreviation: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.abbreviationKey),
    framing: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.framingKey),
    cameraMove: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.cameraMoveKey),
    lens: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.lensKey),
    recordingFormat: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.recordingFormatKey),
    estimatedDurationMs: OcptVersionJsonReader.readNullableInt(
      json,
      OcptVersionJsonKeys.estimatedDurationMsKey,
    ),
    shootingDay: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.shootingDayKey),
    plannedTakes: OcptVersionJsonReader.readNullableInt(json, OcptVersionJsonKeys.plannedTakesKey),
    sound: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.soundKey),
    status: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonKeys.statusKey,
      OcptShotStatus.values.asNameMap(),
    ),
    difficultySet: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.difficultySetKey),
    difficultyCamera: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.difficultyCameraKey),
    difficultyActing: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.difficultyActingKey),
    difficultySound: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.difficultySoundKey),
    notes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.notesKey),
    locationNotes: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.locationNotesKey),
    needsCheck: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.needsCheckKey),
    checkReason: OcptVersionJsonReader.readNullableEnum(
      json,
      OcptVersionJsonKeys.checkReasonKey,
      OcptShotCheckReason.values.asNameMap(),
    ),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `shot_characters` row.
  static Map<String, dynamic> shotCharacterToJson(OcptShotCharacterRow row) => {
    OcptVersionJsonKeys.shotIdKey: row.shotId,
    OcptVersionJsonProductionKeys.roleIdKey: row.roleId,
    OcptVersionJsonKeys.positionKey: row.position,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shot_characters` row, from payload format 3 on — see `OcptProjectVersionCodec`'s
  /// payload walk, whose doc comment for why an older payload never reaches this at all.
  static OcptShotCharacterRow shotCharacterFromJson(Map<String, dynamic> json) =>
      OcptShotCharacterRow(
        shotId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.shotIdKey),
        roleId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.roleIdKey),
        position: OcptVersionJsonReader.readInt(json, OcptVersionJsonKeys.positionKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `shot_coverages` row.
  static Map<String, dynamic> shotCoverageToJson(OcptShotCoverageRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.shotIdKey: row.shotId,
    OcptVersionJsonKeys.sceneIdKey: row.sceneId,
    OcptVersionJsonProductionKeys.startOffsetKey: row.startOffset,
    OcptVersionJsonProductionKeys.endOffsetKey: row.endOffset,
    OcptVersionJsonProductionKeys.coveredTextDigestKey: row.coveredTextDigest,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `shot_coverages` row.
  static OcptShotCoverageRow shotCoverageFromJson(Map<String, dynamic> json) => OcptShotCoverageRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    shotId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.shotIdKey),
    sceneId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sceneIdKey),
    startOffset: OcptVersionJsonReader.readInt(json, OcptVersionJsonProductionKeys.startOffsetKey),
    endOffset: OcptVersionJsonReader.readInt(json, OcptVersionJsonProductionKeys.endOffsetKey),
    coveredTextDigest: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonProductionKeys.coveredTextDigestKey,
    ),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `storyboard_panels` row.
  static Map<String, dynamic> storyboardPanelToJson(OcptStoryboardPanelRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonKeys.shotIdKey: row.shotId,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonProductionKeys.imageAssetIdKey: row.imageAssetId,
    OcptVersionJsonProductionKeys.commentKey: row.comment,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `storyboard_panels` row.
  static OcptStoryboardPanelRow storyboardPanelFromJson(Map<String, dynamic> json) =>
      OcptStoryboardPanelRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        shotId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.shotIdKey),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        imageAssetId: OcptVersionJsonReader.readNullableString(
          json,
          OcptVersionJsonProductionKeys.imageAssetIdKey,
        ),
        comment: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.commentKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `storyboard_annotations` row.
  static Map<String, dynamic> storyboardAnnotationToJson(OcptStoryboardAnnotationRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.panelIdKey: row.panelId,
    OcptVersionJsonKeys.kindKey: row.kind.name,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonProductionKeys.x1Key: row.x1,
    OcptVersionJsonProductionKeys.y1Key: row.y1,
    OcptVersionJsonProductionKeys.x2Key: row.x2,
    OcptVersionJsonProductionKeys.y2Key: row.y2,
    OcptVersionJsonProductionKeys.textKey: row.labelText,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `storyboard_annotations` row.
  static OcptStoryboardAnnotationRow storyboardAnnotationFromJson(Map<String, dynamic> json) =>
      OcptStoryboardAnnotationRow(
        id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
        panelId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.panelIdKey),
        kind: OcptVersionJsonReader.readEnum(
          json,
          OcptVersionJsonKeys.kindKey,
          OcptStoryboardAnnotationKind.values.asNameMap(),
        ),
        sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
        x1: OcptVersionJsonReader.readDouble(json, OcptVersionJsonProductionKeys.x1Key),
        y1: OcptVersionJsonReader.readDouble(json, OcptVersionJsonProductionKeys.y1Key),
        x2: OcptVersionJsonReader.readDouble(json, OcptVersionJsonProductionKeys.x2Key),
        y2: OcptVersionJsonReader.readDouble(json, OcptVersionJsonProductionKeys.y2Key),
        labelText: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.textKey),
        isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
      );

  /// Serialize one `floor_plan_sets` row.
  static Map<String, dynamic> floorPlanSetToJson(OcptFloorPlanSetRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.underlayAssetIdKey: row.underlayAssetId,
    OcptVersionJsonProductionKeys.underlayXMKey: row.underlayXM,
    OcptVersionJsonProductionKeys.underlayYMKey: row.underlayYM,
    OcptVersionJsonProductionKeys.underlayWidthMKey: row.underlayWidthM,
    OcptVersionJsonProductionKeys.underlayHeightMKey: row.underlayHeightM,
    OcptVersionJsonProductionKeys.underlayRotationDegKey: row.underlayRotationDeg,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `floor_plan_sets` row.
  static OcptFloorPlanSetRow floorPlanSetFromJson(Map<String, dynamic> json) => OcptFloorPlanSetRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    underlayAssetId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.underlayAssetIdKey,
    ),
    underlayXM: OcptVersionJsonReader.readNullableDouble(
      json,
      OcptVersionJsonProductionKeys.underlayXMKey,
    ),
    underlayYM: OcptVersionJsonReader.readNullableDouble(
      json,
      OcptVersionJsonProductionKeys.underlayYMKey,
    ),
    underlayWidthM: OcptVersionJsonReader.readNullableDouble(
      json,
      OcptVersionJsonProductionKeys.underlayWidthMKey,
    ),
    underlayHeightM: OcptVersionJsonReader.readNullableDouble(
      json,
      OcptVersionJsonProductionKeys.underlayHeightMKey,
    ),
    underlayRotationDeg: OcptVersionJsonReader.readNullableDouble(
      json,
      OcptVersionJsonProductionKeys.underlayRotationDegKey,
    ),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `floor_plan_symbols` row.
  static Map<String, dynamic> floorPlanSymbolToJson(OcptFloorPlanSymbolRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.setIdKey: row.setId,
    OcptVersionJsonKeys.sceneIdKey: row.sceneId,
    OcptVersionJsonKeys.shotIdKey: row.shotId,
    OcptVersionJsonProductionKeys.layerKey: row.layer.name,
    OcptVersionJsonKeys.sortKeyKey: row.sortKey,
    OcptVersionJsonProductionKeys.xMKey: row.xM,
    OcptVersionJsonProductionKeys.yMKey: row.yM,
    OcptVersionJsonProductionKeys.rotationDegKey: row.rotationDeg,
    OcptVersionJsonProductionKeys.widthMKey: row.widthM,
    OcptVersionJsonProductionKeys.heightMKey: row.heightM,
    OcptVersionJsonProductionKeys.fovDegKey: row.fovDeg,
    OcptVersionJsonProductionKeys.fovReachMKey: row.fovReachM,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.setElementShapeKey: row.setElementShape?.name,
    OcptVersionJsonProductionKeys.overridesSymbolIdKey: row.overridesSymbolId,
    OcptVersionJsonProductionKeys.isHiddenKey: row.isHidden,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `floor_plan_symbols` row.
  static OcptFloorPlanSymbolRow floorPlanSymbolFromJson(
    Map<String, dynamic> json,
  ) => OcptFloorPlanSymbolRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    setId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.setIdKey),
    sceneId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.sceneIdKey),
    shotId: OcptVersionJsonReader.readNullableString(json, OcptVersionJsonKeys.shotIdKey),
    layer: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonProductionKeys.layerKey,
      OcptFloorPlanLayer.values.asNameMap(),
    ),
    sortKey: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.sortKeyKey),
    xM: OcptVersionJsonReader.readDouble(json, OcptVersionJsonProductionKeys.xMKey),
    yM: OcptVersionJsonReader.readDouble(json, OcptVersionJsonProductionKeys.yMKey),
    rotationDeg: OcptVersionJsonReader.readDouble(
      json,
      OcptVersionJsonProductionKeys.rotationDegKey,
    ),
    widthM: OcptVersionJsonReader.readNullableDouble(json, OcptVersionJsonProductionKeys.widthMKey),
    heightM: OcptVersionJsonReader.readNullableDouble(
      json,
      OcptVersionJsonProductionKeys.heightMKey,
    ),
    fovDeg: OcptVersionJsonReader.readNullableDouble(json, OcptVersionJsonProductionKeys.fovDegKey),
    fovReachM: OcptVersionJsonReader.readNullableDouble(
      json,
      OcptVersionJsonProductionKeys.fovReachMKey,
    ),
    label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
    setElementShape: OcptVersionJsonReader.readNullableEnum(
      json,
      OcptVersionJsonProductionKeys.setElementShapeKey,
      OcptFloorPlanSetElementShape.values.asNameMap(),
    ),
    overridesSymbolId: OcptVersionJsonReader.readNullableString(
      json,
      OcptVersionJsonProductionKeys.overridesSymbolIdKey,
    ),
    isHidden: OcptVersionJsonReader.readBoolWithFalseDefault(
      json,
      OcptVersionJsonProductionKeys.isHiddenKey,
    ),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );

  /// Serialize one `floor_plan_arrows` row.
  static Map<String, dynamic> floorPlanArrowToJson(OcptFloorPlanArrowRow row) => {
    OcptVersionJsonKeys.idKey: row.id,
    OcptVersionJsonProductionKeys.setIdKey: row.setId,
    OcptVersionJsonKeys.shotIdKey: row.shotId,
    OcptVersionJsonKeys.kindKey: row.kind.name,
    OcptVersionJsonProductionKeys.fromSymbolIdKey: row.fromSymbolId,
    OcptVersionJsonProductionKeys.toSymbolIdKey: row.toSymbolId,
    OcptVersionJsonKeys.labelKey: row.label,
    OcptVersionJsonProductionKeys.ctrlXMKey: row.ctrlXM,
    OcptVersionJsonProductionKeys.ctrlYMKey: row.ctrlYM,
    OcptVersionJsonKeys.isDeletedKey: row.isDeleted,
  };

  /// Parse one `floor_plan_arrows` row.
  static OcptFloorPlanArrowRow floorPlanArrowFromJson(
    Map<String, dynamic> json,
  ) => OcptFloorPlanArrowRow(
    id: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.idKey),
    setId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.setIdKey),
    shotId: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.shotIdKey),
    kind: OcptVersionJsonReader.readEnum(
      json,
      OcptVersionJsonKeys.kindKey,
      OcptFloorPlanArrowKind.values.asNameMap(),
    ),
    fromSymbolId: OcptVersionJsonReader.readString(
      json,
      OcptVersionJsonProductionKeys.fromSymbolIdKey,
    ),
    toSymbolId: OcptVersionJsonReader.readString(json, OcptVersionJsonProductionKeys.toSymbolIdKey),
    label: OcptVersionJsonReader.readString(json, OcptVersionJsonKeys.labelKey),
    ctrlXM: OcptVersionJsonReader.readNullableDouble(json, OcptVersionJsonProductionKeys.ctrlXMKey),
    ctrlYM: OcptVersionJsonReader.readNullableDouble(json, OcptVersionJsonProductionKeys.ctrlYMKey),
    isDeleted: OcptVersionJsonReader.readBool(json, OcptVersionJsonKeys.isDeletedKey),
  );
}
