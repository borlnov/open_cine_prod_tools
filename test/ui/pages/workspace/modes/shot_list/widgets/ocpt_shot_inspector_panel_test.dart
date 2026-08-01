// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_difficulty_rating.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

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
  bool needsCheck = false,
  OcptShotCheckReason? checkReason,
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
  needsCheck: needsCheck,
  checkReason: checkReason,
  characters: characters,
  coverageRanges: const [],
  code: code,
  averageDifficulty:
      (difficultySet + difficultyCamera + difficultyActing + difficultySound) / 4,
);

/// The text field of the panel's estimated duration row, the one field of the panel bound to
/// something other than free text.
TextField _durationFieldOf(WidgetTester tester) => tester.widget<TextField>(
  find.descendant(
    of: find.ancestor(
      of: find.text("ESTIMATED DURATION (MM:SS)"),
      matching: find.byType(OcptShotInspectorField),
    ),
    matching: find.byType(TextField),
  ),
);

/// Builds a panel with a sensible default of every field, only the fields a given test cares
/// about overridden.
Widget _buildPanel({
  OcptShot? shot,
  List<String> screenplayCharacters = const ["LÉA"],
  void Function(OcptShotDifficultyAxis axis, int value)? onDifficultyChanged,
  ValueChanged<String>? onCharacterToggled,
  void Function(OcptShotListEditableField field, String rawValue)? onFieldChanged,
  String Function(OcptShotListEditableField field)? fieldValueOf,
  VoidCallback? onMarkAsChecked,
  VoidCallback? onSelectCoverageRequested,
  VoidCallback? onDeleteRequested,
}) => OcptShotInspectorPanel(
  shot: shot,
  sequenceHeading: "INT. LÉA'S FLAT - NIGHT",
  sequenceDisplayNumber: "1",
  screenplayCharacters: screenplayCharacters,
  suggestions: const OcptShotFieldSuggestions.empty(),
  coverageLayout: null,
  otherShotsCoverageRanges: const {},
  staleCoverageRangeIds: const {},
  fieldValueOf: fieldValueOf ?? (field) => "",
  onDifficultyChanged: onDifficultyChanged ?? (_, __) {},
  onCharacterToggled: onCharacterToggled ?? (_) {},
  onFieldChanged: onFieldChanged ?? (_, __) {},
  onSelectCoverageRequested: onSelectCoverageRequested ?? () {},
  onCoverageClearAll: () {},
  onMarkAsChecked: onMarkAsChecked ?? () {},
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

    expect(find.text("ESTIMATED DURATION (MM:SS)"), findsOneWidget);
    expect(find.text("SHOOTING DAY"), findsNothing);
    expect(find.text("PLANNED TAKES"), findsNothing);
  });

  testWidgets("the estimated duration field accepts nothing but a mm:ss duration",
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(
          shot: _buildShot(),
          fieldValueOf: (field) =>
              field == OcptShotListEditableField.estimatedDuration ? "1:75" : "",
        ),
      ),
    );

    final field = _durationFieldOf(tester);

    expect(field.inputFormatters, ocptShotDurationInputFormatters);
    expect(field.decoration?.hintText, "mm:ss");
    expect(field.decoration?.errorText, "Use the mm:ss format");
  });

  testWidgets("the estimated duration field shows no error for a duration it accepts",
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(
          shot: _buildShot(),
          fieldValueOf: (field) =>
              field == OcptShotListEditableField.estimatedDuration ? "01:30" : "",
        ),
      ),
    );

    expect(_durationFieldOf(tester).decoration?.errorText, isNull);
  });

  testWidgets("the fields written as a sentence are as tall as the director's notes",
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildPanel(shot: _buildShot())));

    /// The text field of the inspector field labelled [label].
    TextField fieldOf(String label) => tester.widget<TextField>(
      find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(OcptShotInspectorField),
        ),
        matching: find.byType(TextField),
      ),
    );

    for (final label in const ["FRAMING & COMPOSITION", "CAMERA MOVE", "SOUND"]) {
      expect(fieldOf(label).minLines, greaterThan(1), reason: label);
      expect(fieldOf(label).maxLines, isNull, reason: label);
    }

    expect(fieldOf("SHOT SIZE").maxLines, 1);
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

  testWidgets("the Needs checking callout is absent when the shot doesn't need checking",
      (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_wrapInApp(_buildPanel(shot: _buildShot())));

    expect(find.text("Mark as checked"), findsNothing);
  });

  testWidgets("the Needs checking callout shows the covered-text-changed reason", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(
          shot: _buildShot(
            needsCheck: true,
            checkReason: OcptShotCheckReason.coveredTextChanged,
          ),
        ),
      ),
    );

    expect(
      find.text("The screenplay text one of this shot's coverage ranges covers has changed."),
      findsOneWidget,
    );
    expect(find.text("Mark as checked"), findsOneWidget);
  });

  testWidgets("the Needs checking callout shows the coverage-out-of-bounds reason", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(
          shot: _buildShot(
            needsCheck: true,
            checkReason: OcptShotCheckReason.coverageOutOfBounds,
          ),
        ),
      ),
    );

    expect(
      find.text(
        "One of this shot's coverage ranges no longer fits inside its scene and was clamped.",
      ),
      findsOneWidget,
    );
  });

  testWidgets("the Needs checking callout shows the scene-deleted reason", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(
          shot: _buildShot(needsCheck: true, checkReason: OcptShotCheckReason.sceneDeleted),
        ),
      ),
    );

    expect(find.text("This shot's scene was removed from the screenplay."), findsOneWidget);
  });

  testWidgets("Mark as checked is filled with the callout's own warning colour", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(
          shot: _buildShot(needsCheck: true, checkReason: OcptShotCheckReason.sceneDeleted),
        ),
      ),
    );

    // A filled button, not a bare label: the action has to carry its own background against the
    // callout's tinted one.
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text("Mark as checked"), matching: find.byType(FilledButton)),
    );
    final context = tester.element(find.byType(OcptShotInspectorPanel));
    expect(
      button.style?.backgroundColor?.resolve({}),
      ocptShotListWarningColor(context),
    );
  });

  testWidgets("clicking Mark as checked reports it", (tester) async {
    await _useTallSurface(tester);
    var markedAsChecked = false;

    await tester.pumpWidget(
      _wrapInApp(
        _buildPanel(
          shot: _buildShot(needsCheck: true, checkReason: OcptShotCheckReason.sceneDeleted),
          onMarkAsChecked: () => markedAsChecked = true,
        ),
      ),
    );

    await tester.tap(find.text("Mark as checked"));
    await tester.pump();

    expect(markedAsChecked, isTrue);
  });
}
