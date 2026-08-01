// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_status_bar.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, in the app's own
/// theme (the status bar reads the shot list's warning colour out of [OcptSpecificColors]), inside
/// a box [width] wide.
Widget _wrapInApp(Widget child, {double width = 700}) => MaterialApp(
  theme: ocptTheme.lightThemeData,
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
  /// Pumps the status bar for a shot list of [shotsToCheckCount] shots left to check, in a band
  /// [width] wide.
  Future<void> pumpStatusBar(
    WidgetTester tester, {
    int shotsToCheckCount = 2,
    double width = 700,
  }) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotListStatusBar(
          sequenceCount: 3,
          shotCount: 9,
          filmedShotCount: 2,
          shotsToCheckCount: shotsToCheckCount,
        ),
        width: width,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("shows the sequence, shot, filmed and to-check counters", (tester) async {
    await pumpStatusBar(tester);

    expect(find.text("3 sequences · 9 shots · 2 filmed"), findsOneWidget);
    expect(find.text("2 to check"), findsOneWidget);
  });

  testWidgets("a narrow band drops the filmed count before the two first ones", (tester) async {
    await pumpStatusBar(tester, width: 190);

    expect(find.text("3 sequences · 9 shots"), findsOneWidget);
    // The count asking for an action is the trailing segment: it is never dropped.
    expect(find.text("2 to check"), findsOneWidget);
  });

  testWidgets("the to-check count is only tinted while there is something to check", (
    tester,
  ) async {
    await pumpStatusBar(tester);
    final warningColor = ocptTheme.lightThemeData!
        .extension<OcptSpecificColors>()!
        .shotStatusRetake;

    expect(tester.widget<Text>(find.text("2 to check")).style?.color, warningColor);

    await pumpStatusBar(tester, shotsToCheckCount: 0);

    expect(tester.widget<Text>(find.text("0 to check")).style?.color, isNot(warningColor));
  });
}
