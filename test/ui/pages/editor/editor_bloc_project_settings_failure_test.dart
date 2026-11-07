// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../ocpt_result_expectations.dart';
import '../project_settings_read_test_doubles.dart';
import 'editor_bloc_test_doubles.dart';

/// What the editor does when the project file fails a setting it reads or writes: the load stays
/// loading, a page setup that cannot be written is neither stored nor applied, and a re-read of the
/// settings that fails keeps what the editor showed, then each goes through once the file can.
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
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_settings_failure_test_");
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
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Give the bloc time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 300);

  /// Run [statement] on the open project's database.
  Future<void> run(String statement) =>
      projectsManager.currentProject!.database.customStatement(statement);

  /// Build an editor bloc, which starts loading at once.
  OcptEditorBloc build() {
    final bloc = OcptEditorBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: RecordingRouterManager(),
      exportManager: InertExportManager(),
    );
    addTearDown(bloc.close);

    return bloc;
  }

  test(
    "stays loading while the screenplay language cannot be read, and loads once it can",
    () async {
      await run("ALTER TABLE project_info RENAME TO project_info_gone");

      final bloc = build();
      await settle();

      expect(bloc.state.isLoading, isTrue);

      await run("ALTER TABLE project_info_gone RENAME TO project_info");
      bloc.add(const AsyncInitEvent());
      await settle();

      expect(bloc.state.isLoading, isFalse);
    },
  );

  test("a page setup that cannot be written is neither stored nor applied", () async {
    final bloc = build();
    await settle();
    final stateBefore = bloc.state;
    final marginsBefore = await propertiesManager.pageMargins.load();
    const changed = OcptPageSetup(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(leftInches: 2, rightInches: 2, topInches: 2, bottomInches: 2),
    );
    await run(
      "CREATE TRIGGER refuse_update BEFORE UPDATE ON project_info "
      "BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );

    bloc.add(const OcptEditorPageSetupChangedEvent(pageSetup: changed));
    await settle();

    expect(bloc.state, same(stateBefore));
    expect(await propertiesManager.pageMargins.load(), marginsBefore);
    expect(
      await projectsManager.loadCurrentProjectPageFormat().maybeValueOrFail,
      OcptPageFormat.usLetter,
    );

    await run("DROP TRIGGER refuse_update");
    bloc.add(const OcptEditorPageSetupChangedEvent(pageSetup: changed));
    await settle();

    expect(bloc.state.pageSetup, changed);
    expect(await propertiesManager.pageMargins.load(), changed.margins);
    expect(
      await projectsManager.loadCurrentProjectPageFormat().maybeValueOrFail,
      OcptPageFormat.a4,
    );
  });

  test("keeps its page format and language when the settings changed and cannot be read", () async {
    final bloc = build();
    await settle();
    final stateBefore = bloc.state;
    await projectsManager.saveCurrentProjectPageFormat(OcptPageFormat.a4).okOrFail;
    await projectsManager.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.fr).okOrFail;
    await run("ALTER TABLE project_info RENAME TO project_info_gone");

    bloc.add(const OcptEditorProjectSettingsChangedEvent());
    await settle();

    expect(bloc.state, same(stateBefore));

    await run("ALTER TABLE project_info_gone RENAME TO project_info");
    bloc.add(const OcptEditorProjectSettingsChangedEvent());
    await settle();

    expect(bloc.state.pageSetup.format, OcptPageFormat.a4);
    expect(bloc.state.screenplayLanguage, OcptScreenplayLanguage.fr);
  });

  group("with one setting refused while the others read", () {
    late RefusingSettingsProjectsManager refusing;

    setUp(() async {
      refusing = RefusingSettingsProjectsManager(propertiesManager: propertiesManager);
      await refusing.initLifeCycle();
      await refusing.openProject(filePath: projectsManager.currentProject!.path);
    });

    tearDown(() async {
      await refusing.disposeLifeCycle();
    });

    /// Build an editor bloc over the manager that refuses.
    OcptEditorBloc buildRefused() {
      final bloc = OcptEditorBloc(
        projectsManager: refusing,
        propertiesManager: propertiesManager,
        routerManager: RecordingRouterManager(),
        exportManager: InertExportManager(),
      );
      addTearDown(bloc.close);

      return bloc;
    }

    for (final setting in ["language", "pageFormat"]) {
      test("stays loading while the $setting cannot be read, and loads once it can", () async {
        refusing.refused.add(setting);

        final bloc = buildRefused();
        await settle();

        expect(bloc.state.isLoading, isTrue);

        refusing.refused.clear();
        bloc.add(const AsyncInitEvent());
        await settle();

        expect(bloc.state.isLoading, isFalse);
      });
    }

    test("keeps its state when the page format cannot be read again", () async {
      await refusing.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.fr).okOrFail;
      final bloc = buildRefused();
      await settle();
      await refusing.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb).okOrFail;
      final stateBefore = bloc.state;
      refusing.refused.add("pageFormat");

      bloc.add(const OcptEditorProjectSettingsChangedEvent());
      await settle();

      expect(bloc.state, same(stateBefore));
    });

    test("applies the page format the first read gave when the language read is refused", () async {
      await refusing.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.fr).okOrFail;
      final bloc = buildRefused();
      await settle();
      await refusing.saveCurrentProjectPageFormat(OcptPageFormat.a4).okOrFail;
      await refusing.saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb).okOrFail;
      refusing.refused.add("language");

      bloc.add(const OcptEditorProjectSettingsChangedEvent());
      await settle();

      expect(bloc.state.pageSetup.format, OcptPageFormat.a4);
      expect(bloc.state.screenplayLanguage, OcptScreenplayLanguage.fr);
    });
  });
}
