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
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_revenue_dialog.dart';

/// A router manager whose [pop] only records the last call and its value — mirrors
/// `ocpt_budget_resource_dialog_test.dart`'s own instance of this pattern.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// The value [pop] was last called with.
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
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

/// A minimal existing revenue, everything but what each test actually varies neutral.
OcptBudgetRevenue _existingRevenue({
  String id = "revenue-1",
  DateTime? date,
  String label = "Festival prize",
  int amountCents = 500000,
  OcptBudgetRevenueStatus status = OcptBudgetRevenueStatus.expected,
  String notes = "",
}) => OcptBudgetRevenue(
  id: id,
  date: date ?? DateTime(2026, 3),
  label: label,
  amountCents: amountCents,
  status: status,
  notes: notes,
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

  /// Pumps [OcptBudgetRevenueDialog] directly (no `.show`), creating a new revenue unless
  /// [existing] is given.
  Future<Tr> pumpDialog(WidgetTester tester, {OcptBudgetRevenue? existing}) async {
    // The default test surface is too short for the dialog's own scrollable content to lay every
    // field out without one ending up outside the hit-testable area.
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapWithLocalization(OcptBudgetRevenueDialog(existing: existing, currencyCode: "EUR")),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetRevenueDialog)));
  }

  testWidgets("Save is withheld until the label is filled", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetEntryDialogLabelRequiredError), findsOneWidget);
    expect(routerManager.popped, isFalse);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Festival prize",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetRevenueFormFields;
    expect(fields.label, "Festival prize");
    expect(fields.amountCents, 1000);
  });

  testWidgets("defaults to the expected status", (tester) async {
    final tr = await pumpDialog(tester);

    expect(find.text(tr.budgetSharingRevenueStatusExpectedLabel), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Festival prize",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetRevenueFormFields;
    expect(fields.status, OcptBudgetRevenueStatus.expected);
  });

  testWidgets("editing pre-fills every field", (tester) async {
    final existing = _existingRevenue(
      status: OcptBudgetRevenueStatus.invoiced,
      notes: "Billed in March",
    );
    final tr = await pumpDialog(tester, existing: existing);

    expect(find.widgetWithText(TextFormField, "Festival prize"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "5000.00"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "Billed in March"), findsOneWidget);

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetRevenueFormFields;
    expect(fields.status, OcptBudgetRevenueStatus.invoiced);
    expect(fields.notes, "Billed in March");
    expect(fields.amountCents, 500000);
  });

  testWidgets("picking a different status reports the pick", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetSharingRevenueStatusConfirmedLabel));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Festival prize",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetRevenueFormFields;
    expect(fields.status, OcptBudgetRevenueStatus.confirmed);
  });

  testWidgets("cancelling pops with nothing", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetEntryDialogCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}
