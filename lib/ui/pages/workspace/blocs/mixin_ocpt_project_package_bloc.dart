// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';

/// Everything a production mode's bloc needs to write the open project out as a portable package:
/// the pre-flight over the files it references, the question that follows when some of them are
/// gone, the native save dialog and the write itself.
///
/// A package covers the whole project rather than any one mode's data, so this is deliberately a
/// mixin (the idiom `MixinOcptProjectVersionsBloc` already follows) rather than a bloc of its own
/// or a copy in each mode: the `Export` panel's standing project card dispatches the same events
/// whichever mode it was opened from, and a new production mode gets it by mixing this in and
/// answering the three hooks below.
///
/// [flushPendingProjectWrites] is the very hook the versions mixin declares, for the very reason:
/// the package is built from the **project file on disk**, so a field edit still sitting in a
/// debounce would be missing from what a colleague receives, exactly as it would be missing from a
/// version preview. A mode already answering one mixin answers both with the same method.
///
/// Nothing here reads or writes the open database. The export works from
/// `OcptOpenProjectModel.path` alone (see `OcptProjectPackageService`), which is what lets the same
/// manager call serve a project card on the home page where no project is open at all.
mixin MixinOcptProjectPackageBloc<S extends MixinOcptProjectPackageState<S>> on BlocForMixin<S> {
  /// {@template open_cine_prod_tools.MixinOcptProjectPackageBloc.projectsManager}
  /// The manager owning the open project and the package service behind it.
  ///
  /// Declared here and implemented by each mode's bloc, rather than resolved through [globalGetIt]
  /// by the mixin itself, so a bloc built with an explicitly injected manager (which is what every
  /// test does) has this mixin work against that same instance.
  /// {@endtemplate}
  @protected
  OcptProjectsManager get projectsManager;

  /// {@template open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  /// The manager whose [OcptExportManager.saveLocationService] shows the native save dialog.
  ///
  /// Reached through the manager rather than through [globalGetIt] for the reason
  /// [MixinOcptProjectPackageBloc.projectsManager] gives, and through the export manager rather
  /// than as a service of its own because every other export of this app asks the very same object
  /// where to write.
  /// {@endtemplate}
  @protected
  OcptExportManager get exportManager;

  /// Writes whatever the mode still holds outside the database — a pending autosave, a debounced
  /// field edit — before the project file is copied into a package.
  ///
  /// The same hook `MixinOcptProjectVersionsBloc` declares, with the same signature, so a mode
  /// answers it once for both.
  @protected
  Future<void> flushPendingProjectWrites(Emitter<S> emitter);

  /// Whether a package is being written right now, which is what keeps a second `Export` from
  /// starting one over it.
  ///
  /// A write streams a whole project and everything it references to disk: it can take long enough
  /// for the user to reopen the panel, and two of them running against one save location is not a
  /// thing this has to make sense of.
  bool _isWritingProjectPackage = false;

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();

    on<OcptProjectPackageExportRequestedEvent>(_onExportRequested);
    on<OcptProjectPackageMissingFilesAskDismissedEvent>(_onMissingFilesAskDismissed);
    on<OcptProjectPackageExportConfirmedEvent>(_onExportConfirmed);
    on<OcptProjectPackageNoticeDismissedEvent>(_onNoticeDismissed);
  }

  /// Flushes whatever the mode still holds, scans the files the project references, and either
  /// asks about the missing ones or writes the package straight away.
  ///
  /// Refused while a version is being previewed, belt and braces: the panel already draws the card
  /// greyed there (what it would export is the working copy, not what is on screen), and this makes
  /// the rule hold whatever else ever dispatches this event.
  Future<void> _onExportRequested(
    OcptProjectPackageExportRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    final project = projectsManager.currentProject;
    if (project == null || _isWritingProjectPackage) {
      return;
    }

    if (project.isReadOnly) {
      appLogger().w("A project package can't be written while a version is being previewed: it "
          "would carry the working copy rather than what is on screen");
      return;
    }

    await flushPendingProjectWrites(emitter);

    final preflight = projectsManager.scanProjectPackageAssets(projectFilePath: project.path);
    if (preflight == null) {
      appLogger().e("The files referenced by the project at ${project.path} can't be scanned, so "
          "no package can be written");
      _emitNotice(
        emitter,
        const OcptProjectPackageNotice(kind: OcptProjectPackageNoticeKind.exportFailed),
      );
      return;
    }

    if (!preflight.isComplete) {
      emitter(state.copyProjectPackageState(projectPackagePendingExport: preflight));
      return;
    }

    await _writePackage(emitter, fileTypeLabel: event.fileTypeLabel);
  }

  /// Clears the missing-files question from the state, the mode having opened it.
  Future<void> _onMissingFilesAskDismissed(
    OcptProjectPackageMissingFilesAskDismissedEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(state.copyProjectPackageState(clearProjectPackagePendingExport: true));
  }

  /// Writes the package the user asked for despite the missing files.
  ///
  /// The pre-flight is not run again: it was run a moment ago and answered, and a file that
  /// vanished in between is reported by the write itself, whose own report is what the manifest
  /// carries to the other machine.
  Future<void> _onExportConfirmed(
    OcptProjectPackageExportConfirmedEvent event,
    Emitter<S> emitter,
  ) async {
    if (_isWritingProjectPackage) {
      return;
    }

    await _writePackage(emitter, fileTypeLabel: event.fileTypeLabel);
  }

  /// Clears the transient package notice currently shown, if any.
  Future<void> _onNoticeDismissed(
    OcptProjectPackageNoticeDismissedEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(state.copyProjectPackageState(clearProjectPackageNotice: true));
  }

  /// Asks where to write the package, writes it there, and reports what travelled.
  ///
  /// A cancelled save dialog is a silent no-op, exactly as it is for every other export of this
  /// app: the user closed a dialog they opened. A failure raises the transient notice, and a
  /// success raises it too — a package is a file that lands somewhere the user then has to find.
  Future<void> _writePackage(Emitter<S> emitter, {required String fileTypeLabel}) async {
    final project = projectsManager.currentProject;
    if (project == null) {
      return;
    }

    _isWritingProjectPackage = true;
    try {
      final packagePath = await exportManager.saveLocationService.pickSaveLocation(
        suggestedFileName: ocptExportFileNameOf(
          projectName: project.name,
          extension: ocptPackageFileExtension,
        ),
        fileTypeLabel: fileTypeLabel,
        extensions: const [ocptPackageFileExtension],
      );
      if (packagePath == null) {
        // The user cancelled the save dialog.
        return;
      }

      final result = await projectsManager.exportProjectPackage(
        projectFilePath: project.path,
        projectName: project.name,
        packageFilePath: packagePath,
      );

      final report = result.value;
      if (!result.status.isSuccess || report == null) {
        appLogger().e("The project at ${project.path} can't be packaged into $packagePath: "
            "${result.status}");
        _emitNotice(
          emitter,
          const OcptProjectPackageNotice(kind: OcptProjectPackageNoticeKind.exportFailed),
        );
        return;
      }

      _emitNotice(
        emitter,
        OcptProjectPackageNotice(
          kind: OcptProjectPackageNoticeKind.exportSucceeded,
          path: report.packagePath,
          skippedAssetCount: report.skippedAssets.length,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to package the project at ${project.path}: "
          "$error");
      _emitNotice(
        emitter,
        const OcptProjectPackageNotice(kind: OcptProjectPackageNoticeKind.exportFailed),
      );
    } finally {
      _isWritingProjectPackage = false;
    }
  }

  /// Emits [notice], and clears any question left hanging along with it.
  ///
  /// The two always move together: whatever the outcome, the pre-flight's question has been
  /// answered by the time there is something to report, and a question outliving its own export
  /// would reopen on the next state change.
  void _emitNotice(Emitter<S> emitter, OcptProjectPackageNotice notice) {
    emitter(
      state.copyProjectPackageState(
        projectPackageNotice: notice,
        clearProjectPackagePendingExport: true,
      ),
    );
  }
}
