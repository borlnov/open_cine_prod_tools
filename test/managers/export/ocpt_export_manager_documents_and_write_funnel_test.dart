// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_share_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:path/path.dart' as p;
import 'ocpt_export_manager_test_doubles.dart';

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
  _FakeShareService({required Directory directory, this.result = true})
    : _directory = directory,
      super(logger: const SilentLogger());

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
        saveLocationService: FakeSaveLocationService(),
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
        saveLocationService: FakeSaveLocationService(result: chosenPath),
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
      final saveLocationService = FakeSaveLocationService();
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
        final saveLocationService = FakeSaveLocationService(result: p.join(tempDir.path, "unused"));
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

    test(
      'a share sheet that could not be shown reports null, exactly like a failed write',
      () async {
        final manager = OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: FakeSaveLocationService(),
          platformManager: _StubPlatformManager(isMobile: true),
          shareService: _FakeShareService(directory: tempDir, result: false),
        );

        final outcome = await manager.exportFountain(
          fountainText: fountainText,
          projectName: "My Movie",
          fileTypeLabel: "Fountain screenplay",
        );

        expect(outcome, isNull);
      },
    );
  });

  group('exportPdf', () {
    const parser = FountainParser();
    final document = parser.parse("INT. HOUSE - DAY\n\nAction.\n");
    const pageSetup = OcptPageSetup.standard();

    test('a cancelled dialog returns null and writes nothing', () async {
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(),
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
        saveLocationService: FakeSaveLocationService(result: chosenPath),
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
      final saveLocationService = FakeSaveLocationService();
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
    final snapshot = OcptShotListSnapshot.build(screenplayId: "screenplay", sequences: const []);
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
        saveLocationService: FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives the generated bytes and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - coverage.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(writtenBytes, isNotEmpty);
      expect(String.fromCharCodes(writtenBytes.take(4)), "%PDF");
    });

    test('suggests the file name computed from the localized suffix', () async {
      final saveLocationService = FakeSaveLocationService();
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
    final snapshot = OcptShotListSnapshot.build(screenplayId: "screenplay", sequences: const []);
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
        saveLocationService: FakeSaveLocationService(),
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
        saveLocationService: FakeSaveLocationService(result: chosenPath),
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
      final saveLocationService = FakeSaveLocationService();
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
        saveLocationService: FakeSaveLocationService(),
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
        saveLocationService: FakeSaveLocationService(result: chosenPath),
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
      final saveLocationService = FakeSaveLocationService();
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
        saveLocationService: FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - contacts.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptContactListPdfService, suffixed', () async {
      final saveLocationService = FakeSaveLocationService();
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
        saveLocationService: FakeSaveLocationService(),
      );

      expect(await export(manager), isNull);
      expect(tempDir.listSync(), isEmpty);
    });

    test('a chosen path receives a PDF and is returned', () async {
      final chosenPath = p.join(tempDir.path, "My Movie - breakdown.pdf");
      final manager = OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: FakeSaveLocationService(result: chosenPath),
      );

      expect(await export(manager), OcptExportSaved(chosenPath));
      final writtenBytes = await File(chosenPath).readAsBytes();
      expect(ascii.decode(writtenBytes.sublist(0, 4)), "%PDF");
    });

    test('suggests the file name computed by OcptBreakdownSheetsPdfService, suffixed', () async {
      final saveLocationService = FakeSaveLocationService();
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
}
