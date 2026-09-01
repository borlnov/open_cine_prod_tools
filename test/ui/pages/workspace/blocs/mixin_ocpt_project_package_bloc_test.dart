// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_share_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The app language every projects manager built here is given, so a created project never depends
/// on the machine the tests run on.
String _testAppLanguageCode() => "en";

/// A router manager whose [pop] does nothing: these tests never leave the workspace, and no real
/// GoRouter is built for it to operate on.
class _SilentRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A save location service answering [answer] without ever showing a native dialog, and recording
/// that it was asked.
///
/// A null [answer] is the user cancelling the dialog, which every export of this app treats as a
/// silent no-op.
class _RecordingSaveLocationService extends OcptSaveLocationService {
  /// The path handed back, or null to answer as a cancelled dialog.
  final String? answer;

  /// How many times a save location was asked for.
  int askCount = 0;

  /// The extensions the last call restricted itself to.
  List<String> lastExtensions = const [];

  /// The file name the last call suggested.
  String lastSuggestedFileName = "";

  /// Class constructor
  _RecordingSaveLocationService({required this.answer});

  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
  }) async {
    askCount++;
    lastExtensions = extensions;
    lastSuggestedFileName = suggestedFileName;
    return answer;
  }
}

/// A [PlatformManager] whose [isMobile] is stubbed, so the mixin's desktop/mobile branch can be
/// exercised on either side without a real platform underneath it — the same idiom
/// `ocpt_export_manager_test.dart` uses for the manager's own write funnel.
class _StubPlatformManager extends PlatformManager {
  /// Class constructor
  _StubPlatformManager({required this.isMobile});

  @override
  final bool isMobile;
}

/// A share service answering [temporaryDirectory] with the directory given at construction and
/// [shareFiles] with [answer], without ever showing a real OS share sheet, and recording that it
/// was asked.
///
/// A false [answer] is the user dismissing the share sheet, which the mixin's mobile branch treats
/// as a silent no-op, exactly as a cancelled save dialog is on desktop.
class _RecordingShareService extends OcptShareService {
  /// Class constructor
  _RecordingShareService({required Directory directory, required this.answer}) : _directory = directory;

  /// The directory [temporaryDirectory] resolves to.
  final Directory _directory;

  /// The outcome [shareFiles] reports.
  final bool answer;

  /// How many times the share sheet was asked for.
  int shareCount = 0;

  /// The paths of the last [shareFiles] call.
  List<String> lastPaths = const [];

  @override
  Future<Directory> temporaryDirectory() async => _directory;

  @override
  Future<bool> shareFiles({required List<String> paths, Rect? sharePositionOrigin}) async {
    shareCount++;
    lastPaths = paths;
    return answer;
  }
}

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late String packagePath;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the mixin's failure paths)
    // resolvable; the bloc's own dependencies are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_package_bloc_test_");
    packagePath = p.join(tempDir.path, "movie.ocptz");

    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: _testAppLanguageCode,
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

  /// Adds one `assets` row labelled [label] and pointing at [path], which may or may not exist.
  Future<void> addAsset({required String path, required String label}) {
    final database = projectsManager.currentProject!.database;

    return database
        .into(database.ocptAssetsTable)
        .insert(
          OcptAssetsTableCompanion.insert(
            id: label,
            kind: OcptAssetKind.locationPhoto,
            path: path,
            label: Value(label),
            addedAt: DateTime.utc(2026, 8, 19),
          ),
        );
  }

  /// Writes a real file under the temp directory and returns its path, so an `assets` row can point
  /// at something that is actually there.
  String writeReferencedFile(String name) {
    final path = p.join(tempDir.path, name);
    File(path).writeAsStringSync("referenced bytes");
    return path;
  }

  /// Builds a shot list bloc — one of the five blocs mixing `MixinOcptProjectPackageBloc` in — over
  /// the test project, its save dialog answered by [saveLocationService] and, on
  /// [platformManager]'s own [PlatformManager.isMobile], its share sheet answered by
  /// [shareService].
  ///
  /// The shot list is the mode used here because it is the lightest of the five; the mixin's
  /// behaviour is the same in every one of them, which is the whole reason it is a mixin.
  /// [platformManager] and [shareService] default to the real desktop write funnel, so the existing
  /// desktop-only tests need not know either exists.
  OcptShotListBloc buildBloc(
    OcptSaveLocationService saveLocationService, {
    PlatformManager? platformManager,
    OcptShareService? shareService,
  }) => OcptShotListBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _SilentRouterManager(),
    exportManager: OcptExportManager(
      fileSelectorManager: const FileSelectorManager(),
      saveLocationService: saveLocationService,
      platformManager: platformManager,
      shareService: shareService,
    ),
    fieldEditDebounce: const Duration(milliseconds: 20),
  );

  /// Builds a bloc through [buildBloc] and waits for its own initial read of the project to land,
  /// so nothing of the mode's is still in flight when a test's assertions — or its teardown —
  /// arrive.
  Future<OcptShotListBloc> buildLoadedBloc(
    OcptSaveLocationService saveLocationService, {
    PlatformManager? platformManager,
    OcptShareService? shareService,
  }) async {
    final bloc = buildBloc(
      saveLocationService,
      platformManager: platformManager,
      shareService: shareService,
    );
    await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 20));
    return bloc;
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptShotListState> waitForState(
    OcptShotListBloc bloc,
    bool Function(OcptShotListState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 20));
  }

  /// Polls [condition] until it is true or 20 seconds pass, without depending on a bloc state
  /// emission — for a request whose outcome (a dismissed share sheet, mirroring a cancelled save
  /// dialog) is a silent no-op and therefore never emits a new state [waitForState] could wait on.
  Future<void> waitUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test("a project whose every referenced file is there is packaged without a question", () async {
    await addAsset(path: writeReferencedFile("headshot.jpg"), label: "Headshot");

    final saveLocationService = _RecordingSaveLocationService(answer: packagePath);
    final bloc = await buildLoadedBloc(saveLocationService);

    bloc.add(const OcptProjectPackageExportRequestedEvent(fileTypeLabel: "Project package"));

    final state = await waitForState(bloc, (state) => state.projectPackageNotice != null);

    expect(state.projectPackagePendingExport, isNull);
    expect(state.projectPackageNotice?.kind, OcptProjectPackageNoticeKind.exportSucceeded);
    expect(state.projectPackageNotice?.path, packagePath);
    expect(state.projectPackageNotice?.skippedAssetCount, 0);
    expect(File(packagePath).existsSync(), isTrue);
    expect(saveLocationService.lastExtensions, ["ocptz"]);
    expect(saveLocationService.lastSuggestedFileName, "My Movie.ocptz");
  });

  test("a missing referenced file raises the question, and nothing is written yet", () async {
    await addAsset(path: p.join(tempDir.path, "gone.jpg"), label: "Town hall permit");

    final saveLocationService = _RecordingSaveLocationService(answer: packagePath);
    final bloc = await buildLoadedBloc(saveLocationService);

    bloc.add(const OcptProjectPackageExportRequestedEvent(fileTypeLabel: "Project package"));

    final state = await waitForState(bloc, (state) => state.projectPackagePendingExport != null);

    expect(state.projectPackagePendingExport?.missingAssets.single.label, "Town hall permit");
    expect(state.projectPackageNotice, isNull);
    expect(saveLocationService.askCount, 0);
    expect(File(packagePath).existsSync(), isFalse);
  });

  test("answering that question writes the package, and the notice counts what stayed behind", () async {
    await addAsset(path: writeReferencedFile("headshot.jpg"), label: "Headshot");
    await addAsset(path: p.join(tempDir.path, "gone.jpg"), label: "Town hall permit");

    final saveLocationService = _RecordingSaveLocationService(answer: packagePath);
    final bloc = await buildLoadedBloc(saveLocationService);

    bloc.add(const OcptProjectPackageExportRequestedEvent(fileTypeLabel: "Project package"));
    await waitForState(bloc, (state) => state.projectPackagePendingExport != null);

    bloc.add(const OcptProjectPackageMissingFilesAskDismissedEvent());
    bloc.add(const OcptProjectPackageExportConfirmedEvent(fileTypeLabel: "Project package"));

    final state = await waitForState(bloc, (state) => state.projectPackageNotice != null);

    expect(state.projectPackagePendingExport, isNull);
    expect(state.projectPackageNotice?.kind, OcptProjectPackageNoticeKind.exportSucceeded);
    expect(state.projectPackageNotice?.skippedAssetCount, 1);
    expect(File(packagePath).existsSync(), isTrue);
  });

  test(
    "a named target is packaged even while no project is open at all",
    () async {
      final movieFilePath = p.join(tempDir.path, "movie.ocpt");
      await addAsset(path: writeReferencedFile("headshot.jpg"), label: "Headshot");
      await projectsManager.closeCurrentProject();

      final saveLocationService = _RecordingSaveLocationService(answer: packagePath);
      final bloc = await buildLoadedBloc(saveLocationService);

      bloc.add(
        OcptProjectPackageExportRequestedEvent(
          fileTypeLabel: "Project package",
          target: OcptProjectPackageTarget(filePath: movieFilePath, name: "My Movie"),
        ),
      );

      final state = await waitForState(bloc, (state) => state.projectPackageNotice != null);

      expect(state.projectPackagePendingExport, isNull);
      expect(state.projectPackageNotice?.kind, OcptProjectPackageNoticeKind.exportSucceeded);
      expect(File(packagePath).existsSync(), isTrue);
      expect(saveLocationService.lastSuggestedFileName, "My Movie.ocptz");
    },
  );

  test(
    "the read-only preview refusal does not apply to a named target",
    () async {
      final movieFilePath = p.join(tempDir.path, "movie.ocpt");
      await addAsset(path: writeReferencedFile("headshot.jpg"), label: "Headshot");
      final version = await projectsManager.createProjectVersion(name: "v1", note: "");
      await projectsManager.previewVersion(version!.id);
      expect(projectsManager.currentProject!.isReadOnly, isTrue);

      final saveLocationService = _RecordingSaveLocationService(answer: packagePath);
      final bloc = await buildLoadedBloc(saveLocationService);

      bloc.add(
        OcptProjectPackageExportRequestedEvent(
          fileTypeLabel: "Project package",
          target: OcptProjectPackageTarget(filePath: movieFilePath, name: "My Movie"),
        ),
      );

      final state = await waitForState(bloc, (state) => state.projectPackageNotice != null);

      expect(state.projectPackageNotice?.kind, OcptProjectPackageNoticeKind.exportSucceeded);
      expect(File(packagePath).existsSync(), isTrue);
    },
  );

  test("a cancelled save dialog writes nothing and says nothing", () async {
    await addAsset(path: writeReferencedFile("headshot.jpg"), label: "Headshot");

    final saveLocationService = _RecordingSaveLocationService(answer: null);
    final bloc = await buildLoadedBloc(saveLocationService);

    bloc.add(const OcptProjectPackageExportRequestedEvent(fileTypeLabel: "Project package"));
    await waitForState(bloc, (_) => saveLocationService.askCount > 0);

    // Nothing else is coming: the handler returned the moment the dialog answered null, so a state
    // holding a notice would have to be emitted by something that is not running any more.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.projectPackageNotice, isNull);
    expect(bloc.state.projectPackagePendingExport, isNull);
    expect(File(packagePath).existsSync(), isFalse);
  });

  group("on mobile", () {
    test(
      "a successful export writes into the temporary directory and shares it",
      () async {
        await addAsset(path: writeReferencedFile("headshot.jpg"), label: "Headshot");

        final saveLocationService = _RecordingSaveLocationService(answer: packagePath);
        final shareService = _RecordingShareService(directory: tempDir, answer: true);
        final bloc = await buildLoadedBloc(
          saveLocationService,
          platformManager: _StubPlatformManager(isMobile: true),
          shareService: shareService,
        );

        bloc.add(const OcptProjectPackageExportRequestedEvent(fileTypeLabel: "Project package"));

        final state = await waitForState(bloc, (state) => state.projectPackageNotice != null);

        // The native save dialog is never shown on mobile.
        expect(saveLocationService.askCount, 0);
        expect(shareService.shareCount, 1);
        expect(shareService.lastPaths, hasLength(1));
        expect(p.basename(shareService.lastPaths.single), "My Movie.ocptz");
        expect(File(shareService.lastPaths.single).existsSync(), isTrue);
        expect(state.projectPackagePendingExport, isNull);
        expect(state.projectPackageNotice?.kind, OcptProjectPackageNoticeKind.exportShared);
        expect(state.projectPackageNotice?.path, isNull);
      },
    );

    test("a dismissed share sheet writes nothing to report and raises no notice", () async {
      await addAsset(path: writeReferencedFile("headshot.jpg"), label: "Headshot");

      final saveLocationService = _RecordingSaveLocationService(answer: packagePath);
      final shareService = _RecordingShareService(directory: tempDir, answer: false);
      final bloc = await buildLoadedBloc(
        saveLocationService,
        platformManager: _StubPlatformManager(isMobile: true),
        shareService: shareService,
      );

      bloc.add(const OcptProjectPackageExportRequestedEvent(fileTypeLabel: "Project package"));
      await waitUntil(() => shareService.shareCount > 0);

      // Nothing else is coming: the handler returned the moment the share sheet answered false, so
      // a state holding a notice would have to be emitted by something that is not running any
      // more.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.projectPackageNotice, isNull);
      expect(bloc.state.projectPackagePendingExport, isNull);
    });
  });
}
