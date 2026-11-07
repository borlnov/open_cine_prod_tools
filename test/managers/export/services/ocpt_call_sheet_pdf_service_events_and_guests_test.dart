// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'ocpt_call_sheet_pdf_service_test_doubles.dart';

/// Builds a day event with the few fields these tests read, everything else neutral.
OcptShootingDayEvent _buildEvent({
  required String id,
  required int minute,
  String label = "",
  String notes = "",
}) => OcptShootingDayEvent(
  id: id,
  shootingDayId: "day-1",
  minute: minute,
  label: label,
  notes: notes,
);

/// Builds a slot guest with the few fields these tests read, everything else neutral.
OcptShootingSlotGuest _buildGuest({
  required String id,
  required String slotId,
  String? personId,
  String freeName = "",
  String reason = "",
  String notes = "",
}) => OcptShootingSlotGuest(
  id: id,
  slotId: slotId,
  personId: personId,
  freeName: freeName,
  reason: reason,
  notes: notes,
);

/// Run the tests of the call sheet pdf service events and guests.
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

  group("events, guests and crew notes", () {
    test("a day's own events change what both sheets print", () async {
      final withoutEvents = buildTwoSlotDaySnapshot();
      final withEvents = buildTwoSlotDaySnapshot(
        events: [_buildEvent(id: "event-1", minute: 1020, label: "Village fireworks")],
      );

      final generalWithout = await service.generateGeneralCallSheet(
        plan: withoutEvents,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final generalWith = await service.generateGeneralCallSheet(
        plan: withEvents,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      expect(contentStreams(generalWith), isNot(contentStreams(generalWithout)));

      final convocationWithout = withoutEvents
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final convocationWith = withEvents
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final namedWithout = await service.generateNamedCallSheet(
        plan: withoutEvents,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: convocationWithout,
        exportDate: pinnedExportDate,
      );
      final namedWith = await service.generateNamedCallSheet(
        plan: withEvents,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: convocationWith,
        exportDate: pinnedExportDate,
      );
      expect(contentStreams(namedWith), isNot(contentStreams(namedWithout)));
    });

    test("a day's own guests change what both sheets print, and a guest with no PAT band does not "
        "crash", () async {
      final withoutGuest = buildTwoSlotDaySnapshot();
      final withGuest = buildTwoSlotDaySnapshot(
        morningGuests: [
          _buildGuest(
            id: "guest-1",
            slotId: "slot-morning",
            freeName: "Mayor Dupont",
            reason: "Lends the square",
          ),
        ],
      );

      // A guest's own convocation is computed like any other, and it never carries a PAT band
      // (ADR 0018) — generating a sheet over one must not throw.
      final guestConvocation = withGuest.convocationsOfDay("day-1").firstWhere((c) => c.isGuest);
      expect(guestConvocation.patStartMinute, isNull);
      expect(guestConvocation.patEndMinute, isNull);

      final generalWithout = await service.generateGeneralCallSheet(
        plan: withoutGuest,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final generalWith = await service.generateGeneralCallSheet(
        plan: withGuest,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      expect(ascii.decode(generalWith.sublist(0, 4)), "%PDF");
      expect(contentStreams(generalWith), isNot(contentStreams(generalWithout)));

      // The guest table is day-wide (like the cast table and the two directories), so it shows up
      // on a named sheet too, even one addressed to the morning unit's own director rather than
      // to the guest.
      final convocationWithout = withoutGuest
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final convocationWith = withGuest
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final namedWithout = await service.generateNamedCallSheet(
        plan: withoutGuest,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: convocationWithout,
        exportDate: pinnedExportDate,
      );
      final namedWith = await service.generateNamedCallSheet(
        plan: withGuest,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: convocationWith,
        exportDate: pinnedExportDate,
      );
      expect(ascii.decode(namedWith.sublist(0, 4)), "%PDF");
      expect(contentStreams(namedWith), isNot(contentStreams(namedWithout)));
    });

    test("a shot block's own crew note changes the sheet", () async {
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");

      OcptSchedulePlanSnapshot buildPlan(String crewNote) => buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
              crewNote: crewNote,
            ),
          ],
        },
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      final withoutNote = await service.generateGeneralCallSheet(
        plan: buildPlan(""),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final withNote = await service.generateGeneralCallSheet(
        plan: buildPlan("Bring the rain cover."),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(contentStreams(withNote), isNot(contentStreams(withoutNote)));
    });

    test("a milestone block's own crew note changes the sheet", () async {
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);

      OcptSchedulePlanSnapshot buildPlan(String crewNote) => buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.meal,
              crewNote: crewNote,
            ),
          ],
        },
      );

      final withoutNote = await service.generateGeneralCallSheet(
        plan: buildPlan(""),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final withNote = await service.generateGeneralCallSheet(
        plan: buildPlan("Catering arrives at noon."),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(contentStreams(withNote), isNot(contentStreams(withoutNote)));
    });

    test("a named sheet prints only its own slots' blocks' crew notes", () async {
      final morning = buildSlot(
        id: "slot-morning",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1")],
      );
      final evening = buildSlot(
        id: "slot-evening",
        anchorMinute: 1080,
        crew: [buildCrewMember(id: "crew-2", slotId: "slot-evening", personId: "person-2")],
      );
      final shot1 = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final shot2 = buildShot(id: "shot-2", sceneId: "scene-1", code: "1/2");

      OcptSchedulePlanSnapshot buildPlan({required String eveningCrewNote}) => buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
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
              crewNote: "Morning note.",
            ),
            buildBlock(
              id: "block-2",
              slotId: "slot-evening",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-2",
              durationMinutes: 60,
              crewNote: eveningCrewNote,
            ),
          ],
        },
        people: [
          buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard"),
          buildPerson(id: "person-2", firstName: "Marc", lastName: "Petit"),
        ],
        shotLists: [
          buildShotList(shots: [shot1, shot2]),
        ],
      );

      final withoutEveningNote = buildPlan(eveningCrewNote: "");
      final withEveningNote = buildPlan(eveningCrewNote: "Evening note.");

      // The morning recipient's own sheet only ever draws their own slot's blocks: changing the
      // evening slot's own crew note must not move a single byte of it.
      final morningConvocationWithout = withoutEveningNote
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final morningConvocationWith = withEveningNote
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final morningBytesWithout = await service.generateNamedCallSheet(
        plan: withoutEveningNote,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: morningConvocationWithout,
        exportDate: pinnedExportDate,
      );
      final morningBytesWith = await service.generateNamedCallSheet(
        plan: withEveningNote,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: morningConvocationWith,
        exportDate: pinnedExportDate,
      );
      expect(contentStreams(morningBytesWith), contentStreams(morningBytesWithout));

      // But the evening recipient's own sheet does draw the new note.
      final eveningConvocationWithout = withoutEveningNote
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-2");
      final eveningConvocationWith = withEveningNote
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-2");
      final eveningBytesWithout = await service.generateNamedCallSheet(
        plan: withoutEveningNote,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: eveningConvocationWithout,
        exportDate: pinnedExportDate,
      );
      final eveningBytesWith = await service.generateNamedCallSheet(
        plan: withEveningNote,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: eveningConvocationWith,
        exportDate: pinnedExportDate,
      );
      expect(contentStreams(eveningBytesWith), isNot(contentStreams(eveningBytesWithout)));
    });
  });
}
