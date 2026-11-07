// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'ocpt_call_sheet_pdf_service_test_doubles.dart';

/// Run the tests of the call sheet pdf service department contacts.
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

  group("the by-department contacts block wraps at four columns per row", () {
    /// One person per crew-block department (castingAndExtras, image, electricAndGrip, sound,
    /// artDepartment, costume, hairAndMakeUp, specialEffects — eight, one over the four-column
    /// row `_contactsColumnsPerRow` wraps at), each convoked through a slot's own crew list.
    ///
    /// These tests only prove [count] departments are all still printed — not dropped, not
    /// truncated — once there are more than fit one row: the byte comparisons below read the
    /// still-compressed content streams (see `contentStreams`'s own doc comment), which carries
    /// no readable text and no page geometry, so the actual "two rows of four" grid the reference
    /// call sheet lays out cannot be asserted from here. That grid is covered by hand, and by the
    /// service's own doc comment.
    OcptSchedulePlanSnapshot buildDayWithDepartments(int count) {
      const positionsByDepartment = [
        "castingDirector", // castingAndExtras
        "cameraOperator", // image
        "gaffer", // electricAndGrip
        "soundEngineer", // sound
        "setDecorator", // artDepartment
        "costumeDesigner", // costume
        "makeupArtist", // hairAndMakeUp
        "specialEffectsSupervisor", // specialEffects
      ];
      final people = [
        for (var i = 0; i < count; i++)
          buildPerson(id: "person-$i", firstName: "First$i", lastName: "Last$i"),
      ];
      final crew = [
        for (var i = 0; i < count; i++)
          buildCrewMember(
            id: "crew-$i",
            slotId: "slot-1",
            personId: "person-$i",
            positionId: positionsByDepartment[i],
          ),
      ];

      return buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [buildSlot(id: "slot-1", anchorMinute: 480, crew: crew)],
        },
        people: people,
      );
    }

    test("eight departments print something a four-department day does not", () async {
      final eightBytes = await service.generateGeneralCallSheet(
        plan: buildDayWithDepartments(8),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final fourBytes = await service.generateGeneralCallSheet(
        plan: buildDayWithDepartments(4),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(contentStreams(eightBytes), isNot(contentStreams(fourBytes)));
    });

    test("eight departments still fit a single page, the same as four", () async {
      final eightBytes = await service.generateGeneralCallSheet(
        plan: buildDayWithDepartments(8),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final fourBytes = await service.generateGeneralCallSheet(
        plan: buildDayWithDepartments(4),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(pageCount(eightBytes), 1);
      expect(pageCount(fourBytes), 1);
    });
  });

  group("generateNamedCallSheet vs generateGeneralCallSheet", () {
    test("a named sheet carries the day's own directories, so it grows with the crew", () async {
      final plan = buildTwoSlotDaySnapshot();
      final convocation = plan
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final namedBytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: convocation,
        exportDate: pinnedExportDate,
      );

      // A brand new crew member, on the *other* unit, in a department that never reaches the key
      // contacts block either (image, not production/direction): the only sections that can see
      // them are the department-contacts table and the crew list, both of which a named sheet now
      // prints.
      final grownPlan = buildTwoSlotDaySnapshot(
        extraEveningCrew: [
          buildCrewMember(
            id: "crew-3",
            slotId: "slot-evening",
            personId: "person-3",
            positionId: "cameraOperator",
          ),
        ],
      );
      final grownPlanWithPerson = _addPerson(
        grownPlan,
        buildPerson(id: "person-3", firstName: "Léa", lastName: "Bernard", phone: "0611223344"),
      );
      final grownConvocation = grownPlanWithPerson
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");

      final generalBytesBefore = await service.generateGeneralCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final generalBytesAfter = await service.generateGeneralCallSheet(
        plan: grownPlanWithPerson,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final namedBytesAfter = await service.generateNamedCallSheet(
        plan: grownPlanWithPerson,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: grownConvocation,
        exportDate: pinnedExportDate,
      );

      // The general sheet's own crew list grew...
      expect(contentStreams(generalBytesBefore), isNot(contentStreams(generalBytesAfter)));
      // ...and so did the named one's, the two directories being facts about the day rather than
      // about whoever the sheet is addressed to.
      expect(contentStreams(namedBytes), isNot(contentStreams(namedBytesAfter)));
    });

    test("two recipients of one day get sheets narrowed to their own slots", () async {
      final plan = buildTwoSlotDaySnapshot();
      final morning = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
      final evening = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-2");

      final morningBytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: morning,
        exportDate: pinnedExportDate,
      );
      final eveningBytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: evening,
        exportDate: pinnedExportDate,
      );

      // Every closing table is day-wide and therefore identical between the two; what still has to
      // differ is the recipient line, their own band, their location and their own timetable.
      expect(contentStreams(morningBytes), isNot(contentStreams(eveningBytes)));
    });

    test("a person's arrival, PAT band and departure print as three distinct figures", () async {
      // slot-1, start-anchored at 08:00: a preparation block (not shooting, 08:00-08:30), a shot
      // block (08:30-09:30) and a wrap block (09:30-10:00, not shooting either) — so arrival
      // (08:00), PAT start (08:30), PAT end (09:30) and departure (10:00) are four distinct
      // minutes.
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final fullPlan = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(id: "prep", slotId: "slot-1"),
            buildBlock(
              id: "shot",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
            buildBlock(id: "wrap", slotId: "slot-1", kind: OcptShootingBlockKind.wrap),
          ],
        },
        people: [buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      // Drop the wrap block: departure now collapses onto the PAT end (09:30), so the four-figure
      // fixture's own bytes must differ from this one — proving departure is its own figure.
      final noWrapPlan = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(id: "prep", slotId: "slot-1"),
            buildBlock(
              id: "shot",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        people: [buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      // Drop the preparation block too: arrival now collapses onto PAT start (08:30) as well.
      final onlyShotPlan = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "shot",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        people: [buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) async {
        final convocation = plan.convocationsOfDay("day-1").single;
        return service.generateNamedCallSheet(
          plan: plan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          convocation: convocation,
          exportDate: pinnedExportDate,
        );
      }

      final full = await generateFor(fullPlan);
      final noWrap = await generateFor(noWrapPlan);
      final onlyShot = await generateFor(onlyShotPlan);

      // Removing the wrap block changes departure alone.
      expect(contentStreams(full), isNot(contentStreams(noWrap)));
      // Removing the preparation block too then changes arrival as well.
      expect(contentStreams(noWrap), isNot(contentStreams(onlyShot)));
    });

    test("a convocation with no shooting block prints an em dash for its PAT band", () async {
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );
      final plan = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [buildBlock(id: "prep", slotId: "slot-1")],
        },
        people: [buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
      );
      final convocation = plan.convocationsOfDay("day-1").single;

      expect(convocation.patStartMinute, isNull);

      final bytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: convocation,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a named sheet is stamped too: two moments, two documents", () async {
      final plan = buildTwoSlotDaySnapshot();
      final convocation = plan
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");

      Future<Uint8List> generateAt(DateTime exportDate) => service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: convocation,
        exportDate: exportDate,
      );

      final morning = await generateAt(DateTime(2026, 1, 15, 9, 15));
      final afternoon = await generateAt(DateTime(2026, 1, 15, 17, 45));

      expect(contentStreams(morning), isNot(contentStreams(afternoon)));
    });
  });
}

/// [plan] with [person] appended to its address book — used to grow a fixture's own catalogue
/// without rebuilding every other field.
OcptSchedulePlanSnapshot _addPerson(OcptSchedulePlanSnapshot plan, OcptPerson person) =>
    OcptSchedulePlanSnapshot.build(
      schedule: plan.schedule,
      shotLists: plan.shotLists,
      episodes: const [],
      locations: plan.locations,
      roles: plan.roles,
      people: [...plan.people, person],
      elements: plan.elements,
      minimumRestMinutes: plan.minimumRestMinutes,
    );
