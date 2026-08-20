// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_package_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_page.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_empty_state.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_header.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_import_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_card.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_file_newer_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_package_skipped_files_dialog.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, and with
/// [ocptTheme]'s light theme so widgets reading its `OcptSpecificColors` extension (the project
/// card's poster tint) resolve one, just like the real app always does.
///
/// [navigatorKey] is only given by the tests that need a dialog to *close* again: the app closes
/// one through `OcptRouterManager.pop`, which drives a real `GoRouter` no widget test builds, so
/// those register a [_NavigatorKeyRouterManager] popping this very navigator instead.
Widget _wrapWithLocalization(Widget child, {GlobalKey<NavigatorState>? navigatorKey}) =>
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: ocptTheme.lightThemeData,
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      home: child,
    );

/// Pumps [child], localized, on a desktop-sized surface: the default test surface (800x600) is
/// too narrow for the home page header's three actions side by side, which this app never runs
/// at in practice (a resizable desktop window, not a fixed small canvas).
Future<void> _pumpHome(
  WidgetTester tester,
  Widget child, {
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_wrapWithLocalization(child, navigatorKey: navigatorKey));
}

/// A router manager whose [pop] closes the topmost route of [navigatorKey]'s own navigator.
///
/// The real one drives a `GoRouter` these tests never build, so every dialog of this app — which
/// all close through `OcptRouterManager.pop`, never `Navigator` — would stay on screen for ever
/// and the flow behind it would never resume. Popping the test's own navigator is the smallest
/// stand-in that keeps that rule honest in production code while letting a test click `Close`.
class _NavigatorKeyRouterManager extends OcptRouterManager {
  /// The key of the navigator the pumped [MaterialApp] builds.
  final GlobalKey<NavigatorState> navigatorKey;

  /// Class constructor
  _NavigatorKeyRouterManager({required this.navigatorKey});

  @override
  void pop<Y extends Object?>([Y? result]) => navigatorKey.currentState?.pop<Y>(result);

  /// The route the last [push] named, or null if none ever was.
  ///
  /// A push is recorded rather than performed: these tests stop at the home page, and none of them
  /// ever gets far enough to open a project.
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

/// A file selector manager answering with [result] instead of a native open-file dialog.
///
/// [result] is settable because the file it answers with is one the test only has once it has
/// written a package, while the manager itself has to be registered before the page — and the bloc
/// it builds — ever resolves it.
class _FakeFileSelectorManager extends FileSelectorManager {
  /// The file [openSelector] hands back, or null to answer as a cancelled dialog.
  XFile? result;

  /// Class constructor
  _FakeFileSelectorManager();

  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async =>
      // A cancelled native dialog reports success with no file, never a failure status — mirroring
      // FileSelectorManager.openSelector's own real behaviour.
      ResultWithBoolStatus<XFile>(status: BoolResultStatus.success, value: result);
}

/// A save location service answering [directoryAnswer] instead of showing the native folder picker
/// an import asks its destination through.
class _FakeSaveLocationService extends OcptSaveLocationService {
  /// The path [pickDirectory] hands back, or null to answer as a cancelled dialog.
  final String? directoryAnswer;

  /// Class constructor
  const _FakeSaveLocationService({this.directoryAnswer});

  @override
  Future<String?> pickDirectory({required String confirmButtonText}) async => directoryAnswer;
}

void main() {
  // HomePage builds its OcptHomeBloc internally via `OcptHomeBloc()`, which resolves every
  // manager it needs from globalGetIt() by default. We register real (but test-controlled)
  // instances of those managers in the app's actual GetIt instance once, matching how
  // OcptPropertiesManager's own test backs it with an in-memory store instead of mocking it.
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(OcptRouterManager())
      ..registerSingleton<FileSaverManager>(const FileSaverManager())
      ..registerSingleton<FileSelectorManager>(const FileSelectorManager())
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_home_page_test_");
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('shows the empty state when there are no recent projects', (tester) async {
    await _pumpHome(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.byType(OcptHomeEmptyState), findsOneWidget);
    expect(find.byType(OcptProjectCard), findsNothing);

    final context = tester.element(find.byType(HomePage));
    expect(find.text(Tr.of(context).homeEmptyStateTitle), findsOneWidget);
  });

  testWidgets('shows a card per recent project once loaded', (tester) async {
    final existingFile = File(p.join(tempDir.path, "movie.ocpt"))..writeAsStringSync("");
    await propertiesManager.addRecentProject(
      OcptRecentProjectModel(
        path: existingFile.path,
        name: "My Movie",
        lastOpenedAt: DateTime.now(),
      ),
    );

    await _pumpHome(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.byType(OcptHomeEmptyState), findsNothing);
    expect(find.byType(OcptProjectCard), findsOneWidget);
    expect(find.text("My Movie"), findsOneWidget);
  });

  testWidgets("a recent project whose file is missing is shown greyed out and can't be opened", (
    tester,
  ) async {
    final missingPath = p.join(tempDir.path, "missing.ocpt");
    await propertiesManager.addRecentProject(
      OcptRecentProjectModel(
        path: missingPath,
        name: "Missing Movie",
        lastOpenedAt: DateTime.now(),
      ),
    );

    await _pumpHome(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.byType(OcptProjectCard), findsOneWidget);

    final cardWidget = tester.widget<OcptProjectCard>(find.byType(OcptProjectCard));
    expect(cardWidget.entry.exists, isFalse);

    // The card is wrapped in a Tooltip explaining why it's disabled, instead of being tappable.
    final context = tester.element(find.byType(HomePage));
    expect(find.byTooltip(Tr.of(context).homeMissingFileTooltip), findsOneWidget);
    final inkWell = tester.widget<InkWell>(find.byKey(ValueKey(missingPath)));
    expect(inkWell.onTap, isNull);
  });

  testWidgets('the import action is shown in the header and the empty state', (tester) async {
    await _pumpHome(tester, const HomePage());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomePage));
    expect(find.text(Tr.of(context).homeImportAction), findsNWidgets(2));
  });

  testWidgets('tapping the import action calls back', (tester) async {
    var tapped = false;
    await _pumpHome(
      tester,
      OcptHomeHeader(
        onNewProject: () {},
        onOpenProject: () {},
        onImport: () => tapped = true,
        onOpenSettings: () {},
      ),
    );

    final context = tester.element(find.byType(OcptHomeHeader));
    await tester.tap(find.text(Tr.of(context).homeImportAction));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('Import… opens a modal offering a project and a screenplay', (tester) async {
    await _pumpHome(tester, const HomePage());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomePage));
    await tester.tap(find.text(Tr.of(context).homeImportAction).first);
    await tester.pumpAndSettle();

    expect(find.byType(OcptHomeImportDialog), findsOneWidget);
    expect(find.text(Tr.of(context).homeImportProjectTitle), findsOneWidget);
    expect(find.text(Tr.of(context).homeImportScreenplayTitle), findsOneWidget);
  });

  group("opening a project file from another build", () {
    /// Writes a project file at [filePath] stating [userVersion], and puts it on the home page as
    /// a recent project.
    ///
    /// Written through raw `sqlite3` rather than by creating a real project: everything the probe
    /// reads is the format number and `project_info`, and drift's own asynchronous work has no
    /// place inside a widget test's clock. What these tests are about is the sentence the user
    /// reads before anything happens to their file; the migration itself is covered where it runs.
    Future<void> addRecentProjectStatingFormat(String filePath, int userVersion) async {
      final database = sqlite3.open(filePath);
      database
        ..execute("CREATE TABLE project_info (name TEXT, app_version_at_creation TEXT)")
        ..execute("INSERT INTO project_info (name, app_version_at_creation) VALUES (?, ?)", [
          "My Movie",
          "9.9.9",
        ])
        ..execute("PRAGMA user_version = $userVersion")
        ..dispose();

      await propertiesManager.addRecentProject(
        OcptRecentProjectModel(path: filePath, name: "My Movie", lastOpenedAt: DateTime.now()),
      );
    }

    testWidgets("an older one is answered for, the copy named where it will be kept", (
      tester,
    ) async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await addRecentProjectStatingFormat(filePath, OcptProjectDatabase.currentSchemaVersion - 1);

      await _pumpHome(tester, const HomePage());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey(filePath)));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomePage));
      expect(find.byType(OcptConfirmDialog), findsOneWidget);
      expect(find.text(Tr.of(context).homeMigrateProjectTitle), findsOneWidget);
      expect(
        find.textContaining(
          projectsManager.probeProjectFile(filePath: filePath).suggestedBackupPath!,
        ),
        findsOneWidget,
        reason: "the promise the dialog makes is the very path the open then writes to",
      );
      expect(find.text(Tr.of(context).homeMigrateProjectConfirmAction), findsOneWidget);
    });

    testWidgets("a newer one is refused, naming the build that wrote it", (tester) async {
      final filePath = p.join(tempDir.path, "movie.ocpt");
      await addRecentProjectStatingFormat(filePath, OcptProjectDatabase.currentSchemaVersion + 1);

      await _pumpHome(tester, const HomePage());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey(filePath)));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomePage));
      expect(find.byType(OcptProjectFileNewerDialog), findsOneWidget);
      expect(find.text(Tr.of(context).homeProjectFileNewerTitle), findsOneWidget);
      expect(
        find.byType(OcptConfirmDialog),
        findsNothing,
        reason: "there is nothing to confirm: this build cannot open that file at all",
      );
    });
  });
  group("importing a project package", () {
    /// The navigator the pumped app builds, which [_NavigatorKeyRouterManager] closes the dialogs
    /// of — the modal offering the two kinds of import, and the report the landing states.
    late GlobalKey<NavigatorState> navigatorKey;

    /// Where an import is told to put the folder it creates.
    late Directory importsParent;

    /// The stand-in for the native open-file dialog, answering the package the test wrote.
    late _FakeFileSelectorManager fileSelectorManager;

    setUp(() async {
      navigatorKey = GlobalKey<NavigatorState>();
      importsParent = Directory(p.join(tempDir.path, "imports"))..createSync(recursive: true);
      fileSelectorManager = _FakeFileSelectorManager();

      // Registered here rather than inside the tests: swapping a singleton is real asynchronous
      // work, and a widget test's own clock is no place for any of it.
      final managers = OcptGlobalManager.instance.managers;
      await managers.unregister<OcptRouterManager>();
      await managers.unregister<FileSelectorManager>();
      await managers.unregister<OcptExportManager>();

      managers
        ..registerSingleton<OcptRouterManager>(
          _NavigatorKeyRouterManager(navigatorKey: navigatorKey),
        )
        ..registerSingleton<FileSelectorManager>(fileSelectorManager)
        ..registerSingleton<OcptExportManager>(
          OcptExportManager(
            fileSelectorManager: const FileSelectorManager(),
            saveLocationService: _FakeSaveLocationService(directoryAnswer: importsParent.path),
          ),
        );
    });

    tearDown(() async {
      // The real managers this file registers once are put back, so the tests around this group
      // keep finding the ones their own set-up left in place.
      final managers = OcptGlobalManager.instance.managers;
      await managers.unregister<OcptRouterManager>();
      await managers.unregister<FileSelectorManager>();
      await managers.unregister<OcptExportManager>();

      managers
        ..registerSingleton<OcptRouterManager>(OcptRouterManager())
        ..registerSingleton<FileSelectorManager>(const FileSelectorManager())
        ..registerSingleton<OcptExportManager>(
          OcptExportManager(fileSelectorManager: const FileSelectorManager()),
        );
    });

    /// Writes a package holding a project that references [missingLabel], if given, at a path
    /// nothing is at — and hands it to the open-file dialog's stand-in.
    ///
    /// The project inside is built through raw `sqlite3` rather than by creating a real one, for
    /// the reason the group above gives: drift's own asynchronous work has no place inside a
    /// widget test's clock. It is stamped **one format ahead of this build** on purpose — the
    /// package then lands as a file the compatibility gate refuses, which is what lets these tests
    /// watch the whole landing sequence through to the open without drift ever being reached.
    ///
    /// The writing itself runs through [WidgetTester.runAsync]: zipping a file is real I/O, and
    /// real I/O never completes under the faked clock a widget test otherwise runs on.
    Future<void> writePackageOf(WidgetTester tester, {String? missingLabel}) async {
      final projectPath = p.join(tempDir.path, "source", "movie.ocpt");
      Directory(p.dirname(projectPath)).createSync(recursive: true);

      final database = sqlite3.open(projectPath);
      database
        ..execute("CREATE TABLE project_info (name TEXT, app_version_at_creation TEXT)")
        ..execute("INSERT INTO project_info (name, app_version_at_creation) VALUES (?, ?)", [
          "My Movie",
          "9.9.9",
        ])
        ..execute(
          "CREATE TABLE assets (id TEXT, path TEXT, label TEXT, is_deleted INTEGER DEFAULT 0)",
        );
      if (missingLabel != null) {
        database.execute("INSERT INTO assets (id, path, label) VALUES (?, ?, ?)", [
          "asset-1",
          p.join(tempDir.path, "source", "gone.pdf"),
          missingLabel,
        ]);
      }
      database
        ..execute("PRAGMA user_version = ${OcptProjectDatabase.currentSchemaVersion + 1}")
        ..dispose();

      final packagePath = p.join(tempDir.path, "sent", "My Movie.ocptz");
      await tester.runAsync(() async {
        final exported = await const OcptProjectPackageService().writePackage(
          projectFilePath: projectPath,
          packageFilePath: packagePath,
          projectName: "My Movie",
          appVersion: "0.1.0",
          exportedAt: DateTime.utc(2026, 8, 19),
        );
        expect(exported.status, OcptProjectPackageStatus.ok);
      });

      fileSelectorManager.result = XFile(packagePath);
    }

    /// Walks the page from `Import…` to the card offering a project, and lets the import that
    /// follows actually run.
    ///
    /// The pause is what makes this work: the tap, the modal closing and every rebuild happen on
    /// the test's faked clock, but the unpacking behind them is real file work that only ever
    /// progresses while [WidgetTester.runAsync] hands the real event loop back. The settle that
    /// follows is what draws whatever the bloc emitted once it had.
    Future<void> importTheProject(WidgetTester tester) async {
      await _pumpHome(tester, const HomePage(), navigatorKey: navigatorKey);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomePage));
      await tester.tap(find.text(Tr.of(context).homeImportAction).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text(Tr.of(context).homeImportProjectTitle));
      await tester.pumpAndSettle();

      // Several rounds rather than one: the unpacking, the report it emits, the open that follows
      // and the gate's own verdict each hand control back to the real event loop, and each needs a
      // frame drawn on the faked one before the next can start.
      for (var round = 0; round < 4; round++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pumpAndSettle();
      }
    }

    testWidgets("states the files that did not travel before opening what landed", (tester) async {
      await writePackageOf(tester, missingLabel: "Autorisation mairie");

      await importTheProject(tester);

      final context = tester.element(find.byType(HomePage));
      expect(find.byType(OcptProjectPackageSkippedFilesDialog), findsOneWidget);
      expect(find.textContaining("Autorisation mairie"), findsOneWidget);
      expect(
        find.byType(OcptProjectFileNewerDialog),
        findsNothing,
        reason: "the project is only opened once the report has been read",
      );

      await tester.tap(find.text(Tr.of(context).homeImportSkippedFilesCloseAction));
      await tester.pumpAndSettle();

      // The landed file is one format ahead of this build, so reaching the compatibility gate is
      // exactly what this refusal proves: the import ends by opening what it just wrote, through
      // the very door every other project file goes through.
      expect(
        find.byType(OcptProjectFileNewerDialog),
        findsOneWidget,
        reason: "dismissing the report is what lets the landed project reach the gate",
      );
    });

    testWidgets("says nothing when the package carried every file it referenced", (tester) async {
      await writePackageOf(tester);

      await importTheProject(tester);

      // A package that travelled whole has nothing to report: the project opening is the report.
      expect(find.byType(OcptProjectPackageSkippedFilesDialog), findsNothing);
      expect(find.byType(OcptProjectFileNewerDialog), findsOneWidget);
    });

    testWidgets("lands the project in a folder of its own inside the picked one", (tester) async {
      await writePackageOf(tester);

      await importTheProject(tester);

      expect(
        File(p.join(importsParent.path, "My Movie", "My Movie.ocpt")).existsSync(),
        isTrue,
        reason: "the display name the manifest carries is what names the folder and the file",
      );
    });
  });
}
