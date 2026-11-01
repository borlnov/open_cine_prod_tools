// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'ocpt_call_sheet_pdf_service_test_doubles.dart';

/// Run the tests of `generateGeneralCallSheet`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate…` calls must not re-read the asset bundle).
  final service = OcptCallSheetPdfService(logger: const SilentLogger());

  const pageSetup = OcptPageSetup.standard();

  /// A day with two slots, two crews and two shots — the fixture "a day with two slots and two
  /// crews" tests are measured against, and every location/role/shot the other tests reuse.
  OcptSchedulePlanSnapshot buildTwoSlotDaySnapshot({
    List<OcptShootingSlotCrewMember> extraEveningCrew = const [],
    List<OcptShootingDayEvent> events = const [],
    List<OcptShootingSlotGuest> morningGuests = const [],
  }) {
    final locationA = buildLocation(
      id: "loc-a",
      name: "Studio A",
      latitude: 48.85,
      longitude: 2.35,
    );
    final locationB = buildLocation(id: "loc-b", name: "Location B");

    final morning = buildSlot(
      id: "slot-morning",
      label: "Morning unit",
      locationId: "loc-a",
      anchorMinute: 480, // 08:00
      crew: [
        buildCrewMember(
          id: "crew-1",
          slotId: "slot-morning",
          personId: "person-1",
          positionId: "director",
        ),
      ],
      cast: [buildCastMember(id: "cast-1", slotId: "slot-morning", roleId: "role-1")],
      guests: morningGuests,
    );
    final evening = buildSlot(
      id: "slot-evening",
      label: "Evening unit",
      locationId: "loc-b",
      anchorMinute: 1080, // 18:00
      crew: [
        buildCrewMember(id: "crew-2", slotId: "slot-evening", personId: "person-2"),
        ...extraEveningCrew,
      ],
    );

    final shot1 = buildShot(
      id: "shot-1",
      sceneId: "scene-1",
      code: "1/1",
      characters: const ["ALICE"],
    );
    final shot2 = buildShot(
      id: "shot-2",
      sceneId: "scene-1",
      code: "1/2",
      characters: const ["ALICE"],
    );

    return buildSnapshot(
      days: [testBuildDay(id: "day-1", dayNumber: 2, crewNote: "Bring rain gear.")],
      slotsByDayId: {
        "day-1": [morning, evening],
      },
      blocksByDayId: {
        "day-1": [
          buildBlock(
            id: "block-1",
            slotId: "slot-morning",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
            durationMinutes: 60,
          ),
          buildBlock(
            id: "block-2",
            slotId: "slot-evening",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-2",
            durationMinutes: 90,
          ),
        ],
      },
      eventsByDayId: events.isEmpty ? const {} : {"day-1": events},
      locations: [locationA, locationB],
      roles: [buildRole(id: "role-1", name: "Alice")],
      people: [
        buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard", phone: "0601020304"),
        buildPerson(id: "person-2", firstName: "Marc", lastName: "Petit", phone: "0605060708"),
      ],
      shotLists: [
        buildShotList(shots: [shot1, shot2]),
      ],
    );
  }

  group("generateGeneralCallSheet", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a day with two slots and two crews prints both", () async {
      final full = await service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      // Drop the evening slot and its crew entirely: the second unit's own time band, its
      // crew-list row and its shot must all disappear with it.
      final locationA = buildLocation(
        id: "loc-a",
        name: "Studio A",
        latitude: 48.85,
        longitude: 2.35,
      );
      final morning = buildSlot(
        id: "slot-morning",
        label: "Morning unit",
        locationId: "loc-a",
        anchorMinute: 480,
        crew: [
          buildCrewMember(
            id: "crew-1",
            slotId: "slot-morning",
            personId: "person-1",
            positionId: "director",
          ),
        ],
        cast: [buildCastMember(id: "cast-1", slotId: "slot-morning", roleId: "role-1")],
      );
      final shot1 = buildShot(
        id: "shot-1",
        sceneId: "scene-1",
        code: "1/1",
        characters: const ["ALICE"],
      );
      final oneSlotOnly = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 2, crewNote: "Bring rain gear.")],
        slotsByDayId: {
          "day-1": [morning],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        locations: [locationA],
        roles: [buildRole(id: "role-1", name: "Alice")],
        people: [buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [
          buildShotList(shots: [shot1]),
        ],
      );

      final single = await service.generateGeneralCallSheet(
        plan: oneSlotOnly,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(contentStreams(full), isNot(contentStreams(single)));
      // Two units printing distinct content is, by construction, a longer document than one.
      expect(full.length, greaterThan(single.length));
    });

    test("a role a placed shot plays is printed even when no slot convokes it", () async {
      // One slot convoking nobody, one shot on it played by two roles: the main table's own ROLES
      // column names both numbers, so the cast table must be able to answer for both — the second
      // role having no convocation of its own, and therefore no arrival and no PAT band.
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);
      final roles = [
        buildRole(id: "role-1", name: "Alice"),
        buildRole(id: "role-2", name: "Bob", number: 2),
      ];
      final blocks = {
        "day-1": [
          buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
            durationMinutes: 60,
          ),
        ],
      };

      final bothPlaying = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: blocks,
        roles: roles,
        shotLists: [
          buildShotList(
            shots: [
              buildShot(
                id: "shot-1",
                sceneId: "scene-1",
                code: "1/1",
                characters: const ["ALICE", "BOB"],
              ),
            ],
          ),
        ],
      );
      final oneOnly = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: blocks,
        roles: roles,
        shotLists: [
          buildShotList(
            shots: [
              buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["ALICE"]),
            ],
          ),
        ],
      );

      final bothBytes = await service.generateGeneralCallSheet(
        plan: bothPlaying,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final oneBytes = await service.generateGeneralCallSheet(
        plan: oneOnly,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      // A second cast row and a second cast-and-extras row, on a day whose slots convoke nobody at
      // all: the two documents can only differ if a role nobody convoked is printed.
      expect(contentStreams(bothBytes), isNot(contentStreams(oneBytes)));
      expect(bothBytes.length, greaterThan(oneBytes.length));
    });

    test("a night slot crossing midnight prints the resolved hours, never modulo 1440", () async {
      final nightSlot = buildSlot(id: "slot-night", anchorMinute: 1140); // 19:00
      final nightSnapshot = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [nightSlot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(id: "block-1", slotId: "slot-night", durationMinutes: 480),
          ], // ends at 1620
        },
      );

      // A same-length day that never crosses midnight, so the two documents' own time-band lines
      // must print differently: the night one alone spans past 24:00.
      final daySlot = buildSlot(id: "slot-day", anchorMinute: 480);
      final daySnapshot = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [daySlot],
        },
        blocksByDayId: {
          "day-1": [buildBlock(id: "block-1", slotId: "slot-day", durationMinutes: 480)],
        },
      );

      // Generating a night slot that resolves well past 1440 minutes must not throw.
      final nightBytes = await service.generateGeneralCallSheet(
        plan: nightSnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final dayBytes = await service.generateGeneralCallSheet(
        plan: daySnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(nightBytes.sublist(0, 4)), "%PDF");
      expect(contentStreams(nightBytes), isNot(contentStreams(dayBytes)));
    });

    test("an end-anchored slot prints the hours the timeline resolves, not the raw "
        "anchor", () async {
      // Both slots are end-anchored on the very same minute (720); only their own block's duration
      // differs, so only the *resolved start* tells them apart — a service that printed the stored
      // anchor by mistake would draw the two documents identically.
      final shortSlot = buildSlot(
        id: "slot-1",
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 720,
      );
      final shortSnapshot = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [shortSlot],
        },
        blocksByDayId: {
          "day-1": [buildBlock(id: "block-1", slotId: "slot-1")], // starts at 690
        },
      );

      final longSlot = buildSlot(
        id: "slot-1",
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 720,
      );
      final longSnapshot = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [longSlot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(id: "block-1", slotId: "slot-1", durationMinutes: 180),
          ], // starts at 540
        },
      );

      final shortBytes = await service.generateGeneralCallSheet(
        plan: shortSnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final longBytes = await service.generateGeneralCallSheet(
        plan: longSnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(contentStreams(shortBytes), isNot(contentStreams(longBytes)));
    });

    test("a day with no slot at all still writes a readable one-page document", () async {
      final emptySnapshot = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: const {},
      );

      final bytes = await service.generateGeneralCallSheet(
        plan: emptySnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(pageCount(bytes), 1);
    });

    test("a day id the schedule holds nothing for still writes a readable document", () async {
      final snapshot = buildSnapshot(days: const [], slotsByDayId: const {});

      final bytes = await service.generateGeneralCallSheet(
        plan: snapshot,
        dayId: "missing-day",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(pageCount(bytes), 1);
    });

    test("the same schedule exported twice draws exactly the same pages", () async {
      final first = await service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final second = await service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(contentStreams(first), contentStreams(second));
    });

    test("two sheets of one day, produced at two moments, do not draw the same pages", () async {
      Future<Uint8List> generateAt(DateTime exportDate) => service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: exportDate,
      );

      final morning = await generateAt(DateTime(2026, 1, 15, 9, 15));
      final afternoon = await generateAt(DateTime(2026, 1, 15, 17, 45));

      expect(contentStreams(morning), isNot(contentStreams(afternoon)));
    });
  });
}
