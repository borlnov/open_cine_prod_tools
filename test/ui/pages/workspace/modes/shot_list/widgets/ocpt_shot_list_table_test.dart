// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The `OcptSpecificColors` these tests theme the table with: recognisable, deliberately
/// non-Material colours, so an assertion on a cell's colour can only pass by reading the
/// extension rather than by accident.
const _specificColors = OcptSpecificColors(
  previewBackdrop: Color(0xFFFFFFFF),
  projectPosterTints: [Color(0xFF112233)],
  shotStatusShot: Color(0xFF00FF00),
  shotStatusRetake: Color(0xFFFF00FF),
);

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, and with
/// [_specificColors], inside a sized box standing in for the centre area the table fills in the
/// app.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  theme: ThemeData(extensions: const [_specificColors]),
  home: Scaffold(body: SizedBox(width: 900, height: 600, child: child)),
);

/// Builds a shot with the fields these tests read, everything else left at a neutral value.
OcptShot _buildShot({
  required String id,
  required String code,
  String shotSize = "Wide shot",
  String lens = "35 mm",
  int? estimatedDurationMs,
  int? plannedTakes,
  bool needsCheck = false,
  OcptShotStatus status = OcptShotStatus.toShoot,
  int difficulty = 1,
}) => OcptShot(
  id: id,
  screenplayId: "screenplay",
  sceneId: "scene",
  orphanedHeading: null,
  position: 0,
  shotSize: shotSize,
  framing: "Eye level",
  cameraMove: "Static",
  lens: lens,
  recordingFormat: "4K · 25 fps",
  estimatedDurationMs: estimatedDurationMs,
  shootingDay: null,
  plannedTakes: plannedTakes,
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
  characters: const ["LÉA"],
  coverageRanges: const [],
  code: code,
  averageDifficulty: difficulty.toDouble(),
);

void main() {
  /// Pumps the table, recording every shot selection it reports.
  Future<List<String>> pumpTable(
    WidgetTester tester, {
    required List<OcptShot> shots,
    Set<OcptShotListColumn>? visibleColumns,
    String? selectedShotId,
  }) async {
    final selectedShots = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotListTable(
          shots: shots,
          sequenceHeading: "INT. HOUSE - DAY",
          visibleColumns: visibleColumns ?? OcptShotListColumn.defaultVisibleColumns,
          selectedShotId: selectedShotId,
          onShotSelected: selectedShots.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return selectedShots;
  }

  testWidgets("shows the always-visible columns and the default optional ones", (tester) async {
    await pumpTable(tester, shots: [_buildShot(id: "shot-1", code: "1/1")]);

    for (final header in const [
      "SHOT",
      "CHARACTERS",
      "SHOT SIZE",
      "FRAMING & COMPOSITION",
      "CAMERA MOVE",
      "DIFF.",
      "DURATION",
      "SHOOTING DAY",
      "STATUS",
    ]) {
      expect(find.text(header), findsOneWidget, reason: "missing the $header column");
    }

    // The optional columns left off by default aren't there.
    expect(find.text("LENS"), findsNothing);
    expect(find.text("SET"), findsNothing);
  });

  testWidgets("an optional column appears once it is made visible", (tester) async {
    await pumpTable(
      tester,
      shots: [_buildShot(id: "shot-1", code: "1/1")],
      visibleColumns: {OcptShotListColumn.lens, OcptShotListColumn.set},
    );

    expect(find.text("LENS"), findsOneWidget);
    expect(find.text("35 mm"), findsOneWidget);
    // The `Set` column reads the sequence's heading, which no shot stores itself.
    expect(find.text("SET"), findsOneWidget);
    expect(find.text("INT. HOUSE - DAY"), findsOneWidget);
    expect(find.text("STATUS"), findsNothing);
  });

  testWidgets("renders each cell's value, dashing the ones a shot has no value for",
      (tester) async {
    await pumpTable(
      tester,
      shots: [
        _buildShot(
          id: "shot-1",
          code: "1/1",
          estimatedDurationMs: 95000,
          plannedTakes: 3,
          status: OcptShotStatus.retake,
        ),
      ],
      visibleColumns: {
        OcptShotListColumn.duration,
        OcptShotListColumn.takes,
        OcptShotListColumn.status,
        OcptShotListColumn.shootingDay,
      },
    );

    expect(find.text("1/1"), findsOneWidget);
    expect(find.text("LÉA"), findsOneWidget);
    expect(find.text("1:35"), findsOneWidget);
    expect(find.text("3"), findsOneWidget);
    expect(find.text("Retake"), findsOneWidget);
    // The shot has no shooting day yet.
    expect(find.text(ocptShotListEmptyValue), findsOneWidget);
  });

  testWidgets("the shot code is typeset in the screenplay's fixed-pitch family", (tester) async {
    await pumpTable(tester, shots: [_buildShot(id: "shot-1", code: "1/1")]);

    final codeCell = tester.widget<Text>(find.text("1/1"));
    expect(codeCell.style?.fontFamily, ocptMonospaceFontFamily);
  });

  testWidgets("a difficulty at or above the warning threshold is warning-coloured",
      (tester) async {
    await pumpTable(
      tester,
      shots: [
        // 2.0 sits just under the warning threshold, 3.0 just over it.
        _buildShot(id: "shot-1", code: "1/1", difficulty: 2),
        _buildShot(id: "shot-2", code: "1/2", difficulty: 3),
      ],
    );

    final calmDifficulty = tester.widget<Text>(find.text("2.0"));
    final warningDifficulty = tester.widget<Text>(find.text("3.0"));

    expect(warningDifficulty.style?.color, _specificColors.shotStatusRetake);
    expect(calmDifficulty.style?.color, isNot(_specificColors.shotStatusRetake));
  });

  testWidgets("the status cell takes its own status colour", (tester) async {
    await pumpTable(
      tester,
      shots: [
        _buildShot(id: "shot-1", code: "1/1", status: OcptShotStatus.shot),
        _buildShot(id: "shot-2", code: "1/2", status: OcptShotStatus.retake),
      ],
      visibleColumns: {OcptShotListColumn.status},
    );

    expect(
      tester.widget<Text>(find.text("Shot")).style?.color,
      _specificColors.shotStatusShot,
    );
    expect(
      tester.widget<Text>(find.text("Retake")).style?.color,
      _specificColors.shotStatusRetake,
    );
  });

  testWidgets("a shot needing checking carries the gutter marker", (tester) async {
    await pumpTable(
      tester,
      shots: [
        _buildShot(id: "shot-1", code: "1/1"),
        _buildShot(id: "shot-2", code: "1/2", needsCheck: true),
      ],
    );

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets("clicking a row reports the shot it shows", (tester) async {
    final selectedShots = await pumpTable(
      tester,
      shots: [
        _buildShot(id: "shot-1", code: "1/1"),
        _buildShot(id: "shot-2", code: "1/2"),
      ],
    );

    await tester.tap(find.text("1/2"));
    await tester.pump();

    expect(selectedShots, ["shot-2"]);
  });

  testWidgets("an empty sequence shows the hint instead of the table", (tester) async {
    await pumpTable(tester, shots: const []);

    expect(find.text("This sequence has no shot yet."), findsOneWidget);
    expect(find.text("SHOT"), findsNothing);
  });
}
