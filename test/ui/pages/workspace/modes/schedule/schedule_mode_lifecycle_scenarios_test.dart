// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_alerts_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_working_copy_card.dart';

import 'schedule_mode_scenarios_test_doubles.dart';

/// How long a scenario waits, in real time, for the working copy capture throttle to let go.
const _captureThrottle = Duration(milliseconds: 2100);

/// The dates of the days most scenarios plan, far from any clock a test could run on.
final _first = DateTime(2099, 3);

/// The second of the two days the tests use.
final _second = DateTime(2099, 3, 2);

/// Run the tests of the schedule mode lifecycle scenarios.
void main() {
  final harness = ScheduleScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Opens the right dock on its `Versions` tab.
  Future<void> openVersions(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await harness.openDockTab(tester, tr.scheduleRightDockVersionsTabLabel);
  }

  /// Taps the version card to preview it and waits for the read-only banner to show.
  Future<void> previewFirstVersion(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await tester.tapAt(
      tester.getTopLeft(find.byType(OcptProjectVersionCard)) + const Offset(24, 12),
    );
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
  }

  /// Leaves the preview and waits for the banner to go.
  Future<void> exitPreview(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await tester.tap(find.text(tr.workspaceReadOnlyBannerExitAction));
    await harness.pumpUntil(
      tester,
      () => !harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
  }

  testWidgets("the right dock opens on Versions, fills the working copy card, follows a write, "
      "and reopens on the tab it was closed on, even in the next visit", (tester) async {
    final dayId = await harness.seedDay(_first);
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.byType(OcptProjectVersionsPanel), findsNothing);
    await harness.openRightDock(tester);
    await harness.tap(tester, find.text(tr.scheduleRightDockVersionsTabLabel));
    expect(find.byType(OcptProjectWorkingCopyCard), findsOneWidget);
    expect(find.text(tr.projectWorkingCopyIdenticalHint("v1")), findsOneWidget);

    // A write landing while the tab is open makes the card read the new state.
    // The working copy is captured at most once every two real seconds, whatever the test clock.
    await tester.runAsync(() => Future<void>.delayed(_captureThrottle));
    await harness.tap(tester, find.text(tr.scheduleAddSlotAction));
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(tr.projectWorkingCopyModifiedHint("v1"))),
    );
    expect(find.text(tr.projectWorkingCopyModifiedHint("v1")), findsOneWidget);
    expect((await harness.readSchedule()).slotsByDayId[dayId], hasLength(2));

    // Closed, then reopened from the toolbar: the same tab. A new visit remembers it too.
    await harness.tap(tester, find.byTooltip(tr.scheduleRightDockCloseTooltip));
    expect(find.byType(OcptScheduleRightDock), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    expect(find.byType(OcptProjectVersionsPanel), findsOneWidget);

    await harness.tap(tester, find.text(tr.scheduleRightDockAlertsTabLabel));
    await harness.unmount(tester);
    await harness.mount(tester);
    expect(find.byType(OcptScheduleRightDock), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    expect(find.byType(OcptProjectVersionsPanel), findsNothing);
    expect(find.byType(OcptScheduleAlertsPanel), findsOneWidget);
  });

  testWidgets("previewing a version reloads every view and withholds their writes, leaving it "
      "brings the working copy back", (tester) async {
    final shotId = (await harness.seedShots(1)).single;
    final dayId = await harness.seedDay(_first);
    final slotId = await harness.firstSlotOf(dayId);
    final service = harness.projectsManager.scheduleService;
    await service.updateSlot(
      database: harness.database,
      slotId: slotId,
      label: const Value("Cave"),
    );
    await service.placeShot(database: harness.database, slotId: slotId, shotId: shotId);
    await service.addSlotCrewMember(
      database: harness.database,
      slotId: slotId,
      personId: await harness.seedPerson("Alice"),
    );
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);

    // Written after the version was captured, so the preview cannot show it.
    await harness.seedDay(_second);
    await service.createBlock(
      database: harness.database,
      slotId: slotId,
      kind: OcptShootingBlockKind.meal,
    );

    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(find.textContaining(tr.scheduleStatsDays(2)), findsOneWidget);
    expect(harness.inTimetable(tr.scheduleBlockKindMeal), findsOneWidget);

    await openVersions(tester);
    await previewFirstVersion(tester);

    // The version's own plan on every view: one day, no meal.
    expect(find.text(tr.workspaceReadOnlyBannerExitAction), findsOneWidget);
    expect(find.textContaining(tr.scheduleStatsDays(1)), findsOneWidget);
    expect(harness.inTimetable(tr.scheduleBlockKindMeal), findsNothing);
    expect(harness.inTimetable("1/1"), findsOneWidget);
    expect(harness.inLeftDock("D2"), findsNothing);

    // And none of them writable: every affordance of the three surfaces is withheld.
    expect(find.byTooltip(tr.scheduleNewDayAction), findsNothing);
    expect(
      find.descendant(
        of: find.byType(OcptScheduleLeftDock),
        matching: find.byIcon(Icons.more_vert),
      ),
      findsNothing,
    );
    expect(find.text(tr.scheduleAddSlotAction), findsNothing);
    expect(find.text(tr.scheduleAddBlockAction), findsNothing);
    expect(find.text(tr.scheduleAddCrewMemberAction), findsNothing);
    expect(find.text(tr.scheduleAddCastAction), findsNothing);
    expect(find.byTooltip(tr.scheduleRemoveBlockTooltip), findsNothing);
    expect(
      find.descendant(of: find.byType(OcptScheduleSlotCard), matching: find.byType(TextField)),
      findsNothing,
    );
    expect(find.text("Cave"), findsWidgets);

    // Back to the working copy: everything written since is there again.
    await exitPreview(tester);
    expect(find.textContaining(tr.scheduleStatsDays(2)), findsOneWidget);
    expect(harness.inTimetable(tr.scheduleBlockKindMeal), findsOneWidget);
    expect(find.byTooltip(tr.scheduleNewDayAction), findsOneWidget);
    expect(find.byType(OcptScheduleDayView), findsOneWidget);
  });

  testWidgets("a label typed just before previewing a version is written first, the preview "
      "shows the version's own, and leaving it brings the label back", (tester) async {
    final dayId = await harness.seedDay(_first);
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await openVersions(tester);
    await harness.type(tester, harness.fieldHinted(tr.scheduleInspectorUnnamedSlot), "Late note");
    await previewFirstVersion(tester);

    // The working copy file holds it already, though the debounce never ran out.
    final fileDatabase = harness.projectsManager.currentProject!.fileDatabase;
    final stored = await harness.projectsManager.scheduleService.loadSchedule(
      database: fileDatabase,
    );
    expect(stored.slotsByDayId[dayId]!.single.label, "Late note");

    // The preview shows the version, which never had it.
    expect(find.text("Late note"), findsNothing);

    await exitPreview(tester);
    expect(find.widgetWithText(TextField, "Late note"), findsOneWidget);
  });

  testWidgets("restoring a version puts the days, the slots and the totals back to it", (
    tester,
  ) async {
    final dayId = await harness.seedDay(_first);
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    final laterDayId = await harness.seedDay(_second);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(find.textContaining(tr.scheduleStatsDays(2)), findsOneWidget);

    await openVersions(tester);
    await harness.tap(tester, find.text(tr.projectVersionRestoreAction));
    await harness.tap(tester, find.text(tr.projectVersionRestoreConfirmAction));
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.textContaining(tr.scheduleStatsDays(1))),
    );

    expect(find.textContaining(tr.scheduleStatsDays(1)), findsOneWidget);
    expect(harness.inLeftDock("D2"), findsNothing);
    final schedule = await harness.readSchedule();
    expect(schedule.days.map((day) => day.id), [dayId]);
    expect(schedule.daysById.containsKey(laterDayId), isFalse);
    expect(find.byType(OcptScheduleSlotCard), findsOneWidget);
  });

  testWidgets("coming back from the project settings with a change re-reads the whole plan and "
      "chooses the day afresh, while a plain return reads nothing", (tester) async {
    await harness.seedDay(_first);
    await harness.seedDay(_second);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openRightDock(tester);
    await harness.tap(tester, harness.inLeftDock("D2"));
    expect(harness.inInspector(tr.scheduleInspectorDayTitle("D2")), findsOneWidget);

    // A third day appears behind the mode's back; a return without change does not look.
    await harness.seedDay(DateTime(2099, 3, 3));
    harness.routerManager.pushAnswer = false;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    expect(harness.routerManager.pushCount, 1);
    expect(find.textContaining(tr.scheduleStatsDays(2)), findsOneWidget);

    // A return with a change re-reads, and the selection goes back to the default day.
    harness.routerManager.pushAnswer = true;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    expect(harness.routerManager.pushCount, 2);
    expect(find.textContaining(tr.scheduleStatsDays(3)), findsOneWidget);
    expect(harness.inInspector(tr.scheduleInspectorDayTitle("D1")), findsOneWidget);
  });

  testWidgets("the agenda presentation, its colouring and its paging survive a visit to the other "
      "views", (tester) async {
    await harness.seedDay(_first);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.switchView(tester, tr.scheduleHeaderAgendaSegmentLabel);
    await harness.switchView(tester, tr.scheduleAgendaModeWeek);
    await harness.switchView(tester, tr.scheduleAgendaColorModeEffect);
    final pagedLabel = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data ?? "").contains("2099"),
    );
    final firstWeekLabels = pagedLabel.evaluate().map((e) => (e.widget as Text).data).toList();
    expect(firstWeekLabels, isNotEmpty);
    await harness.tap(tester, find.byTooltip(tr.scheduleAgendaNextAction));
    final anchorLabels = pagedLabel.evaluate().map((e) => (e.widget as Text).data).toList();
    expect(anchorLabels, isNot(firstWeekLabels));

    await harness.switchView(tester, tr.scheduleHeaderPositionsSegmentLabel);
    await harness.switchView(tester, tr.scheduleHeaderPresenceSegmentLabel);
    await harness.switchView(tester, tr.scheduleHeaderDaySegmentLabel);
    await harness.switchView(tester, tr.scheduleHeaderAgendaSegmentLabel);

    expect(find.byTooltip(tr.scheduleAgendaNextAction), findsOneWidget);
    expect(find.text(tr.scheduleAgendaEffectLegendInteriorDay), findsOneWidget);
    expect(pagedLabel.evaluate().map((e) => (e.widget as Text).data).toList(), anchorLabels);

    // The left dock toggles away and back.
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    expect(find.byType(OcptScheduleLeftDock), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    expect(find.byType(OcptScheduleLeftDock), findsOneWidget);
  });
}
