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
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_manifest.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';

/// Everything a bloc needs to write a project out as a portable package: the pre-flight over the
/// files it references, the question that follows when some of them are gone, the native save
/// dialog and the write itself.
///
/// A package covers the whole project rather than any one mode's data, so this is deliberately a
/// mixin (the idiom `MixinOcptProjectVersionsBloc` already follows) rather than a bloc of its own
/// or a copy in each caller: the `Export` panel's standing project card dispatches the same events
/// whichever mode it was opened from, `OcptHomeBloc` mixes this in too for a project card's own
/// `Export…`, and a new caller gets it by mixing this in and answering the three hooks below.
///
/// **The target is resolved once per request, in [_onExportRequested]**:
/// [OcptProjectPackageExportRequestedEvent.target] when the caller named one, or the project
/// currently open otherwise — which is what every production mode's panel relies on, since it asks
/// from inside a project. A caller with neither (the home page, for an entry nothing has opened)
/// gets nothing exported, exactly as a mode with no project open today.
///
/// [flushPendingProjectWrites] is the very hook the versions mixin declares, for the very reason:
/// the package is built from the **project file on disk**, so a field edit still sitting in a
/// debounce would be missing from what a colleague receives, exactly as it would be missing from a
/// version preview. A bloc already answering one mixin answers both with the same method — one
/// with nothing pending (the home page) answers it with a no-op.
///
/// Nothing here reads or writes the open database. The export works from
/// [OcptProjectPackageTarget.filePath] alone (see `OcptProjectPackageService`), which is what lets
/// the same manager call serve a project open in a mode and a project card on the home page where
/// no project is open at all.
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

  /// The target the pre-flight question is currently about, from the moment it found a missing
  /// file until [OcptProjectPackageExportConfirmedEvent] uses it — null the rest of the time.
  ///
  /// [OcptProjectPackageExportConfirmedEvent] deliberately does not carry the target again: the
  /// mode or the page resolves it from the very question it just showed, and a bloc holding a
  /// **resolved word** across that wait (the way the confirmed event still carries `fileTypeLabel`
  /// fresh, rather than reusing what the request brought) would be holding something that could
  /// have changed under it — a locale can flip mid-dialog, a save dialog's own label with it. A
  /// file path is not that: it is a fact about which project this export is for, settled the
  /// moment the question was raised, so remembering it here rather than re-resolving it is safe in
  /// a way re-resolving `fileTypeLabel` would not be.
  ///
  /// Cleared once [_onExportConfirmed] has read it (the question answered) and, defensively,
  /// whenever a notice is emitted (the question reported on) — never by
  /// [_onMissingFilesAskDismissed], which the mode/page dispatches the instant the pending state is
  /// read, well before the user has actually answered the dialog it is about to open: clearing the
  /// target there would lose it before [_onExportConfirmed] ever gets to use it.
  OcptProjectPackageTarget? _pendingProjectPackageExportTarget;

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();

    on<OcptProjectPackageExportRequestedEvent>(_onExportRequested);
    on<OcptProjectPackageMissingFilesAskDismissedEvent>(_onMissingFilesAskDismissed);
    on<OcptProjectPackageExportConfirmedEvent>(_onExportConfirmed);
    on<OcptProjectPackageNoticeDismissedEvent>(_onNoticeDismissed);
  }

  /// Resolves what this export is about, flushes whatever the caller still holds, scans the files
  /// the project references, and either asks about the missing ones or writes the package straight
  /// away.
  ///
  /// [OcptProjectPackageExportRequestedEvent.target] wins when the caller named one (the home
  /// page's card); otherwise the project currently open is what this defaults to, and nothing is
  /// exported when there is neither — a mode's panel with no project open, exactly as today.
  ///
  /// The read-only-preview refusal only ever applies to that **default**: a version being
  /// previewed is a state of the project open in a mode, and a named target from the home page has
  /// nothing to do with it — the file it names is packaged exactly as it stands, open or not.
  Future<void> _onExportRequested(
    OcptProjectPackageExportRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    if (_isWritingProjectPackage) {
      return;
    }

    final openProject = projectsManager.currentProject;
    final target = event.target ?? _openProjectTarget(openProject);
    if (target == null) {
      return;
    }

    if (event.target == null && openProject!.isReadOnly) {
      appLogger().w("A project package can't be written while a version is being previewed: it "
          "would carry the working copy rather than what is on screen");
      return;
    }

    await flushPendingProjectWrites(emitter);

    final preflight = projectsManager.scanProjectPackageAssets(projectFilePath: target.filePath);
    if (preflight == null) {
      appLogger().e("The files referenced by the project at ${target.filePath} can't be scanned, "
          "so no package can be written");
      _emitNotice(
        emitter,
        const OcptProjectPackageNotice(kind: OcptProjectPackageNoticeKind.exportFailed),
      );
      return;
    }

    if (!preflight.isComplete) {
      _pendingProjectPackageExportTarget = target;
      emitter(state.copyProjectPackageState(projectPackagePendingExport: preflight));
      return;
    }

    await _writePackage(emitter, fileTypeLabel: event.fileTypeLabel, target: target);
  }

  /// The target an export defaults to when the request names none: the project currently open, or
  /// null while none is.
  OcptProjectPackageTarget? _openProjectTarget(OcptOpenProjectModel? project) => project == null
      ? null
      : OcptProjectPackageTarget(filePath: project.path, name: project.name);

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
  /// carries to the other machine. The target it writes is the one [_onExportRequested] stored for
  /// this very question — see [_pendingProjectPackageExportTarget].
  Future<void> _onExportConfirmed(
    OcptProjectPackageExportConfirmedEvent event,
    Emitter<S> emitter,
  ) async {
    if (_isWritingProjectPackage) {
      return;
    }

    final target = _pendingProjectPackageExportTarget;
    _pendingProjectPackageExportTarget = null;
    if (target == null) {
      return;
    }

    await _writePackage(emitter, fileTypeLabel: event.fileTypeLabel, target: target);
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
  Future<void> _writePackage(
    Emitter<S> emitter, {
    required String fileTypeLabel,
    required OcptProjectPackageTarget target,
  }) async {
    _isWritingProjectPackage = true;
    try {
      final packagePath = await exportManager.saveLocationService.pickSaveLocation(
        suggestedFileName: ocptExportFileNameOf(
          projectName: target.name,
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
        projectFilePath: target.filePath,
        projectName: target.name,
        packageFilePath: packagePath,
      );

      final report = result.value;
      if (!result.status.isSuccess || report == null) {
        appLogger().e("The project at ${target.filePath} can't be packaged into $packagePath: "
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
      appLogger().e("A problem occurred when tried to package the project at ${target.filePath}: "
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
  /// would reopen on the next state change. [_pendingProjectPackageExportTarget] is cleared here
  /// too, defensively — by the time this runs it is already null on every path that ever set it,
  /// [_onExportConfirmed] having consumed it first.
  void _emitNotice(Emitter<S> emitter, OcptProjectPackageNotice notice) {
    _pendingProjectPackageExportTarget = null;
    emitter(
      state.copyProjectPackageState(
        projectPackageNotice: notice,
        clearProjectPackagePendingExport: true,
      ),
    );
  }
}
