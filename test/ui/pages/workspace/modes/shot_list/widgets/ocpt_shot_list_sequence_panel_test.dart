// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_panel.dart';

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
  home: Scaffold(body: SizedBox(width: 260, height: 600, child: child)),
);

/// Builds a shot with the few fields these tests read, everything else left at a neutral value.
OcptShot _buildShot({
  required String id,
  required String code,
  String shotSize = "",
  bool needsCheck = false,
  OcptShotStatus status = OcptShotStatus.toShoot,
  int difficulty = 1,
  String? orphanedHeading,
}) => OcptShot(
  id: id,
  screenplayId: "screenplay",
  sceneId: orphanedHeading == null ? "scene" : null,
  orphanedHeading: orphanedHeading,
  position: 0,
  shotSize: shotSize,
  abbreviation: "",
  framing: "",
  cameraMove: "",
  lens: "",
  recordingFormat: "",
  estimatedDurationMs: null,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: status,
  difficultySet: difficulty,
  difficultyCamera: difficulty,
  difficultyActing: difficulty,
  difficultySound: difficulty,
  notes: "",
  locationNotes: "",
  needsCheck: needsCheck,
  checkReason: null,
  characters: const [],
  coverageRanges: const [],
  code: code,
  averageDifficulty: difficulty.toDouble(),
);

void main() {
  final sceneSequence = OcptSceneShotSequence(
    sceneId: "scene-1",
    heading: "INT. HOUSE - DAY",
    sceneNumber: null,
    displaySceneNumber: "1",
    charStart: 0,
    charEnd: 40,
    shots: [
      _buildShot(id: "shot-1", code: "1/1", shotSize: "Wide shot"),
      _buildShot(id: "shot-2", code: "1/2", shotSize: "Close-up", needsCheck: true),
    ],
  );
  final otherSequence = OcptSceneShotSequence(
    sceneId: "scene-2",
    heading: "EXT. GARDEN - NIGHT",
    sceneNumber: "2A",
    displaySceneNumber: "2A",
    charStart: 40,
    charEnd: 80,
    shots: [_buildShot(id: "shot-3", code: "2A/1")],
  );

  /// Pumps the panel with [selectedSequenceId] selected, recording every selection and every
  /// orphaned-shot deletion it reports.
  Future<({List<String> sequences, List<String> shots, List<String> deletedShots})> pumpPanel(
    WidgetTester tester, {
    required String? selectedSequenceId,
    List<OcptShotSequence>? sequences,
    VoidCallback? onShotCreated,
    bool canDeleteOrphanedShots = true,
  }) async {
    final selectedSequences = <String>[];
    final selectedShots = <String>[];
    final deletedShots = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotListSequencePanel(
          sequences: sequences ?? [sceneSequence, otherSequence],
          totalShotCount: 3,
          selectedSequenceId: selectedSequenceId,
          selectedShotId: null,
          onSequenceSelected: selectedSequences.add,
          onShotSelected: selectedShots.add,
          onShotCreated: onShotCreated,
          onOrphanedShotDeleted: canDeleteOrphanedShots ? deletedShots.add : null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return (sequences: selectedSequences, shots: selectedShots, deletedShots: deletedShots);
  }

  testWidgets("lists every sequence with its number, heading and summary", (tester) async {
    await pumpPanel(tester, selectedSequenceId: null);

    expect(find.text("1"), findsOneWidget);
    expect(find.text("INT. HOUSE - DAY"), findsOneWidget);
    expect(find.text("2A"), findsOneWidget);
    expect(find.text("EXT. GARDEN - NIGHT"), findsOneWidget);
    // The summary line pairs the sequence's shot count with its average difficulty.
    expect(find.textContaining("2 shots"), findsOneWidget);
    expect(find.textContaining("avg. difficulty 1.0"), findsWidgets);
  });

  testWidgets("only the selected sequence expands to show its shots", (tester) async {
    await pumpPanel(tester, selectedSequenceId: null);
    expect(find.text("1/1"), findsNothing);

    await pumpPanel(tester, selectedSequenceId: "scene-1");
    expect(find.text("1/1"), findsOneWidget);
    expect(find.text("1/2"), findsOneWidget);
    expect(find.text("Wide shot"), findsOneWidget);
    // The other sequence stays collapsed.
    expect(find.text("2A/1"), findsNothing);
  });

  testWidgets("a shot needing checking carries the warning marker", (tester) async {
    await pumpPanel(tester, selectedSequenceId: "scene-1");

    // Exactly one of the two expanded shots needs checking.
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets("clicking a sequence and a shot reports each selection", (tester) async {
    final selections = await pumpPanel(tester, selectedSequenceId: "scene-1");

    await tester.tap(find.text("EXT. GARDEN - NIGHT"));
    await tester.tap(find.text("1/2"));
    await tester.pump();

    expect(selections.sequences, ["scene-2"]);
    expect(selections.shots, ["shot-2"]);
  });

  testWidgets("the + Shot button is disabled when no callback is given", (tester) async {
    await pumpPanel(tester, selectedSequenceId: null);

    final disabledButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(disabledButton.onPressed, isNull);

    var created = 0;
    await pumpPanel(tester, selectedSequenceId: "scene-1", onShotCreated: () => created++);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(created, 1);
  });

  testWidgets("an empty screenplay shows the hint instead of the tree", (tester) async {
    await pumpPanel(tester, selectedSequenceId: null, sequences: const []);

    expect(
      find.text("Sequences will appear here as the screenplay grows."),
      findsOneWidget,
    );
  });

  testWidgets("the orphan group is named rather than carrying a scene heading", (tester) async {
    await pumpPanel(
      tester,
      selectedSequenceId: OcptOrphanShotSequence.sequenceId,
      sequences: [
        sceneSequence,
        OcptOrphanShotSequence(shots: [_buildShot(id: "shot-4", code: "—/1")]),
      ],
    );

    expect(find.text("Orphaned shots"), findsOneWidget);
    expect(find.text("—/1"), findsOneWidget);
  });

  testWidgets("the expanded orphan group heads each deleted scene's shots once", (tester) async {
    await pumpPanel(
      tester,
      selectedSequenceId: OcptOrphanShotSequence.sequenceId,
      sequences: [
        OcptOrphanShotSequence(
          shots: [
            _buildShot(id: "shot-4", code: "—/1", orphanedHeading: "INT. OLD KITCHEN - DAY"),
            _buildShot(id: "shot-5", code: "—/2", orphanedHeading: "INT. OLD KITCHEN - DAY"),
            _buildShot(id: "shot-6", code: "—/3", orphanedHeading: "EXT. CUT ROOFTOP - NIGHT"),
          ],
        ),
      ],
    );

    // One heading row per run of shots that came from the same deleted scene, not one per shot.
    expect(find.text("INT. OLD KITCHEN - DAY"), findsOneWidget);
    expect(find.text("EXT. CUT ROOFTOP - NIGHT"), findsOneWidget);
  });

  testWidgets("only an orphaned shot carries a delete button, reporting its id", (tester) async {
    await pumpPanel(tester, selectedSequenceId: "scene-1");
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    final selections = await pumpPanel(
      tester,
      selectedSequenceId: OcptOrphanShotSequence.sequenceId,
      sequences: [
        OcptOrphanShotSequence(
          shots: [_buildShot(id: "shot-4", code: "—/1", orphanedHeading: "INT. OLD KITCHEN - DAY")],
        ),
      ],
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(selections.deletedShots, ["shot-4"]);
  });

  testWidgets("no orphaned shot carries a delete button while no shot may be deleted", (
    tester,
  ) async {
    await pumpPanel(
      tester,
      selectedSequenceId: OcptOrphanShotSequence.sequenceId,
      sequences: [
        OcptOrphanShotSequence(
          shots: [_buildShot(id: "shot-4", code: "—/1", orphanedHeading: "INT. OLD KITCHEN - DAY")],
        ),
      ],
      canDeleteOrphanedShots: false,
    );

    expect(find.text("—/1"), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
