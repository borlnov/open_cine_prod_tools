// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_pdf_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';

/// Builds the [OcptExportManager] instance registered by the global manager.
class OcptExportManagerBuilder extends AbsLifeCycleFactory<OcptExportManager> {
  /// Class constructor
  const OcptExportManagerBuilder() : super(OcptExportManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, FileSaverManager, FileSelectorManager];
}

/// Owns everything about getting a screenplay in and out of the app as a plain `.fountain` file
/// or a PDF.
///
/// Holds the native save/open dialogs; the actual bytes/text conversion is delegated to
/// [fountainIoService] and [pdfExportService], the services this manager owns (RFL18).
class OcptExportManager extends AbsWithLifeCycle {
  /// The manager used to show the native "save as" dialog when exporting.
  final FileSaverManager _fileSaverManager;

  /// The manager used to show the native "open" dialog when importing.
  final FileSelectorManager _fileSelectorManager;

  /// The service converting Fountain files to and from text.
  final OcptFountainIoService fountainIoService;

  /// The service rendering a screenplay PDF.
  final OcptPdfExportService pdfExportService;

  /// Class constructor
  OcptExportManager({FileSaverManager? fileSaverManager, FileSelectorManager? fileSelectorManager})
    : _fileSaverManager = fileSaverManager ?? globalGetIt().get<FileSaverManager>(),
      _fileSelectorManager = fileSelectorManager ?? globalGetIt().get<FileSelectorManager>(),
      fountainIoService = const OcptFountainIoService(),
      pdfExportService = OcptPdfExportService();

  /// Shows the native save dialog and writes [fountainText] to the chosen `.fountain` file.
  ///
  /// Returns the path of the written file, or null if the user cancelled or the save failed
  /// (failures are logged; the OS dialog already reported them to the user).
  Future<String?> exportFountain({required String fountainText, required String projectName}) =>
      _fileSaverManager.saveFileFromBytes(
        fileName: fountainIoService.fountainFileName(projectName),
        bytes: fountainIoService.encodeFountainText(fountainText),
      );

  /// Renders [document] into a PDF via [pdfExportService] and shows the native save dialog to
  /// write it out.
  ///
  /// Returns the path of the written file, or null if the user cancelled or the save failed
  /// (failures are logged; the OS dialog already reported them to the user).
  Future<String?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
  }) async {
    final bytes = await pdfExportService.generate(
      document: document,
      pageSetup: pageSetup,
      projectName: projectName,
      includeSceneNumbers: includeSceneNumbers,
      includeTitlePage: includeTitlePage,
    );

    return _fileSaverManager.saveFileFromBytes(
      fileName: pdfExportService.pdfFileName(projectName),
      bytes: bytes,
    );
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
