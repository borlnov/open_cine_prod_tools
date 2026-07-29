// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_difficulty_rating.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_panel.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 320, child: child)),
);

/// Grows the test surface tall enough that the whole (long, scrolling) panel is built and
/// hit-testable without having to scroll it, restoring the default size once the test ends.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Builds a shot with the fields these tests read, everything else left at a neutral value.
OcptShot _buildShot({
  String id = "shot-1",
  String code = "1/1",
  OcptShotStatus status = OcptShotStatus.toShoot,
  List<String> characters = const ["LÉA"],
  int difficultySet = 1,
  int difficultyCamera = 1,
  int difficultyActing = 1,
  int difficultySound = 1,
}) => OcptShot(
  id: id,
  screenplayId: "screenplay",
  sceneId: "scene",
  orphanedHeading: null,
  position: 0,
  shotSize: "Wide shot",
  framing: "Eye level",
  cameraMove: "Static",
  lens: "35 mm",
  recordingFormat: "4K · 25 fps",
  estimatedDurationMs: null,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: status,
  difficultySet: difficultySet,
  difficultyCamera: difficultyCamera,
  difficultyActing: difficultyActing,
  difficultySound: difficultySound,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: characters,
  coverageRanges: const [],
  code: code,
  averageDifficulty:
      (difficultySet + difficultyCamera + difficultyActing + difficultySound) / 4,
);

/// Builds a panel with a sensible default of every field, only the fields a given test cares
/// about overridden.
Widget _buildPanel({
  OcptShot? shot,
  List<String> speakingCharacters = const ["LÉA"],
  void Function(OcptShotDifficultyAxis axis, int value)? onDifficultyChanged,
  ValueChanged<String>? onCharacterToggled,
  void Function(OcptShotListEditableField field, String rawValue)? onFieldChanged,
  VoidCallback? onDeleteRequested,
}) => OcptShotInspectorPanel(
  shot: shot,
  sequenceHeading: "INT. LÉA'S FLAT - NIGHT",
  sequenceDisplayNumber: "1",
  speakingCharacters: speakingCharacters,
  suggestions: const OcptShotFieldSuggestions.empty(),
  fieldValueOf: (field) => "",
  onDifficultyChanged: onDifficultyChanged ?? (_, __) {},
  onCharacterToggled: onCharacterToggled ?? (_) {},
  onFieldChanged: onFieldChanged ?? (_, __) {},
  onDeleteRequested: onDeleteRequested,
);

void main() {
  testWidgets("shows the empty hint when no shot is selected", (tester) async {
    await tester.pumpWidget(_wrapInApp(_buildPanel()));

    expect(find.text("Select a shot to see its details."), findsOneWidget);
    expect(find.text("Delete shot"), findsNothing);
  });

  testWidgets("renders the selected shot's header, sequence and average difficulty",
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildPanel(shot: _buildShot())));

    expect(find.text("Shot 1/1"), findsOneWidget);
    expect(find.text("INT. LÉA'S FLAT - NIGHT"), findsOneWidget);
    expect(find.text("Difficulty — avg. 1.0"), findsOneWidget);
    expect(find.text("Delete shot"), findsOneWidget);
  });

  testWidgets("toggling a character chip reports its name", (tester) async {
    final toggled = <String>[];

    await tester.pumpWidget(
      _wrapInApp(_buildPanel(shot: _buildShot(), onCharacterToggled: toggled.add)),
    );

    await tester.tap(find.text("LÉA"));
    await tester.pump();

    expect(toggled, ["LÉA"]);
  });

  testWidgets("the status pill is a read-out, not a control", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildPanel(shot: _buildShot())));

    await tester.tap(find.text("To shoot"));
    await tester.pumpAndSettle();

    expect(find.text("To shoot"), findsOneWidget);
    expect(find.text("Shot"), findsNothing);
    expect(find.text("Retake"), findsNothing);
  });

  testWidgets("the production section leaves the scheduling fields out", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildPanel(shot: _buildShot())));

    expect(find.text("ESTIMATED DURATION"), findsOneWidget);
    expect(find.text("SHOOTING DAY"), findsNothing);
    expect(find.text("PLANNED TAKES"), findsNothing);
  });

  testWidgets("clicking a difficulty dot reports the axis and value", (tester) async {
    await _useTallSurface(tester);
    OcptShotDifficultyAxis? reportedAxis;
    int? reportedValue;

    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(
          shot: _buildShot(),
          onDifficultyChanged: (axis, value) {
            reportedAxis = axis;
            reportedValue = value;
          },
        ),
      ),
    );

    // The four difficulty rows are laid out in axis order: Set, Camera move, Acting, Sound. The
    // third row (Acting) is what this test clicks into, its fifth dot (value 4).
    final actingRow = find.byType(OcptShotDifficultyRating).at(2);
    final dots = find.descendant(of: actingRow, matching: find.byType(InkWell));
    await tester.tap(dots.at(4));
    await tester.pump();

    expect(reportedAxis, OcptShotDifficultyAxis.acting);
    expect(reportedValue, 4);
  });

  testWidgets("clicking delete shot dispatches the delete request", (tester) async {
    await _useTallSurface(tester);
    var deleteRequested = false;

    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(shot: _buildShot(), onDeleteRequested: () => deleteRequested = true),
      ),
    );

    await tester.tap(find.text("Delete shot"));
    await tester.pump();

    expect(deleteRequested, isTrue);
  });

  testWidgets("a character attached but removed from the screenplay stays listed, struck through",
      (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(shot: _buildShot(characters: const ["LÉA", "CLARA"])),
      ),
    );

    expect(find.text("CLARA (removed)"), findsOneWidget);
  });
}
