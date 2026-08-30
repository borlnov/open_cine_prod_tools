// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_share_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:path/path.dart' as p;

/// The seven weekday names an availability window's summary cell is built from, keyed by their
/// `DateTime.monday`…`DateTime.sunday` numbers — the locale's own names in the app, plain English
/// ones here.
const Map<int, String> _weekdayLabels = {
  DateTime.monday: "Mon",
  DateTime.tuesday: "Tue",
  DateTime.wednesday: "Wed",
  DateTime.thursday: "Thu",
  DateTime.friday: "Fri",
  DateTime.saturday: "Sat",
  DateTime.sunday: "Sun",
};

/// A save-location service whose [pickSaveLocation] is stubbed and whose calls are recorded, so
/// the manager's export methods can be exercised without any real native dialog.
class _FakeSaveLocationService extends OcptSaveLocationService {
  /// Class constructor
  _FakeSaveLocationService({this.result});

  /// The path [pickSaveLocation] returns, or null to simulate a cancelled dialog.
  final String? result;

  /// The suggested file name of the last [pickSaveLocation] call.
  String? lastSuggestedFileName;

  /// The file type label of the last [pickSaveLocation] call.
  String? lastFileTypeLabel;

  /// The extensions of the last [pickSaveLocation] call.
  List<String>? lastExtensions;

  /// The path [pickDirectory] returns, or null to simulate a cancelled dialog — independent of
  /// [result], since the call sheet exports pick a folder rather than a file.
  String? directoryResult;

  /// The confirm-button label of the last [pickDirectory] call.
  String? lastConfirmButtonText;

  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
  }) async {
    lastSuggestedFileName = suggestedFileName;
    lastFileTypeLabel = fileTypeLabel;
    lastExtensions = extensions;
    return result;
  }

  @override
  Future<String?> pickDirectory({required String confirmButtonText}) async {
    lastConfirmButtonText = confirmButtonText;
    return directoryResult;
  }
}

/// A [PlatformManager] whose [isMobile] is stubbed, so the manager's write funnel can be exercised
/// on either branch without a real platform underneath it.
class _StubPlatformManager extends PlatformManager {
  /// Class constructor
  _StubPlatformManager({required this.isMobile});

  @override
  final bool isMobile;
}

/// A share service whose [temporaryDirectory] and [shareFiles] are stubbed and whose calls are
/// recorded, so the manager's mobile write funnel can be exercised without any real OS share sheet.
class _FakeShareService extends OcptShareService {
  /// Class constructor
  _FakeShareService({required Directory directory, this.result = true}) : _directory = directory;

  /// The directory [temporaryDirectory] resolves to.
  final Directory _directory;

  /// Whether [shareFiles] reports the share sheet as shown.
  final bool result;

  /// The paths of the last [shareFiles] call.
  List<String>? lastPaths;

  /// The anchor of the last [shareFiles] call.
  Rect? lastSharePositionOrigin;

  @override
  Future<Directory> temporaryDirectory() async => _directory;

  @override
  Future<bool> shareFiles({required List<String> paths, Rect? sharePositionOrigin}) async {
    lastPaths = paths;
    lastSharePositionOrigin = sharePositionOrigin;
    return result;
  }
}

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

  group('exportFountain', () {
    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(),
      );

      final path = await manager.exportFountain(
        fountainText: "INT. HOUSE - DAY\n\nAction.\n",
        projectName: "My Movie",
        fileTypeLabel: "Fountain screenplay",
      );

      expect(path, isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives the encoded bytes and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie.fountain");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );
      const fountainText = "INT. HOUSE - DAY\n\nAction.\n";

      final path = await manager.exportFountain(
        fountainText: fountainText,
        projectName: "My Movie",
        fileTypeLabel: "Fountain screenplay",
      );

      expect(path, OcptExportSaved(chosenPath));
      expect(
        await File(chosenPath).readAsBytes(),
        manager.fountainIoService.encodeFountainText(fountainText),
      );
    });

    test('suggests the file name computed by OcptFountainIoService', () async {
      final saveLocationService = _FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await manager.exportFountain(
        fountainText: "INT. HOUSE - DAY\n",
        projectName: "My Movie",
        fileTypeLabel: "Fountain screenplay",
      );

      expect(saveLocationService.lastSuggestedFileName, "My Movie.fountain");
      expect(saveLocationService.lastFileTypeLabel, "Fountain screenplay");
      expect(saveLocationService.lastExtensions, [OcptFountainIoService.fountainFileExtension]);
    });
  });

  group('the write funnel on mobile', () {
    // Exercised through exportFountain alone: every export method funnels through the very same
    // private _writeToPickedLocation, so this is the one place the desktop/mobile branch itself
    // needs covering — each export method's own tests above already cover its own file name and
    // bytes on the desktop branch.
    const fountainText = "INT. HOUSE - DAY\n\nAction.\n";

    test(
      'writes to a temporary file and shares it instead of showing the native save dialog',
      () async {
        final saveLocationService = _FakeSaveLocationService(result: p.join(tempDir.path, "unused"));
        final shareService = _FakeShareService(directory: tempDir);
        final manager = OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
          platformManager: _StubPlatformManager(isMobile: true),
          shareService: shareService,
        );
        const anchor = Rect.fromLTWH(1, 2, 3, 4);

        final outcome = await manager.exportFountain(
          fountainText: fountainText,
          projectName: "My Movie",
          fileTypeLabel: "Fountain screenplay",
          shareAnchor: anchor,
        );

        expect(outcome, const OcptExportShared());
        // The native save dialog is never shown on mobile.
        expect(saveLocationService.lastSuggestedFileName, isNull);

        final sharedPaths = shareService.lastPaths;
        expect(sharedPaths, hasLength(1));
        expect(p.basename(sharedPaths!.single), "My Movie.fountain");
        expect(
          await File(sharedPaths.single).readAsBytes(),
          manager.fountainIoService.encodeFountainText(fountainText),
        );
        expect(shareService.lastSharePositionOrigin, anchor);
      },
    );

    test('a share sheet that could not be shown reports null, exactly like a failed write', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(),
        platformManager: _StubPlatformManager(isMobile: true),
        shareService: _FakeShareService(directory: tempDir, result: false),
      );

      final outcome = await manager.exportFountain(
        fountainText: fountainText,
        projectName: "My Movie",
        fileTypeLabel: "Fountain screenplay",
      );

      expect(outcome, isNull);
    });
  });

  group('exportPdf', () {
    const parser = FountainParser();
    final document = parser.parse("INT. HOUSE - DAY\n\nAction.\n");
    const pageSetup = OcptPageSetup.standard();

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(),
      );

      final path = await manager.exportPdf(
        document: document,
        pageSetup: pageSetup,
        projectName: "My Movie",
        includeSceneNumbers: true,
        includeTitlePage: true,
        fileTypeLabel: "PDF document",
      );

      expect(path, isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives the generated bytes and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      final path = await manager.exportPdf(
        document: document,
        pageSetup: pageSetup,
        projectName: "My Movie",
        includeSceneNumbers: true,
        includeTitlePage: true,
        fileTypeLabel: "PDF document",
      );

      expect(path, OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(writtenBytes, isNotEmpty);
      expect(String.fromCharCodes(writtenBytes.take(4)), "%PDF");
    });

    test('suggests the file name computed by OcptPdfExportService', () async {
      final saveLocationService = _FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await manager.exportPdf(
        document: document,
        pageSetup: pageSetup,
        projectName: "My Movie",
        includeSceneNumbers: true,
        includeTitlePage: true,
        fileTypeLabel: "PDF document",
      );

      expect(saveLocationService.lastSuggestedFileName, "My Movie.pdf");
      expect(saveLocationService.lastFileTypeLabel, "PDF document");
      expect(saveLocationService.lastExtensions, const ["pdf"]);
    });
  });

  group('exportScenarioCoverage', () {
    const parser = FountainParser();
    final document = parser.parse("INT. HOUSE - DAY\n\nAction.\n");
    const pageSetup = OcptPageSetup.standard();
    final snapshot = OcptShotListSnapshot.build(
      screenplayId: "screenplay",
      sequences: const [],
    );
    const labels = OcptScenarioCoverageLabels(
      fileNameSuffix: "coverage",
      legendTitle: "Legend",
      legendShotHeader: "Shot",
      legendShotSizeHeader: "Shot size",
      legendFramingHeader: "Framing",
      legendCameraMoveHeader: "Camera move",
      summaryTitle: "Summary",
      summarySequenceHeader: "Sequence",
      summaryShotCountHeader: "Shots",
      summaryCoveredHeader: "Covered",
      summaryStaleHeader: "To check",
      summaryUncoveredHeader: "Uncovered",
      laneOverflowNote: "Some bars share a lane.",
      sequenceTitles: {},
    );

    Future<OcptExportOutcome?> export(OcptExportManager manager) => manager.exportScenarioCoverage(
      document: document,
      screenplayText: "INT. HOUSE - DAY\n\nAction.\n",
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: "My Movie",
      includeSceneNumbers: true,
      includeTitlePage: true,
      includeLegendPage: true,
      includeSummaryPage: true,
      fileTypeLabel: "PDF document",
    );

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives the generated bytes and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - coverage.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(writtenBytes, isNotEmpty);
      expect(String.fromCharCodes(writtenBytes.take(4)), "%PDF");
    });

    test('suggests the file name computed from the localized suffix', () async {
      final saveLocationService = _FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await export(manager);

      expect(saveLocationService.lastSuggestedFileName, "My Movie - coverage.pdf");
      expect(saveLocationService.lastFileTypeLabel, "PDF document");
      expect(saveLocationService.lastExtensions, const ["pdf"]);
    });
  });

  group('exportShotListXlsx', () {
    final snapshot = OcptShotListSnapshot.build(
      screenplayId: "screenplay",
      sequences: const [],
    );
    const labels = OcptShotListXlsxLabels(
      sheetName: "Shot list",
      columnHeaders: {},
      statusLabels: {},
      sequenceTitles: {},
      dayTagPrefix: "D",
    );

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(),
      );

      final path = await manager.exportShotListXlsx(
        snapshot: snapshot,
        labels: labels,
        projectName: "My Movie",
        fileTypeLabel: "Excel workbook",
      );

      expect(path, isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a readable workbook and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie.xlsx");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      final path = await manager.exportShotListXlsx(
        snapshot: snapshot,
        labels: labels,
        projectName: "My Movie",
        fileTypeLabel: "Excel workbook",
      );

      expect(path, OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(Excel.decodeBytes(writtenBytes).tables.keys, ["Shot list"]);
    });

    test('suggests the file name computed by OcptShotListXlsxExportService', () async {
      final saveLocationService = _FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await manager.exportShotListXlsx(
        snapshot: snapshot,
        labels: labels,
        projectName: "My Movie",
        fileTypeLabel: "Excel workbook",
      );

      expect(saveLocationService.lastSuggestedFileName, "My Movie.xlsx");
      expect(saveLocationService.lastFileTypeLabel, "Excel workbook");
      expect(saveLocationService.lastExtensions, const [
        OcptShotListXlsxExportService.xlsxFileExtension,
      ]);
    });
  });

  group('exportResourcesXlsx', () {
    final snapshot = OcptResourcesSnapshot.build(
      people: const [],
      roles: const [],
      locations: const [],
      elements: const [],
      candidatesByRoleId: const {},
      scenes: const [],
    );
    const labels = OcptResourcesXlsxLabels(
      fileNameSuffix: "resources",
      peopleSheetName: "People",
      rolesSheetName: "Roles",
      locationsSheetName: "Locations",
      elementsSheetName: "Elements",
      peopleColumnHeaders: {},
      rolesColumnHeaders: {},
      locationsColumnHeaders: {},
      elementsColumnHeaders: {},
      crewPositionLabels: {},
      roleKindLabels: {},
      imageRightsStatusLabels: {},
      permitStatusLabels: {},
      elementCategoryLabels: {},
      elementSourceKindLabels: {},
      dayPartSlotLabels: {},
      availabilityKindLabels: {},
      elementTrackingToSecureLabel: "To secure",
      elementTrackingSecuredLabel: "Secured",
      elementTrackingReadyLabel: "Ready",
      elementTrackingReturnedLabel: "Returned",
      everyDayLabel: "Every day",
      weekdayLabels: _weekdayLabels,
      sceneLabels: {},
    );

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(),
      );

      final path = await manager.exportResourcesXlsx(
        snapshot: snapshot,
        labels: labels,
        projectName: "My Movie",
        fileTypeLabel: "Excel workbook",
      );

      expect(path, isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a readable, four-sheet workbook and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - resources.xlsx");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      final path = await manager.exportResourcesXlsx(
        snapshot: snapshot,
        labels: labels,
        projectName: "My Movie",
        fileTypeLabel: "Excel workbook",
      );

      expect(path, OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(Excel.decodeBytes(writtenBytes).tables.keys, [
        "People",
        "Roles",
        "Locations",
        "Elements",
      ]);
    });

    test('suggests the file name computed by OcptResourcesXlsxExportService, suffixed', () async {
      final saveLocationService = _FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await manager.exportResourcesXlsx(
        snapshot: snapshot,
        labels: labels,
        projectName: "My Movie",
        fileTypeLabel: "Excel workbook",
      );

      expect(saveLocationService.lastSuggestedFileName, "My Movie - resources.xlsx");
      expect(saveLocationService.lastFileTypeLabel, "Excel workbook");
      expect(saveLocationService.lastExtensions, const [
        OcptShotListXlsxExportService.xlsxFileExtension,
      ]);
    });
  });

  group('exportContactList', () {
    final snapshot = OcptResourcesSnapshot.build(
      people: const [],
      roles: const [],
      locations: const [],
      elements: const [],
      candidatesByRoleId: const {},
      scenes: const [],
    );
    const labels = OcptContactListLabels(
      fileNameSuffix: "contacts",
      documentTitle: "Contact list",
      versionLabel: "Version",
      crewSectionTitle: "Crew",
      castSectionTitle: "Cast",
      nameHeader: "Name",
      positionHeader: "Position",
      phoneHeader: "Phone",
      emailHeader: "Email",
      crewDepartmentLabels: {},
      crewPositionLabels: {},
      unassignedDepartmentLabel: "Unassigned",
      emptyDocumentNote: "Nothing to print.",
    );

    Future<OcptExportOutcome?> export(OcptExportManager manager) => manager.exportContactList(
      snapshot: snapshot,
      pageSetup: const OcptPageSetup.standard(),
      labels: labels,
      projectName: "My Movie",
      fileTypeLabel: "PDF document",
    );

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - contacts.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptContactListPdfService, suffixed', () async {
      final saveLocationService = _FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await export(manager);

      expect(saveLocationService.lastSuggestedFileName, "My Movie - contacts.pdf");
      expect(saveLocationService.lastFileTypeLabel, "PDF document");
      expect(saveLocationService.lastExtensions, const ["pdf"]);
    });
  });

  group('exportBreakdownSheets', () {
    final document = const FountainParser().parse("INT. KITCHEN - DAY\n\nJohn walks in.\n");
    final snapshot = OcptBreakdownSnapshot.build(
      screenplayId: "screenplay",
      scenes: const [],
      tags: const [],
      elements: const [],
      roles: const [],
      sets: const [],
      locations: const [],
      people: const [],
    );
    const labels = OcptBreakdownSheetsLabels(
      fileNameSuffix: "breakdown",
      documentTitle: "Breakdown sheets",
      sceneTitles: {},
      statusLabel: "Breakdown",
      lengthLabel: "Length",
      notesLabel: "Breakdown notes",
      targetsSectionTitle: "What the scene needs",
      toFindSectionTitle: "Still to find",
      nameHeader: "Name",
      statusHeader: "Status",
      ownerHeader: "Owner",
      sceneStatusLabels: {},
      elementStatusLabels: {},
      elementCategoryLabels: {},
      roleGroupLabel: "Roles",
      setGroupLabel: "Sets",
      emptySceneNote: "Nothing tagged in this scene.",
      emptyDocumentNote: "No scene to print.",
    );

    Future<OcptExportOutcome?> export(OcptExportManager manager) => manager.exportBreakdownSheets(
      document: document,
      snapshot: snapshot,
      pageSetup: const OcptPageSetup.standard(),
      labels: labels,
      projectName: "My Movie",
      onlyDoneScenes: false,
      includeNotes: true,
      includeToFindList: true,
      fileTypeLabel: "PDF document",
    );

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - breakdown.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptBreakdownSheetsPdfService, suffixed', () async {
      final saveLocationService = _FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await export(manager);

      expect(saveLocationService.lastSuggestedFileName, "My Movie - breakdown.pdf");
      expect(saveLocationService.lastFileTypeLabel, "PDF document");
      expect(saveLocationService.lastExtensions, const ["pdf"]);
    });
  });

  group('exportGeneralCallSheets and exportNamedCallSheets', () {
    const pageSetup = OcptPageSetup.standard();
    const labels = OcptCallSheetLabels(
      fileNamePrefix: "FDS",
      documentTitle: "Call sheet",
      dayTitles: {},
      directorLine: "",
      versionLabel: "Version",
      dayTagPrefix: "D",
      dayNumberLabel: "DAY",
      recipientsSectionTitle: "Recipients",
      namedRecipientLabel: "For",
      crewNoteSectionTitle: "Note",
      locationSectionTitle: "Location",
      mapsLinkLabel: "Maps",
      sunSectionTitle: "Sun",
      civilDawnLabel: "Dawn",
      sunriseLabel: "Sunrise",
      sunsetLabel: "Sunset",
      civilDuskLabel: "Dusk",
      contactsSectionTitle: "Contacts",
      crewDepartmentLabels: {},
      crewPositionLabels: {},
      hoursLinePrefix: "HOURS",
      patLabel: "PAT",
      presenceLabel: "PRESENCE",
      arrivalHeader: "ARRIVAL",
      departureLabel: "Departure",
      toBringSectionTitle: "To bring",
      blockKindLabels: {},
      seqHeader: "SEQ",
      plansHeader: "SHOTS",
      effetHeader: "EFFECT",
      decorsHeader: "SET",
      rolesHeader: "ROLES",
      castSectionTitle: "Cast",
      roleHeader: "ROLE",
      actorHeader: "ACTOR",
      nameHeader: "NAME",
      positionsHeader: "POSITION(S)",
      phoneHeader: "PHONE",
      emailHeader: "EMAIL",
      crewListSectionTitle: "Crew",
      castAndExtrasListSectionTitle: "Cast and extras",
      emptyDayNote: "Nothing planned.",
      unnamedPersonLabel: "No name",
      eventsSectionTitle: "Events",
      auditionsSectionTitle: "Auditions",
      candidateHeader: "CANDIDAT",
      candidatesSectionTitle: "Candidates",
      guestsSectionTitle: "Guests",
      guestReasonHeader: "Reason",
    );

    /// A one-day, one-slot, one-person schedule plan — enough for one general and one named call
    /// sheet.
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
      final slot = const OcptShootingSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        label: "",
        locationId: null,
        setId: null,
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorMinute: 480,
        anchorSlotId: null,
        notes: "",
        crew: [
          OcptShootingSlotCrewMember(
            id: "crew-1",
            slotId: "slot-1",
            personId: "person-1",
            positionId: "director",
            customLabel: "",
            notes: "",
          ),
        ],
        cast: [],
        guests: [],
      );

      return OcptSchedulePlanSnapshot.build(
        schedule: OcptScheduleSnapshot.build(
          days: [day],
          slotsByDayId: {
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

    group('exportGeneralCallSheets', () {
      test('a cancelled directory dialog returns null and writes nothing', () async {
        final manager = OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: _FakeSaveLocationService(),
        );

        final result = await manager.exportGeneralCallSheets(
          plan: buildPlan(),
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          confirmButtonText: "Choose",
        );

        expect(result, isNull);
        expect(tempDir.listSync(), isEmpty);
      });

      test('a chosen folder receives one PDF per day, named after its own tag', () async {
        final saveLocationService = _FakeSaveLocationService()..directoryResult = tempDir.path;
        final manager = OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        );

        final result = await manager.exportGeneralCallSheets(
          plan: buildPlan(),
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          confirmButtonText: "Choose",
        );

        expect(result, isNotNull);
        expect(result!.folderPath, tempDir.path);
        expect(result.writtenFileNames, ["FDS-D2.pdf"]);
        expect(result.failedFileNames, isEmpty);
        expect(result.isComplete, isTrue);
        expect(saveLocationService.lastConfirmButtonText, "Choose");

        final writtenBytes = await File(p.join(tempDir.path, "FDS-D2.pdf")).readAsBytes();
        expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
      });

      test('a folder that cannot be written into is reported as a failed file, not a crash', () async {
        final saveLocationService = _FakeSaveLocationService()
          ..directoryResult = p.join(tempDir.path, "does-not-exist");
        final manager = OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        );

        final result = await manager.exportGeneralCallSheets(
          plan: buildPlan(),
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          confirmButtonText: "Choose",
        );

        expect(result, isNotNull);
        expect(result!.writtenFileNames, isEmpty);
        expect(result.failedFileNames, ["FDS-D2.pdf"]);
        expect(result.isComplete, isFalse);
      });
    });

    group('exportNamedCallSheets', () {
      test('a cancelled directory dialog returns null and writes nothing', () async {
        final manager = OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: _FakeSaveLocationService(),
        );

        final result = await manager.exportNamedCallSheets(
          plan: buildPlan(),
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          confirmButtonText: "Choose",
        );

        expect(result, isNull);
        expect(tempDir.listSync(), isEmpty);
      });

      test('a chosen folder receives one PDF per convocation, none of them the crew list', () async {
        final saveLocationService = _FakeSaveLocationService()..directoryResult = tempDir.path;
        final manager = OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        );

        final result = await manager.exportNamedCallSheets(
          plan: buildPlan(),
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          confirmButtonText: "Choose",
        );

        expect(result, isNotNull);
        expect(result!.folderPath, tempDir.path);
        // `buildPlan` convokes exactly one person, holding no display name at all (blank first/last
        // name), so the file name falls back to the labels' own unnamed-person fallback. Whether the
        // named PDF is smaller than the general one — the crew list it never reads — is asserted at
        // the service level (`ocpt_call_sheet_pdf_service_test.dart`), against a fixture with an
        // actual crew to make the comparison meaningful; this manager-level test's own job is only
        // that the right number of files land under the right names.
        expect(result.writtenFileNames, ["FDS-D2-No-name.pdf"]);
        expect(result.failedFileNames, isEmpty);

        final writtenBytes = await File(p.join(tempDir.path, "FDS-D2-No-name.pdf")).readAsBytes();
        expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
      });

      test('convocationKeys narrows which people get their own file', () async {
        final saveLocationService = _FakeSaveLocationService()..directoryResult = tempDir.path;
        final manager = OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        );

        final result = await manager.exportNamedCallSheets(
          plan: buildPlan(),
          dayIds: const ["day-1"],
          convocationKeys: const {"nobody-selected"},
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          confirmButtonText: "Choose",
        );

        expect(result, isNotNull);
        expect(result!.writtenFileNames, isEmpty);
      });

      test('two convoked people whose names collide each keep a file of their own', () async {
        final saveLocationService = _FakeSaveLocationService()..directoryResult = tempDir.path;
        final manager = OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        );

        // Two crew rows naming two people the address book holds nothing for: both read as the
        // labels' own unnamed-person fallback, so both ask for the very same file name. The second
        // one must not overwrite the first — that would be one person on the call list ending the
        // export with no call sheet at all.
        final plan = buildPlan();
        final slot = plan.schedule.slotsByDayId["day-1"]!.first;
        final collidingPlan = OcptSchedulePlanSnapshot.build(
          schedule: OcptScheduleSnapshot.build(
            days: plan.schedule.days,
            slotsByDayId: {
              "day-1": [
                OcptShootingSlot(
                  id: slot.id,
                  shootingDayId: slot.shootingDayId,
                  label: slot.label,
                  locationId: slot.locationId,
                  setId: slot.setId,
                  anchorEdge: slot.anchorEdge,
                  anchorMinute: slot.anchorMinute,
                  anchorSlotId: slot.anchorSlotId,
                  notes: slot.notes,
                  crew: [
                    ...slot.crew,
                    const OcptShootingSlotCrewMember(
                      id: "crew-2",
                      slotId: "slot-1",
                      personId: "person-2",
                      positionId: "gaffer",
                      customLabel: "",
                      notes: "",
                    ),
                  ],
                  cast: slot.cast,
                  guests: slot.guests,
                ),
              ],
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

        final result = await manager.exportNamedCallSheets(
          plan: collidingPlan,
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          confirmButtonText: "Choose",
        );

        expect(result, isNotNull);
        expect(result!.writtenFileNames, ["FDS-D2-No-name.pdf", "FDS-D2-No-name-2.pdf"]);
        expect(result.failedFileNames, isEmpty);
        expect(tempDir.listSync().length, 2);
      });

      test(
        'a two-day run writes one file per (recipient x day), a single-day recipient getting '
        'exactly one and the two days never colliding',
        () async {
          final saveLocationService = _FakeSaveLocationService()..directoryResult = tempDir.path;
          final manager = OcptExportManager(
            fileSelectorManager: const FileSelectorManager(),
            saveLocationService: saveLocationService,
          );

          // person-1 is convoked on both days and must therefore be printed twice, once per day; the
          // day tag ("D2" vs "D3") already makes the two files distinct, so neither is suffixed even
          // though every person here shares the very same blank display name. person-2 is convoked
          // only on the second day and must therefore be printed exactly once.
          final dayOne = OcptShootingDay(
            id: "day-1",
            date: DateTime(2026, 1, 2),
            dayNumber: 2,
            status: OcptShootingDayStatus.planned,
            crewNote: "",
            weatherNote: "",
            notes: "",
          );
          final dayTwo = OcptShootingDay(
            id: "day-2",
            date: DateTime(2026, 1, 3),
            dayNumber: 3,
            status: OcptShootingDayStatus.planned,
            crewNote: "",
            weatherNote: "",
            notes: "",
          );
          const slotOne = OcptShootingSlot(
            id: "slot-1",
            shootingDayId: "day-1",
            label: "",
            locationId: null,
            setId: null,
            anchorEdge: OcptShootingSlotAnchorEdge.start,
            anchorMinute: 480,
            anchorSlotId: null,
            notes: "",
            crew: [
              OcptShootingSlotCrewMember(
                id: "crew-1",
                slotId: "slot-1",
                personId: "person-1",
                positionId: "director",
                customLabel: "",
                notes: "",
              ),
            ],
            cast: [],
            guests: [],
          );
          const slotTwo = OcptShootingSlot(
            id: "slot-2",
            shootingDayId: "day-2",
            label: "",
            locationId: null,
            setId: null,
            anchorEdge: OcptShootingSlotAnchorEdge.start,
            anchorMinute: 480,
            anchorSlotId: null,
            notes: "",
            crew: [
              OcptShootingSlotCrewMember(
                id: "crew-2",
                slotId: "slot-2",
                personId: "person-1",
                positionId: "director",
                customLabel: "",
                notes: "",
              ),
              OcptShootingSlotCrewMember(
                id: "crew-3",
                slotId: "slot-2",
                personId: "person-2",
                positionId: "gaffer",
                customLabel: "",
                notes: "",
              ),
            ],
            cast: [],
            guests: [],
          );

          final twoDayPlan = OcptSchedulePlanSnapshot.build(
            schedule: OcptScheduleSnapshot.build(
              days: [dayOne, dayTwo],
              slotsByDayId: {
                "day-1": [slotOne],
                "day-2": [slotTwo],
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

          final result = await manager.exportNamedCallSheets(
            plan: twoDayPlan,
            dayIds: const ["day-1", "day-2"],
            pageSetup: pageSetup,
            labels: labels,
            projectName: "My Movie",
            confirmButtonText: "Choose",
          );

          expect(result, isNotNull);
          expect(result!.writtenFileNames, [
            "FDS-D2-No-name.pdf",
            "FDS-D3-No-name.pdf",
            "FDS-D3-No-name-2.pdf",
          ]);
          expect(result.failedFileNames, isEmpty);
          expect(tempDir.listSync().length, 3);
        },
      );
    });
  });

  group('exportShootingPlan', () {
    const labels = OcptShootingPlanLabels(
      fileNameSuffix: "shooting plan",
      documentTitle: "Shooting plan",
      dayTitles: {},
      tenMinuteGridSectionTitle: "Ten-minute grid",
      directorLine: "",
      versionLabel: "Version",
      dayTagPrefix: "D",
      locationsGridTitle: "Summary - Locations",
      sequencesGridTitle: "Summary - Sequences",
      peopleGridTitle: "Summary - Crew and cast",
      elementsGridTitle: "Summary - Elements",
      locationsGridRowHeader: "Location",
      sequencesGridRowHeader: "Sequence",
      peopleGridRowHeader: "Position / Role",
      elementsGridRowHeader: "Element",
      elementCategoryLabels: {},
      persoLabel: "Cast",
      sequenceRowPrefix: "Seq.",
      presenceMark: "x",
      crewPositionLabels: {},
      dayLocationLabel: "Location",
      dayHoursLabel: "Hours",
      daySetsLabel: "Sets",
      dayTimetableLabel: "Timetable",
      callTimeLabel: "call at",
      estimatedEndLabel: "estimated end",
      milestoneFromLabel: "From",
      milestoneToLabel: "to",
      blockKindLabels: {},
      rolesLabel: "CAST",
      hoursHeader: "Hours",
      planHeader: "Plan",
      shotSizeHeader: "Shot size",
      moveHeader: "Move.",
      framingHeader: "Frame",
      commentHeader: "Comment",
      emptyPlanNote: "Nothing planned yet.",
      emptyDayScheduleNote: "Nothing planned for this day yet.",
      eventsSectionTitle: "Events",
      guestsSectionTitle: "Guests",
      guestReasonHeader: "Reason",
      nameHeader: "NAME",
      hoursLinePrefix: "HOURS",
      unnamedPersonLabel: "Unnamed",
    );

    /// A one-day, one-slot schedule plan — enough for one shooting plan document.
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
      final slot = const OcptShootingSlot(
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
          slotsByDayId: {
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

    Future<OcptExportOutcome?> export(OcptExportManager manager) => manager.exportShootingPlan(
      plan: buildPlan(),
      dayIds: const ["day-1"],
      pageSetup: const OcptPageSetup.standard(),
      labels: labels,
      projectName: "My Movie",
      includeTitlePage: true,
      includeLocationsGrid: true,
      includeSequencesGrid: true,
      includePeopleGrid: true,
      includeTenMinuteGrid: true,
      includeElementsGrid: true,
      fileTypeLabel: "PDF document",
    );

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a single PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - shooting plan.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptShootingPlanPdfService, suffixed', () async {
      final saveLocationService = _FakeSaveLocationService();
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      );

      await export(manager);

      expect(saveLocationService.lastSuggestedFileName, "My Movie - shooting plan.pdf");
      expect(saveLocationService.lastFileTypeLabel, "PDF document");
      expect(saveLocationService.lastExtensions, const ["pdf"]);
    });
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
        cast: [OcptShootingSlotCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1", notes: "")],
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
        saveLocationService: _FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a single PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - day out of days.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptDayOutOfDaysPdfService, suffixed', () async {
      final saveLocationService = _FakeSaveLocationService();
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
        saveLocationService: _FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a single PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - one-line schedule.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptOneLineSchedulePdfService, suffixed', () async {
      final saveLocationService = _FakeSaveLocationService();
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
        saveLocationService: _FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a single PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - sides - D2.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: _FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptSidesPdfService, with the day tag', () async {
      final saveLocationService = _FakeSaveLocationService();
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
