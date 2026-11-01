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
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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

/// How long a people bloc waits before it writes what was typed, for the tests that wait for it.
const _shortDebounce = Duration(milliseconds: 30);

/// A debounce no test waits out, for the tests that must find an edit still pending.
const _neverDebounce = Duration(days: 1);

/// Run the tests of [OcptResourcesPeopleBloc].
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_people_bloc_test_");
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

  /// Builds the people bloc of [modeBloc], writing what is typed after [fieldEditDebounce].
  OcptResourcesPeopleBloc buildPeople(
    OcptResourcesBloc modeBloc, {
    Duration fieldEditDebounce = _shortDebounce,
    FileSelectorManager? fileSelectorManager,
  }) => OcptResourcesPeopleBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    fileSelectorManager: fileSelectorManager,
    fieldEditDebounce: fieldEditDebounce,
  );

  /// The value the people table holds in the column the test types into, whichever row.
  Future<String> readStoredValue(OcptProjectDatabase database) async {
    final row = await database.customSelect("SELECT city AS value FROM people").getSingle();
    return row.read<String>("value");
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Creates a person through [peopleBloc] and waits for the mode to select them.
  Future<String> createPerson(
    OcptResourcesBloc modeBloc,
    OcptResourcesPeopleBloc peopleBloc,
  ) async {
    final before = modeBloc.state.peopleCount;
    final previouslySelected = modeBloc.state.selectedPersonId;
    peopleBloc.add(const OcptResourcesPersonCreationRequestedEvent());
    final state = await waitForState(
      modeBloc,
      (state) =>
          state.peopleCount == before + 1 &&
          state.selectedPersonId != null &&
          state.selectedPersonId != previouslySelected,
    );

    return state.selectedPersonId!;
  }

  /// Reads the address book straight from the database.
  Future<List<OcptPerson>> readPeople() =>
      projectsManager.peopleService.loadPeople(database: projectsManager.currentProject!.database);

  /// Closes the blocs of a test, the view before its mode.
  Future<void> closeAll(OcptResourcesPeopleBloc peopleBloc, OcptResourcesBloc modeBloc) async {
    await peopleBloc.close();
    await modeBloc.close();
  }

  group("creating and erasing a person", () {
    test("appends it to the address book and selects it", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      final personId = await createPerson(bloc, peopleBloc);

      expect(bloc.state.selectedPerson, isNotNull);
      expect(bloc.state.people.single.id, personId);

      await closeAll(peopleBloc, bloc);
    });

    test("tints each new person by its rank in the address book", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      await createPerson(bloc, peopleBloc);
      expect(bloc.state.selectedPerson!.colorIndex, 0);

      await createPerson(bloc, peopleBloc);
      expect(bloc.state.selectedPerson!.colorIndex, 1);

      await closeAll(peopleBloc, bloc);
    });

    test("erasing the selected person clears the selection", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await createPerson(bloc, peopleBloc);

      peopleBloc.add(OcptResourcesPersonDeletionRequestedEvent(personId: personId));
      final state = await waitForState(
        bloc,
        (state) => state.peopleCount == 0 && state.selectedPersonId == null,
      );

      expect(state.people, isEmpty);

      await closeAll(peopleBloc, bloc);
    });

    test("erasing another person leaves the selection alone", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final firstPersonId = await createPerson(bloc, peopleBloc);
      final secondPersonId = await createPerson(bloc, peopleBloc);
      expect(secondPersonId, isNot(firstPersonId));

      peopleBloc.add(OcptResourcesPersonDeletionRequestedEvent(personId: firstPersonId));
      final state = await waitForState(bloc, (state) => state.peopleCount == 1);

      expect(state.selectedPersonId, secondPersonId);

      await closeAll(peopleBloc, bloc);
    });

    test("drops the field typed on the erased person's sheet without writing it", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await createPerson(bloc, peopleBloc);

      peopleBloc.add(
        OcptResourcesPersonFieldChangedEvent(
          personId: personId,
          field: OcptPersonField.firstName,
          rawValue: "Alicia",
        ),
      );
      await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      peopleBloc.add(OcptResourcesPersonDeletionRequestedEvent(personId: personId));
      await waitForState(bloc, (state) => state.peopleCount == 0);
      await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isEmpty);

      expect(await readPeople(), isEmpty);
      expect(bloc.state.hasWriteError, isFalse);

      await closeAll(peopleBloc, bloc);
    });
  });

  group("the fields typed on a person's sheet", () {
    test("show as a pending value and write once after the debounce", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await createPerson(bloc, peopleBloc);

      peopleBloc.add(
        OcptResourcesPersonFieldChangedEvent(
          personId: personId,
          field: OcptPersonField.firstName,
          rawValue: "L",
        ),
      );
      await waitForState(
        peopleBloc,
        (state) => state.pendingFieldEdits[(personId, OcptPersonField.firstName)] == "L",
      );
      // Not written yet: still the field's default empty value.
      expect(bloc.state.selectedPerson!.firstName, isEmpty);

      // A second keystroke before the debounce elapses restarts it rather than firing twice: only
      // the last value typed is ever written.
      peopleBloc.add(
        OcptResourcesPersonFieldChangedEvent(
          personId: personId,
          field: OcptPersonField.firstName,
          rawValue: "Léa",
        ),
      );
      await waitForState(
        peopleBloc,
        (state) => state.pendingFieldEdits[(personId, OcptPersonField.firstName)] == "Léa",
      );
      expect(bloc.state.selectedPerson!.firstName, isEmpty);

      await waitForState(bloc, (state) => state.selectedPerson!.firstName == "Léa");
      await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isEmpty);
      expect((await readPeople()).single.firstName, "Léa");

      await closeAll(peopleBloc, bloc);
    });

    test("are written at once when the mode asks every view to write", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await createPerson(bloc, peopleBloc);
      peopleBloc.add(
        OcptResourcesPersonFieldChangedEvent(
          personId: personId,
          field: OcptPersonField.lastName,
          rawValue: "Martin",
        ),
      );
      await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      final mayProceed = await bloc.flushAllPendingWrites();

      expect(mayProceed, isTrue);
      expect(peopleBloc.state.pendingFieldEdits, isEmpty);
      expect(bloc.state.selectedPerson!.lastName, "Martin");
      expect((await readPeople()).single.lastName, "Martin");

      await closeAll(peopleBloc, bloc);
    });

    test("are written once when the widget leaves the tree and the bloc then closes", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await createPerson(bloc, peopleBloc);
      peopleBloc.add(
        OcptResourcesPersonFieldChangedEvent(
          personId: personId,
          field: OcptPersonField.city,
          rawValue: "Lyon",
        ),
      );
      await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      // Every update of the table is logged, so a second write of the same edit shows even when
      // it stores the same value.
      final database = projectsManager.currentProject!.database;
      await database.customStatement("CREATE TABLE write_log (written INTEGER)");
      await database.customStatement(
        "CREATE TRIGGER log_write AFTER UPDATE ON people BEGIN INSERT INTO write_log VALUES (1); END",
      );

      // What the widget leaving the tree does: the flush starts, and the bloc closes in the same
      // frame, before the write is done.
      final flushing = bloc.flushPendingFieldEdits();
      await closeAll(peopleBloc, bloc);
      await flushing;

      expect(await readStoredValue(database), "Lyon");
      final writes = await database.customSelect("SELECT COUNT(*) AS n FROM write_log").getSingle();
      expect(writes.read<int>("n"), 1);
    });

    test(
      "are written and forgotten, with the one write error, when the read after the write fails",
      () async {
        final bloc = buildBloc();
        final peopleBloc = buildPeople(bloc, fieldEditDebounce: _neverDebounce);
        await waitForState(bloc, (state) => !state.isLoading);
        final personId = await createPerson(bloc, peopleBloc);
        peopleBloc.add(
          OcptResourcesPersonFieldChangedEvent(
            personId: personId,
            field: OcptPersonField.city,
            rawValue: "Lyon",
          ),
        );
        await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isNotEmpty);

        final database = projectsManager.currentProject!.database;
        // The write of an edit never touches the episodes, whereas the read of the catalogue after it
        // does: the write lands and the read fails.
        await database.customStatement("ALTER TABLE screenplays RENAME TO screenplays_gone");
        try {
          final mayProceed = await bloc.flushAllPendingWrites();

          expect(mayProceed, isTrue);
          expect(bloc.state.hasWriteError, isTrue);
          expect(peopleBloc.state.pendingFieldEdits, isEmpty);
        } finally {
          await database.customStatement("ALTER TABLE screenplays_gone RENAME TO screenplays");
        }

        expect(await readStoredValue(database), "Lyon");

        await closeAll(peopleBloc, bloc);
      },
    );

    test("are all dropped when the mode says writing the typed edits failed", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await createPerson(bloc, peopleBloc);
      peopleBloc.add(
        OcptResourcesPersonFieldChangedEvent(
          personId: personId,
          field: OcptPersonField.firstName,
          rawValue: "Alicia",
        ),
      );
      await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isNotEmpty);

      bloc.add(const OcptResourcesPendingEditsLostEvent());
      await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isEmpty);

      expect(bloc.state.hasWriteError, isTrue);
      expect(bloc.state.selectedPerson!.firstName, isEmpty);

      await closeAll(peopleBloc, bloc);
    });

    test("fall back to the stored value, with the one write error, when the write fails", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await createPerson(bloc, peopleBloc);
      final database = projectsManager.currentProject!.database;

      await database.customStatement("ALTER TABLE people RENAME TO people_gone");
      try {
        peopleBloc.add(
          OcptResourcesPersonFieldChangedEvent(
            personId: personId,
            field: OcptPersonField.firstName,
            rawValue: "Alicia",
          ),
        );
        await waitForState(bloc, (state) => state.hasWriteError);
        await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isEmpty);

        expect(bloc.state.selectedPerson!.firstName, isEmpty);
      } finally {
        await database.customStatement("ALTER TABLE people_gone RENAME TO people");
      }

      await closeAll(peopleBloc, bloc);
    });
  });

  group("the other writes of a person's sheet", () {
    test("land in the database and in the mode's catalogue", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await createPerson(bloc, peopleBloc);

      peopleBloc.add(
        OcptResourcesPositionAddedEvent(
          personId: personId,
          positionId: "director",
          customLabel: "",
        ),
      );
      peopleBloc.add(OcptResourcesSkillAddedEvent(personId: personId, label: "Driving"));
      peopleBloc.add(
        OcptResourcesPersonImageRightsStatusChangedEvent(
          personId: personId,
          status: OcptImageRightsStatus.signed,
        ),
      );
      peopleBloc.add(
        OcptResourcesUnavailabilityAddedEvent(
          personId: personId,
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 12),
          slot: OcptDayPartSlot.fullDay,
          startMinute: null,
          endMinute: null,
          reason: "Holiday",
        ),
      );
      final state = await waitForState(
        bloc,
        (state) =>
            state.selectedPerson!.positions.length == 1 &&
            state.selectedPerson!.skills.length == 1 &&
            state.selectedPerson!.unavailabilities.length == 1 &&
            state.selectedPerson!.imageRightsStatus == OcptImageRightsStatus.signed,
      );

      expect(state.selectedPerson!.skills.single.label, "Driving");
      expect(state.selectedPerson!.unavailabilities.single.reason, "Holiday");
      expect(state.positionCount, 1);

      await closeAll(peopleBloc, bloc);
    });

    test("reference a photo the picker answered with, and nothing when it is cancelled", () async {
      final bloc = buildBloc();
      final cancelledBloc = buildPeople(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: null),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await createPerson(bloc, cancelledBloc);

      cancelledBloc.add(
        OcptResourcesPersonPhotoPickRequestedEvent(personId: personId, fileTypeLabel: "Images"),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.selectedPerson!.photo, isNull);
      await cancelledBloc.close();

      final photoBloc = buildPeople(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/tmp/alice.jpg"),
      );
      photoBloc.add(
        OcptResourcesPersonPhotoPickRequestedEvent(personId: personId, fileTypeLabel: "Images"),
      );
      final state = await waitForState(bloc, (state) => state.selectedPerson!.photo != null);

      expect(state.selectedPerson!.photo!.path, "/tmp/alice.jpg");

      photoBloc.add(OcptResourcesPersonPhotoClearedEvent(personId: personId));
      await waitForState(bloc, (state) => state.selectedPerson!.photo == null);

      await closeAll(photoBloc, bloc);
    });
  });

  group("the events of the people bloc", () {
    String nameOf(OcptResourcesPeopleEvent event) => switch (event) {
      OcptResourcesPersonCreationRequestedEvent() => "creation",
      OcptResourcesPersonDeletionRequestedEvent() => "deletion",
      OcptResourcesPersonFieldChangedEvent() => "field",
      OcptResourcesPeopleFieldEditFlushRequestedEvent() => "field flush",
      OcptResourcesPersonColorChangedEvent() => "colour",
      OcptResourcesPersonBirthDateChangedEvent() => "birth date",
      OcptResourcesPersonTransportAutonomyChangedEvent() => "transport autonomy",
      OcptResourcesPersonImageRightsStatusChangedEvent() => "image rights status",
      OcptResourcesPersonImageRightsDateChangedEvent() => "image rights date",
      OcptResourcesPersonMileageRateChangedEvent() => "mileage rate",
      OcptResourcesPositionAddedEvent() => "position added",
      OcptResourcesPositionUpdatedEvent() => "position updated",
      OcptResourcesPositionRemovedEvent() => "position removed",
      OcptResourcesSkillAddedEvent() => "skill added",
      OcptResourcesSkillUpdatedEvent() => "skill updated",
      OcptResourcesSkillRemovedEvent() => "skill removed",
      OcptResourcesUnavailabilityAddedEvent() => "unavailability added",
      OcptResourcesUnavailabilityUpdatedEvent() => "unavailability updated",
      OcptResourcesUnavailabilityRemovedEvent() => "unavailability removed",
      OcptResourcesPersonPhotoPickRequestedEvent() => "photo pick",
      OcptResourcesPersonPhotoClearedEvent() => "photo cleared",
      OcptResourcesImageRightsDocumentPickRequestedEvent() => "document pick",
      OcptResourcesImageRightsDocumentClearedEvent() => "document cleared",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: null),
      );
      await waitForState(bloc, (state) => !state.isLoading);

      final events = <OcptResourcesPeopleEvent>[
        const OcptResourcesPersonCreationRequestedEvent(),
        const OcptResourcesPersonDeletionRequestedEvent(personId: "p"),
        const OcptResourcesPersonFieldChangedEvent(
          personId: "p",
          field: OcptPersonField.notes,
          rawValue: "",
        ),
        const OcptResourcesPeopleFieldEditFlushRequestedEvent(),
        const OcptResourcesPersonColorChangedEvent(personId: "p", colorIndex: 1),
        const OcptResourcesPersonBirthDateChangedEvent(personId: "p", date: null),
        const OcptResourcesPersonTransportAutonomyChangedEvent(
          personId: "p",
          isTransportAutonomous: true,
        ),
        const OcptResourcesPersonImageRightsStatusChangedEvent(
          personId: "p",
          status: OcptImageRightsStatus.signed,
        ),
        const OcptResourcesPersonImageRightsDateChangedEvent(personId: "p", date: null),
        const OcptResourcesPersonMileageRateChangedEvent(personId: "p", mileageRateId: null),
        const OcptResourcesPositionAddedEvent(personId: "p", positionId: "", customLabel: ""),
        const OcptResourcesPositionUpdatedEvent(id: "i", positionId: "", customLabel: ""),
        const OcptResourcesPositionRemovedEvent(id: "i"),
        const OcptResourcesSkillAddedEvent(personId: "p", label: ""),
        const OcptResourcesSkillUpdatedEvent(id: "i", label: ""),
        const OcptResourcesSkillRemovedEvent(id: "i"),
        OcptResourcesUnavailabilityAddedEvent(
          personId: "p",
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 10),
          slot: OcptDayPartSlot.fullDay,
          startMinute: null,
          endMinute: null,
          reason: "",
        ),
        OcptResourcesUnavailabilityUpdatedEvent(
          id: "i",
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 10),
          slot: OcptDayPartSlot.fullDay,
          startMinute: null,
          endMinute: null,
          reason: "",
        ),
        const OcptResourcesUnavailabilityRemovedEvent(id: "i"),
        const OcptResourcesPersonPhotoPickRequestedEvent(personId: "p", fileTypeLabel: ""),
        const OcptResourcesPersonPhotoClearedEvent(personId: "p"),
        const OcptResourcesImageRightsDocumentPickRequestedEvent(personId: "p", fileTypeLabel: ""),
        const OcptResourcesImageRightsDocumentClearedEvent(personId: "p"),
      ];
      expect(events.map(nameOf).toSet(), hasLength(23));

      // With no project open every write handler returns at its first line: the handlers are
      // reached without any of the rows the events name having to exist.
      await projectsManager.closeCurrentProject();

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => peopleBloc.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await closeAll(peopleBloc, bloc);
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      final peopleBloc = buildPeople(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);

      await closeAll(peopleBloc, bloc);
    });
  });
}
