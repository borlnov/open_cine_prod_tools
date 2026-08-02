// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:path/path.dart' as p;

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

      expect(path, chosenPath);
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

      expect(path, chosenPath);
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

    Future<String?> export(OcptExportManager manager) => manager.exportScenarioCoverage(
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

      expect(await export(manager), chosenPath);
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

      expect(path, chosenPath);
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
}
