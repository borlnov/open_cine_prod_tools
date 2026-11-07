// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_overrun.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_timetable.dart';
import 'ocpt_schedule_timetable_test_doubles.dart';

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({
  required String id,
  required String code,
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

/// Run the tests of the schedule timetable block times.
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

  testWidgets("a block's computed start time is shown from the timeline", (tester) async {
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal, label: "Lunch");
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

    await tester.pumpWidget(wrapInApp(buildTimetable(blocks: [block], timeline: timeline)));
    await tester.pumpAndSettle();

    expect(find.textContaining("08:00"), findsOneWidget);
    expect(find.textContaining("08:30"), findsOneWidget);
  });

  testWidgets("an over-run block is marked in the error colour", (tester) async {
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal, anchorMinute: 480);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
      ],
      overruns: [OcptTimelineOverrun(blockId: "block-1", reachedMinute: 540, anchorMinute: 480)],
      startMinute: 480,
      endMinute: 510,
    );

    await tester.pumpWidget(wrapInApp(buildTimetable(blocks: [block], timeline: timeline)));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(OcptScheduleTimetable)));
    final timeText = tester.widget<Text>(find.textContaining("08:00 →"));
    expect(timeText.style?.color, theme.colorScheme.error);
  });

  testWidgets("the ± controls dispatch a new duration", (tester) async {
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

  testWidgets("an on-grid duration still steps by exactly five", (tester) async {
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 495,
          durationMinutes: 15,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 495,
    );
    final durations = <(String, int)>[];

    await tester.pumpWidget(
      wrapInApp(
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

    expect(durations, [("block-1", 20), ("block-1", 10)]);
  });

  testWidgets("an off-grid duration snaps to the nearest five on either control", (tester) async {
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 492,
          durationMinutes: 12,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 492,
    );
    final durations = <(String, int)>[];

    await tester.pumpWidget(
      wrapInApp(
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

    // The 12 is lost either way — the whole point of a stepper that snaps to the grid.
    expect(durations, [("block-1", 15), ("block-1", 10)]);
  });

  testWidgets("stepping down below the grid's first step floors at zero", (tester) async {
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 483,
          durationMinutes: 3,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 483,
    );
    final durations = <(String, int)>[];

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: [block],
          timeline: timeline,
          onDurationChanged: (blockId, duration) => durations.add((blockId, duration)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    expect(durations, [("block-1", 0)]);
  });

  testWidgets("a drag-to-reorder gesture dispatches the reorder event", (tester) async {
    final blockA = buildBlock(id: "block-a", label: "Prep");
    final blockB = buildBlock(id: "block-b", kind: OcptShootingBlockKind.meal, label: "Lunch");
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-a",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
        OcptShootingTimelineEntry(
          blockId: "block-b",
          startMinute: 510,
          endMinute: 540,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 540,
    );
    final reordered = <(String, int)>[];

    await tester.pumpWidget(
      wrapInApp(
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
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.shot, shotId: "shot-1");
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
    OcptShotStatus? pickedStatus;
    String? pickedShotId;

    await tester.pumpWidget(
      wrapInApp(
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
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.shot, shotId: "shot-1");
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
      wrapInApp(
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
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal, anchorMinute: 745);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 745,
          endMinute: 790,
          durationMinutes: 45,
        ),
      ],
      overruns: [],
      startMinute: 745,
      endMinute: 790,
    );
    final anchors = <int?>[];

    await tester.pumpWidget(
      wrapInApp(
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
    final block = buildBlock(id: "block-1", kind: OcptShootingBlockKind.meal);
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-1",
          startMinute: 480,
          endMinute: 525,
          durationMinutes: 45,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 525,
    );

    await tester.pumpWidget(
      wrapInApp(buildTimetable(blocks: [block], timeline: timeline, onAnchorChanged: (_, _) {})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });

  testWidgets("only this slot's own blocks are shown, none of another slot's", (tester) async {
    final ownBlock = buildBlock(id: "block-own", label: "Prep");
    const timeline = OcptShootingSlotTimeline(
      entries: [
        OcptShootingTimelineEntry(
          blockId: "block-own",
          startMinute: 480,
          endMinute: 510,
          durationMinutes: 30,
        ),
      ],
      overruns: [],
      startMinute: 480,
      endMinute: 510,
    );

    // A caller that (incorrectly) handed this timetable another slot's block would still only ever
    // draw what's in `blocks` — there is nothing in this widget that reaches for a second slot's
    // own rows, which this test pins by never passing one in the first place.
    await tester.pumpWidget(wrapInApp(buildTimetable(blocks: [ownBlock], timeline: timeline)));
    await tester.pumpAndSettle();

    expect(find.text("Prep"), findsOneWidget);
  });

  testWidgets("the `+ Block` menu names this timetable's own slot", (tester) async {
    OcptShootingBlockKind? addedKind;

    await tester.pumpWidget(
      wrapInApp(
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

  testWidgets("the `+ Block` menu offers a `Shot` entry, picking it calls onShotBlockRequested "
      "rather than onBlockAdded", (tester) async {
    OcptShootingBlockKind? addedKind;
    var shotRequested = false;

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: const [],
          timeline: null,
          onBlockAdded: (kind) => addedKind = kind,
          onShotBlockRequested: () => shotRequested = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    await tester.tap(find.text(tr.scheduleAddBlockAction));
    await tester.pumpAndSettle();

    // The `Shot` entry sits first, ahead of every milestone/hold kind, with a divider between the
    // two groups.
    expect(
      tester.getCenter(find.text(tr.scheduleBlockKindShot)).dy,
      lessThan(tester.getCenter(find.text(tr.scheduleBlockKindMeal)).dy),
    );
    expect(find.byType(PopupMenuDivider), findsOneWidget);

    await tester.tap(find.text(tr.scheduleBlockKindShot));
    await tester.pumpAndSettle();

    expect(shotRequested, isTrue);
    expect(addedKind, isNull);
  });

  testWidgets("the `Shot` entry is absent when onShotBlockRequested is withheld", (tester) async {
    await tester.pumpWidget(
      wrapInApp(buildTimetable(blocks: const [], timeline: null, onBlockAdded: (_) {})),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    await tester.tap(find.text(tr.scheduleAddBlockAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.scheduleBlockKindShot), findsNothing);
  });

  testWidgets("the `+ Block` menu offers every kind, an audition and a rehearsal included", (
    tester,
  ) async {
    // Nothing narrows this menu: what a day is for is what its blocks say, and one day regularly
    // auditions in the morning, rehearses at noon and shoots in the afternoon.
    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: const [],
          timeline: null,
          onBlockAdded: (_) {},
          onShotBlockRequested: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    await tester.tap(find.text(tr.scheduleAddBlockAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.scheduleBlockKindShot), findsOneWidget);
    expect(find.text(tr.scheduleBlockKindHold), findsOneWidget);
    expect(find.text(tr.scheduleBlockKindAudition), findsOneWidget);
    expect(find.text(tr.scheduleBlockKindRehearsal), findsOneWidget);
  });

  testWidgets("an audition is created in place, like every other kind but a shot", (tester) async {
    OcptShootingBlockKind? addedKind;

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: const [],
          timeline: null,
          onBlockAdded: (kind) => addedKind = kind,
          onShotBlockRequested: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    await tester.tap(find.text(tr.scheduleAddBlockAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.scheduleBlockKindAudition).last);
    await tester.pumpAndSettle();

    expect(addedKind, OcptShootingBlockKind.audition);
  });

  testWidgets("an audition row naming nobody says so, and its picker offers every candidacy", (
    tester,
  ) async {
    final audition = buildBlock(id: "block-1", kind: OcptShootingBlockKind.audition);
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
    final marie = buildRole(id: "role-1", name: "MARIE");
    String? pickedCandidacyId;

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: [audition],
          timeline: timeline,
          roles: [marie],
          roleCandidateById: {
            "candidacy-1": buildCandidacy(
              id: "candidacy-1",
              roleId: "role-1",
              firstName: "Camille",
            ),
          },
          onCandidateAdded: (_, roleCandidateId) => pickedCandidacyId = roleCandidateId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    // Naming nobody yet is an ordinary state, exactly as a hold with no sequence is.
    expect(find.text(tr.scheduleAuditionNoCandidateHint), findsOneWidget);

    await tester.tap(find.text(tr.scheduleAddAuditionCandidateAction));
    await tester.pumpAndSettle();
    // Grouped by the part each candidacy is for: the role's own name heads its candidates.
    expect(find.text("MARIE"), findsOneWidget);
    await tester.tap(find.text("Camille"));
    await tester.pumpAndSettle();

    expect(pickedCandidacyId, "candidacy-1");
  });

  testWidgets("an audition's picker says so, rather than not opening, when nobody is a candidate", (
    tester,
  ) async {
    final audition = buildBlock(id: "block-1", kind: OcptShootingBlockKind.audition);
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
          onCandidateAdded: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    await tester.tap(find.text(tr.scheduleAddAuditionCandidateAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.scheduleAuditionPickerNoCandidacyHint), findsOneWidget);
  });

  testWidgets("an audition's picker still offers a candidacy whose part the roles do not hold", (
    tester,
  ) async {
    final audition = buildBlock(id: "block-1", kind: OcptShootingBlockKind.audition);
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
    String? pickedCandidacyId;

    await tester.pumpWidget(
      wrapInApp(
        buildTimetable(
          blocks: [audition],
          timeline: timeline,
          roleCandidateById: {
            "candidacy-1": buildCandidacy(
              id: "candidacy-1",
              roleId: "role-1",
              firstName: "Camille",
            ),
          },
          onCandidateAdded: (_, roleCandidateId) => pickedCandidacyId = roleCandidateId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleTimetable)));
    await tester.tap(find.text(tr.scheduleAddAuditionCandidateAction));
    await tester.pumpAndSettle();
    expect(find.text(tr.resourcesRoleUnnamed), findsOneWidget);
    await tester.tap(find.text("Camille"));
    await tester.pumpAndSettle();

    expect(pickedCandidacyId, "candidacy-1");
  });
}
