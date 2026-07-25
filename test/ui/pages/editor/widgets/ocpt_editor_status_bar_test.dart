// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_status_bar.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, matching
/// `editor_page_test.dart`'s own `_wrapWithLocalization` helper, constrained to [width] so the
/// narrow-width degradation tests can force a tight layout.
Widget _wrapWithLocalization(Widget child, {double width = 800}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

/// Widens the test surface well past [width], so a `SizedBox`-constrained status bar of that
/// width actually gets it: the default 800x600 test surface would otherwise clamp it first (this
/// file's `_wrapWithLocalization`'s `Align` never offers its child more width than its own — the
/// test surface's), silently forcing a wide-status-bar test into the narrow/degraded branch.
void _widenTestSurface(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width + 200, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _statistics = FountainScriptStatistics(
  pageCount: 12,
  sceneCount: 34,
  speakingCharacterCount: 8,
  wordCount: 9412,
  signCount: 52108,
);

void main() {
  testWidgets("a wide status bar shows all six counters", (tester) async {
    const width = 1200.0;
    _widenTestSurface(tester, width);

    await tester.pumpWidget(
      _wrapWithLocalization(
        const OcptEditorStatusBar(statistics: _statistics, lastSavedAt: null),
        width: width,
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(OcptEditorStatusBar));
    final tr = Tr.of(context);

    expect(find.textContaining(tr.editorStatsPages(12)), findsOneWidget);
    expect(find.textContaining(tr.editorStatsScenes(34)), findsOneWidget);
    expect(find.textContaining(tr.editorStatsCharacters(8)), findsOneWidget);
    expect(find.textContaining(tr.editorStatsWords(9412)), findsOneWidget);
    expect(find.textContaining(tr.editorStatsSigns(52108)), findsOneWidget);
    expect(find.text(tr.editorStatsNeverSaved), findsOneWidget);
  });

  testWidgets("an empty document and a never-saved state show the zero counters and the fallback "
      "wording", (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        const OcptEditorStatusBar(statistics: FountainScriptStatistics.empty, lastSavedAt: null),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(OcptEditorStatusBar));
    final tr = Tr.of(context);

    expect(find.textContaining(tr.editorStatsPages(0)), findsOneWidget);
    expect(find.text(tr.editorStatsNeverSaved), findsOneWidget);
  });

  testWidgets("a saved time shows the relative-time wording", (tester) async {
    final justNow = DateTime.now();

    await tester.pumpWidget(
      _wrapWithLocalization(OcptEditorStatusBar(statistics: _statistics, lastSavedAt: justNow)),
    );
    await tester.pump();

    final context = tester.element(find.byType(OcptEditorStatusBar));
    final tr = Tr.of(context);

    expect(find.text(tr.editorStatsSavedRelative(tr.homeRelativeTimeJustNow)), findsOneWidget);
  });

  testWidgets(
    "narrowing the status bar drops signs first, keeping words and the saved segment",
    (tester) async {
      const width = 880.0;
      _widenTestSurface(tester, width);

      await tester.pumpWidget(
        _wrapWithLocalization(
          const OcptEditorStatusBar(statistics: _statistics, lastSavedAt: null),
          width: width,
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(OcptEditorStatusBar));
      final tr = Tr.of(context);

      expect(find.textContaining(tr.editorStatsPages(12)), findsOneWidget);
      expect(find.textContaining(tr.editorStatsWords(9412)), findsOneWidget);
      expect(find.textContaining(tr.editorStatsSigns(52108)), findsNothing);
      expect(find.text(tr.editorStatsNeverSaved), findsOneWidget);
    },
  );

  testWidgets(
    "narrowing the status bar further drops words too, keeping the saved segment",
    (tester) async {
      const width = 700.0;
      _widenTestSurface(tester, width);

      await tester.pumpWidget(
        _wrapWithLocalization(
          const OcptEditorStatusBar(statistics: _statistics, lastSavedAt: null),
          width: width,
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(OcptEditorStatusBar));
      final tr = Tr.of(context);

      expect(find.textContaining(tr.editorStatsPages(12)), findsOneWidget);
      expect(find.textContaining(tr.editorStatsWords(9412)), findsNothing);
      expect(find.textContaining(tr.editorStatsSigns(52108)), findsNothing);
      expect(find.text(tr.editorStatsNeverSaved), findsOneWidget);
    },
  );
}
