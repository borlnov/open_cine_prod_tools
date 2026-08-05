// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_status_bar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a band [width]
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
  /// Pumps the status bar for [taggedTargetCount] tagged targets, [usedCategoryCount] categories,
  /// [toFindCount] elements still to find and [needsCheckTagCount] tags still to check, in a band
  /// [width] wide.
  Future<void> pumpStatusBar(
    WidgetTester tester, {
    int taggedTargetCount = 5,
    int usedCategoryCount = 3,
    int toFindCount = 2,
    int needsCheckTagCount = 0,
    double width = 700,
  }) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownStatusBar(
          taggedTargetCount: taggedTargetCount,
          usedCategoryCount: usedCategoryCount,
          toFindCount: toFindCount,
          needsCheckTagCount: needsCheckTagCount,
        ),
        width: width,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("shows the tagged, category, to-find and to-check counters", (tester) async {
    await pumpStatusBar(tester, needsCheckTagCount: 1);

    expect(find.text("5 tagged · 3 categories"), findsOneWidget);
    expect(find.text("2 to find"), findsOneWidget);
    expect(find.text("1 to check"), findsOneWidget);
  });

  testWidgets("a narrow band drops the category count before the tagged count", (tester) async {
    await pumpStatusBar(tester, needsCheckTagCount: 1, width: 320);

    expect(find.text("5 tagged"), findsOneWidget);
    // The trailing counters are never dropped.
    expect(find.text("2 to find"), findsOneWidget);
    expect(find.text("1 to check"), findsOneWidget);
  });

  testWidgets("a single tagged target still reads in the singular", (tester) async {
    await pumpStatusBar(
      tester,
      taggedTargetCount: 1,
      usedCategoryCount: 1,
      toFindCount: 1,
      needsCheckTagCount: 1,
    );

    expect(find.text("1 tagged · 1 category"), findsOneWidget);
    expect(find.text("1 to find"), findsOneWidget);
    expect(find.text("1 to check"), findsOneWidget);
  });

  testWidgets("the to-check counter shows plainly while there is nothing to check", (tester) async {
    await pumpStatusBar(tester);

    final warningColor = ocptWarningColor(tester.element(find.byType(OcptBreakdownStatusBar)));
    final toCheckText = tester.widget<Text>(find.text("0 to check"));
    expect(toCheckText.style?.color, isNot(warningColor));
  });

  testWidgets("the to-check counter wears the warning colour once something needs checking",
      (tester) async {
    await pumpStatusBar(tester, needsCheckTagCount: 3);

    final warningColor = ocptWarningColor(tester.element(find.byType(OcptBreakdownStatusBar)));
    final toCheckText = tester.widget<Text>(find.text("3 to check"));
    expect(toCheckText.style?.color, warningColor);
  });
}
