// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_saved_time_segment.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, matching
/// `editor_page_test.dart`'s own `_wrapWithLocalization` helper.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

void main() {
  testWidgets("a null lastSavedAt shows the never-saved fallback wording", (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(const OcptEditorSavedTimeSegment(lastSavedAt: null)),
    );
    await tester.pump();

    final context = tester.element(find.byType(OcptEditorSavedTimeSegment));
    final tr = Tr.of(context);

    expect(find.text(tr.editorStatsNeverSaved), findsOneWidget);
  });

  testWidgets("a recent lastSavedAt shows the relative-time wording", (tester) async {
    final justNow = DateTime.now();

    await tester.pumpWidget(
      _wrapWithLocalization(OcptEditorSavedTimeSegment(lastSavedAt: justNow)),
    );
    await tester.pump();

    final context = tester.element(find.byType(OcptEditorSavedTimeSegment));
    final tr = Tr.of(context);

    expect(find.text(tr.editorStatsSavedRelative(tr.homeRelativeTimeJustNow)), findsOneWidget);
  });

  testWidgets("textFor computes the same text the widget itself renders", (tester) async {
    final justNow = DateTime.now();

    await tester.pumpWidget(
      _wrapWithLocalization(OcptEditorSavedTimeSegment(lastSavedAt: justNow)),
    );
    await tester.pump();

    final context = tester.element(find.byType(OcptEditorSavedTimeSegment));
    final expectedText = OcptEditorSavedTimeSegment.textFor(context, justNow);

    expect(find.text(expectedText), findsOneWidget);
  });
}
