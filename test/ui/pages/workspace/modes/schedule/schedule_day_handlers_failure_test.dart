// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// The rows every case below acts on, all real and all written before the database starts to
/// refuse.
class _Fixtures {
  /// The day everything hangs off.
  final String dayId;

  /// The slot that carries the blocks, the crew, the cast and the guest.
  final String slotId;

  /// The second slot of the day, which a block moves to and the first slot is reordered past.
  final String otherSlotId;

  /// The first block of [slotId], a meal.
  final String blockId;

  /// An audition block of [slotId], placed after [blockId].
  final String auditionBlockId;

  /// A hold block of [slotId], which names no sequence yet.
  final String holdBlockId;

  /// A sequence of the screenplay, to name from [holdBlockId].
  final String sceneId;

  /// A location, to give to a slot.
  final String locationId;

  /// A shot, to place in a slot.
  final String shotId;

  /// A person, to crew or to invite.
  final String personId;

  /// A part, to convoke.
  final String roleId;

  /// A candidacy for [roleId], not yet convoked to [auditionBlockId].
  final String roleCandidateId;

  /// The crew assignment of [personId] on [slotId].
  final String crewMemberId;

  /// The convocation of [roleId] on [slotId].
  final String castRoleId;

  /// The guest attendance of [personId] on [slotId].
  final String guestId;

  /// The convocation of [roleCandidateId] on [auditionBlockId].
  final String blockCandidateId;

  /// The event of [dayId].
  final String eventId;

  /// Class constructor
  const _Fixtures({
    required this.dayId,
    required this.slotId,
    required this.otherSlotId,
    required this.blockId,
    required this.auditionBlockId,
    required this.holdBlockId,
    required this.sceneId,
    required this.locationId,
    required this.shotId,
    required this.personId,
    required this.roleId,
    required this.roleCandidateId,
    required this.crewMemberId,
    required this.castRoleId,
    required this.guestId,
    required this.blockCandidateId,
    required this.eventId,
  });
}

/// One handler of the day bloc: the event that reaches it, built from the rows it acts on.
typedef _Case = (String handler, OcptScheduleEvent Function(_Fixtures f) event);

/// A debounce no test waits out, so every typed edit stays pending until a flush.
const _neverDebounce = Duration(days: 1);

/// What every handler of the day bloc that writes the schedule does when the database refuses its
/// write, with a real SQLite failure (a trigger that aborts every insert and update): it stops at
/// the write, the mode reads nothing again and emits nothing. Each case is then sent a second time
/// with the refusal lifted, which must read again, so that a handler cannot pass by never reaching
/// its write.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptScheduleBloc mode;
  late OcptScheduleDayBloc day;
  late _Fixtures fixtures;

  final cases = <_Case>[
    ("slot creation", (f) => OcptScheduleSlotCreatedEvent(dayId: f.dayId)),
    (
      "slot place change",
      (f) => OcptScheduleSlotPlaceChangedEvent(
        slotId: f.slotId,
        locationId: f.locationId,
        setId: null,
      ),
    ),
    (
      "slot anchor change",
      (f) => OcptScheduleSlotAnchorChangedEvent(
        slotId: f.slotId,
        edge: OcptShootingSlotAnchorEdge.start,
        minute: 600,
        sourceSlotId: null,
      ),
    ),
    (
      "slot reorder",
      (f) => OcptScheduleSlotReorderedEvent(dayId: f.dayId, slotId: f.slotId, newPosition: 1),
    ),
    ("slot deletion", (f) => OcptScheduleSlotDeletionConfirmedEvent(slotId: f.slotId)),
    (
      "crew member addition",
      (f) => OcptScheduleSlotCrewMemberAddedEvent(slotId: f.otherSlotId, personId: f.personId),
    ),
    (
      "crew member position change",
      (f) => OcptScheduleSlotCrewMemberPositionChangedEvent(
        crewMemberId: f.crewMemberId,
        positionId: "",
        customLabel: "Gaffer",
      ),
    ),
    (
      "crew member removal",
      (f) => OcptScheduleSlotCrewMemberRemovedEvent(crewMemberId: f.crewMemberId),
    ),
    (
      "cast role addition",
      (f) => OcptScheduleSlotCastRoleAddedEvent(slotId: f.otherSlotId, roleId: f.roleId),
    ),
    ("cast role removal", (f) => OcptScheduleSlotCastRoleRemovedEvent(castRoleId: f.castRoleId)),
    (
      "guest addition",
      (f) => OcptScheduleSlotGuestAddedEvent(slotId: f.otherSlotId, personId: f.personId),
    ),
    ("guest removal", (f) => OcptScheduleSlotGuestRemovedEvent(guestId: f.guestId)),
    (
      "candidate addition",
      (f) => OcptScheduleBlockCandidateAddedEvent(
        blockId: f.auditionBlockId,
        roleCandidateId: f.roleCandidateId,
      ),
    ),
    (
      "candidate removal",
      (f) => OcptScheduleBlockCandidateRemovedEvent(blockCandidateId: f.blockCandidateId),
    ),
    ("day event creation", (f) => OcptScheduleDayEventCreatedEvent(dayId: f.dayId, minute: 720)),
    (
      "day event minute change",
      (f) => OcptScheduleDayEventMinuteChangedEvent(eventId: f.eventId, minute: 800),
    ),
    ("day event deletion", (f) => OcptScheduleDayEventDeletionConfirmedEvent(eventId: f.eventId)),
    (
      "block creation",
      (f) => OcptScheduleBlockCreatedEvent(slotId: f.slotId, kind: OcptShootingBlockKind.meal),
    ),
    (
      "shot placement",
      (f) => OcptScheduleShotBlockCreatedEvent(slotId: f.slotId, shotId: f.shotId),
    ),
    (
      "block duration change",
      (f) => OcptScheduleBlockDurationChangedEvent(blockId: f.blockId, durationMinutes: 45),
    ),
    (
      "block anchor change",
      (f) => OcptScheduleBlockAnchorChangedEvent(blockId: f.blockId, anchorMinute: 780),
    ),
    (
      "block sequence change",
      (f) => OcptScheduleBlockSequenceChangedEvent(blockId: f.holdBlockId, sceneId: f.sceneId),
    ),
    ("block reorder", (f) => OcptScheduleBlockReorderedEvent(blockId: f.blockId, newPosition: 1)),
    (
      "block move to another slot",
      (f) => OcptScheduleBlockMovedToSlotEvent(blockId: f.blockId, targetSlotId: f.otherSlotId),
    ),
    ("block deletion", (f) => OcptScheduleBlockDeletionConfirmedEvent(blockId: f.blockId)),
  ];

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_day_handlers_failure_test_");
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

    fixtures = await _seed(projectsManager);

    mode = OcptScheduleBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    day = OcptScheduleDayBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fieldEditDebounce: _neverDebounce,
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
  });

  tearDown(() async {
    await day.close();
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make every insert and every update of every table fail with a database error.
  Future<void> refuseEveryWrite() async {
    final database = projectsManager.currentProject!.database;
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
          "AND sql NOT LIKE 'CREATE VIRTUAL%'",
        )
        .get();
    for (final table in tables) {
      final name = table.read<String>("name");
      for (final verb in const ["INSERT", "UPDATE"]) {
        await database.customStatement(
          "CREATE TRIGGER refuse_${verb}_$name BEFORE $verb ON $name "
          "BEGIN SELECT RAISE(ABORT, 'refused'); END",
        );
      }
    }
  }

  /// Lift every refusal [refuseEveryWrite] set.
  Future<void> allowEveryWrite() async {
    final database = projectsManager.currentProject!.database;
    final triggers = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'refuse_%'",
        )
        .get();
    for (final trigger in triggers) {
      await database.customStatement("DROP TRIGGER ${trigger.read<String>("name")}");
    }
  }

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  for (final (handler, event) in cases) {
    test(
      "the $handler stops when the database refuses the write, and goes on once it does not",
      () async {
        await refuseEveryWrite();
        final epoch = mode.state.reloadEpoch;
        final modeState = mode.state;
        final dayState = day.state;

        day.add(event(fixtures));
        await settle();

        expect(mode.state.reloadEpoch, epoch, reason: "nothing is read again");
        expect(mode.state, same(modeState), reason: "the mode emits nothing");
        expect(day.state, same(dayState), reason: "the view emits nothing");

        await allowEveryWrite();
        day.add(event(fixtures));
        await settle();

        expect(
          mode.state.reloadEpoch,
          greaterThan(epoch),
          reason: "the same event reads again once the write can land",
        );
      },
    );
  }

  test("every handler that writes the schedule is in the table", () {
    expect(cases, hasLength(25));
    expect({for (final (handler, _) in cases) handler}, hasLength(25));
  });
}

/// Write the rows [_Fixtures] names, through the services.
Future<_Fixtures> _seed(OcptProjectsManager projectsManager) async {
  final project = projectsManager.currentProject!;
  final database = project.database;
  final schedule = projectsManager.scheduleService;

  final dayId = await schedule
      .createDay(database: database, date: DateTime(2026, 8, 10))
      .valueOrFail;
  final slotId =
      (await schedule.loadSchedule(database: database).valueOrFail).slotsByDayId[dayId]!.single.id;
  final otherSlotId = await schedule
      .createSlot(database: database, shootingDayId: dayId, anchorMinute: 840)
      .valueOrFail;
  final blockId = await schedule
      .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.meal)
      .maybeValueOrFail;
  final auditionBlockId = await schedule
      .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
      .maybeValueOrFail;

  final holdBlockId = await schedule
      .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.hold)
      .maybeValueOrFail;
  final locationId = await projectsManager.locationsService.createLocation(
    database: database,
    name: "Kitchen",
  );

  final personId = (await projectsManager.peopleService.createPerson(database: database))!;
  final roleId = (await projectsManager.roleIndexService.addRole(
    database: database,
    screenplayId: project.primaryScreenplayId,
    name: "LEA",
    kind: OcptRoleKind.silent,
  ))!;
  final otherPersonId = (await projectsManager.peopleService.createPerson(database: database))!;
  const convokedCandidacyId = "candidacy-1";
  const roleCandidateId = "candidacy-2";
  await database
      .into(database.ocptRoleCandidatesTable)
      .insert(
        OcptRoleCandidatesTableCompanion.insert(
          id: convokedCandidacyId,
          roleId: roleId,
          personId: personId,
        ),
      );
  await database
      .into(database.ocptRoleCandidatesTable)
      .insert(
        OcptRoleCandidatesTableCompanion.insert(
          id: roleCandidateId,
          roleId: roleId,
          personId: otherPersonId,
        ),
      );
  const sceneId = "scene-1";
  await database
      .into(database.ocptScenesTable)
      .insert(
        OcptScenesTableCompanion.insert(
          id: sceneId,
          screenplayId: project.primaryScreenplayId,
          position: 0,
          heading: "INT. CUISINE - JOUR",
          charStart: 0,
          charEnd: 1,
        ),
      );
  final shotId = (await projectsManager.shotListService.createShot(
    database: database,
    screenplayId: project.primaryScreenplayId,
    sceneId: sceneId,
  ))!;

  final crewMemberId = await schedule
      .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
      .maybeValueOrFail;
  final castRoleId = await schedule
      .addSlotCastRole(database: database, slotId: slotId, roleId: roleId)
      .maybeValueOrFail;
  final guestId = await schedule
      .addSlotGuest(database: database, slotId: slotId, personId: personId)
      .maybeValueOrFail;
  final blockCandidateId = await schedule
      .addBlockCandidate(
        database: database,
        blockId: auditionBlockId!,
        roleCandidateId: convokedCandidacyId,
      )
      .maybeValueOrFail;
  final eventId = await schedule
      .createDayEvent(database: database, dayId: dayId, minute: 600)
      .maybeValueOrFail;

  return _Fixtures(
    dayId: dayId,
    slotId: slotId,
    otherSlotId: otherSlotId,
    blockId: blockId!,
    auditionBlockId: auditionBlockId,
    holdBlockId: holdBlockId!,
    sceneId: sceneId,
    locationId: locationId!,
    shotId: shotId,
    personId: personId,
    roleId: roleId,
    roleCandidateId: roleCandidateId,
    crewMemberId: crewMemberId!,
    castRoleId: castRoleId!,
    guestId: guestId!,
    blockCandidateId: blockCandidateId!,
    eventId: eventId!,
  );
}
