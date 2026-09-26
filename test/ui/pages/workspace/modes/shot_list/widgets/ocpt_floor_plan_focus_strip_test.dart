// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_focus_strip.dart';

/// Wraps [child] with the localization delegates so `Tr.of` lookups resolve.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
    ),
  );
}

OcptShot _shot({required String id, required String code}) => OcptShot(
  id: id,
  screenplayId: "screenplay",
  sceneId: "scene-1",
  orphanedHeading: null,
  position: 0,
  shotSize: "",
  abbreviation: "",
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
  testWidgets('the "All cameras" toggle chip reports a tap', (tester) async {
    var toggled = false;

    await _pump(
      tester,
      OcptFloorPlanFocusStrip(
        shots: [_shot(id: "shot-1", code: "1/1")],
        hasCameraOnSetOf: const {"shot-1": true},
        selectedShotId: "shot-1",
        previousShotId: null,
        nextShotId: null,
        isAllCamerasShown: false,
        onShotChipSelected: (_) {},
        onAllCamerasToggled: () => toggled = true,
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanFocusStrip)));

    await tester.tap(find.text(tr.shotListFloorPlanAllCamerasToggleLabel));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('the "All cameras" toggle chip reads active once isAllCamerasShown is true', (
    tester,
  ) async {
    await _pump(
      tester,
      OcptFloorPlanFocusStrip(
        shots: [_shot(id: "shot-1", code: "1/1")],
        hasCameraOnSetOf: const {},
        selectedShotId: "shot-1",
        previousShotId: null,
        nextShotId: null,
        isAllCamerasShown: true,
        onShotChipSelected: (_) {},
        onAllCamerasToggled: () {},
      ),
    );

    expect(find.byIcon(Icons.videocam), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
  });
}
