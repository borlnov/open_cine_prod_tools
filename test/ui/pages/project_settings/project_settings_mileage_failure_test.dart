// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../ocpt_result_expectations.dart';

/// How long a handler that failed is given to emit anything: it must emit nothing at all.
const _quietPeriod = Duration(milliseconds: 300);

/// What the project settings bloc does when the database refuses a call on the mileage rates, or
/// cannot read them: the handler stops where the call failed and emits nothing, then goes through
/// once the refusal is lifted.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late String rateId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_settings_mileage_failure_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
    await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    rateId = await projectsManager.budgetFinancingService
        .createMileageRate(database: projectsManager.currentProject!.database, label: "Car")
        .valueOrFail;
    await projectsManager.budgetFinancingService
        .createMileageRate(database: projectsManager.currentProject!.database, label: "Van")
        .okOrFail;
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Run [statement] on the open project's database.
  Future<void> run(String statement) =>
      projectsManager.currentProject!.database.customStatement(statement);

  /// Make [verb] on the mileage rates fail with a database error.
  Future<void> refuse(String verb) => run(
    "CREATE TRIGGER refuse_${verb.toLowerCase()} BEFORE $verb ON budget_mileage_rates "
    "BEGIN SELECT RAISE(ABORT, 'refused'); END",
  );

  /// Lift the refusal [refuse] put on [verb].
  Future<void> lift(String verb) => run("DROP TRIGGER refuse_${verb.toLowerCase()}");

  /// Make the rows the [verb] writes unreadable afterwards: the write lands, the re-read fails.
  Future<void> poison(String verb) => run(
    "CREATE TRIGGER poison_${verb.toLowerCase()} AFTER $verb ON budget_mileage_rates "
    "BEGIN UPDATE budget_mileage_rates SET rate_per_km_milli_cents = 'unreadable'; END",
  );

  /// Mend what [poison] spoilt and lift its trigger.
  Future<void> mend(String verb) async {
    await run("DROP TRIGGER poison_${verb.toLowerCase()}");
    await run("UPDATE budget_mileage_rates SET rate_per_km_milli_cents = 0");
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

  /// The handlers, each with the event, the verb that fails the write and what proves it landed.
  final cases =
      <
        String,
        ({
          String verb,
          OcptProjectSettingsEvent Function() event,
          bool Function(OcptProjectSettingsState state) done,
        })
      >{
        "adding a rate": (
          verb: "INSERT",
          event: () => const OcptProjectSettingsMileageRateAddedEvent(),
          done: (state) => state.mileageRates.length == 3,
        ),
        "renaming a rate": (
          verb: "UPDATE",
          event: () =>
              OcptProjectSettingsMileageRateLabelChangedEvent(rateId: rateId, label: "Changed"),
          done: (state) => state.mileageRates.any((rate) => rate.label == "Changed"),
        ),
        "changing the amount of a rate": (
          verb: "UPDATE",
          event: () => OcptProjectSettingsMileageRateAmountChangedEvent(
            rateId: rateId,
            ratePerKmMilliCents: 7000,
          ),
          done: (state) => state.mileageRates.any((rate) => rate.ratePerKmMilliCents == 7000),
        ),
        "deleting a rate": (
          verb: "UPDATE",
          event: () => OcptProjectSettingsMileageRateDeletionConfirmedEvent(rateId: rateId),
          done: (state) => state.mileageRates.length == 1,
        ),
      };

  for (final entry in cases.entries) {
    final case_ = entry.value;
    test("${entry.key} stops where the write failed, and goes through once lifted", () async {
      final (bloc, emitted) = await loadedBloc();
      await refuse(case_.verb);

      bloc.add(case_.event());
      await Future<void>.delayed(_quietPeriod);

      expect(emitted, isEmpty);

      await lift(case_.verb);
      bloc.add(case_.event());
      await Future<void>.delayed(_quietPeriod);

      expect(emitted, isNotEmpty);
      expect(case_.done(bloc.state), isTrue);
    });

    test("${entry.key} emits nothing when the rates cannot be read back", () async {
      final (bloc, emitted) = await loadedBloc();
      await poison(case_.verb);

      bloc.add(case_.event());
      await Future<void>.delayed(_quietPeriod);

      expect(emitted, isEmpty);

      await mend(case_.verb);
    });
  }

  test("rates that cannot be read leave the page loading", () async {
    await run("ALTER TABLE budget_mileage_rates RENAME TO budget_mileage_rates_gone");
    final bloc = OcptProjectSettingsBloc(projectsManager: projectsManager);
    addTearDown(bloc.close);

    await Future<void>.delayed(_quietPeriod);

    expect(bloc.state.isLoading, isTrue);
  });
}
