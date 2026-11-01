// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector.dart';
import 'package:path/path.dart' as p;

import 'schedule_mode_scenarios_test_doubles.dart';

/// How long a scenario lets the mode's 2 s field-edit debounce run out.
const _debounceElapsed = Duration(milliseconds: 2500);

/// How long a scenario waits while staying clear of the 2 s field-edit debounce.
const _beforeDebounce = Duration(milliseconds: 300);

/// The date of the only day most scenarios plan, far from any clock a test could run on.
final _shootingDate = DateTime(2099, 3);

/// Run the tests of the schedule mode fields scenarios.
void main() {
  final harness = ScheduleScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  testWidgets("a typed slot label shows at once, reaches the database when its debounce runs out "
      "and then the inspector", (tester) async {
    final dayId = await harness.seedDay(_shootingDate);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openRightDock(tester);

    await harness.type(tester, harness.fieldHinted(tr.scheduleInspectorUnnamedSlot), "Cave");
    await tester.pump(_beforeDebounce);

    expect(find.widgetWithText(TextField, "Cave"), findsOneWidget);
    expect((await harness.readSchedule()).slotsByDayId[dayId]!.single.label, isEmpty);
    expect(
      find.descendant(
        of: find.byType(OcptScheduleInspector),
        matching: find.textContaining("Cave"),
      ),
      findsNothing,
    );

    await tester.pump(_debounceElapsed);
    await tester.pumpAndSettle();

    expect((await harness.readSchedule()).slotsByDayId[dayId]!.single.label, "Cave");
    expect(
      find.descendant(
        of: find.byType(OcptScheduleInspector),
        matching: find.textContaining("Cave"),
      ),
      findsOneWidget,
    );
  });

  testWidgets("a typed field survives a change of view and of day, and is written once, by the "
      "debounce it started", (tester) async {
    final dayId = await harness.seedDay(_shootingDate);
    final otherDayId = await harness.seedDay(DateTime(2099, 3, 2));
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.fieldHinted(tr.scheduleInspectorUnnamedSlot), "Cave");

    await harness.tapQuickly(tester, find.text(tr.scheduleHeaderAgendaSegmentLabel));
    await harness.tapQuickly(tester, find.text(tr.scheduleHeaderDaySegmentLabel));
    expect(find.widgetWithText(TextField, "Cave"), findsOneWidget);

    // Another day and back: nothing flushed the edit, and it is still the one typed.
    await harness.tapQuickly(tester, harness.inLeftDock("D2"));
    expect((await harness.readSchedule()).slotsByDayId[dayId]!.single.label, isEmpty);
    await harness.tapQuickly(tester, harness.inLeftDock("D1"));
    expect(find.widgetWithText(TextField, "Cave"), findsOneWidget);

    await tester.pump(_debounceElapsed);
    await tester.pumpAndSettle();

    final schedule = await harness.readSchedule();
    expect(schedule.slotsByDayId[dayId]!.single.label, "Cave");
    expect(schedule.slotsByDayId[otherDayId]!.single.label, isEmpty);
  });

  testWidgets("a typed slot label and a typed day note are written at once when another dock tab "
      "is picked", (tester) async {
    final dayId = await harness.seedDay(_shootingDate);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openRightDock(tester);

    await harness.type(tester, harness.fieldHinted(tr.scheduleInspectorUnnamedSlot), "Cave");
    await harness.type(tester, harness.inspectorFields().first, "Rain at noon");
    await harness.tapQuickly(tester, find.text(tr.scheduleRightDockConvocationsTabLabel));
    await tester.pump();
    await tester.pumpAndSettle();

    final schedule = await harness.readSchedule();
    expect(schedule.slotsByDayId[dayId]!.single.label, "Cave");
    expect(schedule.daysById[dayId]!.weatherNote, "Rain at noon");

    // Back on the inspector, the stored values are the ones read.
    await harness.tap(tester, find.text(tr.scheduleRightDockInspectorTabLabel));
    expect(find.widgetWithText(TextField, "Rain at noon"), findsOneWidget);
    expect(find.widgetWithText(TextField, "Cave"), findsOneWidget);
  });

  testWidgets("a typed day crew note, block note and slot note are written when the mode is "
      "left right after typing", (tester) async {
    final dayId = await harness.seedDay(_shootingDate);
    final slotId = await harness.firstSlotOf(dayId);
    final blockId = (await harness.projectsManager.scheduleService.createBlock(
      database: harness.database,
      slotId: slotId,
      kind: OcptShootingBlockKind.meal,
    ))!;
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    // Day-level notes first: the inspector falls back to the day with no block selected.
    await harness.openRightDock(tester);
    await harness.type(tester, harness.inspectorFields().last, "Bring umbrellas");
    await harness.type(tester, harness.fieldHinted(tr.scheduleSlotNotesHint), "Private slot note");
    await harness.unmount(tester);

    var schedule = await harness.readSchedule();
    expect(schedule.daysById[dayId]!.crewNote, "Bring umbrellas");
    expect(schedule.slotsByDayId[dayId]!.single.notes, "Private slot note");

    // Block-level notes: the inspector switches to the selected block's fields.
    await harness.mount(tester);
    await harness.tap(tester, harness.inTimetable(tr.scheduleBlockKindMeal));
    // The block's duration field comes first, then its crew note and its private notes.
    await harness.type(tester, harness.inspectorFields().at(1), "Vegetarian");
    await harness.type(tester, harness.inspectorFields().last, "Cold lunch");
    await harness.unmount(tester);

    schedule = await harness.readSchedule();
    final block = schedule.blocksByDayId[dayId]!.single;
    expect(block.id, blockId);
    expect({block.crewNote, block.notes}, {"Vegetarian", "Cold lunch"});
  });

  testWidgets("a typed event label and a typed guest reason are written when the mode is left "
      "right after typing", (tester) async {
    final dayId = await harness.seedDay(_shootingDate);
    final slotId = await harness.firstSlotOf(dayId);
    final service = harness.projectsManager.scheduleService;
    final eventId = (await service.createDayEvent(
      database: harness.database,
      dayId: dayId,
      minute: 600,
    ))!;
    final guestId = (await service.addSlotGuest(
      database: harness.database,
      slotId: slotId,
      freeName: "The mayor",
    ))!;
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.fieldHinted(tr.scheduleDayEventLabelHint), "Fire drill");
    await harness.type(
      tester,
      harness.fieldHinted(tr.scheduleSlotGuestReasonHint),
      "Ribbon cutting",
    );
    await harness.unmount(tester);

    final schedule = await harness.readSchedule();
    expect(schedule.eventsByDayId[dayId]!.single.id, eventId);
    expect(schedule.eventsByDayId[dayId]!.single.label, "Fire drill");
    final guest = schedule.slotsByDayId[dayId]!.single.guests.single;
    expect(guest.id, guestId);
    expect(guest.reason, "Ribbon cutting");
  });

  /// Opens the toolbar's export panel and picks the card titled [title].
  Future<void> pickExport(WidgetTester tester, String title) async {
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.byTooltip(tr.workspaceExportTooltip));
    await harness.tap(tester, harness.inDialog(find.text(title)));
  }

  /// Applies the options dialog the picked export opened.
  Future<void> applyOptions(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.widgetWithText(FilledButton, tr.editorExportPdfExportAction));
  }

  testWidgets("every export prints the plan as typed, even when it is requested right after the "
      "keystroke", (tester) async {
    final dayId = await harness.seedDay(_shootingDate);
    final slotId = await harness.firstSlotOf(dayId);
    await harness.projectsManager.scheduleService.addSlotCrewMember(
      database: harness.database,
      slotId: slotId,
      personId: await harness.seedPerson("Alice"),
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    final documents = <(String, String, String)>[
      ("callSheets", tr.scheduleExportPanelCallSheetsTitle, "Call sheets label"),
      ("namedCallSheets", tr.scheduleExportPanelNamedCallSheetsTitle, "Named label"),
      ("shootingPlan", tr.scheduleExportPanelShootingPlanTitle, "Plan label"),
      ("shootingPlanXlsx", tr.scheduleExportPanelShootingPlanXlsxTitle, "Workbook label"),
      ("dayOutOfDays", tr.scheduleExportPanelDayOutOfDaysTitle, "Out of days label"),
      ("oneLineSchedule", tr.scheduleExportPanelOneLineScheduleTitle, "One line label"),
      ("sides", tr.scheduleExportPanelSidesTitle, "Sides label"),
    ];

    for (final (document, title, typed) in documents) {
      harness.exportManager.exports.clear();
      await harness.type(tester, harness.fieldHinted(tr.scheduleInspectorUnnamedSlot), typed);
      await pickExport(tester, title);
      await applyOptions(tester);

      final exported = harness.exportManager.exports.single;
      expect(exported.document, document, reason: title);
      expect(exported.dayIds, [dayId], reason: title);
      expect(exported.plan.schedule.slotsByDayId[dayId]!.single.label, typed, reason: title);
      expect((await harness.readSchedule()).slotsByDayId[dayId]!.single.label, typed);
      expect(find.byType(SnackBar), findsOneWidget, reason: title);
    }
  });

  testWidgets("the export notices tell a file, a folder, a partial folder, a failure, and say "
      "nothing for a cancelled dialog", (tester) async {
    final dayId = await harness.seedDay(_shootingDate);
    await harness.seedDay(DateTime(2099, 3, 2));
    await harness.projectsManager.scheduleService.addSlotCrewMember(
      database: harness.database,
      slotId: await harness.firstSlotOf(dayId),
      personId: await harness.seedPerson("Alice"),
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await pickExport(tester, tr.scheduleExportPanelShootingPlanTitle);
    await applyOptions(tester);
    expect(find.text(tr.scheduleExportFileSuccessMessage("/tmp/shootingPlan.pdf")), findsOneWidget);

    await pickExport(tester, tr.scheduleExportPanelCallSheetsTitle);
    await applyOptions(tester);
    // The general call sheets dialog opens on the selected day alone.
    expect(harness.exportManager.exports.last.dayIds, [dayId]);
    expect(find.text(tr.scheduleExportFolderSuccessMessage(1, "/tmp/sheets")), findsOneWidget);

    harness.exportManager.failedFileNames = ["broken.pdf"];
    await pickExport(tester, tr.scheduleExportPanelCallSheetsTitle);
    await applyOptions(tester);
    expect(find.text(tr.scheduleExportFolderPartialMessage(0, "/tmp/sheets", 1)), findsOneWidget);

    harness.exportManager
      ..failedFileNames = const []
      ..shouldFail = true;
    await pickExport(tester, tr.scheduleExportPanelOneLineScheduleTitle);
    await applyOptions(tester);
    expect(find.text(tr.scheduleExportError), findsOneWidget);

    // Every document says so when it fails, not only the one above.
    harness.exportManager.shouldFail = true;
    for (final title in [
      tr.scheduleExportPanelCallSheetsTitle,
      tr.scheduleExportPanelNamedCallSheetsTitle,
      tr.scheduleExportPanelShootingPlanTitle,
      tr.scheduleExportPanelShootingPlanXlsxTitle,
      tr.scheduleExportPanelDayOutOfDaysTitle,
      tr.scheduleExportPanelSidesTitle,
    ]) {
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text(tr.scheduleExportError), findsNothing, reason: title);
      await pickExport(tester, title);
      await applyOptions(tester);
      expect(find.text(tr.scheduleExportError), findsOneWidget, reason: title);
    }

    // A cancelled dialog leaves the screen as it was: the earlier notice goes, none replaces it.
    harness.exportManager
      ..shouldFail = false
      ..shouldCancel = true;
    await tester.pump(const Duration(seconds: 10));
    await pickExport(tester, tr.scheduleExportPanelDayOutOfDaysTitle);
    await applyOptions(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(SnackBar), findsNothing);
    expect(harness.exportManager.exports.last.document, "dayOutOfDays");
  });

  testWidgets("going back to the projects right after typing closes the project before the "
      "keystrokes could be written, and they are lost", (tester) async {
    final dayId = await harness.seedDay(_shootingDate);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.fieldHinted(tr.scheduleInspectorUnnamedSlot), "Cave");
    await harness.tap(tester, find.byTooltip(tr.editorBackToProjectsTooltip));
    await harness.pumpUntil(tester, () => harness.projectsManager.currentProject == null);
    expect(harness.projectsManager.currentProject, isNull);

    // The route going away runs the mode's leaving flush, which finds no project any more.
    await harness.unmount(tester);
    await tester.runAsync(() async {
      final reopened = await harness.projectsManager.openProject(
        filePath: p.join(harness.tempDir.path, "movie.ocpt"),
      );
      expect(reopened.status.isSuccess, isTrue);
    });

    expect((await harness.readSchedule()).slotsByDayId[dayId]!.single.label, isEmpty);
  });
}
