// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_block_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'ocpt_schedule_timetable_test_doubles.dart';

/// Builds the link naming candidacy [roleCandidateId] on an audition block.
OcptShootingBlockCandidate _buildBlockCandidate({
  required String id,
  required String roleCandidateId,
  String blockId = "block-1",
}) => OcptShootingBlockCandidate(
  id: id,
  blockId: blockId,
  roleCandidateId: roleCandidateId,
  notes: "",
);

/// Builds a scene sequence with the few fields these tests read, everything else neutral.
OcptSceneShotSequence _buildSequence({
  required String sceneId,
  required String displaySceneNumber,
  String heading = "INT. KITCHEN - DAY",
}) => OcptSceneShotSequence(
  sceneId: sceneId,
  heading: heading,
  sceneNumber: null,
  displaySceneNumber: displaySceneNumber,
  charStart: 0,
  charEnd: 0,
  shots: const [],
);

/// Run the tests of the schedule timetable audition rows.
void main() {
  /// Builds an [OcptScheduleTimetable] with the neutral defaults these tests don't otherwise care
  /// about — a lone slot with no other one to move a block to and no cross-slot moving wired up,
  /// unless a test overrides either.
  Widget buildTimetable({
    required List<OcptShootingDayBlock> blocks,
    required OcptShootingSlotTimeline? timeline,
    OcptShot? Function(String shotId) shotOf = noShot,
    String? selectedBlockId,
    List<OcptSceneShotSequence> sequences = const [],
    List<(String, String)> otherSlots = const [],
    ValueChanged<String> onBlockSelected = ignoreString,
    void Function(String blockId, int newPosition)? onReordered,
    void Function(String blockId, int durationMinutes)? onDurationChanged,
    void Function(String blockId, int? anchorMinute)? onAnchorChanged,
    void Function(String shotId, OcptShotStatus status)? onShotStatusChanged,
    void Function(String blockId, String? sceneId)? onHoldSequenceChanged,
    ValueChanged<String>? onDeletionRequested,
    ValueChanged<OcptShootingBlockKind>? onBlockAdded,
    VoidCallback? onShotBlockRequested,
    void Function(String blockId, String roleCandidateId)? onCandidateAdded,
    ValueChanged<String>? onCandidateRemoved,
    Map<String, OcptRoleCandidate> roleCandidateById = const {},
    List<OcptRole> roles = const [],
    void Function(String blockId, String targetSlotId)? onBlockMovedToSlot,
  }) => OcptScheduleTimetable(
    slotId: "slot-1",
    blocks: blocks,
    timeline: timeline,
    shotOf: shotOf,
    selectedBlockId: selectedBlockId,
    sequences: sequences,
    otherSlots: otherSlots,
    onBlockSelected: onBlockSelected,
    onReordered: onReordered,
    onDurationChanged: onDurationChanged,
    onAnchorChanged: onAnchorChanged,
    onShotStatusChanged: onShotStatusChanged,
    onHoldSequenceChanged: onHoldSequenceChanged,
    onDeletionRequested: onDeletionRequested,
    onBlockAdded: onBlockAdded,
    onShotBlockRequested: onShotBlockRequested,
    onBlockMovedToSlot: onBlockMovedToSlot,
    onCandidateAdded: onCandidateAdded,
    onCandidateRemoved: onCandidateRemoved,
    roleCandidateById: roleCandidateById,
    roles: roles,
  );

  testWidgets("an audition row draws one chip per candidacy, each with its own remove control", (
    tester,
  ) async {
    final audition = buildBlock(
      id: "block-1",
      kind: OcptShootingBlockKind.audition,
      candidates: [
        _buildBlockCandidate(id: "link-1", roleCandidateId: "candidacy-1"),
        _buildBlockCandidate(id: "link-2", roleCandidateId: "candidacy-2"),
      ],
    );
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 540,
          endMinute: 580,
          durationMinutes: 40,
        ),
      ],
      overruns: [],
      startMinute: 540,
      endMinute: 580,
    );
    final removed = <String>[];

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: [audition],
          timeline: timeline,
          roles: [
            buildRole(id: "role-1", name: "MARIE"),
            buildRole(id: "role-2", name: "JULIEN"),
          ],
          roleCandidateById: {
            "candidacy-1": buildCandidacy(
              id: "candidacy-1",
              roleId: "role-1",
              firstName: "Camille",
            ),
            "candidacy-2": buildCandidacy(id: "candidacy-2", roleId: "role-2", firstName: "Alice"),
          },
          onCandidateRemoved: removed.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    // Two actors of two different parts read together: each chip says who, and for which part.
    expect(find.text(tr.scheduleAuditionBlockLabel("Camille", "MARIE")), findsOneWidget);
    expect(find.text(tr.scheduleAuditionBlockLabel("Alice", "JULIEN")), findsOneWidget);

    await tester.tap(find.byTooltip(tr.scheduleRemoveAuditionCandidateTooltip).first);
    await tester.pumpAndSettle();

    expect(removed, ["link-1"]);
  });

  testWidgets("a chip onto a candidacy the project no longer holds is left out", (tester) async {
    final audition = buildBlock(
      id: "block-1",
      kind: OcptShootingBlockKind.audition,
      candidates: [_buildBlockCandidate(id: "link-1", roleCandidateId: "gone")],
    );
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 540,
          endMinute: 560,
          durationMinutes: 20,
        ),
      ],
      overruns: [],
      startMinute: 540,
      endMinute: 560,
    );

    await tester.pumpWidget(wrapInApp(buildTimetable(blocks: [audition], timeline: timeline)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    expect(find.text(tr.scheduleAuditionNoCandidateHint), findsOneWidget);
  });

  testWidgets("no other kind of row draws the candidacy strip at all", (tester) async {
    final meal = buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 560,
          endMinute: 620,
          durationMinutes: 60,
        ),
      ],
      overruns: [],
      startMinute: 560,
      endMinute: 620,
    );

    await tester.pumpWidget(
      wrapInApp(buildTimetable(blocks: [meal], timeline: timeline, onCandidateAdded: (_, _) {})),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    expect(find.text(tr.scheduleAuditionNoCandidateHint), findsNothing);
    expect(find.text(tr.scheduleAddAuditionCandidateAction), findsNothing);
  });

  testWidgets("the chips' controls are withheld under a read-only preview", (tester) async {
    final audition = buildBlock(
      id: "block-1",
      kind: OcptShootingBlockKind.audition,
      candidates: [_buildBlockCandidate(id: "link-1", roleCandidateId: "candidacy-1")],
    );
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 540,
          endMinute: 560,
          durationMinutes: 20,
        ),
      ],
      overruns: [],
      startMinute: 540,
      endMinute: 560,
    );

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: [audition],
          timeline: timeline,
          roles: [buildRole(id: "role-1", name: "MARIE")],
          roleCandidateById: {
            "candidacy-1": buildCandidacy(
              id: "candidacy-1",
              roleId: "role-1",
              firstName: "Camille",
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    // The chip itself still reads — a stored convocation is never hidden, only the affordances
    // that would change something.
    expect(find.text(tr.scheduleAuditionBlockLabel("Camille", "MARIE")), findsOneWidget);
    expect(find.byTooltip(tr.scheduleRemoveAuditionCandidateTooltip), findsNothing);
    expect(find.text(tr.scheduleAddAuditionCandidateAction), findsNothing);
  });

  testWidgets("a rehearsal row carries the sequence picker a hold row does", (tester) async {
    final rehearsal = buildBlock(id: "block-1", kind: OcptShootingBlockKind.rehearsal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 570,
          durationMinutes: 90,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 570,
    );
    final sequence = _buildSequence(sceneId: "scene-1", displaySceneNumber: "4A");

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: [rehearsal],
          timeline: timeline,
          sequences: [sequence],
          onHoldSequenceChanged: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });

  testWidgets("the `Move to…` entry is withheld when the day has no other slot", (tester) async {
    final block = buildBlock(id: "block-1", label: "Prep");
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 510,
    );

    await tester.pumpWidget(
      wrapInApp(buildTimetable(blocks: [block], timeline: timeline, onBlockMovedToSlot: (_, _) {})),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drive_file_move_outline), findsNothing);
  });

  testWidgets("the `Move to…` entry lists the day's other slots and dispatches the one picked", (
    tester,
  ) async {
    final block = buildBlock(id: "block-1", label: "Prep");
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 510,
    );
    final moved = <(String, String)>[];

    await tester.pumpWidget(
      wrapInApp(
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

  testWidgets("dragging a row onto another slot's own timetable dispatches the move", (
    tester,
  ) async {
    final block = buildBlock(id: "block-1", label: "Prep");
    const timelineOne = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 510,
    );
    final moved = <(String, String)>[];

    // Two timetables, standing in for two slot cards' own, stacked so a drag can cross from one to
    // the other — proving the mechanism actually resolves in the gesture arena rather than assuming
    // it does, as designed: the drag handle keeps the in-slot reorder, and the rest of the row
    // is what becomes draggable, so the two never compete for the same pointer.
    await tester.pumpWidget(
      wrapInApp(
        Column(
          children: [
            SizedBox(
              key: const ValueKey("timetable-1"),
              height: 120,
              child: OcptScheduleTimetable(
                slotId: "slot-1",
                blocks: [block],
                timeline: timelineOne,
                shotOf: noShot,
                selectedBlockId: null,
                sequences: const [],
                otherSlots: const [("slot-2", "Soir")],
                onBlockSelected: ignoreString,
                onReordered: (_, _) {},
                onDurationChanged: null,
                onAnchorChanged: null,
                onShotStatusChanged: null,
                onHoldSequenceChanged: null,
                onDeletionRequested: null,
                onBlockAdded: null,
                onShotBlockRequested: null,
                onBlockMovedToSlot: (blockId, targetSlotId) => moved.add((blockId, targetSlotId)),
                onCandidateAdded: null,
                onCandidateRemoved: null,
                roleCandidateById: const {},
                roles: const [],
              ),
            ),
            SizedBox(
              key: const ValueKey("timetable-2"),
              height: 120,
              child: OcptScheduleTimetable(
                slotId: "slot-2",
                blocks: const [],
                timeline: null,
                shotOf: noShot,
                selectedBlockId: null,
                sequences: const [],
                otherSlots: const [("slot-1", "Matin")],
                onBlockSelected: ignoreString,
                onReordered: (_, _) {},
                onDurationChanged: null,
                onAnchorChanged: null,
                onShotStatusChanged: null,
                onHoldSequenceChanged: null,
                onDeletionRequested: null,
                onBlockAdded: null,
                onShotBlockRequested: null,
                onBlockMovedToSlot: (blockId, targetSlotId) => moved.add((blockId, targetSlotId)),
                onCandidateAdded: null,
                onCandidateRemoved: null,
                roleCandidateById: const {},
                roles: const [],
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

  testWidgets("a dropped-into slot shows a hover state while a block hovers over it", (
    tester,
  ) async {
    final block = buildBlock(id: "block-1", label: "Prep");
    const timelineOne = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 510,
    );

    await tester.pumpWidget(
      wrapInApp(
        Column(
          children: [
            SizedBox(
              key: const ValueKey("timetable-1"),
              height: 120,
              child: OcptScheduleTimetable(
                slotId: "slot-1",
                blocks: [block],
                timeline: timelineOne,
                shotOf: noShot,
                selectedBlockId: null,
                sequences: const [],
                otherSlots: const [("slot-2", "Soir")],
                onBlockSelected: ignoreString,
                onReordered: (_, _) {},
                onDurationChanged: null,
                onAnchorChanged: null,
                onShotStatusChanged: null,
                onHoldSequenceChanged: null,
                onDeletionRequested: null,
                onBlockAdded: null,
                onShotBlockRequested: null,
                onBlockMovedToSlot: (_, _) {},
                onCandidateAdded: null,
                onCandidateRemoved: null,
                roleCandidateById: const {},
                roles: const [],
              ),
            ),
            SizedBox(
              key: const ValueKey("timetable-2"),
              height: 120,
              child: OcptScheduleTimetable(
                slotId: "slot-2",
                blocks: const [],
                timeline: null,
                shotOf: noShot,
                selectedBlockId: null,
                sequences: const [],
                otherSlots: const [("slot-1", "Matin")],
                onBlockSelected: ignoreString,
                onReordered: (_, _) {},
                onDurationChanged: null,
                onAnchorChanged: null,
                onShotStatusChanged: null,
                onHoldSequenceChanged: null,
                onDeletionRequested: null,
                onBlockAdded: null,
                onShotBlockRequested: null,
                onBlockMovedToSlot: (_, _) {},
                onCandidateAdded: null,
                onCandidateRemoved: null,
                roleCandidateById: const {},
                roles: const [],
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
          find.descendant(
            of: find.byKey(const ValueKey("timetable-2")),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .first;
    final hoveringDecoration = hoveringContainer.decoration! as BoxDecoration;
    expect(hoveringDecoration.border!.top.color, theme.colorScheme.primary);

    await gesture.up();
    await tester.pumpAndSettle();

    final settledContainer = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: find.byKey(const ValueKey("timetable-2")),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .first;
    final settledDecoration = settledContainer.decoration! as BoxDecoration;
    expect(settledDecoration.border!.top.color, Colors.transparent);
  });

  testWidgets("the duration stepper still responds once cross-slot dragging is wired up", (
    tester,
  ) async {
    // Real usage always turns on every writing affordance together, including cross-slot moving —
    // this pins that wrapping a row's body in a `Draggable` for that doesn't also swallow its own
    // ordinary control taps.
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 510,
    );
    final durations = <(String, int)>[];

    await tester.pumpWidget(
      wrapInApp(
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

  testWidgets("a hold row shows its own sequence picker, no other kind does", (tester) async {
    final hold = buildBlock(id: "block-1", kind: OcptShootingBlockKind.hold, sceneId: "scene-1");
    final meal = buildBlock(id: "block-2", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
        OcptShootingTimelineEntry(
          blockId: "block-2",
          startMinute: 510,
          endMinute: 540,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 540,
    );
    final sequence = _buildSequence(sceneId: "scene-1", displaySceneNumber: "4A");

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: [hold, meal],
          timeline: timeline,
          sequences: [sequence],
          onHoldSequenceChanged: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    // The hold row reads its own picked sequence's tag; the meal row shows nothing of the kind.
    expect(find.text(tr.scheduleUnplacedSequenceLabel("4A")), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });

  testWidgets("picking a sequence and clearing it back to none both dispatch", (tester) async {
    final hold = buildBlock(id: "block-1", kind: OcptShootingBlockKind.hold);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 510,
    );
    final sequence = _buildSequence(sceneId: "scene-1", displaySceneNumber: "4A");
    final picked = <(String, String?)>[];

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: [hold],
          timeline: timeline,
          sequences: [sequence],
          onHoldSequenceChanged: (blockId, sceneId) => picked.add((blockId, sceneId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    expect(find.text(tr.scheduleHoldSequencePickerNoSequenceOption), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("${tr.scheduleUnplacedSequenceLabel("4A")} · INT. KITCHEN - DAY"));
    await tester.pumpAndSettle();

    expect(picked, [("block-1", "scene-1")]);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.scheduleHoldSequencePickerNoSequenceOption).last);
    await tester.pumpAndSettle();

    expect(picked, [("block-1", "scene-1"), ("block-1", null)]);
  });

  testWidgets("the sequence picker is withheld when the mode is read-only", (tester) async {
    final hold = buildBlock(id: "block-1", kind: OcptShootingBlockKind.hold, sceneId: "scene-1");
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 510,
    );
    final sequence = _buildSequence(sceneId: "scene-1", displaySceneNumber: "4A");

    await tester.pumpWidget(
      wrapInApp(buildTimetable(blocks: [hold], timeline: timeline, sequences: [sequence])),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text(tr.scheduleUnplacedSequenceLabel("4A")), findsOneWidget);
  });
}
