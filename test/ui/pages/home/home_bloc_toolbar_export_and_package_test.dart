// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_event.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../ocpt_result_expectations.dart';
import 'home_bloc_test_doubles.dart';

/// A file selector manager whose [openSelector] is stubbed, to exercise the bloc's import flows
/// without any real open-file dialog.
class _FakeFileSelectorManager extends FileSelectorManager {
  /// The file [openSelector] returns, or null to simulate a cancelled dialog.
  final XFile? result;

  /// The extensions of the last [openSelector] call.
  List<String>? lastAllowedExtensions;

  /// Class constructor
  _FakeFileSelectorManager({this.result});

  /// Remember the allowed extensions, and answer with the canned file.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async {
    lastAllowedExtensions = allowedExtensions;
    // A cancelled native dialog reports success with no file, never a failure status — mirroring
    // FileSelectorManager.openSelector's own real behaviour.
    return ResultWithBoolStatus<XFile>(status: BoolResultStatus.success, value: result);
  }
}

/// Run the tests of the home bloc toolbar export and package.
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
    projectsManager = TestProjectsManager(
      directory: tempDir,
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
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
    FileSelectorManager? fileSelectorManager,
    OcptRouterManager? routerManager,
  }) => OcptHomeBloc(
    propertiesManager: propertiesManager,
    projectsManager: projectsManager,
    routerManager: routerManager ?? RecordingRouterManager(),
    fileSelectorManager: fileSelectorManager ?? const FileSelectorManager(),
    exportManager: exportManager ?? FakeExportManager(),
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

  group("the home toolbar's Join a shared project…", () {
    test("pushes the Rejoindre screen and opens no project", () async {
      final routerManager = RecordingRouterManager();
      final bloc = buildBloc(routerManager: routerManager);

      bloc.add(const OcptHomeJoinSharedProjectRequestedEvent());
      await pumpEventQueue();

      expect(routerManager.pushedRoute, OcptRoute.joining);
      expect(projectsManager.currentProject, isNull);

      await bloc.close();
    });
  });

  group("a project card's Export…", () {
    /// Writes a real file under the temp directory and returns its path, so an `assets` row can
    /// point at something that is actually there.
    String writeReferencedFile(String name) {
      final path = p.join(tempDir.path, name);
      File(path).writeAsStringSync("referenced bytes");
      return path;
    }

    /// Creates a project at [filePath], adds one `assets` row labelled [label] and pointing at
    /// [assetPath] (which may or may not exist), then closes it — a project card names a file
    /// nothing has opened, exactly like this leaves the project.
    Future<void> createProjectWithAsset(
      String filePath, {
      required String assetPath,
      required String label,
    }) async {
      await projectsManager.createProject(name: "My Movie", filePath: filePath);
      final database = projectsManager.currentProject!.database;
      await database
          .into(database.ocptAssetsTable)
          .insert(
            OcptAssetsTableCompanion.insert(
              id: label,
              kind: OcptAssetKind.locationPhoto,
              path: assetPath,
              label: Value(label),
              addedAt: DateTime.utc(2026, 8, 19),
            ),
          );
      await projectsManager.closeCurrentProject().okOrFail;
    }

    test(
      "runs the pre-flight and asks through the state when a referenced file is missing",
      () async {
        final filePath = p.join(tempDir.path, "movie.ocpt");
        await createProjectWithAsset(
          filePath,
          assetPath: p.join(tempDir.path, "gone.jpg"),
          label: "Town hall permit",
        );

        final bloc = buildBloc();
        bloc.add(
          OcptProjectPackageExportRequestedEvent(
            fileTypeLabel: "Project package",
            target: OcptProjectPackageTarget(filePath: filePath, name: "My Movie"),
          ),
        );

        final state = await waitForState(
          bloc,
          (state) => state.projectPackagePendingExport != null,
        );

        expect(state.projectPackagePendingExport?.missingAssets.single.label, "Town hall permit");
        expect(state.projectPackageNotice, isNull);
        expect(
          projectsManager.currentProject,
          isNull,
          reason: "nothing was opened to export the card's project",
        );

        await bloc.close();
      },
    );

    test("writes to the picked save location when nothing is missing", () async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await createProjectWithAsset(
        filePath,
        assetPath: writeReferencedFile("headshot.jpg"),
        label: "Headshot",
      );

      final packagePath = p.join(tempDir.path, "movie.ocptz");
      final saveLocationService = RecordingSaveLocationService(saveLocationAnswer: packagePath);
      final bloc = buildBloc(
        exportManager: OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        ),
      );

      bloc.add(
        OcptProjectPackageExportRequestedEvent(
          fileTypeLabel: "Project package",
          target: OcptProjectPackageTarget(filePath: filePath, name: "My Movie"),
        ),
      );

      final state = await waitForState(bloc, (state) => state.projectPackageNotice != null);

      expect(state.projectPackageNotice?.kind, OcptProjectPackageNoticeKind.exportSucceeded);
      expect(File(packagePath).existsSync(), isTrue);
      expect(saveLocationService.askCount, 1);
      expect(projectsManager.currentProject, isNull);

      await bloc.close();
    });
  });

  group("importing a project package", () {
    late Directory importsParent;

    setUp(() {
      importsParent = Directory(p.join(tempDir.path, "imports"))..createSync(recursive: true);
    });

    /// Creates a project, exports it as a package at [packagePath], and returns it: the package a
    /// test picks through the (faked) open dialog.
    Future<String> exportedPackage(String packagePath) async {
      final projectFilePath = p.join(tempDir.path, "source.ocpt");
      await projectsManager.createProject(name: "Les Vagues", filePath: projectFilePath);
      await projectsManager.closeCurrentProject().okOrFail;

      final result = await projectsManager.exportProjectPackage(
        projectFilePath: projectFilePath,
        projectName: "Les Vagues",
        packageFilePath: packagePath,
      );
      expect(result.status.isSuccess, isTrue);
      return packagePath;
    }

    /// Rewrites the `manifest.json` entry of the package at [sourcePath] with [transform] applied
    /// to it, and returns the path of the package this produces — used to build the malformed
    /// package a newer `packageFormat` refusal is tested against, on the model of
    /// `ocpt_project_package_service_test.dart`'s own `repackagedWith`.
    Future<String> repackagedWithManifest(
      String sourcePath,
      Map<String, dynamic> Function(Map<String, dynamic> manifest) transform,
    ) async {
      final archive = ZipDecoder().decodeStream(InputFileStream(sourcePath));
      final manifestEntry = archive.files.firstWhere((entry) => entry.name == "manifest.json");
      final manifest = jsonDecode(utf8.decode(manifestEntry.readBytes()!)) as Map<String, dynamic>;
      final rewrittenManifest = utf8.encode(jsonEncode(transform(manifest)));

      final targetPath = p.join(p.dirname(sourcePath), "repackaged-${p.basename(sourcePath)}");
      final encoder = ZipFileEncoder()..create(targetPath);
      try {
        for (final entry in archive.files) {
          if (!entry.isFile) {
            continue;
          }
          final bytes = entry.name == "manifest.json" ? rewrittenManifest : entry.readBytes()!;
          encoder.addArchiveFile(ArchiveFile.bytes(entry.name, bytes));
        }
      } finally {
        await encoder.close();
      }

      return targetPath;
    }

    test("imports a picked package into the picked parent folder and raises the report, without "
        "opening anything itself", () async {
      final packagePath = await exportedPackage(p.join(tempDir.path, "movie.ocptz"));
      final fileSelectorManager = _FakeFileSelectorManager(result: XFile(packagePath));
      final saveLocationService = RecordingSaveLocationService(directoryAnswer: importsParent.path);
      final bloc = buildBloc(
        fileSelectorManager: fileSelectorManager,
        exportManager: OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        ),
      );

      bloc.add(
        const OcptHomeImportProjectPackageRequestedEvent(
          packageFileTypeLabel: "Project package",
          destinationConfirmButtonText: "Import here",
        ),
      );

      final state = await waitForState(bloc, (state) => state.projectPackageImportReport != null);

      final report = state.projectPackageImportReport!;
      expect(report.projectName, "Les Vagues");
      expect(report.skippedAssets, isEmpty);
      expect(File(report.projectFilePath).existsSync(), isTrue);
      expect(fileSelectorManager.lastAllowedExtensions, ["ocptz"]);
      expect(saveLocationService.lastDirectoryConfirmButtonText, "Import here");
      expect(
        projectsManager.currentProject,
        isNull,
        reason: "the bloc unpacks the package but never opens it itself",
      );
      expect(state.projectPackageImportError, isNull);

      await bloc.close();
    });

    test(
      "an existing folder of that name comes back as destinationExists, raised through the state",
      () async {
        final packagePath = await exportedPackage(p.join(tempDir.path, "movie.ocptz"));
        Directory(p.join(importsParent.path, "Les Vagues")).createSync(recursive: true);

        final bloc = buildBloc(
          fileSelectorManager: _FakeFileSelectorManager(result: XFile(packagePath)),
          exportManager: OcptExportManager(
            fileSelectorManager: const FileSelectorManager(),
            saveLocationService: RecordingSaveLocationService(directoryAnswer: importsParent.path),
          ),
        );

        bloc.add(
          const OcptHomeImportProjectPackageRequestedEvent(
            packageFileTypeLabel: "Project package",
            destinationConfirmButtonText: "Import here",
          ),
        );

        final state = await waitForState(bloc, (state) => state.projectPackageImportError != null);

        expect(state.projectPackageImportError, OcptProjectPackageStatus.destinationExists);
        expect(state.projectPackageImportReport, isNull);

        await bloc.close();
      },
    );

    test("a packageFormat newer than this build's is refused with its own status rather than an "
        "exception", () async {
      final packagePath = await exportedPackage(p.join(tempDir.path, "movie.ocptz"));
      final futurePackagePath = await repackagedWithManifest(
        packagePath,
        (manifest) => {...manifest, "packageFormat": 999},
      );

      final bloc = buildBloc(
        fileSelectorManager: _FakeFileSelectorManager(result: XFile(futurePackagePath)),
        exportManager: OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: RecordingSaveLocationService(directoryAnswer: importsParent.path),
        ),
      );

      bloc.add(
        const OcptHomeImportProjectPackageRequestedEvent(
          packageFileTypeLabel: "Project package",
          destinationConfirmButtonText: "Import here",
        ),
      );

      final state = await waitForState(bloc, (state) => state.projectPackageImportError != null);

      expect(state.projectPackageImportError, OcptProjectPackageStatus.unsupportedPackageFormat);
      expect(state.projectPackageImportReport, isNull);
      expect(importsParent.listSync(), isEmpty);

      await bloc.close();
    });

    test("a cancelled open dialog does nothing at all", () async {
      final saveLocationService = RecordingSaveLocationService(directoryAnswer: importsParent.path);
      final bloc = buildBloc(
        fileSelectorManager: _FakeFileSelectorManager(),
        exportManager: OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: saveLocationService,
        ),
      );

      bloc.add(
        const OcptHomeImportProjectPackageRequestedEvent(
          packageFileTypeLabel: "Project package",
          destinationConfirmButtonText: "Import here",
        ),
      );
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.projectPackageImportReport, isNull);
      expect(state.projectPackageImportError, isNull);
      expect(
        saveLocationService.lastDirectoryConfirmButtonText,
        isNull,
        reason: "the folder picker is never reached once the open dialog was cancelled",
      );

      await bloc.close();
    });

    test("a cancelled folder picker does nothing at all", () async {
      final packagePath = await exportedPackage(p.join(tempDir.path, "movie.ocptz"));
      final bloc = buildBloc(
        fileSelectorManager: _FakeFileSelectorManager(result: XFile(packagePath)),
        exportManager: OcptExportManager(
          fileSelectorManager: const FileSelectorManager(),
          saveLocationService: RecordingSaveLocationService(),
        ),
      );

      bloc.add(
        const OcptHomeImportProjectPackageRequestedEvent(
          packageFileTypeLabel: "Project package",
          destinationConfirmButtonText: "Import here",
        ),
      );
      await waitForState(bloc, (state) => state.isBusy);
      final state = await waitForState(bloc, (state) => !state.isBusy);

      expect(state.projectPackageImportReport, isNull);
      expect(state.projectPackageImportError, isNull);
      expect(importsParent.listSync(), isEmpty);

      await bloc.close();
    });
  });
}
