// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../project_settings_read_test_doubles.dart';

/// How long a handler that failed is given to emit anything: it must emit nothing at all.
const _quietPeriod = Duration(milliseconds: 300);

/// What the project settings bloc does when the project file refuses the write of a setting, or
/// cannot read the settings when it opens: the handler stops where the call failed and emits
/// nothing, the row keeps what it held, and the same event goes through once the refusal is lifted.
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_settings_write_failure_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
    await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Run [statement] on the open project's database.
  Future<void> run(String statement) =>
      projectsManager.currentProject!.database.customStatement(statement);

  /// Read the whole `project_info` row of the open project.
  Future<OcptProjectInfoRow> info() {
    final database = projectsManager.currentProject!.database;

    return database.select(database.ocptProjectInfoTable).getSingle();
  }

  /// Build a bloc and wait for its first load to end, then record every state it emits from there.
  Future<(OcptProjectSettingsBloc, List<OcptProjectSettingsState>)> loadedBloc() async {
    final bloc = OcptProjectSettingsBloc(projectsManager: projectsManager);
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    final emitted = <OcptProjectSettingsState>[];
    final subscription = bloc.stream.listen(emitted.add);
    addTearDown(subscription.cancel);

    return (bloc, emitted);
  }

  /// The handlers, each with its event and what proves it landed.
  final cases =
      <
        String,
        ({
          OcptProjectSettingsEvent event,
          bool Function(OcptProjectSettingsState state) done,
          bool Function(OcptProjectInfoRow row) stored,
        })
      >{
        "the currency": (
          event: const OcptProjectSettingsCurrencyChangedEvent(currencyCode: "GBP"),
          done: (state) => state.currencyCode == "GBP",
          stored: (row) => row.currencyCode == "GBP",
        ),
        "the page format": (
          event: const OcptProjectSettingsPageFormatChangedEvent(pageFormat: OcptPageFormat.a4),
          done: (state) => state.pageFormat == OcptPageFormat.a4,
          stored: (row) => row.pageFormat == OcptPageFormat.a4,
        ),
        "the minimum rest": (
          event: const OcptProjectSettingsMinimumRestMinutesChangedEvent(minutes: 660),
          done: (state) => state.minimumRestMinutes == 660,
          stored: (row) => row.minimumRestMinutes == 660,
        ),
        "the default VAT rate": (
          event: const OcptProjectSettingsDefaultVatRateBasisPointsChangedEvent(basisPoints: 2000),
          done: (state) => state.defaultVatRateBasisPoints == 2000,
          stored: (row) => row.defaultVatRateBasisPoints == 2000,
        ),
        "the meal price": (
          event: const OcptProjectSettingsMealPriceCentsChangedEvent(cents: 1200),
          done: (state) => state.mealPriceCents == 1200,
          stored: (row) => row.mealPriceCents == 1200,
        ),
        "the buffet price": (
          event: const OcptProjectSettingsBuffetPriceCentsChangedEvent(cents: 400),
          done: (state) => state.buffetPriceCents == 400,
          stored: (row) => row.snackPriceCents == 400,
        ),
        "the screenplay language": (
          event: const OcptProjectSettingsScreenplayLanguageChangedEvent(
            screenplayLanguage: OcptScreenplayLanguage.fr,
          ),
          done: (state) => state.screenplayLanguage == OcptScreenplayLanguage.fr,
          stored: (row) => row.screenplayLanguage == OcptScreenplayLanguage.fr,
        ),
      };

  for (final entry in cases.entries) {
    final case_ = entry.value;
    test(
      "writing ${entry.key} stops where the write failed, and goes through once lifted",
      () async {
        final (bloc, emitted) = await loadedBloc();
        final before = await info();
        await run(
          "CREATE TRIGGER refuse_update BEFORE UPDATE ON project_info "
          "BEGIN SELECT RAISE(ABORT, 'refused'); END",
        );

        bloc.add(case_.event);
        await Future<void>.delayed(_quietPeriod);

        expect(emitted, isEmpty);
        expect(case_.done(bloc.state), isFalse);
        expect(bloc.state.hasChanged, isFalse);
        expect(await info(), before);

        await run("DROP TRIGGER refuse_update");
        bloc.add(case_.event);
        await Future<void>.delayed(_quietPeriod);

        expect(emitted, isNotEmpty);
        expect(case_.done(bloc.state), isTrue);
        expect(bloc.state.hasChanged, isTrue);
        expect(case_.stored(await info()), isTrue);
      },
    );
  }

  test("a write refused for one setting does not stop the next one", () async {
    final (bloc, emitted) = await loadedBloc();
    await run(
      "CREATE TRIGGER refuse_update BEFORE UPDATE ON project_info "
      "WHEN NEW.currency_code IS NOT OLD.currency_code "
      "BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );

    bloc.add(const OcptProjectSettingsCurrencyChangedEvent(currencyCode: "GBP"));
    await Future<void>.delayed(_quietPeriod);

    expect(emitted, isEmpty);

    bloc.add(const OcptProjectSettingsMealPriceCentsChangedEvent(cents: 1200));
    await Future<void>.delayed(_quietPeriod);

    expect(bloc.state.mealPriceCents, 1200);
    expect((await info()).mealPriceCents, 1200);
    expect((await info()).currencyCode, isNot("GBP"));
  });

  test("stays loading while the settings cannot be read, and loads once they can", () async {
    await run("ALTER TABLE project_info RENAME TO project_info_gone");
    final bloc = OcptProjectSettingsBloc(projectsManager: projectsManager);
    addTearDown(bloc.close);
    await Future<void>.delayed(_quietPeriod);

    expect(bloc.state.isLoading, isTrue);

    await run("ALTER TABLE project_info_gone RENAME TO project_info");
    bloc.add(const AsyncInitEvent());
    await Future<void>.delayed(_quietPeriod);

    expect(bloc.state.isLoading, isFalse);
  });

  for (final setting in [
    "currency",
    "pageFormat",
    "minimumRest",
    "vatRate",
    "mealPrice",
    "buffetPrice",
    "language",
  ]) {
    test("stays loading while only the $setting cannot be read, and loads once it can", () async {
      final refusing = RefusingSettingsProjectsManager(propertiesManager: propertiesManager);
      await refusing.initLifeCycle();
      addTearDown(refusing.disposeLifeCycle);
      await refusing.openProject(filePath: projectsManager.currentProject!.path);
      refusing.refused.add(setting);
      final bloc = OcptProjectSettingsBloc(projectsManager: refusing);
      addTearDown(bloc.close);
      await Future<void>.delayed(_quietPeriod);

      expect(bloc.state.isLoading, isTrue);

      refusing.refused.clear();
      bloc.add(const AsyncInitEvent());
      await Future<void>.delayed(_quietPeriod);

      expect(bloc.state.isLoading, isFalse);
    });
  }
}
