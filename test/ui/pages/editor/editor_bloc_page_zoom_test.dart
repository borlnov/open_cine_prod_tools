// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_page_zoom.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'editor_bloc_test_doubles.dart';

/// Run the tests of the editor bloc's page zoom.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_zoom_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: testAppLanguageCode,
    );
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
    await propertiesManager.styledPageZoom.delete();
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Build a bloc wired to the test project.
  OcptEditorBloc buildBloc() => OcptEditorBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: InertExportManager(),
    parseDebounce: const Duration(milliseconds: 20),
    autosaveDebounce: const Duration(milliseconds: 60),
  );

  /// Wait for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptEditorState> waitForState(
    OcptEditorBloc bloc,
    bool Function(OcptEditorState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test("defaults to 100 % when nothing was ever stored", () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.styledPageZoom, const OcptPageZoom.actualSize());
    expect(state.pageZoomFactor, 1);

    await bloc.close();
  });

  test("loads the stored zoom on entry, a step or the fit to width mode", () async {
    await propertiesManager.styledPageZoom.store(OcptPageZoom.nearestStep(1.75));
    var bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);
    expect(state.pageZoomFactor, 1.75);
    await bloc.close();

    await propertiesManager.styledPageZoom.store(const OcptPageZoom.fitToWidth());
    bloc = buildBloc();
    state = await waitForState(bloc, (state) => !state.isLoading);
    expect(state.styledPageZoom.isFitToWidth, isTrue);

    await bloc.close();
  });

  test("brings a stored percentage out of the bounds back to the nearest step", () async {
    await propertiesManager.styledPageZoom.store(OcptPageZoom.tryParse("900"));
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.pageZoomFactor, 2);

    await bloc.close();
  });

  test("selecting a zoom emits it and stores it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(OcptEditorPageZoomSelectedEvent(zoom: OcptPageZoom.nearestStep(0.75)));
    final state = await waitForState(bloc, (state) => state.pageZoomFactor == 0.75);

    expect(state.styledPageZoom, OcptPageZoom.nearestStep(0.75));
    expect(await propertiesManager.styledPageZoom.load(), OcptPageZoom.nearestStep(0.75));

    await bloc.close();
  });

  test("stepping moves one step, stores it and stops at the bounds", () async {
    await propertiesManager.styledPageZoom.store(OcptPageZoom.nearestStep(1.75));
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorPageZoomSteppedEvent(direction: 1));
    await waitForState(bloc, (state) => state.pageZoomFactor == 2);
    expect(await propertiesManager.styledPageZoom.load(), OcptPageZoom.nearestStep(2));

    bloc.add(const OcptEditorPageZoomSteppedEvent(direction: 1));
    bloc.add(const OcptEditorPageZoomSteppedEvent(direction: -1));
    final state = await waitForState(bloc, (state) => state.pageZoomFactor == 1.75);
    expect(state.styledPageZoom, OcptPageZoom.nearestStep(1.75));

    await bloc.close();
  });

  test("stepping out of the fit to width mode starts from the measured factor", () async {
    await propertiesManager.styledPageZoom.store(const OcptPageZoom.fitToWidth());
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorFitPageZoomMeasuredEvent(factor: 1.3));
    final measured = await waitForState(bloc, (state) => state.measuredFitPageZoomFactor == 1.3);
    expect(measured.pageZoomFactor, 1.3);
    // What is measured is never stored: only the mode is.
    expect(await propertiesManager.styledPageZoom.load(), const OcptPageZoom.fitToWidth());

    bloc.add(const OcptEditorPageZoomSteppedEvent(direction: 1));
    final state = await waitForState(bloc, (state) => !state.styledPageZoom.isFitToWidth);

    expect(state.styledPageZoom, OcptPageZoom.nearestStep(1.5));
    expect(await propertiesManager.styledPageZoom.load(), OcptPageZoom.nearestStep(1.5));

    await bloc.close();
  });

  test(
    "a step the status bar's button is withheld on is refused, in the fit to width mode too",
    () async {
      await propertiesManager.styledPageZoom.store(const OcptPageZoom.fitToWidth());
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      // Close to the largest step: the plus button is withheld, so the shortcut goes nowhere.
      bloc.add(const OcptEditorFitPageZoomMeasuredEvent(factor: 1.95));
      await waitForState(bloc, (state) => state.measuredFitPageZoomFactor == 1.95);
      expect(OcptPageZoom.canStep(1, 1.95), isFalse);
      bloc.add(const OcptEditorPageZoomSteppedEvent(direction: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.styledPageZoom.isFitToWidth, isTrue);

      // Close to the smallest one, the same for the minus button.
      bloc.add(const OcptEditorFitPageZoomMeasuredEvent(factor: 0.52));
      await waitForState(bloc, (state) => state.measuredFitPageZoomFactor == 0.52);
      expect(OcptPageZoom.canStep(-1, 0.52), isFalse);
      bloc.add(const OcptEditorPageZoomSteppedEvent(direction: -1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.styledPageZoom.isFitToWidth, isTrue);

      await bloc.close();
    },
  );
}
