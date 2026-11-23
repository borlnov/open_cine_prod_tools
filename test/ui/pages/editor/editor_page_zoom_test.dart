// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_page_zoom.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_control.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';
import '../../../ocpt_result_expectations.dart';
import 'editor_page_test_doubles.dart';

/// Run the tests of the editor page's page zoom: the status bar control and the shortcuts.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

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
      ..registerSingleton<OcptRouterManager>(RecordingRouterManager())
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      )
      ..registerSingleton<OcptSpellCheckManager>(
        OcptSpellCheckManager(loadAsset: loadMiniatureDictionaryAsset),
      );
  });

  tearDownAll(
    () => OcptGlobalManager.instance.managers.get<OcptSpellCheckManager>().disposeLifeCycle(),
  );

  setUp(() async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);
    await propertiesManager.isPageSimulationEnabled.store(false);
    await propertiesManager.styledPageZoom.delete();

    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_zoom_test_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);

    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: sampleText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  });

  tearDown(() async {
    await projectsManager.closeCurrentProject().okOrFail;
    await tempDir.delete(recursive: true);
  });

  /// Pump [OcptEditorPage] on a [width] wide surface.
  Future<void> pumpPage(WidgetTester tester, {double width = 1400}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptEditorPage()));
    await tester.pumpAndSettle();
  }

  /// Press [key] with Ctrl held.
  Future<void> pressWithCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  /// Get the zoom stored for the user.
  Future<OcptPageZoom?> storedZoom() => propertiesManager.styledPageZoom.load();

  testWidgets("the status bar shows the zoom control at 100 % by default", (tester) async {
    await pumpPage(tester);

    expect(find.byType(OcptEditorZoomControl), findsOneWidget);
    expect(find.text("100 %"), findsOneWidget);
  });

  testWidgets("the zoom stored for the user is shown on entry", (tester) async {
    await propertiesManager.styledPageZoom.store(OcptPageZoom.nearestStep(1.5));
    await pumpPage(tester);

    expect(find.text("150 %"), findsOneWidget);
  });

  testWidgets("the plus and minus buttons step the zoom and store it", (tester) async {
    await pumpPage(tester);
    final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

    await tester.tap(find.byTooltip(tr.editorZoomInTooltip));
    await tester.pumpAndSettle();
    expect(find.text("110 %"), findsOneWidget);
    expect(await storedZoom(), OcptPageZoom.nearestStep(1.1));

    await tester.tap(find.byTooltip(tr.editorZoomOutTooltip));
    await tester.tap(find.byTooltip(tr.editorZoomOutTooltip));
    await tester.pumpAndSettle();
    expect(find.text("90 %"), findsOneWidget);
    expect(await storedZoom(), OcptPageZoom.nearestStep(0.9));
  });

  testWidgets("the percentage opens the steps and the fit to width mode", (tester) async {
    await pumpPage(tester);
    final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

    await tester.tap(find.byTooltip(tr.editorZoomMenuTooltip));
    await tester.pumpAndSettle();
    for (final step in OcptPageZoom.steps) {
      expect(find.text("${OcptPageZoom.percentOf(step)} %"), findsWidgets);
    }

    await tester.tap(find.text(tr.editorZoomFitToWidth));
    await tester.pumpAndSettle();

    expect(await storedZoom(), const OcptPageZoom.fitToWidth());
    // The mode is a measure of the area, shown as a percentage in [50 %, 200 %].
    final percent = OcptPageZoom.percentOf(
      tester.widget<OcptEditorZoomControl>(find.byType(OcptEditorZoomControl)).factor,
    );
    expect(percent, inInclusiveRange(50, 200));
  });

  testWidgets("the buttons are withheld at the ends of the steps", (tester) async {
    await propertiesManager.styledPageZoom.store(OcptPageZoom.nearestStep(0.5));
    await pumpPage(tester);
    final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

    expect(find.byTooltip(tr.editorZoomOutTooltip), findsNothing);
    expect(find.byTooltip(tr.editorZoomInTooltip), findsOneWidget);

    await propertiesManager.styledPageZoom.store(OcptPageZoom.nearestStep(2));
    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester);
    expect(find.byTooltip(tr.editorZoomOutTooltip), findsOneWidget);
    expect(find.byTooltip(tr.editorZoomInTooltip), findsNothing);
  });

  testWidgets("Ctrl+=, Ctrl+- and Ctrl+0 zoom with the styled editor focused", (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byType(SuperEditor));
    await tester.pumpAndSettle();

    await pressWithCtrl(tester, LogicalKeyboardKey.equal);
    expect(find.text("110 %"), findsOneWidget);
    expect(await storedZoom(), OcptPageZoom.nearestStep(1.1));

    await pressWithCtrl(tester, LogicalKeyboardKey.minus);
    await pressWithCtrl(tester, LogicalKeyboardKey.minus);
    expect(find.text("90 %"), findsOneWidget);

    await pressWithCtrl(tester, LogicalKeyboardKey.digit0);
    expect(find.text("100 %"), findsOneWidget);
    expect(await storedZoom(), const OcptPageZoom.actualSize());
  });

  testWidgets("the shortcuts also zoom in raw mode, from the source field", (tester) async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    await pumpPage(tester);
    await tester.tap(find.byType(OcptEditorSourceField));
    await tester.pumpAndSettle();

    await pressWithCtrl(tester, LogicalKeyboardKey.equal);

    expect(find.text("110 %"), findsOneWidget);
  });

  testWidgets("a compact window has no zoom control and ignores the shortcuts", (tester) async {
    await pumpPage(tester, width: 700);
    await tester.tap(find.byType(SuperEditor));
    await tester.pumpAndSettle();

    expect(find.byType(OcptEditorZoomControl), findsNothing);

    await pressWithCtrl(tester, LogicalKeyboardKey.equal);

    expect(await storedZoom(), isNull);
  });
}
