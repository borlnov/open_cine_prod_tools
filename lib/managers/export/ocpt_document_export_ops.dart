// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_breakdown_sheets_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_breakdown_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_contact_list_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_write_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_pdf_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_resources_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_scenario_coverage_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_storyboard_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';

/// The export of the screenplay, the shot list, the storyboard and floor plans, the resources and
/// the script breakdown: each one renders its document and hands the bytes to the write funnel.
abstract final class OcptDocumentExportOps {
  /// Shows the native save dialog and writes [fountainText] to the chosen `.fountain` file.
  ///
  /// [fileTypeLabel] is the localized label passed to the native dialog's type filter. [episodeTag]
  /// is the selected episode's own tag, resolved by the caller (this manager has no `Tr` of its
  /// own) and present only while the open project holds more than one episode — a screenplay is one
  /// episode's own text, so two episodes exported into the same folder must not silently overwrite
  /// one another (issue #55, ADR 0019). Returns the write funnel's own outcome, or null if the user
  /// cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  static Future<OcptExportOutcome?> exportFountain({
    required String fountainText,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptFountainIoService fountainIoService,
  }) => writer.writeToPickedLocation(
    suggestedFileName: fountainIoService.fountainFileName(
      projectName: projectName,
      episodeTag: episodeTag,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: [OcptFountainIoService.fountainFileExtension],
    bytes: fountainIoService.encodeFountainText(fountainText),
    shareAnchor: shareAnchor,
  );

  /// Renders [document] into a PDF via [pdfExportService] and shows the native save dialog to
  /// write it out.
  ///
  /// [fileTypeLabel] is the localized label passed to the native dialog's type filter. [episodeTag]
  /// is the selected episode's own tag, resolved by the caller (this manager has no `Tr` of its
  /// own) and present only while the open project holds more than one episode — see
  /// [exportFountain]'s own doc comment for why. Returns the write funnel's own outcome, or null if
  /// the user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  static Future<OcptExportOutcome?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptPdfExportService pdfExportService,
  }) async {
    final bytes = await pdfExportService.generate(
      document: document,
      pageSetup: pageSetup,
      projectName: projectName,
      includeSceneNumbers: includeSceneNumbers,
      includeTitlePage: includeTitlePage,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: pdfExportService.pdfFileName(
        projectName: projectName,
        episodeTag: episodeTag,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Builds the XLSX workbook of [snapshot] via [shotListXlsxExportService] and shows the native
  /// save dialog to write it out.
  ///
  /// [labels] carries every localized string the sheet itself holds (its name, its headers, the
  /// status labels and the sequence separator titles), and [fileTypeLabel] is the localized label
  /// passed to the native dialog's type filter — this manager has no `Tr` of its own. [episodeTag]
  /// is the selected episode's own tag, resolved by the caller and present only while the open
  /// project holds more than one episode — see [exportFountain]'s own doc comment for why. Returns
  /// the write funnel's own outcome, or null if the user cancelled or the save failed (failures are
  /// logged; the OS dialog already reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportShotListXlsx({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptShotListXlsxExportService shotListXlsxExportService,
  }) => writer.writeWorkbookToPickedLocation(
    suggestedFileName: shotListXlsxExportService.xlsxFileName(
      projectName: projectName,
      episodeTag: episodeTag,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    workbook: shotListXlsxExportService.generate(snapshot: snapshot, labels: labels),
    shareAnchor: shareAnchor,
  );

  /// Renders the scenario coverage of [snapshot] over [document] via [scenarioCoveragePdfService]
  /// and shows the native save dialog to write it out.
  ///
  /// [screenplayText] must be the very text [document] was parsed from and [snapshot]'s scenes were
  /// indexed against — a coverage range addresses it by character offset. [labels] carries every
  /// localized string the document itself holds (the two appendix pages' headings and headers, the
  /// sequence titles and the file name's own suffix) and [fileTypeLabel] the one the native dialog
  /// needs — this manager has no `Tr` of its own. [episodeTag] is the selected episode's own tag,
  /// resolved by the caller and present only while the open project holds more than one episode —
  /// see [exportFountain]'s own doc comment for why. Returns the write funnel's own outcome, or
  /// null if the user cancelled or the save failed (failures are logged; the OS dialog already
  /// reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportScenarioCoverage({
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
    String? episodeTag,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptScenarioCoveragePdfService scenarioCoveragePdfService,
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

    return writer.writeToPickedLocation(
      suggestedFileName: scenarioCoveragePdfService.coverageFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
        episodeTag: episodeTag,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the storyboard of [snapshot]/[storyboardSnapshot] via [storyboardPdfService] and
  /// shows the native save dialog to write it out.
  ///
  /// [shotsPerPage] and [includeFloorPlansAfterEachSequence] are the dialog's own options;
  /// [floorPlanSnapshot] and [floorPlanLabels] are required exactly when the toggle is on, so the
  /// appended sheets can be drawn. [labels] carries every localized string the document itself
  /// holds and [fileTypeLabel] the one the native dialog needs — this manager has no `Tr` of its
  /// own. [episodeTag] is the selected episode's own tag, present only while the open project
  /// holds more than one episode — see [exportFountain]'s own doc comment for why. Returns the
  /// write funnel's own outcome, or null if the user cancelled or the save failed (failures are
  /// logged; the OS dialog already reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportStoryboard({
    required OcptShotListSnapshot snapshot,
    required OcptStoryboardSnapshot storyboardSnapshot,
    required OcptPageSetup pageSetup,
    required OcptStoryboardLabels labels,
    required String projectName,
    required int shotsPerPage,
    required bool includeFloorPlansAfterEachSequence,
    OcptFloorPlanSnapshot? floorPlanSnapshot,
    OcptFloorPlanLabels? floorPlanLabels,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptStoryboardPdfService storyboardPdfService,
  }) async {
    final bytes = await storyboardPdfService.generate(
      snapshot: snapshot,
      storyboardSnapshot: storyboardSnapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      shotsPerPage: shotsPerPage,
      includeFloorPlansAfterEachSequence: includeFloorPlansAfterEachSequence,
      floorPlanSnapshot: floorPlanSnapshot,
      floorPlanLabels: floorPlanLabels,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: storyboardPdfService.storyboardFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
        episodeTag: episodeTag,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the floor plans of [snapshot]/[floorPlanSnapshot] via [floorPlanPdfService] and shows
  /// the native save dialog to write it out — no options dialog of its own, the page format coming
  /// from [pageSetup] (`OcptShotListState.pageSetup`), mirroring the shot list workbook's own
  /// `Export XLSX` button.
  ///
  /// [labels] carries every localized string the document itself holds and [fileTypeLabel] the one
  /// the native dialog needs — this manager has no `Tr` of its own. [episodeTag] is the selected
  /// episode's own tag, present only while the open project holds more than one episode — see
  /// [exportFountain]'s own doc comment for why. Returns the write funnel's own outcome, or null if
  /// the user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  static Future<OcptExportOutcome?> exportFloorPlans({
    required OcptShotListSnapshot snapshot,
    required OcptFloorPlanSnapshot floorPlanSnapshot,
    required OcptPageSetup pageSetup,
    required OcptFloorPlanLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptFloorPlanPdfService floorPlanPdfService,
  }) async {
    final bytes = await floorPlanPdfService.generate(
      snapshot: snapshot,
      floorPlanSnapshot: floorPlanSnapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: floorPlanPdfService.floorPlansFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
        episodeTag: episodeTag,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Builds the resources catalogue's four-sheet XLSX workbook of [snapshot] via
  /// [resourcesXlsxExportService] and shows the native save dialog to write it out.
  ///
  /// [labels] carries every localized string the four sheets themselves hold, and [fileTypeLabel]
  /// is the localized label passed to the native dialog's type filter — this manager has no `Tr`
  /// of its own. Returns the write funnel's own outcome, or null if the user cancelled or the save
  /// failed (failures are logged; the OS dialog already reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportResourcesXlsx({
    required OcptResourcesSnapshot snapshot,
    required OcptResourcesXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptResourcesXlsxExportService resourcesXlsxExportService,
  }) => writer.writeWorkbookToPickedLocation(
    suggestedFileName: resourcesXlsxExportService.xlsxFileName(
      projectName: projectName,
      suffix: labels.fileNameSuffix,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    workbook: resourcesXlsxExportService.generate(snapshot: snapshot, labels: labels),
    shareAnchor: shareAnchor,
  );

  /// Renders the contact list of [snapshot] via [contactListPdfService] and shows the native save
  /// dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds (the section titles, the
  /// department and position labels and the file name's own suffix) and [fileTypeLabel] the one the
  /// native dialog needs — this manager has no `Tr` of its own. [exportDate] is resolved by the
  /// caller, exactly as the schedule mode's own PDF exports resolve theirs, so a test can pin it
  /// rather than race a midnight rollover. Returns the write funnel's own outcome, or null if the
  /// user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  static Future<OcptExportOutcome?> exportContactList({
    required OcptResourcesSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptContactListLabels labels,
    required String projectName,
    required String fileTypeLabel,
    DateTime? exportDate,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptContactListPdfService contactListPdfService,
  }) async {
    final bytes = await contactListPdfService.generate(
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      exportDate: exportDate,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: contactListPdfService.contactListFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the breakdown sheets of [snapshot] via [breakdownSheetsPdfService] and shows the
  /// native save dialog to write them out.
  ///
  /// [document] is the screenplay [snapshot]'s scenes were indexed against, read for each scene's
  /// own length alone (see the service's own doc comment). [labels] carries every localized string
  /// the document itself holds (the scene titles, the section headings, the status and category
  /// labels and the file name's own suffix) and [fileTypeLabel] the one the native dialog needs —
  /// this manager has no `Tr` of its own. [episodeTag] is the selected episode's own tag, resolved
  /// by the caller and present only while the open project holds more than one episode — see
  /// [exportFountain]'s own doc comment for why. Returns the write funnel's own outcome, or null if
  /// the user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  static Future<OcptExportOutcome?> exportBreakdownSheets({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownSheetsLabels labels,
    required String projectName,
    required bool onlyDoneScenes,
    required bool includeNotes,
    required bool includeToFindList,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptBreakdownSheetsPdfService breakdownSheetsPdfService,
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

    return writer.writeToPickedLocation(
      suggestedFileName: breakdownSheetsPdfService.sheetsFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
        episodeTag: episodeTag,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Builds the breakdown's two-sheet XLSX workbook of [snapshot] via [breakdownXlsxExportService]
  /// and shows the native save dialog to write it out.
  ///
  /// [document] is the screenplay [snapshot]'s scenes were indexed against, read for each scene's
  /// own length alone, exactly as [exportBreakdownSheets] reads it — see
  /// [OcptBreakdownXlsxExportService]'s own doc comment. [labels] carries every localized string
  /// the two sheets themselves hold and [fileTypeLabel] the one the native dialog needs — this
  /// manager has no `Tr` of its own. [episodeTag] is the selected episode's own tag, resolved by
  /// the caller and present only while the open project holds more than one episode — see
  /// [exportFountain]'s own doc comment for why. Unlike the breakdown sheets, this export takes no
  /// options dialog: there is nothing to ask before writing it out. Returns the write funnel's own
  /// outcome, or null if the user cancelled or the save failed (failures are logged; the OS dialog
  /// already reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportBreakdownXlsx({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptBreakdownXlsxExportService breakdownXlsxExportService,
  }) => writer.writeWorkbookToPickedLocation(
    suggestedFileName: breakdownXlsxExportService.xlsxFileName(
      projectName: projectName,
      suffix: labels.fileNameSuffix,
      episodeTag: episodeTag,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    workbook: breakdownXlsxExportService.generate(
      document: document,
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
    ),
    shareAnchor: shareAnchor,
  );
}
