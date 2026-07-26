// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_event.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// An export manager whose [pickAndReadFountain] is stubbed, to exercise the bloc's import flow
/// without any real file dialog. [fountainIoService] is left as the real, pure implementation.
class _FakeExportManager extends OcptExportManager {
  /// Class constructor
  _FakeExportManager({this.importResult})
    : super(fileSelectorManager: const FileSelectorManager());

  /// The model [pickAndReadFountain] returns, or null to simulate a cancelled open dialog.
  final OcptImportedFountainModel? importResult;

  /// The file type label of the last [pickAndReadFountain] call.
  String? lastFileTypeLabel;

  @override
  Future<OcptImportedFountainModel?> pickAndReadFountain({required String fileTypeLabel}) async {
    lastFileTypeLabel = fileTypeLabel;
    return importResult;
  }
}

/// A file saver manager whose [saveFileFromBytes] is stubbed, to exercise the bloc's save-as
/// step without any real save dialog.
class _FakeFileSaverManager extends FileSaverManager {
  /// Class constructor
  _FakeFileSaverManager({this.result});

  /// The path [saveFileFromBytes] returns, or null to simulate a cancelled save dialog.
  final String? result;

  /// The file name of the last [saveFileFromBytes] call.
  String? lastFileName;

  @override
  Future<String?> saveFileFromBytes({required String fileName, required Uint8List bytes}) async {
    lastFileName = fileName;
    return result;
  }
}

/// A router manager whose [push] only records the route pushed: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// The last route [push] was called with, or null if it never was.
  OcptRoute? pushedRoute;

  @override
  Future<Y?> push<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    pushedRoute = route;
    return null;
  }
}

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's own error paths)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_home_bloc_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
    await projectsManager.initLifeCycle();
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds a bloc wired to the test project manager, defaulting every dialog-facing dependency
  /// to a fake that cancels (returns null), so a test not exercising the import flow never
  /// touches a real file dialog.
  OcptHomeBloc buildBloc({
    OcptExportManager? exportManager,
    FileSaverManager? fileSaverManager,
    OcptRouterManager? routerManager,
  }) => OcptHomeBloc(
    propertiesManager: propertiesManager,
    projectsManager: projectsManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    fileSaverManager: fileSaverManager ?? _FakeFileSaverManager(),
    fileSelectorManager: const FileSelectorManager(),
    exportManager: exportManager ?? _FakeExportManager(),
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptHomeState> waitForState(
    OcptHomeBloc bloc,
    bool Function(OcptHomeState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test(
    'imports a picked fountain file into a new project and navigates to the editor',
    () async {
      const importedText = "Title: My Movie\n\nINT. HOUSE - DAY\n\nAction.\n";
      final exportManager = _FakeExportManager(
        importResult: const OcptImportedFountainModel(
          fountainText: importedText,
          sourceFileName: "draft.fountain",
        ),
      );
      final savedPath = p.join(tempDir.path, "My Movie.ocpt");
      final fileSaverManager = _FakeFileSaverManager(result: savedPath);
      final routerManager = _RecordingRouterManager();

      final bloc = buildBloc(
        exportManager: exportManager,
        fileSaverManager: fileSaverManager,
        routerManager: routerManager,
      );

      bloc.add(
        const OcptHomeImportScreenplayRequestedEvent(
          fountainFileTypeLabel: "Fountain screenplay",
        ),
      );
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.error, isNull);
      expect(exportManager.lastFileTypeLabel, "Fountain screenplay");
      // The suggested file name comes from the imported file's title page.
      expect(fileSaverManager.lastFileName, "My Movie.ocpt");
      expect(routerManager.pushedRoute, OcptRoute.workspace);

      final project = projectsManager.currentProject!;
      expect(project.name, "My Movie");
      expect(project.path, savedPath);

      final storedText = await projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );
      expect(storedText, importedText);

      final snapshots =
          await (project.database.select(
            project.database.ocptScreenplaySnapshotsTable,
          )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();
      expect(snapshots.last.reason, OcptSnapshotReason.import);

      await bloc.close();
    },
  );

  test('a cancelled fountain file picker leaves the bloc idle and creates no project', () async {
    final exportManager = _FakeExportManager();
    final fileSaverManager = _FakeFileSaverManager();
    final bloc = buildBloc(exportManager: exportManager, fileSaverManager: fileSaverManager);

    bloc.add(
      const OcptHomeImportScreenplayRequestedEvent(fountainFileTypeLabel: "Fountain screenplay"),
    );
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.error, isNull);
    expect(fileSaverManager.lastFileName, isNull);
    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });

  test('a cancelled save-as dialog leaves the bloc idle and creates no project', () async {
    const importedText = "INT. HOUSE - DAY\n\nAction.\n";
    final exportManager = _FakeExportManager(
      importResult: const OcptImportedFountainModel(
        fountainText: importedText,
        sourceFileName: "draft.fountain",
      ),
    );
    final fileSaverManager = _FakeFileSaverManager();
    final bloc = buildBloc(exportManager: exportManager, fileSaverManager: fileSaverManager);

    bloc.add(
      const OcptHomeImportScreenplayRequestedEvent(fountainFileTypeLabel: "Fountain screenplay"),
    );
    await waitForState(bloc, (state) => state.isBusy);
    final state = await waitForState(bloc, (state) => !state.isBusy);

    expect(state.error, isNull);
    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });
}
