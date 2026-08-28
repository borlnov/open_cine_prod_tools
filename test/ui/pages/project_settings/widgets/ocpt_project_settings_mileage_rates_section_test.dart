// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_mileage_rates_section.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// One rate, `0.529 €/km`, for tests that need a single row already there.
const _carRate = OcptBudgetMileageRate(
  id: "r1",
  label: "Car",
  ratePerKmMilliCents: 52900,
  sortKey: "a",
);

/// Pumps [OcptProjectSettingsMileageRatesSection] over [mileageRates], recording every callback
/// into the list/map a test reads back.
Future<void> _pumpSection(
  WidgetTester tester, {
  List<OcptBudgetMileageRate> mileageRates = const [],
  VoidCallback? onRateAdded,
  void Function(String rateId, String label)? onRateLabelChanged,
  void Function(String rateId, int ratePerKmMilliCents)? onRateAmountChanged,
  ValueChanged<OcptBudgetMileageRate>? onRateDeletionRequested,
}) async {
  await tester.pumpWidget(
    _wrapWithLocalization(
      OcptProjectSettingsMileageRatesSection(
        mileageRates: mileageRates,
        currencyCode: "EUR",
        onRateAdded: onRateAdded ?? () {},
        onRateLabelChanged: onRateLabelChanged ?? (_, __) {},
        onRateAmountChanged: onRateAmountChanged ?? (_, __) {},
        onRateDeletionRequested: onRateDeletionRequested ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("an empty card offers to add a rate and suggests no figure of its own", (
    tester,
  ) async {
    await _pumpSection(tester);

    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsMileageRatesSection)));
    expect(find.text(tr.projectSettingsMileageRatesEmptyHint), findsOneWidget);
    expect(find.text(tr.projectSettingsMileageRateAddAction), findsOneWidget);
    // No pre-filled row, and nothing that looks like an example figure.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets("tapping Add a rate reports it", (tester) async {
    var added = false;
    await _pumpSection(tester, onRateAdded: () => added = true);

    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsMileageRatesSection)));
    await tester.tap(find.text(tr.projectSettingsMileageRateAddAction));
    await tester.pumpAndSettle();

    expect(added, isTrue);
  });

  testWidgets("a rate typed at three decimals reads back unchanged", (tester) async {
    await _pumpSection(tester, mileageRates: const [_carRate]);

    expect(find.text("0.529"), findsOneWidget);

    final rateField = find.byType(TextField).at(1);
    await tester.enterText(rateField, "0.601");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text("0.601"), findsOneWidget);
  });

  testWidgets("committing a new rate reports the thousandths of a cent it makes", (tester) async {
    final calls = <(String, int)>[];
    await _pumpSection(
      tester,
      mileageRates: const [_carRate],
      onRateAmountChanged: (rateId, cents) => calls.add((rateId, cents)),
    );

    final rateField = find.byType(TextField).at(1);
    await tester.enterText(rateField, "0.601");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(calls, [("r1", 60100)]);
  });

  testWidgets("committing a new label reports it", (tester) async {
    final calls = <(String, String)>[];
    await _pumpSection(
      tester,
      mileageRates: const [_carRate],
      onRateLabelChanged: (rateId, label) => calls.add((rateId, label)),
    );

    final labelField = find.byType(TextField).at(0);
    await tester.enterText(labelField, "Production van");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(calls, [("r1", "Production van")]);
  });

  testWidgets("an unparseable rate is rejected and the field reverts, reporting nothing", (
    tester,
  ) async {
    final calls = <(String, int)>[];
    await _pumpSection(
      tester,
      mileageRates: const [_carRate],
      onRateAmountChanged: (rateId, cents) => calls.add((rateId, cents)),
    );

    final rateField = find.byType(TextField).at(1);
    await tester.enterText(rateField, "gratuit");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(find.text("0.529"), findsOneWidget);
  });

  testWidgets("a row's delete action asks through the callback rather than writing", (
    tester,
  ) async {
    OcptBudgetMileageRate? requested;
    await _pumpSection(
      tester,
      mileageRates: const [_carRate],
      onRateDeletionRequested: (rate) => requested = rate,
    );

    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsMileageRatesSection)));
    await tester.tap(find.byTooltip(tr.projectSettingsMileageRateDeleteTooltip));
    await tester.pumpAndSettle();

    // The widget only ever asks: no confirmation dialog and no state change of its own.
    expect(requested, _carRate);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets("shows the currency over a kilometre as the rate field's suffix", (tester) async {
    await _pumpSection(tester, mileageRates: const [_carRate]);

    final rateField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(rateField.decoration!.suffixText, "€/km");
  });
}
