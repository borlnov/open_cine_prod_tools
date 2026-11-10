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
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_bloc.dart';
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
  String personId,
  String otherPersonId,
  String positionId,
  String skillId,
  String unavailabilityId,
  String mileageRateId,
});

/// What the people bloc does when the database refuses a write on the address book: the handler
/// raises the mode's write error, reads nothing again, and goes on once the refusal is lifted; a
/// flush stops at the first write that fails.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptResourcesBloc modeBloc;
  late OcptResourcesPeopleBloc peopleBloc;
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_people_failure_test_");
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
    final people = projectsManager.peopleService;
    final personId = await people.createPerson(database: database).valueOrFail;
    final otherPersonId = await people.createPerson(database: database).valueOrFail;
    final positionId = await people
        .addPosition(database: database, personId: personId, positionId: "sound", customLabel: "")
        .valueOrFail;
    final skillId = await people
        .addSkill(database: database, personId: personId, label: "French")
        .valueOrFail;
    final unavailabilityId = await people
        .addUnavailability(
          database: database,
          personId: personId,
          startDate: DateTime(2026, 5),
          endDate: DateTime(2026, 5, 2),
          slot: OcptDayPartSlot.fullDay,
          reason: "Holiday",
        )
        .valueOrFail;
    await people
        .setPersonPhoto(database: database, personId: personId, path: "/photos/a.jpg")
        .valueOrFail;
    await people
        .setImageRightsDocument(database: database, personId: personId, path: "/docs/release.pdf")
        .valueOrFail;
    final mileageRateId = await projectsManager.budgetFinancingService
        .createMileageRate(database: database, label: "Car")
        .valueOrFail;

    modeBloc = OcptResourcesBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    peopleBloc = OcptResourcesPeopleBloc(
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
      personId: personId,
      otherPersonId: otherPersonId,
      positionId: positionId,
      skillId: skillId,
      unavailabilityId: unavailabilityId,
      mileageRateId: mileageRateId,
    );
  });

  tearDown(() async {
    await peopleBloc.close();
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

  /// Read straight from the database the notes of every live person, by id.
  Future<Map<String, String>> notes() async {
    final rows = await projectsManager.currentProject!.database
        .customSelect("SELECT id, notes FROM people WHERE is_deleted = 0")
        .get();

    return {for (final row in rows) row.read<String>("id"): row.read<String>("notes")};
  }

  /// The handlers, each with the table and the verb that fail it, and the event it dispatches.
  final cases =
      <String, ({String table, String verb, OcptResourcesPeopleEvent Function(_Seeded) event})>{
        "creating a person": (
          table: "people",
          verb: "INSERT",
          event: (s) => const OcptResourcesPersonCreationRequestedEvent(),
        ),
        "colouring a new person": (
          table: "people",
          verb: "UPDATE",
          event: (s) => const OcptResourcesPersonCreationRequestedEvent(),
        ),
        "erasing a person": (
          table: "people",
          verb: "UPDATE",
          event: (s) => OcptResourcesPersonDeletionRequestedEvent(personId: s.otherPersonId),
        ),
        "changing the colour": (
          table: "people",
          verb: "UPDATE",
          event: (s) => OcptResourcesPersonColorChangedEvent(personId: s.personId, colorIndex: 3),
        ),
        "changing the date of birth": (
          table: "people",
          verb: "UPDATE",
          event: (s) =>
              OcptResourcesPersonBirthDateChangedEvent(personId: s.personId, date: DateTime(1990)),
        ),
        "changing the transport autonomy": (
          table: "people",
          verb: "UPDATE",
          event: (s) => OcptResourcesPersonTransportAutonomyChangedEvent(
            personId: s.personId,
            isTransportAutonomous: true,
          ),
        ),
        "changing the image rights status": (
          table: "people",
          verb: "UPDATE",
          event: (s) => OcptResourcesPersonImageRightsStatusChangedEvent(
            personId: s.personId,
            status: OcptImageRightsStatus.signed,
          ),
        ),
        "changing the image rights date": (
          table: "people",
          verb: "UPDATE",
          event: (s) => OcptResourcesPersonImageRightsDateChangedEvent(
            personId: s.personId,
            date: DateTime(2026, 3),
          ),
        ),
        "changing the mileage rate": (
          table: "people",
          verb: "UPDATE",
          event: (s) => OcptResourcesPersonMileageRateChangedEvent(
            personId: s.personId,
            mileageRateId: s.mileageRateId,
          ),
        ),
        "adding a position": (
          table: "person_positions",
          verb: "INSERT",
          event: (s) => OcptResourcesPositionAddedEvent(
            personId: s.personId,
            positionId: "light",
            customLabel: "",
          ),
        ),
        "updating a position": (
          table: "person_positions",
          verb: "UPDATE",
          event: (s) => OcptResourcesPositionUpdatedEvent(
            id: s.positionId,
            positionId: "sound",
            customLabel: "Boom",
          ),
        ),
        "removing a position": (
          table: "person_positions",
          verb: "UPDATE",
          event: (s) => OcptResourcesPositionRemovedEvent(id: s.positionId),
        ),
        "adding a skill": (
          table: "person_skills",
          verb: "INSERT",
          event: (s) => OcptResourcesSkillAddedEvent(personId: s.personId, label: "Sailing"),
        ),
        "updating a skill": (
          table: "person_skills",
          verb: "UPDATE",
          event: (s) => OcptResourcesSkillUpdatedEvent(id: s.skillId, label: "Spanish"),
        ),
        "removing a skill": (
          table: "person_skills",
          verb: "UPDATE",
          event: (s) => OcptResourcesSkillRemovedEvent(id: s.skillId),
        ),
        "adding an unavailability": (
          table: "person_unavailabilities",
          verb: "INSERT",
          event: (s) => OcptResourcesUnavailabilityAddedEvent(
            personId: s.personId,
            startDate: DateTime(2026, 6),
            endDate: DateTime(2026, 6, 2),
            slot: OcptDayPartSlot.morning,
            startMinute: null,
            endMinute: null,
            reason: "Exam",
          ),
        ),
        "updating an unavailability": (
          table: "person_unavailabilities",
          verb: "UPDATE",
          event: (s) => OcptResourcesUnavailabilityUpdatedEvent(
            id: s.unavailabilityId,
            startDate: DateTime(2026, 5),
            endDate: DateTime(2026, 5, 2),
            slot: OcptDayPartSlot.fullDay,
            startMinute: null,
            endMinute: null,
            reason: "Illness",
          ),
        ),
        "removing an unavailability": (
          table: "person_unavailabilities",
          verb: "UPDATE",
          event: (s) => OcptResourcesUnavailabilityRemovedEvent(id: s.unavailabilityId),
        ),
        "picking a photo": (
          table: "assets",
          verb: "INSERT",
          event: (s) => OcptResourcesPersonPhotoPickRequestedEvent(
            personId: s.personId,
            fileTypeLabel: "Images",
          ),
        ),
        "clearing the photo": (
          table: "people",
          verb: "UPDATE",
          event: (s) => OcptResourcesPersonPhotoClearedEvent(personId: s.personId),
        ),
        "picking an image rights document": (
          table: "assets",
          verb: "INSERT",
          event: (s) => OcptResourcesImageRightsDocumentPickRequestedEvent(
            personId: s.personId,
            fileTypeLabel: "Documents",
          ),
        ),
        "clearing the image rights document": (
          table: "people",
          verb: "UPDATE",
          event: (s) => OcptResourcesImageRightsDocumentClearedEvent(personId: s.personId),
        ),
      };

  for (final entry in cases.entries) {
    test("${entry.key} raises the write error, reads nothing again, and goes through once the "
        "refusal is lifted", () async {
      final held = modeBloc.state;
      await refuse(entry.value.verb, entry.value.table);

      peopleBloc.add(entry.value.event(seeded));
      await settle();

      expect(modeBloc.state.hasWriteError, isTrue);
      expect(modeBloc.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");

      await allow(entry.value.verb, entry.value.table);
      modeBloc.add(const OcptResourcesWriteErrorDismissedEvent());
      peopleBloc.add(entry.value.event(seeded));
      await settle();

      expect(modeBloc.state.hasWriteError, isFalse);
      expect(modeBloc.state.reloadEpoch, isNot(held.reloadEpoch));
    });
  }

  test("a new person whose colour cannot be written is not selected", () async {
    await refuse("UPDATE", "people");

    peopleBloc.add(const OcptResourcesPersonCreationRequestedEvent());
    await settle();

    expect(modeBloc.state.hasWriteError, isTrue);
    expect(modeBloc.state.selectedPerson, isNull);
  });

  test("an erasure refused half way keeps the person and everything of theirs", () async {
    await refuse("UPDATE", "person_skills");

    peopleBloc.add(OcptResourcesPersonDeletionRequestedEvent(personId: seeded.personId));
    await settle();

    expect(modeBloc.state.hasWriteError, isTrue);
    final person = modeBloc.state.people.firstWhere((person) => person.id == seeded.personId);
    expect(person.skills, isNotEmpty);
    expect(person.photo, isNotNull);
    final erased = await projectsManager.currentProject!.database
        .customSelect("SELECT COUNT(*) AS n FROM local_erasures")
        .getSingle();
    expect(erased.read<int>("n"), 0);
  });

  group("flushing the typed edits", () {
    /// Type [note] into the notes of [personId].
    Future<void> type(String personId, String note) async {
      peopleBloc.add(
        OcptResourcesPersonFieldChangedEvent(
          personId: personId,
          field: OcptPersonField.notes,
          rawValue: note,
        ),
      );
      await settle();
    }

    test("a refused write stops the edits after it", () async {
      await type(seeded.personId, "Tall");
      await type(seeded.otherPersonId, "Short");
      await refuse("UPDATE", "people", when: "NEW.id = '${seeded.personId}'");

      final status = await peopleBloc.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.failed);
      expect(modeBloc.state.hasWriteError, isTrue);
      final stored = await notes();
      expect(stored[seeded.personId], isEmpty);
      expect(stored[seeded.otherPersonId], isEmpty, reason: "the edit after the refused one");
      expect(peopleBloc.state.pendingFieldEdits, hasLength(2));
    });

    test("a refused flush on leaving stops the edits after it, and keeps them pending", () async {
      await type(seeded.personId, "Tall");
      await type(seeded.otherPersonId, "Short");
      await refuse("UPDATE", "people", when: "NEW.id = '${seeded.personId}'");

      await peopleBloc.flushPendingWritesWithoutState();

      expect((await notes())[seeded.otherPersonId], isEmpty, reason: "the edit after the refused");
      expect(peopleBloc.state.pendingFieldEdits, isNotEmpty);
      expect(modeBloc.state.hasWriteError, isFalse, reason: "a flush on leaving only logs");
    });

    test("a refused erasure keeps the edits typed into the person", () async {
      await type(seeded.otherPersonId, "Short");
      await refuse("UPDATE", "people");

      peopleBloc.add(OcptResourcesPersonDeletionRequestedEvent(personId: seeded.otherPersonId));
      await settle();

      expect(modeBloc.state.hasWriteError, isTrue);
      expect(peopleBloc.state.pendingFieldEdits, {
        (seeded.otherPersonId, OcptPersonField.notes): "Short",
      });
    });

    test("a refused flush on leaving is written again by the next one", () async {
      await type(seeded.personId, "Tall");
      await refuse("UPDATE", "people");
      await peopleBloc.flushPendingWritesWithoutState();
      await allow("UPDATE", "people");

      await peopleBloc.flushPendingWritesWithoutState();

      expect((await notes())[seeded.personId], "Tall");
    });
  });
}
