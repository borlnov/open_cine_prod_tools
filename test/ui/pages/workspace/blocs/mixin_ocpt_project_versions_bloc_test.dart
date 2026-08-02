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
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
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

/// The versions dock tab, exercised through `OcptEditorBloc` — one of the two blocs mixing
/// `MixinOcptProjectVersionsBloc` in.
///
/// The screenplay mode is the one used here because it is the mode that holds unsaved text between
/// two writes, which is what makes the "flush before previewing" hook of the mixin observable: the
/// mixin's behaviour itself is the same in every mode.
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
  OcptEditorBloc buildBloc() => OcptEditorBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _SilentRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
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
    await waitForState(bloc, (state) => !state.isLoading);

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
    expect(state.projectVersions.single.isCurrent, isTrue);
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
}
