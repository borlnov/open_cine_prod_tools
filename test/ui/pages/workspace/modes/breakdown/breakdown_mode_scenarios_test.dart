// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_recap_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_tag_popover.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_target_inspector.dart';

import 'breakdown_mode_scenarios_test_doubles.dart';

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

  /// Finds [target] inside the tag popover.
  Finder inPopover(Finder target) =>
      find.descendant(of: find.byType(OcptBreakdownTagPopover), matching: target);

  /// Whether the tag popover is on screen.
  bool isPopoverShown() => harness.isShown(find.byType(OcptBreakdownTagPopover));

  /// Opens an anchor on the word "teapot" of the first scene: the script then draws it without the
  /// whitespace that follows the word.
  Future<void> anchorTeapotOfKitchen(WidgetTester tester) =>
      harness.tap(tester, inScript(find.text("teapot ")).first);

  /// Closes a range on the word "teapot" of the first scene, which opens the popover: a second
  /// click on the anchor closes the range over that single word.
  Future<void> selectTeapotOfKitchen(WidgetTester tester) async {
    await anchorTeapotOfKitchen(tester);
    await harness.tap(tester, inScript(find.text("teapot")));
  }

  /// Closes a range on "old rake" of the second scene, which opens the popover.
  Future<void> selectOldRakeOfGarden(WidgetTester tester) async {
    await harness.tap(tester, inScript(find.text("old ")));
    await harness.tap(tester, inScript(find.text("rake.")));
  }

  /// Taps the category chip of the open popover labelled [label].
  Future<void> pickCategory(WidgetTester tester, String label) =>
      harness.tapScrolled(tester, inPopover(find.text(label)));

  /// Finds the title of the scene sheet of scene [number].
  Finder sceneSheetTitle(WidgetTester tester, String number) =>
      find.text(harness.trOf(tester).breakdownSceneInspectorTitle(number));

  testWidgets("the mode shows a spinner, then the script with every scene listed, nothing "
      "selected and the right dock shut", (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness.wrap(const OcptBreakdownMode()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    final tr = harness.trOf(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("My Movie"), findsOneWidget);
    expect(inPanel(find.text("INT. KITCHEN - DAY")), findsOneWidget);
    expect(inPanel(find.text("EXT. GARDEN - NIGHT")), findsOneWidget);
    expect(find.text(tr.breakdownScenesDoneCount(0, 2)), findsOneWidget);
    expect(
      find.text("${tr.breakdownStatsTagged(0)} · ${tr.breakdownHeaderScenesProgressLabel(0, 2)}"),
      findsOneWidget,
    );
    expect(
      find.text("${tr.breakdownStatsTagged(0)} · ${tr.breakdownStatsCategories(0)}"),
      findsOneWidget,
    );
    // The script view is the centre, with every word of the screenplay in it.
    expect(find.byType(OcptBreakdownScriptView), findsOneWidget);
    expect(find.byType(OcptBreakdownRecapTable), findsNothing);
    expect(find.text(tr.breakdownHeaderScriptHint), findsOneWidget);
    expect(inScript(find.text("rake.")), findsOneWidget);
    // Neither a scene nor a target is selected, and the right dock is shut.
    expect(find.byTooltip(tr.breakdownRightDockCloseTooltip), findsNothing);
    expect(find.byType(OcptBreakdownSceneInspector), findsNothing);
    expect(await harness.readScenes(), hasLength(2));
    expect(await harness.readTags(), isEmpty);
  });

  testWidgets("a scene picked in the list stays quiet, one picked in the script lands on its sheet "
      "even from the Versions tab", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, inPanel(find.text("EXT. GARDEN - NIGHT")));
    expect(find.byTooltip(tr.breakdownRightDockCloseTooltip), findsNothing);

    await harness.openRightDock(tester);
    expect(sceneSheetTitle(tester, "2"), findsOneWidget);
    expect(find.text("EXT. GARDEN - NIGHT"), findsNWidgets(3));

    // A heading of the script switches the sheet.
    await harness.tap(tester, inScript(find.text("INT. KITCHEN - DAY")));
    expect(sceneSheetTitle(tester, "1"), findsOneWidget);

    // From the Versions tab, the same click goes back to the Inspector tab and remembers it.
    await harness.tap(tester, find.text(tr.breakdownRightDockVersionsTabLabel));
    expect(sceneSheetTitle(tester, "1"), findsNothing);
    expect(
      await harness.propertiesManager.breakdownLastRightDockTab.load(),
      OcptBreakdownRightDockTab.versions,
    );
    await harness.tap(tester, inScript(find.text("EXT. GARDEN - NIGHT")));
    expect(sceneSheetTitle(tester, "2"), findsOneWidget);
    expect(
      await harness.propertiesManager.breakdownLastRightDockTab.load(),
      OcptBreakdownRightDockTab.inspector,
    );

    // With the dock shut, a heading click opens it; the list's click leaves it shut.
    await harness.tap(tester, find.byTooltip(tr.breakdownRightDockCloseTooltip));
    await harness.tap(tester, inPanel(find.text("INT. KITCHEN - DAY")));
    expect(find.byType(OcptBreakdownSceneInspector), findsNothing);
    await harness.tap(tester, inScript(find.text("EXT. GARDEN - NIGHT")));
    expect(sceneSheetTitle(tester, "2"), findsOneWidget);
  });

  testWidgets("a first click opens an anchor, the second one the popover, and the × button, "
      "Escape and a tap outside each drop both without writing", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await anchorTeapotOfKitchen(tester);
    expect(isPopoverShown(), isFalse);
    // The anchor selected its scene and is drawn without the whitespace after it.
    expect(inScript(find.text("teapot ")), findsOneWidget);

    await harness.tap(tester, inScript(find.text("teapot")));
    expect(isPopoverShown(), isTrue);
    expect(inPopover(find.text('"teapot"')), findsOneWidget);
    final field = tester.widget<TextField>(harness.fieldHinted(tr.breakdownPopoverFieldHint));
    expect(field.controller!.text, "teapot");

    await harness.tap(tester, inPopover(find.byIcon(Icons.close)));
    expect(isPopoverShown(), isFalse);
    expect(inScript(find.text("teapot ")), findsNWidgets(2));

    // The script keeps the keyboard focus the anchor gave it, so Escape reaches the popover only
    // once its field has been clicked.
    await selectTeapotOfKitchen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(isPopoverShown(), isTrue);
    await harness.tap(tester, harness.fieldHinted(tr.breakdownPopoverFieldHint));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(isPopoverShown(), isFalse);
    expect(inScript(find.text("teapot ")), findsNWidgets(2));

    // A lone anchor is dropped by Escape, which the script itself catches.
    await anchorTeapotOfKitchen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(inScript(find.text("teapot ")), findsNWidgets(2));

    await selectTeapotOfKitchen(tester);
    await tester.tapAt(const Offset(1500, 1300));
    await tester.pumpAndSettle();
    expect(isPopoverShown(), isFalse);
    expect(inScript(find.text("teapot ")), findsNWidgets(2));

    expect(await harness.readTags(), isEmpty);
    expect(await harness.readElements(), isEmpty);
  });

  testWidgets("an anchor in another scene replaces the first and selects that scene, and a word "
      "that would overlap a tag is no click target", (tester) async {
    final elementId = await harness.seedElement("Teapot");
    await harness.seedTag(
      sceneIndex: 0,
      text: "teapot",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, inScript(find.text("enters ")));
    await harness.tap(tester, inScript(find.text("rests ")));
    // The first anchor is gone, and the click moved the selection to the second scene.
    expect(inScript(find.text("enters ")), findsOneWidget);
    expect(inScript(find.text("rests")), findsOneWidget);
    expect(isPopoverShown(), isFalse);
    await harness.openRightDock(tester);
    expect(sceneSheetTitle(tester, "2"), findsOneWidget);
    await harness.tap(tester, inScript(find.text("rests")));
    expect(isPopoverShown(), isTrue);
    await harness.tap(tester, inPopover(find.byIcon(Icons.close)));

    // "a" then "on" would span the tagged "teapot": the second word cannot close the range.
    await harness.tap(tester, inScript(find.text("a ")));
    expect(find.byTooltip(tr.breakdownBlockedWordTooltip), findsWidgets);
    // A blocked word takes no click of its own, so the click falls on the sheet behind it and
    // abandons the anchor.
    await harness.tap(tester, inScript(find.text("on ")));
    expect(isPopoverShown(), isFalse);
    expect(find.byTooltip(tr.breakdownBlockedWordTooltip), findsNothing);
    expect(inScript(find.text("a ")), findsOneWidget);
    expect(await harness.readTags(), hasLength(1));
  });

  testWidgets("a word clicked while a note is still being typed writes the note first", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, inScript(find.text("INT. KITCHEN - DAY")));

    await harness.type(tester, harness.fieldLabelled(tr.breakdownSceneNotesLabel), "Ladder");
    expect(await harness.readSceneNotes(0), "");
    await harness.tapQuickly(tester, inScript(find.text("enters ")));
    await harness.eventually(tester, () async => await harness.readSceneNotes(0) == "Ladder");
    // The click went on to open an anchor all the same.
    expect(inScript(find.text("enters")), findsOneWidget);
    await harness.letDebounceRun(tester);
  });

  testWidgets("a popover match links the passage to the existing element, ensures its scene link "
      "and lands on the element's sheet", (tester) async {
    final elementId = await harness.seedElement("Teapot");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await selectTeapotOfKitchen(tester);
    expect(inPopover(find.text("Teapot")), findsOneWidget);
    await harness.type(tester, harness.fieldHinted(tr.breakdownPopoverFieldHint), "zzz");
    expect(inPopover(find.text("Teapot")), findsNothing);
    await harness.type(tester, harness.fieldHinted(tr.breakdownPopoverFieldHint), "tea");
    await harness.tap(tester, inPopover(find.text("Teapot")));

    expect(isPopoverShown(), isFalse);
    final tag = (await harness.readTags()).single;
    expect(tag.targetKind, OcptBreakdownTargetKind.element);
    expect(tag.targetId, elementId);
    expect(tag.taggedText, "teapot");
    final scenes = await harness.readScenes();
    expect(tag.sceneId, scenes.first.id);
    final element = (await harness.readElements()).single;
    expect(element.sceneLinks.map((link) => link.sceneId), [scenes.first.id]);

    // The element's sheet is on screen, on a freshly opened Inspector tab.
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);
    expect(
      find.text("${tr.breakdownStatsTagged(1)} · ${tr.breakdownStatsCategories(1)}"),
      findsOneWidget,
    );
    expect(find.text(tr.breakdownScenesDoneCount(0, 2)), findsOneWidget);
    expect(
      await harness.propertiesManager.breakdownLastRightDockTab.load(),
      OcptBreakdownRightDockTab.inspector,
    );
  });

  testWidgets("a category chip creates the element named from the field and tags the passage in "
      "one write, falling back on the passage when the field is cleared", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await selectTeapotOfKitchen(tester);
    await harness.type(tester, harness.fieldHinted(tr.breakdownPopoverFieldHint), "  Blue teapot ");
    await pickCategory(tester, tr.resourcesElementCategoryProp);

    expect(isPopoverShown(), isFalse);
    var element = (await harness.readElements()).single;
    expect(element.name, "Blue teapot");
    expect(element.category, OcptElementCategory.prop);
    expect(element.sourceKind, OcptElementSourceKind.owned);
    var tag = (await harness.readTags()).single;
    expect(tag.targetId, element.id);
    expect(tag.taggedText, "teapot");
    expect(element.sceneLinks, hasLength(1));
    // The sheet that opened has the new element's name as its title field.
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OcptBreakdownTargetInspector),
        matching: find.text("Blue teapot"),
      ),
      findsOneWidget,
    );

    await selectOldRakeOfGarden(tester);
    await harness.type(tester, harness.fieldHinted(tr.breakdownPopoverFieldHint), "");
    await pickCategory(tester, tr.resourcesElementCategoryCostume);
    final elements = await harness.readElements();
    expect(elements, hasLength(2));
    element = elements.firstWhere((candidate) => candidate.id != element.id);
    expect(element.name, "old rake");
    expect(element.category, OcptElementCategory.costume);
    tag = (await harness.readTags()).firstWhere((candidate) => candidate.targetId == element.id);
    expect(tag.taggedText, "old rake");
  });

  testWidgets("create a set mints the set in the picked location, or a location of its own, and "
      "tags the passage", (tester) async {
    final locationId = await harness.seedLocation("Farm");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await selectTeapotOfKitchen(tester);
    await harness.type(tester, harness.fieldHinted(tr.breakdownPopoverFieldHint), "Kitchen");
    await harness.tapScrolled(tester, inPopover(find.text(tr.breakdownPopoverCreateSetAction)));
    await harness.tap(tester, find.text(tr.breakdownPopoverCreateSetInOption("Farm")).last);

    var locations = await harness.readLocations();
    expect(locations, hasLength(1));
    final farmSet = locations.single.sets.single;
    expect(farmSet.name, "Kitchen");
    expect(farmSet.locationId, locationId);
    final kitchenScene = (await harness.readScenes()).first;
    expect(farmSet.sceneIds, [kitchenScene.id]);
    var tag = (await harness.readTags()).single;
    expect(tag.targetKind, OcptBreakdownTargetKind.set);
    expect(tag.targetId, farmSet.id);
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);

    await selectOldRakeOfGarden(tester);
    await harness.tapScrolled(tester, inPopover(find.text(tr.breakdownPopoverCreateSetAction)));
    await harness.tap(tester, find.text(tr.breakdownPopoverCreateSetInNewLocationOption).last);

    locations = await harness.readLocations();
    expect(locations, hasLength(2));
    final minted = locations.firstWhere((location) => location.id != locationId);
    expect(minted.name, "old rake");
    expect(minted.sets.single.name, "old rake");
    tag = (await harness.readTags()).firstWhere(
      (candidate) => candidate.targetId == minted.sets.single.id,
    );
    expect(tag.taggedText, "old rake");
  });

  testWidgets("a tag refused behind the popover's back writes nothing at all: no element, no set, "
      "no location, and the popover stays open", (tester) async {
    final elementId = await harness.seedElement("Teapot");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await selectTeapotOfKitchen(tester);
    // Another writer tags the same passage while the popover is open.
    await harness.seedTag(
      sceneIndex: 0,
      text: "teapot",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId,
    );

    await pickCategory(tester, tr.resourcesElementCategoryProp);
    expect(find.text(tr.breakdownTagWriteError), findsOneWidget);
    expect(isPopoverShown(), isTrue);
    expect((await harness.readElements()).map((element) => element.name), ["Teapot"]);
    expect(await harness.readTags(), hasLength(1));

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text(tr.breakdownTagWriteError), findsNothing);

    await harness.tapScrolled(tester, inPopover(find.text(tr.breakdownPopoverCreateSetAction)));
    await harness.tap(tester, find.text(tr.breakdownPopoverCreateSetInNewLocationOption).last);
    expect(find.text(tr.breakdownTagWriteError), findsOneWidget);
    expect(isPopoverShown(), isTrue);
    expect(await harness.readLocations(), isEmpty);
    expect(await harness.readTags(), hasLength(1));

    // Linking the same passage to a match is refused the same way.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await harness.tapScrolled(tester, inPopover(find.text("Teapot")));
    expect(find.text(tr.breakdownTagWriteError), findsOneWidget);
    expect(isPopoverShown(), isTrue);
    expect(await harness.readTags(), hasLength(1));
  });

  testWidgets("a tagged word selects its target instead of anchoring, and a suggested occurrence "
      "is tagged without leaving the sheet, a refused one raising the notice", (tester) async {
    final elementId = await harness.seedElement("Teapot");
    await harness.seedTag(
      sceneIndex: 0,
      text: "teapot",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, inScript(find.text("teapot")));
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);
    expect(isPopoverShown(), isFalse);
    await harness.scrollRightDockTo(
      tester,
      find.text(tr.breakdownSuggestedOccurrencesSectionTitle(1)),
    );
    expect(find.text(tr.breakdownSuggestedOccurrencesSectionTitle(1)), findsOneWidget);

    // Another writer takes the suggested passage first: accepting it is refused.
    await harness.seedTag(
      sceneIndex: 1,
      text: "teapot",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId,
    );
    await harness.tap(tester, find.byTooltip(tr.breakdownSuggestionAcceptAction));
    expect(find.text(tr.breakdownTagWriteError), findsOneWidget);
    expect(await harness.readTags(), hasLength(2));
  });

  testWidgets("accepting a suggested occurrence tags it and keeps the sheet on its target", (
    tester,
  ) async {
    final elementId = await harness.seedElement("Teapot");
    await harness.seedTag(
      sceneIndex: 0,
      text: "teapot",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, inScript(find.text("teapot")));
    await harness.scrollRightDockTo(tester, find.byTooltip(tr.breakdownSuggestionAcceptAction));
    await harness.tap(tester, find.byTooltip(tr.breakdownSuggestionAcceptAction));

    final tags = await harness.readTags();
    expect(tags, hasLength(2));
    final scenes = await harness.readScenes();
    expect(tags.map((tag) => tag.sceneId).toSet(), {scenes[0].id, scenes[1].id});
    expect(tags.every((tag) => tag.targetId == elementId && tag.taggedText == "teapot"), isTrue);
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);
    expect(find.text(tr.breakdownSuggestedOccurrencesSectionTitle(1)), findsNothing);
    final secondOccurrence = find.text(
      tr.breakdownOccurrenceSceneLabel("2", "EXT. GARDEN - NIGHT"),
    );
    await harness.scrollRightDockTo(tester, secondOccurrence);
    expect(secondOccurrence, findsOneWidget);
    expect(find.text(tr.breakdownTagWriteError), findsNothing);
  });
}
