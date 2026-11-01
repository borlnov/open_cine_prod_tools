// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_alerts_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_convocations_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_alert_badge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_positions_matrix.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_presence_grid.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_strip_agenda.dart';

import 'schedule_mode_scenarios_test_doubles.dart';

/// Three dates far from any clock the test could run on: one long past, two in the far future.
final _past = DateTime(2001, 1, 5);

/// The first of the two days the scenarios use.
final _first = DateTime(2099, 3);

/// The second of the two days the tests use.
final _second = DateTime(2099, 3, 2);

/// Run the tests of the schedule mode scenarios.
void main() {
  final harness = ScheduleScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  final inLeftDock = harness.inLeftDock;
  final inTimetable = harness.inTimetable;
  final inInspector = harness.inInspector;

  testWidgets("entry lands on the day nearest to come, with the dock shut and the totals read", (
    tester,
  ) async {
    await harness.seedShots(2);
    await harness.seedDay(_second);
    await harness.seedDay(_first);
    await harness.seedDay(_past);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    // Three days listed, ranked by date rather than by creation order.
    expect(find.textContaining(tr.scheduleStatsDays(3)), findsOneWidget);
    expect(find.textContaining(tr.scheduleStatsAlerts(0)), findsOneWidget);
    expect(find.textContaining(tr.scheduleStatsShotsLeftToPlace(2)), findsOneWidget);
    expect(find.byType(OcptScheduleRightDock), findsNothing);
    expect(find.byType(OcptScheduleSlotCard), findsOneWidget);

    // The day shown is the first still to come: D2, not the long-past D1.
    await harness.openRightDock(tester);
    expect(inInspector(tr.scheduleInspectorDayTitle("D2")), findsOneWidget);
    expect(find.byType(OcptScheduleSlotCard), findsOneWidget);
  });

  testWidgets("a project with no day yet says so, and shows no slot card", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.text(tr.scheduleDaysEmptyHint), findsOneWidget);
    expect(find.text(tr.scheduleInspectorEmptyHint), findsOneWidget);
    expect(find.byType(OcptScheduleSlotCard), findsNothing);
    expect(find.textContaining(tr.scheduleStatsDays(0)), findsOneWidget);
  });

  testWidgets("selecting a day, a block from the agenda and a day again carries the selection "
      "from one view to the next", (tester) async {
    final shotId = (await harness.seedShots(1)).single;
    final firstDay = await harness.seedDay(_first);
    final secondDay = await harness.seedDay(_second);
    await harness.projectsManager.scheduleService.updateSlot(
      database: harness.database,
      slotId: await harness.firstSlotOf(secondDay),
      label: const Value("Cave"),
    );
    await harness.projectsManager.scheduleService.placeShot(
      database: harness.database,
      slotId: await harness.firstSlotOf(firstDay),
      shotId: shotId,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openRightDock(tester);
    expect(inInspector(tr.scheduleInspectorDayTitle("D1")), findsOneWidget);

    // A day picked in the left dock drives the day view and the inspector at once.
    await harness.tap(tester, inLeftDock("D2"));
    expect(inInspector(tr.scheduleInspectorDayTitle("D2")), findsOneWidget);
    expect(find.widgetWithText(TextField, "Cave"), findsOneWidget);
    expect(inTimetable("1/1"), findsNothing);

    // A block clicked in the agenda selects it, its day, and brings its read-out up.
    await harness.switchView(tester, tr.scheduleHeaderAgendaSegmentLabel);
    await harness.tap(
      tester,
      find.descendant(
        of: find.byType(OcptScheduleStripAgenda),
        matching: find.textContaining("1/1"),
      ),
    );
    expect(inInspector(tr.scheduleInspectorBlockCrewNoteLabel.toUpperCase()), findsOneWidget);
    expect(inInspector(tr.scheduleInspectorDayTitle("D2")), findsNothing);

    // Back on the day view the same selection reads: D1's timetable, the block's read-out.
    await harness.switchView(tester, tr.scheduleHeaderDaySegmentLabel);
    expect(inTimetable("1/1"), findsOneWidget);
    expect(find.widgetWithText(TextField, "Cave"), findsNothing);
    expect(inInspector(tr.scheduleInspectorBlockCrewNoteLabel.toUpperCase()), findsOneWidget);

    // Picking the day again drops the block: the inspector falls back to the day.
    await harness.tap(tester, inLeftDock("D1"));
    expect(inInspector(tr.scheduleInspectorBlockCrewNoteLabel.toUpperCase()), findsNothing);
    expect(inInspector(tr.scheduleInspectorDayTitle("D1")), findsOneWidget);
  });

  testWidgets("an unplaced shot picked in the left dock shows its read-out, and a day or a block "
      "picked after it takes the inspector back", (tester) async {
    await harness.seedShots(2);
    final dayId = await harness.seedDay(_first);
    final blockId = await harness.projectsManager.scheduleService.createBlock(
      database: harness.database,
      slotId: await harness.firstSlotOf(dayId),
      kind: OcptShootingBlockKind.meal,
    );
    expect(blockId, isNotNull);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, inLeftDock("1/2"));
    expect(inInspector(tr.scheduleInspectorShotNotPlanned), findsOneWidget);
    expect(inInspector(tr.scheduleInspectorDayTitle("D1")), findsNothing);

    // A block clears the shot: the two selections are exclusive.
    await harness.tap(tester, inTimetable(tr.scheduleBlockKindMeal));
    expect(inInspector(tr.scheduleInspectorShotNotPlanned), findsNothing);
    expect(inInspector(tr.scheduleInspectorBlockCrewNoteLabel.toUpperCase()), findsOneWidget);

    // And a shot clears the block.
    await harness.tap(tester, inLeftDock("1/1"));
    expect(inInspector(tr.scheduleInspectorShotNotPlanned), findsOneWidget);
    expect(inInspector(tr.scheduleInspectorBlockCrewNoteLabel.toUpperCase()), findsNothing);

    // A day clears the shot.
    await harness.tap(tester, inLeftDock("D1"));
    expect(inInspector(tr.scheduleInspectorShotNotPlanned), findsNothing);
    expect(inInspector(tr.scheduleInspectorDayTitle("D1")), findsOneWidget);

    // A shot, then a block, then the block deleted: the inspector lands on the day, not on the
    // shot picked before the block.
    await harness.tap(tester, inLeftDock("1/2"));
    await harness.tap(tester, inTimetable(tr.scheduleBlockKindMeal));
    await harness.tap(tester, find.byTooltip(tr.scheduleRemoveBlockTooltip));
    await harness.tap(tester, find.text(tr.scheduleDeleteDayConfirmAction));
    expect(inInspector(tr.scheduleInspectorShotNotPlanned), findsNothing);
    expect(inInspector(tr.scheduleInspectorDayTitle("D1")), findsOneWidget);
  });

  testWidgets("a slot, a shot block and a meal block written from the day view reach the left "
      "dock, the status bar, the agenda and the database", (tester) async {
    final shotIds = await harness.seedShots(2);
    final dayId = await harness.seedDay(_first);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    // A shot picked from the `Block` menu is placed on the slot.
    await harness.tap(tester, find.text(tr.scheduleAddBlockAction));
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<OcptShootingBlockKind>, tr.scheduleBlockKindShot),
    );
    expect(find.text(tr.scheduleShotPickerDialogTitle), findsOneWidget);
    await harness.tap(
      tester,
      find.descendant(of: find.byType(AlertDialog), matching: find.textContaining("1/2")),
    );
    expect(find.text(tr.scheduleShotPickerDialogTitle), findsNothing);

    var schedule = await harness.readSchedule();
    expect(schedule.blocksByDayId[dayId]!.single.shotId, shotIds[1]);
    expect(inTimetable("1/2"), findsOneWidget);
    expect(find.textContaining(tr.scheduleStatsShotsPlaced(1)), findsOneWidget);
    expect(find.textContaining(tr.scheduleStatsShotsLeftToPlace(1)), findsOneWidget);
    expect(inLeftDock("1/2"), findsNothing);
    expect(inLeftDock("1/1"), findsOneWidget);
    expect(inLeftDock(tr.scheduleDayBlockCount(1)), findsOneWidget);

    // A meal from the same menu lands after it.
    await harness.tap(tester, find.text(tr.scheduleAddBlockAction));
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<OcptShootingBlockKind>, tr.scheduleBlockKindMeal),
    );
    schedule = await harness.readSchedule();
    expect(schedule.blocksByDayId[dayId]!.map((block) => block.kind), [
      OcptShootingBlockKind.shot,
      OcptShootingBlockKind.meal,
    ]);
    expect(inLeftDock(tr.scheduleDayBlockCount(2)), findsOneWidget);

    // A second slot shows as a second card and in the inspector's day read-out.
    await harness.tap(tester, find.text(tr.scheduleAddSlotAction));
    schedule = await harness.readSchedule();
    expect(schedule.slotsByDayId[dayId], hasLength(2));
    expect(find.byType(OcptScheduleSlotCard), findsNWidgets(2));
    await harness.openRightDock(tester);
    expect(
      find.descendant(
        of: find.byType(OcptScheduleInspector),
        matching: find.textContaining(tr.scheduleInspectorUnnamedSlot),
      ),
      findsNWidgets(2),
    );

    // The agenda reads the same plan.
    await harness.switchView(tester, tr.scheduleHeaderAgendaSegmentLabel);
    expect(
      find.descendant(
        of: find.byType(OcptScheduleStripAgenda),
        matching: find.textContaining("1/2"),
      ),
      findsOneWidget,
    );
  });

  testWidgets("a shot's status changed from its block row is written to the shot list and read "
      "back by the block's inspector", (tester) async {
    final shotId = (await harness.seedShots(1)).single;
    final dayId = await harness.seedDay(_first);
    await harness.projectsManager.scheduleService.placeShot(
      database: harness.database,
      slotId: await harness.firstSlotOf(dayId),
      shotId: shotId,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, inTimetable(tr.shotListStatusToShoot));
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<OcptShotStatus>, tr.shotListStatusRetake),
    );

    expect((await harness.readShotList()).shotsById[shotId]!.status.name, "retake");
    expect(inTimetable(tr.shotListStatusRetake), findsOneWidget);

    await harness.tap(tester, inTimetable("1/1"));
    expect(inInspector(tr.shotListStatusRetake), findsOneWidget);
  });

  testWidgets("a crew member and an uncast role convoked from the day view reach the convocations, "
      "the positions matrix, the presence grid and the alerts, and leave them when removed", (
    tester,
  ) async {
    final dayId = await harness.seedDay(_first);
    await harness.seedPerson("Alice");
    await harness.seedUncastRole("MARIE");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.text(tr.scheduleAddCrewMemberAction));
    await harness.tap(tester, find.widgetWithText(PopupMenuItem<String>, "Alice"));
    var slot = (await harness.readSchedule()).slotsByDayId[dayId]!.single;
    expect(slot.crew.single.personId, isNotEmpty);

    // A position given outside the mode shows once the next write reloads the plan.
    await harness.projectsManager.scheduleService.updateSlotCrewMember(
      database: harness.database,
      crewMemberId: slot.crew.single.id,
      customLabel: const Value("Gaffer"),
    );

    // An uncast role convoked raises an alert: the status bar and the day badge.
    expect(find.textContaining(tr.scheduleStatsAlerts(0)), findsOneWidget);
    await harness.tap(tester, find.text(tr.scheduleAddCastAction));
    await harness.tap(tester, find.widgetWithText(PopupMenuItem<String>, "MARIE"));
    slot = (await harness.readSchedule()).slotsByDayId[dayId]!.single;
    expect(slot.cast, hasLength(1));
    expect(find.textContaining(tr.scheduleStatsAlerts(1)), findsOneWidget);
    expect(find.byType(OcptScheduleDayAlertBadge), findsWidgets);

    // The convocation reads from the dock, and the two calculated views list the same plan.
    await harness.openDockTab(tester, tr.scheduleRightDockConvocationsTabLabel);
    expect(
      find.descendant(
        of: find.byType(OcptScheduleConvocationsPanel),
        matching: find.textContaining("Alice"),
      ),
      findsWidgets,
    );
    await harness.switchView(tester, tr.scheduleHeaderPositionsSegmentLabel);
    expect(
      find.descendant(of: find.byType(OcptSchedulePositionsMatrix), matching: find.text("Gaffer")),
      findsWidgets,
    );
    await harness.switchView(tester, tr.scheduleHeaderPresenceSegmentLabel);
    expect(
      find.descendant(
        of: find.byType(OcptSchedulePresenceGrid),
        matching: find.textContaining("Alice"),
      ),
      findsWidgets,
    );
    await harness.switchView(tester, tr.scheduleHeaderDaySegmentLabel);
    await harness.tap(tester, find.text(tr.scheduleRightDockAlertsTabLabel));
    expect(
      find.descendant(
        of: find.byType(OcptScheduleAlertsPanel),
        matching: find.textContaining("MARIE"),
      ),
      findsWidgets,
    );

    // Removing the convocation clears the alert everywhere.
    await harness.tap(tester, find.byTooltip(tr.scheduleRemoveCastTooltip));
    expect((await harness.readSchedule()).slotsByDayId[dayId]!.single.cast, isEmpty);
    expect(find.textContaining(tr.scheduleStatsAlerts(0)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OcptScheduleAlertsPanel),
        matching: find.textContaining("MARIE"),
      ),
      findsNothing,
    );

    // And so does removing the crew member from the slot card.
    await harness.tap(tester, find.byTooltip(tr.scheduleRemoveCrewMemberTooltip));
    expect((await harness.readSchedule()).slotsByDayId[dayId]!.single.crew, isEmpty);
  });

  testWidgets("deleting a block, then a slot, then a day cascades to every view and every total", (
    tester,
  ) async {
    final shotId = (await harness.seedShots(1)).single;
    final dayId = await harness.seedDay(_first);
    final otherDayId = await harness.seedDay(_second);
    final slotId = await harness.firstSlotOf(dayId);
    final service = harness.projectsManager.scheduleService;
    await service.placeShot(database: harness.database, slotId: slotId, shotId: shotId);
    await service.createBlock(
      database: harness.database,
      slotId: slotId,
      kind: OcptShootingBlockKind.meal,
    );
    await service.addSlotCastRole(
      database: harness.database,
      slotId: slotId,
      roleId: await harness.seedUncastRole("MARIE"),
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(find.textContaining(tr.scheduleStatsAlerts(1)), findsOneWidget);
    expect(find.textContaining(tr.scheduleStatsShotsPlaced(1)), findsOneWidget);

    // The block selected, then deleted from its row after a confirmation: the shot goes back to
    // the left dock, and the inspector falls back to the day.
    await harness.tap(tester, inTimetable("1/1"));
    expect(inInspector(tr.scheduleInspectorBlockCrewNoteLabel.toUpperCase()), findsOneWidget);
    await harness.tap(tester, find.byTooltip(tr.scheduleRemoveBlockTooltip).first);
    expect(find.text(tr.scheduleDeleteBlockConfirmTitle), findsOneWidget);
    await harness.tap(tester, find.text(tr.scheduleDeleteDayCancelAction));
    expect((await harness.readSchedule()).blocksByDayId[dayId], hasLength(2));
    await harness.tap(tester, find.byTooltip(tr.scheduleRemoveBlockTooltip).first);
    await harness.tap(tester, find.text(tr.scheduleDeleteDayConfirmAction));

    expect(
      (await harness.readSchedule()).blocksByDayId[dayId]!.single.kind,
      OcptShootingBlockKind.meal,
    );
    expect(inTimetable("1/1"), findsNothing);
    expect(inLeftDock("1/1"), findsOneWidget);
    expect(find.textContaining(tr.scheduleStatsShotsLeftToPlace(1)), findsOneWidget);
    expect(inInspector(tr.scheduleInspectorBlockCrewNoteLabel.toUpperCase()), findsNothing);
    expect(inInspector(tr.scheduleInspectorDayTitle("D1")), findsOneWidget);

    // The slot deleted takes its remaining block and the convocation raising the alert along.
    await harness.tap(
      tester,
      find
          .descendant(of: find.byType(OcptScheduleSlotCard), matching: find.byIcon(Icons.more_vert))
          .first,
    );
    await harness.tap(tester, find.text(tr.scheduleDeleteSlotAction));
    expect(find.text(tr.scheduleDeleteSlotConfirmTitle), findsOneWidget);
    await harness.tap(tester, find.text(tr.scheduleDeleteDayConfirmAction));

    var schedule = await harness.readSchedule();
    expect(schedule.slotsByDayId[dayId] ?? const [], isEmpty);
    expect(schedule.blocksByDayId[dayId] ?? const [], isEmpty);
    expect(find.byType(OcptScheduleSlotCard), findsNothing);
    expect(find.textContaining(tr.scheduleStatsAlerts(0)), findsOneWidget);
    expect(inLeftDock(tr.scheduleDayBlockCount(0)), findsNWidgets(2));

    // The day deleted leaves the other one, but no selection: the day view asks for a pick.
    await harness.tap(
      tester,
      find
          .descendant(of: find.byType(OcptScheduleLeftDock), matching: find.byIcon(Icons.more_vert))
          .first,
    );
    await harness.tap(tester, find.text(tr.scheduleDeleteDayAction));
    expect(find.text(tr.scheduleDeleteDayConfirmTitle), findsOneWidget);
    await harness.tap(tester, find.text(tr.scheduleDeleteDayConfirmAction));

    schedule = await harness.readSchedule();
    expect(schedule.days.map((day) => day.id), [otherDayId]);
    expect(find.textContaining(tr.scheduleStatsDays(1)), findsOneWidget);
    // Both the day view and the open inspector ask for a pick.
    expect(find.text(tr.scheduleInspectorEmptyHint), findsNWidgets(2));
    expect(find.byType(OcptScheduleSlotCard), findsNothing);
    expect(find.text(tr.scheduleStatsNoDaySelected), findsOneWidget);
  });

  testWidgets("a day created, duplicated and re-statused from the left dock is selected as soon as "
      "it exists", (tester) async {
    final dayId = await harness.seedDay(_first);
    await harness.projectsManager.scheduleService.updateSlot(
      database: harness.database,
      slotId: await harness.firstSlotOf(dayId),
      label: const Value("Cave"),
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openRightDock(tester);

    // A new day dated today ranks before the far-future one, and is the one selected.
    await harness.tap(tester, find.byTooltip(tr.scheduleNewDayAction));
    await harness.tap(tester, find.text("OK"));
    var schedule = await harness.readSchedule();
    expect(schedule.days, hasLength(2));
    final createdId = schedule.days.first.id;
    expect(createdId, isNot(dayId));
    expect(schedule.days.last.id, dayId);
    expect(inInspector(tr.scheduleInspectorDayTitle("D1")), findsOneWidget);
    expect(find.textContaining(tr.scheduleStatsDays(2)), findsOneWidget);

    // Duplicating the far-future day copies its slot and selects the copy.
    await harness.tap(tester, find.byIcon(Icons.more_vert).at(2));
    await harness.tap(tester, find.text(tr.scheduleDuplicateDayAction));
    await harness.tap(tester, find.text("OK"));
    schedule = await harness.readSchedule();
    expect(schedule.days, hasLength(3));
    final copy = schedule.days.firstWhere((day) => day.id != dayId && day.id != createdId);
    expect(schedule.slotsByDayId[copy.id]!.single.label, "Cave");
    expect(find.widgetWithText(TextField, "Cave"), findsOneWidget);

    // A status picked in the inspector is written onto the selected day.
    await harness.tap(tester, inInspector(tr.scheduleDayStatusPlanned));
    await harness.tap(
      tester,
      find.widgetWithText(PopupMenuItem<OcptShootingDayStatus>, tr.scheduleDayStatusCancelled),
    );
    schedule = await harness.readSchedule();
    expect(schedule.daysById[copy.id]!.status, OcptShootingDayStatus.cancelled);
    expect(
      find.descendant(
        of: find.byType(OcptScheduleLeftDock),
        matching: find.text(tr.scheduleDayStatusCancelled),
      ),
      findsOneWidget,
    );
  });

  testWidgets("re-dating the selected day renumbers the schedule around it and keeps it selected", (
    tester,
  ) async {
    final earlierDayId = await harness.seedDay(DateTime(2099, 3, 10));
    final laterDayId = await harness.seedDay(DateTime(2099, 3, 20));
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openRightDock(tester);
    await harness.tap(tester, inLeftDock("D2"));
    expect(inInspector(tr.scheduleInspectorDayTitle("D2")), findsOneWidget);

    await harness.tap(
      tester,
      find
          .descendant(of: find.byType(OcptScheduleLeftDock), matching: find.byIcon(Icons.more_vert))
          .last,
    );
    await harness.tap(tester, find.text(tr.scheduleChangeDayDateAction));
    await harness.tap(tester, find.text("5"));
    await harness.tap(tester, find.text("OK"));

    final schedule = await harness.readSchedule();
    expect(schedule.daysById[laterDayId]!.date, DateTime(2099, 3, 5));
    expect(schedule.days.map((day) => day.id), [laterDayId, earlierDayId]);
    expect(inInspector(tr.scheduleInspectorDayTitle("D1")), findsOneWidget);
  });

  testWidgets("a block moved to another slot and a slot moved down are written in the order the "
      "day view then shows", (tester) async {
    final dayId = await harness.seedDay(_first);
    final service = harness.projectsManager.scheduleService;
    final firstSlotId = await harness.firstSlotOf(dayId);
    await service.updateSlot(
      database: harness.database,
      slotId: firstSlotId,
      label: const Value("Cave"),
    );
    final secondSlotId = (await service.createSlot(
      database: harness.database,
      shootingDayId: dayId,
      anchorMinute: 780,
      label: "Garden",
    ))!;
    final blockId = (await service.createBlock(
      database: harness.database,
      slotId: firstSlotId,
      kind: OcptShootingBlockKind.meal,
    ))!;
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.byTooltip(tr.scheduleMoveBlockTooltip));
    await harness.tap(tester, find.widgetWithText(PopupMenuItem<String>, "Garden"));
    var schedule = await harness.readSchedule();
    expect(schedule.blocksByDayId[dayId]!.single.id, blockId);
    expect(schedule.blocksByDayId[dayId]!.single.slotId, secondSlotId);

    await harness.tap(tester, find.byTooltip(tr.scheduleMoveSlotDownTooltip).first);
    schedule = await harness.readSchedule();
    expect(schedule.slotsByDayId[dayId]!.map((slot) => slot.id), [secondSlotId, firstSlotId]);
    final cards = tester.widgetList<OcptScheduleSlotCard>(find.byType(OcptScheduleSlotCard));
    expect(cards.map((card) => card.slot.id), [secondSlotId, firstSlotId]);
  });
}
