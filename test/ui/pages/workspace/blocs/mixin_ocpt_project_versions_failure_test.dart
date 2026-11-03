// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_preview_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these tests never leave the workspace.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A projects manager whose restore and preview exit fail on a step around them, as a refused
/// episode count or a preview database that cannot be closed do.
class _StoppedRestoreProjectsManager extends OcptProjectsManager {
  /// Class constructor
  _StoppedRestoreProjectsManager({required super.propertiesManager})
    : super(appLanguageCode: () => "en");

  /// Fail as a project file that cannot be read for the version does.
  @override
  Future<ResultWithStatus<OcptProjectPreviewStatus, OcptOpenProjectModel>> previewVersion(
    String versionId,
  ) async => const ResultWithStatus(
    status: OcptProjectPreviewStatus.databaseError,
    extraInfo: "preview intentionally failed for the test",
  );

  /// Fail as a preview database that cannot be closed does.
  @override
  Future<OcptDatabaseOutcome> exitPreview() async => const OcptDatabaseOutcome(
    status: OcptDatabaseStatus.databaseError,
    extraInfo: "exit intentionally failed for the test",
  );

  /// Stop as a failing database does.
  @override
  Future<OcptProjectRestoreStatus> restoreProjectVersion({
    required String versionId,
    required String safetyVersionName,
  }) async => OcptProjectRestoreStatus.databaseError;
}

/// A projects manager whose version list read and working-copy capture can each be refused alone,
/// which a refused `project_versions` table cannot do: it fails both.
class _OneReadRefusedProjectsManager extends OcptProjectsManager {
  /// Whether the version list read is refused.
  bool refuseList = false;

  /// Whether the working-copy capture is refused.
  bool refuseCapture = false;

  /// Class constructor
  _OneReadRefusedProjectsManager({required super.propertiesManager})
    : super(appLanguageCode: () => "en");

  /// Refuse as a project file that cannot be read does, when told to.
  @override
  Future<OcptDatabaseResult<List<OcptProjectVersion>>> listProjectVersions() async {
    if (refuseList) {
      return const OcptDatabaseResult(status: OcptDatabaseStatus.databaseError);
    }

    return super.listProjectVersions();
  }

  /// Refuse as a project file that cannot be read does, when told to.
  @override
  Future<OcptDatabaseResult<OcptProjectWorkingCopyState>> captureWorkingCopyState() async {
    if (refuseCapture) {
      return const OcptDatabaseResult(status: OcptDatabaseStatus.databaseError);
    }

    return super.captureWorkingCopyState();
  }
}

/// What the versions handlers do when the project file cannot answer them: each stops where the
/// failure was answered, with no notice and no state, and goes through once the file answers.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptEditorBloc bloc;
  late String versionId;
  late List<OcptEditorState> emitted;

  setUpAll(() async {
    OcptGlobalManager.instance;
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Give the bloc time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 300);

  /// Build the bloc on [manager] and record what it emits from the moment it is loaded.
  Future<void> start(OcptProjectsManager manager) async {
    bloc = OcptEditorBloc(
      projectsManager: manager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      parseDebounce: const Duration(milliseconds: 20),
      autosaveDebounce: const Duration(seconds: 30),
    );
    await bloc.stream.firstWhere((state) => !state.isLoading);
    await settle();
    emitted = [];
    final subscription = bloc.stream.listen(emitted.add);
    addTearDown(subscription.cancel);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_versions_failure_test_");
  });

  tearDown(() async {
    await bloc.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Open a project on [manager] holding one version.
  Future<void> openProject(OcptProjectsManager manager) async {
    projectsManager = manager;
    await manager.initLifeCycle();
    final created = await manager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(created.status.isSuccess, isTrue);
    versionId = (await manager.createProjectVersion(name: "v1", note: "").valueOrFail).id;
  }

  /// Make the project file unable to answer a version operation.
  Future<void> refuse() => projectsManager.currentProject!.fileDatabase.customStatement(
    "ALTER TABLE project_versions RENAME TO project_versions_gone",
  );

  /// Let the project file answer again.
  Future<void> allow() => projectsManager.currentProject!.fileDatabase.customStatement(
    "ALTER TABLE project_versions_gone RENAME TO project_versions",
  );

  /// Count the versions the project file holds, read straight from it.
  Future<int> storedVersions() async {
    final rows = await projectsManager.currentProject!.fileDatabase
        .customSelect("SELECT id FROM project_versions")
        .get();

    return rows.length;
  }

  group("with a project file that cannot answer", () {
    setUp(() async {
      await openProject(
        OcptProjectsManager(propertiesManager: propertiesManager, appLanguageCode: () => "en"),
      );
      await start(projectsManager);
    });

    test("a creation emits nothing, and goes through once the file answers", () async {
      await refuse();
      bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v2", note: ""));
      await settle();

      expect(emitted, isEmpty);

      await allow();
      expect(await storedVersions(), 1);
      bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v2", note: ""));
      await settle();

      expect(await storedVersions(), 2);
      expect(emitted, isNotEmpty);
    });

    test("a deletion emits nothing and keeps the version", () async {
      await refuse();
      bloc.add(OcptProjectVersionDeletionConfirmedEvent(versionId: versionId));
      await settle();

      expect(emitted, isEmpty);

      await allow();
      expect(await storedVersions(), 1);
      bloc.add(OcptProjectVersionDeletionConfirmedEvent(versionId: versionId));
      await settle();

      expect(await storedVersions(), 0);
      expect(bloc.state.projectVersions, isEmpty);
    });

    test("a rename emits nothing", () async {
      await refuse();
      bloc.add(
        OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: "v1 bis", note: ""),
      );
      await settle();

      expect(emitted, isEmpty);

      await allow();
      bloc.add(
        OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: "v1 bis", note: ""),
      );
      await settle();

      expect(bloc.state.projectVersions.single.name, "v1 bis");
    });

    test("a refresh emits nothing", () async {
      await refuse();
      bloc.add(const OcptProjectVersionsRefreshRequestedEvent());
      await settle();

      expect(emitted, isEmpty);
    });

    test("a preview stops before any notice, and keeps the working copy on screen", () async {
      bloc.add(OcptProjectVersionDeletionRequestedEvent(versionId: versionId));
      await settle();
      emitted.clear();
      await refuse();

      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
      await settle();

      expect(emitted, isEmpty);
      expect(projectsManager.currentProject!.isReadOnly, isFalse);
      expect(bloc.state.versionPendingDeletionId, versionId);

      await allow();
      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
      await settle();

      expect(bloc.state.previewedVersionId, versionId);
      expect(bloc.state.versionPendingDeletionId, isNull);
    });

    test("a working copy refresh emits nothing", () async {
      // The refresh is throttled: wait out the window the mount's own capture opened.
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      await refuse();
      bloc.add(const OcptProjectWorkingCopyRefreshRequestedEvent());
      await settle();

      expect(emitted, isEmpty);
    });
  });

  group("with one of the two reads that redraw the panel refused", () {
    late _OneReadRefusedProjectsManager manager;

    setUp(() async {
      manager = _OneReadRefusedProjectsManager(propertiesManager: propertiesManager);
      await openProject(manager);
      await start(manager);
    });

    test(
      "the version list refused alone emits nothing, and a refresh goes through after",
      () async {
        manager.refuseList = true;
        bloc.add(const OcptProjectVersionsRefreshRequestedEvent());
        await settle();

        expect(emitted, isEmpty);

        manager.refuseList = false;
        bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v3", note: ""));
        await settle();

        expect(emitted, isNotEmpty);
      },
    );

    test(
      "the working-copy capture refused alone emits nothing, and a refresh goes through",
      () async {
        manager.refuseCapture = true;
        bloc.add(const OcptProjectVersionsRefreshRequestedEvent());
        await settle();

        expect(emitted, isEmpty);

        manager.refuseCapture = false;
        bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v3", note: ""));
        await settle();

        expect(emitted, isNotEmpty);
      },
    );

    test("a creation whose redraw read is refused alone still writes the version", () async {
      manager.refuseCapture = true;
      bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "v2", note: ""));
      await settle();

      expect(emitted, isEmpty);
      expect(await storedVersions(), 2);
    });
  });

  test("a restore that stops on a step around it emits nothing", () async {
    await openProject(_StoppedRestoreProjectsManager(propertiesManager: propertiesManager));
    await start(projectsManager);

    bloc.add(
      OcptProjectVersionRestoreConfirmedEvent(versionId: versionId, safetyVersionName: "safety"),
    );
    await settle();

    expect(emitted, isEmpty);
  });

  test("a preview exit that cannot leave the preview emits nothing", () async {
    await openProject(_StoppedRestoreProjectsManager(propertiesManager: propertiesManager));
    await start(projectsManager);

    bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
    await settle();

    expect(emitted, isEmpty);
  });

  test(
    "a preview that stops on the project file emits nothing and keeps the confirmation",
    () async {
      await openProject(_StoppedRestoreProjectsManager(propertiesManager: propertiesManager));
      await start(projectsManager);
      bloc.add(OcptProjectVersionDeletionRequestedEvent(versionId: versionId));
      await settle();
      emitted.clear();

      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
      await settle();

      expect(emitted, isEmpty);
      expect(bloc.state.versionPendingDeletionId, versionId);
    },
  );
}
