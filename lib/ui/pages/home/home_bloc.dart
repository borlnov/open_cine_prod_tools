// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_event.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:path/path.dart' as p;

/// This is the bloc class for the home page.
///
/// It refreshes the recent projects list from [OcptPropertiesManager] (flagging every entry
/// whose file has gone missing since), and orchestrates the "New project"/"Open…"/card-tap/
/// remove-from-list actions: showing the relevant native dialogs through [FileSaverManager] and
/// [FileSelectorManager], delegating the actual create/open work to [OcptProjectsManager], and
/// navigating to the workspace through [OcptRouterManager] (RFL31: navigation only via the router
/// manager) once it succeeds.
///
/// It is also where the app's **compatibility gate** stands: every path that opens a project file
/// runs through here, so every one of them is probed before it is opened, and a file from another
/// build is raised as a question or a refusal rather than migrated behind the user's back.
///
/// It mixes in [MixinOcptProjectPackageBloc] for a project card's own `Export…`: the same flow
/// every production mode's toolbar `Export` panel runs, over a target the card names rather than
/// an open project — nothing has to be open for it, which is the point (see
/// `MixinOcptProjectPackageBloc`'s own doc comment).
class OcptHomeBloc extends BlocForMixin<OcptHomeState>
    with MixinOcptProjectPackageBloc<OcptHomeState> {
  /// The properties manager used to read/update the recent projects list.
  final OcptPropertiesManager _propertiesManager;

  /// The manager used to create, open and close projects.
  final OcptProjectsManager _projectsManager;

  /// The router manager used to navigate to the editor once a project is open.
  final OcptRouterManager _routerManager;

  /// The manager used to show the "New project" save-file dialog.
  final FileSaverManager _fileSaverManager;

  /// The manager used to show the "Open…" open-file dialog.
  final FileSelectorManager _fileSelectorManager;

  /// The manager used to pick and read a `.fountain` file when importing a screenplay.
  final OcptExportManager _exportManager;

  /// Class constructor
  OcptHomeBloc({
    OcptPropertiesManager? propertiesManager,
    OcptProjectsManager? projectsManager,
    OcptRouterManager? routerManager,
    FileSaverManager? fileSaverManager,
    FileSelectorManager? fileSelectorManager,
    OcptExportManager? exportManager,
  }) : _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _fileSaverManager = fileSaverManager ?? globalGetIt().get<FileSaverManager>(),
       _fileSelectorManager = fileSelectorManager ?? globalGetIt().get<FileSelectorManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       super(const OcptHomeState.init()) {
    add(const OcptHomeRefreshRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptHomeRefreshRequestedEvent>(_onRefreshRequested);
    on<OcptHomeCreateProjectRequestedEvent>(_onCreateProjectRequested);
    on<OcptHomeOpenProjectRequestedEvent>(_onOpenProjectRequested);
    on<OcptHomeRemoveRecentProjectRequestedEvent>(_onRemoveRecentProjectRequested);
    on<OcptHomeFileCompatibilityStatedEvent>(_onFileCompatibilityStated);
    on<OcptHomeErrorDismissedEvent>(_onErrorDismissed);
    on<OcptHomeImportScreenplayRequestedEvent>(_onImportScreenplayRequested);
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  @protected
  @override
  OcptExportManager get exportManager => _exportManager;

  /// Does nothing: no project is open from the home page, so there is no debounced field edit or
  /// pending autosave a mode would otherwise still be holding outside the database.
  @protected
  @override
  Future<void> flushPendingProjectWrites(Emitter<OcptHomeState> emitter) async {}

  /// Reloads the recent projects list and recomputes which of them still exist on disk.
  Future<void> _onRefreshRequested(
    OcptHomeRefreshRequestedEvent event,
    Emitter<OcptHomeState> emitter,
  ) async {
    final projects = await _propertiesManager.recentProjects.load() ?? const [];
    final entries = [
      for (final project in projects)
        OcptHomeRecentProjectEntry(project: project, exists: File(project.path).existsSync()),
    ];

    emitter(state.copyWith(recentProjects: entries));
  }

  /// Navigates to the workspace, then reloads the recent projects list once it pops back here.
  ///
  /// The push only completes when the user leaves the workspace, and what they did in there is
  /// exactly what this page shows: `OcptProjectsManager.closeCurrentProject` writes back the
  /// project's episode count on the way out, and its entry has just been moved to the top of the
  /// list with a fresh `lastOpenedAt`. This page stays in the navigator's stack while the
  /// workspace sits on top of it, so nothing else would ever re-read any of that.
  ///
  /// The emitter is checked before it is used again: an app closing while the workspace is on
  /// screen closes this bloc too, and emitting into a closed one throws.
  Future<void> _pushWorkspaceAndRefreshOnReturn(Emitter<OcptHomeState> emitter) async {
    await _routerManager.push(OcptRoute.workspace);

    if (emitter.isDone) {
      return;
    }

    await _onRefreshRequested(const OcptHomeRefreshRequestedEvent(), emitter);
  }

  /// Shows the save-file dialog, creates the new project there, then navigates to the editor.
  Future<void> _onCreateProjectRequested(
    OcptHomeCreateProjectRequestedEvent event,
    Emitter<OcptHomeState> emitter,
  ) async {
    emitter(state.copyWith(isBusy: true, clearError: true));

    final suggestedFileName = "${event.name}.${OcptProjectsManager.projectFileExtension}";
    final filePath = await _fileSaverManager.saveFileFromBytes(
      fileName: suggestedFileName,
      bytes: Uint8List(0),
    );

    if (filePath == null) {
      // The user cancelled the save dialog.
      emitter(state.copyWith(isBusy: false));
      return;
    }

    final result = await _projectsManager.createProject(name: event.name, filePath: filePath);
    if (!result.status.isSuccess) {
      emitter(state.copyWith(isBusy: false, error: result.status));
      return;
    }

    await _onRefreshRequested(const OcptHomeRefreshRequestedEvent(), emitter);
    emitter(state.copyWith(isBusy: false));
    await _pushWorkspaceAndRefreshOnReturn(emitter);
  }

  /// Opens [OcptHomeOpenProjectRequestedEvent.filePath], or shows an open-file dialog first if
  /// it's null, then navigates to the editor.
  ///
  /// Every project file this page opens goes through the compatibility gate first, the picked one
  /// and the tapped card alike: a file from another build stops here, and what the probe found is
  /// raised through the state for the page to state — the migration to confirm, or the refusal to
  /// report. The open itself is only reached for a file this build can take as it is, or for one
  /// the user has just answered the migration question for.
  Future<void> _onOpenProjectRequested(
    OcptHomeOpenProjectRequestedEvent event,
    Emitter<OcptHomeState> emitter,
  ) async {
    emitter(state.copyWith(isBusy: true, clearError: true));

    var filePath = event.filePath;
    if (filePath == null) {
      final selection = await _fileSelectorManager.openSelector(
        allowedExtensions: [OcptProjectsManager.projectFileExtension],
        label: event.fileTypeLabel,
      );

      final selectedFile = selection.value;
      if (!selection.status.isSuccess || selectedFile == null) {
        // The user cancelled the dialog, or the selection failed; the latter is a soft failure
        // deliberately not surfaced as an error, since the OS dialog itself already reported it.
        emitter(state.copyWith(isBusy: false));
        return;
      }

      filePath = selectedFile.path;
    }

    if (!event.allowMigration && _stopsOnFileFormat(filePath, emitter)) {
      return;
    }

    final result = await _projectsManager.openProject(
      filePath: filePath,
      allowMigration: event.allowMigration,
    );
    if (!result.status.isSuccess) {
      emitter(state.copyWith(isBusy: false, error: result.status));
      return;
    }

    await _onRefreshRequested(const OcptHomeRefreshRequestedEvent(), emitter);
    emitter(state.copyWith(isBusy: false));
    await _pushWorkspaceAndRefreshOnReturn(emitter);
  }

  /// Whether opening [filePath] has to stop and be stated to the user first, raising what the
  /// probe found through the state when it does.
  ///
  /// The manager refuses these two verdicts on its own as well, and would report them as statuses:
  /// asking here rather than reacting there is what gets the *numbers* to the dialog — which format
  /// the file is in, which one this build writes, and which build made it — instead of a status
  /// that could only say that something is wrong.
  bool _stopsOnFileFormat(String filePath, Emitter<OcptHomeState> emitter) {
    final compatibility = _projectsManager.probeProjectFile(filePath: filePath);

    switch (compatibility.verdict) {
      case OcptProjectFileVerdict.older:
      case OcptProjectFileVerdict.newer:
        emitter(state.copyWith(isBusy: false, pendingFileCompatibility: compatibility));
        return true;
      case OcptProjectFileVerdict.current:
      case OcptProjectFileVerdict.unreadable:
        return false;
    }
  }

  /// Clears the compatibility verdict the page has just stated, if any.
  Future<void> _onFileCompatibilityStated(
    OcptHomeFileCompatibilityStatedEvent event,
    Emitter<OcptHomeState> emitter,
  ) async {
    emitter(state.copyWith(clearPendingFileCompatibility: true));
  }

  /// Removes a recent project from the list and refreshes it.
  Future<void> _onRemoveRecentProjectRequested(
    OcptHomeRemoveRecentProjectRequestedEvent event,
    Emitter<OcptHomeState> emitter,
  ) async {
    await _propertiesManager.removeRecentProject(event.path);
    await _onRefreshRequested(const OcptHomeRefreshRequestedEvent(), emitter);
  }

  /// Clears the transient error currently shown, if any.
  Future<void> _onErrorDismissed(
    OcptHomeErrorDismissedEvent event,
    Emitter<OcptHomeState> emitter,
  ) async {
    emitter(state.copyWith(clearError: true));
  }

  /// Picks a `.fountain` file, creates a new project for it, imports its text, then navigates to
  /// the editor.
  ///
  /// Mirrors [_onCreateProjectRequested] step for step, with two differences: the save-file
  /// dialog is preceded by an open-file dialog picking the `.fountain` file (its name suggesting
  /// the new project's file name), and the new project's screenplay is seeded with the picked
  /// file's text instead of staying empty.
  Future<void> _onImportScreenplayRequested(
    OcptHomeImportScreenplayRequestedEvent event,
    Emitter<OcptHomeState> emitter,
  ) async {
    emitter(state.copyWith(isBusy: true, clearError: true));

    final imported = await _exportManager.pickAndReadFountain(
      fileTypeLabel: event.fountainFileTypeLabel,
    );
    if (imported == null) {
      // The user cancelled the dialog, or the selection failed; the latter is a soft failure
      // deliberately not surfaced as an error, since the OS dialog itself already reported it.
      emitter(state.copyWith(isBusy: false));
      return;
    }

    final suggestedName = _exportManager.fountainIoService.suggestedProjectName(
      fountainText: imported.fountainText,
      sourceFileName: imported.sourceFileName,
    );
    final suggestedFileName = "$suggestedName.${OcptProjectsManager.projectFileExtension}";
    final filePath = await _fileSaverManager.saveFileFromBytes(
      fileName: suggestedFileName,
      bytes: Uint8List(0),
    );

    if (filePath == null) {
      // The user cancelled the save dialog.
      emitter(state.copyWith(isBusy: false));
      return;
    }

    final projectName = p.basenameWithoutExtension(filePath);
    final result = await _projectsManager.createProject(name: projectName, filePath: filePath);
    if (!result.status.isSuccess) {
      emitter(state.copyWith(isBusy: false, error: result.status));
      return;
    }

    try {
      final project = result.value!;
      await _projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: imported.fountainText,
        snapshotReason: OcptSnapshotReason.import,
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to import a fountain file into the project at "
          "$filePath: $error");
      emitter(state.copyWith(isBusy: false, error: OcptProjectStatus.ioError));
      return;
    }

    await _onRefreshRequested(const OcptHomeRefreshRequestedEvent(), emitter);
    emitter(state.copyWith(isBusy: false));
    await _pushWorkspaceAndRefreshOnReturn(emitter);
  }
}
