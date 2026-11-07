// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_set_picker_popover.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_target_inspector.dart';

import '../../../../../ocpt_result_expectations.dart';
import 'breakdown_mode_scenarios_test_doubles.dart';

/// Run the tests of the breakdown mode inspector scenarios.
void main() {
  final harness = BreakdownScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds [target] inside the scene list on the left.
  Finder inPanel(Finder target) =>
      find.descendant(of: find.byType(OcptBreakdownScenePanel), matching: target);

  /// Finds [target] inside the script view in the centre.
  Finder inScript(Finder target) =>
      find.descendant(of: find.byType(OcptBreakdownScriptView), matching: target);

  /// Finds [target] inside the scene sheet.
  Finder inSceneSheet(Finder target) =>
      find.descendant(of: find.byType(OcptBreakdownSceneInspector), matching: target);

  /// Finds [target] inside the sheet of the selected target.
  Finder inTargetSheet(Finder target) =>
      find.descendant(of: find.byType(OcptBreakdownTargetInspector), matching: target);

  /// Opens the sheet of the first scene by clicking its heading in the script.
  Future<void> openFirstSceneSheet(WidgetTester tester) =>
      harness.tap(tester, inScript(find.text("INT. KITCHEN - DAY")));

  /// Reads the first scene's notes back from the database.
  Future<String> firstSceneNotes() => harness.readSceneNotes(0);

  /// Reads the element called [name] back from the database.
  Future<OcptElement> elementNamed(String name) async =>
      (await harness.readElements()).firstWhere((element) => element.name == name);

  /// Finds the title of the scene sheet of scene [number].
  Finder sceneSheetTitle(WidgetTester tester, String number) =>
      find.text(harness.trOf(tester).breakdownSceneInspectorTitle(number));

  /// Seeds element "Teapot" and tags its word in the first scene, returning its id.
  Future<String> seedTaggedTeapot() async {
    final id = await harness.seedElement("Teapot");
    await harness.seedTag(
      sceneIndex: 0,
      text: "teapot",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: id,
    );
    return id;
  }

  testWidgets("the scene sheet writes the status at once, and the header, the list and the status "
      "bar follow it", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openFirstSceneSheet(tester);

    await harness.tap(tester, inSceneSheet(find.text(tr.breakdownSceneStatusInProgress)));
    expect(await harness.readSceneStatus(0), OcptBreakdownSceneStatus.inProgress.name);
    expect(find.text(tr.breakdownScenesDoneCount(0, 2)), findsOneWidget);

    await harness.tap(tester, inSceneSheet(find.text(tr.breakdownSceneStatusDone)));
    expect(await harness.readSceneStatus(0), OcptBreakdownSceneStatus.done.name);
    expect(await harness.readSceneStatus(1), OcptBreakdownSceneStatus.toDo.name);
    expect(find.text(tr.breakdownScenesDoneCount(1, 2)), findsOneWidget);
    expect(inPanel(find.text(tr.breakdownSceneStatusDone)), findsOneWidget);
  });

  testWidgets("the scene sheet's sets row links an existing set, unlinks it and creates a set in "
      "a location or in a new one, tagging nothing", (tester) async {
    final locationId = await harness.seedLocation("Kitchen");
    final setId = await harness.seedSet(locationId, "Main");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openFirstSceneSheet(tester);
    final firstSceneId = (await harness.readScenes()).first.id;
    expect(inSceneSheet(find.text(tr.breakdownSceneInspectorNoSetHint)), findsOneWidget);

    await harness.tap(tester, inSceneSheet(find.text(tr.breakdownSceneInspectorAddSetAction)));
    // The set of the location the heading names comes first, marked as the suggestion.
    await harness.tap(
      tester,
      find.text(tr.breakdownSceneInspectorSetSuggestedOption("Main · Kitchen")),
    );
    var sets = (await harness.readLocations()).single.sets;
    expect(sets.single.id, setId);
    expect(sets.single.sceneIds, [firstSceneId]);
    expect(inSceneSheet(find.text("Main · Kitchen")), findsOneWidget);
    expect(inSceneSheet(find.text(tr.breakdownSceneInspectorNoSetHint)), findsNothing);

    // The chip's delete control unlinks it again.
    await harness.tap(
      tester,
      find.descendant(
        of: find.widgetWithText(Chip, "Main · Kitchen"),
        matching: find.byIcon(Icons.cancel),
      ),
    );
    expect((await harness.readLocations()).single.sets.single.sceneIds, isEmpty);
    expect(inSceneSheet(find.text(tr.breakdownSceneInspectorNoSetHint)), findsOneWidget);

    // Creating: the name field opens on the heading's place, and can be typed over.
    await harness.tap(tester, inSceneSheet(find.text(tr.breakdownSceneInspectorAddSetAction)));
    expect(
      find.descendant(
        of: find.byType(Overlay),
        matching: find.text(tr.breakdownSceneInspectorCreateSetMenuTitle("KITCHEN")),
      ),
      findsWidgets,
    );
    await harness.type(
      tester,
      find.descendant(
        of: find.byType(OcptBreakdownSetPickerPopover),
        matching: find.byType(TextField),
      ),
      "  Pantry ",
    );
    await harness.tap(
      tester,
      find.text(tr.breakdownSceneInspectorCreateSetInOption("Kitchen")).last,
    );
    sets = (await harness.readLocations()).single.sets;
    expect(sets.map((set) => set.name), containsAll(["Main", "Pantry"]));
    expect(sets.firstWhere((set) => set.name == "Pantry").sceneIds, [firstSceneId]);

    await harness.tap(tester, inSceneSheet(find.text(tr.breakdownSceneInspectorAddSetAction)));
    await harness.type(
      tester,
      find.descendant(
        of: find.byType(OcptBreakdownSetPickerPopover),
        matching: find.byType(TextField),
      ),
      "Garden",
    );
    await harness.tap(
      tester,
      find.text(tr.breakdownSceneInspectorCreateSetInNewLocationOption).last,
    );
    final locations = await harness.readLocations();
    expect(locations, hasLength(2));
    final garden = locations.firstWhere((location) => location.name == "Garden");
    expect(garden.sets.single.name, "Garden");
    expect(garden.sets.single.sceneIds, [firstSceneId]);
    expect(await harness.readTags(), isEmpty);
  });

  testWidgets("the scene notes autosave after the debounce, and a scene change, a tab change and "
      "leaving the mode each write them first", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openFirstSceneSheet(tester);
    final notesField = harness.fieldLabelled(tr.breakdownSceneNotesLabel);

    await harness.type(tester, notesField, "Bring a ladder");
    expect(await firstSceneNotes(), "");
    await tester.pump(const Duration(milliseconds: 1500));
    expect(await firstSceneNotes(), "");
    await harness.letDebounceRun(tester);
    expect(await firstSceneNotes(), "Bring a ladder");

    // Another scene picked in the list.
    await harness.type(tester, notesField, "Bring two ladders");
    await harness.tapQuickly(tester, inPanel(find.text("EXT. GARDEN - NIGHT")));
    await harness.eventually(tester, () async => await firstSceneNotes() == "Bring two ladders");
    await harness.letDebounceRun(tester);

    // The Versions tab of the right dock.
    await harness.type(tester, harness.fieldLabelled(tr.breakdownSceneNotesLabel), "Garden note");
    await harness.tapQuickly(tester, find.text(tr.breakdownRightDockVersionsTabLabel));
    await harness.eventually(tester, () async => await harness.readSceneNotes(1) == "Garden note");
    await harness.letDebounceRun(tester);

    // Leaving the mode.
    await harness.tap(tester, find.text(tr.breakdownRightDockInspectorTabLabel));
    await harness.type(tester, harness.fieldLabelled(tr.breakdownSceneNotesLabel), "Last words");
    await harness.unmount(tester);
    await harness.eventually(tester, () async => await harness.readSceneNotes(1) == "Last words");
  });

  testWidgets("switching the centre between script and recap writes nothing: a pending note "
      "still lands once its debounce runs out", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await openFirstSceneSheet(tester);

    await harness.type(tester, harness.fieldLabelled(tr.breakdownSceneNotesLabel), "Kept");
    await harness.tapQuickly(tester, find.text(tr.breakdownHeaderRecapSegmentLabel));
    await tester.pump(const Duration(milliseconds: 100));
    expect(await firstSceneNotes(), "");
    expect(
      tester.widget<TextField>(harness.fieldLabelled(tr.breakdownSceneNotesLabel)).controller!.text,
      "Kept",
    );
    await harness.letDebounceRun(tester);
    expect(await firstSceneNotes(), "Kept");
  });

  testWidgets("the element sheet writes its status, its category and its two people at once, and "
      "the status bar follows", (tester) async {
    await seedTaggedTeapot();
    final ownerId = await harness.seedPerson("Alice");
    final bringerId = await harness.seedPerson("Bob");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(
      find.text("${tr.breakdownStatsTagged(1)} · ${tr.breakdownStatsCategories(1)}"),
      findsOneWidget,
    );
    expect(find.text(tr.breakdownStatsToFind(1)), findsOneWidget);

    await harness.tap(tester, inScript(find.text("teapot")));
    await harness.tap(tester, inTargetSheet(find.text(tr.breakdownElementStatusConfirmed)));
    var element = await elementNamed("Teapot");
    expect(element.status, OcptElementStatus.confirmed);
    expect(find.text(tr.breakdownStatsToFind(0)), findsOneWidget);

    await harness.tap(tester, inTargetSheet(find.text(tr.resourcesElementCategoryCostume)));
    element = await elementNamed("Teapot");
    expect(element.category, OcptElementCategory.costume);

    await harness.tapScrolled(tester, inTargetSheet(find.text(tr.resourcesElementNoOwner)));
    await harness.tap(tester, find.text("Alice").last);
    await harness.tapScrolled(tester, inTargetSheet(find.text(tr.resourcesElementNoBringer)));
    await harness.tap(tester, find.text("Bob").last);
    element = await elementNamed("Teapot");
    expect(element.ownerPersonId, ownerId);
    expect(element.broughtByPersonId, bringerId);
    expect(inTargetSheet(find.text("Alice")), findsOneWidget);

    // Nobody again.
    await harness.tap(tester, inTargetSheet(find.text("Alice")));
    await harness.tap(tester, find.text(tr.resourcesElementNoOwner).last);
    expect((await elementNamed("Teapot")).ownerPersonId, isNull);
  });

  testWidgets("the element sheet's typed fields and name autosave together after the debounce, "
      "and picking another target or going back to the scene writes them first", (tester) async {
    final teapotId = await seedTaggedTeapot();
    final rakeId = await harness.seedElement("Rake");
    await harness.seedTag(
      sceneIndex: 1,
      text: "rests",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: rakeId,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, inScript(find.text("teapot")));

    await harness.type(
      tester,
      harness.fieldLabelled(tr.resourcesElementSubCategoryLabel),
      "Ceramic",
    );
    await harness.type(tester, harness.fieldLabelled(tr.resourcesElementQuantityLabel), "2");
    await harness.type(tester, harness.fieldLabelled(tr.breakdownElementNotesLabel), "Chipped");
    await harness.type(tester, inTargetSheet(find.byType(TextField)).first, "Big teapot");
    var element = await elementNamed("Teapot");
    expect(element.subCategory, "");
    expect(element.quantity, "");
    await harness.letDebounceRun(tester);
    element = await elementNamed("Big teapot");
    expect(element.id, teapotId);
    expect(element.subCategory, "Ceramic");
    expect(element.quantity, "2");
    expect(element.notes, "Chipped");

    // Picking another target through the scene sheet writes a quantity typed a moment ago.
    await harness.type(tester, harness.fieldLabelled(tr.resourcesElementQuantityLabel), "3");
    await harness.tapQuickly(
      tester,
      inTargetSheet(find.text(tr.breakdownInspectorBackToSceneAction)),
    );
    await harness.eventually(
      tester,
      () async => (await elementNamed("Big teapot")).quantity == "3",
    );
    await harness.letDebounceRun(tester);

    // Selecting a tagged word of another scene does the same for the target left behind.
    await harness.tap(tester, inScript(find.text("teapot")));
    await harness.type(tester, harness.fieldLabelled(tr.resourcesElementQuantityLabel), "4");
    await harness.tapQuickly(tester, inScript(find.textContaining("rests")));
    await harness.eventually(
      tester,
      () async => (await elementNamed("Big teapot")).quantity == "4",
    );
    await harness.letDebounceRun(tester);

    // Leaving the mode writes the last of it.
    await harness.type(tester, harness.fieldLabelled(tr.breakdownElementNotesLabel), "Rusty");
    await harness.unmount(tester);
    await harness.eventually(tester, () async => (await elementNamed("Rake")).notes == "Rusty");
  });

  testWidgets("a set's title renames it after the debounce, a role's title is read out, and "
      "Open in Resources lands on the right record of the right tab", (tester) async {
    final locationId = await harness.seedLocation("Kitchen");
    final setId = await harness.seedSet(locationId, "Main");
    await harness.seedTag(
      sceneIndex: 0,
      text: "table",
      targetKind: OcptBreakdownTargetKind.set,
      targetId: setId,
    );
    final roleId = (await harness.readRoles()).firstWhere((role) => role.name == "SAM").id;
    await harness.seedTag(
      sceneIndex: 0,
      text: "SAM",
      targetKind: OcptBreakdownTargetKind.role,
      targetId: roleId,
    );
    final elementId = await seedTaggedTeapot();
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    OcptResourcesRevealRequest revealed() =>
        harness.workspaceBlocOf(tester).state.revealRequest! as OcptResourcesRevealRequest;
    Future<void> openInResources() async {
      await harness.scrollRightDockTo(tester, find.text(tr.breakdownOpenInResourcesAction));
      await harness.tap(tester, find.text(tr.breakdownOpenInResourcesAction));
    }

    // The set: its title is a field, renaming the catalogue row.
    await openFirstSceneSheet(tester);
    await harness.tap(tester, inSceneSheet(find.text("Main")));
    await harness.type(tester, inTargetSheet(find.byType(TextField)).first, "Cooking corner");
    expect((await harness.readLocations()).single.sets.single.name, "Main");
    await harness.letDebounceRun(tester);
    expect((await harness.readLocations()).single.sets.single.name, "Cooking corner");
    await openInResources();
    expect(harness.workspaceBlocOf(tester).state.mode, OcptWorkspaceMode.resources);
    expect(revealed().tab, OcptResourcesTab.locations);
    expect(revealed().recordId, locationId);

    // The role: nothing to type into, and the roles tab is revealed.
    await harness.tap(tester, inTargetSheet(find.text(tr.breakdownInspectorBackToSceneAction)));
    await harness.tap(tester, inSceneSheet(find.text("SAM")));
    expect(inTargetSheet(find.byType(TextField)), findsNothing);
    expect(inTargetSheet(find.text("SAM")), findsOneWidget);
    await openInResources();
    expect(revealed().tab, OcptResourcesTab.roles);
    expect(revealed().recordId, roleId);

    // The element, on the elements tab.
    await harness.tap(tester, inTargetSheet(find.text(tr.breakdownInspectorBackToSceneAction)));
    await harness.tap(tester, inSceneSheet(find.widgetWithText(InkWell, "Teapot")));
    await openInResources();
    expect(revealed().tab, OcptResourcesTab.elements);
    expect(revealed().recordId, elementId);
  });

  testWidgets("removing a target from the breakdown asks first, cancelling keeps every tag, "
      "confirming drops its tags of the selected scene alone and keeps the scene link", (
    tester,
  ) async {
    final teapotId = await seedTaggedTeapot();
    await harness.seedTag(
      sceneIndex: 0,
      text: "table",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: teapotId,
    );
    await harness.seedTag(
      sceneIndex: 1,
      text: "teapot",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: teapotId,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, inScript(find.text("teapot")).first);
    final scenes = await harness.readScenes();

    Future<void> askRemoval() async {
      await harness.scrollRightDockTo(tester, find.text(tr.breakdownRemoveFromBreakdownAction));
      await harness.tap(tester, find.text(tr.breakdownRemoveFromBreakdownAction));
    }

    await askRemoval();
    expect(find.text(tr.breakdownRemoveFromBreakdownConfirmTitle), findsOneWidget);
    await harness.tap(tester, find.text(tr.breakdownRemoveFromBreakdownCancelAction));
    expect(find.text(tr.breakdownRemoveFromBreakdownConfirmTitle), findsNothing);
    expect(await harness.readTags(), hasLength(3));

    await askRemoval();
    await harness.confirmDialog(tester, tr.breakdownRemoveFromBreakdownConfirmAction);
    final remaining = await harness.readTags();
    expect(remaining.map((tag) => tag.sceneId), [scenes[1].id]);
    // The scene links the tags once ensured are the resources mode's too: they stay.
    expect((await elementNamed("Teapot")).sceneLinks, hasLength(2));
    // It is still tagged in the second scene, so its sheet stays; the first scene's words are
    // plain.
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);
    expect(inScript(find.text("teapot ")), findsOneWidget);
    expect(inScript(find.text("teapot")), findsOneWidget);
    expect(
      find.text("${tr.breakdownStatsTagged(1)} · ${tr.breakdownStatsCategories(1)}"),
      findsOneWidget,
    );

    // Asking again from the first scene, which no longer holds any of its tags, drops nothing.
    await askRemoval();
    await harness.confirmDialog(tester, tr.breakdownRemoveFromBreakdownConfirmAction);
    expect(await harness.readTags(), hasLength(1));

    // From the second scene, the last tag goes and the target leaves the breakdown altogether.
    await harness.scrollRightDockTo(
      tester,
      find.text(tr.breakdownOccurrenceSceneLabel("2", "EXT. GARDEN - NIGHT")),
    );
    await harness.tap(
      tester,
      find.text(tr.breakdownOccurrenceSceneLabel("2", "EXT. GARDEN - NIGHT")),
    );
    await askRemoval();
    await harness.confirmDialog(tester, tr.breakdownRemoveFromBreakdownConfirmAction);
    expect(await harness.readTags(), isEmpty);
    expect(find.byType(OcptBreakdownTargetInspector), findsNothing);
    expect(sceneSheetTitle(tester, "2"), findsOneWidget);
    expect(
      find.text("${tr.breakdownStatsTagged(0)} · ${tr.breakdownStatsCategories(0)}"),
      findsOneWidget,
    );
    expect((await elementNamed("Teapot")).sceneLinks, hasLength(2));
  });

  testWidgets("a tag whose passage moved is flagged in the list, the sheet and the status bar, "
      "and can be marked as checked or removed from there", (tester) async {
    final teapotId = await seedTaggedTeapot();
    await harness.seedTag(
      sceneIndex: 0,
      text: "table",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: teapotId,
    );
    final project = harness.projectsManager.currentProject!;
    await harness.projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText:
              "INT. KITCHEN - DAY\n\nSAM enters with a kettle on the chair.\n\nSAM\nHello.\n\n"
              "EXT. GARDEN - NIGHT\n\nA teapot rests by the old rake.\n",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    expect((await harness.readTags()).where((tag) => tag.needsCheck), hasLength(2));
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(find.text(tr.breakdownStatsToCheck(2)), findsOneWidget);
    expect(inPanel(find.byTooltip(tr.breakdownTagNeedsCheckTooltip)), findsOneWidget);

    // The list's warning mark leads to the callout on the scene sheet.
    await harness.tap(tester, inPanel(find.byTooltip(tr.breakdownTagNeedsCheckTooltip)));
    expect(sceneSheetTitle(tester, "1"), findsOneWidget);
    expect(find.text(tr.breakdownSceneInspectorNeedsCheckAlertTitle(2)), findsOneWidget);

    await harness.tap(tester, find.text(tr.breakdownSceneInspectorNeedsCheckClearAction).first);
    expect((await harness.readTags()).where((tag) => tag.needsCheck), hasLength(1));
    expect(await harness.readTags(), hasLength(2));
    expect(find.text(tr.breakdownStatsToCheck(1)), findsOneWidget);
    expect(find.text(tr.breakdownSceneInspectorNeedsCheckAlertTitle(1)), findsOneWidget);

    await harness.tap(tester, find.text(tr.breakdownSceneInspectorNeedsCheckRemoveAction).first);
    expect(await harness.readTags(), hasLength(1));
    expect((await harness.readTags()).single.needsCheck, isFalse);
    expect(find.text(tr.breakdownStatsToCheck(0)), findsOneWidget);
    expect(find.text(tr.breakdownSceneInspectorNeedsCheckAlertTitle(1)), findsNothing);
    expect(inPanel(find.byTooltip(tr.breakdownTagNeedsCheckTooltip)), findsNothing);
  });
}
