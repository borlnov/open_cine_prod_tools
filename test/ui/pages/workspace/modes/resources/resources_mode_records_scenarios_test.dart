// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

import 'resources_mode_scenarios_test_doubles.dart';

/// How long a scenario lets the mode's 2 s field-edit debounce run out.
const _debounceElapsed = Duration(milliseconds: 2500);

/// Run the tests of the resources mode records scenarios.
void main() {
  final harness = ResourcesScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  testWidgets("adding a record in each tab selects it, tints it by its rank and counts it", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.text(tr.resourcesAddPersonAction));
    await harness.tap(tester, find.text(tr.resourcesAddPersonAction));
    var people = await harness.readPeople();
    expect(people.map((person) => person.colorIndex), [0, 1]);
    expect(harness.fieldHinted(tr.resourcesFirstNameHint), findsOneWidget);
    expect(find.text(tr.resourcesNoPersonSelectedHint), findsNothing);

    await harness.openTab(tester, tr.resourcesTabRoles);
    await harness.tap(tester, find.text(tr.resourcesAddRoleAction));
    await harness.tap(tester, find.text(tr.resourcesAddRoleExtraOption));
    final roles = await harness.readRoles();
    expect(roles.where((role) => role.kind == OcptRoleKind.extra), hasLength(1));
    expect(harness.fieldHinted(tr.resourcesRoleNameHint), findsOneWidget);

    await harness.openTab(tester, tr.resourcesTabLocations);
    await harness.tap(tester, find.text(tr.resourcesAddLocationAction));
    await harness.tap(tester, find.text(tr.resourcesAddLocationAction));
    expect((await harness.readLocations()).map((location) => location.colorIndex), [0, 1]);
    expect(harness.fieldHinted(tr.resourcesLocationNameHint), findsOneWidget);

    await harness.openTab(tester, tr.resourcesTabElements);
    await harness.tap(tester, find.text(tr.resourcesAddElementAction));
    await harness.tap(tester, find.text(tr.resourcesElementCategoryCostume));
    final elements = await harness.readElements();
    expect(elements.single.category.name, "costume");
    expect(harness.fieldHinted(tr.resourcesElementNameHint), findsOneWidget);

    expect(
      find.text(
        "${tr.resourcesStatsPeople(2)} · ${tr.resourcesStatsRoles(2)} · "
        "${tr.resourcesStatsPositions(0)} · ${tr.resourcesStatsLocations(2)}",
      ),
      findsOneWidget,
    );
    expect(find.text(tr.resourcesStatsElements(1)), findsWidgets);
    people = await harness.readPeople();
    expect(people, hasLength(2));
  });

  testWidgets("deleting a role asks first, then drops its candidacies and its element links "
      "and keeps the people and the elements", (tester) async {
    final roleId = await harness.seedRole("Ghost");
    final aliceId = await harness.seedPerson("Alice", lastName: "Smith");
    final elementId = await harness.seedElement("Lamp");
    await harness.seedCandidate(roleId, aliceId);
    await harness.seedRoleElement(roleId, elementId);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.openTab(tester, tr.resourcesTabRoles);
    await harness.tap(tester, find.text("Ghost"));
    await harness.tapScrolled(tester, find.text(tr.resourcesRoleDeleteAction));
    expect(find.text(tr.resourcesRoleDeleteConfirmTitle), findsOneWidget);
    await harness.tap(tester, find.text(tr.resourcesDeleteConfirmCancelAction));
    expect((await harness.readRoles()).map((role) => role.name), contains("Ghost"));

    await harness.tapScrolled(tester, find.text(tr.resourcesRoleDeleteAction));
    await harness.confirmDialog(tester, tr.resourcesDeleteConfirmDeleteAction);

    expect((await harness.readRoles()).map((role) => role.name), isNot(contains("Ghost")));
    expect(await harness.readCandidates(), isEmpty);
    expect((await harness.readElements()).single.roleLinks, isEmpty);
    expect((await harness.readElements()).single.id, elementId);
    expect(await harness.readPeople(), hasLength(1));
    expect(find.text(tr.resourcesNoRoleSelectedHint), findsOneWidget);
    expect(find.text("Ghost"), findsNothing);
  });

  testWidgets("deleting a location drops its sets and their scene links, and asks first", (
    tester,
  ) async {
    final locationId = await harness.seedLocation("Cave");
    final setId = await harness.seedSet(locationId, "Back room");
    await harness.seedSceneInSet(setId);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.openTab(tester, tr.resourcesTabLocations);
    await harness.tap(tester, find.text("Cave"));
    await harness.tapScrolled(tester, find.text(tr.resourcesLocationDeleteAction));
    await harness.tap(tester, find.text(tr.resourcesDeleteConfirmCancelAction));
    expect(await harness.readLocations(), hasLength(1));

    await harness.tapScrolled(tester, find.text(tr.resourcesLocationDeleteAction));
    await harness.confirmDialog(tester, tr.resourcesDeleteConfirmDeleteAction);

    expect(await harness.readLocations(), isEmpty);
    expect(
      await harness.projectsManager.locationsService.firstLinkedSceneOf(
        database: harness.database,
        setId: setId,
      ),
      isNull,
    );
    expect(await harness.readScenes(), hasLength(2));
    expect(find.text(tr.resourcesLocationsEmptyHint), findsWidgets);
    expect(find.text("Cave"), findsNothing);
  });

  testWidgets("deleting an element drops its scene and role links and leaves the role", (
    tester,
  ) async {
    final roleId = await harness.seedRole("Ghost");
    final elementId = await harness.seedElement("Lamp");
    await harness.seedRoleElement(roleId, elementId);
    await harness.seedSceneElement(elementId);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.openTab(tester, tr.resourcesTabElements);
    await harness.tap(tester, find.textContaining("Lamp"));
    await harness.tapScrolled(tester, find.text(tr.resourcesDeleteElementAction));
    await harness.tap(tester, find.text(tr.resourcesDeleteConfirmCancelAction));
    expect(await harness.readElements(), hasLength(1));

    await harness.tapScrolled(tester, find.text(tr.resourcesDeleteElementAction));
    await harness.confirmDialog(tester, tr.resourcesDeleteConfirmDeleteAction);

    expect(await harness.readElements(), isEmpty);
    expect((await harness.readRoles()).map((role) => role.name), contains("Ghost"));
    expect(find.text(tr.resourcesElementsEmptyHint), findsWidgets);

    // The role's own card has nothing left to list.
    await harness.openTab(tester, tr.resourcesTabRoles);
    await harness.tap(tester, find.text("Ghost"));
    expect(find.text(tr.resourcesRoleNoElementHint), findsOneWidget);
  });

  testWidgets("a candidate added, retained and removed on the role sheet casts and uncasts the "
      "role on the roles tab", (tester) async {
    final roleId = await harness.seedRole("Ghost");
    final aliceId = await harness.seedPerson("Alice", lastName: "Smith");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.openTab(tester, tr.resourcesTabRoles);
    expect(find.text(tr.resourcesRolesListNoLeadPill), findsNothing);
    await harness.tap(tester, find.text("Ghost"));
    await harness.tap(tester, find.text(tr.resourcesAddCandidateToRoleAction));
    await harness.tap(tester, find.text("Alice Smith").last);

    var candidates = (await harness.readCandidates())[roleId]!;
    expect(candidates.single.person.id, aliceId);
    expect(candidates.single.status, OcptRoleCandidateStatus.spotted);
    expect(find.text(tr.resourcesRolesListCandidatesPill(1)), findsOneWidget);

    await harness.tap(tester, find.byTooltip(tr.resourcesRoleCandidateActionsTooltip));
    await harness.tap(tester, find.text(tr.resourcesRoleCandidateStatusRetained));

    candidates = (await harness.readCandidates())[roleId]!;
    expect(candidates.single.status, OcptRoleCandidateStatus.retained);
    expect((await harness.readRoles()).singleWhere((role) => role.id == roleId).personId, aliceId);
    expect(find.text(tr.resourcesRolesListCastPill), findsOneWidget);
    expect(
      find.textContaining("${tr.resourcesStatsRoles(2)} · ${tr.resourcesStatsRolesCast(1)}"),
      findsOneWidget,
    );

    // Removing the retained candidate asks first, then clears the cast it had written.
    await harness.tap(tester, find.byTooltip(tr.resourcesRoleCandidateActionsTooltip));
    await harness.tap(tester, find.text(tr.resourcesRemoveCandidateAction));
    expect(find.text(tr.resourcesRemoveCandidateConfirmTitle), findsOneWidget);
    await harness.tap(tester, find.text(tr.resourcesDeleteConfirmCancelAction));
    expect(await harness.readCandidates(), isNotEmpty);

    await harness.tap(tester, find.byTooltip(tr.resourcesRoleCandidateActionsTooltip));
    await harness.tap(tester, find.text(tr.resourcesRemoveCandidateAction));
    await harness.confirmDialog(tester, tr.resourcesDeleteConfirmDeleteAction);

    expect(await harness.readCandidates(), isEmpty);
    expect((await harness.readRoles()).singleWhere((role) => role.id == roleId).personId, isNull);
    expect(find.text(tr.resourcesRolesListCastPill), findsNothing);
    expect(await harness.readPeople(), hasLength(1));
  });

  testWidgets("a character removed from the screenplay raises a banner that follows the keep "
      "action of its role", (tester) async {
    await harness.projectsManager.screenplayService.saveScreenplayText(
      database: harness.database,
      screenplayId: harness.screenplayId,
      fountainText: "INT. KITCHEN - DAY\n\nNobody here.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    final line = tr.roleAlertCompactOrphanedLine("SAM");
    expect(find.text(line), findsWidgets);

    // The banner line opens the role on the roles tab from any tab.
    await harness.tap(tester, find.text(line).first);
    expect(find.text(tr.roleAlertOrphanedMessage("SAM")), findsOneWidget);

    await harness.tapScrolled(tester, find.text(tr.roleAlertOrphanedKeepAction));

    expect(find.text(line), findsNothing);
    expect(find.text(tr.roleAlertOrphanedMessage("SAM")), findsNothing);
    final role = (await harness.readRoles()).single;
    expect(role.kind, OcptRoleKind.silent);
    expect(role.orphanedName, isNull);
  });

  testWidgets("a hand-added role sharing a screenplay character's name raises a banner that "
      "typing another name, or merging the roles, takes away", (tester) async {
    await harness.seedRole("Sam");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final line = tr.roleAlertCompactCollisionLine("SAM");

    expect(find.text(line), findsWidgets);

    // Renaming the hand-added role, once the debounce wrote it, ends the collision.
    await harness.openTab(tester, tr.resourcesTabRoles);
    await harness.tap(tester, find.text("Sam"));
    await harness.type(tester, harness.fieldHinted(tr.resourcesRoleNameHint), "Samuel");
    expect(find.text(line), findsWidgets);
    await tester.pump(_debounceElapsed);
    await tester.pumpAndSettle();
    expect(find.text(line), findsNothing);
    expect((await harness.readRoles()).map((role) => role.name), containsAll(["SAM", "Samuel"]));

    // Back to a collision, then merged away.
    await harness.type(tester, harness.fieldHinted(tr.resourcesRoleNameHint), "Sam");
    await tester.pump(_debounceElapsed);
    await tester.pumpAndSettle();
    expect(find.text(line), findsWidgets);

    await harness.tap(tester, find.text(line).first);
    await harness.tapScrolled(tester, find.text(tr.roleAlertMergeAction));
    await harness.confirmDialog(tester, tr.roleAlertMergeConfirmAction);

    expect(find.text(line), findsNothing);
    expect(await harness.readRoles(), hasLength(1));
  });
}
