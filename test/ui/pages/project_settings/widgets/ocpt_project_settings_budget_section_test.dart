// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_budget_section.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  /// The VAT rate field: the section's first [TextField] in build order.
  Finder vatRateField() => find.byType(TextField).at(0);

  /// The meal price field: the section's second [TextField] in build order.
  Finder mealPriceField() => find.byType(TextField).at(1);

  /// Pumps [OcptProjectSettingsBudgetSection] with [defaultVatRateBasisPoints], [mealPriceCents]
  /// and [snackPriceCents] as its current values, recording every commit each callback reports into
  /// the list it hands back — one entry per call, in call order.
  Future<List<int?>> pumpSection(
    WidgetTester tester, {
    int? defaultVatRateBasisPoints,
    int? mealPriceCents,
    int? snackPriceCents,
    required ValueChanged<int?> onVatRateChanged,
  }) async {
    final mealCalls = <int?>[];
    final snackCalls = <int?>[];

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectSettingsBudgetSection(
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          onDefaultVatRateBasisPointsChanged: onVatRateChanged,
          mealPriceCents: mealPriceCents,
          onMealPriceCentsChanged: mealCalls.add,
          snackPriceCents: snackPriceCents,
          onSnackPriceCentsChanged: snackCalls.add,
          currencyCode: "EUR",
        ),
      ),
    );
    await tester.pumpAndSettle();

    return mealCalls;
  }

  testWidgets("typing a rate in per cent reports it in basis points", (tester) async {
    final vatCalls = <int?>[];
    await pumpSection(tester, onVatRateChanged: vatCalls.add);

    await tester.enterText(vatRateField(), "20");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(vatCalls, [2000]);
  });

  testWidgets("a fractional rate typed with a comma reports it in basis points", (tester) async {
    final vatCalls = <int?>[];
    await pumpSection(tester, onVatRateChanged: vatCalls.add);

    await tester.enterText(vatRateField(), "5,5");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(vatCalls, [550]);
  });

  testWidgets("typing 0 reports 0 rather than null — an explicit exemption", (tester) async {
    final vatCalls = <int?>[];
    await pumpSection(tester, onVatRateChanged: vatCalls.add);

    await tester.enterText(vatRateField(), "0");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(vatCalls, [0]);
  });

  testWidgets("tapping No rate reports null", (tester) async {
    final vatCalls = <int?>[];
    await pumpSection(tester, defaultVatRateBasisPoints: 2000, onVatRateChanged: vatCalls.add);
    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsBudgetSection)));

    await tester.tap(find.widgetWithText(TextButton, tr.projectSettingsBudgetVatRateNoRateAction));
    await tester.pumpAndSettle();

    expect(vatCalls, [null]);
  });

  testWidgets("a negative rate is rejected and the field reverts, reporting nothing", (
    tester,
  ) async {
    final vatCalls = <int?>[];
    await pumpSection(tester, defaultVatRateBasisPoints: 2000, onVatRateChanged: vatCalls.add);

    await tester.enterText(vatRateField(), "-5");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(vatCalls, isEmpty);
    expect(find.text("20"), findsOneWidget);
  });

  testWidgets("an unparseable rate is rejected and the field reverts", (tester) async {
    final vatCalls = <int?>[];
    await pumpSection(tester, defaultVatRateBasisPoints: 2000, onVatRateChanged: vatCalls.add);

    await tester.enterText(vatRateField(), "twenty");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(vatCalls, isEmpty);
    expect(find.text("20"), findsOneWidget);
  });

  testWidgets("submitting the VAT rate field empty reverts it rather than clearing the rate", (
    tester,
  ) async {
    final vatCalls = <int?>[];
    await pumpSection(tester, defaultVatRateBasisPoints: 2000, onVatRateChanged: vatCalls.add);

    await tester.enterText(vatRateField(), "");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(vatCalls, isEmpty);
    expect(find.text("20"), findsOneWidget);
  });

  testWidgets("a money field submitted empty reports null", (tester) async {
    final mealCalls = await pumpSection(
      tester,
      mealPriceCents: 500,
      onVatRateChanged: (_) {},
    );

    await tester.enterText(mealPriceField(), "");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(mealCalls, [null]);
  });

  testWidgets("a money field typed over reports the cents it makes", (tester) async {
    final mealCalls = await pumpSection(tester, onVatRateChanged: (_) {});

    await tester.enterText(mealPriceField(), "12.50");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(mealCalls, [1250]);
  });

  testWidgets("shows the currency symbol as the money fields' suffix", (tester) async {
    await pumpSection(tester, onVatRateChanged: (_) {});

    final field = tester.widget<TextField>(mealPriceField());
    expect((field.decoration!.suffixText), "€");
  });
}
