// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the day view's own scroll area.
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

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required String id,
  OcptShootingBlockKind kind = OcptShootingBlockKind.preparation,
  String? shotId,
  int? anchorMinute,
  String label = "",
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: "slot-1",
  kind: kind,
  shotId: shotId,
  label: label,
  durationMinutes: null,
  anchorMinute: anchorMinute,
  notes: "",
);

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({required String id, required String code, OcptShotStatus status = OcptShotStatus.toShoot}) =>
    OcptShot(
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
      status: status,
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
  testWidgets("a block's computed start time is shown from the timeline", (tester) async {
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal, label: "Lunch");
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      dayEndMinute: 510,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleTimetable(
          blocks: [block],
          timeline: timeline,
          shotOf: (_) => null,
          selectedBlockId: null,
          onBlockSelected: (_) {},
          onReordered: null,
          onDurationChanged: null,
          onAnchorChanged: null,
          onShotStatusChanged: null,
          onDeletionRequested: null,
          onBlockAdded: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("08:00"), findsOneWidget);
    expect(find.textContaining("08:30"), findsOneWidget);
  });

  testWidgets("an over-run block is marked in the error colour", (tester) async {
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal, anchorMinute: 480);
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [OcptTimelineOverrun(blockId: "block-1", reachedMinute: 540, anchorMinute: 480)],
      dayEndMinute: 510,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleTimetable(
          blocks: [block],
          timeline: timeline,
          shotOf: (_) => null,
          selectedBlockId: null,
          onBlockSelected: (_) {},
          onReordered: null,
          onDurationChanged: null,
          onAnchorChanged: null,
          onShotStatusChanged: null,
          onDeletionRequested: null,
          onBlockAdded: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(OcptScheduleTimetable)));
    final timeText = tester.widget<Text>(find.textContaining("08:00 →"));
    expect(timeText.style?.color, theme.colorScheme.error);
  });

  testWidgets("the ± controls dispatch a new duration", (tester) async {
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      dayEndMinute: 510,
    );
    final durations = <(String, int)>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleTimetable(
          blocks: [block],
          timeline: timeline,
          shotOf: (_) => null,
          selectedBlockId: null,
          onBlockSelected: (_) {},
          onReordered: null,
          onDurationChanged: (blockId, duration) => durations.add((blockId, duration)),
          onAnchorChanged: null,
          onShotStatusChanged: null,
          onDeletionRequested: null,
          onBlockAdded: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    expect(durations, [("block-1", 35), ("block-1", 25)]);
  });

  testWidgets("a drag-to-reorder gesture dispatches the reorder event", (tester) async {
    final blockA = _buildBlock(id: "block-a", label: "Prep");
    final blockB = _buildBlock(id: "block-b", kind: OcptShootingBlockKind.meal, label: "Lunch");
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-a", startMinute: 480, endMinute: 510, durationMinutes: 30),
        OcptShootingTimelineEntry(blockId: "block-b", startMinute: 510, endMinute: 540, durationMinutes: 30),
      ],
      overruns: [],
      dayEndMinute: 540,
    );
    final reordered = <(String, int)>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleTimetable(
          blocks: [blockA, blockB],
          timeline: timeline,
          shotOf: (_) => null,
          selectedBlockId: null,
          onBlockSelected: (_) {},
          onReordered: (blockId, newPosition) => reordered.add((blockId, newPosition)),
          onDurationChanged: null,
          onAnchorChanged: null,
          onShotStatusChanged: null,
          onDeletionRequested: null,
          onBlockAdded: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A `ReorderableListView` is used once reordering is allowed, and its own `onReorderItem` is
    // what the drag gesture ultimately calls — invoking it directly is how the wiring is exercised
    // without simulating drag physics, mirroring how a drop is reported.
    final reorderable = tester.widget<ReorderableListView>(find.byType(ReorderableListView));
    reorderable.onReorderItem!(1, 0);

    expect(reordered, [("block-b", 0)]);
  });

  testWidgets("the shot status control dispatches the status just picked", (tester) async {
    final shot = _buildShot(id: "shot-1", code: "4/1");
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.shot, shotId: "shot-1");
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      dayEndMinute: 510,
    );
    OcptShotStatus? pickedStatus;
    String? pickedShotId;

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleTimetable(
          blocks: [block],
          timeline: timeline,
          shotOf: (id) => id == "shot-1" ? shot : null,
          selectedBlockId: null,
          onBlockSelected: (_) {},
          onReordered: null,
          onDurationChanged: null,
          onAnchorChanged: null,
          onShotStatusChanged: (shotId, status) {
            pickedShotId = shotId;
            pickedStatus = status;
          },
          onDeletionRequested: null,
          onBlockAdded: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    await tester.tap(find.text(tr.shotListStatusToShoot));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.shotListStatusShot).last);
    await tester.pumpAndSettle();

    expect(pickedShotId, "shot-1");
    expect(pickedStatus, OcptShotStatus.shot);
  });

  testWidgets("every writing affordance is withheld when the mode is read-only", (tester) async {
    final shot = _buildShot(id: "shot-1", code: "4/1");
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.shot, shotId: "shot-1");
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      dayEndMinute: 510,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleTimetable(
          blocks: [block],
          timeline: timeline,
          shotOf: (id) => id == "shot-1" ? shot : null,
          selectedBlockId: null,
          onBlockSelected: (_) {},
          onReordered: null,
          onDurationChanged: null,
          onAnchorChanged: null,
          onShotStatusChanged: null,
          onDeletionRequested: null,
          onBlockAdded: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No reorder handle, no ± controls, no anchor pin, no delete control, no `+ Block` footer, and
    // the status reads as plain text rather than a drop-down.
    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(PopupMenuButton<OcptShotStatus>), findsNothing);
    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    expect(find.text(tr.shotListStatusToShoot), findsOneWidget);
  });

  testWidgets("a pinned block's anchor can be retyped to the minute it exists for", (tester) async {
    // The meal break was pinned wherever the chain had reached; the legal start is 13:00.
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal, anchorMinute: 745);
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 745, endMinute: 790, durationMinutes: 45),
      ],
      overruns: [],
      dayEndMinute: 790,
    );
    final anchors = <int?>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleTimetable(
          blocks: [block],
          timeline: timeline,
          shotOf: (_) => null,
          selectedBlockId: null,
          onBlockSelected: (_) {},
          onReordered: null,
          onDurationChanged: null,
          onAnchorChanged: (_, anchorMinute) => anchors.add(anchorMinute),
          onShotStatusChanged: null,
          onDeletionRequested: null,
          onBlockAdded: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), "13:00");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(anchors, [780]);
  });

  testWidgets("an unpinned block offers no anchor field, only the pin", (tester) async {
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 525, durationMinutes: 45),
      ],
      overruns: [],
      dayEndMinute: 525,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleTimetable(
          blocks: [block],
          timeline: timeline,
          shotOf: (_) => null,
          selectedBlockId: null,
          onBlockSelected: (_) {},
          onReordered: null,
          onDurationChanged: null,
          onAnchorChanged: (_, _) {},
          onShotStatusChanged: null,
          onDeletionRequested: null,
          onBlockAdded: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });
}
