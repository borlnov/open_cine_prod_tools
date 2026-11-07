// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these tests never leave the workspace.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A shot list service whose text field writes always fail, as a full disk would; everything else
/// is the source service's own.
class _FailingFieldShotListService extends OcptShotListService {
  /// Class constructor
  _FailingFieldShotListService(OcptShotListService source)
    : super(
        logger: const SilentLogger(),
        roleIndexService: source.roleIndexService,
        storyboardService: source.storyboardService,
        floorPlanService: source.floorPlanService,
        deviceId: source.deviceId,
      );

  /// Fail as a refused field write does.
  @override
  Future<OcptDatabaseOutcome> updateTextField({
    required OcptProjectDatabase database,
    required String shotId,
    required OcptShotListEditableField field,
    required String rawValue,
  }) async => const OcptDatabaseOutcome(
    status: OcptDatabaseStatus.databaseError,
    extraInfo: "field write intentionally failed for the test",
  );
}

/// An export manager that records the shot list it is asked to export, and saves it nowhere.
class _RecordingExportManager extends OcptExportManager {
  /// The snapshot of the last export, or null if none was asked for.
  OcptShotListSnapshot? lastExportedSnapshot;

  /// Class constructor
  _RecordingExportManager() : super(fileSelectorManager: const FileSelectorManager());

  /// Remember the snapshot and answer that the workbook was saved.
  @override
  Future<OcptExportOutcome?> exportShotListXlsx({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedSnapshot = snapshot;
    return const OcptExportSaved("/tmp/My Movie.xlsx");
  }
}

/// A save location service recording that it was asked, and answering [answer].
class _RecordingSaveLocationService extends OcptSaveLocationService {
  /// The path handed back.
  final String answer;

  /// How many times a save location was asked for.
  int askCount = 0;

  /// Class constructor
  _RecordingSaveLocationService({required this.answer}) : super(logger: const SilentLogger());

  /// Count the question and answer with the canned location.
  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    String? initialDirectory,
  }) async {
    askCount++;
    return answer;
  }
}

/// Run the tests of the shot list flush failure.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late _RecordingSaveLocationService saveLocationService;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_flush_failure_test_");
    saveLocationService = _RecordingSaveLocationService(answer: p.join(tempDir.path, "a.ocptz"));
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
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

  /// A mode bloc over a one-scene screenplay with a shot, an inspector whose writes fail with a
  /// field typed into it, and a saved version.
  Future<({OcptShotListBloc mode, OcptShotListInspectorBloc inspector, String versionId})>
  setUpTypedEdit() async {
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: "INT. HOUSE - DAY\n\nAction one.\n",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    final version = await projectsManager
        .createProjectVersion(name: "v1", note: "")
        .maybeValueOrFail;

    final mode = OcptShotListBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        saveLocationService: saveLocationService,
      ),
    );
    final inspector = OcptShotListInspectorBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      shotListService: _FailingFieldShotListService(projectsManager.shotListService),
      fieldEditDebounce: const Duration(days: 1),
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));

    mode.add(const OcptShotListShotCreationRequestedEvent());
    final created = await mode.stream
        .firstWhere((state) => state.totalShotCount == 1)
        .timeout(const Duration(seconds: 5));
    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: created.selectedShotId!,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Close-up",
      ),
    );
    await inspector.stream
        .firstWhere((state) => state.pendingFieldEdits.isNotEmpty)
        .timeout(const Duration(seconds: 5));

    return (mode: mode, inspector: inspector, versionId: version!.id);
  }

  group("a typed edit the database refuses", () {
    test("does not stop a version preview, and raises the write error", () async {
      final fixture = await setUpTypedEdit();

      fixture.mode.add(OcptProjectVersionPreviewRequestedEvent(versionId: fixture.versionId));
      await fixture.mode.stream
          .firstWhere((state) => state.isPreviewingVersion)
          .timeout(const Duration(seconds: 5));

      expect(fixture.inspector.state.hasWriteError, isTrue);

      await fixture.inspector.close();
      await fixture.mode.close();
    });

    test("does not stop a restore, and raises the write error", () async {
      final fixture = await setUpTypedEdit();
      final versionCount = (await projectsManager.listProjectVersions().valueOrFail).length;

      fixture.mode.add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: fixture.versionId,
          safetyVersionName: "safety",
        ),
      );
      await pumpEventQueue(times: 400);

      expect(
        (await projectsManager.listProjectVersions().valueOrFail).length,
        greaterThan(versionCount),
        reason: "the restore ran, and took a safety version of the changed working copy",
      );
      expect(fixture.inspector.state.hasWriteError, isTrue);

      await fixture.inspector.close();
      await fixture.mode.close();
    });

    test("does not stop a project package", () async {
      final fixture = await setUpTypedEdit();

      fixture.mode.add(const OcptProjectPackageExportRequestedEvent(fileTypeLabel: "Package"));
      await pumpEventQueue(times: 400);

      expect(saveLocationService.askCount, 1);
      expect(fixture.inspector.state.hasWriteError, isTrue);

      await fixture.inspector.close();
      await fixture.mode.close();
    });

    test("does not stop an export, which holds the value the database still has", () async {
      final fixture = await setUpTypedEdit();
      final exportManager = _RecordingExportManager();
      final exportBloc = OcptShotListExportBloc(
        modeBloc: fixture.mode,
        projectsManager: projectsManager,
        exportManager: exportManager,
      );

      exportBloc.add(
        const OcptShotListXlsxExportRequestedEvent(
          labels: OcptShotListXlsxLabels(
            sheetName: "Shot list",
            columnHeaders: {},
            statusLabels: {},
            sequenceTitles: {},
            dayTagPrefix: "D",
          ),
          fileTypeLabel: "Excel workbook",
        ),
      );
      await exportBloc.stream
          .firstWhere((state) => state.ioNotice != null)
          .timeout(const Duration(seconds: 5));

      expect(exportManager.lastExportedSnapshot, isNotNull);
      expect(fixture.inspector.state.hasWriteError, isTrue);

      await exportBloc.close();
      await fixture.inspector.close();
      await fixture.mode.close();
    });
  });
}
