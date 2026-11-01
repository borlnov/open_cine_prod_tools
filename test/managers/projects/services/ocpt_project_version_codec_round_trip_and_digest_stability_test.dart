// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'ocpt_project_version_codec_test_doubles.dart';

void main() {
  // The codec logs through appLogger(), which requires a global manager instance to be set; merely
  // accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec(logger: SilentLogger());

  /// [buildRichPayload] serialized and read back.
  OcptProjectVersionPayload roundTrip(OcptProjectVersionPayload payload) {
    final result = codec.decode(codec.encode(payload));

    expect(result.status, OcptProjectVersionPayloadStatus.ok);
    return result.value!;
  }

  group('OcptProjectVersionCodec round trip', () {
    test('a candidacy in any of the statuses decodes back to the one it was written in', () {
      // A `status` is stored by **name** and read back through `values.byName`: a value the tests
      // never actually put through the codec is exactly the kind that only ever fails in a user's
      // own file, months later. Walking `values` is what keeps a ninth status from being added
      // without this being true of it too.
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;

      for (final status in OcptRoleCandidateStatus.values) {
        final rewritten = {
          ...encoded,
          "roleCandidates": [
            for (final row in encoded["roleCandidates"] as List)
              {...row as Map<String, dynamic>, "status": status.name},
          ],
        };

        final result = codec.decode(jsonEncode(rewritten));

        expect(result.status, OcptProjectVersionPayloadStatus.ok, reason: "for $status");
        expect(
          result.value!.roleCandidates.map((row) => row.status),
          everyElement(status),
          reason: "for $status",
        );
      }
    });

    test('decode(encode(payload)) returns an equal payload', () {
      final payload = buildRichPayload();

      expect(roundTrip(payload), payload);
    });

    test('a floor_plan_symbols row with no isHidden key at all (an older format-4 payload, from '
        'before the column existed) reads back as false rather than throwing', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      final rewritten = {
        ...encoded,
        "floorPlanSymbols": [
          for (final row in encoded["floorPlanSymbols"] as List)
            {...row as Map<String, dynamic>}..remove("isHidden"),
        ],
      };

      final result = codec.decode(jsonEncode(rewritten));

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value!.floorPlanSymbols, isNotEmpty);
      expect(result.value!.floorPlanSymbols.map((row) => row.isHidden), everyElement(isFalse));
    });

    test('tombstones, sort keys and version stamps all survive', () {
      final roundTripped = roundTrip(buildRichPayload());

      // Tombstones are rows: a payload that dropped them would resurrect, on restore, everything
      // the user had deleted since.
      expect(roundTripped.screenplays.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.scenes.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.shots.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.shotCharacters.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.shotCoverages.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.people.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.personPositions.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.personSkills.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.personUnavailabilities.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.roles.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.roleEpisodes.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.locations.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.sets.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.sceneSets.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.elements.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.sceneElements.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.assets.map((row) => row.isDeleted), [false, true, false, false, false]);
      expect(roundTripped.storyboardPanels.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.storyboardAnnotations.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.floorPlanSets.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.floorPlanSymbols.map((row) => row.isDeleted), [
        false,
        false,
        true,
        false,
      ]);
      expect(roundTripped.floorPlanArrows.map((row) => row.isDeleted), [false, true]);

      // sortKey, not position, is what orders a group after ADR 0010.
      expect(roundTripped.shots.map((row) => row.sortKey), ["V", "k"]);
      expect(roundTripped.shotCharacters.map((row) => row.sortKey), ["V", "k"]);
      expect(roundTripped.people.map((row) => row.sortKey), ["V", "k"]);
      expect(roundTripped.storyboardPanels.map((row) => row.sortKey), ["V", "k"]);
      expect(roundTripped.floorPlanSymbols.map((row) => row.sortKey), ["V", "k", "m", "w"]);
      // fovReachM: only the camera symbol carries one, every other row stays null.
      expect(roundTripped.floorPlanSymbols.map((row) => row.fovReachM), [null, 6, null, null]);

      // The per-column stamps travel with the rows they describe: this is the assertion that
      // catches a codec silently dropping the sidecar.
      expect(roundTripped.rowFieldVersions, hasLength(2));
      expect(roundTripped.rowFieldVersions.first.targetTableName, "shots");
      expect(roundTripped.rowFieldVersions.first.version, 7);
      expect(roundTripped.rowFieldVersions.last.rowId, "shot-1/THÉO");
      expect(roundTripped.rowFieldVersions.last.deviceId, "device-2");
    });

    test('every column of the twelve resource tables round trips, enums and nulls included', () {
      final roundTripped = roundTrip(buildRichPayload());

      final person = roundTripped.people.first;
      expect(person.firstName, "Clara");
      // The six address columns travel one by one: a payload that kept only the street would lose
      // the postcode a call sheet prints and the country an export gives a column of its own.
      expect(person.addressLine1, "12 rue des Lilas");
      expect(person.addressLine2, "Bâtiment B");
      expect(person.postalCode, "75011");
      expect(person.city, "Paris");
      expect(person.region, "Île-de-France");
      expect(person.country, "France");
      expect(person.colorIndex, 2);
      expect(person.birthDate, isNull);
      expect(person.maxDailyPresenceMinutes, 480);
      expect(person.isTransportAutonomous, isTrue);
      expect(person.imageRightsStatus, OcptImageRightsStatus.signed);
      expect(person.imageRightsAssetId, "asset-1");
      final erasedPerson = roundTripped.people.last;
      expect(erasedPerson.birthDate, DateTime.utc(1990, 5, 12));
      expect(erasedPerson.maxDailyPresenceMinutes, isNull);
      expect(erasedPerson.isTransportAutonomous, isNull);
      expect(erasedPerson.imageRightsStatus, OcptImageRightsStatus.notApplicable);

      final position = roundTripped.personPositions.first;
      expect(position.personId, "person-1");
      expect(position.positionId, "director");

      final skill = roundTripped.personSkills.first;
      expect(skill.label, "Permis B");

      final unavailability = roundTripped.personUnavailabilities.first;
      expect(unavailability.startDate, DateTime.utc(2026, 3));
      expect(unavailability.endDate, DateTime.utc(2026, 3, 5));
      expect(unavailability.slot, OcptDayPartSlot.custom);
      expect(unavailability.startMinute, 14 * 60);
      expect(unavailability.endMinute, 17 * 60 + 30);
      // The window of the second row is null, not zero: only a custom slot carries one.
      expect(roundTripped.personUnavailabilities.last.startMinute, isNull);
      expect(unavailability.reason, "Wedding");

      final role = roundTripped.roles.first;
      expect(role.personId, "person-1");
      expect(role.kind, OcptRoleKind.speaking);
      expect(role.isFromScreenplay, isTrue);
      expect(role.orphanedName, isNull);
      final orphanedRole = roundTripped.roles.last;
      expect(orphanedRole.personId, isNull);
      expect(orphanedRole.kind, OcptRoleKind.extra);
      expect(orphanedRole.orphanedName, "GHOST");

      final screenplay = roundTripped.screenplays.first;
      expect(screenplay.number, 1);
      expect(screenplay.sortKey, "V");
      final tombstonedScreenplay = roundTripped.screenplays.last;
      expect(tombstonedScreenplay.number, 2);
      expect(tombstonedScreenplay.sortKey, "k");

      final roleEpisode = roundTripped.roleEpisodes.first;
      expect(roleEpisode.roleId, "role-1");
      expect(roleEpisode.screenplayId, "screenplay-1");
      expect(roleEpisode.isDeleted, isFalse);
      final tombstonedRoleEpisode = roundTripped.roleEpisodes.last;
      expect(tombstonedRoleEpisode.roleId, "role-2");
      expect(tombstonedRoleEpisode.isDeleted, isTrue);

      final location = roundTripped.locations.first;
      expect(location.addressLine1, "3 rue Victor Hugo");
      expect(location.postalCode, "69002");
      expect(location.region, "Auvergne-Rhône-Alpes");
      expect(location.country, "France");
      expect(location.latitude, 45.75);
      expect(location.longitude, 4.85);
      expect(location.contactPersonId, "person-1");
      expect(location.permitStatus, OcptPermitStatus.granted);
      final unpinnedLocation = roundTripped.locations.last;
      expect(unpinnedLocation.latitude, isNull);
      expect(unpinnedLocation.longitude, isNull);
      expect(unpinnedLocation.permitDate, DateTime.utc(2026, 2));

      final set = roundTripped.sets.first;
      expect(set.locationId, "location-1");
      expect(set.code, "A");

      final sceneSet = roundTripped.sceneSets.first;
      expect(sceneSet.sceneId, "scene-1");
      expect(sceneSet.setId, "set-1");

      final element = roundTripped.elements.first;
      expect(element.category, OcptElementCategory.prop);
      expect(element.sourceKind, OcptElementSourceKind.owned);
      expect(element.ownerPersonId, "person-1");
      expect(element.broughtByPersonId, "person-1");
      expect(element.isSecured, isTrue);
      expect(element.cost, 1200);
      expect(element.status, OcptElementStatus.confirmed);
      final freeElement = roundTripped.elements.last;
      expect(freeElement.ownerPersonId, isNull);
      expect(freeElement.cost, isNull);
      expect(freeElement.status, OcptElementStatus.toFind);

      final sceneElement = roundTripped.sceneElements.first;
      expect(sceneElement.elementId, "element-1");
      expect(sceneElement.quantity, "1");

      final roleElement = roundTripped.roleElements.first;
      expect(roleElement.roleId, "role-1");
      expect(roleElement.elementId, "element-1");
      expect(roleElement.notes, "Torn from scene 12 on");

      final candidate = roundTripped.roleCandidates.first;
      expect(candidate.roleId, "role-1");
      expect(candidate.personId, "person-1");
      expect(candidate.status, OcptRoleCandidateStatus.retained);
      expect(candidate.auditionedOn, DateTime.utc(2026, 2, 12, 14, 30));
      expect(candidate.notes, "Very sure of the last scene");
      expect(candidate.sortKey, "V");
      // The second candidacy was never dated: a self-tape, or somebody seen before the project was
      // opened, keeps a null there rather than a moment nobody recorded.
      final undatedCandidate = roundTripped.roleCandidates.last;
      expect(undatedCandidate.status, OcptRoleCandidateStatus.declined);
      expect(undatedCandidate.auditionedOn, isNull);
      expect(undatedCandidate.isDeleted, isTrue);

      final asset = roundTripped.assets.first;
      expect(asset.kind, OcptAssetKind.document);
      expect(asset.path, "/home/user/Documents/release-clara.pdf");
      expect(asset.addedAt, DateTime.utc(2026, 1, 10, 9));
      expect(asset.personId, "person-1");

      // The two storyboard/floor plan asset kinds set none of the four owner columns: the
      // panel's/case's own id is the only link.
      final panelImageAsset = roundTripped.assets.firstWhere((row) => row.id == "asset-4");
      expect(panelImageAsset.kind, OcptAssetKind.storyboardPanelImage);
      expect(panelImageAsset.personId, isNull);
      expect(panelImageAsset.locationId, isNull);
      expect(panelImageAsset.elementId, isNull);
      expect(panelImageAsset.budgetEntryId, isNull);
      final underlayAsset = roundTripped.assets.firstWhere((row) => row.id == "asset-5");
      expect(underlayAsset.kind, OcptAssetKind.floorPlanUnderlay);
    });

    test('every column of the storyboard and floor plan tables round trips, enums and nulls '
        'included', () {
      final roundTripped = roundTrip(buildRichPayload());

      final panel = roundTripped.storyboardPanels.firstWhere((row) => row.id == "panel-1");
      expect(panel.shotId, "shot-1");
      expect(panel.imageAssetId, "asset-4");
      expect(panel.comment, "Wide establishing");
      expect(panel.isDeleted, isFalse);
      // A panel outlives its image: `Replace image` tombstones the old asset and re-points this
      // column, so it has to survive a round trip as null.
      final panelWithNoImage = roundTripped.storyboardPanels.firstWhere(
        (row) => row.id == "panel-2",
      );
      expect(panelWithNoImage.imageAssetId, isNull);

      final movementArrow = roundTripped.storyboardAnnotations.firstWhere(
        (row) => row.id == "annotation-1",
      );
      expect(movementArrow.panelId, "panel-1");
      expect(movementArrow.kind, OcptStoryboardAnnotationKind.movementArrow);
      expect(movementArrow.x1, 0.1);
      expect(movementArrow.y1, 0.2);
      expect(movementArrow.x2, 0.8);
      expect(movementArrow.y2, 0.75);
      expect(movementArrow.labelText, "dolly in");
      final label = roundTripped.storyboardAnnotations.firstWhere(
        (row) => row.id == "annotation-2",
      );
      expect(label.kind, OcptStoryboardAnnotationKind.label);
      expect(label.isDeleted, isTrue);

      final case1 = roundTripped.floorPlanSets.firstWhere((row) => row.id == "case-1");
      expect(case1.underlayAssetId, "asset-5");
      expect(case1.underlayXM, 1.2);
      expect(case1.underlayYM, 0.8);
      expect(case1.underlayWidthM, 4);
      expect(case1.underlayHeightM, 3);
      expect(case1.underlayRotationDeg, 15);
      // No underlay placed yet on the second set: every underlay column stays null.
      final caseWithNoUnderlay = roundTripped.floorPlanSets.firstWhere((row) => row.id == "case-2");
      expect(caseWithNoUnderlay.underlayAssetId, isNull);
      expect(caseWithNoUnderlay.underlayXM, isNull);
      expect(caseWithNoUnderlay.underlayYM, isNull);
      expect(caseWithNoUnderlay.underlayWidthM, isNull);
      expect(caseWithNoUnderlay.underlayHeightM, isNull);
      expect(caseWithNoUnderlay.underlayRotationDeg, isNull);

      // A sequence layer: shotId null, a footprint of its own, no field of view.
      final sequenceSymbol = roundTripped.floorPlanSymbols.firstWhere(
        (row) => row.id == "symbol-1",
      );
      expect(sequenceSymbol.setId, "case-1");
      expect(sequenceSymbol.shotId, isNull);
      expect(sequenceSymbol.layer, OcptFloorPlanLayer.set);
      expect(sequenceSymbol.xM, 0.5);
      expect(sequenceSymbol.yM, 0.5);
      expect(sequenceSymbol.widthM, 5);
      expect(sequenceSymbol.heightM, 4);
      expect(sequenceSymbol.fovDeg, isNull);
      expect(sequenceSymbol.label, "North wall");
      expect(sequenceSymbol.setElementShape, OcptFloorPlanSetElementShape.wall);
      // A shot layer: shotId set, a field of view instead of a footprint, no set-element shape.
      final cameraSymbol = roundTripped.floorPlanSymbols.firstWhere((row) => row.id == "symbol-2");
      expect(cameraSymbol.shotId, "shot-1");
      expect(cameraSymbol.layer, OcptFloorPlanLayer.cameras);
      expect(cameraSymbol.rotationDeg, 45);
      expect(cameraSymbol.widthM, isNull);
      expect(cameraSymbol.heightM, isNull);
      expect(cameraSymbol.fovDeg, 84);
      expect(cameraSymbol.setElementShape, isNull);
      final tombstonedSymbol = roundTripped.floorPlanSymbols.firstWhere(
        (row) => row.id == "symbol-3",
      );
      expect(tombstonedSymbol.layer, OcptFloorPlanLayer.characters);
      expect(tombstonedSymbol.isDeleted, isTrue);
      // A scene-scope override: sceneId set, overridesSymbolId naming the set-scope original.
      final overrideSymbol = roundTripped.floorPlanSymbols.firstWhere(
        (row) => row.id == "symbol-4",
      );
      expect(overrideSymbol.sceneId, "scene-1");
      expect(overrideSymbol.shotId, isNull);
      expect(overrideSymbol.overridesSymbolId, "symbol-1");
      expect(overrideSymbol.label, "North wall, re-dressed");
      expect(overrideSymbol.isHidden, isTrue);
      expect(sequenceSymbol.isHidden, isFalse);

      final movement = roundTripped.floorPlanArrows.firstWhere((row) => row.id == "arrow-1");
      expect(movement.setId, "case-1");
      expect(movement.shotId, "shot-1");
      expect(movement.kind, OcptFloorPlanArrowKind.movement);
      expect(movement.fromSymbolId, "symbol-2");
      expect(movement.toSymbolId, "symbol-3");
      expect(movement.label, "walks in");
      expect(movement.ctrlXM, 1.1);
      expect(movement.ctrlYM, 1.6);
      final cameraMove = roundTripped.floorPlanArrows.firstWhere((row) => row.id == "arrow-2");
      expect(cameraMove.kind, OcptFloorPlanArrowKind.cameraMove);
      expect(cameraMove.isDeleted, isTrue);
      expect(cameraMove.ctrlXM, isNull);
      expect(cameraMove.ctrlYM, isNull);
    });

    test('every column of the two breakdown tables round trips, enums and nulls included', () {
      final roundTripped = roundTrip(buildRichPayload());

      // The three targetKind values, each pointing at exactly one of elementId/roleId/setId and
      // leaving the other two null — a codec that forgot one of the three columns would silently
      // lose the tags of that whole kind on a restore.
      final elementTag = roundTripped.breakdownTags.firstWhere(
        (tag) => tag.id == "breakdown-tag-1",
      );
      expect(elementTag.targetKind, OcptBreakdownTargetKind.element);
      expect(elementTag.elementId, "element-1");
      expect(elementTag.roleId, isNull);
      expect(elementTag.setId, isNull);
      expect(elementTag.taggedText, "desk");
      expect(elementTag.startOffset, 0);
      expect(elementTag.endOffset, 4);
      expect(elementTag.needsCheck, isFalse);
      expect(elementTag.isDeleted, isFalse);

      final roleTag = roundTripped.breakdownTags.firstWhere((tag) => tag.id == "breakdown-tag-2");
      expect(roleTag.targetKind, OcptBreakdownTargetKind.role);
      expect(roleTag.elementId, isNull);
      expect(roleTag.roleId, "role-1");
      expect(roleTag.setId, isNull);
      expect(roleTag.needsCheck, isTrue);

      final setTag = roundTripped.breakdownTags.firstWhere((tag) => tag.id == "breakdown-tag-3");
      expect(setTag.targetKind, OcptBreakdownTargetKind.set);
      expect(setTag.elementId, isNull);
      expect(setTag.roleId, isNull);
      expect(setTag.setId, "set-1");
      // The tombstone is a row like any other: a payload holding only live tags would resurrect,
      // on restore, every tag the user had removed since.
      expect(setTag.isDeleted, isTrue);

      final inProgressScene = roundTripped.sceneBreakdowns.firstWhere(
        (row) => row.id == "scene-breakdown-1",
      );
      expect(inProgressScene.status, OcptBreakdownSceneStatus.inProgress);
      expect(inProgressScene.notes, "Check the lamp cable colour");
      expect(inProgressScene.isDeleted, isFalse);

      final doneScene = roundTripped.sceneBreakdowns.firstWhere(
        (row) => row.id == "scene-breakdown-2",
      );
      expect(doneScene.status, OcptBreakdownSceneStatus.done);
      expect(doneScene.notes, "");
      expect(doneScene.isDeleted, isTrue);
    });

    test('every column of the schedule tables round trips, enums and nulls included', () {
      final roundTripped = roundTrip(buildRichPayload());

      final day = roundTripped.shootingDays.firstWhere((row) => row.id == "day-1");
      expect(day.date, DateTime.utc(2026, 3, 10));
      expect(day.sortKey, "V");
      expect(day.status, OcptShootingDayStatus.planned);
      expect(day.crewNote, "Arrive at the north gate");
      expect(day.weatherNote, "Sunny, light wind");
      expect(day.notes, "Backup interior booked in case of rain");
      expect(day.isDeleted, isFalse);
      final cancelledDay = roundTripped.shootingDays.firstWhere((row) => row.id == "day-2");
      expect(cancelledDay.status, OcptShootingDayStatus.cancelled);
      expect(cancelledDay.isDeleted, isTrue);

      final slot = roundTripped.shootingSlots.firstWhere((row) => row.id == "slot-1");
      expect(slot.shootingDayId, "day-1");
      expect(slot.label, "Matin");
      expect(slot.locationId, "location-1");
      expect(slot.setId, "set-1");
      expect(slot.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(slot.anchorMinute, 420);
      expect(slot.anchorSlotId, isNull);
      // A night slot's anchored minute exceeds 1440 and comes back exactly as stored, never taken
      // modulo anything — see ocpt_shooting_slots_table.dart.
      final nightSlot = roundTripped.shootingSlots.firstWhere((row) => row.id == "slot-2");
      expect(nightSlot.anchorEdge, OcptShootingSlotAnchorEdge.end);
      expect(nightSlot.anchorMinute, 1620);
      expect(nightSlot.locationId, isNull);
      expect(nightSlot.setId, isNull);
      expect(nightSlot.isDeleted, isTrue);

      // The other half of the anchor discriminator: a linked edge comes back with no minute and
      // the slot it reads.
      final linkedSlot = roundTripped.shootingSlots.firstWhere((row) => row.id == "slot-3");
      expect(linkedSlot.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(linkedSlot.anchorMinute, isNull);
      expect(linkedSlot.anchorSlotId, "slot-1");

      final crew = roundTripped.shootingSlotCrew.firstWhere((row) => row.id == "crew-1");
      expect(crew.slotId, "slot-1");
      expect(crew.personId, "person-1");
      expect(crew.positionId, "director");
      expect(crew.customLabel, "");
      final customCrew = roundTripped.shootingSlotCrew.firstWhere((row) => row.id == "crew-2");
      expect(customCrew.positionId, "");
      expect(customCrew.customLabel, "Régie");
      expect(customCrew.isDeleted, isTrue);

      final cast = roundTripped.shootingSlotCast.firstWhere((row) => row.id == "cast-1");
      expect(cast.slotId, "slot-1");
      expect(cast.roleId, "role-1");
      final unsetCast = roundTripped.shootingSlotCast.firstWhere((row) => row.id == "cast-2");
      expect(unsetCast.isDeleted, isTrue);

      final shotBlock = roundTripped.shootingDayBlocks.firstWhere((row) => row.id == "block-1");
      expect(shotBlock.shootingDayId, "day-1");
      expect(shotBlock.slotId, "slot-1");
      expect(shotBlock.kind, OcptShootingBlockKind.shot);
      expect(shotBlock.shotId, "shot-1");
      expect(shotBlock.durationMinutes, isNull);
      expect(shotBlock.anchorMinute, isNull);
      expect(shotBlock.sceneId, isNull);
      final holdBlock = roundTripped.shootingDayBlocks.firstWhere((row) => row.id == "block-2");
      expect(holdBlock.slotId, "slot-2");
      expect(holdBlock.kind, OcptShootingBlockKind.hold);
      expect(holdBlock.shotId, isNull);
      expect(holdBlock.sceneId, "scene-1");
      expect(holdBlock.label, "Seq. 6 not shot-listed yet");
      expect(holdBlock.durationMinutes, 30);
      expect(holdBlock.anchorMinute, 600);
      expect(holdBlock.isDeleted, isTrue);

      final guest = roundTripped.shootingSlotGuests.firstWhere((row) => row.id == "guest-1");
      expect(guest.slotId, "slot-1");
      expect(guest.personId, "person-1");
      expect(guest.freeName, "");
      expect(guest.reason, "Maire, prête la place");
      expect(guest.isDeleted, isFalse);
      final freeNamedGuest = roundTripped.shootingSlotGuests.firstWhere(
        (row) => row.id == "guest-2",
      );
      expect(freeNamedGuest.personId, isNull);
      expect(freeNamedGuest.freeName, "Le maire");
      expect(freeNamedGuest.isDeleted, isTrue);

      final event = roundTripped.shootingDayEvents.firstWhere((row) => row.id == "event-1");
      expect(event.shootingDayId, "day-1");
      // Past 1440, exactly as a night slot's own anchored minute is — see
      // ocpt_shooting_day_events_table.dart.
      expect(event.minute, 1020);
      expect(event.label, "Feu d'artifice du village");
      expect(event.isDeleted, isFalse);
      final tombstonedEvent = roundTripped.shootingDayEvents.firstWhere(
        (row) => row.id == "event-2",
      );
      expect(tombstonedEvent.isDeleted, isTrue);
    });

    test("a shot's abbreviation survives, so a restore keeps the coverage bar labels", () {
      final roundTripped = roundTrip(buildRichPayload());

      // The codec is a hand-written mirror of the schema, so every column it forgets is a column
      // a restore silently blanks. This one degrades the scenario coverage export's bar labels
      // from «WS1/1» back to «1/1», which nothing else would catch.
      expect(roundTripped.shots.map((row) => row.abbreviation), ["WS", ""]);
    });

    test('scene ids come back identical, and every reference to them still resolves', () {
      final roundTripped = roundTrip(buildRichPayload());

      // Re-deriving the scene index on restore would mint fresh UUIDs and break every reference
      // carried by the very same payload.
      expect(roundTripped.scenes.map((row) => row.id), ["scene-1", "scene-2"]);

      final sceneIds = {for (final scene in roundTripped.scenes) scene.id};
      for (final shot in roundTripped.shots) {
        expect(shot.sceneId == null || sceneIds.contains(shot.sceneId), isTrue);
      }
      for (final coverage in roundTripped.shotCoverages) {
        expect(sceneIds, contains(coverage.sceneId));
      }
    });

    test('the whole page setup comes back, margins included', () {
      final roundTripped = roundTrip(buildRichPayload());

      expect(roundTripped.pageSetup.format, OcptPageFormat.a4);
      expect(roundTripped.pageSetup.margins.leftInches, 1.5);
      expect(roundTripped.pageSetup.margins.rightInches, 1);
      expect(roundTripped.pageSetup.margins.topInches, 0.75);
      expect(roundTripped.pageSetup.margins.bottomInches, 1.25);
      expect(roundTripped.settingsJson, '{"someSetting":true}');
    });

    test('the currency comes back', () {
      expect(roundTrip(buildRichPayload()).currencyCode, "GBP");
    });

    test('the minimum rest comes back', () {
      expect(roundTrip(buildRichPayload()).minimumRestMinutes, 660);
    });

    test('the screenplay language comes back', () {
      expect(roundTrip(buildRichPayload()).screenplayLanguage, OcptScreenplayLanguage.fr);
    });

    test('the learned words come back, exactly as typed, tombstones included', () {
      final roundTripped = roundTrip(buildRichPayload());

      expect(roundTripped.projectDictionaryWords.map((row) => row.word), ["Séquence", "Marc"]);
      expect(roundTripped.projectDictionaryWords.map((row) => row.isDeleted), [false, true]);
    });

    test("a block's crew note comes back", () {
      final block = roundTrip(
        buildRichPayload(),
      ).shootingDayBlocks.firstWhere((row) => row.id == "block-1");
      expect(block.crewNote, "Silence, take in progress");
    });

    test("an asset's validity window comes back", () {
      final asset = roundTrip(buildRichPayload()).assets.firstWhere((row) => row.id == "asset-1");
      expect(asset.validFrom, DateTime.utc(2026, 1, 10));
      expect(asset.validUntil, DateTime.utc(2027, 1, 10));
    });

    test("a receipt asset's budgetEntryId comes back", () {
      final asset = roundTrip(buildRichPayload()).assets.firstWhere((row) => row.id == "asset-3");
      expect(asset.kind, OcptAssetKind.receipt);
      expect(asset.budgetEntryId, "entry-1");
    });

    test('every column of the cash journal round trips, tombstones and nulls included', () {
      final roundTripped = roundTrip(buildRichPayload());

      final liveEntry = roundTripped.budgetEntries.firstWhere((row) => row.id == "entry-1");
      expect(liveEntry.date, DateTime.utc(2026, 3, 10));
      expect(liveEntry.label, "Location camion");
      expect(liveEntry.posteId, "poste-1");
      expect(liveEntry.debitCents, 15000);
      expect(liveEntry.creditCents, 0);
      expect(liveEntry.isTaxInclusive, isTrue);
      expect(liveEntry.vatRateBasisPoints, 550);
      expect(liveEntry.voucherNumber, "J-001");
      expect(liveEntry.isDeleted, isFalse);

      expect(liveEntry.commitmentId, "commitment-1");
      expect(liveEntry.personId, "person-1");

      final tombstonedEntry = roundTripped.budgetEntries.firstWhere((row) => row.id == "entry-2");
      expect(tombstonedEntry.posteId, isNull);
      expect(tombstonedEntry.commitmentId, isNull);
      expect(tombstonedEntry.personId, isNull);
      expect(tombstonedEntry.isDeleted, isTrue);

      final liveCommitment = roundTripped.budgetCommitments.firstWhere(
        (row) => row.id == "commitment-1",
      );
      expect(liveCommitment.dueDate, DateTime.utc(2026, 4, 15));
      expect(liveCommitment.label, "Assurance tournage");
      expect(liveCommitment.posteId, "poste-1");
      expect(liveCommitment.amountCents, 45000);
      expect(liveCommitment.isTaxInclusive, isFalse);
      expect(liveCommitment.vatRateBasisPoints, 2000);
      expect(liveCommitment.status, OcptBudgetCommitmentStatus.contractSigned);
      expect(liveCommitment.isDeleted, isFalse);

      final tombstonedCommitment = roundTripped.budgetCommitments.firstWhere(
        (row) => row.id == "commitment-2",
      );
      expect(tombstonedCommitment.dueDate, isNull);
      expect(tombstonedCommitment.isDeleted, isTrue);
    });

    test('a project with no shot list at all round trips as an empty one', () {
      const payload = OcptProjectVersionPayload(
        screenplays: [],
        scenes: [],
        shots: [],
        shotCharacters: [],
        shotCoverages: [],
        people: [],
        personPositions: [],
        personSkills: [],
        personUnavailabilities: [],
        roles: [],
        roleEpisodes: [],
        locations: [],
        locationAvailabilities: [],
        sets: [],
        sceneSets: [],
        elements: [],
        sceneElements: [],
        roleElements: [],
        roleCandidates: [],
        budgetPostes: [],
        budgetLines: [],
        budgetEntries: [],
        budgetCommitments: [],
        budgetResources: [],
        budgetMileageRates: [],
        budgetRevenues: [],
        budgetShares: [],
        budgetAllowances: [],
        storyboardPanels: [],
        storyboardAnnotations: [],
        floorPlanSets: [],
        floorPlanSymbols: [],
        floorPlanArrows: [],
        assets: [],
        breakdownTags: [],
        sceneBreakdowns: [],
        shootingDays: [],
        shootingSlots: [],
        shootingSlotCrew: [],
        shootingSlotCast: [],
        shootingDayBlocks: [],
        shootingSlotGuests: [],
        shootingDayEvents: [],
        projectDictionaryWords: [],
        rowFieldVersions: [],
        pageSetup: OcptPageSetup.standard(),
        settingsJson: null,
        currencyCode: null,
        minimumRestMinutes: null,
        screenplayLanguage: null,
        shootingBlockCandidates: [],
        defaultVatRateBasisPoints: null,
        mealPriceCents: null,
        snackPriceCents: null,
        isBudgetSimplified: null,
      );

      expect(roundTrip(payload), payload);
    });

    test('the encoded text declares the format it was written in', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;

      expect(encoded["payloadFormat"], OcptProjectVersionCodec.currentPayloadFormat);
    });
  });

  group('OcptProjectVersionCodec contentDigest', () {
    test('is stable across two captures of the same unchanged state', () {
      expect(codec.contentDigest(buildRichPayload()), codec.contentDigest(buildRichPayload()));
    });

    test('is insensitive to the order SQLite happened to return rows in', () {
      final payload = buildRichPayload();
      final reordered = OcptProjectVersionPayload(
        screenplays: payload.screenplays.reversed.toList(),
        scenes: payload.scenes.reversed.toList(),
        shots: payload.shots.reversed.toList(),
        shotCharacters: payload.shotCharacters.reversed.toList(),
        shotCoverages: payload.shotCoverages.reversed.toList(),
        people: payload.people.reversed.toList(),
        personPositions: payload.personPositions.reversed.toList(),
        personSkills: payload.personSkills.reversed.toList(),
        personUnavailabilities: payload.personUnavailabilities.reversed.toList(),
        roles: payload.roles.reversed.toList(),
        roleEpisodes: payload.roleEpisodes.reversed.toList(),
        locations: payload.locations.reversed.toList(),
        locationAvailabilities: payload.locationAvailabilities.reversed.toList(),
        sets: payload.sets.reversed.toList(),
        sceneSets: payload.sceneSets.reversed.toList(),
        elements: payload.elements.reversed.toList(),
        sceneElements: payload.sceneElements.reversed.toList(),
        roleElements: payload.roleElements.reversed.toList(),
        roleCandidates: payload.roleCandidates.reversed.toList(),
        budgetPostes: payload.budgetPostes.reversed.toList(),
        budgetLines: payload.budgetLines.reversed.toList(),
        budgetEntries: payload.budgetEntries.reversed.toList(),
        budgetCommitments: payload.budgetCommitments.reversed.toList(),
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
        storyboardPanels: payload.storyboardPanels,
        storyboardAnnotations: payload.storyboardAnnotations,
        floorPlanSets: payload.floorPlanSets,
        floorPlanSymbols: payload.floorPlanSymbols,
        floorPlanArrows: payload.floorPlanArrows,
        assets: payload.assets.reversed.toList(),
        breakdownTags: payload.breakdownTags.reversed.toList(),
        sceneBreakdowns: payload.sceneBreakdowns.reversed.toList(),
        shootingDays: payload.shootingDays.reversed.toList(),
        shootingSlots: payload.shootingSlots.reversed.toList(),
        shootingSlotCrew: payload.shootingSlotCrew.reversed.toList(),
        shootingSlotCast: payload.shootingSlotCast.reversed.toList(),
        shootingDayBlocks: payload.shootingDayBlocks.reversed.toList(),
        shootingSlotGuests: payload.shootingSlotGuests.reversed.toList(),
        shootingDayEvents: payload.shootingDayEvents.reversed.toList(),
        projectDictionaryWords: payload.projectDictionaryWords.reversed.toList(),
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      expect(codec.contentDigest(payload), codec.contentDigest(reordered));
    });

    test('ignores rowFieldVersions: the per-column stamps play no part in the content', () {
      final payload = buildRichPayload();
      final withDifferentStamps = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
        storyboardPanels: payload.storyboardPanels,
        storyboardAnnotations: payload.storyboardAnnotations,
        floorPlanSets: payload.floorPlanSets,
        floorPlanSymbols: payload.floorPlanSymbols,
        floorPlanArrows: payload.floorPlanArrows,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: const [
          OcptRowFieldVersionRow(
            targetTableName: "shots",
            rowId: "shot-1",
            columnName: "framing",
            version: 99,
            deviceId: "device-9",
          ),
        ],
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      expect(codec.contentDigest(payload), codec.contentDigest(withDifferentStamps));
    });

    test('ignores the page margins: only the page format is project content', () {
      final payload = buildRichPayload();
      final withDifferentMargins = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
        storyboardPanels: payload.storyboardPanels,
        storyboardAnnotations: payload.storyboardAnnotations,
        floorPlanSets: payload.floorPlanSets,
        floorPlanSymbols: payload.floorPlanSymbols,
        floorPlanArrows: payload.floorPlanArrows,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: OcptPageSetup(
          format: payload.pageSetup.format,
          margins: const FountainPageMargins(
            leftInches: 2,
            rightInches: 2,
            topInches: 2,
            bottomInches: 2,
          ),
        ),
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      expect(codec.contentDigest(payload), codec.contentDigest(withDifferentMargins));
    });
  });
}
