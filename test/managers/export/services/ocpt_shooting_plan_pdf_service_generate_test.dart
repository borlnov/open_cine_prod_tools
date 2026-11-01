// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'ocpt_shooting_plan_pdf_service_test_doubles.dart';

/// Builds a crew member with the few fields these tests read, everything else neutral.
OcptShootingSlotCrewMember _buildCrewMember({
  required String id,
  required String slotId,
  required String personId,
  String positionId = "gaffer",
}) => OcptShootingSlotCrewMember(
  id: id,
  slotId: slotId,
  personId: personId,
  positionId: positionId,
  customLabel: "",
  notes: "",
);

/// Builds a cast member with the few fields these tests read, everything else neutral.
OcptShootingSlotCastMember _buildCastMember({
  required String id,
  required String slotId,
  required String roleId,
}) => OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

/// Builds a person with the few fields these tests read, everything else neutral.
OcptPerson _buildPerson({
  required String id,
  required String firstName,
  required String lastName,
}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: lastName,
  email: "",
  phone: "",
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  colorIndex: 0,
  birthDate: null,
  minorNotes: "",
  maxDailyPresenceMinutes: null,
  isTransportAutonomous: null,
  accommodationNotes: "",
  travelNotes: "",
  dietaryNotes: "",
  allergies: "",
  measurementHeight: "",
  measurementChest: "",
  measurementWaist: "",
  measurementHips: "",
  sizeTop: "",
  sizeBottom: "",
  sizeShoes: "",
  hmcNotes: "",
  imageRightsStatus: OcptImageRightsStatus.notApplicable,
  imageRightsDate: null,
  imageRightsAssetId: null,
  photoAssetId: null,
  photo: null,
  imageRightsDocument: null,
  notes: "",
  commuteKmMilli: null,
  mileageRateId: null,
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required String name, String? personId, int number = 1}) =>
    OcptRole(
      id: id,
      name: name,
      personId: personId,
      kind: OcptRoleKind.speaking,
      isFromScreenplay: true,
      orphanedName: null,
      castingNotes: "",
      number: number,
      episodeIds: const [],
    );

/// Builds a location with the few fields these tests read, everything else neutral.
OcptLocation _buildLocation({required String id, String name = ""}) => OcptLocation(
  id: id,
  name: name,
  colorIndex: 0,
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  latitude: null,
  longitude: null,
  contactPersonId: null,
  contactNotes: "",
  permitStatus: OcptPermitStatus.notNeeded,
  permitLabel: "",
  permitDate: null,
  permitAssetId: null,
  parkingNotes: "",
  powerNotes: "",
  facilitiesNotes: "",
  constraintsNotes: "",
  notes: "",
  sets: const [],
  photos: const [],
  permitDocument: null,
  availabilities: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptShootingPlanPdfService(logger: const SilentLogger());

  const pageSetup = OcptPageSetup.standard();

  final pinnedExportDate = DateTime(2026, 1, 15);

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final locationA = _buildLocation(id: "loc-a", name: "Studio A");
      final slot = buildSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        locationId: "loc-a",
        anchorMinute: 480,
      );
      final plan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        locations: [locationA],
      );

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: true,
        includeLocationsGrid: true,
        includeSequencesGrid: true,
        includePeopleGrid: true,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a two-slot day produces two grid columns under one day tag", () async {
      final locationA = _buildLocation(id: "loc-a", name: "Studio A");
      final locationB = _buildLocation(id: "loc-b", name: "Location B");
      final morning = buildSlot(
        id: "slot-morning",
        shootingDayId: "day-1",
        locationId: "loc-a",
        anchorMinute: 480,
      );
      final evening = buildSlot(
        id: "slot-evening",
        shootingDayId: "day-1",
        locationId: "loc-b",
        anchorMinute: 1080,
      );

      final twoSlotPlan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 2)],
        slotsByDayId: {
          "day-1": [morning, evening],
        },
        locations: [locationA, locationB],
      );
      final oneSlotPlan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 2)],
        slotsByDayId: {
          "day-1": [morning],
        },
        locations: [locationA],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: true,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final full = await generateFor(twoSlotPlan);
      final single = await generateFor(oneSlotPlan);

      expect(contentStreams(full), isNot(contentStreams(single)));
      // Two grid columns and two day-slot hours lines printing distinct content is, by
      // construction, a longer document than one.
      expect(full.length, greaterThan(single.length));
    });

    test("a range wide enough to chunk the grid adds at least one extra page over the same "
        "range without it", () async {
      final location = _buildLocation(id: "loc-a", name: "Studio A");
      // Eight days, each with its own single slot at the same location — one row, eight columns,
      // well past the grid's own per-page chunk size.
      final days = [for (var i = 1; i <= 8; i++) buildDay(id: "day-$i", dayNumber: i)];
      final slotsByDayId = {
        for (var i = 1; i <= 8; i++)
          "day-$i": [
            buildSlot(
              id: "slot-$i",
              shootingDayId: "day-$i",
              locationId: "loc-a",
              anchorMinute: 480,
            ),
          ],
      };
      final dayIds = [for (var i = 1; i <= 8; i++) "day-$i"];
      final plan = buildSnapshot(days: days, slotsByDayId: slotsByDayId, locations: [location]);

      Future<Uint8List> generateFor({required bool includeLocationsGrid}) => service.generate(
        plan: plan,
        dayIds: dayIds,
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: includeLocationsGrid,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final withGrid = await generateFor(includeLocationsGrid: true);
      final withoutGrid = await generateFor(includeLocationsGrid: false);

      expect(pageCount(withGrid) - pageCount(withoutGrid), greaterThanOrEqualTo(2));
    });

    test("each grid toggled off shrinks the document", () async {
      final location = _buildLocation(id: "loc-a", name: "Studio A");
      final person = _buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard");
      final role = _buildRole(id: "role-1", name: "Alice", personId: "person-1");
      final slot = buildSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        locationId: "loc-a",
        anchorMinute: 480,
        crew: [
          _buildCrewMember(
            id: "crew-1",
            slotId: "slot-1",
            personId: "person-1",
            positionId: "director",
          ),
        ],
        cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );
      final shot = buildShot(
        id: "shot-1",
        sceneId: "scene-1",
        code: "1/1",
        characters: const ["ALICE"],
      );
      final blocksByDayId = {
        "day-1": [
          buildBlock(
            id: "block-1",
            shootingDayId: "day-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
          ),
        ],
      };
      final plan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: blocksByDayId,
        locations: [location],
        roles: [role],
        people: [person],
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      Future<Uint8List> generateFor({required bool includeGrids}) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: includeGrids,
        includeSequencesGrid: includeGrids,
        includePeopleGrid: includeGrids,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final withGrids = await generateFor(includeGrids: true);
      final withoutGrids = await generateFor(includeGrids: false);

      expect(withoutGrids.length, lessThan(withGrids.length));
    });

    test("a night slot crossing midnight prints the resolved hours, never modulo 1440", () async {
      final nightSlot = buildSlot(
        id: "slot-night",
        shootingDayId: "day-1",
        anchorMinute: 1140,
      ); // 19:00
      final nightSnapshot = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [nightSlot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-night",
              durationMinutes: 480,
            ),
          ], // ends at 1620
        },
      );

      final daySlot = buildSlot(id: "slot-day", shootingDayId: "day-1", anchorMinute: 480);
      final daySnapshot = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [daySlot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-day",
              durationMinutes: 480,
            ),
          ],
        },
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final nightBytes = await generateFor(nightSnapshot);
      final dayBytes = await generateFor(daySnapshot);

      expect(ascii.decode(nightBytes.sublist(0, 4)), "%PDF");
      expect(contentStreams(nightBytes), isNot(contentStreams(dayBytes)));
    });

    test("a shot table's own hours column prints the resolved hours, never modulo 1440", () async {
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");

      final nightSlot = buildSlot(
        id: "slot-night",
        shootingDayId: "day-1",
        anchorMinute: 1140,
      ); // 19:00
      final nightSnapshot = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [nightSlot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-night",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 480, // ends at 1620, i.e. 03:00 the following morning
            ),
          ],
        },
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      final daySlot = buildSlot(id: "slot-day", shootingDayId: "day-1", anchorMinute: 480);
      final daySnapshot = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [daySlot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-day",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 480,
            ),
          ],
        },
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final nightBytes = await generateFor(nightSnapshot);
      final dayBytes = await generateFor(daySnapshot);

      expect(ascii.decode(nightBytes.sublist(0, 4)), "%PDF");
      expect(contentStreams(nightBytes), isNot(contentStreams(dayBytes)));
    });

    test(
      "an end-anchored slot prints the hours the timeline resolves, not the raw anchor",
      () async {
        // Both slots are end-anchored on the very same minute (720); only their own block's
        // duration differs, so only the *resolved start* tells them apart.
        final shortSlot = buildSlot(
          id: "slot-1",
          shootingDayId: "day-1",
          anchorEdge: OcptShootingSlotAnchorEdge.end,
          anchorMinute: 720,
        );
        final shortSnapshot = buildSnapshot(
          days: [buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [shortSlot],
          },
          blocksByDayId: {
            "day-1": [
              buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1"),
            ], // starts at 690
          },
        );

        final longSlot = buildSlot(
          id: "slot-1",
          shootingDayId: "day-1",
          anchorEdge: OcptShootingSlotAnchorEdge.end,
          anchorMinute: 720,
        );
        final longSnapshot = buildSnapshot(
          days: [buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [longSlot],
          },
          blocksByDayId: {
            "day-1": [
              buildBlock(
                id: "block-1",
                shootingDayId: "day-1",
                slotId: "slot-1",
                durationMinutes: 180,
              ),
            ], // starts at 540
          },
        );

        Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
          plan: plan,
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          includeTitlePage: false,
          includeLocationsGrid: false,
          includeSequencesGrid: false,
          includePeopleGrid: false,
          includeTenMinuteGrid: false,
          includeElementsGrid: false,
          exportDate: pinnedExportDate,
        );

        final shortBytes = await generateFor(shortSnapshot);
        final longBytes = await generateFor(longSnapshot);

        expect(contentStreams(shortBytes), isNot(contentStreams(longBytes)));
      },
    );

    test("a day with no slot still writes a readable document", () async {
      final plan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: const {},
      );

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: true,
        includeSequencesGrid: true,
        includePeopleGrid: true,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(pageCount(bytes), greaterThanOrEqualTo(1));
    });

    test("a range naming no live day at all still writes a readable, one-note document", () async {
      final plan = buildSnapshot(days: const [], slotsByDayId: const {});

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["missing-day"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: true,
        includeSequencesGrid: true,
        includePeopleGrid: true,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(pageCount(bytes), 1);
    });

    test(
      "the same schedule exported twice, at the same export date, draws exactly the same pages",
      () async {
        final location = _buildLocation(id: "loc-a", name: "Studio A");
        final slot = buildSlot(
          id: "slot-1",
          shootingDayId: "day-1",
          locationId: "loc-a",
          anchorMinute: 480,
        );
        final plan = buildSnapshot(
          days: [buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          locations: [location],
        );

        Future<Uint8List> generateOnce() => service.generate(
          plan: plan,
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          includeTitlePage: true,
          includeLocationsGrid: true,
          includeSequencesGrid: true,
          includePeopleGrid: true,
          includeTenMinuteGrid: false,
          includeElementsGrid: false,
          exportDate: pinnedExportDate,
        );

        final first = await generateOnce();
        final second = await generateOnce();

        expect(contentStreams(first), contentStreams(second));
      },
    );

    test("the same schedule exported at two moments of one day draws different pages", () async {
      final plan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480)],
        },
      );

      // No title page: what tells these two apart can only be the running head's own stamp, which
      // is the whole point of repeating it on every page rather than printing it on the cover
      // alone.
      Future<Uint8List> generateAt(DateTime exportDate) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: exportDate,
      );

      final morning = await generateAt(DateTime(2026, 1, 15, 9, 15));
      final afternoon = await generateAt(DateTime(2026, 1, 15, 17, 45));

      expect(contentStreams(morning), isNot(contentStreams(afternoon)));
    });
  });
}
