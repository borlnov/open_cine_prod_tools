// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the `OcptWorkspaceDock` right panel the inspector fills in the app.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 320, height: 700, child: child)),
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({
  OcptShootingDayStatus status = OcptShootingDayStatus.planned,
  String crewNote = "",
  String weatherNote = "",
}) => OcptShootingDay(
  id: "day-1",
  screenplayId: "screenplay-1",
  date: DateTime(2026, 8, 4),
  dayNumber: 3,
  status: status,
  crewNote: crewNote,
  weatherNote: weatherNote,
  notes: "",
);

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({
  String id = "shot-1",
  String code = "4/1",
  List<String> characters = const [],
  int? estimatedDurationMs,
  OcptShotStatus status = OcptShotStatus.toShoot,
}) => OcptShot(
  id: id,
  screenplayId: "screenplay-1",
  sceneId: "scene-1",
  orphanedHeading: null,
  position: 0,
  shotSize: "GP",
  abbreviation: "GP",
  framing: "",
  cameraMove: "",
  lens: "",
  recordingFormat: "",
  estimatedDurationMs: estimatedDurationMs,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: status,
  difficultySet: 0,
  difficultyCamera: 0,
  difficultyActing: 0,
  difficultySound: 0,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: characters,
  coverageRanges: const [],
  code: code,
  averageDifficulty: 0,
);

/// Builds a `hold` block, distinguishable from the shot read-out by carrying a label and no shot.
OcptShootingDayBlock _buildHoldBlock({String id = "block-1", String label = "Prep"}) =>
    OcptShootingDayBlock(
      id: id,
      shootingDayId: "day-1",
      slotId: "slot-1",
      kind: OcptShootingBlockKind.hold,
      shotId: null,
      sceneId: null,
      label: label,
      durationMinutes: null,
      anchorMinute: null,
      notes: "",
    );

/// Pumps [OcptScheduleInspector] with [day]/[shot]/[block] selected as given — mirrors the widget's
/// own block-then-shot-then-day precedence, so a test only fills in whichever of the three it
/// exercises.
Future<void> _pumpInspector(
  WidgetTester tester, {
  OcptShootingDay? day,
  OcptSunTimes? sunTimes,
  ValueChanged<OcptShootingDayStatus>? onDayStatusChanged,
  ValueChanged<String>? onCrewNoteChanged,
  ValueChanged<String>? onWeatherNoteChanged,
  OcptShot? shot,
  String? shotSequenceLabel,
  List<int> shotPlacedDayNumbers = const [],
  OcptShootingDayBlock? block,
  OcptShootingTimelineEntry? blockEntry,
  ValueChanged<OcptShotStatus>? onShotStatusChanged,
  ValueChanged<int>? onBlockDurationChanged,
}) async {
  await tester.pumpWidget(
    _wrapInApp(
      OcptScheduleInspector(
        day: day,
        slots: const [],
        locationById: const {},
        setById: const {},
        timeline: null,
        sunTimes: sunTimes,
        crewNoteValue: day?.crewNote ?? "",
        weatherNoteValue: day?.weatherNote ?? "",
        onDayStatusChanged: onDayStatusChanged,
        onCrewNoteChanged: onCrewNoteChanged,
        onWeatherNoteChanged: onWeatherNoteChanged,
        shot: shot,
        shotSequenceLabel: shotSequenceLabel,
        shotPlacedDayNumbers: shotPlacedDayNumbers,
        block: block,
        blockShot: null,
        blockSlotLabel: null,
        blockEntry: blockEntry,
        onShotStatusChanged: onShotStatusChanged,
        onBlockDurationChanged: onBlockDurationChanged,
        blockNotesValue: "",
        onBlockNotesChanged: null,
        isReadOnly: onDayStatusChanged == null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps [OcptScheduleInspector] with [day] selected and nothing else — the day-inspector tests'
/// own convenience wrapper over [_pumpInspector].
Future<void> _pumpDayInspector(
  WidgetTester tester, {
  required OcptShootingDay day,
  OcptSunTimes? sunTimes,
  ValueChanged<OcptShootingDayStatus>? onDayStatusChanged,
  ValueChanged<String>? onCrewNoteChanged,
  ValueChanged<String>? onWeatherNoteChanged,
}) => _pumpInspector(
  tester,
  day: day,
  sunTimes: sunTimes,
  onDayStatusChanged: onDayStatusChanged,
  onCrewNoteChanged: onCrewNoteChanged,
  onWeatherNoteChanged: onWeatherNoteChanged,
);

void main() {
  testWidgets("shows the selected day's own date, status and PAT-to-end read-outs", (
    tester,
  ) async {
    final day = _buildDay(status: OcptShootingDayStatus.shot);
    await _pumpDayInspector(tester, day: day, onDayStatusChanged: (_) {});

    final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
    expect(find.text(tr.scheduleInspectorDayTitle("D3")), findsOneWidget);
    expect(find.text(tr.scheduleDayStatusShot), findsOneWidget);
    // No slot at all: PAT → end reads as an em dash rather than crashing.
    expect(find.text("—"), findsWidgets);
  });

  testWidgets("a day with no sun times shows the hint rather than crashing", (tester) async {
    // The helper defaults `sunTimes` to null: no coordinates on the day's first location, so
    // nothing was computed.
    await _pumpDayInspector(tester, day: _buildDay(), onDayStatusChanged: (_) {});

    final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
    expect(find.text(tr.scheduleInspectorNoSunTimes), findsOneWidget);
    expect(find.textContaining("null"), findsNothing);
  });

  testWidgets(
    "a day whose sun times hold null figures never prints the word 'null', an em dash instead",
    (tester) async {
      const sunTimesWithNoFigures = OcptSunTimes(
        sunriseMinute: null,
        sunsetMinute: null,
        civilDawnMinute: null,
        civilDuskMinute: null,
        nauticalDawnMinute: null,
        nauticalDuskMinute: null,
        astronomicalDawnMinute: null,
        astronomicalDuskMinute: null,
        utcOffsetUsed: Duration(hours: 2),
      );

      await _pumpDayInspector(
        tester,
        day: _buildDay(),
        sunTimes: sunTimesWithNoFigures,
        onDayStatusChanged: (_) {},
      );

      final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
      expect(
        find.text(tr.scheduleInspectorSunTimesLine("—", "—", "—", "—", "UTC+2")),
        findsOneWidget,
      );
      expect(find.textContaining("null"), findsNothing);
    },
  );

  testWidgets("the status control and note fields write immediately when picked or typed", (
    tester,
  ) async {
    OcptShootingDayStatus? pickedStatus;
    final crewNoteEdits = <String>[];

    await _pumpDayInspector(
      tester,
      day: _buildDay(),
      onDayStatusChanged: (status) => pickedStatus = status,
      onCrewNoteChanged: crewNoteEdits.add,
      onWeatherNoteChanged: (_) {},
    );

    final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
    await tester.tap(find.text(tr.scheduleDayStatusPlanned));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.scheduleDayStatusShot).last);
    await tester.pumpAndSettle();
    expect(pickedStatus, OcptShootingDayStatus.shot);

    // The weather field comes first in the inspector, the crew note second: both are plain
    // `TextField`s, so the crew note is the last of the two.
    await tester.enterText(find.byType(TextField).last, "Rain expected");
    expect(crewNoteEdits, ["Rain expected"]);
  });

  testWidgets("every writing affordance is withheld when the mode is read-only", (tester) async {
    // Every callback left at the helper's own default, which is null: read-only is expressed as
    // "no callback, no affordance", so handing none of them is exactly what the mode does while a
    // version is being previewed.
    await _pumpDayInspector(tester, day: _buildDay(crewNote: "Bring umbrellas"));

    final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
    // The status reads as plain text, no drop-down affordance.
    expect(find.byType(PopupMenuButton<OcptShootingDayStatus>), findsNothing);
    expect(find.text(tr.scheduleDayStatusPlanned), findsOneWidget);
    // The crew note reads as plain selectable text, not an editable field.
    expect(find.byType(TextField), findsNothing);
    expect(find.text("Bring umbrellas"), findsOneWidget);
  });

  group("the shot read-out", () {
    testWidgets("shows the code/size, sequence, duration and status, with no placement yet", (
      tester,
    ) async {
      final shot = _buildShot(estimatedDurationMs: 90000);

      await _pumpInspector(
        tester,
        shot: shot,
        shotSequenceLabel: "SEQ 4A INT. KITCHEN - DAY",
        onShotStatusChanged: (_) {},
      );

      final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
      expect(find.text("${shot.code} · ${shot.shotSize}"), findsOneWidget);
      expect(find.text("SEQ 4A INT. KITCHEN - DAY"), findsOneWidget);
      // 90000 ms formats as `01:30` (mm:ss), the very format the shot list itself accepts back.
      expect(find.text("01:30"), findsOneWidget);
      expect(find.text(tr.scheduleInspectorShotNotPlanned), findsOneWidget);
      expect(find.text(ocptShotStatusLabel(tr, shot.status)), findsOneWidget);
      // No characters section at all: an empty list, not an empty line.
      expect(find.text(tr.scheduleInspectorCharactersLabel.toUpperCase()), findsNothing);
    });

    testWidgets("shows the characters line when the shot has any", (tester) async {
      final shot = _buildShot(characters: const ["LÉA", "MARC"]);

      await _pumpInspector(tester, shot: shot, shotSequenceLabel: "SEQ 1", onShotStatusChanged: (_) {});

      final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
      expect(find.text(tr.scheduleInspectorCharactersLabel.toUpperCase()), findsOneWidget);
      expect(find.text("LÉA, MARC"), findsOneWidget);
    });

    testWidgets("reads out the day tags the shot is currently placed on", (tester) async {
      final shot = _buildShot();

      await _pumpInspector(
        tester,
        shot: shot,
        shotSequenceLabel: "SEQ 1",
        shotPlacedDayNumbers: const [2, 5],
        onShotStatusChanged: (_) {},
      );

      final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
      expect(find.text("D2, D5"), findsOneWidget);
      expect(find.text(tr.scheduleInspectorShotNotPlanned), findsNothing);
    });

    testWidgets("the status control writes through the same callback the block read-out uses", (
      tester,
    ) async {
      OcptShotStatus? pickedStatus;
      final shot = _buildShot();

      await _pumpInspector(
        tester,
        shot: shot,
        shotSequenceLabel: "SEQ 1",
        onShotStatusChanged: (status) => pickedStatus = status,
      );

      final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
      await tester.tap(find.text(ocptShotStatusLabel(tr, OcptShotStatus.toShoot)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ocptShotStatusLabel(tr, OcptShotStatus.shot)).last);
      await tester.pumpAndSettle();

      expect(pickedStatus, OcptShotStatus.shot);
    });

    testWidgets("is read-only when the status callback is withheld", (tester) async {
      await _pumpInspector(tester, shot: _buildShot(), shotSequenceLabel: "SEQ 1");

      expect(find.byType(PopupMenuButton<OcptShotStatus>), findsNothing);
    });
  });

  group("the block read-out's own duration field", () {
    const entry = OcptShootingTimelineEntry(
      blockId: "block-1",
      startMinute: 480,
      endMinute: 510,
      durationMinutes: 30,
    );

    testWidgets("shows the block's own resolved duration", (tester) async {
      await _pumpInspector(
        tester,
        block: _buildHoldBlock(),
        blockEntry: entry,
        onBlockDurationChanged: (_) {},
      );

      expect(find.text("30"), findsOneWidget);
    });

    testWidgets("submitting a new figure reports it, 12 included", (tester) async {
      int? reported;

      await _pumpInspector(
        tester,
        block: _buildHoldBlock(),
        blockEntry: entry,
        onBlockDurationChanged: (durationMinutes) => reported = durationMinutes,
      );

      await tester.enterText(find.byType(TextField).first, "12");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(reported, 12);
    });

    testWidgets("reads as plain text with no field when the mode is read-only", (tester) async {
      await _pumpInspector(tester, block: _buildHoldBlock(), blockEntry: entry);

      expect(find.byType(TextField), findsNothing);
      expect(find.text(ocptFormatMinuteDuration(30)), findsOneWidget);
    });
  });

  group("the inspector's three-way precedence", () {
    testWidgets("a selected block wins over a selected shot", (tester) async {
      await _pumpInspector(
        tester,
        block: _buildHoldBlock(label: "Camera reset"),
        shot: _buildShot(),
        shotSequenceLabel: "SEQ 1",
      );

      final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
      // The block read-out's own label section, absent from the shot read-out.
      expect(find.text(tr.scheduleInspectorLabelLabel.toUpperCase()), findsOneWidget);
      expect(find.text("Camera reset"), findsOneWidget);
      // The shot read-out's own sequence section never shows: the block won.
      expect(find.text(tr.scheduleInspectorSequenceLabel.toUpperCase()), findsNothing);
    });

    testWidgets("a selected shot wins over the selected day", (tester) async {
      await _pumpInspector(
        tester,
        day: _buildDay(status: OcptShootingDayStatus.shot),
        shot: _buildShot(),
        shotSequenceLabel: "SEQ 1",
      );

      final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
      // The shot read-out's own sequence section shows.
      expect(find.text(tr.scheduleInspectorSequenceLabel.toUpperCase()), findsOneWidget);
      // The day read-out's own status section never shows: the shot won.
      expect(find.text(tr.scheduleInspectorStatusLabel.toUpperCase()), findsNothing);
    });

    testWidgets("with neither a block nor a shot selected, the day's own read-out shows", (
      tester,
    ) async {
      await _pumpInspector(tester, day: _buildDay(status: OcptShootingDayStatus.shot));

      final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
      expect(find.text(tr.scheduleInspectorStatusLabel.toUpperCase()), findsOneWidget);
    });
  });
}
