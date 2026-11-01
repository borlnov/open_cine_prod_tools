// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'ocpt_shooting_plan_pdf_service_test_doubles.dart';

/// Builds a day event with the few fields these tests read, everything else neutral.
OcptShootingDayEvent _buildEvent({
  required String id,
  required String shootingDayId,
  required int minute,
  String label = "",
  String notes = "",
}) => OcptShootingDayEvent(
  id: id,
  shootingDayId: shootingDayId,
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

/// Run the tests of the shooting plan pdf service events and grid.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptShootingPlanPdfService(logger: const SilentLogger());

  const pageSetup = OcptPageSetup.standard();

  final pinnedExportDate = DateTime(2026, 1, 15);

  group("events, guests and crew notes", () {
    test("a day's own events, guests and a block's own crew note enlarge the document", () async {
      final bareSlot = buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final withoutExtras = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [bareSlot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.meal,
            ),
          ],
        },
      );

      final busySlot = buildSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        anchorMinute: 480,
        guests: [
          _buildGuest(
            id: "guest-1",
            slotId: "slot-1",
            freeName: "Mayor Dupont",
            reason: "Lends the square",
          ),
        ],
      );
      final withExtras = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [busySlot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.meal,
              crewNote: "Catering arrives at noon.",
            ),
          ],
        },
        eventsByDayId: {
          "day-1": [
            _buildEvent(
              id: "event-1",
              shootingDayId: "day-1",
              minute: 1020,
              label: "Village fireworks",
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

      // A guest's own convocation is computed like any other, and it never carries a PAT band
      // (ADR 0018) — generating a document over one must not throw.
      final guestConvocation = withExtras.convocationsOfDay("day-1").firstWhere((c) => c.isGuest);
      expect(guestConvocation.patStartMinute, isNull);
      expect(guestConvocation.patEndMinute, isNull);

      final withBytes = await generateFor(withExtras);
      final withoutBytes = await generateFor(withoutExtras);

      expect(ascii.decode(withBytes.sublist(0, 4)), "%PDF");
      expect(contentStreams(withBytes), isNot(contentStreams(withoutBytes)));
      expect(withBytes.length, greaterThan(withoutBytes.length));
    });

    test(
      "a milestone block's own crew note changes the document even with no shot on the day",
      () async {
        final slot = buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);

        OcptSchedulePlanSnapshot buildPlan(String crewNote) => buildSnapshot(
          days: [buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [
              buildBlock(
                id: "block-1",
                shootingDayId: "day-1",
                slotId: "slot-1",
                kind: OcptShootingBlockKind.meal,
                crewNote: crewNote,
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

        final withoutNote = await generateFor(buildPlan(""));
        final withNote = await generateFor(buildPlan("Keep noise down before 9am."));

        expect(contentStreams(withNote), isNot(contentStreams(withoutNote)));
      },
    );

    test("a shot block's own crew note closes its table chunk and changes the document", () async {
      final slot = buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");

      OcptSchedulePlanSnapshot buildPlan(String crewNote) => buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
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

      final withoutNote = await generateFor(buildPlan(""));
      final withNote = await generateFor(buildPlan("Bring the rain cover."));

      expect(contentStreams(withNote), isNot(contentStreams(withoutNote)));
    });
  });

  group("ten-minute day grid", () {
    test("toggled on grows the document, toggled off leaves it as it was", () async {
      final slot = buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final plan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      Future<Uint8List> generateFor({required bool includeTenMinuteGrid}) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: includeTenMinuteGrid,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final without = await generateFor(includeTenMinuteGrid: false);
      final withGrid = await generateFor(includeTenMinuteGrid: true);
      final withGridAgain = await generateFor(includeTenMinuteGrid: true);

      expect(withGrid.length, greaterThan(without.length));
      // Toggled off twice in a row, at the very same export date, draws exactly the same pages —
      // nothing about the day agenda itself changed by the option existing at all.
      final withoutAgain = await generateFor(includeTenMinuteGrid: false);
      expect(contentStreams(without), contentStreams(withoutAgain));
      expect(contentStreams(withGrid), contentStreams(withGridAgain));
    });

    test("a day whose blocks run past midnight still produces it", () async {
      final nightSlot = buildSlot(
        id: "slot-night",
        shootingDayId: "day-1",
        anchorMinute: 1140,
      ); // 19:00
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final plan = buildSnapshot(
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

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: true,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      // The day agenda, then the ten-minute grid itself spilling onto a second physical page
      // (48 rows for an eight-hour night block) — exactly the case whose own header must repeat.
      expect(pageCount(bytes), greaterThanOrEqualTo(3));
    });

    test(
      "an event pinned outside every block's own band still produces a readable document",
      () async {
        final slot = buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
        final withoutEvent = buildSnapshot(
          days: [buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [
              buildBlock(
                id: "block-1",
                shootingDayId: "day-1",
                slotId: "slot-1",
                durationMinutes: 60,
              ),
            ],
          },
        );
        final withEvent = buildSnapshot(
          days: [buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [
              buildBlock(
                id: "block-1",
                shootingDayId: "day-1",
                slotId: "slot-1",
                durationMinutes: 60,
              ),
            ],
          },
          eventsByDayId: {
            "day-1": [
              _buildEvent(
                id: "event-1",
                shootingDayId: "day-1",
                minute: 1020,
                label: "Village fireworks",
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
          includeTenMinuteGrid: true,
          includeElementsGrid: false,
          exportDate: pinnedExportDate,
        );

        final withBytes = await generateFor(withEvent);
        final withoutBytes = await generateFor(withoutEvent);

        expect(ascii.decode(withBytes.sublist(0, 4)), "%PDF");
        expect(contentStreams(withBytes), isNot(contentStreams(withoutBytes)));
      },
    );
  });
}
