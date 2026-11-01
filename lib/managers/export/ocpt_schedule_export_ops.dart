// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_day_out_of_days_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_write_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_one_line_schedule_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_sides_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_sides_presentation.dart';

/// The export of the shooting schedule's documents: the call sheets, the shooting plan, the day out
/// of days, the one-line schedule and the sides.
abstract final class OcptScheduleExportOps {
  /// Renders one general call sheet per day of [dayIds] via [callSheetPdfService] and writes every
  /// one of them into a folder the user picks.
  ///
  /// This is the one export of this app that writes more than one file, so it shows the native
  /// "choose a folder" dialog ([confirmButtonText] is its own confirm button's localized label)
  /// rather than a "save as" one. Returns null if the user cancelled that dialog — nothing was
  /// touched on disk yet at that point — or an [OcptCallSheetExportResult] once a folder was
  /// chosen, even when every write inside it failed: a folder was picked, so the caller needs to
  /// know exactly what did and did not get written into it rather than being told the whole run
  /// "failed". A write failure is logged (this manager's usual soft-failure convention) and the
  /// file's own name lands in [OcptCallSheetExportResult.failedFileNames] instead of
  /// [OcptCallSheetExportResult.writtenFileNames].
  ///
  /// The moment every sheet of the run is stamped with is resolved **once**, here, and handed to
  /// each of them: a folder of sheets produced by one gesture is one issue of that day's paperwork,
  /// and a batch that read the clock per file would hand two people sheets a minute apart with no
  /// way to tell they are the same one.
  ///
  /// On mobile there is no folder to choose at all: every sheet is written into a temporary one
  /// instead, then handed to the OS share sheet together once the run is done, anchored at
  /// [shareAnchor] on an iPad/Mac — [OcptCallSheetExportResult.wasShared] is what tells a caller
  /// which of the two happened.
  static Future<OcptCallSheetExportResult?> exportGeneralCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptCallSheetPdfService callSheetPdfService,
  }) async {
    final folderPath = await writer.resolveCallSheetFolder(confirmButtonText: confirmButtonText);
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

      if (await writer.writeBytesInFolder(
        folderPath: folderPath,
        fileName: fileName,
        bytes: bytes,
      )) {
        written.add(fileName);
      } else {
        failed.add(fileName);
      }
    }

    return writer.finishCallSheetExport(
      folderPath: folderPath,
      written: written,
      failed: failed,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders one named call sheet per (convocation × day) of [dayIds] via [callSheetPdfService] and
  /// writes every one of them into a folder the user picks — a call sheet being a document about a
  /// day, so a recipient convoked on two of [dayIds] gets two files, one for each.
  ///
  /// The loop is over each day's **own** convocations, filtered by [convocationKeys], never over
  /// the product of the two: a key ticked in the dialog but convoked on none of a given day's slots
  /// simply yields no file for that day rather than an empty one. [convocationKeys] selects which
  /// of a day's own convocations are printed — `OcptDayConvocation.selectionKey`, the very key the
  /// dialog ticks them by — or null to print every convocation of every day, the common case when
  /// nobody has narrowed the selection down. See [exportGeneralCallSheets] for the folder-picking,
  /// the once-per-run export moment (its own argument holds for a run spanning several days exactly
  /// as it does for one: a folder of sheets produced by one gesture is one issue of that paperwork)
  /// and the partial-failure contract, identical here.
  ///
  /// **A guest is never printed here**, whatever [convocationKeys] says: a guest carries no
  /// `selectionKey` at all, so they are out before either the explicit selection or the "print
  /// every convocation" default is applied — a guest is not yet a call sheet recipient. A
  /// **candidate** very much is one: somebody coming to be seen for a part is convoked like anybody
  /// else (ADR
  /// 0018) and is owed the sheet saying when.
  ///
  /// `_uniqueFileName` accumulates across the **whole** run rather than being reset per day, so two
  /// recipients whose names collide on one day still each get a file of their own (`-2`, `-3`) —
  /// the file name already carries the day's own tag, so two different days' sheets never collide
  /// with each other in the first place.
  ///
  /// On mobile the whole run is shared together in one gesture rather than written into a folder
  /// the user picks — see [exportGeneralCallSheets]'s own doc comment for [shareAnchor] and
  /// [OcptCallSheetExportResult.wasShared].
  static Future<OcptCallSheetExportResult?> exportNamedCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    Set<String>? convocationKeys,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptCallSheetPdfService callSheetPdfService,
  }) async {
    final folderPath = await writer.resolveCallSheetFolder(confirmButtonText: confirmButtonText);
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
          if (convocation.selectionKey case final key?)
            if (convocationKeys == null || convocationKeys.contains(key)) convocation,
      ];

      for (final convocation in convocations) {
        final personName = OcptExportWriteService.namedCallSheetRecipientNameOf(plan, convocation);
        final fileName = OcptExportWriteService.uniqueFileName(
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

        if (await writer.writeBytesInFolder(
          folderPath: folderPath,
          fileName: fileName,
          bytes: bytes,
        )) {
          written.add(fileName);
        } else {
          failed.add(fileName);
        }
      }
    }

    return writer.finishCallSheetExport(
      folderPath: folderPath,
      written: written,
      failed: failed,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the whole-shoot shooting plan of [dayIds] via [shootingPlanPdfService] and shows the
  /// native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds (the day titles, the
  /// director line, the grid and section headings, the shot table's own headers and the file name's
  /// own suffix) and [fileTypeLabel] the one the native dialog needs — this manager has no `Tr` of
  /// its own. Unlike the call sheets, this is a **single** file: the whole shoot's own plan,
  /// through `pickSaveLocation` rather than a folder. Returns the write funnel's own outcome, or
  /// null if the user cancelled or the save failed (failures are logged; the OS dialog already
  /// reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportShootingPlan({
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
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptShootingPlanPdfService shootingPlanPdfService,
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

    return writer.writeToPickedLocation(
      suggestedFileName: shootingPlanPdfService.shootingPlanFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Builds the whole-shoot shooting plan's own five-sheet XLSX workbook of [dayIds] via
  /// [shootingPlanXlsxExportService] and shows the native save dialog to write it out.
  ///
  /// [labels] carries every localized string the five sheets themselves hold and [fileTypeLabel]
  /// the one the native dialog needs — this manager has no `Tr` of its own. Unlike
  /// [exportShootingPlan], this export takes no options beyond [dayIds]: there is no page geometry
  /// to ask about, and a sheet costs nothing to hide, unlike a PDF's own page. Returns the write
  /// funnel's own outcome, or null if the user cancelled or the save failed (failures are logged;
  /// the OS dialog already reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportShootingPlanXlsx({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptShootingPlanXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptShootingPlanXlsxExportService shootingPlanXlsxExportService,
  }) => writer.writeWorkbookToPickedLocation(
    suggestedFileName: shootingPlanXlsxExportService.xlsxFileName(
      projectName: projectName,
      suffix: labels.fileNameSuffix,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    workbook: shootingPlanXlsxExportService.generate(plan: plan, dayIds: dayIds, labels: labels),
    shareAnchor: shareAnchor,
  );

  /// Renders the cast's own *Day Out of Days* over [dayIds] via [dayOutOfDaysPdfService] and shows
  /// the native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds (the column dates, the code
  /// letters and their legend, the two count headers and the file name's own suffix) and
  /// [fileTypeLabel] the one the native dialog needs — this manager has no `Tr` of its own. Like
  /// the shooting plan and unlike the call sheets, this is a **single** file, through
  /// `pickSaveLocation` rather than a folder. Returns the write funnel's own outcome, or null if
  /// the user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  static Future<OcptExportOutcome?> exportDayOutOfDays({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptDayOutOfDaysLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptDayOutOfDaysPdfService dayOutOfDaysPdfService,
  }) async {
    final bytes = await dayOutOfDaysPdfService.generate(
      plan: plan,
      dayIds: dayIds,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: dayOutOfDaysPdfService.dayOutOfDaysFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the one-line schedule over [dayIds] via [oneLineSchedulePdfService] and shows the
  /// native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds (the day titles, the column
  /// headers and the file name's own suffix) and [fileTypeLabel] the one the native dialog needs —
  /// this manager has no `Tr` of its own. Like the shooting plan and the *Day Out of Days*, this is
  /// a **single** file, through `pickSaveLocation` rather than a folder. Returns the write funnel's
  /// own outcome, or null if the user cancelled or the save failed (failures are logged; the OS
  /// dialog already reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportOneLineSchedule({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptOneLineScheduleLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptOneLineSchedulePdfService oneLineSchedulePdfService,
  }) async {
    final bytes = await oneLineSchedulePdfService.generate(
      plan: plan,
      dayIds: dayIds,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: oneLineSchedulePdfService.oneLineScheduleFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders [dayId]'s own sides booklet via [sidesPdfService] and shows the native save dialog to
  /// write it out.
  ///
  /// [documents] is a parameter rather than something this manager reads off the open project, for
  /// the same reason `exportScenarioCoverage` takes one: this manager touches no database, and the
  /// screenplay text a booklet is sliced from is the caller's to supply — one composed run per
  /// episode the day plays, in the order the booklet chains them in (see
  /// [OcptSidesPdfService.generate]'s own doc comment for why a screenplay is never composed
  /// alongside another's). [labels] carries every localized string the document itself holds (its
  /// own title, the day tag prefix, the printed day's own title, each episode's own label, the
  /// script-page prefix and the file name's own suffix) and [fileTypeLabel] the one the native
  /// dialog needs — this manager has no `Tr` of its own. Like the shooting plan, the *Day Out of
  /// Days* and the one-line schedule, this is a **single** file, through `pickSaveLocation` rather
  /// than a folder — one booklet is one day's own paperwork, handed to one recipient at a time.
  /// Returns the write funnel's own outcome, or null if the user cancelled or the save failed
  /// (failures are logged; the OS dialog already reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportSides({
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required List<({String screenplayId, FountainDocument document})> documents,
    required OcptPageSetup pageSetup,
    required OcptSidesLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required OcptSidesPresentation presentation,
    required String fileTypeLabel,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptSidesPdfService sidesPdfService,
  }) async {
    final bytes = await sidesPdfService.generate(
      plan: plan,
      dayId: dayId,
      documents: documents,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeSceneNumbers: includeSceneNumbers,
      presentation: presentation,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: sidesPdfService.sidesFileName(
        plan: plan,
        dayId: dayId,
        projectName: projectName,
        labels: labels,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }
}
