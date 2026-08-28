// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_allowance_dialog.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// A router manager whose [pop] only records the last call and its value — mirrors
/// `ocpt_budget_revenue_dialog_test.dart`'s own instance of this pattern.
class _RecordingRouterManager extends OcptRouterManager {
  /// The value [pop] was last called with.
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    poppedValue = result;
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
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

/// A mileage scale, its rate given in thousandths of a cent per kilometre.
OcptBudgetMileageRate _buildRate({
  required String id,
  required String label,
  required int ratePerKmMilliCents,
}) => OcptBudgetMileageRate(
  id: id,
  label: label,
  ratePerKmMilliCents: ratePerKmMilliCents,
  sortKey: "a0",
);

/// A defrayal, everything but what each test varies left neutral.
OcptBudgetAllowance _buildAllowance({
  OcptBudgetAllowanceKind kind = OcptBudgetAllowanceKind.travel,
  int quantityMilli = 168000,
  int unitAmountMilliCents = 52900,
}) => OcptBudgetAllowance(
  id: "allowance-1",
  personId: null,
  kind: kind,
  label: "Paris — Rouen",
  date: null,
  endDate: null,
  quantityMilli: quantityMilli,
  unitAmountMilliCents: unitAmountMilliCents,
  notes: "",
  sortKey: "a0",
);

void main() {
  late _RecordingRouterManager routerManager;

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }

    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);
  });

  /// Pumps the dialog with [rates] on offer, on [existing] or on a fresh defrayal.
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    required List<OcptBudgetMileageRate> rates,
    OcptBudgetAllowance? existing,
  }) async {
    // The default test surface is too short for the dialog's own scrollable content to lay every
    // field out inside the hit-testable area.
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptBudgetAllowanceDialog(
          existing: existing,
          people: const [],
          mileageRates: rates,
          currencyCode: "EUR",
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetAllowanceDialog)));
  }

  final rates = [
    _buildRate(id: "rate-1", label: "Voiture personnelle", ratePerKmMilliCents: 52900),
    _buildRate(id: "rate-2", label: "Camion", ratePerKmMilliCents: 71000),
  ];

  testWidgets("a travel defrayal is priced by a scale, not by a typed amount", (tester) async {
    final tr = await pumpDialog(tester, rates: rates);

    expect(find.text(tr.budgetAllowanceDialogMileageRateFieldLabel), findsOneWidget);
    // Nothing is picked yet, so the field is still there to type into: the dropdown replaces it
    // only once a scale prices the trip.
    expect(find.text(tr.budgetAllowanceDialogUnitPriceFieldLabel), findsOneWidget);

    await tester.tap(find.text(tr.budgetAllowanceDialogCustomRateOption));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(tr.budgetAllowanceDialogMileageRateOption("Camion", "0.710 EUR")).last,
    );
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetAllowanceDialogUnitPriceFieldLabel), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetAllowanceDialogQuantityFieldLabel),
      "100",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetAllowanceFormFields;
    expect(fields.unitAmountMilliCents, 71000);
    expect(fields.quantityMilli, 100000);
  });

  testWidgets("Free amount hands the field back and keeps the scale on offer", (tester) async {
    final tr = await pumpDialog(tester, rates: rates, existing: _buildAllowance());

    // The existing defrayal is priced at `Voiture personnelle`'s own rate to the thousandth, so it
    // comes back with that scale picked rather than as a bare number.
    expect(find.text(tr.budgetAllowanceDialogUnitPriceFieldLabel), findsNothing);

    await tester.tap(
      find.text(tr.budgetAllowanceDialogMileageRateOption("Voiture personnelle", "0.529 EUR")),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetAllowanceDialogCustomRateOption).last);
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetAllowanceDialogUnitPriceFieldLabel), findsOneWidget);
    // A mis-click has to be undoable: the dropdown does not go away with the value it held.
    expect(find.text(tr.budgetAllowanceDialogMileageRateFieldLabel), findsOneWidget);
  });

  testWidgets("no scale is offered on a nature a scale cannot price", (tester) async {
    final tr = await pumpDialog(tester, rates: rates);

    await tester.tap(
      find.text(
        ocptBudgetAllowanceKindLabel(tr, OcptBudgetAllowanceKind.accommodation),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetAllowanceDialogMileageRateFieldLabel), findsNothing);
    expect(find.text(tr.budgetAllowanceDialogUnitPriceFieldLabel), findsOneWidget);
  });

  testWidgets("a project with no scale says where scales come from", (tester) async {
    final tr = await pumpDialog(tester, rates: const []);

    expect(find.text(tr.budgetAllowanceDialogMileageRateFieldLabel), findsNothing);
    expect(find.text(tr.budgetAllowanceDialogNoMileageRateHint), findsOneWidget);
  });
}
