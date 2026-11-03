// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account_seed.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../ocpt_result_expectations.dart';
import '../../project_settings_read_test_doubles.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// What a test needs to drive one mode through the reads of the settings.
typedef _Mode = ({
  /// Tell whether the mode is still loading.
  bool Function() isLoading,

  /// Ask the mode to load again.
  void Function() reload,

  /// Tell the mode the settings changed.
  void Function() changed,

  /// Get the state the mode shows now.
  Object Function() state,

  /// Get the reload epoch of the mode.
  int Function() epoch,
});

/// The accounts a budget is seeded with.
const _seed = [
  OcptBudgetAccountSeed(id: "seed-1", code: "1", label: "Poste one", simpleLabel: "P1"),
  OcptBudgetAccountSeed(id: "seed-2", code: "2", label: "Poste two", simpleLabel: "P2"),
];

/// What every mode that reads a setting of the project does when the project file really fails
/// that read: it stays loading, or keeps what it showed and its reload epoch, and it reads on once
/// the file can be read.
///
/// The settings become unreadable by renaming the `project_info` table, which no other read of a
/// mode touches, so the read that fails is the setting's own.
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

  /// Make the settings of the open project unreadable.
  Future<void> spoil() => projectsManager.currentProject!.database.customStatement(
    "ALTER TABLE project_info RENAME TO project_info_gone",
  );

  /// Make the settings of the open project readable again.
  Future<void> mend() => projectsManager.currentProject!.database.customStatement(
    "ALTER TABLE project_info_gone RENAME TO project_info",
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_settings_reads_failure_test_");
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

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  /// Build the export manager the modes are handed.
  OcptExportManager exportManager() =>
      OcptExportManager(fileSelectorManager: const FileSelectorManager());

  group("the shot list", () {
    OcptShotListBloc build() {
      final mode = OcptShotListBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: exportManager(),
      );
      addTearDown(mode.close);

      return mode;
    }

    test("stays loading while the page format cannot be read, and loads once it can", () async {
      await spoil();

      final mode = build();
      await settle();

      expect(mode.state.isLoading, isTrue);

      await mend();
      mode.add(const AsyncInitEvent());
      await settle();

      expect(mode.state.isLoading, isFalse);
    });

    test("keeps its page setup and epoch when the settings changed and cannot be read", () async {
      final mode = build();
      await settle();
      final pageSetup = mode.state.pageSetup;
      final epoch = mode.state.reloadEpoch;
      await projectsManager.saveCurrentProjectPageFormat(OcptPageFormat.a4).okOrFail;
      await spoil();

      mode.add(const OcptShotListProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.pageSetup, same(pageSetup));
      expect(mode.state.reloadEpoch, epoch);

      await mend();
      mode.add(const OcptShotListProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.pageSetup.format, OcptPageFormat.a4);
    });
  });

  group("the breakdown", () {
    OcptBreakdownBloc build() {
      final mode = OcptBreakdownBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: exportManager(),
      );
      addTearDown(mode.close);

      return mode;
    }

    test("stays loading while the page format cannot be read, and loads once it can", () async {
      await spoil();

      final mode = build();
      await settle();

      expect(mode.state.isLoading, isTrue);

      await mend();
      mode.add(const AsyncInitEvent());
      await settle();

      expect(mode.state.isLoading, isFalse);
    });

    test("keeps its page setup and epoch when the settings changed and cannot be read", () async {
      final mode = build();
      await settle();
      final pageSetup = mode.state.pageSetup;
      final epoch = mode.state.reloadEpoch;
      await projectsManager.saveCurrentProjectPageFormat(OcptPageFormat.a4).okOrFail;
      await spoil();

      mode.add(const OcptBreakdownProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.pageSetup, same(pageSetup));
      expect(mode.state.reloadEpoch, epoch);

      await mend();
      mode.add(const OcptBreakdownProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.pageSetup.format, OcptPageFormat.a4);
    });
  });

  group("the resources", () {
    OcptResourcesBloc build() {
      final mode = OcptResourcesBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: exportManager(),
      );
      addTearDown(mode.close);

      return mode;
    }

    test("stay loading while the settings cannot be read, and load once they can", () async {
      await spoil();

      final mode = build();
      await settle();

      expect(mode.state.isLoading, isTrue);

      await mend();
      mode.add(const AsyncInitEvent());
      await settle();

      expect(mode.state.isLoading, isFalse);
    });

    test("keep their currency and epoch when the settings changed and cannot be read", () async {
      final mode = build();
      await settle();
      final epoch = mode.state.reloadEpoch;
      final currencyCode = mode.state.currencyCode;
      await projectsManager.saveCurrentProjectCurrencyCode("GBP").okOrFail;
      await spoil();

      mode.add(const OcptResourcesProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.currencyCode, currencyCode);
      expect(mode.state.reloadEpoch, epoch);

      await mend();
      mode.add(const OcptResourcesProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.currencyCode, "GBP");
    });
  });

  group("the schedule", () {
    OcptScheduleBloc build() {
      final mode = OcptScheduleBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: exportManager(),
      );
      addTearDown(mode.close);

      return mode;
    }

    test("stays loading while the settings cannot be read, and loads once they can", () async {
      await spoil();

      final mode = build();
      await settle();

      expect(mode.state.isLoading, isTrue);

      await mend();
      mode.add(const AsyncInitEvent());
      await settle();

      expect(mode.state.isLoading, isFalse);
    });

    test("keeps its minimum rest and epoch when the settings changed and cannot be read", () async {
      final mode = build();
      await settle();
      final epoch = mode.state.reloadEpoch;
      await projectsManager.saveCurrentProjectMinimumRestMinutes(660).okOrFail;
      await spoil();

      mode.add(const OcptScheduleProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.minimumRestMinutes, isNull);
      expect(mode.state.reloadEpoch, epoch);

      await mend();
      mode.add(const OcptScheduleProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.minimumRestMinutes, 660);
    });
  });

  group("the budget", () {
    OcptBudgetBloc build() {
      final mode = OcptBudgetBloc(
        seed: _seed,
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _SilentRouterManager(),
        exportManager: exportManager(),
      );
      addTearDown(mode.close);

      return mode;
    }

    test("stays loading while the settings cannot be read, and loads once they can", () async {
      await spoil();

      final mode = build();
      await settle();

      expect(mode.state.isLoading, isTrue);

      await mend();
      mode.add(const AsyncInitEvent());
      await settle();

      expect(mode.state.isLoading, isFalse);
    });

    test("keeps its currency and epoch when the settings changed and cannot be read", () async {
      final mode = build();
      await settle();
      final epoch = mode.state.reloadEpoch;
      final currencyCode = mode.state.currencyCode;
      await projectsManager.saveCurrentProjectCurrencyCode("GBP").okOrFail;
      await spoil();

      mode.add(const OcptBudgetProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.currencyCode, currencyCode);
      expect(mode.state.reloadEpoch, epoch);

      await mend();
      mode.add(const OcptBudgetProjectSettingsChangedEvent());
      await settle();

      expect(mode.state.currencyCode, "GBP");
    });
  });

  group("one setting refused while the others read", () {
    late RefusingSettingsProjectsManager refusing;

    setUp(() async {
      refusing = RefusingSettingsProjectsManager(propertiesManager: propertiesManager);
      await refusing.initLifeCycle();
      await refusing.openProject(filePath: projectsManager.currentProject!.path);
    });

    tearDown(() async {
      await refusing.disposeLifeCycle();
    });

    /// The modes, each with the settings its load reads, the ones its re-read reads and how to
    /// drive it.
    final modes =
        <
          String,
          ({
            Set<String> loads,
            Set<String> rereads,
            _Mode Function(RefusingSettingsProjectsManager) build,
          })
        >{
          "the shot list": (
            loads: {"pageFormat"},
            rereads: {"pageFormat"},
            build: (manager) {
              final mode = OcptShotListBloc(
                projectsManager: manager,
                propertiesManager: propertiesManager,
                routerManager: _SilentRouterManager(),
                exportManager: exportManager(),
              );
              addTearDown(mode.close);

              return (
                isLoading: () => mode.state.isLoading,
                reload: () => mode.add(const AsyncInitEvent()),
                changed: () => mode.add(const OcptShotListProjectSettingsChangedEvent()),
                state: () => mode.state,
                epoch: () => mode.state.reloadEpoch,
              );
            },
          ),
          "the breakdown": (
            loads: {"pageFormat"},
            rereads: {"pageFormat"},
            build: (manager) {
              final mode = OcptBreakdownBloc(
                projectsManager: manager,
                propertiesManager: propertiesManager,
                routerManager: _SilentRouterManager(),
                exportManager: exportManager(),
              );
              addTearDown(mode.close);

              return (
                isLoading: () => mode.state.isLoading,
                reload: () => mode.add(const AsyncInitEvent()),
                changed: () => mode.add(const OcptBreakdownProjectSettingsChangedEvent()),
                state: () => mode.state,
                epoch: () => mode.state.reloadEpoch,
              );
            },
          ),
          "the resources": (
            loads: {"currency", "pageFormat"},
            rereads: {"currency"},
            build: (manager) {
              final mode = OcptResourcesBloc(
                projectsManager: manager,
                propertiesManager: propertiesManager,
                routerManager: _SilentRouterManager(),
                exportManager: exportManager(),
              );
              addTearDown(mode.close);

              return (
                isLoading: () => mode.state.isLoading,
                reload: () => mode.add(const AsyncInitEvent()),
                changed: () => mode.add(const OcptResourcesProjectSettingsChangedEvent()),
                state: () => mode.state,
                epoch: () => mode.state.reloadEpoch,
              );
            },
          ),
          "the schedule": (
            loads: {"pageFormat", "minimumRest"},
            rereads: {"pageFormat", "minimumRest"},
            build: (manager) {
              final mode = OcptScheduleBloc(
                projectsManager: manager,
                propertiesManager: propertiesManager,
                routerManager: _SilentRouterManager(),
                exportManager: exportManager(),
              );
              addTearDown(mode.close);

              return (
                isLoading: () => mode.state.isLoading,
                reload: () => mode.add(const AsyncInitEvent()),
                changed: () => mode.add(const OcptScheduleProjectSettingsChangedEvent()),
                state: () => mode.state,
                epoch: () => mode.state.reloadEpoch,
              );
            },
          ),
          "the budget": (
            loads: {"currency", "vatRate", "mealPrice", "buffetPrice", "pageFormat"},
            rereads: {"currency", "vatRate", "mealPrice", "buffetPrice"},
            build: (manager) {
              final mode = OcptBudgetBloc(
                seed: _seed,
                projectsManager: manager,
                propertiesManager: propertiesManager,
                routerManager: _SilentRouterManager(),
                exportManager: exportManager(),
              );
              addTearDown(mode.close);

              return (
                isLoading: () => mode.state.isLoading,
                reload: () => mode.add(const AsyncInitEvent()),
                changed: () => mode.add(const OcptBudgetProjectSettingsChangedEvent()),
                state: () => mode.state,
                epoch: () => mode.state.reloadEpoch,
              );
            },
          ),
        };

    for (final entry in modes.entries) {
      for (final setting in entry.value.loads) {
        test("${entry.key} stay loading while the $setting cannot be read", () async {
          refusing.refused.add(setting);

          final mode = entry.value.build(refusing);
          await settle();

          expect(mode.isLoading(), isTrue);

          refusing.refused.clear();
          mode.reload();
          await settle();

          expect(mode.isLoading(), isFalse);
        });
      }

      for (final setting in entry.value.rereads) {
        test("${entry.key} keep their state when the $setting cannot be read again", () async {
          final mode = entry.value.build(refusing);
          await settle();
          final state = mode.state();
          final epoch = mode.epoch();
          refusing.refused.add(setting);

          mode.changed();
          await settle();

          expect(mode.state(), same(state));
          expect(mode.epoch(), epoch);

          refusing.refused.clear();
          mode.changed();
          await settle();

          expect(mode.state(), isNot(same(state)));
        });
      }
    }
  });
}
