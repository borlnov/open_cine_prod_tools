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
import 'package:open_cine_prod_tools/managers/export/services/ocpt_breakdown_sheets_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_pdf_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_resources_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_scenario_coverage_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:path/path.dart' as p;

/// Builds the [OcptExportManager] instance registered by the global manager.
class OcptExportManagerBuilder extends AbsLifeCycleFactory<OcptExportManager> {
  /// Class constructor
  const OcptExportManagerBuilder() : super(OcptExportManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, FileSelectorManager];
}

/// Owns everything about getting a screenplay in and out of the app as a plain `.fountain` file
/// or a PDF, the project's shot list out of it as an XLSX workbook, its scenario coverage as an
/// annotated screenplay PDF, its resources catalogue as a second, four-sheet XLSX workbook, its
/// breakdown as one printed sheet per scene, and its shooting schedule as call sheets — the general
/// one and the named ones, both per day — and as one whole-shoot shooting plan.
///
/// Holds the native save/open dialogs; the actual bytes/text conversion is delegated to
/// [fountainIoService], [pdfExportService], [shotListXlsxExportService],
/// [scenarioCoveragePdfService], [resourcesXlsxExportService], [breakdownSheetsPdfService],
/// [callSheetPdfService] and [shootingPlanPdfService], and the "save as"/"choose a folder" location
/// picking to [saveLocationService] — the nine services this manager owns (RFL18).
class OcptExportManager extends AbsWithLifeCycle {
  /// The manager used to show the native "open" dialog when importing.
  final FileSelectorManager _fileSelectorManager;

  /// The service converting Fountain files to and from text.
  final OcptFountainIoService fountainIoService;

  /// The service rendering a screenplay PDF.
  final OcptPdfExportService pdfExportService;

  /// The service building the shot list XLSX workbook.
  final OcptShotListXlsxExportService shotListXlsxExportService;

  /// The service rendering the scenario coverage PDF.
  final OcptScenarioCoveragePdfService scenarioCoveragePdfService;

  /// The service building the resources catalogue's four-sheet XLSX workbook.
  final OcptResourcesXlsxExportService resourcesXlsxExportService;

  /// The service rendering the breakdown sheets PDF.
  final OcptBreakdownSheetsPdfService breakdownSheetsPdfService;

  /// The service rendering the general and the named call sheets PDFs.
  final OcptCallSheetPdfService callSheetPdfService;

  /// The service rendering the whole-shoot shooting plan PDF.
  final OcptShootingPlanPdfService shootingPlanPdfService;

  /// The service showing the native "save as"/"choose a folder" dialog and resolving the chosen
  /// path.
  final OcptSaveLocationService saveLocationService;

  /// Class constructor
  OcptExportManager({
    FileSelectorManager? fileSelectorManager,
    OcptSaveLocationService? saveLocationService,
  }) : this._(
         fontsLoader: OcptCourierPrimeFontsLoader(),
         fileSelectorManager: fileSelectorManager,
         saveLocationService: saveLocationService,
       );

  /// Class constructor, taking the one font loader every PDF renderer shares.
  ///
  /// Handing them all the same [OcptCourierPrimeFontsLoader] is what keeps the app from decoding
  /// the 4 embedded Courier Prime TTFs once per renderer, however many exports of any kind it runs.
  OcptExportManager._({
    required OcptCourierPrimeFontsLoader fontsLoader,
    required FileSelectorManager? fileSelectorManager,
    required OcptSaveLocationService? saveLocationService,
  }) : _fileSelectorManager = fileSelectorManager ?? globalGetIt().get<FileSelectorManager>(),
       saveLocationService = saveLocationService ?? const OcptSaveLocationService(),
       fountainIoService = const OcptFountainIoService(),
       pdfExportService = OcptPdfExportService(fontsLoader: fontsLoader),
       scenarioCoveragePdfService = OcptScenarioCoveragePdfService(fontsLoader: fontsLoader),
       breakdownSheetsPdfService = OcptBreakdownSheetsPdfService(fontsLoader: fontsLoader),
       callSheetPdfService = OcptCallSheetPdfService(fontsLoader: fontsLoader),
       shootingPlanPdfService = OcptShootingPlanPdfService(fontsLoader: fontsLoader),
       shotListXlsxExportService = const OcptShotListXlsxExportService(),
       resourcesXlsxExportService = const OcptResourcesXlsxExportService();

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

  /// Renders the scenario coverage of [snapshot] over [document] via [scenarioCoveragePdfService]
  /// and shows the native save dialog to write it out.
  ///
  /// [screenplayText] must be the very text [document] was parsed from and [snapshot]'s scenes were
  /// indexed against — a coverage range addresses it by character offset. [labels] carries every
  /// localized string the document itself holds (the two appendix pages' headings and headers, the
  /// sequence titles and the file name's own suffix) and [fileTypeLabel] the one the native dialog
  /// needs — this manager has no `Tr` of its own. Returns the path of the written file, or null if
  /// the user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  Future<String?> exportScenarioCoverage({
    required FountainDocument document,
    required String screenplayText,
    required OcptShotListSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptScenarioCoverageLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required bool includeLegendPage,
    required bool includeSummaryPage,
    required String fileTypeLabel,
  }) async {
    final bytes = await scenarioCoveragePdfService.generate(
      document: document,
      screenplayText: screenplayText,
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeSceneNumbers: includeSceneNumbers,
      includeTitlePage: includeTitlePage,
      includeLegendPage: includeLegendPage,
      includeSummaryPage: includeSummaryPage,
    );

    return _writeToPickedLocation(
      suggestedFileName: scenarioCoveragePdfService.coverageFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
    );
  }

  /// Builds the resources catalogue's four-sheet XLSX workbook of [snapshot] via
  /// [resourcesXlsxExportService] and shows the native save dialog to write it out.
  ///
  /// [labels] carries every localized string the four sheets themselves hold, and [fileTypeLabel]
  /// is the localized label passed to the native dialog's type filter — this manager has no `Tr`
  /// of its own. Returns the path of the written file, or null if the user cancelled or the save
  /// failed (failures are logged; the OS dialog already reported a cancellation to the user).
  Future<String?> exportResourcesXlsx({
    required OcptResourcesSnapshot snapshot,
    required OcptResourcesXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
  }) => _writeToPickedLocation(
    suggestedFileName: resourcesXlsxExportService.xlsxFileName(
      projectName: projectName,
      suffix: labels.fileNameSuffix,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    bytes: resourcesXlsxExportService.generate(snapshot: snapshot, labels: labels),
  );

  /// Renders the breakdown sheets of [snapshot] via [breakdownSheetsPdfService] and shows the
  /// native save dialog to write them out.
  ///
  /// [document] is the screenplay [snapshot]'s scenes were indexed against, read for each scene's
  /// own length alone (see the service's own doc comment). [labels] carries every localized string
  /// the document itself holds (the scene titles, the section headings, the status and category
  /// labels and the file name's own suffix) and [fileTypeLabel] the one the native dialog needs —
  /// this manager has no `Tr` of its own. Returns the path of the written file, or null if the user
  /// cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  Future<String?> exportBreakdownSheets({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownSheetsLabels labels,
    required String projectName,
    required bool onlyDoneScenes,
    required bool includeNotes,
    required bool includeToFindList,
    required String fileTypeLabel,
  }) async {
    final bytes = await breakdownSheetsPdfService.generate(
      document: document,
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      onlyDoneScenes: onlyDoneScenes,
      includeNotes: includeNotes,
      includeToFindList: includeToFindList,
    );

    return _writeToPickedLocation(
      suggestedFileName: breakdownSheetsPdfService.sheetsFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
    );
  }

  /// Renders one general call sheet per day of [dayIds] via [callSheetPdfService] and writes every
  /// one of them into a folder the user picks.
  ///
  /// This is the one export of this app that writes more than one file, so it shows the native
  /// "choose a folder" dialog ([confirmButtonText] is its own confirm button's localized label)
  /// rather than a "save as" one. Returns null if the user cancelled that dialog — nothing was
  /// touched on disk yet at that point — or an [OcptCallSheetExportResult] once a folder was chosen,
  /// even when every write inside it failed: a folder was picked, so the caller needs to know
  /// exactly what did and did not get written into it rather than being told the whole run "failed".
  /// A write failure is logged (this manager's usual soft-failure convention) and the file's own
  /// name lands in [OcptCallSheetExportResult.failedFileNames] instead of
  /// [OcptCallSheetExportResult.writtenFileNames].
  ///
  /// The moment every sheet of the run is stamped with is resolved **once**, here, and handed to
  /// each of them: a folder of sheets produced by one gesture is one issue of that day's paperwork,
  /// and a batch that read the clock per file would hand two people sheets a minute apart with no
  /// way to tell they are the same one.
  Future<OcptCallSheetExportResult?> exportGeneralCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
  }) async {
    final folderPath = await saveLocationService.pickDirectory(confirmButtonText: confirmButtonText);
    if (folderPath == null) {
      return null;
    }

    final exportDate = DateTime.now();
    final written = <String>[];
    final failed = <String>[];

    for (final dayId in dayIds) {
      final day = plan.schedule.daysById[dayId];
      final fileName = callSheetPdfService.callSheetFileName(
        labels: labels,
        dayNumber: day?.dayNumber ?? 0,
      );

      final bytes = await callSheetPdfService.generateGeneralCallSheet(
        plan: plan,
        dayId: dayId,
        pageSetup: pageSetup,
        labels: labels,
        projectName: projectName,
        exportDate: exportDate,
      );

      if (await _writeBytesInFolder(folderPath: folderPath, fileName: fileName, bytes: bytes)) {
        written.add(fileName);
      } else {
        failed.add(fileName);
      }
    }

    return OcptCallSheetExportResult(folderPath: folderPath, writtenFileNames: written, failedFileNames: failed);
  }

  /// Renders one named call sheet per (convocation × day) of [dayIds] via [callSheetPdfService] and
  /// writes every one of them into a folder the user picks — a call sheet being a document about a
  /// day, so a recipient convoked on two of [dayIds] gets two files, one for each.
  ///
  /// The loop is over each day's **own** convocations, filtered by [convocationKeys], never over the
  /// product of the two: a key ticked in the dialog but convoked on none of a given day's slots
  /// simply yields no file for that day rather than an empty one. [convocationKeys] selects which of
  /// a day's own convocations are printed — a person's own id, or an uncast role's, exactly as
  /// `OcptDayConvocation.personId`/`.roleId` discriminate one — or null to print every convocation of
  /// every day, the common case when nobody has narrowed the selection down. See
  /// [exportGeneralCallSheets] for the folder-picking, the once-per-run export moment (its own
  /// argument holds for a run spanning several days exactly as it does for one: a folder of sheets
  /// produced by one gesture is one issue of that paperwork) and the partial-failure contract,
  /// identical here.
  ///
  /// **A guest is never printed here**, whatever [convocationKeys] says: `OcptDayConvocation.isGuest`
  /// is filtered out before either the explicit selection or the "print every convocation" default
  /// is applied — a guest is not yet a call sheet recipient, and every reader downstream of this list
  /// assumes every entry names a person or a role.
  ///
  /// [_uniqueFileName] accumulates across the **whole** run rather than being reset per day, so two
  /// recipients whose names collide on one day still each get a file of their own (`-2`, `-3`) — the
  /// file name already carries the day's own tag, so two different days' sheets never collide with
  /// each other in the first place.
  Future<OcptCallSheetExportResult?> exportNamedCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    Set<String>? convocationKeys,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
  }) async {
    final folderPath = await saveLocationService.pickDirectory(confirmButtonText: confirmButtonText);
    if (folderPath == null) {
      return null;
    }

    final exportDate = DateTime.now();
    final written = <String>[];
    final failed = <String>[];

    for (final dayId in dayIds) {
      final day = plan.schedule.daysById[dayId];
      final dayNumber = day?.dayNumber ?? 0;
      final convocations = [
        for (final convocation in plan.convocationsOfDay(dayId))
          if (!convocation.isGuest &&
              (convocationKeys == null ||
                  convocationKeys.contains(convocation.personId ?? convocation.roleId)))
            convocation,
      ];

      for (final convocation in convocations) {
        final personName = convocation.personId != null
            ? (plan.personById[convocation.personId]?.displayName ?? "")
            : (plan.roleById[convocation.roleId]?.name ?? "");
        final fileName = _uniqueFileName(
          callSheetPdfService.namedCallSheetFileName(
            labels: labels,
            dayNumber: dayNumber,
            personName: personName,
          ),
          written,
          failed,
        );

        final bytes = await callSheetPdfService.generateNamedCallSheet(
          plan: plan,
          dayId: dayId,
          pageSetup: pageSetup,
          labels: labels,
          projectName: projectName,
          convocation: convocation,
          exportDate: exportDate,
        );

        if (await _writeBytesInFolder(folderPath: folderPath, fileName: fileName, bytes: bytes)) {
          written.add(fileName);
        } else {
          failed.add(fileName);
        }
      }
    }

    return OcptCallSheetExportResult(folderPath: folderPath, writtenFileNames: written, failedFileNames: failed);
  }

  /// Renders the whole-shoot shooting plan of [dayIds] via [shootingPlanPdfService] and shows the
  /// native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds (the day titles, the
  /// director line, the grid and section headings, the shot table's own headers and the file name's
  /// own suffix) and [fileTypeLabel] the one the native dialog needs — this manager has no `Tr` of
  /// its own. Unlike the call sheets, this is a **single** file: the whole shoot's own plan, through
  /// `pickSaveLocation` rather than a folder. Returns the path of the written file, or null if the
  /// user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  Future<String?> exportShootingPlan({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required bool includeLocationsGrid,
    required bool includeSequencesGrid,
    required bool includePeopleGrid,
    required bool includeTenMinuteGrid,
    required bool includeElementsGrid,
    required String fileTypeLabel,
  }) async {
    final bytes = await shootingPlanPdfService.generate(
      plan: plan,
      dayIds: dayIds,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
      includeLocationsGrid: includeLocationsGrid,
      includeSequencesGrid: includeSequencesGrid,
      includePeopleGrid: includePeopleGrid,
      includeTenMinuteGrid: includeTenMinuteGrid,
      includeElementsGrid: includeElementsGrid,
    );

    return _writeToPickedLocation(
      suggestedFileName: shootingPlanPdfService.shootingPlanFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
    );
  }

  /// [fileName], suffixed with `-2`, `-3`… while [written] or [failed] already holds it.
  ///
  /// Two convoked people sharing one display name — or, far more likely, two whose name is still
  /// blank and which therefore both fall back to the same label — would otherwise be handed the
  /// same file name, and the second write would overwrite the first: one person on the call list
  /// silently ending the export with no call sheet at all. A suffixed duplicate is a name somebody
  /// has to read twice; a missing file is somebody who never gets told when to turn up.
  String _uniqueFileName(String fileName, List<String> written, List<String> failed) {
    if (!written.contains(fileName) && !failed.contains(fileName)) {
      return fileName;
    }

    final extension = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    for (var suffix = 2; ; suffix++) {
      final candidate = "$base-$suffix$extension";
      if (!written.contains(candidate) && !failed.contains(candidate)) {
        return candidate;
      }
    }
  }

  /// Writes [bytes] to `[folderPath]/[fileName]`, returning whether it succeeded — logged on
  /// failure, exactly like [_writeToPickedLocation]'s own write.
  Future<bool> _writeBytesInFolder({
    required String folderPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = p.join(folderPath, fileName);
    try {
      await File(path).writeAsBytes(bytes, flush: true);
      return true;
    } catch (error) {
      appLogger().e("A problem occurred when tried to write the file at: $path, error: $error");
      return false;
    }
  }

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
