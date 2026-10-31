// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';

import 'resources_mode_scenarios_test_doubles.dart';

void main() {
  final harness = ResourcesScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds the cast member picker of the role sheet, whose badge reads [label].
  Finder castPicker(String label) =>
      find.descendant(of: find.byType(OcptRoleSheet), matching: find.text(label));

  /// Hands the workspace bloc a request to open the resources mode on, then mounts the mode with
  /// what the workspace now holds, the way the workspace page builds it.
  Future<void> mountRevealed(WidgetTester tester, OcptResourcesRevealRequest request) async {
    await harness.mount(tester, mode: const SizedBox.shrink());
    final bloc = harness.workspaceBlocOf(tester);
    await harness.pumpUntil(tester, () => !bloc.state.isLoading);
    bloc.add(
      OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        episodeId: harness.screenplayId,
        revealRequest: request,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      harness.wrap(
        OcptResourcesMode(revealRequest: bloc.state.revealRequest as OcptResourcesRevealRequest?),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the mode shows a spinner, then the people tab with the whole catalogue counted "
      "and nothing selected", (tester) async {
    await harness.seedPerson("Alice", lastName: "Smith");
    final locationId = await harness.seedLocation("Cave");
    await harness.seedSet(locationId, "Back room");
    await harness.seedElement("Lamp");

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness.wrap(const OcptResourcesMode()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    final tr = harness.trOf(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("My Movie"), findsOneWidget);
    expect(find.text("Alice Smith"), findsOneWidget);
    expect(find.text(tr.resourcesNoPersonSelectedHint), findsOneWidget);
    expect(
      find.text(
        "${tr.resourcesStatsPeople(1)} · ${tr.resourcesStatsRoles(1)} · "
        "${tr.resourcesStatsPositions(0)} · ${tr.resourcesStatsLocations(1)}",
      ),
      findsOneWidget,
    );
    expect(find.text(tr.resourcesStatsElements(1)), findsWidgets);
    expect(find.byTooltip(tr.resourcesRightDockCloseTooltip), findsNothing);
  });

  testWidgets("a request to open on a record lands on its tab with its sheet, once, and a stale "
      "id only picks the tab", (tester) async {
    final locationId = await harness.seedLocation("Cave");
    await mountRevealed(
      tester,
      OcptResourcesRevealRequest(tab: OcptResourcesTab.locations, recordId: locationId),
    );
    final tr = harness.trOf(tester);

    expect(harness.fieldHinted(tr.resourcesLocationNameHint), findsOneWidget);
    expect(
      tester.widget<TextField>(harness.fieldHinted(tr.resourcesLocationNameHint)).controller!.text,
      "Cave",
    );
    // The workspace was told the request was taken into account.
    expect(harness.workspaceBlocOf(tester).state.revealRequest, isNull);

    await harness.unmount(tester);
    await mountRevealed(
      tester,
      const OcptResourcesRevealRequest(tab: OcptResourcesTab.elements, recordId: "gone"),
    );
    final elementsTr = harness.trOf(tester);
    expect(find.text(elementsTr.resourcesElementsEmptyHint), findsWidgets);
    expect(harness.workspaceBlocOf(tester).state.revealRequest, isNull);
  });

  testWidgets("switching tabs drops the selection and the search text but keeps the search "
      "open, while picking the same tab again changes nothing", (tester) async {
    await harness.seedPerson("Alice", lastName: "Smith");
    await harness.seedPerson("Bob", lastName: "Jones");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.byTooltip(tr.resourcesToggleSearchTooltip));
    await harness.type(tester, find.widgetWithText(TextField, "").first, "Ali");
    await tester.pumpAndSettle();
    expect(find.text("Alice Smith"), findsOneWidget);
    expect(find.text("Bob Jones"), findsNothing);

    await harness.tap(tester, find.text("Alice Smith"));
    expect(harness.fieldHinted(tr.resourcesFirstNameHint), findsOneWidget);
    await harness.openTab(tester, tr.resourcesTabPeople);
    expect(harness.fieldHinted(tr.resourcesFirstNameHint), findsOneWidget);

    await harness.openTab(tester, tr.resourcesTabRoles);
    expect(find.text(tr.resourcesNoRoleSelectedHint), findsOneWidget);
    expect(find.text(tr.resourcesSearchHint), findsOneWidget);
    expect(find.text("SAM"), findsOneWidget);

    await harness.openTab(tester, tr.resourcesTabPeople);
    expect(find.text(tr.resourcesNoPersonSelectedHint), findsOneWidget);
    expect(find.text("Alice Smith"), findsOneWidget);
    expect(find.text("Bob Jones"), findsOneWidget);

    // Closing the search shuts the field.
    await harness.tap(tester, find.byTooltip(tr.resourcesToggleSearchTooltip));
    expect(find.text(tr.resourcesSearchHint), findsNothing);
  });

  testWidgets("resetting the panel layout writes the default fractions back", (tester) async {
    await harness.propertiesManager.resourcesLeftDockFraction.store(0.3);
    await harness.propertiesManager.resourcesRightDockFraction.store(0.25);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.byIcon(Icons.more_vert));
    await harness.tap(tester, find.text(tr.resourcesResetPanelLayoutAction));

    expect(
      await harness.propertiesManager.resourcesLeftDockFraction.load(),
      OcptWorkspaceDock.leftDefaultFraction,
    );
    expect(
      await harness.propertiesManager.resourcesRightDockFraction.load(),
      OcptWorkspaceDock.rightDefaultFraction,
    );
  });

  testWidgets("casting a person on a role is seen on the roles tab, the person's sheet opens "
      "from the role, and erasing the person uncasts the role", (tester) async {
    final aliceId = await harness.seedPerson("Alice", lastName: "Smith");
    final roleId = await harness.roleIdNamed("SAM");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.openTab(tester, tr.resourcesTabRoles);
    expect(find.text(tr.resourcesStatsRolesCast(0)), findsNothing);
    expect(
      find.textContaining("${tr.resourcesStatsRoles(1)} · ${tr.resourcesStatsRolesCast(0)}"),
      findsOneWidget,
    );
    await harness.tap(tester, find.text("SAM"));
    await harness.tap(tester, castPicker(tr.resourcesRoleNotCast).last);
    await harness.tap(tester, find.text("Alice Smith").last);

    expect((await harness.readRoles()).single.personId, aliceId);
    expect(
      find.textContaining("${tr.resourcesStatsRoles(1)} · ${tr.resourcesStatsRolesCast(1)}"),
      findsOneWidget,
    );
    expect(find.text(tr.resourcesRolesListCastPill), findsOneWidget);

    // The cast member's sheet opens on the people tab; the roles tab finds none selected on return.
    await harness.tap(tester, find.byTooltip(tr.resourcesOpenPersonSheetTooltip));
    expect(harness.fieldHinted(tr.resourcesFirstNameHint), findsOneWidget);
    expect(
      tester.widget<TextField>(harness.fieldHinted(tr.resourcesFirstNameHint)).controller!.text,
      "Alice",
    );
    await harness.openTab(tester, tr.resourcesTabRoles);
    expect(find.text(tr.resourcesNoRoleSelectedHint), findsOneWidget);

    // Erasing the person, confirmed, empties the address book but leaves the role pointing at the
    // erased row, which is how the data model keeps a part from being uncast by a name going.
    await harness.openTab(tester, tr.resourcesTabPeople);
    await harness.tap(tester, find.text("Alice Smith"));
    await harness.tapScrolled(tester, find.text(tr.resourcesDeletePersonAction));
    await harness.confirmDialog(tester, tr.resourcesDeleteConfirmDeleteAction);

    expect(await harness.readPeople(), isEmpty);
    expect((await harness.readRoles()).singleWhere((role) => role.id == roleId).personId, aliceId);
    expect(find.text(tr.resourcesNoPersonSelectedHint), findsOneWidget);
    expect(find.text("Alice Smith"), findsNothing);
    await harness.openTab(tester, tr.resourcesTabRoles);
    expect(find.text(tr.resourcesRolesListCastPill), findsOneWidget);
    expect(
      find.textContaining("${tr.resourcesStatsRoles(1)} · ${tr.resourcesStatsRolesCast(1)}"),
      findsOneWidget,
    );
    await harness.tap(tester, find.text("SAM"));
    expect(castPicker(tr.resourcesRoleNotCast), findsWidgets);
  });

  testWidgets("an element linked to a role from the role sheet is read back on the element's "
      "sheet, whose role chip opens that role", (tester) async {
    final roleId = await harness.seedRole("Ghost");
    final elementId = await harness.seedElement("Lamp");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.openTab(tester, tr.resourcesTabRoles);
    await harness.tap(tester, find.text("Ghost"));
    await harness.tap(tester, find.text(tr.resourcesAddElementToRoleAction));
    await harness.tap(tester, find.textContaining("Lamp").last);

    final element = (await harness.readElements()).single;
    expect(element.roleLinks.map((link) => link.roleId), [roleId]);
    expect(find.byTooltip(tr.resourcesRemoveElementFromRoleTooltip), findsOneWidget);

    await harness.openTab(tester, tr.resourcesTabElements);
    await harness.tap(tester, find.text("Lamp"));
    expect(find.text(tr.resourcesElementRolesCardTitle), findsOneWidget);
    await harness.tap(tester, find.text("Ghost"));

    // The chip lands on the role's sheet, on the roles tab, without going through a tab change.
    expect(harness.fieldHinted(tr.resourcesRoleNameHint), findsOneWidget);
    expect(
      tester.widget<TextField>(harness.fieldHinted(tr.resourcesRoleNameHint)).controller!.text,
      "Ghost",
    );

    // Dropping the link from the role sheet empties the element's read-out.
    await harness.tap(tester, find.byTooltip(tr.resourcesRemoveElementFromRoleTooltip));
    expect((await harness.readElements()).single.roleLinks, isEmpty);
    expect((await harness.readElements()).single.id, elementId);
  });

  testWidgets("a scene placed in a set shows on the sheet, and opening the set in the shot list "
      "hands the workspace the scene and the set, once per request", (tester) async {
    final locationId = await harness.seedLocation("Cave");
    final setId = await harness.seedSet(locationId, "Back room");
    final sceneId = (await harness.readScenes()).first.id;
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.openTab(tester, tr.resourcesTabLocations);
    await harness.tap(tester, find.text("Cave"));
    expect(find.text(tr.resourcesOpenSetInShotListAction), findsNothing);

    await harness.tap(tester, find.text(tr.resourcesAddSceneToSetAction));
    await harness.tap(tester, find.textContaining("KITCHEN").last);

    expect((await harness.readLocations()).single.sets.single.sceneIds, [sceneId]);
    expect(find.text(tr.resourcesSetNoFloorPlanLabel), findsOneWidget);

    final workspace = harness.workspaceBlocOf(tester);
    await harness.tap(tester, find.text(tr.resourcesOpenSetInShotListAction));
    expect(workspace.state.mode, OcptWorkspaceMode.shotList);
    expect(workspace.state.selectedEpisodeId, harness.screenplayId);
    expect(
      workspace.state.revealRequest,
      OcptShotListRevealRequest(sceneId: sceneId, setId: setId),
    );

    // The request is handed over once: the next state change does not send it again.
    workspace.add(const OcptWorkspaceRevealRequestConsumedEvent());
    await tester.pumpAndSettle();
    expect(workspace.state.revealRequest, isNull);
    await harness.tap(tester, find.byTooltip(tr.resourcesToggleSearchTooltip));
    expect(workspace.state.revealRequest, isNull);

    // Taking the scene out of the set writes it at once.
    await harness.tap(tester, find.byIcon(Icons.cancel));
    expect((await harness.readLocations()).single.sets.single.sceneIds, isEmpty);
  });
}
