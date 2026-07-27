// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_inspector_panel.dart';

/// A source range every hand-built heading in this file shares: the panel never looks at it.
const _range = FountainSourceRange(startLine: 0, endLine: 0, startOffset: 0, endOffset: 0);

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, constrained
/// to [width]: `OcptWorkspaceDock`'s own 320 px centre floor leaves the right dock itself able to
/// shrink well below that, so this exercises the panel at the dock's practical minimum width.
Widget _wrap(Widget child, {double width = 220}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: width, child: child)),
);

void main() {
  testWidgets('empty state when the caret precedes every scene', (tester) async {
    await tester.pumpWidget(
      _wrap(const OcptEditorInspectorPanel(scene: null, sceneOrdinal: null, statistics: null)),
    );

    final context = tester.element(find.byType(OcptEditorInspectorPanel));
    expect(find.text(Tr.of(context).editorInspectorEmptyHint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the scene under the caret: heading, number, characters, duration, length', (
    tester,
  ) async {
    const heading = FountainSceneHeading(
      sourceRange: _range,
      rawText: 'INT. KITCHEN - DAY',
      headingText: 'INT. KITCHEN - DAY',
      forcedMarker: false,
      sceneNumber: '3',
    );
    const statistics = FountainSceneStatistics(
      speakingCharacters: ['SARAH', 'JOHN'],
      wordCount: 12,
      pageEighths: 11,
    );

    await tester.pumpWidget(
      _wrap(
        const OcptEditorInspectorPanel(scene: heading, sceneOrdinal: 3, statistics: statistics),
      ),
    );

    final context = tester.element(find.byType(OcptEditorInspectorPanel));
    final tr = Tr.of(context);

    expect(find.text(tr.editorInspectorSceneTitle(3)), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('INT. KITCHEN - DAY'), findsOneWidget);
    expect(find.text('SARAH, JOHN'), findsOneWidget);
    // 11 eighths = 1 whole page and 3 eighths.
    expect(find.text(tr.editorInspectorPageEstimateMixed(1, 3)), findsOneWidget);
    // 11/8 ~= 1.375, rounds to 1 minute.
    expect(find.text(tr.editorInspectorDurationEstimate(1)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('omits the scene-number field when the heading has none', (tester) async {
    const heading = FountainSceneHeading(
      sourceRange: _range,
      rawText: 'EXT. GARDEN - NIGHT',
      headingText: 'EXT. GARDEN - NIGHT',
      forcedMarker: false,
    );
    const statistics = FountainSceneStatistics(speakingCharacters: [], wordCount: 4, pageEighths: 1);

    await tester.pumpWidget(
      _wrap(
        const OcptEditorInspectorPanel(scene: heading, sceneOrdinal: 1, statistics: statistics),
      ),
    );

    final context = tester.element(find.byType(OcptEditorInspectorPanel));
    final tr = Tr.of(context);

    expect(find.text(tr.editorInspectorNumberLabel.toUpperCase()), findsNothing);
    // No dialogue in this scene: the characters field falls back to a dash.
    expect(find.text('—'), findsOneWidget);
    // 1 eighth, under a whole page.
    expect(find.text(tr.editorInspectorPageEstimateEighthsOnly(1)), findsOneWidget);
  });

  testWidgets('a whole-page scene shows a plain page count, no eighths remainder', (tester) async {
    const heading = FountainSceneHeading(
      sourceRange: _range,
      rawText: 'INT. HALL - DAY',
      headingText: 'INT. HALL - DAY',
      forcedMarker: false,
    );
    const statistics = FountainSceneStatistics(speakingCharacters: [], wordCount: 4, pageEighths: 16);

    await tester.pumpWidget(
      _wrap(
        const OcptEditorInspectorPanel(scene: heading, sceneOrdinal: 2, statistics: statistics),
      ),
    );

    final context = tester.element(find.byType(OcptEditorInspectorPanel));
    final tr = Tr.of(context);

    expect(find.text(tr.editorInspectorPageEstimateWhole(2)), findsOneWidget);
  });

  testWidgets('does not overflow at the dock practical minimum width', (tester) async {
    const heading = FountainSceneHeading(
      sourceRange: _range,
      rawText: 'INT. A VERY LONG SCENE HEADING THAT COULD WRAP - CONTINUOUS',
      headingText: 'INT. A VERY LONG SCENE HEADING THAT COULD WRAP - CONTINUOUS',
      forcedMarker: false,
      sceneNumber: '12A',
    );
    const statistics = FountainSceneStatistics(
      speakingCharacters: ['A VERY LONG CHARACTER NAME', 'ANOTHER ONE'],
      wordCount: 40,
      pageEighths: 27,
    );

    await tester.pumpWidget(
      _wrap(const OcptEditorInspectorPanel(scene: heading, sceneOrdinal: 12, statistics: statistics)),
    );

    expect(tester.takeException(), isNull);
  });
}
