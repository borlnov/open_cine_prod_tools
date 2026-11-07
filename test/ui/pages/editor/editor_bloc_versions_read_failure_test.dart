// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../ocpt_result_expectations.dart';
import 'editor_bloc_test_doubles.dart';

/// What the editor's versions handlers do when the screenplay's text cannot be read again after a
/// preview entry, a restore or a preview exit: each stops there, before the card's confirmation is
/// dismissed and before the version list is read, and goes on once the text can be read.
void main() {
  const savedText = "INT. HOUSE - DAY\n\nAction.\n";
  const typedText = "INT. CABIN - DAY\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late UnreadableScreenplayService service;
  late OcptEditorBloc bloc;
  late String versionId;

  setUpAll(() async {
    OcptGlobalManager.instance;
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Give the bloc time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 300);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_versions_read_failure_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: testAppLanguageCode,
    );
    await projectsManager.initLifeCycle();
    final created = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(created.status.isSuccess, isTrue);
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: savedText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    versionId = (await projectsManager.createProjectVersion(name: "v1", note: "").valueOrFail).id;

    service = UnreadableScreenplayService();
    bloc = OcptEditorBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: RecordingRouterManager(),
      exportManager: InertExportManager(),
      screenplayService: service,
    );
    await bloc.stream.firstWhere((OcptEditorState state) => !state.isLoading);
    await settle();
  });

  tearDown(() async {
    await bloc.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Ask for the delete confirmation of the version's card.
  Future<void> askForDeletion() async {
    bloc.add(OcptProjectVersionDeletionRequestedEvent(versionId: versionId));
    await settle();
    expect(bloc.state.versionPendingDeletionId, versionId);
  }

  /// Count the versions the project file holds.
  Future<int> storedVersionCount() async =>
      (await projectsManager.listProjectVersions().valueOrFail).length;

  test("entering a preview stops before the confirmation is dismissed", () async {
    await askForDeletion();
    service.isReadFailing = true;

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await settle();

    expect(projectsManager.currentProject!.previewedVersion, isNotNull, reason: "it did enter");
    expect(bloc.state.versionPendingDeletionId, versionId);
    expect(bloc.state.previewedVersionId, isNull, reason: "the editor never read the version");
  });

  test("leaving a preview stops before the confirmation is dismissed", () async {
    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await settle();
    expect(bloc.state.previewedVersionId, versionId);
    await askForDeletion();
    service.isReadFailing = true;

    bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
    await settle();

    expect(projectsManager.currentProject!.previewedVersion, isNull, reason: "it did leave");
    expect(bloc.state.versionPendingDeletionId, versionId);
    expect(bloc.state.previewedVersionId, versionId, reason: "the editor never read the text");
  });

  test("a restore stops before the version list is read", () async {
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: typedText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    final listedBefore = bloc.state.projectVersions.length;
    service.isReadFailing = true;

    bloc.add(
      OcptProjectVersionRestoreConfirmedEvent(versionId: versionId, safetyVersionName: "safety"),
    );
    await settle();

    expect(await storedVersionCount(), greaterThan(listedBefore), reason: "it did restore");
    expect(bloc.state.projectVersions.length, listedBefore, reason: "the list was not read");
  });

  test("the same events go through once the text can be read", () async {
    await askForDeletion();

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await settle();
    expect(bloc.state.previewedVersionId, versionId);
    expect(bloc.state.versionPendingDeletionId, isNull);

    await askForDeletion();
    bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
    await settle();
    expect(bloc.state.previewedVersionId, isNull);
    expect(bloc.state.versionPendingDeletionId, isNull);
  });
}
