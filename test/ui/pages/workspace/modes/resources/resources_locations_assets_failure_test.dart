// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_locations_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _RecordingRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// What the locations bloc does when the database refuses a write on a referenced file: each
/// handler raises the mode's write error and leaves the reference as it was, and goes on once the
/// refusal is lifted.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptResourcesBloc modeBloc;
  late OcptResourcesLocationsBloc locationsBloc;
  late String photoId;
  late String permitId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Wait for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_assets_failure_test_");
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

    final database = projectsManager.currentProject!.database;
    final locationId = (await projectsManager.locationsService.createLocation(
      database: database,
      name: "Hangar",
    ))!;
    photoId = (await projectsManager.locationsService.addLocationPhoto(
      database: database,
      locationId: locationId,
      path: "/photos/hangar.jpg",
    ))!;
    permitId = (await projectsManager.locationsService.setPermitDocument(
      database: database,
      locationId: locationId,
      path: "/permits/hangar.pdf",
    ))!;

    modeBloc = OcptResourcesBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    locationsBloc = OcptResourcesLocationsBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    await waitForState(modeBloc, (state) => !state.isLoading);
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});
  });

  tearDown(() async {
    await locationsBloc.close();
    await modeBloc.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make every UPDATE on `assets` fail with a database error.
  Future<void> refuseAssetWrites() => projectsManager.currentProject!.database.customStatement(
    "CREATE TRIGGER refuse_update_assets BEFORE UPDATE ON assets "
    "BEGIN SELECT RAISE(ABORT, 'refused'); END",
  );

  /// Lift the refusal [refuseAssetWrites] put.
  Future<void> allowAssetWrites() =>
      projectsManager.currentProject!.database.customStatement("DROP TRIGGER refuse_update_assets");

  /// The location the fixture works on, as a mode state shows it.
  OcptLocation hangar(OcptResourcesState state) =>
      state.locations.firstWhere((location) => location.name == "Hangar");

  /// Add a location the mode has not read yet, and tell whether the mode reads it within a moment:
  /// a handler that stops on a failed write reads nothing.
  Future<bool> modeReadsAnotherLocation() async {
    await projectsManager.locationsService.createLocation(
      database: projectsManager.currentProject!.database,
      name: "Other",
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return modeBloc.state.locations.length > 1;
  }

  group("a refused write on a referenced file", () {
    test("a refused valid-from date raises the write error and keeps the date", () async {
      await refuseAssetWrites();

      locationsBloc.add(
        OcptResourcesAssetValidFromChangedEvent(assetId: permitId, date: DateTime(2026, 3, 5)),
      );
      final state = await waitForState(modeBloc, (state) => state.hasWriteError);

      expect(hangar(state).permitDocument!.validFrom, isNull);
      expect(await modeReadsAnotherLocation(), isFalse, reason: "nothing is read after a failure");

      await allowAssetWrites();
      locationsBloc.add(
        OcptResourcesAssetValidFromChangedEvent(assetId: permitId, date: DateTime(2026, 3, 5)),
      );
      await waitForState(
        modeBloc,
        (state) => hangar(state).permitDocument!.validFrom == DateTime(2026, 3, 5),
      );
    });

    test("a refused valid-until date raises the write error and keeps the date", () async {
      await refuseAssetWrites();

      locationsBloc.add(
        OcptResourcesAssetValidUntilChangedEvent(assetId: permitId, date: DateTime(2026, 9, 30)),
      );
      final state = await waitForState(modeBloc, (state) => state.hasWriteError);

      expect(hangar(state).permitDocument!.validUntil, isNull);
      expect(await modeReadsAnotherLocation(), isFalse, reason: "nothing is read after a failure");

      await allowAssetWrites();
      locationsBloc.add(
        OcptResourcesAssetValidUntilChangedEvent(assetId: permitId, date: DateTime(2026, 9, 30)),
      );
      await waitForState(
        modeBloc,
        (state) => hangar(state).permitDocument!.validUntil == DateTime(2026, 9, 30),
      );
    });

    test("a refused removal raises the write error and keeps the photo", () async {
      await refuseAssetWrites();

      locationsBloc.add(OcptResourcesAssetRemovedEvent(assetId: photoId));
      final state = await waitForState(modeBloc, (state) => state.hasWriteError);

      expect(hangar(state).photos.single.id, photoId);
      expect(await modeReadsAnotherLocation(), isFalse, reason: "nothing is read after a failure");

      await allowAssetWrites();
      locationsBloc.add(OcptResourcesAssetRemovedEvent(assetId: photoId));
      await waitForState(modeBloc, (state) => hangar(state).photos.isEmpty);
    });

    test("the refusal leaves the rows as they were", () async {
      final database = projectsManager.currentProject!.database;
      final before = await database.customSelect("SELECT * FROM assets ORDER BY id").get();
      await refuseAssetWrites();

      locationsBloc.add(OcptResourcesAssetRemovedEvent(assetId: photoId));
      await waitForState(modeBloc, (state) => state.hasWriteError);

      final after = await database.customSelect("SELECT * FROM assets ORDER BY id").get();
      expect([for (final row in after) row.data], [for (final row in before) row.data]);
    });
  });
}
