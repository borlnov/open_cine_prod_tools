// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_alert_badge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_episode_band.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the `OcptWorkspaceDock` the panel fills in the app.
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
  required String id,
  required int dayNumber,
  OcptShootingDayStatus status = OcptShootingDayStatus.planned,
}) => OcptShootingDay(
  id: id,
  date: DateTime(2026, 8, 4),
  dayNumber: dayNumber,
  status: status,
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

void main() {
  final dayOne = _buildDay(id: "day-1", dayNumber: 1);
  final dayThree = _buildDay(id: "day-3", dayNumber: 3, status: OcptShootingDayStatus.shot);

  final unplacedGroup = OcptScheduleUnplacedGroup(
    screenplayId: "screenplay-1",
    sequenceId: "scene-1",
    displaySceneNumber: "4",
    heading: "INT. KITCHEN - DAY",
    shots: [_buildShot(id: "shot-1", code: "4/1")],
  );

  testWidgets("lists every day with its own printed rank", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeftDock(
          days: [dayOne, dayThree],
          selectedDayId: null,
          blockCountByDayId: const {},
          firstLocationByDayId: const {},
          alertsOfDay: (dayId) => const [],
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDateChangeRequested: (_, _) {},
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: (_) {},
          unplacedGroups: const [],
          episodes: const [],
          selectedShotId: null,
          onShotSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The printed rank is a read-time value (`dayNumber`), never a stored column.
    expect(find.text("D1"), findsOneWidget);
    expect(find.text("D3"), findsOneWidget);
  });

  testWidgets("only the days the plan raises something about wear the alert mark", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeftDock(
          days: [dayOne, dayThree],
          selectedDayId: null,
          blockCountByDayId: const {},
          firstLocationByDayId: const {},
          alertsOfDay: (dayId) => dayId == dayThree.id
              ? const [
                  OcptScheduleTimelineOverrunAlert(
                    dayId: "day-3",
                    blockId: "block-1",
                    reachedMinute: 600,
                    anchorMinute: 550,
                  ),
                ]
              : const [],
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDateChangeRequested: (_, _) {},
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: (_) {},
          unplacedGroups: const [],
          episodes: const [],
          selectedShotId: null,
          onShotSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OcptScheduleDayAlertBadge), findsNWidgets(2));
    // Both cards carry the widget; only the day raising something draws a mark at all.
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets("clicking an unplaced shot reports its own selection", (tester) async {
    final selected = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeftDock(
          days: const [],
          selectedDayId: null,
          blockCountByDayId: const {},
          firstLocationByDayId: const {},
          alertsOfDay: (dayId) => const [],
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDateChangeRequested: (_, _) {},
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: (_) {},
          unplacedGroups: [unplacedGroup],
          episodes: const [],
          selectedShotId: null,
          onShotSelected: selected.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("4/1"));
    await tester.pump();

    expect(selected, ["shot-1"]);
  });

  testWidgets("the day card's ⋮ menu asks through a callback rather than acting on its own", (
    tester,
  ) async {
    final deletionRequests = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeftDock(
          days: [dayOne],
          selectedDayId: null,
          blockCountByDayId: const {},
          firstLocationByDayId: const {},
          alertsOfDay: (dayId) => const [],
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDateChangeRequested: (_, _) {},
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: deletionRequests.add,
          unplacedGroups: const [],
          episodes: const [],
          selectedShotId: null,
          onShotSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleLeftDock)));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.scheduleDeleteDayAction));
    await tester.pumpAndSettle();

    // The widget itself never deletes anything nor shows a confirmation dialog: it only reports
    // the click, which the mode answers with `OcptConfirmDialog`.
    expect(deletionRequests, ["day-1"]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text("D1"), findsOneWidget);
  });

  testWidgets("the day card's ⋮ menu offers to change the date, first in the menu", (
    tester,
  ) async {
    final dateChangeRequests = <(String, DateTime)>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeftDock(
          days: [dayOne],
          selectedDayId: null,
          blockCountByDayId: const {},
          firstLocationByDayId: const {},
          alertsOfDay: (dayId) => const [],
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDateChangeRequested: (dayId, date) => dateChangeRequests.add((dayId, date)),
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: (_) {},
          unplacedGroups: const [],
          episodes: const [],
          selectedShotId: null,
          onShotSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleLeftDock)));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // First in the menu, ahead of duplication and deletion: a correction is not a destructive
    // action, and the two must not sit next to each other by accident.
    final menuItems = tester.widgetList<PopupMenuItem<VoidCallback>>(
      find.byType(PopupMenuItem<VoidCallback>),
    );
    final firstLabel = (menuItems.first.child! as Text).data;
    expect(firstLabel, tr.scheduleChangeDayDateAction);

    await tester.tap(find.text(tr.scheduleChangeDayDateAction));
    await tester.pumpAndSettle();

    // The date picker opens seeded on the day's own date, `dayOne`'s 4 August 2026, rather than
    // today's.
    await tester.tap(find.text("OK"));
    await tester.pumpAndSettle();

    expect(dateChangeRequests, isNotEmpty);
    expect(dateChangeRequests.single.$1, "day-1");
    expect(dateChangeRequests.single.$2, DateTime(2026, 8, 4));
  });

  testWidgets("the day card's ⋮ menu withholds the date-change entry when the callback is null", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeftDock(
          days: [dayOne],
          selectedDayId: null,
          blockCountByDayId: const {},
          firstLocationByDayId: const {},
          alertsOfDay: (dayId) => const [],
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDateChangeRequested: null,
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: (_) {},
          unplacedGroups: const [],
          episodes: const [],
          selectedShotId: null,
          onShotSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleLeftDock)));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text(tr.scheduleChangeDayDateAction), findsNothing);
    // The menu still opens for its other entries: withholding one entry doesn't hide the ⋮
    // control itself, since duplication and deletion remain wired.
    expect(find.text(tr.scheduleDuplicateDayAction), findsOneWidget);
  });

  testWidgets(
    "every writing affordance is withheld when read-only, but selecting a shot never is",
    (tester) async {
      final selected = <String>[];

      await tester.pumpWidget(
        _wrapInApp(
          OcptScheduleLeftDock(
            days: [dayOne],
            selectedDayId: null,
            blockCountByDayId: const {},
            firstLocationByDayId: const {},
            alertsOfDay: (dayId) => const [],
            onDaySelected: (_) {},
            onDayCreated: null,
            onDayDateChangeRequested: null,
            onDayDuplicationRequested: null,
            onDayDeletionRequested: null,
            unplacedGroups: [unplacedGroup],
            episodes: const [],
            selectedShotId: null,
            onShotSelected: selected.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No "+ New day" control and no "⋮" menu: nothing here can start a write.
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      // Selecting a shot only ever reads, so it is never withheld: the row's own `InkWell.onTap`
      // still reports the click even while every writing affordance above is null.
      final inkWell = tester.widget<InkWell>(
        find.ancestor(of: find.text("4/1"), matching: find.byType(InkWell)).first,
      );
      expect(inkWell.onTap, isNotNull);

      await tester.tap(find.text("4/1"));
      await tester.pump();
      expect(selected, ["shot-1"]);
    },
  );

  testWidgets("a single-episode project draws no episode band at all", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleLeftDock(
          days: const [],
          selectedDayId: null,
          blockCountByDayId: const {},
          firstLocationByDayId: const {},
          alertsOfDay: (dayId) => const [],
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDateChangeRequested: (_, _) {},
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: (_) {},
          unplacedGroups: [unplacedGroup],
          episodes: const [OcptEpisode(id: "screenplay-1", number: 1, title: "")],
          selectedShotId: null,
          onShotSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A single-episode project names no episode anywhere (ADR 0019): the sequence section reads
    // exactly as it always has, with no band drawn over it.
    expect(find.byType(OcptScheduleEpisodeBand), findsNothing);
    expect(find.text("Episode 1"), findsNothing);
    expect(find.text("INT. KITCHEN - DAY"), findsOneWidget);
  });

  testWidgets(
    "a two-episode project bands each episode's own sections, in episode order, and draws no "
    "band for an episode with nothing left to place",
    (tester) async {
      final episodeOneGroup = OcptScheduleUnplacedGroup(
        screenplayId: "screenplay-1",
        sequenceId: "scene-1",
        displaySceneNumber: "4",
        heading: "INT. KITCHEN - DAY",
        shots: [_buildShot(id: "shot-1", code: "4/1")],
      );
      final episodeThreeGroup = OcptScheduleUnplacedGroup(
        screenplayId: "screenplay-3",
        sequenceId: "scene-3",
        displaySceneNumber: "7",
        heading: "EXT. STREET - NIGHT",
        shots: [_buildShot(id: "shot-2", code: "7/1")],
      );

      await tester.pumpWidget(
        _wrapInApp(
          OcptScheduleLeftDock(
            days: const [],
            selectedDayId: null,
            blockCountByDayId: const {},
            firstLocationByDayId: const {},
            alertsOfDay: (dayId) => const [],
            onDaySelected: (_) {},
            onDayCreated: (_) {},
            onDayDateChangeRequested: (_, _) {},
            onDayDuplicationRequested: (_, _) {},
            onDayDeletionRequested: (_) {},
            // Episode 2 has nothing left to place: it is a live episode ([episodes] below still
            // names it) but contributes no group, so it must draw no band of its own.
            unplacedGroups: [episodeOneGroup, episodeThreeGroup],
            episodes: const [
              OcptEpisode(id: "screenplay-1", number: 1, title: ""),
              OcptEpisode(id: "screenplay-2", number: 2, title: ""),
              OcptEpisode(id: "screenplay-3", number: 3, title: ""),
            ],
            selectedShotId: null,
            onShotSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OcptScheduleEpisodeBand), findsNWidgets(2));
      expect(find.text("Episode 1"), findsOneWidget);
      expect(find.text("Episode 2"), findsNothing);
      expect(find.text("Episode 3"), findsOneWidget);

      // Episode order: episode 1's own band and section sit above episode 3's.
      final episodeOneBandY = tester.getTopLeft(find.text("Episode 1")).dy;
      final episodeOneSectionY = tester.getTopLeft(find.text("INT. KITCHEN - DAY")).dy;
      final episodeThreeBandY = tester.getTopLeft(find.text("Episode 3")).dy;
      final episodeThreeSectionY = tester.getTopLeft(find.text("EXT. STREET - NIGHT")).dy;

      expect(episodeOneBandY, lessThan(episodeOneSectionY));
      expect(episodeOneSectionY, lessThan(episodeThreeBandY));
      expect(episodeThreeBandY, lessThan(episodeThreeSectionY));
    },
  );
}
