// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_metadata_panel.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 320, height: 600, child: child)),
);

/// Builds a shot with the fields these tests read, everything else left at a neutral value.
OcptShot _buildShot({List<String> characters = const [], String? shootingDay, int? plannedTakes}) =>
    OcptShot(
      id: "shot-1",
      screenplayId: "screenplay",
      sceneId: "scene",
      orphanedHeading: null,
      position: 0,
      shotSize: "Wide shot",
      abbreviation: "WS",
      framing: "Eye level",
      cameraMove: "Static",
      lens: "35 mm",
      recordingFormat: "4K · 25 fps",
      estimatedDurationMs: null,
      shootingDay: shootingDay,
      plannedTakes: plannedTakes,
      sound: "",
      status: OcptShotStatus.toShoot,
      difficultySet: 1,
      difficultyCamera: 1,
      difficultyActing: 1,
      difficultySound: 1,
      notes: "",
      locationNotes: "",
      needsCheck: false,
      checkReason: null,
      characters: characters,
      coverageRanges: const [],
      code: "1/1",
      averageDifficulty: 1,
    );

void main() {
  testWidgets("shows the empty hint when no shot is selected", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        const OcptShotMetadataPanel(shot: null, sequenceDisplayNumber: "1", sequenceHeading: ""),
      ),
    );

    expect(find.text("Select a shot to see its details."), findsOneWidget);
  });

  testWidgets("renders the sequence, set, characters, shooting day and takes", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotMetadataPanel(
          shot: _buildShot(
            characters: const ["LÉA", "MARC"],
            shootingDay: "Day 3",
            plannedTakes: 4,
          ),
          sequenceDisplayNumber: "1",
          sequenceHeading: "INT. LÉA'S FLAT - NIGHT",
        ),
      ),
    );

    expect(find.text("1"), findsOneWidget);
    expect(find.text("INT. LÉA'S FLAT - NIGHT"), findsOneWidget);
    expect(find.text("LÉA, MARC"), findsOneWidget);
    expect(find.text("Day 3"), findsOneWidget);
    expect(find.text("4"), findsOneWidget);
  });

  testWidgets("renders the em dash for a shot with no characters, shooting day or takes",
      (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotMetadataPanel(
          shot: _buildShot(),
          sequenceDisplayNumber: "1",
          sequenceHeading: "INT. LÉA'S FLAT - NIGHT",
        ),
      ),
    );

    // Characters, shooting day and takes all fall back to the same em dash placeholder.
    expect(find.text("—"), findsNWidgets(3));
  });
}
