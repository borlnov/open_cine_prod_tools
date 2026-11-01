// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_sides_presentation.dart';
import 'package:path/path.dart' as p;
import 'ocpt_export_manager_test_doubles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A folder a call sheet export cannot write into logs the failure through appLogger(), which
  // requires a global manager instance to be set; merely accessing it creates the (otherwise
  // unused) singleton — the same fixture `ocpt_schedule_service_test.dart` uses.
  setUpAll(() => OcptGlobalManager.instance);

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_export_manager_test_");
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('exportDayOutOfDays', () {
    const labels = OcptDayOutOfDaysLabels(
      fileNameSuffix: "day out of days",
      documentTitle: "Day Out of Days",
      directorLine: "",
      versionLabel: "Version",
      dayTagPrefix: "D",
      dayDateLabels: {},
      roleHeader: "Role",
      workedDaysHeader: "Worked",
      heldDaysHeader: "Held",
      codeLabels: {},
      codeDescriptions: {},
      legendSectionTitle: "Legend",
      unnamedRoleLabel: "Unnamed role",
      emptyTableNote: "No role is called on the printed days yet.",
    );

    /// A one-day, one-slot schedule plan convoking one role — enough for one table row.
    OcptSchedulePlanSnapshot buildPlan() {
      final day = OcptShootingDay(
        id: "day-1",
        date: DateTime(2026, 1, 2),
        dayNumber: 2,
        status: OcptShootingDayStatus.planned,
        crewNote: "",
        weatherNote: "",
        notes: "",
      );
      const slot = OcptShootingSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        label: "",
        locationId: null,
        setId: null,
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorMinute: 480,
        anchorSlotId: null,
        notes: "",
        crew: [],
        cast: [
          OcptShootingSlotCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1", notes: ""),
        ],
        guests: [],
      );

      return OcptSchedulePlanSnapshot.build(
        schedule: OcptScheduleSnapshot.build(
          days: [day],
          slotsByDayId: const {
            "day-1": [slot],
          },
          blocksByDayId: const {},
          eventsByDayId: const {},
        ),
        shotLists: const [],
        episodes: const [],
        locations: const [],
        roles: const [
          OcptRole(
            id: "role-1",
            name: "Alice",
            personId: null,
            kind: OcptRoleKind.speaking,
            isFromScreenplay: true,
            orphanedName: null,
            castingNotes: "",
            number: 1,
            episodeIds: [],
          ),
        ],
        people: const [],
        elements: const [],
        minimumRestMinutes: null,
      );
    }

    Future<OcptExportOutcome?> export(OcptExportManager manager) => manager.exportDayOutOfDays(
      plan: buildPlan(),
      dayIds: const ["day-1"],
      pageSetup: const OcptPageSetup.standard(),
      labels: labels,
      projectName: "My Movie",
      includeTitlePage: true,
      fileTypeLabel: "PDF document",
    );

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a single PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - day out of days.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptDayOutOfDaysPdfService, suffixed', () async {
      final saveLocationService = FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await export(manager);

      expect(saveLocationService.lastSuggestedFileName, "My Movie - day out of days.pdf");
      expect(saveLocationService.lastFileTypeLabel, "PDF document");
      expect(saveLocationService.lastExtensions, const ["pdf"]);
    });
  });

  group('exportOneLineSchedule', () {
    const labels = OcptOneLineScheduleLabels(
      fileNameSuffix: "one-line schedule",
      documentTitle: "One-line schedule",
      directorLine: "",
      versionLabel: "Version",
      dayTagPrefix: "D",
      dayTitles: {},
      seqHeader: "SEQ",
      effectHeader: "EFFECT",
      decorHeader: "SET",
      rolesHeader: "CAST",
      durationHeader: "DURATION",
      noLocationLabel: "No location yet",
      emptyDayNote: "Nothing planned for this day.",
      emptyDocumentNote: "Nothing to print.",
    );

    /// A one-day, one-slot schedule plan with no block placed — enough for one readable page.
    OcptSchedulePlanSnapshot buildPlan() {
      final day = OcptShootingDay(
        id: "day-1",
        date: DateTime(2026, 1, 2),
        dayNumber: 2,
        status: OcptShootingDayStatus.planned,
        crewNote: "",
        weatherNote: "",
        notes: "",
      );
      const slot = OcptShootingSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        label: "",
        locationId: null,
        setId: null,
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorMinute: 480,
        anchorSlotId: null,
        notes: "",
        crew: [],
        cast: [],
        guests: [],
      );

      return OcptSchedulePlanSnapshot.build(
        schedule: OcptScheduleSnapshot.build(
          days: [day],
          slotsByDayId: const {
            "day-1": [slot],
          },
          blocksByDayId: const {},
          eventsByDayId: const {},
        ),
        shotLists: const [],
        episodes: const [],
        locations: const [],
        roles: const [],
        people: const [],
        elements: const [],
        minimumRestMinutes: null,
      );
    }

    Future<OcptExportOutcome?> export(OcptExportManager manager) => manager.exportOneLineSchedule(
      plan: buildPlan(),
      dayIds: const ["day-1"],
      pageSetup: const OcptPageSetup.standard(),
      labels: labels,
      projectName: "My Movie",
      includeTitlePage: true,
      fileTypeLabel: "PDF document",
    );

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a single PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - one-line schedule.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptOneLineSchedulePdfService, suffixed', () async {
      final saveLocationService = FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await export(manager);

      expect(saveLocationService.lastSuggestedFileName, "My Movie - one-line schedule.pdf");
      expect(saveLocationService.lastFileTypeLabel, "PDF document");
      expect(saveLocationService.lastExtensions, const ["pdf"]);
    });
  });

  group('exportSides', () {
    const labels = OcptSidesLabels(
      fileNameSuffix: "sides",
      documentTitle: "Sides",
      versionLabel: "Version",
      dayTagPrefix: "D",
      dayTitle: "",
      episodeLabels: {},
      scriptPagePrefix: "p.",
      emptyDayNote: "Nothing planned for this day.",
    );

    final document = const FountainParser().parse("INT. HOUSE - DAY\n\nJohn walks in.\n");

    /// A one-day, one-slot schedule plan with no block placed — enough for one readable note page,
    /// the same shape `exportOneLineSchedule`'s own `buildPlan` uses.
    OcptSchedulePlanSnapshot buildPlan() {
      final day = OcptShootingDay(
        id: "day-1",
        date: DateTime(2026, 1, 2),
        dayNumber: 2,
        status: OcptShootingDayStatus.planned,
        crewNote: "",
        weatherNote: "",
        notes: "",
      );
      const slot = OcptShootingSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        label: "",
        locationId: null,
        setId: null,
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorMinute: 480,
        anchorSlotId: null,
        notes: "",
        crew: [],
        cast: [],
        guests: [],
      );

      return OcptSchedulePlanSnapshot.build(
        schedule: OcptScheduleSnapshot.build(
          days: [day],
          slotsByDayId: const {
            "day-1": [slot],
          },
          blocksByDayId: const {},
          eventsByDayId: const {},
        ),
        shotLists: const [],
        episodes: const [],
        locations: const [],
        roles: const [],
        people: const [],
        elements: const [],
        minimumRestMinutes: null,
      );
    }

    Future<OcptExportOutcome?> export(OcptExportManager manager) => manager.exportSides(
      plan: buildPlan(),
      dayId: "day-1",
      documents: [(screenplayId: "screenplay-1", document: document)],
      pageSetup: const OcptPageSetup.standard(),
      labels: labels,
      projectName: "My Movie",
      includeSceneNumbers: false,
      presentation: OcptSidesPresentation.scriptPages,
      fileTypeLabel: "PDF document",
    );

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a single PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - sides - D2.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptSidesPdfService, with the day tag', () async {
      final saveLocationService = FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await export(manager);

      expect(saveLocationService.lastSuggestedFileName, "My Movie - sides - D2.pdf");
      expect(saveLocationService.lastFileTypeLabel, "PDF document");
      expect(saveLocationService.lastExtensions, const ["pdf"]);
    });
  });
}
