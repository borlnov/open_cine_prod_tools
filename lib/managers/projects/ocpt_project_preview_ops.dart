// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';

/// Enter the read-only preview of one of the open project's versions.
///
/// The swap of the project on screen is the manager's state, which this class has no access to: it
/// reports it through `onPreviewed`, at the point the old behaviour set it.
abstract final class OcptProjectPreviewOps {
  /// Enter the read-only preview of the version [versionId] of the `currentProject`: the version's
  /// payload is hydrated into an in-memory database, and *that* is what `currentProject` hands the
  /// modes from now on.
  ///
  /// **The project file is never opened for writing by a preview.** It stays open as
  /// [OcptOpenProjectModel.fileDatabase] — same connection, still writable by everything that
  /// isn't a user edit — and a crash mid-preview leaves it exactly as it was. Nothing of the
  /// version is written anywhere either: the page setup it was typeset with travels on
  /// [OcptOpenProjectModel.previewedPageSetup] and is rendered with, never stored, since the
  /// margins half of it is an app-wide preference that has nothing to do with this project.
  ///
  /// Every mode's bloc already rebuilds on `currentProjectStream`, so none of them learns anything
  /// about versions to display one — that stream emission is the whole of the propagation. It
  /// works because the emitted model doesn't compare equal to the previous one (see
  /// [OcptOpenProjectModel.props]).
  ///
  /// Refused with [OcptProjectPreviewStatus.unsavedChanges] while any mode reports itself dirty:
  /// the caller saves first and retries. Refused as a whole on any failure — a preview that can't
  /// be entered leaves the working copy on screen, untouched.
  static Future<ResultWithStatus<OcptProjectPreviewStatus, OcptOpenProjectModel>> previewVersion({
    required OcptOpenProjectModel? project,
    required String versionId,
    required bool hasUnsavedChanges,
    required OcptProjectVersionsService projectVersionsService,
    required LogsHelper logger,
    required void Function(OcptOpenProjectModel previewedProject) onPreviewed,
  }) async {
    if (project == null) {
      return const ResultWithStatus(status: OcptProjectPreviewStatus.noProjectOpen);
    }

    if (hasUnsavedChanges) {
      logger.w(
        "The project version $versionId can't be previewed while a mode still holds unsaved "
        "changes: they must be saved first, or they would be written into the preview",
      );
      return const ResultWithStatus(status: OcptProjectPreviewStatus.unsavedChanges);
    }

    final version = await projectVersionsService.loadVersion(
      database: project.fileDatabase,
      id: versionId,
    );

    if (version == null) {
      logger.w(
        "The project version $versionId can't be previewed: no such version in this project",
      );
      return const ResultWithStatus(status: OcptProjectPreviewStatus.versionNotFound);
    }

    final payloadResult = await projectVersionsService.loadPayload(
      database: project.fileDatabase,
      id: versionId,
    );

    final payload = payloadResult.value;
    if (payload == null) {
      return ResultWithStatus(
        status: switch (payloadResult.status) {
          OcptProjectVersionPayloadStatus.unsupportedFutureFormat =>
            OcptProjectPreviewStatus.unsupportedFutureFormat,
          _ => OcptProjectPreviewStatus.malformedPayload,
        },
      );
    }

    final previewDatabase = OcptProjectDatabase.memory(isPreview: true);
    var isHydrated = false;
    try {
      await projectVersionsService.hydratePreview(
        database: previewDatabase,
        projectInfo: await project.fileDatabase
            .select(project.fileDatabase.ocptProjectInfoTable)
            .getSingle(),
        payload: payload,
      );
      isHydrated = true;
    } catch (error, stackTrace) {
      logger.e(
        "A problem occurred when tried to hydrate the preview of the project version "
        "$versionId: ${error.runtimeType}",
        null,
        stackTrace,
      );
      await previewDatabase.close();
    }

    if (!isHydrated) {
      return const ResultWithStatus(status: OcptProjectPreviewStatus.hydrationFailed);
    }

    // Only now that the new preview is ready does the previous one go: a preview that failed to
    // load must leave what was on screen alone.
    final previousPreviewDatabase = project.isReadOnly ? project.database : null;

    final previewedProject = project.previewing(
      previewDatabase: previewDatabase,
      version: version,
      pageSetup: payload.pageSetup,
    );
    onPreviewed(previewedProject);

    await previousPreviewDatabase?.close();

    logger.i("Previewing the project version $versionId");

    return ResultWithStatus(status: OcptProjectPreviewStatus.ok, value: previewedProject);
  }
}
