// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';

/// Everything a production mode's bloc needs to host the `Versions` dock tab: listing the
/// project's versions, creating one, deleting one, and entering or leaving a version's read-only
/// preview.
///
/// A version covers the whole project rather than any one mode's data, so this is deliberately a
/// mixin (the `MixinActThemesBloc` idiom) rather than a bloc of its own or a copy in each mode:
/// the panel dispatches the same events and reads the same state fields whichever dock it is shown
/// in, and a new production mode gets the tab by mixing this in and answering the two hooks below.
///
/// Those two hooks are what the mixin cannot know:
///
/// - [flushPendingProjectWrites] — entering a preview swaps the database every edit is written
///   through, so anything the mode still holds in a debounce must reach the working copy *first*
///   or it would land in the previewed version's in-memory database and be lost with it. Only the
///   mode knows what it is holding.
/// - [reloadFromProjectDatabase] — entering or leaving a preview replaces
///   `OcptOpenProjectModel.database`, and what a mode shows has to be read again from it. Only the
///   mode knows what "everything I show" is.
mixin MixinOcptProjectVersionsBloc<S extends MixinOcptProjectVersionsState<S>> on BlocForMixin<S> {
  /// {@template open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  /// The manager owning the open project, its version list and the preview state.
  ///
  /// Declared here and implemented by each mode's bloc, rather than resolved through [globalGetIt]
  /// by the mixin itself, so a bloc built with an explicitly injected manager (which is what every
  /// test does) has this mixin work against that same instance.
  /// {@endtemplate}
  @protected
  OcptProjectsManager get projectsManager;

  /// Writes whatever the mode still holds outside the database — a pending autosave, a debounced
  /// field edit — before a preview swaps that database out from under it.
  ///
  /// Called with the current handler's [emitter], so the mode can report the write through its own
  /// state exactly as it would for a user-triggered save.
  @protected
  Future<void> flushPendingProjectWrites(Emitter<S> emitter);

  /// {@template open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  /// Reads everything the mode shows from `OcptOpenProjectModel.database` again, after entering or
  /// leaving a preview replaced it.
  ///
  /// Normally the mode's own load handler, called directly with the current handler's `emitter`.
  /// {@endtemplate}
  @protected
  Future<void> reloadFromProjectDatabase(Emitter<S> emitter);

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  ///
  /// The initial refresh is dispatched from here rather than left to each mode's constructor, so a
  /// mode never has to remember to populate the panel it hosts.
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();

    on<OcptProjectVersionsRefreshRequestedEvent>(_onVersionsRefreshRequested);
    on<OcptProjectVersionCreationRequestedEvent>(_onVersionCreationRequested);
    on<OcptProjectVersionDeletionRequestedEvent>(_onVersionDeletionRequested);
    on<OcptProjectVersionDeletionCancelledEvent>(_onVersionDeletionCancelled);
    on<OcptProjectVersionDeletionConfirmedEvent>(_onVersionDeletionConfirmed);
    on<OcptProjectVersionPreviewRequestedEvent>(_onVersionPreviewRequested);
    on<OcptProjectVersionPreviewExitRequestedEvent>(_onVersionPreviewExitRequested);
    on<OcptProjectVersionNoticeDismissedEvent>(_onVersionNoticeDismissed);

    add(const OcptProjectVersionsRefreshRequestedEvent());
  }

  /// Reloads the version list and the previewed version's id from the open project.
  Future<void> _onVersionsRefreshRequested(
    OcptProjectVersionsRefreshRequestedEvent event,
    Emitter<S> emitter,
  ) => _emitVersions(emitter);

  /// Captures the working copy as a new version, then reloads the list so the new card — the
  /// current one from now on — appears at its top.
  ///
  /// Deliberately refused while a version is being previewed: the capture reads the project file
  /// (`OcptOpenProjectModel.fileDatabase`), so it would record a state the user isn't looking at.
  Future<void> _onVersionCreationRequested(
    OcptProjectVersionCreationRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    if (state.isPreviewingVersion) {
      appLogger().w("A project version can't be created while another one is being previewed: the "
          "capture would record the working copy rather than what is on screen");
      return;
    }

    await flushPendingProjectWrites(emitter);

    try {
      await projectsManager.createProjectVersion(name: event.name, note: event.note);
    } catch (error) {
      appLogger().e("A problem occurred when tried to create the project version "
          "'${event.name}': $error");
      await _emitVersions(emitter, notice: OcptProjectVersionNoticeKind.creationFailed);
      return;
    }

    await _emitVersions(emitter);
  }

  /// Shows the inline delete confirmation of one card, replacing whichever one was already
  /// showing.
  Future<void> _onVersionDeletionRequested(
    OcptProjectVersionDeletionRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(state.copyProjectVersionsState(versionPendingDeletionId: event.versionId));
  }

  /// Hides the inline delete confirmation currently shown.
  Future<void> _onVersionDeletionCancelled(
    OcptProjectVersionDeletionCancelledEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(state.copyProjectVersionsState(clearVersionPendingDeletionId: true));
  }

  /// Deletes a version for good, then reloads the list.
  ///
  /// The confirmation is cleared whatever happens: a failed deletion leaves the card there, but
  /// not stuck on a confirmation the user already answered.
  Future<void> _onVersionDeletionConfirmed(
    OcptProjectVersionDeletionConfirmedEvent event,
    Emitter<S> emitter,
  ) async {
    try {
      await projectsManager.deleteProjectVersion(event.versionId);
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete the project version "
          "${event.versionId}: $error");
      await _emitVersions(emitter, notice: OcptProjectVersionNoticeKind.deletionFailed);
      return;
    }

    await _emitVersions(emitter);
  }

  /// Enters the read-only preview of a version: flushes whatever the mode still holds, asks the
  /// manager to swap the database, then reloads everything the mode shows from it.
  ///
  /// A failed preview leaves the working copy on screen (the manager guarantees it) and reports
  /// why through a notice.
  Future<void> _onVersionPreviewRequested(
    OcptProjectVersionPreviewRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    await flushPendingProjectWrites(emitter);

    final result = await projectsManager.previewVersion(event.versionId);
    if (!result.status.isSuccess) {
      await _emitVersions(emitter, notice: _noticeForPreviewStatus(result.status));
      return;
    }

    await reloadFromProjectDatabase(emitter);
    await _emitVersions(emitter);
  }

  /// Leaves the read-only preview and reloads everything the mode shows from the working copy.
  Future<void> _onVersionPreviewExitRequested(
    OcptProjectVersionPreviewExitRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    await projectsManager.exitPreview();

    await reloadFromProjectDatabase(emitter);
    await _emitVersions(emitter);
  }

  /// Clears the transient version notice currently shown, if any.
  Future<void> _onVersionNoticeDismissed(
    OcptProjectVersionNoticeDismissedEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(state.copyProjectVersionsState(clearProjectVersionNotice: true));
  }

  /// Emits the version list and the previewed version's id as the project now holds them,
  /// optionally alongside [notice].
  ///
  /// Every handler ends here, so the panel is redrawn from the project file rather than from what
  /// the handler believes it did — a deletion that silently did nothing (the previewed version,
  /// which the manager refuses to delete) leaves its card exactly where it was.
  Future<void> _emitVersions(Emitter<S> emitter, {OcptProjectVersionNoticeKind? notice}) async {
    final versions = await projectsManager.listProjectVersions();
    final previewedVersionId = projectsManager.currentProject?.previewedVersion?.id;

    emitter(
      state.copyProjectVersionsState(
        projectVersions: versions,
        previewedVersionId: previewedVersionId,
        clearPreviewedVersionId: previewedVersionId == null,
        clearVersionPendingDeletionId: true,
        projectVersionNotice: notice,
        clearProjectVersionNotice: notice == null,
      ),
    );
  }

  /// The notice reporting the failed preview [status] to the user.
  ///
  /// [OcptProjectPreviewStatus.noProjectOpen] and [OcptProjectPreviewStatus.versionNotFound] can
  /// only happen when the panel is showing a project or a version that is already gone, which the
  /// refresh ending every handler resolves on its own: they read as the generic failure rather
  /// than earning a message of their own.
  OcptProjectVersionNoticeKind _noticeForPreviewStatus(OcptProjectPreviewStatus status) =>
      switch (status) {
        OcptProjectPreviewStatus.unsavedChanges =>
          OcptProjectVersionNoticeKind.previewBlockedByUnsavedChanges,
        OcptProjectPreviewStatus.unsupportedFutureFormat =>
          OcptProjectVersionNoticeKind.previewUnsupportedFormat,
        _ => OcptProjectVersionNoticeKind.previewFailed,
      };
}
