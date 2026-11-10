// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_locations_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter for it
/// to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A file selector manager answering the picker with a file of its own, so a test never opens a
/// native dialog: [pickedPath] is what the user is pretending to pick, and null is a cancellation.
class _StubFileSelectorManager extends FileSelectorManager {
  /// The path the next pick answers with, or null to answer as a cancelled dialog does.
  final String? pickedPath;

  /// Class constructor
  const _StubFileSelectorManager({required this.pickedPath});

  /// Answers with [pickedPath] instead of opening the platform's own dialog.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async {
    final pickedPath = this.pickedPath;
    if (pickedPath == null) {
      return const ResultWithBoolStatus(status: BoolResultStatus.error);
    }

    return ResultWithBoolStatus(status: BoolResultStatus.success, value: XFile(pickedPath));
  }
}

/// How long a view bloc waits before it writes what was typed, for the tests that wait for it.
const _shortDebounce = Duration(milliseconds: 30);

/// A debounce no test waits out, for the tests that must find an edit still pending.
const _neverDebounce = Duration(days: 1);

/// Run the tests of [OcptResourcesLocationsBloc].
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's write error path)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_locations_bloc_test_");
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

  /// Builds the mode bloc wired to the test project.
  OcptResourcesBloc buildBloc() => OcptResourcesBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the locations bloc of [modeBloc], writing what is typed after [fieldEditDebounce].
  OcptResourcesLocationsBloc buildLocations(
    OcptResourcesBloc modeBloc, {
    Duration fieldEditDebounce = _shortDebounce,
    FileSelectorManager? fileSelectorManager,
  }) => OcptResourcesLocationsBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    fileSelectorManager: fileSelectorManager,
    fieldEditDebounce: fieldEditDebounce,
  );

  /// The value the locations table holds in the column the test types into, whichever row.
  Future<String> readStoredValue(OcptProjectDatabase database) async {
    final row = await database.customSelect("SELECT country AS value FROM locations").getSingle();
    return row.read<String>("value");
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Creates a location through [locationsBloc] and waits for the mode to select it.
  Future<String> createLocation(
    OcptResourcesBloc modeBloc,
    OcptResourcesLocationsBloc locationsBloc,
  ) async {
    final before = modeBloc.state.locationCount;
    final previouslySelected = modeBloc.state.selectedLocationId;
    locationsBloc.add(const OcptResourcesLocationCreationRequestedEvent());
    final state = await waitForState(
      modeBloc,
      (state) =>
          state.locationCount == before + 1 &&
          state.selectedLocationId != null &&
          state.selectedLocationId != previouslySelected,
    );

    return state.selectedLocationId!;
  }

  /// Reads the locations straight from the database.
  Future<List<OcptLocation>> readLocations() => projectsManager.locationsService
      .loadLocations(database: projectsManager.currentProject!.database)
      .valueOrFail;

  /// Closes the blocs of a test, the view before its mode.
  Future<void> closeAll(
    OcptResourcesLocationsBloc locationsBloc,
    OcptResourcesBloc modeBloc,
  ) async {
    await locationsBloc.close();
    await modeBloc.close();
  }

  group("creating and deleting a location", () {
    test("creating a location appends it to the list, selects it and colours it by rank", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      await createLocation(bloc, locationsBloc);
      expect(bloc.state.selectedLocationId, bloc.state.locations.single.id);
      expect(bloc.state.locations.single.colorIndex, 0);

      await createLocation(bloc, locationsBloc);
      expect(bloc.state.locations.last.colorIndex, 1);
      expect(bloc.state.selectedLocationId, bloc.state.locations.last.id);

      await closeAll(locationsBloc, bloc);
    });

    test("deleting the selected location clears the selection", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);

      locationsBloc.add(OcptResourcesLocationDeletionRequestedEvent(locationId: locationId));
      final state = await waitForState(
        bloc,
        (state) => state.locationCount == 0 && state.selectedLocationId == null,
      );

      expect(state.locations, isEmpty);

      await closeAll(locationsBloc, bloc);
    });

    test(
      "deleting a location drops the fields typed on it and on its sets without writing them",
      () async {
        final bloc = buildBloc();
        final locationsBloc = buildLocations(bloc, fieldEditDebounce: _neverDebounce);
        await waitForState(bloc, (state) => !state.isLoading);
        final locationId = await createLocation(bloc, locationsBloc);
        locationsBloc.add(OcptResourcesSetAddedEvent(locationId: locationId));
        final withSet = await waitForState(
          bloc,
          (state) => state.selectedLocation!.sets.length == 1,
        );
        final setId = withSet.selectedLocation!.sets.single.id;

        locationsBloc.add(
          OcptResourcesLocationFieldChangedEvent(
            locationId: locationId,
            field: OcptLocationField.name,
            rawValue: "Grotto",
          ),
        );
        locationsBloc.add(
          OcptResourcesSetFieldChangedEvent(
            setId: setId,
            field: OcptSetField.name,
            rawValue: "Back room",
          ),
        );
        await waitForState(
          locationsBloc,
          (state) =>
              state.pendingLocationFieldEdits.isNotEmpty && state.pendingSetFieldEdits.isNotEmpty,
        );

        locationsBloc.add(OcptResourcesLocationDeletionRequestedEvent(locationId: locationId));
        await waitForState(bloc, (state) => state.locationCount == 0);
        await waitForState(
          locationsBloc,
          (state) => state.pendingLocationFieldEdits.isEmpty && state.pendingSetFieldEdits.isEmpty,
        );

        expect(await readLocations(), isEmpty);
        expect(bloc.state.hasWriteError, isFalse);

        await closeAll(locationsBloc, bloc);
      },
    );
  });

  group("the fields typed on a location's sheet", () {
    test("a typed location field edit is pending until the debounce writes it", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);

      locationsBloc.add(
        OcptResourcesLocationFieldChangedEvent(
          locationId: locationId,
          field: OcptLocationField.city,
          rawValue: "Lyon",
        ),
      );
      await waitForState(
        locationsBloc,
        (state) => state.pendingLocationFieldEdits[(locationId, OcptLocationField.city)] == "Lyon",
      );
      expect(bloc.state.selectedLocation!.city, isEmpty);

      await waitForState(bloc, (state) => state.selectedLocation!.city == "Lyon");
      await waitForState(locationsBloc, (state) => state.pendingLocationFieldEdits.isEmpty);

      await closeAll(locationsBloc, bloc);
    });

    // "45,76" is the ordinary French way of typing it, and the one a decimal-point parser refuses.
    test("a coordinate that isn't a number is stored as no coordinate at all", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);

      locationsBloc.add(
        OcptResourcesLocationFieldChangedEvent(
          locationId: locationId,
          field: OcptLocationField.latitude,
          rawValue: "45.76",
        ),
      );
      await waitForState(bloc, (state) => state.selectedLocation!.latitude == 45.76);

      locationsBloc.add(
        OcptResourcesLocationFieldChangedEvent(
          locationId: locationId,
          field: OcptLocationField.latitude,
          rawValue: "45,76",
        ),
      );
      await waitForState(bloc, (state) => state.selectedLocation!.latitude == null);
      await waitForState(locationsBloc, (state) => state.pendingLocationFieldEdits.isEmpty);

      await closeAll(locationsBloc, bloc);
    });

    test("a set is added, typed into, and removed with its pending edit", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);

      locationsBloc.add(OcptResourcesSetAddedEvent(locationId: locationId));
      var state = await waitForState(bloc, (state) => state.selectedLocation!.sets.length == 1);
      final setId = state.selectedLocation!.sets.single.id;

      locationsBloc.add(
        OcptResourcesSetFieldChangedEvent(
          setId: setId,
          field: OcptSetField.name,
          rawValue: "Cuisine",
        ),
      );
      state = await waitForState(
        bloc,
        (state) => state.selectedLocation!.sets.single.name == "Cuisine",
      );
      await waitForState(locationsBloc, (state) => state.pendingSetFieldEdits.isEmpty);

      locationsBloc.add(
        OcptResourcesSetFieldChangedEvent(
          setId: setId,
          field: OcptSetField.notes,
          rawValue: "Nord",
        ),
      );
      await waitForState(locationsBloc, (state) => state.pendingSetFieldEdits.isNotEmpty);

      locationsBloc.add(OcptResourcesSetRemovedEvent(setId: setId));
      await waitForState(bloc, (state) => state.selectedLocation!.sets.isEmpty);
      await waitForState(locationsBloc, (state) => state.pendingSetFieldEdits.isEmpty);

      await closeAll(locationsBloc, bloc);
    });

    test("removing a set drops its own pending edit at once and keeps the location's, "
        "which a flush writes", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);
      locationsBloc.add(OcptResourcesSetAddedEvent(locationId: locationId));
      final withSet = await waitForState(bloc, (state) => state.selectedLocation!.sets.length == 1);
      final setId = withSet.selectedLocation!.sets.single.id;

      locationsBloc.add(
        OcptResourcesLocationFieldChangedEvent(
          locationId: locationId,
          field: OcptLocationField.name,
          rawValue: "Grotto",
        ),
      );
      locationsBloc.add(
        OcptResourcesSetFieldChangedEvent(
          setId: setId,
          field: OcptSetField.name,
          rawValue: "Front room",
        ),
      );
      await waitForState(
        locationsBloc,
        (state) =>
            state.pendingLocationFieldEdits.isNotEmpty && state.pendingSetFieldEdits.isNotEmpty,
      );

      locationsBloc.add(OcptResourcesSetRemovedEvent(setId: setId));
      await waitForState(locationsBloc, (state) => state.pendingSetFieldEdits.isEmpty);
      await waitForState(bloc, (state) => state.selectedLocation!.sets.isEmpty);
      expect(locationsBloc.state.pendingLocationFieldEdits, isNotEmpty);

      await bloc.flushAllPendingWrites();

      final location = (await readLocations()).single;
      expect(location.name, "Grotto");
      expect(location.sets, isEmpty);
      expect(bloc.state.hasWriteError, isFalse);

      await closeAll(locationsBloc, bloc);
    });

    test("are written once when the widget leaves the tree and the bloc then closes", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);
      locationsBloc.add(
        OcptResourcesLocationFieldChangedEvent(
          locationId: locationId,
          field: OcptLocationField.country,
          rawValue: "France",
        ),
      );
      await waitForState(locationsBloc, (state) => state.pendingLocationFieldEdits.isNotEmpty);

      // Every update of the table is logged, so a second write of the same edit shows.
      final database = projectsManager.currentProject!.database;
      await database.customStatement("CREATE TABLE write_log (written INTEGER)");
      await database.customStatement(
        "CREATE TRIGGER log_write AFTER UPDATE ON locations "
        "BEGIN INSERT INTO write_log VALUES (1); END",
      );

      // What the widget leaving the tree does: the flush starts, and the bloc closes in the same
      // frame, before the write is done.
      final flushing = bloc.flushPendingFieldEdits();
      await closeAll(locationsBloc, bloc);
      await flushing;

      expect(await readStoredValue(database), "France");
      final writes = await database.customSelect("SELECT COUNT(*) AS n FROM write_log").getSingle();
      expect(writes.read<int>("n"), 1);
    });

    test(
      "are written and forgotten, with the one write error, when the read after the write fails",
      () async {
        final bloc = buildBloc();
        final locationsBloc = buildLocations(bloc, fieldEditDebounce: _neverDebounce);
        await waitForState(bloc, (state) => !state.isLoading);
        final locationId = await createLocation(bloc, locationsBloc);
        locationsBloc.add(
          OcptResourcesLocationFieldChangedEvent(
            locationId: locationId,
            field: OcptLocationField.country,
            rawValue: "France",
          ),
        );
        await waitForState(locationsBloc, (state) => state.pendingLocationFieldEdits.isNotEmpty);

        final database = projectsManager.currentProject!.database;
        // The write of an edit never touches the episodes, whereas the read of the catalogue after
        // it does: the write lands and the read fails.
        await database.customStatement("ALTER TABLE screenplays RENAME TO screenplays_gone");
        try {
          final mayProceed = await bloc.flushAllPendingWrites();

          expect(mayProceed, isTrue);
          expect(bloc.state.hasWriteError, isTrue);
          expect(locationsBloc.state.pendingLocationFieldEdits, isEmpty);
        } finally {
          await database.customStatement("ALTER TABLE screenplays_gone RENAME TO screenplays");
        }

        expect(await readStoredValue(database), "France");

        await closeAll(locationsBloc, bloc);
      },
    );

    test(
      "are written at once, and show on the mode, when the mode asks every view to write",
      () async {
        final bloc = buildBloc();
        final locationsBloc = buildLocations(bloc, fieldEditDebounce: _neverDebounce);
        await waitForState(bloc, (state) => !state.isLoading);
        final locationId = await createLocation(bloc, locationsBloc);
        locationsBloc.add(
          OcptResourcesLocationFieldChangedEvent(
            locationId: locationId,
            field: OcptLocationField.region,
            rawValue: "Auvergne",
          ),
        );
        await waitForState(locationsBloc, (state) => state.pendingLocationFieldEdits.isNotEmpty);

        final mayProceed = await bloc.flushAllPendingWrites();

        expect(mayProceed, isTrue);
        expect(locationsBloc.state.pendingLocationFieldEdits, isEmpty);
        expect(bloc.state.selectedLocation!.region, "Auvergne");

        await closeAll(locationsBloc, bloc);
      },
    );
  });

  group("the other writes of a location's sheet", () {
    test("the permit status and its date land in the database at once", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);

      locationsBloc.add(
        OcptResourcesLocationPermitStatusChangedEvent(
          locationId: locationId,
          status: OcptPermitStatus.granted,
        ),
      );
      await waitForState(
        bloc,
        (state) => state.selectedLocation!.permitStatus == OcptPermitStatus.granted,
      );

      locationsBloc.add(
        OcptResourcesLocationPermitDateChangedEvent(
          locationId: locationId,
          date: DateTime(2026, 8, 13),
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedLocation!.permitDate != null);
      expect(state.selectedLocation!.permitDate, DateTime(2026, 8, 13));

      await closeAll(locationsBloc, bloc);
    });

    test("an availability window is added, updated and removed", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);

      locationsBloc.add(
        OcptResourcesLocationAvailabilityAddedEvent(
          locationId: locationId,
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 12),
          weekdays: 127,
          slot: OcptDayPartSlot.fullDay,
          startMinute: null,
          endMinute: null,
          kind: OcptLocationAvailabilityKind.available,
          note: "",
        ),
      );
      var state = await waitForState(
        bloc,
        (state) => state.selectedLocation!.availabilities.length == 1,
      );
      final windowId = state.selectedLocation!.availabilities.single.id;

      locationsBloc.add(
        OcptResourcesLocationAvailabilityUpdatedEvent(
          id: windowId,
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 12),
          weekdays: 127,
          slot: OcptDayPartSlot.fullDay,
          startMinute: null,
          endMinute: null,
          kind: OcptLocationAvailabilityKind.available,
          note: "Ask the owner",
        ),
      );
      state = await waitForState(
        bloc,
        (state) => state.selectedLocation!.availabilities.single.note == "Ask the owner",
      );

      locationsBloc.add(OcptResourcesLocationAvailabilityRemovedEvent(id: windowId));
      await waitForState(bloc, (state) => state.selectedLocation!.availabilities.isEmpty);

      await closeAll(locationsBloc, bloc);
    });

    test("picking a scouting photo stores the path the picker answered with", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/photos/hangar.jpg"),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);

      locationsBloc.add(
        OcptResourcesLocationPhotoAddRequestedEvent(
          locationId: locationId,
          fileTypeLabel: "Images",
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedLocation!.photos.isNotEmpty);
      expect(state.selectedLocation!.photos.single.path, "/photos/hangar.jpg");

      locationsBloc.add(
        OcptResourcesAssetRemovedEvent(assetId: state.selectedLocation!.photos.single.id),
      );
      await waitForState(bloc, (state) => state.selectedLocation!.photos.isEmpty);

      await closeAll(locationsBloc, bloc);
    });

    test("the permit document's validity dates land in the database", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(
          pickedPath: "/permits/autorisation.pdf",
        ),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);

      locationsBloc.add(
        OcptResourcesPermitDocumentPickRequestedEvent(
          locationId: locationId,
          fileTypeLabel: "Documents",
        ),
      );
      var state = await waitForState(
        bloc,
        (state) => state.selectedLocation!.permitDocument != null,
      );
      final assetId = state.selectedLocation!.permitDocument!.id;

      locationsBloc.add(
        OcptResourcesAssetValidFromChangedEvent(assetId: assetId, date: DateTime(2026, 3, 5)),
      );
      state = await waitForState(
        bloc,
        (state) => state.selectedLocation!.permitDocument!.validFrom != null,
      );
      expect(state.selectedLocation!.permitDocument!.validFrom, DateTime(2026, 3, 5));

      locationsBloc.add(
        OcptResourcesAssetValidUntilChangedEvent(assetId: assetId, date: DateTime(2026, 9, 30)),
      );
      state = await waitForState(
        bloc,
        (state) => state.selectedLocation!.permitDocument!.validUntil != null,
      );
      expect(state.selectedLocation!.permitDocument!.validUntil, DateTime(2026, 9, 30));

      // Clearing is as real a gesture as setting: the date goes back to null.
      locationsBloc.add(OcptResourcesAssetValidFromChangedEvent(assetId: assetId, date: null));
      await waitForState(
        bloc,
        (state) => state.selectedLocation!.permitDocument!.validFrom == null,
      );

      await closeAll(locationsBloc, bloc);
    });

    test("a cancelled picker references nothing at all", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: null),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final locationId = await createLocation(bloc, locationsBloc);

      locationsBloc.add(
        OcptResourcesPermitDocumentPickRequestedEvent(
          locationId: locationId,
          fileTypeLabel: "Documents",
        ),
      );
      // Nothing to wait for: the cancellation emits no state at all, so the assertion is that the
      // location still has no document once the event has certainly been handled.
      locationsBloc.add(
        OcptResourcesLocationFieldChangedEvent(
          locationId: locationId,
          field: OcptLocationField.name,
          rawValue: "Le hangar",
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.selectedLocation!.name == "Le hangar",
      );
      expect(state.selectedLocation!.permitDocument, isNull);

      await closeAll(locationsBloc, bloc);
    });
  });

  group("the events of the locations bloc", () {
    String nameOf(OcptResourcesLocationsEvent event) => switch (event) {
      OcptResourcesLocationCreationRequestedEvent() => "creation",
      OcptResourcesLocationDeletionRequestedEvent() => "deletion",
      OcptResourcesLocationFieldChangedEvent() => "field",
      OcptResourcesLocationColorChangedEvent() => "colour",
      OcptResourcesLocationPermitStatusChangedEvent() => "permit status",
      OcptResourcesLocationPermitDateChangedEvent() => "permit date",
      OcptResourcesLocationContactChangedEvent() => "contact",
      OcptResourcesSetAddedEvent() => "set added",
      OcptResourcesSetFieldChangedEvent() => "set field",
      OcptResourcesSetRemovedEvent() => "set removed",
      OcptResourcesSetLocationChangedEvent() => "set moved",
      OcptResourcesSceneAssignedToSetEvent() => "scene assigned",
      OcptResourcesSceneRemovedFromSetEvent() => "scene removed",
      OcptResourcesLocationPhotoAddRequestedEvent() => "photo add",
      OcptResourcesPermitDocumentPickRequestedEvent() => "permit pick",
      OcptResourcesPermitDocumentClearedEvent() => "permit cleared",
      OcptResourcesAssetValidFromChangedEvent() => "valid from",
      OcptResourcesAssetValidUntilChangedEvent() => "valid until",
      OcptResourcesAssetRemovedEvent() => "asset removed",
      OcptResourcesLocationAvailabilityAddedEvent() => "availability added",
      OcptResourcesLocationAvailabilityUpdatedEvent() => "availability updated",
      OcptResourcesLocationAvailabilityRemovedEvent() => "availability removed",
      OcptResourcesLocationsFieldEditFlushRequestedEvent() => "field flush",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: null),
      );
      await waitForState(bloc, (state) => !state.isLoading);

      final events = <OcptResourcesLocationsEvent>[
        const OcptResourcesLocationCreationRequestedEvent(),
        const OcptResourcesLocationDeletionRequestedEvent(locationId: "l"),
        const OcptResourcesLocationFieldChangedEvent(
          locationId: "l",
          field: OcptLocationField.name,
          rawValue: "",
        ),
        const OcptResourcesLocationColorChangedEvent(locationId: "l", colorIndex: 1),
        const OcptResourcesLocationPermitStatusChangedEvent(
          locationId: "l",
          status: OcptPermitStatus.granted,
        ),
        const OcptResourcesLocationPermitDateChangedEvent(locationId: "l", date: null),
        const OcptResourcesLocationContactChangedEvent(locationId: "l", personId: null),
        const OcptResourcesSetAddedEvent(locationId: "l"),
        const OcptResourcesSetFieldChangedEvent(setId: "s", field: OcptSetField.name, rawValue: ""),
        const OcptResourcesSetRemovedEvent(setId: "s"),
        const OcptResourcesSetLocationChangedEvent(setId: "s", locationId: "l"),
        const OcptResourcesSceneAssignedToSetEvent(sceneId: "c", setId: "s"),
        const OcptResourcesSceneRemovedFromSetEvent(sceneId: "c", setId: "s"),
        const OcptResourcesLocationPhotoAddRequestedEvent(locationId: "l", fileTypeLabel: ""),
        const OcptResourcesPermitDocumentPickRequestedEvent(locationId: "l", fileTypeLabel: ""),
        const OcptResourcesPermitDocumentClearedEvent(locationId: "l"),
        const OcptResourcesAssetValidFromChangedEvent(assetId: "a", date: null),
        const OcptResourcesAssetValidUntilChangedEvent(assetId: "a", date: null),
        const OcptResourcesAssetRemovedEvent(assetId: "a"),
        OcptResourcesLocationAvailabilityAddedEvent(
          locationId: "l",
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 10),
          weekdays: 127,
          slot: OcptDayPartSlot.fullDay,
          startMinute: null,
          endMinute: null,
          kind: OcptLocationAvailabilityKind.available,
          note: "",
        ),
        OcptResourcesLocationAvailabilityUpdatedEvent(
          id: "i",
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 10),
          weekdays: 127,
          slot: OcptDayPartSlot.fullDay,
          startMinute: null,
          endMinute: null,
          kind: OcptLocationAvailabilityKind.available,
          note: "",
        ),
        const OcptResourcesLocationAvailabilityRemovedEvent(id: "i"),
        const OcptResourcesLocationsFieldEditFlushRequestedEvent(),
      ];
      expect(
        events.map(nameOf).toSet(),
        hasLength(23),
        reason: 'one event per name of the hierarchy',
      );

      // With no project open every write handler returns at its first line: the handlers are
      // reached without any of the rows the events name having to exist.
      await projectsManager.closeCurrentProject().okOrFail;

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => locationsBloc.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await closeAll(locationsBloc, bloc);
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      final locationsBloc = buildLocations(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);

      await closeAll(locationsBloc, bloc);
    });
  });
}
