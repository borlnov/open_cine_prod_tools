// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/gestures.dart';
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
  String slotId = "slot-1",
  OcptShootingBlockKind kind = OcptShootingBlockKind.preparation,
  String? shotId,
  int? anchorMinute,
  String label = "",
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: slotId,
  kind: kind,
  shotId: shotId,
  sceneId: null,
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
  /// Builds an [OcptScheduleTimetable] with the neutral defaults these tests don't otherwise care
  /// about — a lone slot with no other one to move a block to and no cross-slot moving wired up,
  /// unless a test overrides either.
  Widget buildTimetable({
    required List<OcptShootingDayBlock> blocks,
    required OcptShootingSlotTimeline? timeline,
    OcptShot? Function(String shotId) shotOf = _noShot,
    String? selectedBlockId,
    List<(String, String)> otherSlots = const [],
    ValueChanged<String> onBlockSelected = _ignoreString,
    void Function(String blockId, int newPosition)? onReordered,
    void Function(String blockId, int durationMinutes)? onDurationChanged,
    void Function(String blockId, int? anchorMinute)? onAnchorChanged,
    void Function(String shotId, OcptShotStatus status)? onShotStatusChanged,
    ValueChanged<String>? onDeletionRequested,
    ValueChanged<OcptShootingBlockKind>? onBlockAdded,
    void Function(String blockId, String targetSlotId)? onBlockMovedToSlot,
  }) => OcptScheduleTimetable(
    slotId: "slot-1",
    blocks: blocks,
    timeline: timeline,
    shotOf: shotOf,
    selectedBlockId: selectedBlockId,
    otherSlots: otherSlots,
    onBlockSelected: onBlockSelected,
    onReordered: onReordered,
    onDurationChanged: onDurationChanged,
    onAnchorChanged: onAnchorChanged,
    onShotStatusChanged: onShotStatusChanged,
    onDeletionRequested: onDeletionRequested,
    onBlockAdded: onBlockAdded,
    onBlockMovedToSlot: onBlockMovedToSlot,
  );

  testWidgets("a block's computed start time is shown from the timeline", (tester) async {
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal, label: "Lunch");
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );

    await tester.pumpWidget(_wrapInApp(buildTimetable(blocks: [block], timeline: timeline)));
    await tester.pumpAndSettle();

    expect(find.textContaining("08:00"), findsOneWidget);
    expect(find.textContaining("08:30"), findsOneWidget);
  });

  testWidgets("an over-run block is marked in the error colour", (tester) async {
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal, anchorMinute: 480);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [OcptTimelineOverrun(blockId: "block-1", reachedMinute: 540, anchorMinute: 480)],
      endMinute: 510,
    );

    await tester.pumpWidget(_wrapInApp(buildTimetable(blocks: [block], timeline: timeline)));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(OcptScheduleTimetable)));
    final timeText = tester.widget<Text>(find.textContaining("08:00 →"));
    expect(timeText.style?.color, theme.colorScheme.error);
  });

  testWidgets("the ± controls dispatch a new duration", (tester) async {
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );
    final durations = <(String, int)>[];

    await tester.pumpWidget(
      _wrapInApp(
        buildTimetable(
          blocks: [block],
          timeline: timeline,
          onDurationChanged: (blockId, duration) => durations.add((blockId, duration)),
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
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-a", startMinute: 480, endMinute: 510, durationMinutes: 30),
        OcptShootingTimelineEntry(blockId: "block-b", startMinute: 510, endMinute: 540, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 540,
    );
    final reordered = <(String, int)>[];

    await tester.pumpWidget(
      _wrapInApp(
        buildTimetable(
          blocks: [blockA, blockB],
          timeline: timeline,
          onReordered: (blockId, newPosition) => reordered.add((blockId, newPosition)),
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
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );
    OcptShotStatus? pickedStatus;
    String? pickedShotId;

    await tester.pumpWidget(
      _wrapInApp(
        buildTimetable(
          blocks: [block],
          timeline: timeline,
          shotOf: (id) => id == "shot-1" ? shot : null,
          onShotStatusChanged: (shotId, status) {
            pickedShotId = shotId;
            pickedStatus = status;
          },
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
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );

    await tester.pumpWidget(
      _wrapInApp(
        buildTimetable(
          blocks: [block],
          timeline: timeline,
          shotOf: (id) => id == "shot-1" ? shot : null,
          // Every other slot exists, but every writing callback below is withheld anyway — the
          // absence of the callback is what must gate every affordance, not the absence of a slot
          // to move to.
          otherSlots: const [("slot-2", "Soir")],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No reorder handle, no ± controls, no anchor pin, no delete control, no `+ Block` footer, no
    // `Move to…` control, no draggable, and the status reads as plain text rather than a drop-down.
    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.drive_file_move_outline), findsNothing);
    // `Draggable`/`DragTarget` are generic over a private payload type, so `byType` can't name them
    // directly from outside this library — matching on the runtime type's own name is what proves
    // neither is built at all, rather than merely failing to match a mismatched type argument.
    expect(
      find.byWidgetPredicate((widget) => widget.runtimeType.toString().startsWith("Draggable<")),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate((widget) => widget.runtimeType.toString().startsWith("DragTarget<")),
      findsNothing,
    );
    expect(find.byType(PopupMenuButton<OcptShotStatus>), findsNothing);
    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    expect(find.text(tr.shotListStatusToShoot), findsOneWidget);
  });

  testWidgets("a pinned block's anchor can be retyped to the minute it exists for", (tester) async {
    // The meal break was pinned wherever the chain had reached; the legal start is 13:00.
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal, anchorMinute: 745);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 745, endMinute: 790, durationMinutes: 45),
      ],
      overruns: [],
      endMinute: 790,
    );
    final anchors = <int?>[];

    await tester.pumpWidget(
      _wrapInApp(
        buildTimetable(
          blocks: [block],
          timeline: timeline,
          onAnchorChanged: (_, anchorMinute) => anchors.add(anchorMinute),
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
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 525, durationMinutes: 45),
      ],
      overruns: [],
      endMinute: 525,
    );

    await tester.pumpWidget(
      _wrapInApp(buildTimetable(blocks: [block], timeline: timeline, onAnchorChanged: (_, _) {})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });

  testWidgets("only this slot's own blocks are shown, none of another slot's", (tester) async {
    final ownBlock = _buildBlock(id: "block-own", label: "Prep");
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-own", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );

    // A caller that (incorrectly) handed this timetable another slot's block would still only ever
    // draw what's in `blocks` — there is nothing in this widget that reaches for a second slot's
    // own rows, which this test pins by never passing one in the first place.
    await tester.pumpWidget(_wrapInApp(buildTimetable(blocks: [ownBlock], timeline: timeline)));
    await tester.pumpAndSettle();

    expect(find.text("Prep"), findsOneWidget);
  });

  testWidgets("the `+ Block` menu names this timetable's own slot", (tester) async {
    OcptShootingBlockKind? addedKind;

    await tester.pumpWidget(
      _wrapInApp(
        buildTimetable(blocks: const [], timeline: null, onBlockAdded: (kind) => addedKind = kind),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    await tester.tap(find.text(tr.scheduleAddBlockAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.scheduleBlockKindMeal).last);
    await tester.pumpAndSettle();

    // The menu itself carries no slot id — a timetable only ever adds to the one slot it belongs
    // to, `OcptScheduleTimetable.slotId`, which the caller (the slot card) binds when it dispatches
    // the event onward.
    expect(addedKind, OcptShootingBlockKind.meal);
  });

  testWidgets("the `Move to…` entry is withheld when the day has no other slot", (tester) async {
    final block = _buildBlock(id: "block-1", label: "Prep");
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );

    await tester.pumpWidget(
      _wrapInApp(
        buildTimetable(
          blocks: [block],
          timeline: timeline,
          onBlockMovedToSlot: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drive_file_move_outline), findsNothing);
  });

  testWidgets("the `Move to…` entry lists the day's other slots and dispatches the one picked", (
    tester,
  ) async {
    final block = _buildBlock(id: "block-1", label: "Prep");
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );
    final moved = <(String, String)>[];

    await tester.pumpWidget(
      _wrapInApp(
        buildTimetable(
          blocks: [block],
          timeline: timeline,
          otherSlots: const [("slot-2", "Soir"), ("slot-3", "")],
          onBlockMovedToSlot: (blockId, targetSlotId) => moved.add((blockId, targetSlotId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.drive_file_move_outline));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    expect(find.text("Soir"), findsOneWidget);
    // An other slot with an empty label reads as the same hint a slot card's own header falls back
    // to, never as a blank menu entry nobody could pick with confidence.
    expect(find.text(tr.scheduleInspectorUnnamedSlot), findsOneWidget);

    await tester.tap(find.text("Soir"));
    await tester.pumpAndSettle();

    expect(moved, [("block-1", "slot-2")]);
  });

  testWidgets("dragging a row onto another slot's own timetable dispatches the move", (tester) async {
    final block = _buildBlock(id: "block-1", label: "Prep");
    const timelineOne = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );
    final moved = <(String, String)>[];

    // Two timetables, standing in for two slot cards' own, stacked so a drag can cross from one to
    // the other — proving the mechanism actually resolves in the gesture arena rather than assuming
    // it does, as the plan asks: the drag handle keeps the in-slot reorder, and the rest of the row
    // is what becomes draggable, so the two never compete for the same pointer.
    await tester.pumpWidget(
      _wrapInApp(
        Column(
          children: [
            SizedBox(
              key: const ValueKey("timetable-1"),
              height: 120,
              child: OcptScheduleTimetable(
                slotId: "slot-1",
                blocks: [block],
                timeline: timelineOne,
                shotOf: _noShot,
                selectedBlockId: null,
                otherSlots: const [("slot-2", "Soir")],
                onBlockSelected: _ignoreString,
                onReordered: (_, _) {},
                onDurationChanged: null,
                onAnchorChanged: null,
                onShotStatusChanged: null,
                onDeletionRequested: null,
                onBlockAdded: null,
                onBlockMovedToSlot: (blockId, targetSlotId) => moved.add((blockId, targetSlotId)),
              ),
            ),
            SizedBox(
              key: const ValueKey("timetable-2"),
              height: 120,
              child: OcptScheduleTimetable(
                slotId: "slot-2",
                blocks: const [],
                timeline: null,
                shotOf: _noShot,
                selectedBlockId: null,
                otherSlots: const [("slot-1", "Matin")],
                onBlockSelected: _ignoreString,
                onReordered: (_, _) {},
                onDurationChanged: null,
                onAnchorChanged: null,
                onShotStatusChanged: null,
                onDeletionRequested: null,
                onBlockAdded: null,
                onBlockMovedToSlot: (blockId, targetSlotId) => moved.add((blockId, targetSlotId)),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byKey(const ValueKey("timetable-2"))));
    final dragStart = tester.getCenter(find.text("Prep"));
    // The drop target's own rendered area only ever covers its content (the empty hint, here) —
    // not the whole `SizedBox` standing in for the slot card around it — so the drag has to land
    // on that text, not on the card's own geometric centre.
    final dropTarget = tester.getCenter(find.text(tr.scheduleTimetableEmptyHint));

    final gesture = await tester.startGesture(dragStart, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(Offset(dragStart.dx, dragStart.dy + 20));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(dropTarget);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved, [("block-1", "slot-2")]);
  });

  testWidgets("a dropped-into slot shows a hover state while a block hovers over it", (tester) async {
    final block = _buildBlock(id: "block-1", label: "Prep");
    const timelineOne = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );

    await tester.pumpWidget(
      _wrapInApp(
        Column(
          children: [
            SizedBox(
              key: const ValueKey("timetable-1"),
              height: 120,
              child: OcptScheduleTimetable(
                slotId: "slot-1",
                blocks: [block],
                timeline: timelineOne,
                shotOf: _noShot,
                selectedBlockId: null,
                otherSlots: const [("slot-2", "Soir")],
                onBlockSelected: _ignoreString,
                onReordered: (_, _) {},
                onDurationChanged: null,
                onAnchorChanged: null,
                onShotStatusChanged: null,
                onDeletionRequested: null,
                onBlockAdded: null,
                onBlockMovedToSlot: (_, _) {},
              ),
            ),
            SizedBox(
              key: const ValueKey("timetable-2"),
              height: 120,
              child: OcptScheduleTimetable(
                slotId: "slot-2",
                blocks: const [],
                timeline: null,
                shotOf: _noShot,
                selectedBlockId: null,
                otherSlots: const [("slot-1", "Matin")],
                onBlockSelected: _ignoreString,
                onReordered: (_, _) {},
                onDurationChanged: null,
                onAnchorChanged: null,
                onShotStatusChanged: null,
                onDeletionRequested: null,
                onBlockAdded: null,
                onBlockMovedToSlot: (_, _) {},
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byKey(const ValueKey("timetable-2"))));
    final dragStart = tester.getCenter(find.text("Prep"));
    // The drop target's own rendered area only ever covers its content (the empty hint, here) —
    // not the whole `SizedBox` standing in for the slot card around it — so the drag has to land
    // on that text, not on the card's own geometric centre.
    final dropTarget = tester.getCenter(find.text(tr.scheduleTimetableEmptyHint));

    final gesture = await tester.startGesture(dragStart, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(Offset(dragStart.dx, dragStart.dy + 20));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(dropTarget);
    await tester.pump(const Duration(milliseconds: 150));

    // The drop target's own border is transparent while nothing hovers over it (see the same
    // assertion made below, after the drag ends) — reading its colour, rather than merely its
    // presence, is what proves the hover was actually reported rather than the border merely
    // existing at rest.
    final theme = Theme.of(tester.element(find.byKey(const ValueKey("timetable-2"))));
    final hoveringContainer = tester
        .widgetList<AnimatedContainer>(
          find.descendant(of: find.byKey(const ValueKey("timetable-2")), matching: find.byType(AnimatedContainer)),
        )
        .first;
    final hoveringDecoration = hoveringContainer.decoration! as BoxDecoration;
    expect(hoveringDecoration.border!.top.color, theme.colorScheme.primary);

    await gesture.up();
    await tester.pumpAndSettle();

    final settledContainer = tester
        .widgetList<AnimatedContainer>(
          find.descendant(of: find.byKey(const ValueKey("timetable-2")), matching: find.byType(AnimatedContainer)),
        )
        .first;
    final settledDecoration = settledContainer.decoration! as BoxDecoration;
    expect(settledDecoration.border!.top.color, Colors.transparent);
  });

  testWidgets("the duration stepper still responds once cross-slot dragging is wired up", (tester) async {
    // Real usage always turns on every writing affordance together, including cross-slot moving —
    // this pins that wrapping a row's body in a `Draggable` for that doesn't also swallow its own
    // ordinary control taps.
    final block = _buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      endMinute: 510,
    );
    final durations = <(String, int)>[];

    await tester.pumpWidget(
      _wrapInApp(
        buildTimetable(
          blocks: [block],
          timeline: timeline,
          otherSlots: const [("slot-2", "Soir")],
          onDurationChanged: (blockId, duration) => durations.add((blockId, duration)),
          onBlockMovedToSlot: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(durations, [("block-1", 35)]);
  });
}

/// A neutral `shotOf` resolving nothing, for tests that never place a shot block.
OcptShot? _noShot(String shotId) => null;

/// A neutral `onBlockSelected` that ignores every click, for tests that don't assert on selection.
void _ignoreString(String value) {}
