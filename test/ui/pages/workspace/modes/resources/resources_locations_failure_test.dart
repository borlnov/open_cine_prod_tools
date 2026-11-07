// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_locations_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _RecordingRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A file selector manager answering the picker with a file of its own, so a test never opens a
/// native dialog.
class _StubFileSelectorManager extends FileSelectorManager {
  /// Class constructor
  const _StubFileSelectorManager();

  /// Answer with a file of the stub's own instead of opening the platform's dialog.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async => ResultWithBoolStatus(status: BoolResultStatus.success, value: XFile("/files/pick"));
}

/// The ids of what the handlers work on.
typedef _Seeded = ({
  String locationId,
  String otherLocationId,
  String personId,
  String setId,
  String otherSetId,
  String sceneId,
  String availabilityId,
});

/// What the locations bloc does when the database refuses a write on the locations: the handler
/// raises the mode's write error, reads nothing again, and goes on once the refusal is lifted; a
/// flush stops at the first write that fails.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptResourcesBloc modeBloc;
  late OcptResourcesLocationsBloc locationsBloc;
  late _Seeded seeded;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_locations_failure_test_");
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

    final project = projectsManager.currentProject!;
    final database = project.database;
    await database
        .into(database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene-1",
            screenplayId: project.primaryScreenplayId,
            position: 0,
            heading: "INT. CUISINE - JOUR",
            charStart: 0,
            charEnd: 50,
          ),
        );
    final locations = projectsManager.locationsService;
    final locationId = await locations
        .createLocation(database: database, name: "House")
        .valueOrFail;
    final otherLocationId = await locations
        .createLocation(database: database, name: "Barn")
        .valueOrFail;
    final setId = await locations
        .createSet(database: database, locationId: locationId, name: "Kitchen")
        .valueOrFail;
    final otherSetId = await locations
        .createSet(database: database, locationId: locationId, name: "Hall")
        .valueOrFail;
    await locations
        .assignSceneToSet(database: database, sceneId: "scene-1", setId: setId)
        .valueOrFail;
    final availabilityId = await locations
        .addAvailability(
          database: database,
          locationId: locationId,
          startDate: DateTime(2026, 5),
          endDate: DateTime(2026, 5, 2),
        )
        .valueOrFail;
    await locations
        .setPermitDocument(database: database, locationId: locationId, path: "/docs/permit.pdf")
        .valueOrFail;
    final personId = await projectsManager.peopleService
        .createPerson(database: database)
        .valueOrFail;

    modeBloc = OcptResourcesBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    locationsBloc = OcptResourcesLocationsBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fileSelectorManager: const _StubFileSelectorManager(),
      fieldEditDebounce: const Duration(days: 1),
    );
    await modeBloc.stream
        .firstWhere((state) => !state.isLoading)
        .timeout(const Duration(seconds: 5));
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});
    seeded = (
      locationId: locationId,
      otherLocationId: otherLocationId,
      personId: personId,
      setId: setId,
      otherSetId: otherSetId,
      sceneId: "scene-1",
      availabilityId: availabilityId,
    );
  });

  tearDown(() async {
    await locationsBloc.close();
    await modeBloc.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make every [verb] on [table] fail with a database error, on the rows [when] selects when it is
  /// given.
  Future<void> refuse(String verb, String table, {String? when}) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "${when == null ? '' : 'WHEN $when '}BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift what [refuse] put.
  Future<void> allow(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// Read straight from the database one text column of the live rows of [table], by id.
  Future<Map<String, String>> column(String table, String name) async {
    final rows = await projectsManager.currentProject!.database
        .customSelect("SELECT id, $name AS value FROM $table WHERE is_deleted = 0")
        .get();

    return {for (final row in rows) row.read<String>("id"): row.read<String>("value")};
  }

  /// The handlers, each with the table and the verb that fail it, and the event it dispatches.
  final cases =
      <String, ({String table, String verb, OcptResourcesLocationsEvent Function(_Seeded) event})>{
        "creating a location": (
          table: "locations",
          verb: "INSERT",
          event: (s) => const OcptResourcesLocationCreationRequestedEvent(),
        ),
        "colouring a new location": (
          table: "locations",
          verb: "UPDATE",
          event: (s) => const OcptResourcesLocationCreationRequestedEvent(),
        ),
        "deleting a location": (
          table: "locations",
          verb: "UPDATE",
          event: (s) => OcptResourcesLocationDeletionRequestedEvent(locationId: s.otherLocationId),
        ),
        "changing the colour": (
          table: "locations",
          verb: "UPDATE",
          event: (s) =>
              OcptResourcesLocationColorChangedEvent(locationId: s.locationId, colorIndex: 3),
        ),
        "changing the permit status": (
          table: "locations",
          verb: "UPDATE",
          event: (s) => OcptResourcesLocationPermitStatusChangedEvent(
            locationId: s.locationId,
            status: OcptPermitStatus.granted,
          ),
        ),
        "changing the permit date": (
          table: "locations",
          verb: "UPDATE",
          event: (s) => OcptResourcesLocationPermitDateChangedEvent(
            locationId: s.locationId,
            date: DateTime(2026, 4),
          ),
        ),
        "changing the contact": (
          table: "locations",
          verb: "UPDATE",
          event: (s) => OcptResourcesLocationContactChangedEvent(
            locationId: s.locationId,
            personId: s.personId,
          ),
        ),
        "adding a set": (
          table: "sets",
          verb: "INSERT",
          event: (s) => OcptResourcesSetAddedEvent(locationId: s.locationId),
        ),
        "removing a set": (
          table: "sets",
          verb: "UPDATE",
          event: (s) => OcptResourcesSetRemovedEvent(setId: s.otherSetId),
        ),
        "moving a set": (
          table: "sets",
          verb: "UPDATE",
          event: (s) => OcptResourcesSetLocationChangedEvent(
            setId: s.otherSetId,
            locationId: s.otherLocationId,
          ),
        ),
        "assigning a scene to a set": (
          table: "scene_sets",
          verb: "INSERT",
          event: (s) =>
              OcptResourcesSceneAssignedToSetEvent(sceneId: s.sceneId, setId: s.otherSetId),
        ),
        "removing a scene from a set": (
          table: "scene_sets",
          verb: "UPDATE",
          event: (s) => OcptResourcesSceneRemovedFromSetEvent(sceneId: s.sceneId, setId: s.setId),
        ),
        "adding a photo": (
          table: "assets",
          verb: "INSERT",
          event: (s) => OcptResourcesLocationPhotoAddRequestedEvent(
            locationId: s.locationId,
            fileTypeLabel: "Images",
          ),
        ),
        "picking a permit document": (
          table: "assets",
          verb: "INSERT",
          event: (s) => OcptResourcesPermitDocumentPickRequestedEvent(
            locationId: s.locationId,
            fileTypeLabel: "Documents",
          ),
        ),
        "clearing the permit document": (
          table: "locations",
          verb: "UPDATE",
          event: (s) => OcptResourcesPermitDocumentClearedEvent(locationId: s.locationId),
        ),
        "adding an availability window": (
          table: "location_availabilities",
          verb: "INSERT",
          event: (s) => OcptResourcesLocationAvailabilityAddedEvent(
            locationId: s.locationId,
            startDate: DateTime(2026, 6),
            endDate: DateTime(2026, 6, 2),
            weekdays: 127,
            slot: OcptDayPartSlot.fullDay,
            startMinute: null,
            endMinute: null,
            kind: OcptLocationAvailabilityKind.available,
            note: "",
          ),
        ),
        "updating an availability window": (
          table: "location_availabilities",
          verb: "UPDATE",
          event: (s) => OcptResourcesLocationAvailabilityUpdatedEvent(
            id: s.availabilityId,
            startDate: DateTime(2026, 5),
            endDate: DateTime(2026, 5, 3),
            weekdays: 127,
            slot: OcptDayPartSlot.fullDay,
            startMinute: null,
            endMinute: null,
            kind: OcptLocationAvailabilityKind.available,
            note: "Noisy",
          ),
        ),
        "removing an availability window": (
          table: "location_availabilities",
          verb: "UPDATE",
          event: (s) => OcptResourcesLocationAvailabilityRemovedEvent(id: s.availabilityId),
        ),
      };

  for (final entry in cases.entries) {
    test("${entry.key} raises the write error, reads nothing again, and goes through once the "
        "refusal is lifted", () async {
      final held = modeBloc.state;
      await refuse(entry.value.verb, entry.value.table);

      locationsBloc.add(entry.value.event(seeded));
      await settle();

      expect(modeBloc.state.hasWriteError, isTrue);
      expect(modeBloc.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");

      await allow(entry.value.verb, entry.value.table);
      modeBloc.add(const OcptResourcesWriteErrorDismissedEvent());
      locationsBloc.add(entry.value.event(seeded));
      await settle();

      expect(modeBloc.state.hasWriteError, isFalse);
      expect(modeBloc.state.reloadEpoch, isNot(held.reloadEpoch));
    });
  }

  test("a new location whose colour cannot be written is not selected", () async {
    await refuse("UPDATE", "locations");

    locationsBloc.add(const OcptResourcesLocationCreationRequestedEvent());
    await settle();

    expect(modeBloc.state.hasWriteError, isTrue);
    expect(modeBloc.state.selectedLocation, isNull);
  });

  group("flushing the typed edits", () {
    /// Type [note] into the notes of [locationId].
    Future<void> typeLocation(String locationId, String note) async {
      locationsBloc.add(
        OcptResourcesLocationFieldChangedEvent(
          locationId: locationId,
          field: OcptLocationField.notes,
          rawValue: note,
        ),
      );
      await settle();
    }

    /// Type [note] into the notes of [setId].
    Future<void> typeSet(String setId, String note) async {
      locationsBloc.add(
        OcptResourcesSetFieldChangedEvent(setId: setId, field: OcptSetField.notes, rawValue: note),
      );
      await settle();
    }

    test("a refused deletion keeps the edits typed into the location and its sets", () async {
      await typeLocation(seeded.locationId, "Cold");
      await typeSet(seeded.setId, "Bright");
      await refuse("UPDATE", "locations");

      locationsBloc.add(OcptResourcesLocationDeletionRequestedEvent(locationId: seeded.locationId));
      await settle();

      expect(modeBloc.state.hasWriteError, isTrue);
      expect(locationsBloc.state.pendingLocationFieldEdits, {
        (seeded.locationId, OcptLocationField.notes): "Cold",
      });
      expect(locationsBloc.state.pendingSetFieldEdits, {
        (seeded.setId, OcptSetField.notes): "Bright",
      });
    });

    test("a refused location write stops the set edits after it", () async {
      await typeLocation(seeded.locationId, "Cold");
      await typeSet(seeded.setId, "Bright");
      await refuse("UPDATE", "locations");

      final status = await locationsBloc.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      expect(modeBloc.state.hasWriteError, isTrue);
      expect((await column("sets", "notes"))[seeded.setId], isEmpty);
      expect(locationsBloc.state.pendingSetFieldEdits, isEmpty);
    });

    test("a refused location write stops the location edits after it", () async {
      await typeLocation(seeded.locationId, "Cold");
      await typeLocation(seeded.otherLocationId, "Warm");
      await refuse("UPDATE", "locations", when: "NEW.id = '${seeded.locationId}'");

      await locationsBloc.flushPendingWrites();

      expect(modeBloc.state.hasWriteError, isTrue);
      final notes = await column("locations", "notes");
      expect(notes[seeded.locationId], isEmpty);
      expect(notes[seeded.otherLocationId], isEmpty, reason: "the edit after the refused one");
    });

    test(
      "a refused set write stops the set edits after it, and the locations are written",
      () async {
        await typeLocation(seeded.locationId, "Cold");
        await typeSet(seeded.setId, "Bright");
        await typeSet(seeded.otherSetId, "Dark");
        await refuse("UPDATE", "sets", when: "NEW.id = '${seeded.setId}'");

        await locationsBloc.flushPendingWrites();

        expect(modeBloc.state.hasWriteError, isTrue);
        final setNotes = await column("sets", "notes");
        expect(setNotes[seeded.setId], isEmpty);
        expect(setNotes[seeded.otherSetId], isEmpty, reason: "the edit after the refused one");
        expect((await column("locations", "notes"))[seeded.locationId], "Cold");
      },
    );

    test("a refused flush on leaving stops the set edits after the location ones", () async {
      await typeLocation(seeded.locationId, "Cold");
      await typeSet(seeded.setId, "Bright");
      await refuse("UPDATE", "locations");

      await locationsBloc.flushPendingWritesWithoutState();

      expect((await column("sets", "notes"))[seeded.setId], isEmpty);
      expect(locationsBloc.state.pendingLocationFieldEdits, isNotEmpty);
      expect(modeBloc.state.hasWriteError, isFalse, reason: "a flush on leaving only logs");
    });

    test("a refused set edit on leaving stops the set edits after it", () async {
      await typeSet(seeded.setId, "Bright");
      await typeSet(seeded.otherSetId, "Dark");
      await refuse("UPDATE", "sets", when: "NEW.id = '${seeded.setId}'");

      await locationsBloc.flushPendingWritesWithoutState();

      expect((await column("sets", "notes"))[seeded.otherSetId], isEmpty);
      expect(locationsBloc.state.pendingSetFieldEdits, isNotEmpty);
    });

    test("a refused flush on leaving writes what was refused at the next one", () async {
      await typeLocation(seeded.locationId, "Cold");
      await refuse("UPDATE", "locations");
      await locationsBloc.flushPendingWritesWithoutState();
      await allow("UPDATE", "locations");

      await locationsBloc.flushPendingWritesWithoutState();

      expect((await column("locations", "notes"))[seeded.locationId], "Cold");
    });
  });
}
