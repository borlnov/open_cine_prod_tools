// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';

/// Everything a production mode's bloc needs to host the `Versions` dock tab: listing the
/// project's versions and the working copy's own live state, creating a version, renaming or
/// deleting one, entering or leaving a version's read-only preview, and restoring the project onto
/// one.
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
///
/// A mode also decides for itself *when* the working copy's own card needs a fresh read, by
/// dispatching [OcptProjectWorkingCopyRefreshRequestedEvent]: see that event's own doc comment and
/// [_captureWorkingCopyState]'s for the throttle behind it.
///
/// Every handler that touches the project database runs through [_serialized]: this package's
/// blocs process events concurrently by default, and two of these handlers racing — the initial
/// refresh dispatched on mount, say, against a version operation the user triggers a moment
/// later — would otherwise be free to interleave their own multi-step reads and writes against the
/// very same database.
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

  /// The minimum delay this mixin lets pass between two working-copy captures that
  /// [_onWorkingCopyRefreshRequested] performs, since [OcptProjectsManager.captureWorkingCopyState]
  /// reads the whole project and that handler is dispatched on comparatively frequent events (a
  /// tab reselection, a save). [_emitVersions] never goes through this: every one of its callers
  /// just changed the project, so it always captures the truth through [_captureWorkingCopyState]
  /// directly instead of through the throttled handler.
  static const _workingCopyCaptureThrottle = Duration(seconds: 2);

  /// When the working copy was last captured, or null before the first one. Read and written by
  /// [_captureWorkingCopyState] alone, which is the single primitive both capture paths share.
  DateTime? _lastWorkingCopyCaptureAt;

  /// The tail of every project-touching operation queued through [_serialized] so far.
  Future<void> _pendingOperations = Future.value();

  /// Runs [operation] only once every operation already queued through this has settled, and
  /// queues it in turn — the mixin's own way of making its handlers behave as if events were
  /// processed sequentially, which several of them (see the class doc comment) depend on.
  ///
  /// [_emitVersions] in particular reads the version list and only then captures the working
  /// copy, two separate awaits: without this, a slower, earlier operation's list read could land
  /// in the very same emitted state as a later operation's working-copy capture, pairing data that
  /// never coexisted (a version list from before a version existed, say, next to a working-copy
  /// snapshot measured after it was created).
  ///
  /// A failed [operation] must not leave the queue stuck: whatever already reported the failure (a
  /// notice, a logged error) has done its job, so [_pendingOperations] itself never carries the
  /// error forward — only the [Future] handed back to the caller does.
  Future<void> _serialized(Future<void> Function() operation) {
    final result = _pendingOperations.then((_) => operation());
    _pendingOperations = result.then((_) {}, onError: (_) {});
    return result;
  }

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
    on<OcptProjectVersionRenameRequestedEvent>(_onVersionRenameRequested);
    on<OcptProjectVersionRenameCancelledEvent>(_onVersionRenameCancelled);
    on<OcptProjectVersionRenameConfirmedEvent>(_onVersionRenameConfirmed);
    on<OcptProjectVersionPreviewRequestedEvent>(_onVersionPreviewRequested);
    on<OcptProjectVersionPreviewExitRequestedEvent>(_onVersionPreviewExitRequested);
    on<OcptProjectWorkingCopyRefreshRequestedEvent>(_onWorkingCopyRefreshRequested);
    on<OcptProjectVersionNoticeDismissedEvent>(_onVersionNoticeDismissed);

    add(const OcptProjectVersionsRefreshRequestedEvent());
  }

  /// Reloads the version list and the previewed version's id from the open project.
  Future<void> _onVersionsRefreshRequested(
    OcptProjectVersionsRefreshRequestedEvent event,
    Emitter<S> emitter,
  ) => _serialized(() => _emitVersions(emitter));

  /// Captures the working copy as a new version, then reloads the list so the new card — the
  /// current one from now on — appears at its top.
  ///
  /// Deliberately refused while a version is being previewed: the capture reads the project file
  /// (`OcptOpenProjectModel.fileDatabase`), so it would record a state the user isn't looking at.
  Future<void> _onVersionCreationRequested(
    OcptProjectVersionCreationRequestedEvent event,
    Emitter<S> emitter,
  ) => _serialized(() async {
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
  });

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
        clearVersionPendingRenameId: true,
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
  ) => _serialized(() async {
    try {
      await projectsManager.deleteProjectVersion(event.versionId);
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete the project version "
          "${event.versionId}: $error");
      await _emitVersions(emitter, notice: OcptProjectVersionNoticeKind.deletionFailed);
      return;
    }

    await _emitVersions(emitter);
  });

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
        clearVersionPendingRenameId: true,
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
  /// This is also what the read-only banner's `Start from this version` dispatches when the
  /// version being restored is the one currently previewed:
  /// [OcptProjectsManager.restoreProjectVersion] leaves the preview on its own before it writes
  /// anything, so restoring from inside a preview needs nothing beyond this handler.
  ///
  /// A restore changes both halves of what this mixin shows: the mode's own data — hence
  /// [reloadFromProjectDatabase], exactly as after a preview — and the version *list* itself, which
  /// gains the safety version taken on the way (when the working copy actually differed from its
  /// base) and moves its `Base` badge. So unlike the preview handlers, this one ends on
  /// [_emitVersions] too.
  ///
  /// The pending write is flushed first for the same reason a preview flushes it: what the mode
  /// still holds in a debounce belongs to the state being replaced, and a restore is precisely the
  /// moment it would otherwise land in a project it was never typed into.
  Future<void> _onVersionRestoreConfirmed(
    OcptProjectVersionRestoreConfirmedEvent event,
    Emitter<S> emitter,
  ) => _serialized(() async {
    await flushPendingProjectWrites(emitter);

    final status = await projectsManager.restoreProjectVersion(
      versionId: event.versionId,
      safetyVersionName: event.safetyVersionName,
    );

    if (!status.isSuccess) {
      await _emitVersions(emitter, notice: _noticeForRestoreStatus(status));
      return;
    }

    await reloadFromProjectDatabase(emitter);
    await _emitVersions(emitter);
  });

  /// Shows the inline rename form of one card, replacing whichever answer any card was already
  /// asking for.
  Future<void> _onVersionRenameRequested(
    OcptProjectVersionRenameRequestedEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(
      state.copyProjectVersionsState(
        versionPendingRenameId: event.versionId,
        clearVersionPendingDeletionId: true,
        clearVersionPendingRestoreId: true,
      ),
    );
  }

  /// Hides the inline rename form currently shown.
  Future<void> _onVersionRenameCancelled(
    OcptProjectVersionRenameCancelledEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(state.copyProjectVersionsState(clearVersionPendingRenameId: true));
  }

  /// Renames a version's name and note, then reloads the list so its card reads the new ones.
  ///
  /// The rename form is cleared whatever happens, exactly as a delete's confirmation is: a failed
  /// rename leaves the card there, but not stuck on a form the user already submitted.
  Future<void> _onVersionRenameConfirmed(
    OcptProjectVersionRenameConfirmedEvent event,
    Emitter<S> emitter,
  ) => _serialized(() async {
    try {
      await projectsManager.renameProjectVersion(
        versionId: event.versionId,
        name: event.name,
        note: event.note,
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to rename the project version "
          "${event.versionId}: $error");
      await _emitVersions(emitter, notice: OcptProjectVersionNoticeKind.renameFailed);
      return;
    }

    await _emitVersions(emitter);
  });

  /// Enters the read-only preview of a version: flushes whatever the mode still holds, asks the
  /// manager to swap the database, then reloads everything the mode shows from it.
  ///
  /// A failed preview leaves the working copy on screen (the manager guarantees it) and reports
  /// why through a notice. A successful one clears [MixinOcptProjectVersionsState.workingCopy]
  /// outright rather than capturing it: `OcptProjectsManager.captureWorkingCopyState` already
  /// answers null while a preview is up (it would otherwise read a state the user isn't looking
  /// at), so there is nothing a capture here would add over simply saying so.
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
  ///
  /// [MixinOcptProjectVersionsState.workingCopy] is cleared *before* [reloadFromProjectDatabase]
  /// runs rather than after: the hook's own `copyWith` knows nothing about this field, so whatever
  /// it already held would otherwise survive untouched into the very state that reports the
  /// preview — one frame showing a stale working copy alongside a version's data, exactly the kind
  /// of tear this mixin exists to avoid. Clearing it first means that state, once emitted, simply
  /// carries the null this already left behind.
  Future<void> _onVersionPreviewRequested(
    OcptProjectVersionPreviewRequestedEvent event,
    Emitter<S> emitter,
  ) => _serialized(() async {
    await flushPendingProjectWrites(emitter);

    final result = await projectsManager.previewVersion(event.versionId);
    if (!result.status.isSuccess) {
      await _emitVersions(emitter, notice: _noticeForPreviewStatus(result.status));
      return;
    }

    emitter(state.copyProjectVersionsState(clearWorkingCopy: true));
    await reloadFromProjectDatabase(emitter);
    emitter(state.copyProjectVersionsState(clearVersionPendingDeletionId: true));
  });

  /// Leaves the read-only preview and reloads everything the mode shows from the working copy.
  ///
  /// The working copy is captured again on the way, unthrottled: entering the preview cleared it,
  /// and nothing else would put it back — the tab showing its card is already the selected one, so
  /// no reselection is coming to ask for it. It is emitted *before* [reloadFromProjectDatabase]
  /// rather than after, for the mirror image of the reason the preview clears it first: emitted
  /// after, the reload's own state would carry a null working copy out of the preview and show one
  /// frame of an empty card. Emitted before, the only frame that pairs a captured working copy with
  /// a preview still marked as up is one whose card is hidden anyway.
  ///
  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadCarriesThePreview}
  Future<void> _onVersionPreviewExitRequested(
    OcptProjectVersionPreviewExitRequestedEvent event,
    Emitter<S> emitter,
  ) => _serialized(() async {
    await projectsManager.exitPreview();

    final workingCopy = await _captureWorkingCopyState();
    emitter(
      state.copyProjectVersionsState(
        workingCopy: workingCopy,
        clearWorkingCopy: workingCopy == null,
      ),
    );

    await reloadFromProjectDatabase(emitter);
    emitter(state.copyProjectVersionsState(clearVersionPendingDeletionId: true));
  });

  /// Clears the transient version notice currently shown, if any.
  Future<void> _onVersionNoticeDismissed(
    OcptProjectVersionNoticeDismissedEvent event,
    Emitter<S> emitter,
  ) async {
    emitter(state.copyProjectVersionsState(clearProjectVersionNotice: true));
  }

  /// Emits the version list, the previewed version's id and a fresh working-copy capture as the
  /// project now holds them, optionally alongside [notice].
  ///
  /// Every handler that actually changes the project ends here, so the panel is redrawn from the
  /// project file rather than from what the handler believes it did — a deletion that silently did
  /// nothing (the previewed version, which the manager refuses to delete) leaves its card exactly
  /// where it was. The working-copy capture always goes through [_captureWorkingCopyState]
  /// directly, never through the throttle [_onWorkingCopyRefreshRequested] applies: every caller
  /// here just changed the project (or, for the initial refresh on mount, has nothing yet to serve
  /// a stale value from), so it must show the truth rather than something up to 2 s old.
  ///
  /// A read failing here — most often because the project closed (the user navigating back, say)
  /// while this was still queued behind an earlier operation — is swallowed rather than left to
  /// escape as an unhandled error: there is nothing left worth emitting into a bloc that is itself
  /// on its way out, and every caller already reports its own failures through [notice] before
  /// ever reaching this.
  Future<void> _emitVersions(Emitter<S> emitter, {OcptProjectVersionNoticeKind? notice}) async {
    try {
      final versions = await projectsManager.listProjectVersions();
      final previewedVersionId = projectsManager.currentProject?.previewedVersion?.id;
      final workingCopy = await _captureWorkingCopyState();

      emitter(
        state.copyProjectVersionsState(
          projectVersions: versions,
          previewedVersionId: previewedVersionId,
          clearPreviewedVersionId: previewedVersionId == null,
          workingCopy: workingCopy,
          clearWorkingCopy: workingCopy == null,
          clearVersionPendingDeletionId: true,
          clearVersionPendingRestoreId: true,
          clearVersionPendingRenameId: true,
          projectVersionNotice: notice,
          clearProjectVersionNotice: notice == null,
        ),
      );
    } catch (error) {
      appLogger().w("A problem occurred when tried to read the project's versions, most likely "
          "because the project already closed: $error");
    }
  }

  /// Captures the working copy's live state through
  /// [OcptProjectsManager.captureWorkingCopyState], recording when it did so
  /// [_onWorkingCopyRefreshRequested]'s throttle has something to measure against.
  ///
  /// The one primitive both capture paths share: [_emitVersions] calls it directly and
  /// unconditionally, while [_onWorkingCopyRefreshRequested] only reaches it once its own throttle
  /// has let [_workingCopyCaptureThrottle] pass since the timestamp this leaves behind. Null while
  /// no project is open or a version is being previewed, exactly as the manager method itself
  /// documents.
  ///
  /// Only a capture that actually read the project leaves that timestamp behind: the manager
  /// answers the other two cases without touching the file, so there is nothing to throttle, and
  /// stamping them would make the first real capture after a preview wait out a window nothing
  /// ever paid for.
  Future<OcptProjectWorkingCopyState?> _captureWorkingCopyState() async {
    final workingCopy = await projectsManager.captureWorkingCopyState();

    if (workingCopy != null) {
      _lastWorkingCopyCaptureAt = DateTime.now();
    }

    return workingCopy;
  }

  /// Refreshes the working copy's own card alone, throttled to at most one real capture every
  /// [_workingCopyCaptureThrottle]: dispatched on a tab reselection or a save (see the mixin's own
  /// doc comment for exactly where each mode dispatches it), both of which can happen far more often
  /// than the whole-project read behind [OcptProjectsManager.captureWorkingCopyState] should run.
  ///
  /// A dispatch that lands inside the throttle window is a silent no-op — nothing is emitted, so
  /// the state already showing what the last capture found is never replaced by a second,
  /// independently-read value that happens to describe the exact same instant differently. A read
  /// failing for any other reason is swallowed exactly as [_emitVersions]'s own is, for the same
  /// reason given there.
  Future<void> _onWorkingCopyRefreshRequested(
    OcptProjectWorkingCopyRefreshRequestedEvent event,
    Emitter<S> emitter,
  ) => _serialized(() async {
    final lastCaptureAt = _lastWorkingCopyCaptureAt;
    if (lastCaptureAt != null &&
        DateTime.now().difference(lastCaptureAt) < _workingCopyCaptureThrottle) {
      return;
    }

    try {
      final workingCopy = await _captureWorkingCopyState();
      emitter(
        state.copyProjectVersionsState(
          workingCopy: workingCopy,
          clearWorkingCopy: workingCopy == null,
        ),
      );
    } catch (error) {
      appLogger().w("A problem occurred when tried to refresh the working copy, most likely "
          "because the project already closed: $error");
    }
  });

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
