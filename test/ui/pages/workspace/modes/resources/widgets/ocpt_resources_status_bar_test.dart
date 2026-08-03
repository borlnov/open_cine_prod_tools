// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_status_bar.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a box [width]
/// wide.
Widget _wrapInApp(Widget child, {double width = 700}) => MaterialApp(
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
  /// Pumps the status bar with a fixed set of counts, in a band [width] wide.
  Future<void> pumpStatusBar(WidgetTester tester, {double width = 900}) async {
    await tester.pumpWidget(
      _wrapInApp(
        const OcptResourcesStatusBar(
          peopleCount: 12,
          roleCount: 5,
          positionCount: 8,
          locationCount: 3,
          elementCount: 21,
        ),
        width: width,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("shows the five counters", (tester) async {
    await pumpStatusBar(tester);

    expect(find.text("12 people · 5 roles · 8 positions · 3 locations"), findsOneWidget);
    expect(find.text("21 elements"), findsOneWidget);
  });

  testWidgets("a narrow band drops roles and positions before the people count", (tester) async {
    await pumpStatusBar(tester, width: 260);

    expect(find.text("12 people"), findsOneWidget);
    // The elements count is the trailing segment: it is never dropped.
    expect(find.text("21 elements"), findsOneWidget);
  });
}
