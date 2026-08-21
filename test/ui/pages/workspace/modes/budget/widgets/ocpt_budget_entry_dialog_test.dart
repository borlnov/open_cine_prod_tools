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
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_dialog.dart';

/// A router manager whose [pop] only records the last call and its value — mirrors
/// `ocpt_project_version_create_dialog_test.dart`'s own instance of this pattern.
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

/// A minimal poste, everything but [id]/[label] neutral.
OcptBudgetPoste _poste({required String id, required String label}) =>
    OcptBudgetPoste(id: id, code: "1", label: label, simpleLabel: null, sortKey: "a0", lines: const []);

/// A minimal existing entry, its debit or credit set by whichever of [debitCents]/[creditCents] is
/// non-zero.
OcptBudgetEntry _existingEntry({
  String id = "entry-1",
  DateTime? date,
  String label = "Camera rental",
  String? posteId,
  int debitCents = 0,
  int creditCents = 0,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  String voucherNumber = "J-007",
}) => OcptBudgetEntry(
  id: id,
  date: date ?? DateTime(2026, 1, 15),
  label: label,
  posteId: posteId,
  debitCents: debitCents,
  creditCents: creditCents,
  isTaxInclusive: isTaxInclusive,
  vatRateBasisPoints: vatRateBasisPoints,
  voucherNumber: voucherNumber,
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

  /// Pumps [OcptBudgetEntryDialog] directly (no `.show`), creating a new entry unless [existing] is
  /// given.
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    OcptBudgetEntry? existing,
    List<OcptBudgetPoste> postes = const [],
    int? defaultVatRateBasisPoints,
    bool isSimplified = false,
  }) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptBudgetEntryDialog(
          existing: existing,
          postes: postes,
          currencyCode: "EUR",
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          isSimplified: isSimplified,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetEntryDialog)));
  }

  testWidgets("refuses to submit a blank label, and nothing is popped", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "12.50",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetEntryDialogLabelRequiredError), findsOneWidget);
    expect(routerManager.popped, isFalse);
  });

  testWidgets("an empty VAT field pops with a null override, meaning inherit", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera rental",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "12.50",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
    expect(fields.vatRateBasisPoints, isNull);
    expect(fields.label, "Camera rental");
    expect(fields.amountCents, 1250);
    // Creating a new entry defaults to a debit ("I paid").
    expect(fields.isDebit, isTrue);
    // Creating a new entry offers no voucher field at all: the service mints one instead.
    expect(fields.voucherNumber, isNull);
  });

  testWidgets("editing an existing entry pre-fills every field and preserves the amount to the cent", (
    tester,
  ) async {
    final existing = _existingEntry(creditCents: 1250, vatRateBasisPoints: 550);
    final tr = await pumpDialog(tester, existing: existing);

    expect(find.widgetWithText(TextFormField, "Camera rental"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "12.50"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "J-007"), findsOneWidget);

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
    expect(fields.amountCents, 1250);
    // The entry was a credit (money that came in), so the direction round-trips as such.
    expect(fields.isDebit, isFalse);
    expect(fields.vatRateBasisPoints, 550);
    expect(fields.voucherNumber, "J-007");
  });

  testWidgets("creating offers a muted voucher-number hint rather than an editable field", (
    tester,
  ) async {
    final tr = await pumpDialog(tester);

    expect(find.text(tr.budgetEntryDialogVoucherAutoHint), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "J-007"), findsNothing);
  });

  testWidgets("editing offers an editable voucher-number field instead of the auto-mint hint", (
    tester,
  ) async {
    final existing = _existingEntry(debitCents: 500);
    final tr = await pumpDialog(tester, existing: existing);

    expect(find.text(tr.budgetEntryDialogVoucherAutoHint), findsNothing);
    expect(find.widgetWithText(TextFormField, "J-007"), findsOneWidget);
  });

  testWidgets("the direction choice reads as I paid / I received under the simplified header", (
    tester,
  ) async {
    final tr = await pumpDialog(tester, isSimplified: true);

    expect(find.text(tr.budgetEntryDialogPaidOption), findsOneWidget);
    expect(find.text(tr.budgetEntryDialogReceivedOption), findsOneWidget);
    expect(find.text(tr.budgetEntryDialogDebitOption), findsNothing);
    expect(find.text(tr.budgetEntryDialogCreditOption), findsNothing);
  });

  testWidgets("the poste picker offers an explicit no-poste choice alongside every live poste", (
    tester,
  ) async {
    final poste = _poste(id: "poste-1", label: "Camera");
    final tr = await pumpDialog(tester, postes: [poste]);

    expect(find.text(tr.budgetCashJournalNoPosteLabel), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Camera").last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Zoom lens",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetEntryFormFields;
    expect(fields.posteId, "poste-1");
  });

  testWidgets("cancelling pops with nothing", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetEntryDialogCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}
