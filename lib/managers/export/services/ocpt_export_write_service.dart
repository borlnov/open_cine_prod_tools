// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_share_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_xlsx_export_status.dart';
import 'package:path/path.dart' as p;

/// The write funnel every export goes through: the native save dialog on desktop, the OS share
/// sheet on mobile, and the folder run the call sheets write into.
///
/// Every failure is logged and answered as a null outcome (or false), which the callers treat as a
/// cancellation; the OS dialog has already told the user.
class OcptExportWriteService extends AbsOcptService {
  /// The service showing the native save and folder dialogs.
  final OcptSaveLocationService _saveLocationService;

  /// The service handing files to the OS share sheet.
  final OcptShareService _shareService;

  /// The platform manager telling a desktop platform from a mobile one.
  final PlatformManager platformManager;

  /// Class constructor
  const OcptExportWriteService({
    required super.logger,
    required OcptSaveLocationService saveLocationService,
    required OcptShareService shareService,
    required this.platformManager,
  }) : _saveLocationService = saveLocationService,
       _shareService = shareService;

  /// Shows the native save dialog and writes [bytes] to the chosen location — or, on
  /// [PlatformManager.isMobile], writes them to a `path_provider` temporary file and hands that to
  /// `shareService` instead, [shareAnchor] anchoring the popover it opens as on an iPad or a Mac.
  ///
  /// Returns [OcptExportSaved] with the written path, [OcptExportShared] once the bytes were handed
  /// to the share sheet, or null if the user cancelled the dialog or the write/share failed
  /// (logged; treated the same as a cancellation by every caller).
  Future<OcptExportOutcome?> writeToPickedLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    required Uint8List bytes,
    Rect? shareAnchor,
  }) async {
    if (platformManager.isMobile) {
      return shareBytes(fileName: suggestedFileName, bytes: bytes, shareAnchor: shareAnchor);
    }

    final path = await _saveLocationService.pickSaveLocation(
      suggestedFileName: suggestedFileName,
      fileTypeLabel: fileTypeLabel,
      extensions: extensions,
    );
    if (path == null) {
      return null;
    }

    OcptExportOutcome? outcome;
    try {
      await File(path).writeAsBytes(bytes, flush: true);
      logger.i("An export was saved");
      outcome = OcptExportSaved(path);
    } catch (error, stackTrace) {
      logger.e(
        "A problem occurred when tried to write an export file, error: "
        "${error.runtimeType}",
        null,
        stackTrace,
      );
    }

    return outcome;
  }

  /// [writeToPickedLocation] for a workbook an XLSX service has just built.
  ///
  /// A workbook that could not be encoded is logged and answered as [OcptExportFailed], before any
  /// save dialog is shown: the caller words it as a failed export, not a cancellation.
  Future<OcptExportOutcome?> writeWorkbookToPickedLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    required ResultWithStatus<OcptXlsxExportStatus, Uint8List> workbook,
    Rect? shareAnchor,
  }) async {
    final bytes = workbook.value;
    if (!workbook.status.isSuccess || bytes == null) {
      logger.e("A workbook could not be built for an export: ${workbook.status}");
      return const OcptExportFailed();
    }

    return writeToPickedLocation(
      suggestedFileName: suggestedFileName,
      fileTypeLabel: fileTypeLabel,
      extensions: extensions,
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// [writeToPickedLocation]'s mobile branch: writes [bytes] to [fileName] under
  /// [OcptShareService.temporaryDirectory] and hands that file to `shareService`, anchored at
  /// [shareAnchor].
  ///
  /// Returns [OcptExportShared] once the share sheet was shown, or null if the temporary file could
  /// not be written or the share sheet itself could not be shown (logged, exactly like the desktop
  /// write).
  Future<OcptExportOutcome?> shareBytes({
    required String fileName,
    required Uint8List bytes,
    Rect? shareAnchor,
  }) async {
    OcptExportOutcome? outcome;
    try {
      final directory = await _shareService.temporaryDirectory();
      final path = p.join(directory.path, fileName);
      await File(path).writeAsBytes(bytes, flush: true);

      final shared = await _shareService.shareFiles(
        paths: [path],
        sharePositionOrigin: shareAnchor,
      );
      if (shared) {
        logger.i("An export was handed to the share sheet");
      }
      outcome = shared ? const OcptExportShared() : null;
    } catch (error, stackTrace) {
      logger.e(
        "A problem occurred when tried to share a file, error: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }

    return outcome;
  }

  /// Writes [bytes] to `[folderPath]/[fileName]`, returning whether it succeeded — logged on
  /// failure, exactly like [writeToPickedLocation]'s own write.
  Future<bool> writeBytesInFolder({
    required String folderPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = p.join(folderPath, fileName);
    var isWritten = false;
    try {
      await File(path).writeAsBytes(bytes, flush: true);
      logger.i("An export was saved");
      isWritten = true;
    } catch (error, stackTrace) {
      logger.e(
        "A problem occurred when tried to write an export file, error: "
        "${error.runtimeType}",
        null,
        stackTrace,
      );
    }

    return isWritten;
  }

  /// Resolves the folder `exportGeneralCallSheets`/`exportNamedCallSheets` write into: the folder
  /// the user picks through the native "choose a folder" dialog on desktop, or a `path_provider`
  /// temporary directory on mobile, where there is no such dialog to show at all.
  Future<String?> resolveCallSheetFolder({required String confirmButtonText}) async {
    if (platformManager.isMobile) {
      return (await _shareService.temporaryDirectory()).path;
    }

    return _saveLocationService.pickDirectory(confirmButtonText: confirmButtonText);
  }

  /// Finishes a call sheet run: on mobile, hands every file in [written] to the OS share sheet
  /// together, in the one gesture, anchored at [shareAnchor] — rather than leaving them sitting in
  /// the temporary folder [resolveCallSheetFolder] wrote them into. A no-op on desktop, and when
  /// [written] is empty (nothing came out of the run to share).
  Future<OcptCallSheetExportResult> finishCallSheetExport({
    required String folderPath,
    required List<String> written,
    required List<String> failed,
    Rect? shareAnchor,
  }) async {
    var wasShared = false;
    if (platformManager.isMobile && written.isNotEmpty) {
      wasShared = await _shareService.shareFiles(
        paths: [for (final fileName in written) p.join(folderPath, fileName)],
        sharePositionOrigin: shareAnchor,
      );
    }

    return OcptCallSheetExportResult(
      folderPath: folderPath,
      writtenFileNames: written,
      failedFileNames: failed,
      wasShared: wasShared,
    );
  }

  /// [fileName], suffixed with `-2`, `-3`… while [written] or [failed] already holds it.
  ///
  /// Two convoked people sharing one display name — or, far more likely, two whose name is still
  /// blank and which therefore both fall back to the same label — would otherwise be handed the
  /// same file name, and the second write would overwrite the first: one person on the call list
  /// silently ending the export with no call sheet at all. A suffixed duplicate is a name somebody
  /// has to read twice; a missing file is somebody who never gets told when to turn up.
  static String uniqueFileName(String fileName, List<String> written, List<String> failed) {
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

  /// The name a named call sheet's own file is built from for [convocation]: the person's own
  /// display name for a crew or cast recipient, the **candidate's** own for a candidacy — read
  /// through `plan.roleCandidateById`, the candidacy being what points at the person — and the
  /// role's own name for an uncast role, which names nobody else.
  ///
  /// An empty string is a perfectly ordinary answer here, for a recipient the project has not named
  /// yet or a candidacy the file no longer holds: `OcptCallSheetPdfService.namedCallSheetFileName`
  /// falls back to its own localized unnamed-person label for it, and the sheet still gets a
  /// readable file name rather than none.
  static String namedCallSheetRecipientNameOf(
    OcptSchedulePlanSnapshot plan,
    OcptDayConvocation convocation,
  ) {
    final personId = convocation.personId;
    if (personId != null) {
      return plan.personById[personId]?.displayName ?? "";
    }

    return plan.roleById[convocation.roleId]?.name ?? "";
  }
}
