// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';

/// Everything a production mode's bloc needs to host the `Versions` dock tab: listing the
/// project's versions, creating one, deleting one, entering or leaving a version's read-only
/// preview, and putting the project back on one — by restoring it, or by starting a new branch
/// from it.
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
  ///
  /// It must emit [MixinOcptProjectVersionsState.previewedVersionId] — read from
  /// `OcptProjectsManager.currentProject`, the source of truth — in the very same state as the data
  /// it just read, since that data comes from whichever database the id names. Emitting the two
  /// separately would leave one frame showing a version's content with every editing affordance of
  /// the working copy still on it.
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
    on<OcptProjectVersionRestoreRequestedEvent>(_onVersionRestoreRequested);
    on<OcptProjectVersionRestoreCancelledEvent>(_onVersionRestoreCancelled);
    on<OcptProjectVersionRestoreConfirmedEvent>(_onVersionRestoreConfirmed);
    on<OcptProjectVersionForkRequestedEvent>(_onVersionForkRequested);
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

  /// Shows the inline delete confirmation of one card, replacing whichever answer any card was
  /// already asking for.
  Future<void> _onVersionDeletionRequested(
    OcptProjectVersionDeletionRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(
      state.copyProjectVersionsState(
        versionPendingDeletionId: event.versionId,
        clearVersionPendingRestoreId: true,
      ),
    );
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

  /// Shows the inline restore confirmation of one card, replacing whichever answer any card was
  /// already asking for.
  Future<void> _onVersionRestoreRequested(
    OcptProjectVersionRestoreRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(
      state.copyProjectVersionsState(
        versionPendingRestoreId: event.versionId,
        clearVersionPendingDeletionId: true,
      ),
    );
  }

  /// Hides the inline restore confirmation currently shown.
  Future<void> _onVersionRestoreCancelled(
    OcptProjectVersionRestoreCancelledEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(state.copyProjectVersionsState(clearVersionPendingRestoreId: true));
  }

  /// Puts the whole project back into the state a version holds, then reloads everything the mode
  /// shows from the restored working copy.
  ///
  /// {@template open_cine_prod_tools.MixinOcptProjectVersionsBloc.restoreReloadsEverything}
  /// A restore changes both halves of what this mixin shows: the mode's own data — hence the
  /// [reloadFromProjectDatabase], exactly as after a preview — and the version *list* itself, which
  /// gains the safety version taken on the way and moves its `Current` badge. So unlike the preview
  /// handlers, this one ends on [_emitVersions] too.
  ///
  /// The pending write is flushed first for the same reason a preview flushes it: what the mode
  /// still holds in a debounce belongs to the state being replaced, and a restore is precisely the
  /// moment it would otherwise land in a project it was never typed into.
  /// {@endtemplate}
  Future<void> _onVersionRestoreConfirmed(
    OcptProjectVersionRestoreConfirmedEvent event,
    Emitter<S> emitter,
  ) async {
    await flushPendingProjectWrites(emitter);

    final status = await projectsManager.restoreProjectVersion(
      versionId: event.versionId,
      safetyVersionName: event.safetyVersionName,
    );

    await _applyRestoreOutcome(status, emitter);
  }

  /// Starts a new branch from a version: restores it, then marks the branch point with a version of
  /// its own.
  ///
  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.restoreReloadsEverything}
  Future<void> _onVersionForkRequested(
    OcptProjectVersionForkRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    await flushPendingProjectWrites(emitter);

    final status = await projectsManager.forkProjectVersion(
      versionId: event.versionId,
      safetyVersionName: event.safetyVersionName,
      forkName: event.forkName,
      // The branch point is named, never described: what it is a branch from is the whole of what
      // there is to say about it, and the name already says it.
      forkNote: "",
    );

    await _applyRestoreOutcome(status, emitter);
  }

  /// Reports [status] to the mode: on success by reloading what it shows and the version list, on
  /// failure by a notice alone — a refused restore leaves the project exactly as it was, so there
  /// is nothing to reload.
  Future<void> _applyRestoreOutcome(OcptProjectRestoreStatus status, Emitter<S> emitter) async {
    if (!status.isSuccess) {
      await _emitVersions(emitter, notice: _noticeForRestoreStatus(status));
      return;
    }

    await reloadFromProjectDatabase(emitter);
    await _emitVersions(emitter);
  }

  /// Enters the read-only preview of a version: flushes whatever the mode still holds, asks the
  /// manager to swap the database, then reloads everything the mode shows from it.
  ///
  /// A failed preview leaves the working copy on screen (the manager guarantees it) and reports
  /// why through a notice.
  ///
  /// {@template open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadCarriesThePreview}
  /// [reloadFromProjectDatabase] is what emits the version's own data, and it emits the preview
  /// state along with it (both being read from `OcptProjectsManager.currentProject`, see the hook's
  /// own doc comment): the two must land in the *same* state, or the mode would draw one frame of a
  /// version's data with every editing affordance still on it.
  ///
  /// Which is also why neither of these two handlers ends on [_emitVersions], unlike every other
  /// one here: entering or leaving a preview changes nothing about the version *list* — it is read
  /// from the project file, which a preview never touches — so re-reading it would only add a
  /// second, later emission that could land after whatever the user did next.
  /// {@endtemplate}
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
    emitter(state.copyProjectVersionsState(clearVersionPendingDeletionId: true));
  }

  /// Leaves the read-only preview and reloads everything the mode shows from the working copy.
  ///
  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadCarriesThePreview}
  Future<void> _onVersionPreviewExitRequested(
    OcptProjectVersionPreviewExitRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    await projectsManager.exitPreview();

    await reloadFromProjectDatabase(emitter);
    emitter(state.copyProjectVersionsState(clearVersionPendingDeletionId: true));
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
        clearVersionPendingRestoreId: true,
        projectVersionNotice: notice,
        clearProjectVersionNotice: notice == null,
      ),
    );
  }

  /// The notice reporting the failed restore [status] to the user.
  ///
  /// [OcptProjectRestoreStatus.noProjectOpen] and [OcptProjectRestoreStatus.versionNotFound] read
  /// as the generic failure, for the reason [_noticeForPreviewStatus] gives about its own two.
  OcptProjectVersionNoticeKind _noticeForRestoreStatus(OcptProjectRestoreStatus status) =>
      switch (status) {
        OcptProjectRestoreStatus.unsupportedFutureFormat =>
          OcptProjectVersionNoticeKind.restoreUnsupportedFormat,
        _ => OcptProjectVersionNoticeKind.restoreFailed,
      };

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
