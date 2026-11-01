// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_move_status.dart';
import 'package:path/path.dart' as p;

/// Move the open project's file to a new location: the copy, the swap onto the copy, and the
/// clean-up of the old file and of the relay sidecar beside it.
///
/// The swap changes the manager's state, which this class has no access to: it reports it through
/// [moveProject]'s `onSwapped` callback, at the point the old behaviour set it.
abstract final class OcptProjectMoveOps {
  /// Move the `currentProject`'s file to [newFilePath] — the project settings page's own `Move…`
  /// action — and keep it the `currentProject` there.
  ///
  /// Refused with [OcptProjectMoveStatus.noProjectOpen] when no project is open or the open one
  /// sits under a read-only version preview, and with [OcptProjectMoveStatus.fileAlreadyExists]
  /// when a file already sits at [newFilePath] — neither ever touches anything. Asking to move a
  /// project to the path it is already at is a silent no-op returning [OcptProjectMoveStatus.ok].
  ///
  /// The move is a copy-then-swap, never an in-place rename: `VACUUM INTO` runs on the still-open
  /// [OcptOpenProjectModel.fileDatabase], which needs no connection to close first and yields a
  /// single, consistent file — including the schema's own `user_version` — even though the source
  /// is being written to right up to the moment it runs. The copy is opened and read back (its
  /// `project_info` row) to make sure it is a real project before anything else happens; only once
  /// that has succeeded is `_currentProject` swapped to point at it, the old connection closed, and
  /// the old file (with its `-wal`/`-shm` companions, if SQLite left any) deleted. Any failure
  /// before the swap deletes the half-written copy and returns [OcptProjectMoveStatus.ioError],
  /// leaving the original file exactly as it was; a failure deleting the *old* file after the swap
  /// has already happened is only ever logged — the move itself has already succeeded by then.
  ///
  /// The `<path>.relay.sqlite` sidecar an in-app-hosted relay stores beside the project file, if
  /// one exists, travels with it (with its own `-wal`/`-shm`), renamed first and
  /// copied-then-deleted as a fallback across filesystems. **This never checks whether in-app
  /// hosting is currently online** for the project being moved: this manager is a dependency of
  /// `OcptSyncManager`, which `OcptRelayHostManager` itself depends on, so it may never import
  /// either — the dependency rules this whole app follows forbid it (`AGENTS.md`, "Dependencies
  /// never reference their dependents"). A hosted relay keeps the sidecar file open, so moving it
  /// out from under a live server would leave that server writing to a file at a path nothing else
  /// still expects; it is therefore the caller's own responsibility to withhold `Move…` while
  /// hosting is online for this project (`OcptProjectSettingsBloc` reads
  /// `OcptRelayHostManager.state` for exactly that), and this method trusts that it did.
  ///
  /// For the very same reason, **this never touches a running sync session**: `OcptSyncSession` is
  /// owned by `OcptSyncManager`, which this manager may not import either. A session reading or
  /// writing through the very [OcptOpenProjectModel.fileDatabase] connection this closes on a
  /// successful move would find it closed under it; the caller stops the session first and restarts
  /// it against the freshly moved database afterwards, mirroring
  /// `OcptWorkspaceBloc._startSyncSessionIfPaired`'s own start path.
  ///
  /// The recent-projects entry the old path named is updated to the new one in place
  /// ([OcptPropertiesManager.updateRecentProjectPath]), and [newFilePath]'s own parent folder is
  /// remembered as the next dialog's suggested one ([rememberProjectsDirectory]), exactly as
  /// `createProject` already does for a freshly created project.
  static Future<ResultWithStatus<OcptProjectMoveStatus, OcptOpenProjectModel>> moveProject({
    required OcptOpenProjectModel? project,
    required String newFilePath,
    required LogsHelper logger,
    required OcptPropertiesManager propertiesManager,
    required void Function(OcptOpenProjectModel movedProject) onSwapped,
    required Future<void> Function(String directoryPath) rememberProjectsDirectory,
  }) async {
    if (project == null || project.isReadOnly) {
      return const ResultWithStatus(status: OcptProjectMoveStatus.noProjectOpen);
    }

    if (p.equals(newFilePath, project.path)) {
      return ResultWithStatus(status: OcptProjectMoveStatus.ok, value: project);
    }

    if (File(newFilePath).existsSync()) {
      return const ResultWithStatus(status: OcptProjectMoveStatus.fileAlreadyExists);
    }

    OcptProjectDatabase? newDatabase;
    OcptProjectDatabase? copiedDatabase;
    try {
      await File(newFilePath).parent.create(recursive: true);

      // VACUUM INTO takes its target as a plain SQL string expression, not a bindable parameter —
      // the single quotes a path could legitimately contain are doubled, exactly how SQLite's own
      // string-literal escaping works.
      final escapedPath = newFilePath.replaceAll("'", "''");
      await project.fileDatabase.customStatement("VACUUM INTO '$escapedPath'");

      newDatabase = OcptProjectDatabase.alongsideAnother(File(newFilePath));
      final info = await newDatabase.select(newDatabase.ocptProjectInfoTable).getSingleOrNull();
      if (info == null) {
        logger.e(
          "A problem occurred when tried to move project ${project.primaryScreenplayId}: the "
          "copy has no project_info row",
        );
        await newDatabase.close();
        await deleteFileIfExists(newFilePath, logger: logger);
      } else {
        copiedDatabase = newDatabase;
      }
    } catch (error, stackTrace) {
      logger.e(
        "A problem occurred when tried to move project ${project.primaryScreenplayId} to "
        "a new location: ${error.runtimeType}",
        null,
        stackTrace,
      );
      await newDatabase?.close();
      await deleteFileIfExists(newFilePath, logger: logger);
    }

    if (copiedDatabase == null) {
      return const ResultWithStatus(status: OcptProjectMoveStatus.ioError);
    }

    final oldPath = project.path;
    final oldFileDatabase = project.fileDatabase;

    final movedProject = OcptOpenProjectModel(
      path: newFilePath,
      name: project.name,
      primaryScreenplayId: project.primaryScreenplayId,
      database: copiedDatabase,
    );
    onSwapped(movedProject);

    await oldFileDatabase.close();
    await deleteFileAndWalCompanions(oldPath, logger: logger);
    await moveRelaySidecarIfPresent(oldPath: oldPath, newPath: newFilePath, logger: logger);

    await propertiesManager.updateRecentProjectPath(oldPath: oldPath, newPath: newFilePath);
    await rememberProjectsDirectory(p.dirname(newFilePath));

    logger.i("A project was moved: ${project.primaryScreenplayId}");

    return ResultWithStatus(status: OcptProjectMoveStatus.ok, value: movedProject);
  }

  /// Move the `<oldPath minus its extension>.relay.sqlite` sidecar an in-app-hosted relay leaves
  /// beside a project file, along with its own `-wal`/`-shm` companions, to sit beside [newPath]
  /// instead — a no-op when [oldPath] has no such sidecar at all.
  ///
  /// Renamed first, which is instant on the same filesystem; a rename across two different
  /// filesystems fails, so each file falls back to a copy followed by deleting the source. A
  /// failure moving one of the three files is only ever logged: the sidecar is a cache a hosted
  /// relay rebuilds if it has to, not project data, and `OcptProjectsManager.moveCurrentProject`
  /// has already succeeded by the time this runs.
  static Future<void> moveRelaySidecarIfPresent({
    required String oldPath,
    required String newPath,
    required LogsHelper logger,
  }) async {
    final oldSidecarPath = p.setExtension(oldPath, ".relay.sqlite");
    if (!File(oldSidecarPath).existsSync()) {
      return;
    }
    final newSidecarPath = p.setExtension(newPath, ".relay.sqlite");

    for (final suffix in ["", "-wal", "-shm"]) {
      final source = File("$oldSidecarPath$suffix");
      if (!source.existsSync()) {
        continue;
      }

      final destinationPath = "$newSidecarPath$suffix";
      try {
        await source.rename(destinationPath);
      } catch (error, stackTrace) {
        // A rename cannot cross file systems, so a failing one is the expected case for a move
        // onto another drive and the copy below is the way through.
        logger.d(
          "Could not rename the relay sidecar file, copying it instead: ${error.runtimeType}",
          null,
          stackTrace,
        );
        try {
          await source.copy(destinationPath);
          await source.delete();
        } catch (error, stackTrace) {
          logger.w("Could not move a relay sidecar file: ${error.runtimeType}", null, stackTrace);
        }
      }
    }
  }

  /// Delete [path] and its SQLite `-wal`/`-shm` companions, if any of the three exist. A failure
  /// deleting any of them is only ever logged, never thrown: by the time this runs the project has
  /// already been moved to its new file, and a leftover fragment of the old one is a cosmetic
  /// annoyance, not a reason to report the move itself as failed.
  static Future<void> deleteFileAndWalCompanions(String path, {required LogsHelper logger}) async {
    for (final candidate in [path, "$path-wal", "$path-shm"]) {
      await deleteFileIfExists(candidate, logger: logger);
    }
  }

  /// Delete [path] if it exists, logging rather than throwing on failure.
  static Future<void> deleteFileIfExists(String path, {required LogsHelper logger}) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      logger.w("Could not delete a file: ${error.runtimeType}", null, stackTrace);
    }
  }
}
