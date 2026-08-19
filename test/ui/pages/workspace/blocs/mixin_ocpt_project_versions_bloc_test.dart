// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] does nothing: these tests never leave the workspace, and no real
/// GoRouter is built for it to operate on.
class _SilentRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A projects manager whose [renameProjectVersion] always fails, to exercise the bloc's rename
/// failure path.
class _FailingRenameProjectsManager extends OcptProjectsManager {
  /// Class constructor
  _FailingRenameProjectsManager({required OcptPropertiesManager propertiesManager})
    : super(propertiesManager: propertiesManager);

  @override
  Future<void> renameProjectVersion({
    required String versionId,
    required String name,
    required String note,
  }) async => throw StateError("rename intentionally failed for the test");
}

/// A projects manager that counts how many times a working-copy capture actually reads the whole
/// project, so the mixin's throttle can be measured without depending on real wall-clock gaps
/// between assertions.
class _CountingProjectsManager extends OcptProjectsManager {
  /// Class constructor
  _CountingProjectsManager({required OcptPropertiesManager propertiesManager})
    : super(propertiesManager: propertiesManager);

  /// How many times [captureWorkingCopyState] actually ran, as opposed to being skipped by the
  /// mixin's throttle before ever reaching here.
  int captureCount = 0;

  @override
  Future<OcptProjectWorkingCopyState?> captureWorkingCopyState() async {
    captureCount++;
    return super.captureWorkingCopyState();
  }
}

/// The versions dock tab, exercised through `OcptEditorBloc` — one of the two blocs mixing
/// `MixinOcptProjectVersionsBloc` in.
///
/// The screenplay mode is the one used here because it is the mode that holds unsaved text between
/// two writes, which is what makes the "flush before previewing" hook of the mixin observable: the
/// mixin's behaviour itself is the same in every mode.
/// The miniature hunspell pair this file's spell-check manager stands the two ~1 MB bundled
/// dictionaries up with — `OcptEditorBloc` resolves that manager and asks it to load the open
/// project's language, and parsing a real dictionary in an isolate would cost far more than
/// anything this file actually asserts on.
Future<String> _loadMiniatureDictionaryAsset(String assetKey) async =>
    assetKey.endsWith(".aff") ? "SET UTF-8\n" : "2\nthe\nscene\n";

void main() {
  const firstText = "INT. HOUSE - DAY\n\nAction one.\n";
  const secondText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the mixin's failure paths)
    // resolvable; the bloc's own dependencies are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_versions_bloc_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds a bloc wired to the test project, with debounces short enough to await in a test.
  /// [overrideProjectsManager] lets a test swap in a manager of its own (already holding an open
  /// project), for the tests that need to observe or fail one of its calls.
  OcptEditorBloc buildBloc({OcptProjectsManager? overrideProjectsManager}) => OcptEditorBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _SilentRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    spellCheckManager: OcptSpellCheckManager(loadAsset: _loadMiniatureDictionaryAsset),
    parseDebounce: const Duration(milliseconds: 20),
    autosaveDebounce: const Duration(seconds: 30),
    statisticsDebounce: const Duration(milliseconds: 30),
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptEditorState> waitForState(
    OcptEditorBloc bloc,
    bool Function(OcptEditorState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Writes [text] as the project's screenplay, straight through the service, bypassing the bloc.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  test('a project with no version starts with an empty list', () async {
    final bloc = buildBloc();
    // The mixin's own initial refresh is a second, independently-processed handler dispatched
    // alongside the editor's own load: waiting for `workingCopy` too, not only `!isLoading`, is
    // what guarantees it has actually landed before the test closes the bloc out from under it.
    await waitForState(bloc, (state) => !state.isLoading && state.workingCopy != null);

    expect(bloc.state.projectVersions, isEmpty);
    expect(bloc.state.isPreviewingVersion, isFalse);

    await bloc.close();
  });

  test('creating a version lists it as the current one', () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptProjectVersionCreationRequestedEvent(name: "v1", note: "First cut"),
    );
    final state = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);

    expect(state.projectVersions, hasLength(1));
    expect(state.projectVersions.single.name, "v1");
    expect(state.projectVersions.single.note, "First cut");
    expect(state.projectVersions.single.isBase, isTrue);
    expect(state.projectVersions.single.summary.pageCount, 1);

    await bloc.close();
  });

  test('deleting a version confirms inline first, then drops it', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    bloc.add(OcptProjectVersionDeletionRequestedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.versionPendingDeletionId == versionId);

    // Cancelling leaves the version alone.
    bloc.add(const OcptProjectVersionDeletionCancelledEvent());
    final cancelled = await waitForState(bloc, (state) => state.versionPendingDeletionId == null);
    expect(cancelled.projectVersions, hasLength(1));

    bloc.add(OcptProjectVersionDeletionConfirmedEvent(versionId: versionId));
    final deleted = await waitForState(bloc, (state) => state.projectVersions.isEmpty);
    expect(deleted.versionPendingDeletionId, isNull);

    await bloc.close();
  });

  test('renaming a version shows its form inline first, then updates its name and note',
      () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: "First cut"));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    bloc.add(OcptProjectVersionRenameRequestedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.versionPendingRenameId == versionId);

    // Cancelling leaves the version alone.
    bloc.add(const OcptProjectVersionRenameCancelledEvent());
    final cancelled = await waitForState(bloc, (state) => state.versionPendingRenameId == null);
    expect(cancelled.projectVersions.single.name, "v1");

    bloc.add(
      OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: "v1 bis", note: "Renamed"),
    );
    final renamed = await waitForState(
      bloc,
      (state) => state.projectVersions.length == 1 && state.projectVersions.single.name == "v1 bis",
    );
    expect(renamed.projectVersions.single.note, "Renamed");
    expect(renamed.versionPendingRenameId, isNull);

    await bloc.close();
  });

  test('a failing rename reports it and leaves the version alone', () async {
    final failingManager = _FailingRenameProjectsManager(propertiesManager: propertiesManager);
    await failingManager.initLifeCycle();
    final created = await failingManager.createProject(
      name: "Failing Movie",
      filePath: p.join(tempDir.path, "failing.ocpt"),
    );
    expect(created.status.isSuccess, isTrue);
    await failingManager.createProjectVersion(name: "v1", note: "");

    final bloc = buildBloc(overrideProjectsManager: failingManager);
    await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = bloc.state.projectVersions.single.id;

    bloc.add(
      OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: "v1 bis", note: ""),
    );
    final state = await waitForState(bloc, (state) => state.projectVersionNotice != null);

    expect(state.projectVersionNotice, OcptProjectVersionNoticeKind.renameFailed);
    expect(state.projectVersions.single.name, "v1");

    await bloc.close();
    await failingManager.disposeLifeCycle();
  });

  test('the delete, restore and rename inline modes exclude each other', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    bloc.add(OcptProjectVersionDeletionRequestedEvent(versionId: versionId));
    var state = await waitForState(bloc, (state) => state.versionPendingDeletionId == versionId);
    expect(state.versionPendingRestoreId, isNull);
    expect(state.versionPendingRenameId, isNull);

    bloc.add(OcptProjectVersionRestoreRequestedEvent(versionId: versionId));
    state = await waitForState(bloc, (state) => state.versionPendingRestoreId == versionId);
    expect(state.versionPendingDeletionId, isNull);
    expect(state.versionPendingRenameId, isNull);

    bloc.add(OcptProjectVersionRenameRequestedEvent(versionId: versionId));
    state = await waitForState(bloc, (state) => state.versionPendingRenameId == versionId);
    expect(state.versionPendingDeletionId, isNull);
    expect(state.versionPendingRestoreId, isNull);

    bloc.add(OcptProjectVersionDeletionRequestedEvent(versionId: versionId));
    state = await waitForState(bloc, (state) => state.versionPendingDeletionId == versionId);
    expect(state.versionPendingRenameId, isNull);

    await bloc.close();
  });

  test('previewing a version shows its screenplay, and leaving it brings the working copy back',
      () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    // The screenplay moves on, outside the bloc, so the working copy and the version differ.
    await writeScreenplay(secondText);
    bloc.add(const OcptEditorLoadRequestedEvent());
    await waitForState(bloc, (state) => state.text == secondText);

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    final previewing = await waitForState(bloc, (state) => state.previewedVersionId != null);

    expect(previewing.previewedVersionId, versionId);
    expect(previewing.isPreviewingVersion, isTrue);
    expect(previewing.text, firstText);
    expect(projectsManager.currentProject!.isReadOnly, isTrue);

    bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
    final exited = await waitForState(bloc, (state) => state.previewedVersionId == null);

    expect(exited.text, secondText);
    expect(projectsManager.currentProject!.isReadOnly, isFalse);

    await bloc.close();
  });

  test("no emitted state ever carries a version's data without saying it is a preview", () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: "First cut"));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    await writeScreenplay(secondText);
    bloc.add(const OcptEditorLoadRequestedEvent());
    await waitForState(bloc, (state) => state.text == secondText);

    // Every state the preview and its exit go through, so the read-only flag can be checked
    // against what each of them shows rather than only against the last one: a mode drawing one
    // frame of a version's data with its editing affordances still on would be invisible
    // otherwise.
    final emitted = <OcptEditorState>[];
    final subscription = bloc.stream.listen(emitted.add);

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.previewedVersionId != null);
    bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
    await waitForState(bloc, (state) => state.previewedVersionId == null && state.text == secondText);

    await subscription.cancel();

    for (final state in emitted) {
      expect(
        state.text == firstText,
        state.isPreviewingVersion,
        reason: "a state showing '${state.text}' reported isPreviewingVersion="
            "${state.isPreviewingVersion}",
      );
    }

    // The previewed version is resolved from the list the panel is drawn from, so the banner can
    // name it without a second copy of the row.
    expect(emitted.firstWhere((state) => state.isPreviewingVersion).previewedVersion?.name, "v1");

    await bloc.close();
  });

  test('previewing flushes the unsaved screenplay into the working copy first', () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    // Typed but never saved: the autosave debounce is 30 s here, so nothing reached the database.
    bloc.add(const OcptEditorTextChangedEvent(text: secondText));
    await waitForState(bloc, (state) => state.isDirty);

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    final previewing = await waitForState(bloc, (state) => state.previewedVersionId != null);

    expect(previewing.isDirty, isFalse);
    expect(previewing.projectVersionNotice, isNull);
    expect(previewing.text, firstText);

    bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
    final exited = await waitForState(bloc, (state) => state.previewedVersionId == null);

    // The text typed before entering the preview reached the project file rather than the
    // version's in-memory database, so it is still there afterwards.
    expect(exited.text, secondText);

    await bloc.close();
  });

  test('a version can neither be created nor deleted while it is the one being previewed',
      () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.previewedVersionId != null);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v2", note: ""));
    bloc.add(OcptProjectVersionDeletionConfirmedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.versionPendingDeletionId == null);

    expect(bloc.state.projectVersions, hasLength(1));
    expect(bloc.state.projectVersions.single.id, versionId);

    await bloc.close();
  });

  test('restoring a version confirms inline, then puts the project back on it', () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    await writeScreenplay(secondText);
    bloc.add(const OcptEditorLoadRequestedEvent());
    await waitForState(bloc, (state) => state.text == secondText);

    // Asking only opens the card's own confirmation: nothing is written yet.
    bloc.add(OcptProjectVersionRestoreRequestedEvent(versionId: versionId));
    final asking = await waitForState(bloc, (state) => state.versionPendingRestoreId != null);
    expect(asking.versionPendingRestoreId, versionId);
    expect(asking.text, secondText);

    bloc.add(const OcptProjectVersionRestoreCancelledEvent());
    final cancelled = await waitForState(bloc, (state) => state.versionPendingRestoreId == null);
    expect(cancelled.text, secondText);

    bloc.add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: versionId,
        safetyVersionName: "Before restoring v1",
      ),
    );
    // The mode's own data and the version list are read back one after the other, so the state
    // this waits for is the second of the two: the list is what the restore changed last.
    final restored = await waitForState(
      bloc,
      (state) => state.projectVersions.any((version) => version.name == "Before restoring v1"),
    );

    // The mode shows the version's own state, and the list has caught up with what the restore did
    // to it: the state it replaced is a card of its own, and the `Current` badge has moved.
    expect(restored.text, firstText);
    expect(
      restored.projectVersions.singleWhere((version) => version.id == versionId).isBase,
      isTrue,
    );
    expect(restored.versionPendingRestoreId, isNull);
    expect(restored.projectVersionNotice, isNull);

    await bloc.close();
  });

  test('restoring flushes the unsaved screenplay into the state it is about to replace', () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    // Typed but never saved: the autosave debounce is 30 s here, so nothing reached the database.
    bloc.add(const OcptEditorTextChangedEvent(text: secondText));
    await waitForState(bloc, (state) => state.isDirty);

    bloc.add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: versionId,
        safetyVersionName: "Before restoring v1",
      ),
    );
    final restored = await waitForState(
      bloc,
      (state) => state.projectVersions.any((version) => version.name == "Before restoring v1"),
    );
    expect(restored.text, firstText);
    expect(restored.isDirty, isFalse);

    // What the user had typed is in the safety version rather than lost: restoring the safety
    // version in turn brings it back.
    final safety = restored.projectVersions.firstWhere(
      (version) => version.name == "Before restoring v1",
    );

    bloc.add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: safety.id,
        safetyVersionName: "Before restoring the safety version",
      ),
    );
    // The mode's own data lands before the version list does (see `_onVersionRestoreConfirmed`'s
    // own doc comment), so this waits for the working copy to actually descend from the safety
    // version — the list's own read — rather than for the text alone, which a still-in-flight
    // restore could otherwise leave the bloc closing underneath.
    final undone = await waitForState(
      bloc,
      (state) => state.text == secondText && state.workingCopy?.baseVersionId == safety.id,
    );
    expect(undone.isPreviewingVersion, isFalse);

    await bloc.close();
  });

  test('restoring the previewed version — the banner action — restores it and leaves the preview',
      () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = created.projectVersions.single.id;

    await writeScreenplay(secondText);
    bloc.add(const OcptEditorLoadRequestedEvent());
    await waitForState(bloc, (state) => state.text == secondText);

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.previewedVersionId != null);

    // `OcptProjectsManager.restoreProjectVersion` leaves the preview on its own, so the same event
    // a version's own card dispatches is all the read-only banner's `Start from this version`
    // needs — no dedicated fork event or branch-point card any more.
    bloc.add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: versionId,
        safetyVersionName: "Before restoring v1",
      ),
    );
    // The mode's own data lands before the version list does (see `_onVersionRestoreConfirmed`'s
    // own doc comment), so this waits for the working copy to actually descend from the restored
    // version — the list's own read — rather than for the text alone, which a still-in-flight
    // restore could otherwise leave the bloc closing underneath.
    final restored = await waitForState(
      bloc,
      (state) => state.text == firstText && state.workingCopy?.baseVersionId == versionId,
    );

    // The preview is over — what was read-only a moment ago is the working copy now.
    expect(restored.isPreviewingVersion, isFalse);
    expect(projectsManager.currentProject!.isReadOnly, isFalse);

    await bloc.close();
  });

  test('restoring a version that no longer exists reports it and changes nothing', () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(
      const OcptProjectVersionRestoreConfirmedEvent(
        versionId: "not-a-version",
        safetyVersionName: "Before restoring nothing",
      ),
    );
    final state = await waitForState(bloc, (state) => state.projectVersionNotice != null);

    expect(state.projectVersionNotice, OcptProjectVersionNoticeKind.restoreFailed);
    expect(state.text, firstText);
    expect(state.projectVersions, isEmpty);

    await bloc.close();
  });

  test('previewing a version that no longer exists reports it and leaves the working copy',
      () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(
      const OcptProjectVersionPreviewRequestedEvent(versionId: "not-a-version"),
    );
    final state = await waitForState(bloc, (state) => state.projectVersionNotice != null);

    expect(state.projectVersionNotice, OcptProjectVersionNoticeKind.previewFailed);
    expect(state.previewedVersionId, isNull);
    expect(state.text, firstText);

    bloc.add(const OcptProjectVersionNoticeDismissedEvent());
    await waitForState(bloc, (state) => state.projectVersionNotice == null);

    await bloc.close();
  });

  test('the working copy is captured and emitted alongside the list', () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(
      bloc,
      (state) => state.workingCopy?.baseVersionId != null,
    );

    // A fresh version's own working copy is identical content, so nothing has diverged from it
    // yet.
    expect(created.workingCopy?.baseVersionId, created.projectVersions.single.id);
    expect(created.workingCopy?.isModifiedSinceBase, isFalse);

    await bloc.close();
  });

  test('no working copy is captured while a version is being previewed', () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    // `workingCopy` alone is already non-null before this (the mixin's own initial refresh sets
    // it, with no base yet): waiting for a base is what actually proves this creation's own
    // capture — not the earlier one — has landed.
    final created = await waitForState(bloc, (state) => state.workingCopy?.baseVersionId != null);
    final versionId = created.projectVersions.single.id;

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    final previewing = await waitForState(bloc, (state) => state.previewedVersionId != null);

    expect(previewing.workingCopy, isNull);

    await bloc.close();
  });

  test('leaving a preview captures the working copy again', () async {
    await writeScreenplay(firstText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.text == firstText);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    final created = await waitForState(bloc, (state) => state.workingCopy?.baseVersionId != null);
    final versionId = created.projectVersions.single.id;

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.previewedVersionId != null);

    // Nothing else would put the card back: the `Versions` tab showing it is already the selected
    // one, so no reselection is coming to ask for a capture.
    bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
    final left = await waitForState(bloc, (state) => state.previewedVersionId == null);

    expect(left.workingCopy?.baseVersionId, versionId);
    expect(left.workingCopy?.isModifiedSinceBase, isFalse);

    await bloc.close();
  });

  test('two working-copy refreshes in a row only capture once, but a change always captures',
      () async {
    final countingManager = _CountingProjectsManager(propertiesManager: propertiesManager);
    await countingManager.initLifeCycle();
    final created = await countingManager.createProject(
      name: "Throttle Movie",
      filePath: p.join(tempDir.path, "throttle.ocpt"),
    );
    expect(created.status.isSuccess, isTrue);

    final bloc = buildBloc(overrideProjectsManager: countingManager);
    // The initial refresh on mount already captured the working copy once, through the
    // unthrottled path every project-changing operation goes through.
    await waitForState(bloc, (state) => state.workingCopy != null);
    final afterMount = countingManager.captureCount;
    expect(afterMount, 1);

    // Both land well inside the 2 s throttle window, so only the first would ever capture again.
    bloc.add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    bloc.add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(countingManager.captureCount, afterMount);

    // Creating a version changes the project, so it captures the truth regardless of how soon
    // after the last capture it happens.
    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v1", note: ""));
    await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    expect(countingManager.captureCount, afterMount + 1);

    await bloc.close();
    await countingManager.disposeLifeCycle();
  });
}
