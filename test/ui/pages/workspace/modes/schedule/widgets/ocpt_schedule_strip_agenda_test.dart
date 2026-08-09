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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_strip_agenda.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the centre column the strip agenda fills in the app.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 640, height: 700, child: child)),
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({required String id, required int dayNumber}) =>
    OcptShootingDay(
      id: id,
      date: DateTime(2026, 8, 4),
      dayNumber: dayNumber,
      status: OcptShootingDayStatus.planned,
      crewNote: "",
      weatherNote: "",
      notes: "",
    );

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({required String id, required String code}) => OcptShot(
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
  estimatedDurationMs: null,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: OcptShotStatus.toShoot,
  difficultySet: 0,
  difficultyCamera: 0,
  difficultyActing: 0,
  difficultySound: 0,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: const [],
  coverageRanges: const [],
  code: code,
  averageDifficulty: 0,
);

/// Builds a shot block placing [shotId] in slot "slot-1".
OcptShootingDayBlock _buildShotBlock({
  required String id,
  required String shotId,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: "slot-1",
  kind: OcptShootingBlockKind.shot,
  shotId: shotId,
  sceneId: null,
  label: "",
  durationMinutes: null,
  anchorMinute: null,
  notes: "",
  crewNote: "",
);

void main() {
  final dayOne = _buildDay(id: "day-1", dayNumber: 1);

  testWidgets("shows the empty hint while no shooting day exists yet", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleStripAgenda(
          days: const [],
          selectedDayId: null,
          firstLocationByDayId: const {},
          dayTintOf: (_) => Colors.transparent,
          blocksByDayId: const {},
          shotOf: (_) => null,
          timelineOf: (_) => null,
          arrivalMinuteOf: (_) => null,
          alertsOfDay: (dayId) => const [],
          onDayOpenRequested: (_) {},
          onBlockSelected: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleStripAgenda)));
    expect(find.text(tr.scheduleAgendaEmptyHint), findsOneWidget);
  });

  testWidgets(
    "draws no 'Place here' prompt at all — the strip is purely informative",
    (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          OcptScheduleStripAgenda(
            days: [dayOne],
            selectedDayId: null,
            firstLocationByDayId: const {},
            dayTintOf: (_) => Colors.transparent,
            blocksByDayId: const {},
            shotOf: (_) => null,
            timelineOf: (_) => null,
            arrivalMinuteOf: (_) => null,
            alertsOfDay: (dayId) => const [],
            onDayOpenRequested: (_) {},
            onBlockSelected: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No trace of the retired prompt anywhere, whatever the day's own state.
      expect(find.textContaining("Place here"), findsNothing);

      final tr = Tr.of(tester.element(find.byType(OcptScheduleStripAgenda)));
      // The "no shot placed" hint shows unconditionally now — it used to be withheld while a
      // *placing* was in progress, a state that no longer exists.
      expect(find.text(tr.scheduleDayNoShotsPlacedHint), findsOneWidget);
    },
  );

  testWidgets("a chip click reports the block's own id and its day's", (
    tester,
  ) async {
    final selections = <(String, String)>[];
    final shot = _buildShot(id: "shot-1", code: "4/1");
    final block = _buildShotBlock(id: "block-1", shotId: "shot-1");

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleStripAgenda(
          days: [dayOne],
          selectedDayId: null,
          firstLocationByDayId: const {},
          dayTintOf: (_) => Colors.transparent,
          blocksByDayId: {
            "day-1": [block],
          },
          shotOf: (shotId) => shotId == "shot-1" ? shot : null,
          timelineOf: (_) => null,
          arrivalMinuteOf: (_) => null,
          alertsOfDay: (dayId) => const [],
          onDayOpenRequested: (_) {},
          onBlockSelected: (blockId, dayId) => selections.add((blockId, dayId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("4/1"), findsOneWidget);
    await tester.tap(find.text("4/1"));
    await tester.pump();

    expect(selections, [("block-1", "day-1")]);
  });

  testWidgets("the card's own right column reads the day's own arrival-to-end range", (tester) async {
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [],
      overruns: [],
      fixedEndMisses: [],
      anchorCycles: [],
      dayStartMinute: null,
      dayEndMinute: 1080,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleStripAgenda(
          days: [dayOne],
          selectedDayId: null,
          firstLocationByDayId: const {},
          dayTintOf: (_) => Colors.transparent,
          blocksByDayId: const {},
          shotOf: (_) => null,
          timelineOf: (_) => timeline,
          arrivalMinuteOf: (_) => 450,
          alertsOfDay: (dayId) => const [],
          onDayOpenRequested: (_) {},
          onBlockSelected: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleStripAgenda)));
    expect(find.text(tr.scheduleDayArrivalToEndLabel), findsOneWidget);
    expect(find.text("07:30 – 18:00"), findsOneWidget);
  });

  testWidgets("the day header click reports the day's own id, requesting it be opened", (
    tester,
  ) async {
    final openedDayIds = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleStripAgenda(
          days: [dayOne],
          selectedDayId: null,
          firstLocationByDayId: const {},
          dayTintOf: (_) => Colors.transparent,
          blocksByDayId: const {},
          shotOf: (_) => null,
          timelineOf: (_) => null,
          arrivalMinuteOf: (_) => null,
          alertsOfDay: (dayId) => const [],
          onDayOpenRequested: openedDayIds.add,
          onBlockSelected: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("D1"));
    await tester.pump();

    expect(openedDayIds, ["day-1"]);
  });
}
