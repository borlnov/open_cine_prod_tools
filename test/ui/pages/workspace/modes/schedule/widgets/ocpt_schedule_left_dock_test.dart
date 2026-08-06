// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock.dart';

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
  screenplayId: "screenplay-1",
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
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: (_) {},
          unplacedGroups: const [],
          selectedShotId: null,
          onShotSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The printed rank is a read-time value (`dayNumber`), never a stored column.
    expect(find.text("J1"), findsOneWidget);
    expect(find.text("J3"), findsOneWidget);
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
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: (_) {},
          unplacedGroups: [unplacedGroup],
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
          onDaySelected: (_) {},
          onDayCreated: (_) {},
          onDayDuplicationRequested: (_, _) {},
          onDayDeletionRequested: deletionRequests.add,
          unplacedGroups: const [],
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
    expect(find.text("J1"), findsOneWidget);
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
            onDaySelected: (_) {},
            onDayCreated: null,
            onDayDuplicationRequested: null,
            onDayDeletionRequested: null,
            unplacedGroups: [unplacedGroup],
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
}
