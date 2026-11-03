// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';

import 'ocpt_result_expectations.dart';
import 'seed_demo_project_data.dart';

/// Seeds the address book: the crew and the cast members, plus the script supervisor's
/// unavailability.
Future<({Map<String, String> actorIds, Map<String, String> crewIds})> seedAddressBook({
  required OcptProjectDatabase database,
  required OcptPeopleService peopleService,
}) async {
  // ------------------------------------------------------------------------------- the address
  // book

  final crewIds = <String, String>{};
  for (final (index, member) in demoCrew.indexed) {
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
  for (final (index, entry) in demoCast.entries.indexed) {
    final personId = (await peopleService.createPerson(database: database))!;
    await peopleService.updatePerson(
      database: database,
      personId: personId,
      firstName: Value(entry.value.firstName),
      lastName: Value(entry.value.lastName),
      city: const Value("Quimper"),
      country: const Value("France"),
      colorIndex: Value(demoCrew.length + index),
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

  return (actorIds: actorIds, crewIds: crewIds);
}

/// Reconciles the cast from the screenplay's own speaking characters and gives each role its actor.
Future<Map<String, String>> seedCast({
  required Map<String, String> actorIds,
  required OcptProjectDatabase database,
  required OcptRoleIndexService roleIndexService,
}) async {
  // ------------------------------------------------------------------------------------ the
  // cast, reconciled from the screenplay's own speaking characters

  final roles = await roleIndexService.loadRoles(database: database).valueOrFail;
  final roleIdByName = {for (final role in roles) role.name: role.id};
  for (final entry in actorIds.entries) {
    await roleIndexService
        .updateRole(
          database: database,
          roleId: roleIdByName[entry.key]!,
          personId: Value(entry.value),
        )
        .okOrFail;
  }

  return roleIdByName;
}

/// Seeds the locations and their sets, and links the sets to the scenes shot there.
Future<({String boatSetId, String cafeSetId, String harbourId, String pierSetId, String seaId})>
seedLocations({
  required OcptProjectDatabase database,
  required OcptLocationsService locationsService,
  required List<String> sceneIds,
}) async {
  // ------------------------------------------------------------------------- the locations and
  // their sets

  final harbourId = (await locationsService
      .createLocation(database: database, name: "Douarnenez harbour")
      .valueOrFail);
  await locationsService
      .updateLocation(
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
      )
      .okOrFail;
  final cafeSetId = (await locationsService
      .createSet(database: database, locationId: harbourId, name: "Harbour cafe")
      .valueOrFail);
  final pierSetId = (await locationsService
      .createSet(database: database, locationId: harbourId, name: "Pier")
      .valueOrFail);

  final seaId = (await locationsService
      .createLocation(database: database, name: "Bay of Douarnenez")
      .valueOrFail);
  await locationsService
      .updateLocation(
        database: database,
        locationId: seaId,
        colorIndex: const Value(5),
        city: const Value("Douarnenez"),
        country: const Value("France"),
        latitude: const Value(48.1042),
        longitude: const Value(-4.4058),
        permitStatus: const Value(OcptPermitStatus.requested),
        permitLabel: const Value("Maritime authority — filming at sea"),
        constraintsNotes: const Value(
          "Sailing window depends on the swell; skipper decides at 05:00.",
        ),
      )
      .okOrFail;
  final boatSetId = (await locationsService
      .createSet(database: database, locationId: seaId, name: "Fishing boat")
      .valueOrFail);

  for (final (index, setId) in [cafeSetId, cafeSetId, pierSetId, boatSetId].indexed) {
    await locationsService
        .assignSceneToSet(database: database, sceneId: sceneIds[index], setId: setId)
        .maybeValueOrFail;
  }

  return (
    boatSetId: boatSetId,
    cafeSetId: cafeSetId,
    harbourId: harbourId,
    pierSetId: pierSetId,
    seaId: seaId,
  );
}

/// Seeds the elements catalogue, in the order that mints the codes the resources mode shows.
Future<
  ({
    String banknoteId,
    String boatId,
    String chartId,
    String compassId,
    String oilskinId,
    String rainTowerId,
    String satchelId,
    String wetCoatId,
  })
>
seedElements({
  required OcptProjectDatabase database,
  required OcptElementsService elementsService,
}) async {
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
    final elementId = (await elementsService
        .createElement(database: database, name: name, category: category, sourceKind: sourceKind)
        .valueOrFail);
    await elementsService
        .updateElement(
          database: database,
          elementId: elementId,
          status: Value(status),
          notes: Value(notes),
        )
        .okOrFail;
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

  return (
    banknoteId: banknoteId,
    boatId: boatId,
    chartId: chartId,
    compassId: compassId,
    oilskinId: oilskinId,
    rainTowerId: rainTowerId,
    satchelId: satchelId,
    wetCoatId: wetCoatId,
  );
}

/// Seeds the breakdown pass, which links each element to the scenes that need it.
Future<void> seedBreakdown({
  required String banknoteId,
  required String boatId,
  required String boatSetId,
  required OcptBreakdownService breakdownService,
  required String cafeSetId,
  required String chartId,
  required String compassId,
  required OcptProjectDatabase database,
  required String oilskinId,
  required String pierSetId,
  required String rainTowerId,
  required Map<String, String> roleIdByName,
  required String satchelId,
  required List<String> sceneIds,
  required List<OcptSceneRow> sceneRows,
  required String wetCoatId,
}) async {
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
    final sceneText = demoFountainText.substring(row.charStart, row.charEnd);
    final startOffset = sceneText.indexOf(text);
    expect(startOffset, isNonNegative, reason: "'$text' is in scene ${sceneIndex + 1}");

    await breakdownService
        .createTag(
          database: database,
          sceneId: row.id,
          startOffset: startOffset,
          endOffset: startOffset + text.length,
          taggedText: text,
          targetKind: targetKind,
          targetId: targetId,
        )
        .maybeValueOrFail;
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
    await breakdownService
        .updateSceneBreakdown(database: database, sceneId: sceneIds[index], status: Value(status))
        .okOrFail;
  }
}
