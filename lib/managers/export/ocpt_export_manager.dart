// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_pdf_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';

/// Builds the [OcptExportManager] instance registered by the global manager.
class OcptExportManagerBuilder extends AbsLifeCycleFactory<OcptExportManager> {
  /// Class constructor
  const OcptExportManagerBuilder() : super(OcptExportManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, FileSelectorManager];
}

/// Owns everything about getting a screenplay in and out of the app as a plain `.fountain` file
/// or a PDF, and the project's shot list out of it as an XLSX workbook.
///
/// Holds the native save/open dialogs; the actual bytes/text conversion is delegated to
/// [fountainIoService], [pdfExportService] and [shotListXlsxExportService], and the "save as"
/// location picking to [saveLocationService] — the services this manager owns (RFL18).
class OcptExportManager extends AbsWithLifeCycle {
  /// The manager used to show the native "open" dialog when importing.
  final FileSelectorManager _fileSelectorManager;

  /// The service converting Fountain files to and from text.
  final OcptFountainIoService fountainIoService;

  /// The service rendering a screenplay PDF.
  final OcptPdfExportService pdfExportService;

  /// The service building the shot list XLSX workbook.
  final OcptShotListXlsxExportService shotListXlsxExportService;

  /// The service showing the native "save as" dialog and resolving the chosen path.
  final OcptSaveLocationService saveLocationService;

  /// Class constructor
  OcptExportManager({
    FileSelectorManager? fileSelectorManager,
    OcptSaveLocationService? saveLocationService,
  }) : _fileSelectorManager = fileSelectorManager ?? globalGetIt().get<FileSelectorManager>(),
       fountainIoService = const OcptFountainIoService(),
       pdfExportService = OcptPdfExportService(),
       shotListXlsxExportService = const OcptShotListXlsxExportService(),
       saveLocationService = saveLocationService ?? const OcptSaveLocationService();

  /// Shows the native save dialog and writes [fountainText] to the chosen `.fountain` file.
  ///
  /// [fileTypeLabel] is the localized label passed to the native dialog's type filter. Returns
  /// the path of the written file, or null if the user cancelled or the save failed (failures
  /// are logged; the OS dialog already reported a cancellation to the user).
  Future<String?> exportFountain({
    required String fountainText,
    required String projectName,
    required String fileTypeLabel,
  }) => _writeToPickedLocation(
    suggestedFileName: fountainIoService.fountainFileName(projectName),
    fileTypeLabel: fileTypeLabel,
    extensions: [OcptFountainIoService.fountainFileExtension],
    bytes: fountainIoService.encodeFountainText(fountainText),
  );

  /// Renders [document] into a PDF via [pdfExportService] and shows the native save dialog to
  /// write it out.
  ///
  /// [fileTypeLabel] is the localized label passed to the native dialog's type filter. Returns
  /// the path of the written file, or null if the user cancelled or the save failed (failures
  /// are logged; the OS dialog already reported a cancellation to the user).
  Future<String?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required String fileTypeLabel,
  }) async {
    final bytes = await pdfExportService.generate(
      document: document,
      pageSetup: pageSetup,
      projectName: projectName,
      includeSceneNumbers: includeSceneNumbers,
      includeTitlePage: includeTitlePage,
    );

    return _writeToPickedLocation(
      suggestedFileName: pdfExportService.pdfFileName(projectName),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
    );
  }

  /// Builds the XLSX workbook of [snapshot] via [shotListXlsxExportService] and shows the native
  /// save dialog to write it out.
  ///
  /// [labels] carries every localized string the sheet itself holds (its name, its headers, the
  /// status labels and the sequence separator titles), and [fileTypeLabel] is the localized label
  /// passed to the native dialog's type filter — this manager has no `Tr` of its own. Returns the
  /// path of the written file, or null if the user cancelled or the save failed (failures are
  /// logged; the OS dialog already reported a cancellation to the user).
  Future<String?> exportShotListXlsx({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
  }) => _writeToPickedLocation(
    suggestedFileName: shotListXlsxExportService.xlsxFileName(projectName),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    bytes: shotListXlsxExportService.generate(snapshot: snapshot, labels: labels),
  );

  /// Shows the native save dialog and writes [bytes] to the chosen location.
  ///
  /// Returns the written path, or null if the user cancelled the dialog or the write failed
  /// (logged; treated the same as a cancellation by every caller).
  Future<String?> _writeToPickedLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    required Uint8List bytes,
  }) async {
    final path = await saveLocationService.pickSaveLocation(
      suggestedFileName: suggestedFileName,
      fileTypeLabel: fileTypeLabel,
      extensions: extensions,
    );
    if (path == null) {
      return null;
    }

    try {
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (error) {
      appLogger().e("A problem occurred when tried to write the file at: $path, error: $error");
      return null;
    }
  }

  /// Shows the native open dialog, reads the picked `.fountain` file and decodes it.
  ///
  /// Returns null if the user cancelled or the selection failed.
  Future<OcptImportedFountainModel?> pickAndReadFountain({required String fileTypeLabel}) async {
    final selection = await _fileSelectorManager.openSelector(
      allowedExtensions: [OcptFountainIoService.fountainFileExtension],
      label: fileTypeLabel,
    );

    final selectedFile = selection.value;
    if (!selection.status.isSuccess || selectedFile == null) {
      // The user cancelled the dialog, or the selection failed; the latter is a soft failure
      // deliberately not surfaced as an error, since the OS dialog itself already reported it.
      return null;
    }

    final bytes = await XFileUtilities.getBinaryFileContent(xFile: selectedFile);
    if (bytes == null) {
      appLogger().e("A problem occurred when tried to read the picked file: ${selectedFile.name}");
      return null;
    }

    return OcptImportedFountainModel(
      fountainText: fountainIoService.decodeFountainBytes(bytes),
      sourceFileName: selectedFile.name,
    );
  }
}
