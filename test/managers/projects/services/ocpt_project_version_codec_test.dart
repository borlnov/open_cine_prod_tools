// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_unavailability_slot.dart';

void main() {
  // The codec logs through appLogger(), which requires a global manager instance to be set; merely
  // accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec();

  /// A payload covering everything the format has to survive: a live row and a tombstoned one in
  /// every table, both nullable and non-null columns, both enum columns, the fractional sort keys,
  /// and the version stamps of the rows it carries.
  ///
  /// The second row of each table leaves every nullable column at its null default — a scene with
  /// no number, an orphaned shot with no scene, no duration, no shooting day, no planned takes and
  /// no check reason — so the round trip is exercised on null values as well as on set ones.
  OcptProjectVersionPayload buildRichPayload() => OcptProjectVersionPayload(
    screenplays: [
      OcptScreenplayRow(
        id: "screenplay-1",
        title: "My Movie",
        fountainText: "INT. HOUSE - DAY\n\nCLARA enters.",
        updatedAt: DateTime.utc(2026, 3, 4, 15, 42, 12, 345),
        isDeleted: false,
      ),
      OcptScreenplayRow(
        id: "screenplay-2",
        title: "Abandoned draft",
        fountainText: "",
        updatedAt: DateTime.utc(2026, 2, 2),
        isDeleted: true,
      ),
    ],
    scenes: const [
      OcptSceneRow(
        id: "scene-1",
        screenplayId: "screenplay-1",
        position: 0,
        heading: "INT. HOUSE - DAY",
        sceneNumber: "4A",
        charStart: 0,
        charEnd: 18,
        isDeleted: false,
      ),
      OcptSceneRow(
        id: "scene-2",
        screenplayId: "screenplay-1",
        position: 1,
        heading: "EXT. STREET - NIGHT",
        charStart: 18,
        charEnd: 40,
        isDeleted: true,
      ),
    ],
    shots: const [
      OcptShotRow(
        id: "shot-1",
        screenplayId: "screenplay-1",
        sceneId: "scene-1",
        position: 0,
        sortKey: "V",
        shotSize: "Wide",
        abbreviation: "WS",
        framing: "Low angle",
        cameraMove: "Dolly in",
        lens: "35mm",
        recordingFormat: "4K · 25 fps",
        estimatedDurationMs: 12500,
        shootingDay: "Day 3",
        plannedTakes: 4,
        sound: "Direct",
        status: OcptShotStatus.shot,
        difficultySet: 2,
        difficultyCamera: 4,
        difficultyActing: 1,
        difficultySound: 3,
        notes: "Hold on CLARA's hands.",
        locationNotes: "Kitchen, north window",
        needsCheck: true,
        checkReason: OcptShotCheckReason.coveredTextChanged,
        isDeleted: false,
      ),
      OcptShotRow(
        id: "shot-2",
        screenplayId: "screenplay-1",
        orphanedHeading: "EXT. STREET - NIGHT",
        position: 1,
        sortKey: "k",
        shotSize: "",
        abbreviation: "",
        framing: "",
        cameraMove: "",
        lens: "",
        recordingFormat: "",
        sound: "",
        status: OcptShotStatus.toShoot,
        difficultySet: 1,
        difficultyCamera: 1,
        difficultyActing: 1,
        difficultySound: 1,
        notes: "",
        locationNotes: "",
        needsCheck: false,
        isDeleted: true,
      ),
    ],
    shotCharacters: const [
      OcptShotCharacterRow(
        shotId: "shot-1",
        characterName: "CLARA",
        position: 0,
        sortKey: "V",
        isDeleted: false,
      ),
      OcptShotCharacterRow(
        shotId: "shot-1",
        characterName: "THÉO",
        position: 1,
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    shotCoverages: const [
      OcptShotCoverageRow(
        id: "coverage-1",
        shotId: "shot-1",
        sceneId: "scene-1",
        startOffset: 0,
        endOffset: 12,
        coveredTextDigest: "digest-1",
        isDeleted: false,
      ),
      OcptShotCoverageRow(
        id: "coverage-2",
        shotId: "shot-1",
        sceneId: "scene-2",
        startOffset: 3,
        endOffset: 9,
        coveredTextDigest: "digest-2",
        isDeleted: true,
      ),
    ],
    people: [
      const OcptPersonRow(
        id: "person-1",
        sortKey: "V",
        isDeleted: false,
        firstName: "Clara",
        lastName: "Martin",
        email: "clara@example.com",
        phone: "0102030405",
        addressLine1: "12 rue des Lilas",
        addressLine2: "Bâtiment B",
        postalCode: "75011",
        city: "Paris",
        region: "Île-de-France",
        country: "France",
        colorIndex: 2,
        minorNotes: "",
        isTransportAutonomous: true,
        accommodationNotes: "Chez Camille",
        travelNotes: "Carte jeune SNCF",
        dietaryNotes: "Vegetarian",
        allergies: "Peanuts",
        sizeTop: "38",
        sizeBottom: "M",
        sizeShoes: "39",
        hmcNotes: "Redhead wig",
        imageRightsStatus: OcptImageRightsStatus.signed,
        imageRightsAssetId: "asset-1",
        photoAssetId: "asset-2",
        notes: "Lead actress",
      ),
      OcptPersonRow(
        id: "person-2",
        sortKey: "k",
        isDeleted: true,
        firstName: "",
        lastName: "",
        email: "",
        phone: "",
        addressLine1: "",
        addressLine2: "",
        postalCode: "",
        city: "",
        region: "",
        country: "",
        colorIndex: 0,
        birthDate: DateTime.utc(1990, 5, 12),
        minorNotes: "",
        accommodationNotes: "",
        travelNotes: "",
        dietaryNotes: "",
        allergies: "",
        sizeTop: "",
        sizeBottom: "",
        sizeShoes: "",
        hmcNotes: "",
        imageRightsStatus: OcptImageRightsStatus.notApplicable,
        imageRightsDate: DateTime.utc(2026, 1, 10),
        notes: "",
      ),
    ],
    personPositions: const [
      OcptPersonPositionRow(
        id: "position-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptPersonPositionRow(
        id: "position-2",
        personId: "person-1",
        positionId: "",
        customLabel: "Régie",
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    personSkills: const [
      OcptPersonSkillRow(
        id: "skill-1",
        personId: "person-1",
        label: "Permis B",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptPersonSkillRow(id: "skill-2", personId: "person-1", label: "", sortKey: "k", isDeleted: true),
    ],
    personUnavailabilities: [
      OcptPersonUnavailabilityRow(
        id: "unavailability-1",
        personId: "person-1",
        startDate: DateTime.utc(2026, 3),
        endDate: DateTime.utc(2026, 3, 5),
        slot: OcptUnavailabilitySlot.custom,
        startMinute: 14 * 60,
        endMinute: 17 * 60 + 30,
        reason: "Wedding",
        isDeleted: false,
      ),
      OcptPersonUnavailabilityRow(
        id: "unavailability-2",
        personId: "person-1",
        startDate: DateTime.utc(2026, 3, 2),
        endDate: DateTime.utc(2026, 3, 2),
        slot: OcptUnavailabilitySlot.fullDay,
        reason: "",
        isDeleted: true,
      ),
    ],
    roles: const [
      OcptRoleRow(
        id: "role-1",
        screenplayId: "screenplay-1",
        name: "CLARA",
        sortKey: "V",
        isDeleted: false,
        personId: "person-1",
        kind: OcptRoleKind.speaking,
        isFromScreenplay: true,
        castingNotes: "Confirmed",
      ),
      OcptRoleRow(
        id: "role-2",
        screenplayId: "screenplay-1",
        name: "EXTRA",
        sortKey: "k",
        isDeleted: true,
        kind: OcptRoleKind.extra,
        isFromScreenplay: false,
        orphanedName: "GHOST",
        castingNotes: "",
      ),
    ],
    locations: [
      const OcptLocationRow(
        id: "location-1",
        name: "Maison des Pains",
        colorIndex: 1,
        addressLine1: "3 rue Victor Hugo",
        addressLine2: "",
        postalCode: "69002",
        city: "Lyon",
        region: "Auvergne-Rhône-Alpes",
        country: "France",
        latitude: 45.75,
        longitude: 4.85,
        contactPersonId: "person-1",
        contactNotes: "Call after 6pm",
        permitStatus: OcptPermitStatus.granted,
        permitLabel: "AUT-2026-01",
        permitAssetId: "asset-1",
        parkingNotes: "Street parking",
        powerNotes: "16A available",
        facilitiesNotes: "Toilet inside",
        constraintsNotes: "No noise after 10pm",
        notes: "Owner lives nearby",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptLocationRow(
        id: "location-2",
        name: "",
        colorIndex: 0,
        addressLine1: "",
        addressLine2: "",
        postalCode: "",
        city: "",
        region: "",
        country: "",
        contactNotes: "",
        permitStatus: OcptPermitStatus.toRequest,
        permitLabel: "",
        permitDate: DateTime.utc(2026, 2),
        parkingNotes: "",
        powerNotes: "",
        facilitiesNotes: "",
        constraintsNotes: "",
        notes: "",
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    sets: const [
      OcptSetRow(
        id: "set-1",
        locationId: "location-1",
        code: "A",
        name: "Cuisine",
        notes: "Bright morning light",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptSetRow(
        id: "set-2",
        locationId: "location-1",
        code: "",
        name: "Escalier",
        notes: "",
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    sceneSets: const [
      OcptSceneSetRow(id: "scene-set-1", sceneId: "scene-1", setId: "set-1", isDeleted: false),
      OcptSceneSetRow(id: "scene-set-2", sceneId: "scene-2", setId: "set-1", isDeleted: true),
    ],
    elements: const [
      OcptElementRow(
        id: "element-1",
        sortKey: "V",
        isDeleted: false,
        category: OcptElementCategory.prop,
        subCategory: "Kitchenware",
        name: "Ceramic mug",
        code: "MUG1",
        quantity: "×2",
        sourceKind: OcptElementSourceKind.owned,
        ownerPersonId: "person-1",
        ownerNotes: "M. et Mme Schmit",
        broughtByPersonId: "person-1",
        storageNotes: "Sous l'abri",
        isSecured: true,
        isReadyForShoot: true,
        isReturned: false,
        cost: 1200,
        purposeNotes: "Breakfast scene",
        notes: "Handle with care",
        photoAssetId: "asset-1",
      ),
      OcptElementRow(
        id: "element-2",
        sortKey: "k",
        isDeleted: true,
        category: OcptElementCategory.other,
        subCategory: "",
        name: "",
        code: "",
        quantity: "",
        sourceKind: OcptElementSourceKind.toBuy,
        ownerNotes: "",
        storageNotes: "",
        isSecured: false,
        isReadyForShoot: false,
        isReturned: false,
        purposeNotes: "",
        notes: "",
      ),
    ],
    sceneElements: const [
      OcptSceneElementRow(
        id: "scene-element-1",
        sceneId: "scene-1",
        elementId: "element-1",
        quantity: "1",
        notes: "On the table",
        isDeleted: false,
      ),
      OcptSceneElementRow(
        id: "scene-element-2",
        sceneId: "scene-2",
        elementId: "element-1",
        quantity: "",
        notes: "",
        isDeleted: true,
      ),
    ],
    assets: [
      OcptAssetRow(
        id: "asset-1",
        kind: OcptAssetKind.document,
        path: "/home/user/Documents/release-clara.pdf",
        label: "Signed release",
        addedAt: DateTime.utc(2026, 1, 10, 9),
        sortKey: "V",
        isDeleted: false,
        personId: "person-1",
      ),
      OcptAssetRow(
        id: "asset-2",
        kind: OcptAssetKind.personPhoto,
        path: "",
        label: "",
        addedAt: DateTime.utc(2026),
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    rowFieldVersions: const [
      OcptRowFieldVersionRow(
        targetTableName: "shots",
        rowId: "shot-1",
        columnName: "framing",
        version: 7,
        deviceId: "device-1",
      ),
      OcptRowFieldVersionRow(
        targetTableName: "shot_characters",
        rowId: "shot-1/THÉO",
        columnName: "isDeleted",
        version: 2,
        deviceId: "device-2",
      ),
    ],
    pageSetup: const OcptPageSetup(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(
        leftInches: 1.5,
        rightInches: 1,
        topInches: 0.75,
        bottomInches: 1.25,
      ),
    ),
    settingsJson: '{"someSetting":true}',
  );

  /// [buildRichPayload] serialized and read back.
  OcptProjectVersionPayload roundTrip(OcptProjectVersionPayload payload) {
    final result = codec.decode(codec.encode(payload));

    expect(result.status, OcptProjectVersionPayloadStatus.ok);
    return result.value!;
  }

  group('OcptProjectVersionCodec round trip', () {
    test('decode(encode(payload)) returns an equal payload', () {
      final payload = buildRichPayload();

      expect(roundTrip(payload), payload);
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
      expect(roundTripped.locations.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.sets.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.sceneSets.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.elements.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.sceneElements.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.assets.map((row) => row.isDeleted), [false, true]);

      // sortKey, not position, is what orders a group after ADR 0010.
      expect(roundTripped.shots.map((row) => row.sortKey), ["V", "k"]);
      expect(roundTripped.shotCharacters.map((row) => row.sortKey), ["V", "k"]);
      expect(roundTripped.people.map((row) => row.sortKey), ["V", "k"]);

      // The per-column stamps travel with the rows they describe: this is the assertion that
      // catches a codec silently dropping the sidecar.
      expect(roundTripped.rowFieldVersions, hasLength(2));
      expect(roundTripped.rowFieldVersions.first.targetTableName, "shots");
      expect(roundTripped.rowFieldVersions.first.version, 7);
      expect(roundTripped.rowFieldVersions.last.rowId, "shot-1/THÉO");
      expect(roundTripped.rowFieldVersions.last.deviceId, "device-2");
    });

    test('every column of the eleven resource tables round trips, enums and nulls included', () {
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
      expect(person.isTransportAutonomous, isTrue);
      expect(person.imageRightsStatus, OcptImageRightsStatus.signed);
      expect(person.imageRightsAssetId, "asset-1");
      final erasedPerson = roundTripped.people.last;
      expect(erasedPerson.birthDate, DateTime.utc(1990, 5, 12));
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
      expect(unavailability.slot, OcptUnavailabilitySlot.custom);
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
      final freeElement = roundTripped.elements.last;
      expect(freeElement.ownerPersonId, isNull);
      expect(freeElement.cost, isNull);

      final sceneElement = roundTripped.sceneElements.first;
      expect(sceneElement.elementId, "element-1");
      expect(sceneElement.quantity, "1");

      final asset = roundTripped.assets.first;
      expect(asset.kind, OcptAssetKind.document);
      expect(asset.path, "/home/user/Documents/release-clara.pdf");
      expect(asset.addedAt, DateTime.utc(2026, 1, 10, 9));
      expect(asset.personId, "person-1");
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
        locations: [],
        sets: [],
        sceneSets: [],
        elements: [],
        sceneElements: [],
        assets: [],
        rowFieldVersions: [],
        pageSetup: OcptPageSetup.standard(),
        settingsJson: null,
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
        locations: payload.locations.reversed.toList(),
        sets: payload.sets.reversed.toList(),
        sceneSets: payload.sceneSets.reversed.toList(),
        elements: payload.elements.reversed.toList(),
        sceneElements: payload.sceneElements.reversed.toList(),
        assets: payload.assets.reversed.toList(),
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
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
        locations: payload.locations,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        assets: payload.assets,
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
        locations: payload.locations,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        assets: payload.assets,
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
      );

      expect(codec.contentDigest(payload), codec.contentDigest(withDifferentMargins));
    });

    test('changes when a screenplay is edited', () {
      final payload = buildRichPayload();
      final edited = OcptProjectVersionPayload(
        screenplays: [
          payload.screenplays.first.copyWith(fountainText: "INT. HOUSE - DAY\n\nCLARA leaves."),
          payload.screenplays.last,
        ],
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        locations: payload.locations,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        assets: payload.assets,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(edited)));
    });

    test('changes when a row is tombstoned', () {
      final payload = buildRichPayload();
      final tombstoned = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: [payload.shots.first.copyWith(isDeleted: true), payload.shots.last],
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        locations: payload.locations,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        assets: payload.assets,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(tombstoned)));
    });

    test('changes when a resources row is edited', () {
      final payload = buildRichPayload();
      final edited = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: [payload.people.first.copyWith(phone: "0699999999"), payload.people.last],
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        locations: payload.locations,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        assets: payload.assets,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
      );

      // Without the resources tables in the digest, an afternoon of typing people, locations and
      // elements in would leave the working-copy card claiming no drift from its base.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(edited)));
    });

    test('changes when a resources row is tombstoned', () {
      final payload = buildRichPayload();
      final tombstoned = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: [payload.people.first.copyWith(isDeleted: true), payload.people.last],
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        locations: payload.locations,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        assets: payload.assets,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(tombstoned)));
    });

    test('changes when the page format changes', () {
      final payload = buildRichPayload();
      final reformatted = OcptProjectVersionPayload(
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
        locations: payload.locations,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        assets: payload.assets,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: OcptPageSetup(
          format: OcptPageFormat.usLetter,
          margins: payload.pageSetup.margins,
        ),
        settingsJson: payload.settingsJson,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(reformatted)));
    });
  });

  group('OcptProjectVersionCodec format handling', () {
    /// The encoded rich payload, with its declared format replaced by [payloadFormat].
    String encodedWithFormat(int payloadFormat) {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      encoded["payloadFormat"] = payloadFormat;

      return jsonEncode(encoded);
    }

    test('a payload written by a later build of the app is refused, not half-read', () {
      final result = codec.decode(
        encodedWithFormat(OcptProjectVersionCodec.currentPayloadFormat + 1),
      );

      expect(result.status, OcptProjectVersionPayloadStatus.unsupportedFutureFormat);
      expect(result.value, isNull);
    });

    test('a payload written in the current format needs no upgrade step', () {
      final result = codec.decode(
        encodedWithFormat(OcptProjectVersionCodec.currentPayloadFormat),
      );

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value, buildRichPayload());
    });

    test('a format with no upgrade step at all is refused rather than guessed', () {
      // Format 0 has never existed and no step of _payloadUpgrades claims to read it: the replay
      // loop must refuse the payload instead of reading it as if it were current.
      final result = codec.decode(encodedWithFormat(0));

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
      expect(result.value, isNull);
    });

    test('a stored format-1 payload decodes cleanly with the eleven resources tables empty', () {
      // A literal fixture of what a real version written before the resources mode existed looks
      // like on disk: none of the eleven resources keys are present at all, since payload format 1
      // predates them entirely.
      const format1Payload = r'''
{
  "payloadFormat": 1,
  "screenplays": [
    {
      "id": "screenplay-1",
      "title": "My Movie",
      "fountainText": "INT. HOUSE - DAY\n\nCLARA enters.",
      "updatedAt": "2026-03-04T15:42:12.345Z",
      "isDeleted": false
    }
  ],
  "scenes": [],
  "shots": [],
  "shotCharacters": [],
  "shotCoverages": [],
  "rowFieldVersions": [],
  "projectSettings": { "pageFormat": "a4", "settingsJson": null },
  "pageMargins": {
    "leftInches": 1.5,
    "rightInches": 1,
    "topInches": 0.75,
    "bottomInches": 1.25
  }
}
''';

      final result = codec.decode(format1Payload);

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      final payload = result.value!;
      expect(payload.screenplays, hasLength(1));
      expect(payload.screenplays.single.id, "screenplay-1");
      // A version captured before the resources mode existed is a truthful statement that the
      // project had none: this is what OcptProjectVersionsService._restoreTable then tombstones
      // the working copy's resources against, with no special case of its own.
      expect(payload.people, isEmpty);
      expect(payload.personPositions, isEmpty);
      expect(payload.personSkills, isEmpty);
      expect(payload.personUnavailabilities, isEmpty);
      expect(payload.roles, isEmpty);
      expect(payload.locations, isEmpty);
      expect(payload.sets, isEmpty);
      expect(payload.sceneSets, isEmpty);
      expect(payload.elements, isEmpty);
      expect(payload.sceneElements, isEmpty);
      expect(payload.assets, isEmpty);
    });
  });

  group('OcptProjectVersionCodec malformed payloads', () {
    test("text that isn't JSON at all is refused", () {
      final result = codec.decode("not json");

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
    });

    test("a JSON value that isn't an object is refused", () {
      final result = codec.decode("[1, 2, 3]");

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
    });

    test('a payload with no format at all is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>
        ..remove("payloadFormat");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a payload missing one of its row sections is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>
        ..remove("rowFieldVersions");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a row missing one of its columns is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["shots"] as List).first as Map<String, dynamic>).remove("sortKey");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a column holding the wrong type is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["scenes"] as List).first as Map<String, dynamic>)["charStart"] = "zero";

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('an enum column holding an unknown value is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["shots"] as List).first as Map<String, dynamic>)["status"] = "teleported";

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });
  });
}
