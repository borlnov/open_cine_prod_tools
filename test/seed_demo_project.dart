// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

// Seeds the demonstration project the README screenshots are taken against.
//
// This is not a test: it is a script that happens to run through `flutter test`, which is the only
// runner in this repository that gives a plain Dart VM the app's package resolution and the system
// `libsqlite3` drift needs. Its name deliberately lacks the `_test` suffix, so `flutter test` never
// picks it up on its own.
//
//   flutter test test/seed_demo_project.dart
//
// It writes `$OCPT_DEMO_PROJECT` (default: `/tmp/ocpt-screenshot/home/The Last Ferry.ocpt`),
// replacing whatever is there, and drives the app's own services rather than raw inserts, so the
// file it leaves behind is one the application could have written itself.

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_budget_cnc_postes.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// The Fountain text of the demonstration screenplay, written for the purpose so the images carry
/// no third-party work.
const _fountainText = '''
Title: The Last Ferry
Credit: Written by
Author: A demonstration screenplay
Draft date: September 2026

INT. HARBOUR CAFE - DAWN

Rain drums on the window. NORA, 40s, coat still dripping, sets a leather satchel on the counter.

The cafe is empty but for the CAFE OWNER, who polishes the same glass he has been polishing for an hour.

NORA
One coffee. And the schedule for the ferry.

OWNER
The ferry left. Storm's coming.

Nora unclasps the satchel. Inside, a folded nautical chart and a brass compass that has seen better decades.

NORA
Then I'll need a boat.

INT. HARBOUR CAFE - CONTINUOUS

The OWNER puts down the glass. He looks at the compass for a long moment.

OWNER
There's a man at the end of the pier. He has a boat. He won't take you.

NORA
He will.

She leaves a banknote under the saucer and walks out into the rain.

EXT. PIER - DAWN

Wind. The planks are slick. At the far end, a battered fishing boat rides the swell, and beside it, MARTIN, 60s, in a yellow oilskin, coiling a rope with hands that know the work.

NORA
They tell me you have a boat.

MARTIN
They tell you wrong. I have a wreck that floats.

She unfolds the nautical chart against the wind and holds it out. Martin does not take it.

MARTIN
Nobody crosses today.

NORA
I am not asking to cross. I am asking to be put down on the island and left there.

Martin looks at the chart. At the pencil ring drawn around a rock nobody lives on.

EXT. FISHING BOAT - SEA - MORNING

Grey water, no horizon. The boat digs into the swell. Nora braces against the wheelhouse, the satchel held shut with both hands.

Martin watches the compass swing, and holds his course anyway.

MARTIN
Whatever is out there, it waited this long.
''';

/// One crew member of the demonstration project's address book: their name and the catalogue
/// position they hold.
typedef _CrewSeed = ({String firstName, String lastName, String positionId});

/// The crew the demonstration project convokes, in the order the address book lists them.
const _crew = <_CrewSeed>[
  (firstName: "Camille", lastName: "Ferrand", positionId: "director"),
  (firstName: "Yanis", lastName: "Berthier", positionId: "firstAssistantDirector"),
  (firstName: "Elsa", lastName: "Marchand", positionId: "directorOfPhotography"),
  (firstName: "Nadia", lastName: "Lefèvre", positionId: "scriptSupervisor"),
  (firstName: "Tomás", lastName: "Ruiz", positionId: "soundEngineer"),
  (firstName: "Hugo", lastName: "Danet", positionId: "gaffer"),
  (firstName: "Marion", lastName: "Vidal", positionId: "makeupArtist"),
  (firstName: "Paul", lastName: "Ozanne", positionId: "productionManager"),
];

/// The actors the demonstration project casts, by the screenplay character they play.
const _cast = <String, ({String firstName, String lastName})>{
  "NORA": (firstName: "Léa", lastName: "Combes"),
  "OWNER": (firstName: "Gilbert", lastName: "Kervella"),
  "MARTIN": (firstName: "André", lastName: "Le Gall"),
};

void main() {
  // Every service logs through appLogger(), which needs a global manager instance to exist;
  // merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const elementsService = OcptElementsService();
  const locationsService = OcptLocationsService();
  const roleIndexService = OcptRoleIndexService();
  const breakdownService = OcptBreakdownService(
    elementsService: elementsService,
    locationsService: locationsService,
  );
  Future<String> deviceId() async => "seed-device";
  final shotListService = OcptShotListService(deviceId: deviceId);
  const peopleService = OcptPeopleService();
  const scheduleService = OcptScheduleService();
  const budgetQuoteService = OcptBudgetQuoteService();
  const budgetJournalService = OcptBudgetJournalService();
  const budgetFinancingService = OcptBudgetFinancingService();
  const budgetSharingService = OcptBudgetSharingService();
  final screenplayService = OcptScreenplayService(
    sceneIndexService: const OcptSceneIndexService(),
    shotListService: shotListService,
    shotCoverageService: OcptShotCoverageService(deviceId: deviceId),
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: scheduleService,
    deviceId: deviceId,
  );

  test("seed the demonstration project", () async {
    final path =
        Platform.environment["OCPT_DEMO_PROJECT"] ??
        "/tmp/ocpt-screenshot/home/The Last Ferry.ocpt";
    final file = File(path);
    await file.parent.create(recursive: true);
    if (file.existsSync()) {
      await file.delete();
    }

    final database = OcptProjectDatabase(file);
    addTearDown(database.close);

    final now = DateTime.now();
    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: "The Last Ferry",
            createdAt: now,
            appVersionAtCreation: "0.1.0",
            pageFormat: OcptPageFormat.a4,
            currencyCode: const Value("EUR"),
          ),
        );

    final screenplayId = const Uuid().v4();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "The Last Ferry",
            updatedAt: now,
            number: const Value(1),
            sortKey: Value(ocptFractionalKeyBetween()),
          ),
        );

    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: _fountainText,
      snapshotReason: OcptSnapshotReason.import,
    );

    // ---------------------------------------------------------------- the scene index just built

    final sceneRows =
        (await (database.select(database.ocptScenesTable)
                  ..where((row) => row.screenplayId.equals(screenplayId))
                  ..orderBy([(row) => OrderingTerm.asc(row.position)]))
                .get())
            .where((row) => !row.isDeleted)
            .toList();
    expect(sceneRows, hasLength(4), reason: "the demonstration screenplay holds four scenes");
    final sceneIds = [for (final row in sceneRows) row.id];

    // ------------------------------------------------------------------------------- the address
    // book

    final crewIds = <String, String>{};
    for (final (index, member) in _crew.indexed) {
      final personId = (await peopleService.createPerson(database: database))!;
      await peopleService.updatePerson(
        database: database,
        personId: personId,
        firstName: Value(member.firstName),
        lastName: Value(member.lastName),
        city: const Value("Douarnenez"),
        country: const Value("France"),
        colorIndex: Value(index),
      );
      await peopleService.addPosition(
        database: database,
        personId: personId,
        positionId: member.positionId,
        customLabel: "",
      );
      crewIds[member.positionId] = personId;
    }

    final actorIds = <String, String>{};
    for (final (index, entry) in _cast.entries.indexed) {
      final personId = (await peopleService.createPerson(database: database))!;
      await peopleService.updatePerson(
        database: database,
        personId: personId,
        firstName: Value(entry.value.firstName),
        lastName: Value(entry.value.lastName),
        city: const Value("Quimper"),
        country: const Value("France"),
        colorIndex: Value(_crew.length + index),
      );
      actorIds[entry.key] = personId;
    }

    // The script supervisor is away the second day, which is what the alerts panel reports against
    // the convocations below.
    await peopleService.addUnavailability(
      database: database,
      personId: crewIds["scriptSupervisor"]!,
      startDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 9, 16),
      slot: OcptDayPartSlot.fullDay,
      reason: "Second unit on another production",
    );

    // ------------------------------------------------------------------------------------ the
    // cast, reconciled from the screenplay's own speaking characters

    final roles = await roleIndexService.loadRoles(database: database);
    final roleIdByName = {for (final role in roles) role.name: role.id};
    for (final entry in actorIds.entries) {
      await roleIndexService.updateRole(
        database: database,
        roleId: roleIdByName[entry.key]!,
        personId: Value(entry.value),
      );
    }

    // ------------------------------------------------------------------------- the locations and
    // their sets

    final harbourId = (await locationsService.createLocation(
      database: database,
      name: "Douarnenez harbour",
    ))!;
    await locationsService.updateLocation(
      database: database,
      locationId: harbourId,
      colorIndex: const Value(1),
      addressLine1: const Value("Quai du Grand Port"),
      postalCode: const Value("29100"),
      city: const Value("Douarnenez"),
      country: const Value("France"),
      latitude: const Value(48.0947),
      longitude: const Value(-4.3294),
      permitStatus: const Value(OcptPermitStatus.granted),
      permitLabel: const Value("Town hall — quay and terrace"),
      parkingNotes: const Value("Unit base behind the fish market, 200 m from the cafe."),
    );
    final cafeSetId = (await locationsService.createSet(
      database: database,
      locationId: harbourId,
      name: "Harbour cafe",
    ))!;
    final pierSetId = (await locationsService.createSet(
      database: database,
      locationId: harbourId,
      name: "Pier",
    ))!;

    final seaId = (await locationsService.createLocation(
      database: database,
      name: "Bay of Douarnenez",
    ))!;
    await locationsService.updateLocation(
      database: database,
      locationId: seaId,
      colorIndex: const Value(5),
      city: const Value("Douarnenez"),
      country: const Value("France"),
      latitude: const Value(48.1042),
      longitude: const Value(-4.4058),
      permitStatus: const Value(OcptPermitStatus.requested),
      permitLabel: const Value("Maritime authority — filming at sea"),
      constraintsNotes: const Value("Sailing window depends on the swell; skipper decides at 05:00."),
    );
    final boatSetId = (await locationsService.createSet(
      database: database,
      locationId: seaId,
      name: "Fishing boat",
    ))!;

    for (final (index, setId) in [cafeSetId, cafeSetId, pierSetId, boatSetId].indexed) {
      await locationsService.assignSceneToSet(
        database: database,
        sceneId: sceneIds[index],
        setId: setId,
      );
    }

    // ---------------------------------------------------------------- the elements catalogue, in
    // the order that mints the codes the resources mode shows

    /// Creates one element of the catalogue and returns its id.
    Future<String> createElement({
      required String name,
      required OcptElementCategory category,
      required OcptElementSourceKind sourceKind,
      OcptElementStatus status = OcptElementStatus.toFind,
      String notes = "",
    }) async {
      final elementId = (await elementsService.createElement(
        database: database,
        name: name,
        category: category,
        sourceKind: sourceKind,
      ))!;
      await elementsService.updateElement(
        database: database,
        elementId: elementId,
        status: Value(status),
        notes: Value(notes),
      );
      return elementId;
    }

    final satchelId = await createElement(
      name: "Leather satchel",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.rented,
      status: OcptElementStatus.reserved,
    );
    final compassId = await createElement(
      name: "Brass compass",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.toBuy,
      notes: "Has to read as older than the boat.",
    );
    final chartId = await createElement(
      name: "Nautical chart",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.toMake,
      status: OcptElementStatus.beingMade,
      notes: "Pencil ring around the island, drawn by hand.",
    );
    final banknoteId = await createElement(
      name: "Period banknote",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.toMake,
      status: OcptElementStatus.beingMade,
    );
    final oilskinId = await createElement(
      name: "Yellow oilskin",
      category: OcptElementCategory.costume,
      sourceKind: OcptElementSourceKind.rented,
      status: OcptElementStatus.reserved,
    );
    final wetCoatId = await createElement(
      name: "Nora's wet coat",
      category: OcptElementCategory.costume,
      sourceKind: OcptElementSourceKind.owned,
      status: OcptElementStatus.confirmed,
      notes: "Two of them: one soaked, one dry.",
    );
    final boatId = await createElement(
      name: "Battered fishing boat",
      category: OcptElementCategory.vehicle,
      sourceKind: OcptElementSourceKind.borrowed,
      status: OcptElementStatus.reserved,
      notes: "Skipper comes with it and holds the wheel off camera.",
    );
    final rainTowerId = await createElement(
      name: "Rain tower",
      category: OcptElementCategory.specialEquipment,
      sourceKind: OcptElementSourceKind.rented,
      status: OcptElementStatus.reserved,
    );

    // -------------------------------------------------------------------------- the breakdown
    // pass, which is also what links each element to the scenes that need it

    /// Tags the first occurrence of [text] in scene [sceneIndex], pointing it at [targetId].
    Future<void> tag(
      int sceneIndex,
      String text,
      OcptBreakdownTargetKind targetKind,
      String targetId,
    ) async {
      final row = sceneRows[sceneIndex];
      final sceneText = _fountainText.substring(row.charStart, row.charEnd);
      final startOffset = sceneText.indexOf(text);
      expect(startOffset, isNonNegative, reason: "'$text' is in scene ${sceneIndex + 1}");

      await breakdownService.createTag(
        database: database,
        sceneId: row.id,
        startOffset: startOffset,
        endOffset: startOffset + text.length,
        taggedText: text,
        targetKind: targetKind,
        targetId: targetId,
      );
    }

    await tag(0, "HARBOUR CAFE", OcptBreakdownTargetKind.set, cafeSetId);
    await tag(0, "Rain drums on the window", OcptBreakdownTargetKind.element, rainTowerId);
    await tag(0, "NORA, 40s", OcptBreakdownTargetKind.role, roleIdByName["NORA"]!);
    await tag(0, "coat still dripping", OcptBreakdownTargetKind.element, wetCoatId);
    await tag(0, "leather satchel", OcptBreakdownTargetKind.element, satchelId);
    await tag(0, "CAFE OWNER", OcptBreakdownTargetKind.role, roleIdByName["OWNER"]!);
    await tag(0, "nautical chart", OcptBreakdownTargetKind.element, chartId);
    await tag(0, "brass compass", OcptBreakdownTargetKind.element, compassId);

    await tag(1, "HARBOUR CAFE", OcptBreakdownTargetKind.set, cafeSetId);
    await tag(1, "compass", OcptBreakdownTargetKind.element, compassId);
    await tag(1, "banknote", OcptBreakdownTargetKind.element, banknoteId);

    await tag(2, "PIER", OcptBreakdownTargetKind.set, pierSetId);
    await tag(2, "fishing boat", OcptBreakdownTargetKind.element, boatId);
    await tag(2, "MARTIN, 60s", OcptBreakdownTargetKind.role, roleIdByName["MARTIN"]!);
    await tag(2, "yellow oilskin", OcptBreakdownTargetKind.element, oilskinId);
    await tag(2, "nautical chart", OcptBreakdownTargetKind.element, chartId);

    await tag(3, "FISHING BOAT", OcptBreakdownTargetKind.set, boatSetId);
    await tag(3, "compass", OcptBreakdownTargetKind.element, compassId);

    for (final (index, status) in const [
      OcptBreakdownSceneStatus.done,
      OcptBreakdownSceneStatus.done,
      OcptBreakdownSceneStatus.inProgress,
      OcptBreakdownSceneStatus.toDo,
    ].indexed) {
      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: sceneIds[index],
        status: Value(status),
      );
    }

    // ------------------------------------------------------------------------------- the shot
    // list

    /// Creates one shot of scene [sceneIndex] and returns its id.
    Future<String> createShot({
      required int sceneIndex,
      required String shotSize,
      required String framing,
      required String cameraMove,
      required int screenSeconds,
      required List<String> characters,
      int difficulty = 1,
    }) async {
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneIds[sceneIndex],
      ))!;
      await shotListService.updateShot(
        database: database,
        shotId: shotId,
        shotSize: Value(shotSize),
        framing: Value(framing),
        cameraMove: Value(cameraMove),
        lens: const Value("35 mm"),
        recordingFormat: const Value("4K · 25 fps"),
        sound: const Value("Direct"),
        estimatedDurationMs: Value(screenSeconds * 1000),
        plannedTakes: const Value(3),
        difficultySet: Value(difficulty),
        difficultyCamera: Value(difficulty),
      );
      for (final character in characters) {
        await shotListService.attachCharacter(
          database: database,
          shotId: shotId,
          characterName: character,
        );
      }
      return shotId;
    }

    final shotsByScene = <int, List<String>>{};

    /// Records [shotId] as the next shot of scene [sceneIndex].
    void record(int sceneIndex, String shotId) =>
        shotsByScene.putIfAbsent(sceneIndex, () => <String>[]).add(shotId);

    record(
      0,
      await createShot(
        sceneIndex: 0,
        shotSize: "Wide",
        framing: "The cafe, the rain on the window, Nora coming in.",
        cameraMove: "Static",
        screenSeconds: 24,
        characters: ["NORA", "OWNER"],
      ),
    );
    record(
      0,
      await createShot(
        sceneIndex: 0,
        shotSize: "Medium",
        framing: "Nora at the counter, the satchel between them.",
        cameraMove: "Slow push in",
        screenSeconds: 32,
        characters: ["NORA", "OWNER"],
        difficulty: 2,
      ),
    );
    record(
      0,
      await createShot(
        sceneIndex: 0,
        shotSize: "Close-up",
        framing: "The brass compass in the open satchel.",
        cameraMove: "Static",
        screenSeconds: 9,
        characters: ["NORA"],
      ),
    );
    record(
      0,
      await createShot(
        sceneIndex: 0,
        shotSize: "Close-up",
        framing: "The owner, still polishing, watching her.",
        cameraMove: "Handheld",
        screenSeconds: 11,
        characters: ["OWNER"],
        difficulty: 2,
      ),
    );

    record(
      1,
      await createShot(
        sceneIndex: 1,
        shotSize: "Medium",
        framing: "The owner puts the glass down.",
        cameraMove: "Static",
        screenSeconds: 18,
        characters: ["OWNER"],
      ),
    );
    record(
      1,
      await createShot(
        sceneIndex: 1,
        shotSize: "Close-up",
        framing: "Nora, hearing what he is not saying.",
        cameraMove: "Static",
        screenSeconds: 14,
        characters: ["NORA"],
      ),
    );
    record(
      1,
      await createShot(
        sceneIndex: 1,
        shotSize: "Wide",
        framing: "The banknote under the saucer, the door swinging.",
        cameraMove: "Pan",
        screenSeconds: 16,
        characters: ["NORA", "OWNER"],
      ),
    );

    record(
      2,
      await createShot(
        sceneIndex: 2,
        shotSize: "Wide",
        framing: "The pier, the boat riding the swell, Martin at the far end.",
        cameraMove: "Crane down",
        screenSeconds: 22,
        characters: ["NORA", "MARTIN"],
        difficulty: 3,
      ),
    );
    record(
      2,
      await createShot(
        sceneIndex: 2,
        shotSize: "Medium",
        framing: "Martin coiling the rope, not looking up.",
        cameraMove: "Static",
        screenSeconds: 26,
        characters: ["MARTIN"],
        difficulty: 2,
      ),
    );
    record(
      2,
      await createShot(
        sceneIndex: 2,
        shotSize: "Close-up",
        framing: "The chart snapping in the wind, the pencil ring.",
        cameraMove: "Handheld",
        screenSeconds: 12,
        characters: ["NORA"],
        difficulty: 2,
      ),
    );
    record(
      2,
      await createShot(
        sceneIndex: 2,
        shotSize: "Two-shot",
        framing: "Nora and Martin, the wind between them.",
        cameraMove: "Static",
        screenSeconds: 28,
        characters: ["NORA", "MARTIN"],
      ),
    );

    record(
      3,
      await createShot(
        sceneIndex: 3,
        shotSize: "Wide",
        framing: "The boat digging into the swell, no horizon.",
        cameraMove: "Handheld",
        screenSeconds: 20,
        characters: ["NORA", "MARTIN"],
        difficulty: 3,
      ),
    );
    record(
      3,
      await createShot(
        sceneIndex: 3,
        shotSize: "Medium",
        framing: "Nora braced against the wheelhouse.",
        cameraMove: "Handheld",
        screenSeconds: 17,
        characters: ["NORA"],
        difficulty: 3,
      ),
    );
    record(
      3,
      await createShot(
        sceneIndex: 3,
        shotSize: "Close-up",
        framing: "The compass swinging, the course held.",
        cameraMove: "Static",
        screenSeconds: 13,
        characters: ["MARTIN"],
      ),
    );

    // ------------------------------------------------------------------------------- the schedule

    /// The id of the slot [OcptScheduleService.createDay] minted with day [dayId].
    Future<String> firstSlotOf(String dayId) async {
      final rows =
          await (database.select(database.ocptShootingSlotsTable)
                ..where((row) => row.shootingDayId.equals(dayId))
                ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
              .get();
      return rows.firstWhere((row) => !row.isDeleted).id;
    }

    /// Pins slot [slotId] to start at [minute] past its day's own midnight.
    Future<void> startAt(String slotId, int minute) => scheduleService.setSlotAnchor(
      database: database,
      slotId: slotId,
      edge: OcptShootingSlotAnchorEdge.start,
      minute: minute,
    );

    /// Convokes [positionIds] and [roleNames] on slot [slotId].
    Future<void> convoke(
      String slotId, {
      required List<String> positionIds,
      required List<String> roleNames,
    }) async {
      for (final positionId in positionIds) {
        await scheduleService.addSlotCrewMember(
          database: database,
          slotId: slotId,
          personId: crewIds[positionId]!,
        );
      }
      for (final roleName in roleNames) {
        await scheduleService.addSlotCastRole(
          database: database,
          slotId: slotId,
          roleId: roleIdByName[roleName]!,
        );
      }
    }

    /// Appends a milestone block of [kind] lasting [minutes] to slot [slotId].
    Future<void> milestone(
      String slotId,
      OcptShootingBlockKind kind,
      int minutes, {
      String label = "",
      String crewNote = "",
    }) async {
      final blockId = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: kind,
        label: label,
        durationMinutes: minutes,
      ))!;
      if (crewNote.isNotEmpty) {
        await scheduleService.updateBlock(
          database: database,
          blockId: blockId,
          crewNote: Value(crewNote),
        );
      }
    }

    /// Places shot [shotId] on slot [slotId] for [minutes] of shooting time.
    Future<void> place(String slotId, String shotId, int minutes) async {
      final blockId = (await scheduleService.placeShot(
        database: database,
        slotId: slotId,
        shotId: shotId,
      ))!;
      await scheduleService.updateBlock(
        database: database,
        blockId: blockId,
        durationMinutes: Value(minutes),
      );
    }

    // Day 1 — the cafe in the morning, the pier in the afternoon.
    final day1 = (await scheduleService.createDay(database: database, date: DateTime(2026, 9, 15)))!;
    await scheduleService.updateDay(
      database: database,
      dayId: day1,
      crewNote: const Value(
        "Unit base behind the fish market. The cafe opens to the public at 12:00 — everything "
        "inside is shot before that.",
      ),
      weatherNote: const Value("Rain until 09:00, clearing westerly 4."),
    );
    final day1Cafe = await firstSlotOf(day1);
    await scheduleService.updateSlot(
      database: database,
      slotId: day1Cafe,
      label: const Value("Unit 1 — cafe"),
      locationId: Value(harbourId),
      setId: Value(cafeSetId),
      notes: const Value("Key holder: Mme Quéré, 06:30 on the terrace."),
    );
    await startAt(day1Cafe, 7 * 60);
    await convoke(
      day1Cafe,
      positionIds: const [
        "director",
        "firstAssistantDirector",
        "directorOfPhotography",
        "scriptSupervisor",
        "soundEngineer",
        "gaffer",
        "makeupArtist",
        "productionManager",
      ],
      roleNames: const ["NORA", "OWNER"],
    );
    await scheduleService.addSlotGuest(
      database: database,
      slotId: day1Cafe,
      freeName: "Harbour master",
      reason: "Lends the quay, 08:00",
    );
    await milestone(day1Cafe, OcptShootingBlockKind.preparation, 45, label: "Set up");
    await milestone(
      day1Cafe,
      OcptShootingBlockKind.hairMakeUp,
      45,
      crewNote: "Nora arrives wet — hair kept damp all morning.",
    );
    await place(day1Cafe, shotsByScene[0]![0], 60);
    await place(day1Cafe, shotsByScene[0]![1], 45);
    await milestone(day1Cafe, OcptShootingBlockKind.meal, 60, label: "Lunch");
    await place(day1Cafe, shotsByScene[0]![2], 40);
    await place(day1Cafe, shotsByScene[0]![3], 40);
    await milestone(day1Cafe, OcptShootingBlockKind.wrap, 30);

    final day1Pier = (await scheduleService.createSlot(
      database: database,
      shootingDayId: day1,
      anchorMinute: 13 * 60 + 30,
      label: "Unit 2 — pier",
      locationId: harbourId,
      setId: pierSetId,
      notes: "Planks are slick — grip lays matting before anybody walks out.",
    ))!;
    await convoke(
      day1Pier,
      positionIds: const [
        "director",
        "firstAssistantDirector",
        "directorOfPhotography",
        "gaffer",
        "productionManager",
      ],
      roleNames: const ["NORA", "MARTIN"],
    );
    await milestone(day1Pier, OcptShootingBlockKind.travel, 20, label: "To the pier");
    await milestone(day1Pier, OcptShootingBlockKind.preparation, 40, label: "Crane set up");
    await place(day1Pier, shotsByScene[2]![0], 75);
    await place(day1Pier, shotsByScene[2]![1], 50);
    await milestone(day1Pier, OcptShootingBlockKind.wrap, 30);

    await scheduleService.createDayEvent(
      database: database,
      dayId: day1,
      minute: 17 * 60,
      label: "Fish auction — the quay fills up",
    );

    // Day 2 — the rest of the cafe, then the end of the pier.
    final day2 = (await scheduleService.createDay(database: database, date: DateTime(2026, 9, 16)))!;
    await scheduleService.updateDay(
      database: database,
      dayId: day2,
      weatherNote: const Value("Overcast, southerly 3, no rain expected."),
    );
    final day2Cafe = await firstSlotOf(day2);
    await scheduleService.updateSlot(
      database: database,
      slotId: day2Cafe,
      label: const Value("Unit 1 — cafe"),
      locationId: Value(harbourId),
      setId: Value(cafeSetId),
    );
    await startAt(day2Cafe, 8 * 60);
    await convoke(
      day2Cafe,
      positionIds: const [
        "director",
        "firstAssistantDirector",
        "directorOfPhotography",
        "scriptSupervisor",
        "soundEngineer",
        "makeupArtist",
      ],
      roleNames: const ["NORA", "OWNER"],
    );
    await milestone(day2Cafe, OcptShootingBlockKind.preparation, 40, label: "Set up");
    await place(day2Cafe, shotsByScene[1]![0], 50);
    await place(day2Cafe, shotsByScene[1]![1], 40);
    await milestone(day2Cafe, OcptShootingBlockKind.meal, 60, label: "Lunch");
    await milestone(day2Cafe, OcptShootingBlockKind.wrap, 30);

    final day2Pier = (await scheduleService.createSlot(
      database: database,
      shootingDayId: day2,
      anchorMinute: 14 * 60,
      label: "Unit 2 — pier",
      locationId: harbourId,
      setId: pierSetId,
    ))!;
    await convoke(
      day2Pier,
      positionIds: const [
        "director",
        "firstAssistantDirector",
        "directorOfPhotography",
        "gaffer",
        "soundEngineer",
      ],
      roleNames: const ["NORA", "MARTIN"],
    );
    await milestone(day2Pier, OcptShootingBlockKind.travel, 20, label: "To the pier");
    await place(day2Pier, shotsByScene[2]![2], 45);
    await place(day2Pier, shotsByScene[2]![3], 60);
    await milestone(day2Pier, OcptShootingBlockKind.wrap, 30);

    // Day 3 — at sea, one unit, an early call and a hold for the sequence not yet shot-listed.
    final day3 = (await scheduleService.createDay(database: database, date: DateTime(2026, 9, 17)))!;
    await scheduleService.updateDay(
      database: database,
      dayId: day3,
      status: const Value(OcptShootingDayStatus.planned),
      crewNote: const Value("Skipper decides at 05:00 whether the bay is workable."),
      weatherNote: const Value("Swell 1.5 m falling, westerly 3."),
    );
    final day3Sea = await firstSlotOf(day3);
    await scheduleService.updateSlot(
      database: database,
      slotId: day3Sea,
      label: const Value("Unit 1 — at sea"),
      locationId: Value(seaId),
      setId: Value(boatSetId),
      notes: const Value("Six on board, no more. Everything else stays on the quay."),
    );
    await startAt(day3Sea, 6 * 60);
    await convoke(
      day3Sea,
      positionIds: const [
        "director",
        "firstAssistantDirector",
        "directorOfPhotography",
        "soundEngineer",
        "productionManager",
      ],
      roleNames: const ["NORA", "MARTIN"],
    );
    await milestone(day3Sea, OcptShootingBlockKind.preparation, 45, label: "Load the boat");
    await milestone(day3Sea, OcptShootingBlockKind.travel, 40, label: "Out to the bay");
    await place(day3Sea, shotsByScene[3]![0], 70);
    await place(day3Sea, shotsByScene[3]![1], 50);
    await milestone(day3Sea, OcptShootingBlockKind.meal, 45, label: "On board");
    final holdId = (await scheduleService.createBlock(
      database: database,
      slotId: day3Sea,
      kind: OcptShootingBlockKind.hold,
      sceneId: sceneIds[3],
      label: "Kept for the end of the sequence",
      durationMinutes: 60,
    ))!;
    expect(holdId, isNotEmpty);
    await milestone(day3Sea, OcptShootingBlockKind.travel, 40, label: "Back in");
    await milestone(day3Sea, OcptShootingBlockKind.wrap, 30);

    // The budget. The ten CNC postes are seeded by the quote service itself, on this very first
    // read of an empty table — the labels are resolved from `Tr` in the app and written out here,
    // this script having no BuildContext to resolve them against.
    const posteLabels = <String, String>{
      "1": "Artistic rights",
      "2": "Personnel",
      "3": "Cast",
      "4": "Social charges",
      "5": "Sets and costumes",
      "6": "Transport, per diems, logistics",
      "7": "Technical equipment",
      "8": "Laboratory and post-production",
      "9": "Insurance and miscellaneous",
      "10": "Overheads",
    };
    final postes = await budgetQuoteService.loadPostes(
      database: database,
      seed: [
        for (final poste in ocptBudgetCncPostes)
          OcptBudgetPosteSeed(
            id: poste.id,
            code: poste.code,
            label: posteLabels[poste.code]!,
            simpleLabel: null,
          ),
      ],
    );
    expect(postes, hasLength(10));

    String posteIdOf(String code) => postes.firstWhere((poste) => poste.code == code).id;

    Future<String> quoteLine(
      String code,
      String label,
      int quantityMilli,
      String unit,
      int unitAmountCents, {
      int? vatRateBasisPoints,
    }) async {
      final lineId = (await budgetQuoteService.createLine(
        database: database,
        posteId: posteIdOf(code),
        label: label,
        unitAmountCents: Value(unitAmountCents),
      ))!;
      await budgetQuoteService.updateLine(
        database: database,
        lineId: lineId,
        quantityMilli: Value(quantityMilli),
        unit: Value(unit),
        vatRateBasisPoints: Value(vatRateBasisPoints),
      );

      return lineId;
    }

    await quoteLine("1", "Screenplay rights", 1000, "package", 120000, vatRateBasisPoints: 0);
    await quoteLine("2", "Director of photography", 12000, "day", 25000, vatRateBasisPoints: 0);
    await quoteLine("2", "Sound engineer", 12000, "day", 22000, vatRateBasisPoints: 0);
    await quoteLine("3", "Nora", 12000, "day", 30000, vatRateBasisPoints: 0);
    await quoteLine("3", "Martin", 8000, "day", 30000, vatRateBasisPoints: 0);
    await quoteLine("4", "Employer contributions", 1000, "package", 240000, vatRateBasisPoints: 0);
    final costumesLineId = await quoteLine(
      "5",
      "Period costumes",
      1000,
      "package",
      180000,
      vatRateBasisPoints: 2000,
    );
    await quoteLine("5", "Set dressing — the lighthouse", 1000, "package", 95000,
        vatRateBasisPoints: 2000);
    await quoteLine("6", "Boat charter", 3000, "day", 48000, vatRateBasisPoints: 2000);
    await quoteLine("7", "Camera package", 12000, "day", 39000, vatRateBasisPoints: 2000);
    await quoteLine("8", "Colour grading", 4000, "day", 55000, vatRateBasisPoints: 2000);
    await quoteLine("8", "Sound mix", 3000, "day", 40000, vatRateBasisPoints: 2000);
    await quoteLine("9", "Production insurance", 1000, "package", 85000, vatRateBasisPoints: 2000);
    await quoteLine("10", "Office and telephone", 1000, "package", 60000, vatRateBasisPoints: 2000);

    // The financing plan. One contribution is reimbursable out of the takings, which is what the
    // sharing view puts before any split at all.
    Future<String> resource(
      OcptBudgetResourceGroupKind groupKind,
      String label,
      int amountCents,
      OcptBudgetResourceStatus status, {
      bool isReimbursable = false,
    }) async {
      final id = (await budgetFinancingService.createResource(database: database, label: label))!;
      await budgetFinancingService.updateResource(
        database: database,
        resourceId: id,
        groupKind: Value(groupKind),
        amountCents: Value(amountCents),
        status: Value(status),
        isReimbursable: Value(isReimbursable),
      );

      return id;
    }

    await resource(
      OcptBudgetResourceGroupKind.subsidy,
      "Regional production fund",
      800000,
      OcptBudgetResourceStatus.confirmed,
    );
    final ownContribution = await resource(
      OcptBudgetResourceGroupKind.cash,
      "The production's own contribution",
      350000,
      OcptBudgetResourceStatus.confirmed,
      isReimbursable: true,
    );
    await resource(
      OcptBudgetResourceGroupKind.inKind,
      "Harbour office lent for the shoot",
      120000,
      OcptBudgetResourceStatus.agreed,
    );

    // What is ordered but not yet paid. One is settled by the entry below it, so the expenses tree
    // reads a whole line → commitment → payment chain; the other two are still owed, which is what
    // the cash-flow page's own upcoming section and its projection read.
    final costumesCommitmentId = (await budgetJournalService.createCommitment(
      database: database,
      posteId: posteIdOf("5"),
      lineId: costumesLineId,
      label: "Maison Couronne — period costumes",
      dueDate: DateTime.utc(2026, 9, 20),
      amountCents: 180000,
      vatRateBasisPoints: 2000,
      status: OcptBudgetCommitmentStatus.invoiceReceived,
    ))!;
    await budgetJournalService.createCommitment(
      database: database,
      posteId: posteIdOf("7"),
      label: "Camera package, second week",
      dueDate: DateTime.utc(2026, 9, 30),
      amountCents: 117000,
      vatRateBasisPoints: 2000,
    );
    await budgetJournalService.createCommitment(
      database: database,
      posteId: posteIdOf("8"),
      label: "Studio Lumière — colour grading",
      dueDate: DateTime.utc(2026, 11, 16),
      amountCents: 220000,
      vatRateBasisPoints: 2000,
      status: OcptBudgetCommitmentStatus.contractSigned,
    );

    // The cash journal, including the credit that makes the reimbursable contribution received.
    await budgetJournalService.createEntry(
      database: database,
      date: DateTime.utc(2026, 8, 14),
      label: "The production's own contribution paid in",
      creditCents: 350000,
      resourceId: ownContribution,
    );
    await budgetJournalService.createEntry(
      database: database,
      date: DateTime.utc(2026, 9, 2),
      label: "Camera package, first week",
      posteId: posteIdOf("7"),
      debitCents: 117000,
      vatRateBasisPoints: 2000,
    );
    await budgetJournalService.createEntry(
      database: database,
      date: DateTime.utc(2026, 9, 8),
      label: "Boat charter",
      posteId: posteIdOf("6"),
      debitCents: 144000,
      vatRateBasisPoints: 2000,
    );
    await budgetJournalService.createEntry(
      database: database,
      date: DateTime.utc(2026, 9, 20),
      label: "Maison Couronne — period costumes",
      posteId: posteIdOf("5"),
      commitmentId: costumesCommitmentId,
      debitCents: 180000,
      vatRateBasisPoints: 2000,
    );

    // The premium came in above the line quoted for it, so poste 9 reads over its own quote — the
    // one standing alert the demonstration project raises, and the reason the dashboard has an
    // alerts card to draw at all.
    await budgetJournalService.createEntry(
      database: database,
      date: DateTime.utc(2026, 8, 28),
      label: "Production insurance — annual premium",
      posteId: posteIdOf("9"),
      debitCents: 102000,
      vatRateBasisPoints: 2000,
    );

    // The takings, and what each of them has actually brought in.
    Future<String> revenue(
      DateTime date,
      String label,
      int amountCents,
      OcptBudgetRevenueStatus status,
    ) async {
      final id = (await budgetSharingService.createRevenue(
        database: database,
        date: date,
        label: label,
      ))!;
      await budgetSharingService.updateRevenue(
        database: database,
        revenueId: id,
        amountCents: Value(amountCents),
        status: Value(status),
      );

      return id;
    }

    final prize = await revenue(
      DateTime.utc(2027, 2, 2),
      "Clermont-Ferrand — audience award",
      300000,
      OcptBudgetRevenueStatus.confirmed,
    );
    final broadcast = await revenue(
      DateTime.utc(2027, 3, 18),
      "Regional distribution grant",
      220000,
      OcptBudgetRevenueStatus.confirmed,
    );
    await revenue(
      DateTime.utc(2027, 5, 30),
      "Television pre-buy — short film slot",
      100000,
      OcptBudgetRevenueStatus.invoiced,
    );

    await budgetJournalService.createEntry(
      database: database,
      date: DateTime.utc(2027, 2, 2),
      label: "Audience award paid in",
      creditCents: 300000,
      revenueId: prize,
    );
    await budgetJournalService.createEntry(
      database: database,
      date: DateTime.utc(2027, 3, 18),
      label: "Distribution grant paid in",
      creditCents: 220000,
      revenueId: broadcast,
    );

    // The split. The shares deliberately add up to exactly 1000 per mille here, so the demonstration
    // project shows a plan that balances; the view states the sum whenever one does not.
    Future<String> share(String label, int sharePermille, int reinvestPermille) async {
      final id = (await budgetSharingService.createShare(database: database, label: label))!;
      await budgetSharingService.updateShare(
        database: database,
        shareId: id,
        sharePermille: Value(sharePermille),
        reinvestPermille: Value(reinvestPermille),
      );

      return id;
    }

    await share("Director", 400, 1000);
    await share("Production", 250, 0);
    await share("Director of photography", 150, 0);
    await share("Nora", 100, 0);
    final editor = await share("Editor", 100, 500);

    await budgetJournalService.createEntry(
      database: database,
      date: DateTime.utc(2027, 6, 12),
      label: "Editor's share, first instalment",
      debitCents: 8000,
      shareId: editor,
    );

    // ignore: avoid_print, this script reports where it wrote to the terminal that ran it
    print("Seeded $path");
  });
}
